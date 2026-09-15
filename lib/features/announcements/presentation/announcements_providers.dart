import 'package:drift/drift.dart'
    show InsertMode, OrderingTerm, innerJoin;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/storage/db/app_database.dart';
import '../../../providers.dart';
import '../../notifications/data/notification_models.dart';
import '../data/announcements_repository.dart';
import '../../reference/presentation/term_providers.dart';

final termAnnouncementsProvider =
    StreamProvider.family<List<AnnouncementRow>, int>(
  (ref, termId) => ref.watch(announcementsRepositoryProvider).watch(termId),
);

final noticeHistoryProvider =
    StreamProvider.autoDispose<List<NotificationOutboxData>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.notificationOutbox).join([
    innerJoin(db.notificationSettings,
        db.notificationSettings.owner.equalsExp(db.notificationOutbox.owner)),
  ])
    ..orderBy([
      OrderingTerm.desc(db.notificationOutbox.detectedAt),
      OrderingTerm.desc(db.notificationOutbox.id)
    ]);
  return query.watch().map(
      (rows) => rows.map((r) => r.readTable(db.notificationOutbox)).toList());
});

/// 공지 화면 한 줄. [readKey]로 읽음 여부를 기록한다.
class NoticeEntry {
  const NoticeEntry(
      {required this.item, required this.kind, required this.readKey});
  final AnnouncementRow item;
  final NoticeKind kind;
  final String readKey;
}

/// 학기 소식(공지·과제·강의자료·토론)과 알림 내역을 합쳐 최신순으로 정렬한다.
/// 알림 내역의 항목이 이미 학기 소식에 있으면 한 번만 보여준다.
List<NoticeEntry> buildNoticeFeed(int termId, List<AnnouncementRow> announcements,
    List<NotificationOutboxData> history) {
  final entries = <NoticeEntry>[
    for (final item in announcements)
      NoticeEntry(
          item: item, kind: noticeKindOf(item), readKey: noticeReadKey(item)),
  ];
  for (final notice in history) {
    final kind =
        NoticeKind.values.where((k) => k.name == notice.kind).firstOrNull;
    if (kind == null) continue;
    // 예전 알림 내역에는 학생이 쓴 토론도 섞여 있다. 토론은 강의자 글만
    // 걸러 모은 학기 목록으로만 보여준다.
    if (kind == NoticeKind.discussion) continue;
    if (entries.any((c) =>
        c.kind == kind &&
        c.item.courseId == notice.courseId &&
        (noticeItemId(c.item) == notice.itemId ||
            (notice.itemId.isEmpty && c.item.title == notice.title)))) {
      continue;
    }
    final path = switch (kind) {
      NoticeKind.announcement || NoticeKind.discussion => 'discussion_topics',
      NoticeKind.file => 'files',
      NoticeKind.assignment => 'assignments',
    };
    entries.add(NoticeEntry(
      kind: kind,
      readKey: 'notice:${notice.id}',
      item: AnnouncementRow(
        id: 'notice-${notice.id}',
        kind: kind.name,
        submitted: false,
        termId: termId,
        courseId: notice.courseId,
        contextName: notice.courseName,
        title: notice.title,
        message: '',
        authorName: '',
        postedAt: notice.detectedAt.year > 1970 ? notice.detectedAt : null,
        htmlUrl: '${Env.canvasHost}/courses/${notice.courseId}/$path'
            '${notice.itemId.isEmpty ? '' : '/${Uri.encodeComponent(notice.itemId)}'}',
      ),
    ));
  }
  entries.sort((a, b) => (b.item.postedAt ?? DateTime(1970))
      .compareTo(a.item.postedAt ?? DateTime(1970)));
  return entries;
}

class NoticeReadStore {
  NoticeReadStore(this._db);
  final AppDatabase _db;

  Stream<Set<String>> watchKeys() => _db
      .select(_db.readNotices)
      .map((r) => r.key)
      .watch()
      .map((keys) => keys.toSet());

  /// 처음 읽은 시각을 보존하도록 이미 있는 키는 건드리지 않는다.
  Future<void> markRead(Iterable<String> keys) async {
    final now = DateTime.now().toUtc();
    await _db.batch((b) => b.insertAll(
          _db.readNotices,
          [
            for (final key in keys)
              ReadNoticesCompanion.insert(key: key, readAt: now)
          ],
          mode: InsertMode.insertOrIgnore,
        ));
  }
}

final noticeReadStoreProvider =
    Provider((ref) => NoticeReadStore(ref.watch(appDatabaseProvider)));

final readNoticeKeysProvider = StreamProvider<Set<String>>(
    (ref) => ref.watch(noticeReadStoreProvider).watchKeys());

/// 하단 탭 배지에 쓰는 안 읽은 소식 수.
final unreadNoticeCountProvider = Provider.autoDispose<int>((ref) {
  final termId = ref.watch(activeTermIdProvider).valueOrNull;
  final read = ref.watch(readNoticeKeysProvider).valueOrNull;
  if (termId == null || read == null) return 0;
  final feed = buildNoticeFeed(
    termId,
    ref.watch(termAnnouncementsProvider(termId)).valueOrNull ?? const [],
    ref.watch(noticeHistoryProvider).valueOrNull ?? const [],
  );
  return feed.where((e) => !read.contains(e.readKey)).length;
});
