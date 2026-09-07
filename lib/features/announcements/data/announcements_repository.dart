import 'package:drift/drift.dart';
import '../../../core/error/failure.dart';
import '../../canvas/data/canvas_api.dart';
import '../../../core/config/env.dart';
import '../../../core/storage/cache_policy.dart';
import '../../../core/storage/cache_session.dart';
import '../../../core/storage/db/app_database.dart';
import 'announcements_api.dart';

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
    if (_canvas == null) {
      rows.addAll(await _api.fetchAnnouncements(termId));
    } else {
      final courses = await _db.coursesDao.watchByTerm(termId).first;
      if (courses.isEmpty) return;
      final previous = await watch(termId).first;
      for (final c in courses) {
        if (!_session.accepts(revision)) return;
        try {
          final announcements = await _canvas.fetchAnnouncements(c.id);
          rows.addAll(announcements.map((a) => AnnouncementsCompanion.insert(
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
              )));
        } on Failure catch (e) {
          partialFailure = e;
          rows.addAll(previous
              .where((a) => a.courseId == c.id)
              .map((a) => a.toCompanion(false)));
        }
      }
    }
    await _db.transaction(() async {
      if (!_session.accepts(revision)) return;
      await _db.announcementsDao.replaceForTerm(termId, rows);
      if (partialFailure == null) {
        await _db.cacheMetaDao.touch(_cacheKey(termId));
      }
    });
    if (_session.accepts(revision) && partialFailure != null) {
      throw partialFailure;
    }
  }
}
