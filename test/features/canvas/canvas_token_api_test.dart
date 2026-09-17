import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_client.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_api.dart';

/// Canvas 토큰 엔드포인트만 흉내내는 어댑터.
class _TokenScript implements HttpClientAdapter {
  _TokenScript({this.csrfOnWarmup});

  /// 준비 요청(GET /)에서 내려줄 CSRF 쿠키 값. null이면 안 준다.
  final String? csrfOnWarmup;
  final List<String> calls = [];
  final List<String?> csrfHeaders = [];
  String? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.uri.path}');
    csrfHeaders.add(options.headers['X-CSRF-Token'] as String?);

    if (options.method == 'GET' && options.uri.path == '/') {
      return ResponseBody.fromString('', 200, headers: {
        if (csrfOnWarmup != null)
          'set-cookie': ['_csrf_token=$csrfOnWarmup; path=/'],
      });
    }
    if (options.method == 'POST' && options.uri.path == '/api/v1/users/self/tokens') {
      lastBody = options.data?.toString();
      return ResponseBody.fromString(
        '{"id":44,"visible_token":"7~abc","purpose":"금오LMS 앱 · Android · a3f9"}',
        200,
        headers: {
          'content-type': ['application/json'],
        },
      );
    }
    if (options.method == 'DELETE') {
      return ResponseBody.fromString('{"id":41}', 200, headers: {
        'content-type': ['application/json'],
      });
    }
    return ResponseBody.fromString('', 404);
  }

  @override
  void close({bool force = false}) {}
}

Future<CookieJar> _jarWithCsrf(String value) async {
  final jar = DefaultCookieJar();
  await jar.saveFromResponse(
    Uri.parse('https://canvas.kumoh.ac.kr/'),
    [Cookie('_csrf_token', value)..path = '/'],
  );
  return jar;
}

void main() {
  test('토큰을 만들 때 CSRF 헤더를 디코딩해 붙이고 purpose를 보낸다', () async {
    // Canvas 쿠키는 URL 인코딩된 채로 저장된다. 헤더에는 디코딩해 넣어야 한다.
    final jar = await _jarWithCsrf('ab%2Bcd%3D');
    final script = _TokenScript();
    final api = CanvasTokenApi(buildCanvasDio(jar, adapter: script), jar);

    final issued = await api.create('금오LMS 앱 · Android · a3f9');

    expect(issued.id, 44);
    expect(issued.token, '7~abc');
    expect(script.csrfHeaders.last, 'ab+cd=');
    expect(script.lastBody, contains('금오LMS 앱'));
  });

  test('CSRF 쿠키가 없으면 준비 요청을 한 번 보내고 이어서 만든다', () async {
    final jar = DefaultCookieJar();
    final script = _TokenScript(csrfOnWarmup: 'warm');
    final api = CanvasTokenApi(buildCanvasDio(jar, adapter: script), jar);

    final issued = await api.create('금오LMS 앱 · Android · a3f9');

    expect(issued.id, 44);
    expect(script.calls.first, 'GET /');
    expect(script.csrfHeaders.last, 'warm');
  });

  test('준비 요청에도 CSRF가 없으면 CanvasTokenUnavailable을 던진다', () async {
    final jar = DefaultCookieJar();
    final script = _TokenScript();
    final api = CanvasTokenApi(buildCanvasDio(jar, adapter: script), jar);

    expect(() => api.create('금오LMS 앱 · Android · a3f9'),
        throwsA(isA<CanvasTokenUnavailable>()));
  });

  test('삭제는 id 경로로 요청하고 CSRF를 붙인다', () async {
    final jar = await _jarWithCsrf('x');
    final script = _TokenScript();
    final api = CanvasTokenApi(buildCanvasDio(jar, adapter: script), jar);

    await api.delete(41);

    expect(script.calls.last, 'DELETE /api/v1/users/self/tokens/41');
    expect(script.csrfHeaders.last, 'x');
  });
}
