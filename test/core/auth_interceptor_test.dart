import 'package:dio/dio.dart';
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

  test('재시도한 요청이 또 204면 재발급을 반복하지 않는다', () async {
    await setUpDio(
      script: {'/courses': [204, 204]},
      reissue: (_) async => const AuthTokens(accessToken: 'newAccess', refreshToken: 'newRefresh'),
    );

    await expectLater(dio.get<Object?>('/courses'), _throwsAuthFailure);
    expect(reissueCalls, 1, reason: '_retry 플래그가 두 번째 재발급을 막아야 한다');
  });

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
}
