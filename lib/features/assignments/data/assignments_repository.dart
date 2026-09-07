import 'package:drift/drift.dart';
import '../../../core/error/failure.dart';
import '../../canvas/data/canvas_api.dart';
import '../../../core/config/env.dart';
import '../../../core/storage/cache_policy.dart';
import '../../../core/storage/cache_session.dart';
import '../../../core/storage/db/app_database.dart';
import 'calendar_api.dart';

export 'calendar_api.dart' show courseIdFromContextCode;

/// 과제 마감을 포함한 캘린더 이벤트 저장소.
/// 서버가 강좌 단위 조회만 지원하므로 캐시된 강좌를 순회해 한 학기분을 모은다.
class AssignmentsRepository {
  AssignmentsRepository(
      {required CalendarApi api,
      required AppDatabase db,
      CacheSession? session,
      CanvasApi? canvas})
      : _api = api,
        _canvas = canvas,
        _session = session ?? CacheSession(),
        _db = db;

  final CalendarApi _api;
  final CanvasApi? _canvas;
  final AppDatabase _db;
  final CacheSession _session;

  String _cacheKey(int termId) => 'calendar:$termId';

  Stream<List<CalendarEventRow>> watchTerm(int termId) =>
      _db.calendarEventsDao.watchByTerm(termId);

  Stream<List<CalendarEventRow>> watchBetween({
    required DateTime from,
    required DateTime to,
  }) =>
      _db.calendarEventsDao.watchBetween(from: from, to: to);

  Future<void> refresh(
    int termId, {
    bool force = false,
    DateTime? from,
    DateTime? to,
  }) async {
    final revision = _session.revision;
    if (!_session.accepts(revision)) return;
    if (!force) {
      final at = await _db.cacheMetaDao.fetchedAt(_cacheKey(termId));
      if (CachePolicy.isFresh(at, Env.calendarTtl)) return;
    }

    final courses = await _db.coursesDao.watchByTerm(termId).first;
    if (courses.isEmpty) return; // 강좌 캐시가 먼저 채워져야 한다.

    final start =
        from ?? DateTime.now().toUtc().subtract(const Duration(days: 60));
    final end = to ?? DateTime.now().toUtc().add(const Duration(days: 180));

    final all = <CalendarEventsCompanion>[];
    final previous = await watchTerm(termId).first;
    Failure? partialFailure;
    for (final c in courses) {
      if (!_session.accepts(revision)) return;
      final byId = <String, CalendarEventsCompanion>{};
      try {
        final events = await _api.fetchEvents(
            termId: termId, courseId: c.id, from: start, to: end);
        for (final event in events) {
          byId[event.id.value] = event;
        }
      } on Failure catch (e) {
        if (_canvas == null) rethrow;
        partialFailure = e;
        for (final event in previous.where((e) => e.courseId == c.id)) {
          byId[event.id] = event.toCompanion(false);
        }
      }
      if (!_session.accepts(revision)) return;
      if (_canvas != null) {
        try {
          final assignments = await _canvas.fetchAssignments(c.id);
          // Canvas의 과제 원본을 기준으로 마감 변경·삭제·기한 없는 과제도 반영한다.
          byId.removeWhere((id, _) => id.startsWith('assignment_'));
          for (final a in assignments) {
            byId['assignment_${a.id}'] = CalendarEventsCompanion.insert(
              id: 'assignment_${a.id}',
              termId: termId,
              courseId: Value(c.id),
              contextName: Value(c.name),
              title: a.name,
              startAt: Value(a.dueAt),
              endAt: Value(a.dueAt),
              htmlUrl: Value(a.htmlUrl.isEmpty
                  ? '/courses/${c.id}/assignments/${a.id}'
                  : a.htmlUrl),
            );
          }
        } on Failure catch (e) {
          partialFailure = e;
          for (final event in previous.where(
              (e) => e.courseId == c.id && e.id.startsWith('assignment_'))) {
            byId.putIfAbsent(event.id, () => event.toCompanion(false));
          }
        }
      }
      all.addAll(byId.values);
    }

    await _db.transaction(() async {
      if (!_session.accepts(revision)) return;
      await _db.calendarEventsDao.replaceForTerm(termId, all);
      if (partialFailure == null) {
        await _db.cacheMetaDao.touch(_cacheKey(termId));
      }
    });
    if (_session.accepts(revision) && partialFailure != null) {
      throw partialFailure;
    }
  }
}
