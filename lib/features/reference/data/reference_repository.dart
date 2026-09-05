import '../../../core/config/env.dart';
import '../../../core/storage/cache_policy.dart';
import '../../../core/storage/cache_session.dart';
import '../../../core/storage/db/app_database.dart';
import 'reference_api.dart';

const String _termsCacheKey = 'terms';

/// 기관·학기처럼 거의 변하지 않는 기준 데이터.
/// 화면은 항상 캐시를 읽고, 네트워크는 TTL을 넘겼을 때만 친다.
class ReferenceRepository {
  ReferenceRepository({required ReferenceApi api, required AppDatabase db, CacheSession? session})
      : _api = api,
        _session = session ?? CacheSession(),
        _db = db;

  final ReferenceApi _api;
  final AppDatabase _db;
  final CacheSession _session;

  Stream<List<TermRow>> watchTerms() => _db.termsDao.watchAll();

  Future<void> refreshTerms({bool force = false}) async {
    final revision = _session.revision;
    if (!_session.accepts(revision)) return;
    if (!force) {
      final at = await _db.cacheMetaDao.fetchedAt(_termsCacheKey);
      if (CachePolicy.isFresh(at, Env.referenceTtl)) return;
    }
    final rows = await _api.fetchTerms(Env.defaultAccountId);
    await _db.transaction(() async {
      if (!_session.accepts(revision)) return;
      await _db.termsDao.upsertAll(rows);
      await _db.cacheMetaDao.touch(_termsCacheKey);
    });
  }

  /// 오늘이 포함된 학기를 고르고, 없으면 가장 최근(id 최대) 학기로 폴백한다.
  Future<int?> currentTermId({DateTime? now}) async {
    final rows = await _db.termsDao.watchAll().first;
    if (rows.isEmpty) return null;

    final today = (now ?? DateTime.now()).toUtc();
    for (final t in rows) {
      final start = t.startAt;
      final end = t.endAt;
      if (start != null &&
          end != null &&
          !today.isBefore(start) &&
          !today.isAfter(end)) {
        return t.id;
      }
    }
    return rows.first.id; // watchAll은 id 내림차순
  }
}
