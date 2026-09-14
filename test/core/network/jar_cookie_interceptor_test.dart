import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/network/jar_cookie_interceptor.dart';

class _Script implements HttpClientAdapter {
  final cookieHeaders = <String?>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    cookieHeaders.add(options.headers['cookie'] as String?);
    if (options.uri.path == '/set') {
      return ResponseBody.fromString('', 302, headers: {
        'set-cookie': [
          '_normandy_session=abc; path=/; HttpOnly',
          'other=1; path=/',
        ],
      });
    }
    return ResponseBody.fromString('ok', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late CookieJar jar;
  late _Script script;
  late Dio dio;

  setUp(() {
    jar = CookieJar();
    script = _Script();
    dio = Dio(BaseOptions(validateStatus: (s) => s != null && s < 400))
      ..httpClientAdapter = script
      ..interceptors.add(JarCookieInterceptor(jar));
  });

  test('응답의 Set-Cookie를 저장하고 다음 요청에 싣는다', () async {
    await dio.get<String>('https://canvas.kumoh.ac.kr/set');
    await dio.get<String>('https://canvas.kumoh.ac.kr/api/v1/courses');

    expect(script.cookieHeaders.last, '_normandy_session=abc; other=1');
  });

  test('저장소에 미리 심은 도메인 쿠키를 하위 호스트 요청에 싣는다', () async {
    await jar.saveFromResponse(Uri.parse('https://lms.kumoh.ac.kr'), [
      Cookie('_linus_saml_login', 'jwt')
        ..domain = '.kumoh.ac.kr'
        ..path = '/',
    ]);

    await dio.get<String>('https://lms.kumoh.ac.kr:82/api/v1/saml/login.do');

    expect(script.cookieHeaders.single, '_linus_saml_login=jwt');
  });

  test('쿠키가 없으면 cookie 헤더를 붙이지 않는다', () async {
    await dio.get<String>('https://canvas.kumoh.ac.kr/');

    expect(script.cookieHeaders.single, isNull);
  });
}
