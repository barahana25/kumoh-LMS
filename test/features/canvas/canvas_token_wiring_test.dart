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

    test('handleSessionExpired()의 조용한 세션 복구는 ensure()로 이어진다, '
        'issueFresh()가 아니라', () async {
      // LINUS 세션이 끊겨(다른 기기 로그인 등) AuthInterceptor가
      // handleSessionExpired()를 부르는 상황이다. 자동 로그인이 켜져
      // 있으면 저장된 자격증명으로 조용히 다시 로그인하는데, 이 경로가
      // issueFresh()를 쓰면 멀쩡한 Canvas 토큰을 매번 버리고 SAML 다리를
      // 다시 타야 한다 — 다리가 마침 실패하면 쿠키 폴백으로 떨어진다.
      // 정확히 Canvas 토큰이 살아남아야 하는 시나리오라 ensure()여야 한다.
      await tokenStore.saveCredentials(userId: '20250000', password: 'pw');
      authAdapter.onPost('/login', (s) => s.reply(200, loginSuccessJson),
          data: {'userId': '20250000', 'password': 'pw'});
      authAdapter.onGet('/user/profile', (s) => s.reply(200, userProfileJson));

      final container = build();
      addTearDown(container.dispose);
      // 콜드 스타트도 자동 로그인을 거쳐 ensure()를 한 번 부른다.
      // handleSessionExpired()만 따로 보기 위해 그 기록은 비운다.
      await container.read(authControllerProvider.future);
      tokens.calls.clear();

      await container
          .read(authControllerProvider.notifier)
          .handleSessionExpired();

      expect(tokens.calls, ['ensure'],
          reason: '세션 만료 후 조용한 재로그인은 발급을 정확히 한 번, '
              'ensure()로만 해야 한다');
    });
  });

  group('ensure() 발급이 인증 상태가 확정된 뒤에 실행된다 (순서 보장)', () {
    // ensure()/issueFresh()는 CanvasSession을 거쳐 canvasIdentityTokenProvider를
    // 부르는데, 그 클로저는 ref.read(authControllerProvider).valueOrNull로
    // 인증 여부를 가른다. build()가 아직 실행 중이면(state가 AsyncLoading)
    // 이 값은 null이라, 방금 인증에 성공했는데도 SAML 다리가 신원 토큰을
    // 못 구해 조용히 포기한다.
    //
    // _RecordingTokenService 같은 스텁은 canvasIdentityTokenProvider를 아예
    // 부르지 않아 이 경합을 표현할 수 없다. 아래 테스트들은 진짜
    // CanvasTokenService.ensure()/issueFresh()를 끝까지 실행시켜, 그 안에서
    // canvasIdentityTokenProvider가 실제로 무엇을 읽었는지(seenIdentityToken)
    // 관측한다 — AuthController.build()의 listenSelf 게이팅이 없다면 이
    // 값이 null로 관측될 수 있는 지점이다. (참고: 이 스위트의 인메모리
    // 저장소·모킹된 HTTP는 실제 보안 저장소보다 훨씬 빨라, 이 특정
    // 조합에서는 게이팅이 없어도 우연히 순서가 맞아떨어지는 것을 확인했다
    // — 그래도 이 테스트는 스텁이 아닌 실제 경로가 항상 확정된 인증
    // 상태만 보고 동작한다는 것을 계속 지켜준다.)
    late InMemoryTokenStore tokenStore;
    late AppDatabase db;
    late Dio authDio;
    late DioAdapter authAdapter;

    setUp(() {
      tokenStore = InMemoryTokenStore();
      db = createTestDatabase();
      authDio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
      authAdapter = DioAdapter(dio: authDio);
    });

    tearDown(() => db.close());

    test('콜드 스타트 복원이 끝난 뒤에야 신원 토큰을 읽는다', () async {
      await tokenStore.saveTokens(
          accessToken: 'old', refreshToken: 'oldRefresh');
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

      late ProviderContainer container;
      var ensureSessionCalls = 0;
      String? seenIdentityToken;
      final realService = CanvasTokenService(
        api: _StubTokenApi(),
        store: InMemoryCanvasTokenStore(),
        // CanvasSession.fetchSamlForm이 다리를 건너기 전에 가장 먼저 하는
        // 일과 같다: canvasIdentityTokenProvider로 신원 토큰부터 읽는다.
        // build()가 state를 확정하기 전에 ensure()가 여기까지 왔다면
        // AuthController가 아직 AsyncLoading이라 null이 관측된다.
        ensureSession: () async {
          ensureSessionCalls++;
          seenIdentityToken =
              await container.read(canvasIdentityTokenProvider)();
        },
        platformLabel: 'test',
      );

      container = ProviderContainer(overrides: [
        tokenStoreProvider.overrideWithValue(tokenStore),
        appDatabaseProvider.overrideWithValue(db),
        authDioProvider.overrideWithValue(authDio),
        dioProvider.overrideWithValue(authDio),
        canvasTokenServiceProvider.overrideWithValue(realService),
      ]);
      addTearDown(container.dispose);

      final state = await container.read(authControllerProvider.future);
      expect(state, isA<AuthAuthenticated>());

      // 발급은 unawaited다. ensureSession이 실행될 때까지 이벤트 루프를
      // 흘려보낸다.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(ensureSessionCalls, 1);
      expect(seenIdentityToken, 'newAccess',
          reason: 'build()가 state를 확정하기 전에 ensure()가 인증 상태를 '
              '읽으면 null이 관측된다 — 순서 보장이 깨졌다는 뜻이다');
    });

    test('대화형 로그인이 state에 커밋된 뒤에야 신원 토큰을 읽는다', () async {
      // login() 경로도 같은 방식으로 검증한다: issueFresh()가 실제로
      // 실행될 때 canvasIdentityTokenProvider가 관측하는 인증 상태가
      // 항상 확정된 값이어야 한다.
      authAdapter.onPost('/login', (s) => s.reply(200, loginSuccessJson),
          data: {'userId': '20250000', 'password': 'pw'});
      authAdapter.onGet('/user/profile', (s) => s.reply(200, userProfileJson));

      late ProviderContainer container;
      var ensureSessionCalls = 0;
      String? seenIdentityToken;
      final realService = CanvasTokenService(
        api: _StubTokenApi(),
        store: InMemoryCanvasTokenStore(),
        ensureSession: () async {
          ensureSessionCalls++;
          seenIdentityToken =
              await container.read(canvasIdentityTokenProvider)();
        },
        platformLabel: 'test',
      );

      container = ProviderContainer(overrides: [
        tokenStoreProvider.overrideWithValue(tokenStore),
        appDatabaseProvider.overrideWithValue(db),
        authDioProvider.overrideWithValue(authDio),
        dioProvider.overrideWithValue(authDio),
        canvasTokenServiceProvider.overrideWithValue(realService),
      ]);
      addTearDown(container.dispose);

      // 초기 복원: 토큰도 자격증명도 없어 미인증으로 끝난다.
      await container.read(authControllerProvider.future);

      await container.read(authControllerProvider.notifier).login(
            userId: '20250000',
            password: 'pw',
            rememberMe: false,
          );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(ensureSessionCalls, 1);
      expect(seenIdentityToken, 'header.accessPayload.sig',
          reason: 'state가 커밋되기 전에 issueFresh()가 인증 상태를 읽으면 '
              'null이 관측된다 — 순서 보장이 깨졌다는 뜻이다');
    });
  });
}

/// [CanvasTokenService.ensure]가 SAML 다리를 성공한 것처럼 진행하도록,
/// 생성·삭제에 최소한으로만 응답하는 가짜.
class _StubTokenApi implements CanvasTokenApi {
  @override
  Future<IssuedCanvasToken> create(String purpose) async =>
      IssuedCanvasToken(id: 1, token: '7~stub', purpose: purpose);

  @override
  Future<void> delete(int id) async {}
}
