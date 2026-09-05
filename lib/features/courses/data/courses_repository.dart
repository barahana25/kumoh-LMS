import '../../../core/config/env.dart';
import '../../../core/storage/cache_policy.dart';
import '../../../core/storage/db/app_database.dart';
import 'courses_api.dart';

/// 오프라인-퍼스트 강좌 저장소.
/// [watch]는 즉시 캐시를 흘려보내고, [refresh]는 TTL을 넘겼을 때만 네트워크를 친다.
class CoursesRepository {
  CoursesRepository({required CoursesApi api, required AppDatabase db})
      : _api = api,
        _db = db;

  final CoursesApi _api;
  final AppDatabase _db;

  String _cacheKey(int termId) => 'courses:$termId';

  Stream<List<CourseRow>> watch(int termId) => _db.coursesDao.watchByTerm(termId);

  Future<void> refresh(int termId, {bool force = false}) async {
    if (!force) {
      final at = await _db.cacheMetaDao.fetchedAt(_cacheKey(termId));
      if (CachePolicy.isFresh(at, Env.coursesTtl)) return;
    }
    // 실패하면 예외가 그대로 올라가고 캐시는 손대지 않는다.
    final rows = await _api.fetchCourses(
      accountId: Env.defaultAccountId,
      termId: termId,
    );
    await _db.coursesDao.replaceForTerm(termId, rows);
    await _db.cacheMetaDao.touch(_cacheKey(termId));
  }
}
