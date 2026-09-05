import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/core/network/auth_interceptor.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/features/auth/data/auth_dto.dart';

// Dio 5.x는 인터셉터가 handler.reject로 던진 에러를 항상 DioException으로 감싸서
// fetch() 바깥으로 내보낸다(dio_mixin.dart의 assureDioException — 이미
// DioException이면 그대로 반환하고, 아니면 새로 감싼다. 어느 쪽이든 최종적으로
// 던져지는 값은 항상 DioException이다). 그래서 AuthInterceptor가 세션 만료를
// 표현하려고 실어 보낸 AuthFailure는 DioException.error 안에 들어 있고,
// dio.get(...) 호출부에서 직접 AuthFailure가 튀어나오는 일은 없다.
// 따라서 원인이 AuthFailure인지는 DioException을 열어서 확인해야 한다.
final Matcher _throwsAuthFailure = throwsA(
  isA<DioException>().having((e) => e.error, 'error', isA<AuthFailure>()),
);

/// 응답을 대본대로 돌려주는 최소 어댑터.
/// 경로별로 응답 큐를 넣어두면 호출 순서대로 하나씩 꺼내 준다.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.script);

  final Map<String, List<int>> script;
  final List<RequestOptions> received = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    received.add(options);
    final queue = script[options.path];
    if (queue == null || queue.isEmpty) {
      return ResponseBody.fromString('{"code":"200","message":"Success","data":{}}', 200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          });
    }
    final status = queue.removeAt(0);
    if (status == 204) {
      return ResponseBody.fromString('', 204);
    }
    return ResponseBody.fromString('{"code":"200","message":"Success","data":{"ok":true}}', status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}
}

/// [InMemoryTokenStore]를 감싸 readRefreshToken()에 실제 지연(Future.delayed)을
/// 추가한 페이크. Finding 1 회귀 테스트 전용: InMemoryTokenStore의
/// readRefreshToken()은 마이크로태스크 한 틱 만에 끝나서 check-then-act
/// 경쟁을 드러내지 못한다. 실제 타이머 지연을 넣어야 "_refreshing 체크는
/// 통과했지만 아직 플래그를 세우지 않은" 구간이 여러 요청에 걸쳐 실제로
/// 겹치게 만들 수 있다.
class _DelayedRefreshTokenStore implements TokenStore {
  _DelayedRefreshTokenStore(this._inner, this.delay);

  final TokenStore _inner;
  final Duration delay;

  @override
  Future<String?> readAccessToken() => _inner.readAccessToken();

  @override
  Future<String?> readRefreshToken() async {
    await Future<void>.delayed(delay);
    return _inner.readRefreshToken();
  }

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

  @override
  Future<void> clearAll() => _inner.clearAll();
}

/// [InMemoryTokenStore]를 감싸 지정한 호출 번째(1-based)에서 한 번만
/// 예외(PlatformException)를 던지는 페이크. Issue 1 회귀 테스트 전용:
/// 운영 구현인 SecureTokenStore는 flutter_secure_storage 위에서 동작하므로
/// 플랫폼 채널 오류(키스토어/키체인 실패)로 readRefreshToken()/saveTokens()가
/// 언제든 던질 수 있다. 어느 호출에서 던질지는 呼출 순번으로 지정한다 —
/// onRequest가 매 요청마다 readRefreshToken()을 한 번 먼저 호출하므로,
/// _recover 내부에서 발생하는 호출과 호출 순번이 다르다.
class _FaultyTokenStore implements TokenStore {
  _FaultyTokenStore(this._inner, {this.throwReadOnCall, this.throwSaveOnCall});

  final TokenStore _inner;
  final int? throwReadOnCall;
  final int? throwSaveOnCall;
  int readCalls = 0;
  int saveCalls = 0;

  @override
  Future<String?> readAccessToken() => _inner.readAccessToken();

  @override
  Future<String?> readRefreshToken() async {
    readCalls++;
    if (throwReadOnCall != null && readCalls == throwReadOnCall) {
      throw PlatformException(code: 'read_error', message: 'keystore read failed');
    }
    return _inner.readRefreshToken();
  }

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    saveCalls++;
    if (throwSaveOnCall != null && saveCalls == throwSaveOnCall) {
      throw PlatformException(code: 'write_error', message: 'keystore write failed');
    }
    return _inner.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

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

  @override
  Future<void> clearAll() => _inner.clearAll();
}

void main() {
  late InMemoryTokenStore store;
  late Dio dio;
  late _ScriptedAdapter adapter;
  late int reissueCalls;
  late int sessionExpiredCalls;

  /// [script] 는 경로별 응답 상태코드 큐.
  Future<void> setUpDio({
    required Map<String, List<int>> script,
    required Future<AuthTokens> Function(String refresh) reissue,
  }) async {
    store = InMemoryTokenStore();
    await store.saveTokens(accessToken: 'oldAccess', refreshToken: 'oldRefresh');
    reissueCalls = 0;
    sessionExpiredCalls = 0;

    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    adapter = _ScriptedAdapter(script);
    dio.httpClientAdapter = adapter;

    dio.interceptors.add(AuthInterceptor(
      tokenStore: store,
      reissue: (refresh) async {
        reissueCalls++;
        return reissue(refresh);
      },
      onSessionExpired: () async {
        sessionExpiredCalls++;
      },
      retryClient: dio,
    ));
  }

  test('요청에 Authorization과 X-Refresh-Token을 모두 붙인다', () async {
    await setUpDio(
      script: {'/courses': [200]},
      reissue: (_) async => const AuthTokens(accessToken: 'a', refreshToken: 'r'),
    );

    await dio.get<Object?>('/courses');

    final sent = adapter.received.single;
    expect(sent.headers['Authorization'], 'Bearer oldAccess');
    expect(sent.headers['X-Refresh-Token'], 'oldRefresh');
  });

  test('204를 받으면 재발급 후 새 토큰으로 원요청을 재시도한다', () async {
    await setUpDio(
      script: {'/courses': [204, 200]},
      reissue: (_) async => const AuthTokens(accessToken: 'newAccess', refreshToken: 'newRefresh'),
    );

    final res = await dio.get<Object?>('/courses');

    expect(res.statusCode, 200);
    expect(reissueCalls, 1);
    // 첫 요청 + 재시도 = 2회
    expect(adapter.received.length, 2);
    expect(adapter.received.last.headers['Authorization'], 'Bearer newAccess');
    // 회전된 토큰이 저장됐다
    expect(await store.readAccessToken(), 'newAccess');
    expect(await store.readRefreshToken(), 'newRefresh');
  });

  test('401도 재발급 트리거로 동작한다', () async {
    await setUpDio(
      script: {'/courses': [401, 200]},
      reissue: (_) async => const AuthTokens(accessToken: 'newAccess', refreshToken: 'newRefresh'),
    );

    final res = await dio.get<Object?>('/courses');

    expect(res.statusCode, 200);
    expect(reissueCalls, 1);
  });

  test('재발급이 실패하면 세션을 비우고 AuthFailure를 던진다', () async {
    await setUpDio(
      script: {'/courses': [204]},
      reissue: (_) async => throw const ServerFailure(code: 'U004', message: 'bad refresh'),
    );

    await expectLater(
      dio.get<Object?>('/courses'),
      _throwsAuthFailure,
    );
    expect(sessionExpiredCalls, 1);
    expect(await store.readAccessToken(), isNull);
  });

  test(
    '재시도한 요청이 또 204면 재발급을 반복하지 않는다 (Issue 2 회귀: 새 토큰도 거부되면 세션을 종료해야 한다)',
    () async {
      await setUpDio(
        script: {'/courses': [204, 204]},
        reissue: (_) async => const AuthTokens(accessToken: 'newAccess', refreshToken: 'newRefresh'),
      );

      await expectLater(dio.get<Object?>('/courses'), _throwsAuthFailure);
      expect(reissueCalls, 1, reason: '_retry 플래그가 두 번째 재발급을 막아야 한다');
      expect(
        sessionExpiredCalls,
        1,
        reason: '방금 재발급받은 새 토큰도 204로 거부됐으므로, 재시도 실패로 오분류해 세션을 '
            '살려두면 안 되고 세션을 종료해야 한다',
      );
      expect(
        await store.readAccessToken(),
        isNull,
        reason: '세션 종료 시 거부당한 새 토큰도 지워져야 한다',
      );
    },
  );

  test('refreshToken이 없으면 재발급을 시도하지 않고 곧장 세션 만료 처리한다', () async {
    await setUpDio(
      script: {'/courses': [204]},
      reissue: (_) async => const AuthTokens(accessToken: 'a', refreshToken: 'r'),
    );
    await store.clearTokens();

    await expectLater(dio.get<Object?>('/courses'), _throwsAuthFailure);
    expect(reissueCalls, 0);
    expect(sessionExpiredCalls, 1);
  });

  test('동시에 204를 받은 요청들이 재발급을 한 번만 호출한다', () async {
    await setUpDio(
      script: {
        '/courses': [204, 200],
        '/terms': [204, 200],
        '/user/profile': [204, 200],
      },
      reissue: (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return const AuthTokens(accessToken: 'newAccess', refreshToken: 'newRefresh');
      },
    );

    final results = await Future.wait([
      dio.get<Object?>('/courses'),
      dio.get<Object?>('/terms'),
      dio.get<Object?>('/user/profile'),
    ]);

    expect(results.every((r) => r.statusCode == 200), isTrue);
    expect(reissueCalls, 1, reason: '동시 요청은 한 번의 재발급을 공유해야 한다');
  });

  test(
    'refreshToken 읽기에 실제 지연이 있어도 동시 204 요청은 재발급을 한 번만 호출한다 '
    '(Finding 1 회귀: check-then-act 경쟁)',
    () async {
      final innerStore = InMemoryTokenStore();
      await innerStore.saveTokens(accessToken: 'oldAccess', refreshToken: 'oldRefresh');
      final delayedStore = _DelayedRefreshTokenStore(
        innerStore,
        const Duration(milliseconds: 50),
      );

      var localReissueCalls = 0;
      var localSessionExpiredCalls = 0;
      final localDio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
      final localAdapter = _ScriptedAdapter({
        '/courses': [204, 200],
        '/terms': [204, 200],
        '/user/profile': [204, 200],
        '/grades': [204, 200],
      });
      localDio.httpClientAdapter = localAdapter;

      localDio.interceptors.add(AuthInterceptor(
        tokenStore: delayedStore,
        reissue: (refresh) async {
          localReissueCalls++;
          return const AuthTokens(accessToken: 'newAccess', refreshToken: 'newRefresh');
        },
        onSessionExpired: () async {
          localSessionExpiredCalls++;
        },
        retryClient: localDio,
      ));

      final results = await Future.wait([
        localDio.get<Object?>('/courses'),
        localDio.get<Object?>('/terms'),
        localDio.get<Object?>('/user/profile'),
        localDio.get<Object?>('/grades'),
      ]);

      expect(results.every((r) => r.statusCode == 200), isTrue);
      expect(
        localReissueCalls,
        1,
        reason:
            '_refreshing 플래그를 await(readRefreshToken) 이전에 세우지 않으면 '
            '여러 요청이 각자 재발급을 시작할 수 있다',
      );
      expect(localSessionExpiredCalls, 0);
    },
  );

  test(
    '재발급 성공 후 원요청 재시도가 실패하면 AuthFailure가 아닌 실제 에러를 그대로 전달하고 '
    '새로 저장된 토큰을 지우지 않는다 (Finding 2 회귀)',
    () async {
      await setUpDio(
        script: {'/courses': [204, 500]},
        reissue: (_) async => const AuthTokens(accessToken: 'newAccess', refreshToken: 'newRefresh'),
      );

      await expectLater(
        dio.get<Object?>('/courses'),
        throwsA(
          isA<DioException>()
              .having((e) => e.error, 'error', isNot(isA<AuthFailure>()))
              .having((e) => e.response?.statusCode, 'response.statusCode', 500),
        ),
      );

      expect(reissueCalls, 1);
      expect(sessionExpiredCalls, 0, reason: '재발급은 성공했으므로 세션을 지우면 안 된다');
      expect(await store.readAccessToken(), 'newAccess', reason: '재발급으로 저장된 새 토큰이 지워지면 안 된다');
      expect(await store.readRefreshToken(), 'newRefresh');
    },
  );

  test(
    'TokenStore.readRefreshToken()이 예외를 던져도 요청이 멈추지 않고 '
    '이후 요청은 재발급을 다시 시도할 수 있다 (Issue 1 회귀: read 예외)',
    () async {
      final inner = InMemoryTokenStore();
      await inner.saveTokens(accessToken: 'oldAccess', refreshToken: 'oldRefresh');
      // 호출 #1은 onRequest가 첫 요청을 보내기 전에 부착용으로 미리 읽는 것이고,
      // 호출 #2가 _recover 내부에서 재발급을 위해 읽는 것이다. 여기서만 던진다.
      final faultyStore = _FaultyTokenStore(inner, throwReadOnCall: 2);

      var localReissueCalls = 0;
      var localSessionExpiredCalls = 0;
      final localDio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
      final localAdapter = _ScriptedAdapter({
        '/courses': [204],
        '/terms': [204, 200],
      });
      localDio.httpClientAdapter = localAdapter;

      localDio.interceptors.add(AuthInterceptor(
        tokenStore: faultyStore,
        reissue: (refresh) async {
          localReissueCalls++;
          return const AuthTokens(accessToken: 'newAccess', refreshToken: 'newRefresh');
        },
        onSessionExpired: () async {
          localSessionExpiredCalls++;
        },
        retryClient: localDio,
      ));

      // 첫 요청: readRefreshToken()이 _recover 내부에서 던진다. 이 요청은
      // 반드시 settle 되어야 한다(멈추면 안 된다) — 타임아웃으로 확인한다.
      await expectLater(
        localDio.get<Object?>('/courses').timeout(const Duration(seconds: 2)),
        throwsA(anything),
      );

      // _refreshing 플래그가 리셋되지 않았다면 이 두 번째 요청은 아무도 완료해줄
      // 수 없는 waiter로 들어가 영원히 멈춘다. 타임아웃이 그 상태를 실패로 만든다.
      final res = await localDio.get<Object?>('/terms').timeout(const Duration(seconds: 2));

      expect(res.statusCode, 200);
      expect(
        localReissueCalls,
        1,
        reason: '두 번째 요청은 정상적으로 재발급을 다시 트리거할 수 있어야 한다 '
            '(_refreshing이 리셋되지 않았다면 절대 도달하지 못한다)',
      );
      expect(
        localSessionExpiredCalls,
        0,
        reason: 'TokenStore I/O 예외는 로컬 문제일 뿐 세션이 실제로 만료된 근거가 아니므로 '
            '세션을 지우면 안 된다',
      );
    },
  );

  test(
    'TokenStore.saveTokens()이 예외를 던져도 요청이 멈추지 않고 '
    '이후 요청은 재발급을 다시 시도할 수 있다 (Issue 1 회귀: save 예외)',
    () async {
      final inner = InMemoryTokenStore();
      await inner.saveTokens(accessToken: 'oldAccess', refreshToken: 'oldRefresh');
      // saveTokens() 호출 #1(첫 요청의 재발급 저장)에서만 던진다.
      final faultyStore = _FaultyTokenStore(inner, throwSaveOnCall: 1);

      var localReissueCalls = 0;
      var localSessionExpiredCalls = 0;
      final localDio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
      final localAdapter = _ScriptedAdapter({
        '/courses': [204],
        '/terms': [204, 200],
      });
      localDio.httpClientAdapter = localAdapter;

      localDio.interceptors.add(AuthInterceptor(
        tokenStore: faultyStore,
        reissue: (refresh) async {
          localReissueCalls++;
          return const AuthTokens(accessToken: 'newAccess', refreshToken: 'newRefresh');
        },
        onSessionExpired: () async {
          localSessionExpiredCalls++;
        },
        retryClient: localDio,
      ));

      // 첫 요청: 재발급 자체는 성공하지만 saveTokens()가 던진다. 이 요청도
      // 반드시 settle 되어야 한다.
      await expectLater(
        localDio.get<Object?>('/courses').timeout(const Duration(seconds: 2)),
        throwsA(anything),
      );
      expect(localReissueCalls, 1);

      // 두 번째 요청: _refreshing이 리셋되지 않았다면 waiter로 들어가 멈춘다.
      final res = await localDio.get<Object?>('/terms').timeout(const Duration(seconds: 2));

      expect(res.statusCode, 200);
      expect(
        localReissueCalls,
        2,
        reason: '두 번째 요청은 정상적으로 재발급을 다시 트리거할 수 있어야 한다',
      );
      expect(
        localSessionExpiredCalls,
        0,
        reason: 'TokenStore I/O 예외는 로컬 문제일 뿐 세션이 실제로 만료된 근거가 아니므로 '
            '세션을 지우면 안 된다',
      );
    },
  );
}
