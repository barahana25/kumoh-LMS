import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_api.dart';

/// 첫 요청은 [firstStatus], 재시도부터는 200을 준다.
class _Script implements HttpClientAdapter {
  _Script({this.firstStatus = 200, this.alwaysUnauthorized = false});

  final int firstStatus;
  final bool alwaysUnauthorized;
  final List<String?> authHeaders = [];
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    authHeaders.add(options.headers['Authorization'] as String?);
    final status = alwaysUnauthorized
        ? 401
        : (calls == 1 ? firstStatus : 200);
    return ResponseBody.fromString('{}', status, headers: {
      'content-type': ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(
  _Script script, {
  Future<void> Function()? ensureSession,
  Future<String?> Function()? accessToken,
  Future<String?> Function()? reissueToken,
  required Future<void> Function() reBridge,
}) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://canvas.kumoh.ac.kr/api/v1',
    validateStatus: (s) => s != null && s < 500,
  ))..httpClientAdapter = script;
  dio.interceptors.insert(
    0,
    canvasSessionInterceptor(
      dio: dio,
      ensureSession: ensureSession,
      reBridge: reBridge,
      accessToken: accessToken,
      reissueToken: reissueToken,
    ),
  );
  return dio;
}

void main() {
  test('토큰이 있으면 Bearer를 붙이고 다리를 건너지 않는다', () async {
    var ensured = false;
    final script = _Script();
    final dio = _dio(
      script,
      ensureSession: () async => ensured = true,
      accessToken: () async => '7~abc',
      reBridge: () async {},
    );

    await dio.get<dynamic>('/users/self');

    expect(script.authHeaders.single, 'Bearer 7~abc');
    expect(ensured, isFalse);
  });

  test('토큰이 없으면 지금처럼 다리를 건넌다', () async {
    var ensured = false;
    final script = _Script();
    final dio = _dio(
      script,
      ensureSession: () async => ensured = true,
      accessToken: () async => null,
      reBridge: () async {},
    );

    await dio.get<dynamic>('/users/self');

    expect(script.authHeaders.single, isNull);
    expect(ensured, isTrue);
  });

  test('Bearer 요청이 401이면 재발급한 토큰으로 한 번 재시도한다', () async {
    final script = _Script(firstStatus: 401);
    var reBridged = false;
    final dio = _dio(
      script,
      accessToken: () async => '7~old',
      reissueToken: () async => '7~new',
      reBridge: () async => reBridged = true,
    );

    final res = await dio.get<dynamic>('/users/self');

    expect(res.statusCode, 200);
    expect(script.authHeaders, ['Bearer 7~old', 'Bearer 7~new']);
    expect(reBridged, isFalse);
  });

  test('재발급이 안 되면 Authorization을 떼고 쿠키로 폴백한다', () async {
    final script = _Script(firstStatus: 401);
    var reBridged = false;
    final dio = _dio(
      script,
      accessToken: () async => '7~old',
      reissueToken: () async => null,
      reBridge: () async => reBridged = true,
    );

    final res = await dio.get<dynamic>('/users/self');

    expect(res.statusCode, 200);
    expect(script.authHeaders, ['Bearer 7~old', isNull]);
    expect(reBridged, isTrue);
  });

  test('재시도는 한 번뿐이다', () async {
    final script = _Script(alwaysUnauthorized: true);
    final dio = _dio(
      script,
      accessToken: () async => '7~old',
      reissueToken: () async => '7~new',
      reBridge: () async {},
    );

    final res = await dio.get<dynamic>('/users/self');

    expect(res.statusCode, 401);
    expect(script.calls, 2);
  });

  test('토큰이 없고 401이면 ensureSession을 재시도에서도 호출한다', () async {
    var ensureSessionCallCount = 0;
    final script = _Script(firstStatus: 401);
    final dio = _dio(
      script,
      ensureSession: () async => ensureSessionCallCount++,
      accessToken: () async => null,
      reBridge: () async {},
    );

    final res = await dio.get<dynamic>('/users/self');

    expect(res.statusCode, 200);
    expect(ensureSessionCallCount, 2);
  });
}
