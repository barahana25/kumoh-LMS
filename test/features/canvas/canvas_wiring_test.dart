import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_api.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_client.dart';

/// 나가는 요청의 쿠키 헤더를 기록한다.
class _Recorder implements HttpClientAdapter {
  final List<String> cookieHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? s,
    Future<void>? c,
  ) async {
    cookieHeaders.add((options.headers['cookie'] ?? '').toString());
    return ResponseBody.fromString('[]', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('세션이 붙기 전에 쿠키 매니저가 먼저 돌면 안 된다', () async {
    // 실제로 겪은 버그: CookieManager가 먼저 등록돼 있으면 첫 요청에서
    // 비어 있는 저장소를 읽은 뒤에야 브릿지가 돌아, 세션 쿠키 없이 요청이
    // 나가고 Canvas가 강좌를 404로 숨긴다.
    final jar = CookieJar();
    final recorder = _Recorder();
    final dio = buildCanvasDio(jar, adapter: recorder)
      ..options.baseUrl = 'https://canvas.kumoh.ac.kr/api/v1';

    // 운영 배선과 동일하게 세션 인터셉터를 CookieManager 앞에 끼운다.
    dio.interceptors.insert(
      0,
      canvasSessionInterceptor(
        dio: dio,
        reBridge: () async {},
        // 브릿지가 이때 비로소 세션 쿠키를 저장한다.
        ensureSession: () async {
          await jar.saveFromResponse(
            Uri.parse('https://canvas.kumoh.ac.kr'),
            [Cookie('_normandy_session', 'abc')],
          );
        },
      ),
    );

    await CanvasApi(dio).fetchTabs(4831);

    expect(recorder.cookieHeaders.single, contains('_normandy_session'),
        reason: '첫 요청부터 세션 쿠키가 실려야 한다');
  });

  test('순서가 뒤바뀌면 첫 요청에 쿠키가 빠진다 (회귀 증명)', () async {
    // 위 테스트가 진짜로 순서를 검증하는지 보이기 위해, 잘못된 순서를 재현한다.
    final jar = CookieJar();
    final recorder = _Recorder();
    final dio = Dio(BaseOptions(baseUrl: 'https://canvas.kumoh.ac.kr/api/v1'))
      ..httpClientAdapter = recorder;
    dio.interceptors.add(CookieManager(jar)); // 먼저 등록 = 잘못된 순서
    dio.interceptors.add(canvasSessionInterceptor(
      dio: dio,
      reBridge: () async {},
      ensureSession: () async {
        await jar.saveFromResponse(
          Uri.parse('https://canvas.kumoh.ac.kr'),
          [Cookie('_normandy_session', 'abc')],
        );
      },
    ));

    await CanvasApi(dio).fetchTabs(4831);

    expect(recorder.cookieHeaders.single, isNot(contains('_normandy_session')),
        reason: '이 순서에서는 쿠키가 빠진다 — 그래서 앞의 순서를 강제해야 한다');
  });
}
