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

/// 한 번에 동시에 받아 올 강좌 수. 강좌마다 탭 네 개를 동시에 받으므로
/// 실제로 떠 있는 요청은 이 값의 네 배(브라우저 한 탭의 두어 배)다.
/// 강좌 수만큼 직렬로 기다리지 않으면서 학교 서버에 몰지도 않는 절충값이다.
const _courseConcurrency = 4;

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

  /// 강좌별 강의자 id. [_instructorIds]가 채우고 앱이 살아 있는 동안 쓴다.
  final _instructors = <int, Set<int>>{};

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
      // 강좌를 몇 개씩 묶어 동시에 받는다. 강좌 수만큼 차례로 기다리면
      // 왕복이 그대로 쌓이고, 한꺼번에 다 보내면 학교 서버에 몰린다.
      for (var i = 0; i < courses.length; i += _courseConcurrency) {
        if (!_session.accepts(revision)) return;
        final batch = courses.skip(i).take(_courseConcurrency);
        final fetched = await Future.wait(
            [for (final c in batch) _fetchCourse(canvas, termId, c, previous)]);
        for (final (courseRows, failure) in fetched) {
          rows.addAll(courseRows);
          partialFailure ??= failure;
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

  /// 한 강좌의 네 탭을 한꺼번에 받는다. 실패한 탭은 [previous]의 캐시로
  /// 메우고 그 실패를 함께 돌려준다.
  Future<(List<AnnouncementsCompanion>, Failure?)> _fetchCourse(
    CanvasApi canvas,
    int termId,
    CourseRow c,
    List<AnnouncementRow> previous,
  ) async {
    final rows = <AnnouncementsCompanion>[];
    Failure? partialFailure;
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
      if (kind != NoticeKind.announcement && _isClosedTab(failure)) continue;
      partialFailure ??= failure;
      rows.addAll(previous
          .where((a) => a.courseId == c.id && a.kind == kind.name)
          .map((a) => a.toCompanion(false)));
    }
    return (rows, partialFailure);
  }

  /// 강의자 id는 학기 중에 바뀌지 않는다. 앱이 켜져 있는 동안 강좌별로
  /// 기억해 두고 새로고침마다 수강 목록을 다시 받지 않는다.
  Future<Set<int>> _instructorIds(CanvasApi canvas, int courseId) async {
    final known = _instructors[courseId];
    if (known != null) return known;
    var ids = const <int>{};
    try {
      ids = await canvas.fetchInstructorIds(courseId);
    } on Failure catch (e) {
      // 수강 목록을 볼 수 없는 강좌다. 매번 다시 묻지 않는다.
      if (!_isClosedTab(e)) rethrow;
    }
    return _instructors[courseId] = ids;
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
      // 공지는 따로 받으므로 여기서는 뺀다. 남는 글이 없으면 강의자를
      // 가릴 일도 없으니 수강 목록 왕복을 통째로 건너뛴다.
      final topics = raw.where((r) => r['is_announcement'] != true).toList();
      if (topics.isEmpty) return const [];
      // 다른 학생이 올린 토론 글은 공지 탭에 필요 없다. 강의자 글만 남긴다.
      final instructors = await _instructorIds(canvas, c.id);
      return parseCourseActivities(
          topics
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
