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
}
