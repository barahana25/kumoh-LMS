import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/auth/presentation/auth_controller.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_api.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_service.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_store.dart';
import 'package:kumoh_lms/providers.dart';

import '../../fixtures/fixtures.dart';
import '../../helpers/test_db.dart';

/// 실제 [CanvasTokenService] 대신 어떤 발급 메서드가 불렸는지만 기록한다.
/// ensure()는 있는 토큰을 재사용하고, issueFresh()는 세션 번호를 올려
/// 항상 새로 발급한다 — 복원 세션과 새 로그인이 서로 다른 메서드를 써야
/// 하므로, 실제 네트워크/보관소 없이 "어느 쪽을 불렀는가"만 검증한다.
class _RecordingTokenService extends CanvasTokenService {
  _RecordingTokenService()
      : super(
          api: CanvasTokenApi(Dio(), CookieJar()),
          store: InMemoryCanvasTokenStore(),
          ensureSession: () async {},
          platformLabel: 'test',
        );

  final List<String> calls = [];

  @override
  Future<String?> ensure() async {
    calls.add('ensure');
    return null;
  }

  @override
  Future<String?> issueFresh() async {
    calls.add('issueFresh');
    return null;
  }
}

class _HeaderProbe implements HttpClientAdapter {
  _HeaderProbe(this.onHeader);
  final void Function(String?) onHeader;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onHeader(options.headers['Authorization'] as String?);
    return ResponseBody.fromString('{}', 200, headers: {
      'content-type': ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('토큰 서비스와 보관소가 배선돼 있다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(canvasTokenStoreProvider), isA<CanvasTokenStore>());
    expect(container.read(canvasTokenServiceProvider), isA<CanvasTokenService>());
  });

  test('토큰 보관소는 앱 전체가 같은 인스턴스를 쓴다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      identical(container.read(canvasTokenStoreProvider),
          container.read(canvasTokenStoreProvider)),
      isTrue,
    );
  });

  test('Canvas dio는 토큰이 있으면 Bearer를 붙인다', () async {
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~abc', id: 1, purpose: '금오LMS 앱 · Android · a3f9'));
    final container = ProviderContainer(overrides: [
      canvasTokenStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);

    final dio = container.read(canvasDioProvider);
    // 인터셉터가 요청 직전에 토큰을 읽는다. 어댑터를 바꿔 헤더만 확인한다.
    String? seen;
    dio.httpClientAdapter = _HeaderProbe((value) => seen = value);
    await dio.get<dynamic>('/users/self');

    expect(seen, 'Bearer 7~abc');
  });

  test('로그아웃하면 저장된 Canvas 토큰이 사라진다', () async {
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~abc', id: 1, purpose: '금오LMS 앱 · Android · a3f9'));
    final container = ProviderContainer(overrides: [
      canvasTokenStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);

    await container.read(canvasTokenServiceProvider).revoke();

    expect(await store.read(), isNull);
  });

  group('인증 경로별 발급 배선', () {
    // AuthController가 인증에 성공하는 세 경로(콜드 스타트 복원, 자동 로그인,
    // 대화형 로그인) 중 login()에서만 발급을 걸면, 자동 로그인을 켠 기존
    // 사용자는 앱을 업데이트해도 로그인 화면을 다시 보지 않는 한 영영
    // Canvas 토큰을 받지 못하고 쿠키 경로에 남는다.
    late InMemoryTokenStore tokenStore;
    late AppDatabase db;
    late Dio authDio;
    late DioAdapter authAdapter;
    late _RecordingTokenService tokens;

    ProviderContainer build() => ProviderContainer(overrides: [
          tokenStoreProvider.overrideWithValue(tokenStore),
          appDatabaseProvider.overrideWithValue(db),
          authDioProvider.overrideWithValue(authDio),
          dioProvider.overrideWithValue(authDio),
          canvasTokenServiceProvider.overrideWithValue(tokens),
        ]);

    setUp(() {
      tokenStore = InMemoryTokenStore();
      db = createTestDatabase();
      authDio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
      authAdapter = DioAdapter(dio: authDio);
      tokens = _RecordingTokenService();
    });

    tearDown(() => db.close());

    test('저장된 refreshToken으로 되살아난 세션은 ensure()로 있는 토큰을 챙긴다', () async {
      // 같은 사용자, 같은 기기다. issueFresh()를 쓰면 콜드 스타트마다 멀쩡한
      // 토큰을 버리고 Canvas 계정에 새 토큰을 쌓는다.
      await tokenStore.saveTokens(accessToken: 'old', refreshToken: 'oldRefresh');
      authAdapter.onPost(
        '/reissue',
        (s) => s.reply(200, {
          'code': '200',
          'message': 'Success',
          'data': {'accessToken': 'newAccess', 'refreshToken': 'newRefresh'},
        }),
        headers: {'X-Refresh-Token': 'oldRefresh'},
      );
      authAdapter.onGet('/user/profile', (s) => s.reply(200, userProfileJson));

      final container = build();
      addTearDown(container.dispose);
      final state = await container.read(authControllerProvider.future);

      expect(state, isA<AuthAuthenticated>());
      expect(tokens.calls, ['ensure'],
          reason: '복원된 세션은 발급을 정확히 한 번, ensure()로만 해야 한다');
    });

    test('대화형 로그인은 issueFresh()로 깨끗한 토큰에서 시작한다', () async {
      // 로그인은 계정이 바뀔 수 있는 지점이다. 이전 사용자(또는 이전 세션)
      // 토큰을 이어받지 않도록 항상 새로 발급해야 한다.
      authAdapter.onPost('/login', (s) => s.reply(200, loginSuccessJson),
          data: {'userId': '20250000', 'password': 'pw'});
      authAdapter.onGet('/user/profile', (s) => s.reply(200, userProfileJson));

      final container = build();
      addTearDown(container.dispose);
      // 초기 복원: 토큰도 자격증명도 없어 발급이 일어나지 않는다.
      await container.read(authControllerProvider.future);
      expect(tokens.calls, isEmpty);

      await container.read(authControllerProvider.notifier).login(
            userId: '20250000',
            password: 'pw',
            rememberMe: false,
          );

      expect(tokens.calls, ['issueFresh'],
          reason: '대화형 로그인은 발급을 정확히 한 번, issueFresh()로만 해야 한다');
    });
  });
}
