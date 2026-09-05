import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/auth/presentation/auth_controller.dart';
import 'package:kumoh_lms/providers.dart';

import '../../fixtures/fixtures.dart';
import '../../helpers/test_db.dart';

void main() {
  late InMemoryTokenStore store;
  late AppDatabase db;
  late Dio authDio;
  late DioAdapter authAdapter;
  late ProviderContainer container;

  ProviderContainer makeContainer() => ProviderContainer(overrides: [
        tokenStoreProvider.overrideWithValue(store),
        appDatabaseProvider.overrideWithValue(db),
        authDioProvider.overrideWithValue(authDio),
      ]);

  setUp(() {
    store = InMemoryTokenStore();
    db = createTestDatabase();
    authDio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    authAdapter = DioAdapter(dio: authDio);
    container = makeContainer();
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  test('토큰이 없으면 초기 상태는 미인증이다', () async {
    final state = await container.read(authControllerProvider.future);
    expect(state, isA<AuthUnauthenticated>());
  });

  test('로그인 성공 시 토큰을 저장하고 인증 상태가 된다', () async {
    authAdapter.onPost('/login', (s) => s.reply(200, loginSuccessJson),
        data: {'userId': '20250000', 'password': 'pw'});
    authAdapter.onGet('/user/profile', (s) => s.reply(200, userProfileJson));

    await container.read(authControllerProvider.future);
    await container.read(authControllerProvider.notifier).login(
          userId: '20250000',
          password: 'pw',
          rememberMe: false,
        );

    final state = container.read(authControllerProvider).value;
    expect(state, isA<AuthAuthenticated>());
    expect((state! as AuthAuthenticated).profile.name, '홍길동');
    expect(await store.readAccessToken(), 'header.accessPayload.sig');
    expect(await store.readRefreshToken(), 'header.refreshPayload.sig');
  });

  test('rememberMe가 false면 자격증명을 저장하지 않는다', () async {
    authAdapter.onPost('/login', (s) => s.reply(200, loginSuccessJson),
        data: {'userId': '20250000', 'password': 'pw'});
    authAdapter.onGet('/user/profile', (s) => s.reply(200, userProfileJson));

    await container.read(authControllerProvider.future);
    await container.read(authControllerProvider.notifier).login(
          userId: '20250000',
          password: 'pw',
          rememberMe: false,
        );

    expect(await store.readCredentials(), isNull);
  });

  test('로그인 후 프로필 조회에는 회전된 토큰 두 개를 붙인다', () async {
    final requests = <RequestOptions>[];
    authDio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      requests.add(o);
      h.next(o);
    }));
    authAdapter.onPost('/login', (s) => s.reply(200, loginSuccessJson),
        data: {'userId': '20250000', 'password': 'pw'});
    authAdapter.onGet('/user/profile', (s) => s.reply(200, userProfileJson));
    await container.read(authControllerProvider.future);
    await container.read(authControllerProvider.notifier).login(
      userId: '20250000', password: 'pw', rememberMe: false,
    );
    final profileRequest = requests.singleWhere((o) => o.path == '/user/profile');
    expect(profileRequest.headers['Authorization'], 'Bearer header.accessPayload.sig');
    expect(profileRequest.headers['X-Refresh-Token'], 'header.refreshPayload.sig');
  });

  test('오프라인 재시작은 기존 토큰과 캐시를 유지한다', () async {
    await store.saveTokens(accessToken: 'old', refreshToken: 'oldRefresh');
    await db.cacheMetaDao.touch('courses:8');
    authAdapter.onPost('/reissue', (s) => s.throws(0, DioException(
      requestOptions: RequestOptions(path: '/reissue'),
      type: DioExceptionType.connectionError,
    )));
    final state = await container.read(authControllerProvider.future);
    expect(state, isA<AuthOffline>());
    expect(await store.readRefreshToken(), 'oldRefresh');
    expect(await db.cacheMetaDao.fetchedAt('courses:8'), isNotNull);
  });

  test('서버가 세션을 거부하면 오프라인 상태로 인증을 우회하지 않는다', () async {
    await store.saveTokens(accessToken: 'old', refreshToken: 'oldRefresh');
    authAdapter.onPost('/reissue', (s) => s.reply(401, springAuthErrorJson));
    expect(await container.read(authControllerProvider.future), isA<AuthUnauthenticated>());
    expect(await store.readRefreshToken(), isNull);
  });

  test('rememberMe가 true면 자격증명을 저장한다', () async {
    authAdapter.onPost('/login', (s) => s.reply(200, loginSuccessJson),
        data: {'userId': '20250000', 'password': 'pw'});
    authAdapter.onGet('/user/profile', (s) => s.reply(200, userProfileJson));

    await container.read(authControllerProvider.future);
    await container.read(authControllerProvider.notifier).login(
          userId: '20250000',
          password: 'pw',
          rememberMe: true,
        );

    expect((await store.readCredentials())?.userId, '20250000');
  });

  test('로그인 실패는 에러 상태가 되고 토큰을 저장하지 않는다', () async {
    authAdapter.onPost(
      '/login',
      (s) => s.reply(200, {
        'code': 'U001',
        'message': '아이디 또는 비밀번호가 올바르지 않습니다.',
        'data': null,
      }),
      data: {'userId': '20250000', 'password': 'wrong'},
    );

    await container.read(authControllerProvider.future);
    await container.read(authControllerProvider.notifier).login(
          userId: '20250000',
          password: 'wrong',
          rememberMe: false,
        );

    expect(container.read(authControllerProvider).hasError, isTrue);
    expect(await store.readAccessToken(), isNull);
  });

  test('저장된 refreshToken이 있으면 재발급으로 세션을 복원한다', () async {
    await store.saveTokens(accessToken: 'old', refreshToken: 'oldRefresh');
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

    final state = await makeContainer().read(authControllerProvider.future);

    expect(state, isA<AuthAuthenticated>());
    expect(await store.readAccessToken(), 'newAccess');
  });

  test('로그아웃은 토큰·자격증명·캐시를 모두 비운다', () async {
    await store.saveTokens(accessToken: 'a', refreshToken: 'r');
    await store.saveCredentials(userId: '20250000', password: 'pw');
    await db.cacheMetaDao.touch('courses:8');
    authAdapter.onPost('/logout', (s) => s.reply(200, {'code': '200', 'message': 'Success', 'data': null}));

    await container.read(authControllerProvider.notifier).logout();

    expect(await store.readAccessToken(), isNull);
    expect(await store.readCredentials(), isNull);
    expect(await db.cacheMetaDao.fetchedAt('courses:8'), isNull);
    expect(container.read(authControllerProvider).value, isA<AuthUnauthenticated>());
  });

  // --- Task 11 요구사항: handleSessionExpired()는 single-flight여야 한다 ---
  //
  // AuthInterceptor는 만료된 토큰으로 대기 중이던 요청들이 재발급마저 실패하면
  // 각자 독립적으로 onSessionExpired (-> handleSessionExpired)를 호출할 수 있다.
  // 이 함수가 idempotent/single-flight가 아니면 동시에 쌓인 N개의 요청이
  // 학교 서버에 N번의 동시 로그인을 발생시켜 계정이 잠길 수 있다.
  // 그래서 동시에 여러 번 호출해도 진행 중인 복구 하나를 공유해야 하고,
  // 실제로 서버에 도달하는 로그인 시도는 정확히 1회여야 한다.
  test(
    'handleSessionExpired은 동시에 여러 번 호출돼도 로그인 시도를 한 번만 한다 (single-flight)',
    () async {
      // 초기 복원: 토큰도 자격증명도 없는 상태라 미인증으로 끝난다.
      final initial = await container.read(authControllerProvider.future);
      expect(initial, isA<AuthUnauthenticated>());

      // 자동 로그인이 켜진 상태를 만든다 (자격증명이 저장돼 있음).
      await store.saveCredentials(userId: '20250000', password: 'pw');

      var loginCalls = 0;
      authAdapter.onPost(
        '/login',
        (s) => s.replyCallback(
          200,
          (options) {
            loginCalls++;
            return loginSuccessJson;
          },
          // 지연을 둬서 여러 handleSessionExpired() 호출이 실제로 겹치게 만든다.
          delay: const Duration(milliseconds: 30),
        ),
        data: {'userId': '20250000', 'password': 'pw'},
      );
      authAdapter.onGet('/user/profile', (s) => s.reply(200, userProfileJson));

      final notifier = container.read(authControllerProvider.notifier);

      // AuthInterceptor가 실제로 겪을 수 있는 상황: 만료된 토큰으로 대기하던
      // 여러 요청이 거의 동시에 onSessionExpired를 호출한다.
      await Future.wait([
        notifier.handleSessionExpired(),
        notifier.handleSessionExpired(),
        notifier.handleSessionExpired(),
        notifier.handleSessionExpired(),
        notifier.handleSessionExpired(),
      ]);

      expect(
        loginCalls,
        1,
        reason: '동시 호출은 하나의 진행 중인 복구를 공유해야 한다. '
            'single-flight 보호가 없으면 N번의 동시 로그인 시도가 발생한다.',
      );

      final state = container.read(authControllerProvider).value;
      expect(state, isA<AuthAuthenticated>());
    },
  );

  test('앞선 복구가 끝난 뒤의 새 만료는 다시 복구를 시도한다', () async {
    // single-flight 가드가 완료 후 풀리지 않으면 이후 만료가 영원히 무시된다.
    await store.saveCredentials(userId: '20250000', password: 'pw');
    // onPost 콜백은 등록 시점에 1회만 실행된다. 실제 요청 수는 인터셉터로 센다.
    var loginCalls = 0;
    authDio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      if (o.path == '/login') loginCalls++;
      h.next(o);
    }));
    authAdapter.onPost('/login', (s) => s.reply(200, loginSuccessJson),
        data: {'userId': '20250000', 'password': 'pw'});
    authAdapter.onPost('/reissue', (s) => s.reply(401, springAuthErrorJson));
    authAdapter.onGet('/user/profile', (s) => s.reply(200, userProfileJson));

    final notifier = container.read(authControllerProvider.notifier);
    // build()의 최초 세션 복원도 로그인을 한 번 쓰므로, 절대값이 아니라
    // 만료 처리 전후의 증분을 본다.
    await container.read(authControllerProvider.future);
    final base = loginCalls;

    await notifier.handleSessionExpired();
    final afterFirst = loginCalls;
    await notifier.handleSessionExpired();

    expect(afterFirst - base, 1, reason: '첫 만료가 복구되어야 한다');
    expect(loginCalls - afterFirst, 1,
        reason: 'single-flight 가드가 완료 후 풀려 다음 만료도 복구되어야 한다');
  });

  test('로그아웃 중 저장소가 실패해도 세션은 종료된다', () async {
    await store.saveTokens(accessToken: 'a', refreshToken: 'r');
    authAdapter.onPost('/logout',
        (s) => s.reply(200, {'code': '200', 'message': 'Success', 'data': null}));

    final failing = _ThrowingClearAllStore(store);
    final c = ProviderContainer(overrides: [
      tokenStoreProvider.overrideWithValue(failing),
      appDatabaseProvider.overrideWithValue(db),
      authDioProvider.overrideWithValue(authDio),
    ]);
    addTearDown(c.dispose);

    await expectLater(
      c.read(authControllerProvider.notifier).logout(),
      throwsA(anything),
    );
    expect(c.read(authControllerProvider).value, isA<AuthUnauthenticated>(),
        reason: '실패해도 로그인 화면으로 갈 수 있어야 한다');
  });

  test('자동 로그인 중 네트워크가 끊겨도 자격증명을 지우지 않는다', () async {
    // 지하철·엘리베이터에서 재발급이 끊기는 상황. 여기서 자격증명을 지우면
    // 자동 로그인이 영구히 꺼지고 캐시까지 못 보게 된다.
    await store.saveCredentials(userId: '20250000', password: 'pw');
    await store.saveTokens(accessToken: 'a', refreshToken: 'r');
    authAdapter.onPost(
      '/reissue',
      (s) => s.throws(
        0,
        DioException(
          requestOptions: RequestOptions(path: '/reissue'),
          type: DioExceptionType.connectionError,
        ),
      ),
    );
    authAdapter.onPost(
      '/login',
      (s) => s.throws(
        0,
        DioException(
          requestOptions: RequestOptions(path: '/login'),
          type: DioExceptionType.connectionError,
        ),
      ),
      data: {'userId': '20250000', 'password': 'pw'},
    );

    final state = await makeContainer().read(authControllerProvider.future);

    expect(state, isA<AuthOffline>(), reason: '캐시를 열어야 한다');
    expect(
      (await store.readCredentials())?.userId,
      '20250000',
      reason: '네트워크 장애로 저장된 비밀번호를 지우면 안 된다',
    );
  });

  test('서버 점검(5xx)으로 재발급이 실패해도 토큰을 지키고 캐시를 연다', () async {
    await store.saveTokens(accessToken: 'a', refreshToken: 'r');
    authAdapter.onPost(
      '/reissue',
      (s) => s.reply(503, {
        'timestamp': 'x',
        'status': 503,
        'error': 'Service Unavailable',
        'path': '/reissue',
      }),
    );

    final state = await makeContainer().read(authControllerProvider.future);

    expect(state, isA<AuthOffline>());
    expect(
      await store.readRefreshToken(),
      'r',
      reason: '점검 중 콜드 스타트 한 번에 재로그인을 강요하면 안 된다',
    );
  });
}

/// clearAll이 실패하는 저장소(기기 보안 저장소 장애 재현).
class _ThrowingClearAllStore implements TokenStore {
  _ThrowingClearAllStore(this._inner);
  final TokenStore _inner;

  @override
  Future<void> clearAll() async => throw StateError('keystore unavailable');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Function.apply(_delegate(invocation), null);

  Function _delegate(Invocation i) => () => throw UnimplementedError();

  @override
  Future<String?> readAccessToken() => _inner.readAccessToken();
  @override
  Future<String?> readRefreshToken() => _inner.readRefreshToken();
  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) =>
      _inner.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
  @override
  Future<void> clearTokens() => _inner.clearTokens();
  @override
  Future<String> ensureDbKey() => _inner.ensureDbKey();
  @override
  Future<void> saveCredentials({required String userId, required String password}) =>
      _inner.saveCredentials(userId: userId, password: password);
  @override
  Future<Credentials?> readCredentials() => _inner.readCredentials();
  @override
  Future<void> clearCredentials() => _inner.clearCredentials();
}
