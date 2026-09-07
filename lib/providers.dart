import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/env.dart';
import 'core/network/dio_client.dart';
import 'core/network/token_store.dart';
import 'core/storage/db/app_database.dart';
import 'core/storage/cache_session.dart';
import 'features/announcements/data/announcements_api.dart';
import 'features/announcements/data/announcements_repository.dart';
import 'features/assignments/data/assignments_repository.dart';
import 'features/assignments/data/calendar_api.dart';
import 'features/auth/data/auth_api.dart';
import 'features/canvas/data/canvas_api.dart';
import 'features/canvas/data/canvas_cache.dart';
import 'features/canvas/data/canvas_client.dart';
import 'features/canvas/data/canvas_download.dart';
import 'features/canvas/data/canvas_session.dart';
import 'features/canvas/data/saml_bridge_api.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/courses/data/courses_api.dart';
import 'features/courses/data/courses_repository.dart';
import 'features/reference/data/reference_api.dart';
import 'features/reference/data/reference_repository.dart';

// ---------- 인프라 ----------

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final store = ref.watch(tokenStoreProvider);
  final db = AppDatabase.encrypted(store.ensureDbKey);
  ref.onDispose(db.close);
  return db;
});

/// 인터셉터가 없는 dio. 로그인·재발급 전용이라 재귀가 생기지 않는다.
final authDioProvider = Provider<Dio>((ref) => buildAuthDio());

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(
  ref.watch(authDioProvider), tokenStore: ref.watch(tokenStoreProvider),
));

/// 나머지 모든 API가 쓰는 dio. 토큰 부착과 자동 재발급이 붙어 있다.
final dioProvider = Provider<Dio>((ref) {
  final store = ref.watch(tokenStoreProvider);
  final authApi = ref.watch(authApiProvider);
  return buildDio(
    tokenStore: store,
    reissue: authApi.reissue,
    // ref.read를 콜백 안에서 늦게 부르는 것이 순환 의존을 끊는다.
    onSessionExpired: () =>
        ref.read(authControllerProvider.notifier).handleSessionExpired(),
  );
});

// ---------- 리포지토리 ----------

final cacheSessionProvider = Provider<CacheSession>((ref) => CacheSession());

final referenceRepositoryProvider = Provider<ReferenceRepository>((ref) =>
    ReferenceRepository(
      session: ref.watch(cacheSessionProvider),
      api: ReferenceApi(ref.watch(dioProvider)),
      db: ref.watch(appDatabaseProvider),
    ));

final coursesRepositoryProvider = Provider<CoursesRepository>((ref) =>
    CoursesRepository(
      session: ref.watch(cacheSessionProvider),
      api: CoursesApi(ref.watch(dioProvider)),
      db: ref.watch(appDatabaseProvider),
    ));

final assignmentsRepositoryProvider = Provider<AssignmentsRepository>((ref) =>
    AssignmentsRepository(
      session: ref.watch(cacheSessionProvider),
      api: CalendarApi(ref.watch(dioProvider)),
      canvas: ref.watch(canvasApiProvider),
      db: ref.watch(appDatabaseProvider),
    ));

final announcementsRepositoryProvider = Provider<AnnouncementsRepository>((ref) =>
    AnnouncementsRepository(
      session: ref.watch(cacheSessionProvider),
      api: AnnouncementsApi(ref.watch(dioProvider)),
      canvas: ref.watch(canvasApiProvider),
      db: ref.watch(appDatabaseProvider),
    ));

// ---------- 상태 ----------

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);

/// 화면에서 고른 학기. null이면 아직 결정 전이다.
final selectedTermIdProvider = StateProvider<int?>((ref) => null);

// ---------- Canvas (강좌 상세 탭) ----------

/// Canvas 세션 쿠키 보관소. 브릿지용 dio와 API용 dio가 함께 쓴다.
final canvasCookieJarProvider = Provider<CookieJar>((ref) => CookieJar());

/// 브릿지 전용 dio. 세션 인터셉터가 없어야 재브릿지가 스스로를 다시 부르지 않는다.
final canvasBridgeDioProvider = Provider<Dio>(
  (ref) => buildCanvasDio(ref.watch(canvasCookieJarProvider)),
);

final samlBridgeApiProvider =
    Provider<SamlBridgeApi>((ref) => SamlBridgeApi(ref.watch(dioProvider)));

final canvasSessionProvider = Provider<CanvasSession>((ref) {
  final bridge = ref.watch(samlBridgeApiProvider);
  return CanvasSession(
    dio: ref.watch(canvasBridgeDioProvider),
    jar: ref.watch(canvasCookieJarProvider),
    fetchSsoUrl: bridge.fetchSsoUrl,
    loginId: () async {
      final auth = ref.read(authControllerProvider).valueOrNull;
      return auth is AuthAuthenticated ? auth.profile.loginId : null;
    },
  );
});

/// Canvas REST API용 dio. 첫 요청 전에 다리를 건너고, 401이면 다시 건넌다.
final canvasDioProvider = Provider<Dio>((ref) {
  final dio = buildCanvasDio(ref.watch(canvasCookieJarProvider))
    ..options.baseUrl = Env.canvasApiBaseUrl;
  final session = ref.watch(canvasSessionProvider);
  // 반드시 CookieManager보다 앞에 둔다. 뒤에 두면 첫 요청에서 쿠키 매니저가
  // 아직 비어 있는 저장소를 읽은 뒤에야 브릿지가 돌아, 세션 쿠키 없이 요청이
  // 나가고 Canvas가 강좌를 404로 숨긴다.
  dio.interceptors.insert(
      0,
      canvasSessionInterceptor(
    dio: dio,
    ensureSession: session.ensure,
    reBridge: () async {
      session.invalidate();
      await session.ensure();
    },
  ));
  return dio;
});

final canvasApiProvider =
    Provider<CanvasApi>((ref) => CanvasApi(ref.watch(canvasDioProvider)));

/// 콘텐츠 유무와 관계없이 모든 강좌에 같은 순서로 노출한다.
final courseTabsProvider =
    FutureProvider.family<List<CourseTab>, int>((ref, courseId) async {
  return fixedCourseTabs;
});

final canvasCacheProvider =
    Provider<CanvasCache>((ref) => CanvasCache(ref.watch(appDatabaseProvider)));

final canvasDownloaderProvider = Provider<CanvasDownloader>(
  (ref) => CanvasDownloader(ref.watch(canvasDioProvider)),
);
