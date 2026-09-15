import 'package:drift/drift.dart';
import '../../../core/error/failure.dart';
import '../../canvas/data/canvas_api.dart';
import '../../../core/config/env.dart';
import '../../../core/storage/cache_policy.dart';
import '../../../core/storage/cache_session.dart';
import '../../../core/storage/db/app_database.dart';
import '../../notifications/data/notification_models.dart';
import 'announcements_api.dart';

/// 목록 항목의 종류. 알 수 없는 값은 공지로 본다.
NoticeKind noticeKindOf(AnnouncementRow row) =>
    NoticeKind.values.where((k) => k.name == row.kind).firstOrNull ??
    NoticeKind.announcement;

/// 서버의 원래 id. 공지가 아닌 항목은 'file:123'으로 저장한다.
String noticeItemId(AnnouncementRow row) {
  final prefix = '${row.kind}:';
  return row.id.startsWith(prefix) ? row.id.substring(prefix.length) : row.id;
}

/// 읽음 기록 키. 공지는 이 형식이 먼저 쓰였으므로 그대로 둔다.
String noticeReadKey(AnnouncementRow row) =>
    '${noticeKindOf(row).name}:${noticeItemId(row)}';

/// 처음 동기화할 때 이보다 오래된 소식은 읽은 것으로 둔다.
/// 학기 중간에 설치하면 수십 개의 과제·파일이 한꺼번에 빨갛게 뜨기 때문이다.
const _unreadWindow = Duration(days: 7);

class AnnouncementsRepository {
  AnnouncementsRepository({
    required AnnouncementsApi api,
    required AppDatabase db,
    CacheSession? session,
    CanvasApi? canvas,
  })  : _api = api,
        _canvas = canvas,
        _session = session ?? CacheSession(),
        _db = db;

  final AnnouncementsApi _api;
  final CanvasApi? _canvas;
  final AppDatabase _db;
  final CacheSession _session;

  String _cacheKey(int termId) => 'announcements:$termId';
  String _baselineKey(int termId) => 'notice-baseline:$termId';

  Stream<List<AnnouncementRow>> watch(int termId) =>
      _db.announcementsDao.watchByTerm(termId);

  Future<void> refresh(int termId, {bool force = false}) async {
    final revision = _session.revision;
    if (!_session.accepts(revision)) return;
    if (!force) {
      final at = await _db.cacheMetaDao.fetchedAt(_cacheKey(termId));
      if (CachePolicy.isFresh(at, Env.announcementsTtl)) return;
    }
    final rows = <AnnouncementsCompanion>[];
    Failure? partialFailure;
    final canvas = _canvas;
    if (canvas == null) {
      rows.addAll(await _api.fetchAnnouncements(termId));
    } else {
      final courses = await _db.coursesDao.watchByTerm(termId).first;
      if (courses.isEmpty) return;
      final previous = await watch(termId).first;
      for (final c in courses) {
        if (!_session.accepts(revision)) return;
        // 한 강좌 안의 네 탭은 동시에 받는다. 강좌끼리는 차례로 받아
        // 서버에 요청을 한꺼번에 몰지 않는다.
        final results = await Future.wait([
          for (final kind in NoticeKind.values)
            _fetchKind(canvas, termId, c, kind).then<Object>((r) => r,
                onError: (Object e) => e is Failure ? e : throw e),
        ]);
        for (final (i, result) in results.indexed) {
          final kind = NoticeKind.values[i];
          if (result is List<AnnouncementsCompanion>) {
            rows.addAll(result);
            continue;
          }
          final failure = result as Failure;
          // 강의자료실·토론을 닫아 둔 강좌는 학생에게 권한 오류를 준다.
          // 매번 실패 배너를 띄우지 않도록 빈 탭으로 본다.
          if (kind != NoticeKind.announcement && _isClosedTab(failure)) {
            continue;
          }
          partialFailure = failure;
          rows.addAll(previous
              .where((a) => a.courseId == c.id && a.kind == kind.name)
              .map((a) => a.toCompanion(false)));
        }
      }
    }
    await _db.transaction(() async {
      if (!_session.accepts(revision)) return;
      await _db.announcementsDao.replaceForTerm(termId, rows);
      if (partialFailure == null) {
        await _db.cacheMetaDao.touch(_cacheKey(termId));
        await _markOldAsReadOnce(termId);
      }
    });
    if (_session.accepts(revision) && partialFailure != null) {
      throw partialFailure;
    }
  }

  Future<void> _markOldAsReadOnce(int termId) async {
    if (await _db.cacheMetaDao.fetchedAt(_baselineKey(termId)) != null) return;
    final now = DateTime.now().toUtc();
    final rows = await (_db.select(_db.announcements)
          ..where((a) => a.termId.equals(termId)))
        .get();
    final old = rows.where((r) =>
        r.postedAt == null || now.difference(r.postedAt!) > _unreadWindow);
    await _db.batch((b) => b.insertAll(
          _db.readNotices,
          [
            for (final r in old)
              ReadNoticesCompanion.insert(key: noticeReadKey(r), readAt: now)
          ],
          mode: InsertMode.insertOrIgnore,
        ));
    await _db.cacheMetaDao.touch(_baselineKey(termId));
  }

  Future<List<AnnouncementsCompanion>> _fetchKind(
      CanvasApi canvas, int termId, CourseRow c, NoticeKind kind) async {
    if (kind == NoticeKind.announcement) {
      final announcements = await canvas.fetchAnnouncements(c.id);
      return [
        for (final a in announcements)
          AnnouncementsCompanion.insert(
            id: '${a.id}',
            termId: termId,
            courseId: Value(c.id),
            contextName: Value(c.name),
            title: a.title,
            message: Value(a.message),
            authorName: Value(a.authorName),
            postedAt: Value(a.postedAt),
            htmlUrl: Value(a.htmlUrl.isEmpty
                ? '/courses/${c.id}/discussion_topics/${a.id}'
                : a.htmlUrl),
          )
      ];
    }
    final raw = await canvas.getListRaw(
      switch (kind) {
        NoticeKind.file => '/courses/${c.id}/files',
        NoticeKind.assignment => '/courses/${c.id}/assignments',
        _ => '/courses/${c.id}/discussion_topics',
      },
      query: switch (kind) {
        NoticeKind.file => const {'sort': 'created_at', 'order': 'desc'},
        NoticeKind.assignment => const {'include[]': 'submission'},
        _ => null,
      },
    );
    if (kind == NoticeKind.discussion) {
      // 다른 학생이 올린 토론 글은 공지 탭에 필요 없다. 강의자 글만 남긴다.
      var instructors = const <int>{};
      try {
        instructors = await canvas.fetchInstructorIds(c.id);
      } on Failure catch (e) {
        if (!_isClosedTab(e)) rethrow;
      }
      return parseCourseActivities(
          raw
              .where((r) => isInstructorPost(r, instructors,
                  teacherNames: c.teacherNames))
              .toList(),
          kind,
          termId: termId,
          courseId: c.id,
          courseName: c.name);
    }
    return parseCourseActivities(raw, kind,
        termId: termId, courseId: c.id, courseName: c.name);
  }

  static bool _isClosedTab(Failure failure) =>
      failure is ServerFailure &&
      const {'401', '403', '404'}.contains(failure.code);
}

/// 강좌 탭 목록 응답을 공지 화면 행으로 바꾼다.
/// 숨김·잠김 기준은 알림 감지(parseWatchedItems)와 맞춰 같은 항목만 보여준다.
List<AnnouncementsCompanion> parseCourseActivities(
  List<Map<String, dynamic>> json,
  NoticeKind kind, {
  required int termId,
  required int courseId,
  required String courseName,
}) {
  DateTime? date(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toUtc() : null;
  final result = <AnnouncementsCompanion>[];
  for (final row in json) {
    final id = row['id'];
    if (id == null || '$id'.isEmpty) continue;
    if (kind == NoticeKind.discussion && row['is_announcement'] == true) {
      continue;
    }
    if (row['published'] == false ||
        row['locked_for_user'] == true ||
        row['hidden_for_user'] == true ||
        row['hidden'] == true) {
      continue;
    }
    final delayed = date(row['delayed_post_at']);
    if (delayed != null && delayed.isAfter(DateTime.now())) continue;

    final (title, message, author, postedAt, path) = switch (kind) {
      NoticeKind.file => (
          row['display_name'] ?? row['filename'],
          '',
          '',
          date(row['created_at']) ?? date(row['updated_at']),
          'files',
        ),
      NoticeKind.assignment => (
          row['name'],
          row['description'],
          '',
          date(row['created_at']) ?? date(row['updated_at']),
          'assignments',
        ),
      _ => (
          row['title'],
          row['message'],
          (row['author'] as Map?)?['display_name'] ?? row['user_name'],
          date(row['posted_at']) ?? date(row['created_at']),
          'discussion_topics',
        ),
    };
    final htmlUrl = row['html_url'];
    result.add(AnnouncementsCompanion.insert(
      id: '${kind.name}:$id',
      kind: Value(kind.name),
      termId: termId,
      courseId: Value(courseId),
      contextName: Value(courseName),
      title: title is String && title.isNotEmpty ? title : '${kind.label} #$id',
      message: Value(message is String ? message : ''),
      authorName: Value(author is String ? author : ''),
      postedAt: Value(postedAt),
      submitted: Value(
          kind == NoticeKind.assignment && isSubmitted(row['submission'])),
      htmlUrl: Value(htmlUrl is String && htmlUrl.isNotEmpty
          ? htmlUrl
          : '/courses/$courseId/$path/$id'),
    ));
  }
  return result;
}
