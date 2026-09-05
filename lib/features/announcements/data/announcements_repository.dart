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
  })  : _api = api,
        _session = session ?? CacheSession(),
        _db = db;

  final AnnouncementsApi _api;
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
    final rows = await _api.fetchAnnouncements(termId);
    await _db.transaction(() async {
      if (!_session.accepts(revision)) return;
      await _db.announcementsDao.replaceForTerm(termId, rows);
      await _db.cacheMetaDao.touch(_cacheKey(termId));
    });
  }
}
