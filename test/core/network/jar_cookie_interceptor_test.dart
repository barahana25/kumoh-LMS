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
    if (options.uri.path == '/login/saml') {
      return ResponseBody.fromString('', 302, headers: {
        'location': ['https://lms.kumoh.ac.kr:82/api/v1/saml/login.do'],
        'set-cookie': ['_normandy_session=saml; path=/; secure; HttpOnly'],
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

  Future<void> saveSession(String value) => jar.saveFromResponse(
      Uri.parse('https://canvas.kumoh.ac.kr/'),
      [Cookie('_normandy_session', value)..path = '/']);

  test('같은 RequestOptions를 다시 보내도 쿠키를 중복하지 않고 새 값으로 바꾼다',
      () async {
    await saveSession('OLD');
    final first =
        await dio.get<String>('https://canvas.kumoh.ac.kr/api/v1/courses');

    // 재브리지로 세션이 바뀐 뒤 canvasSessionInterceptor처럼 같은 옵션을 재전송한다.
    await saveSession('NEW');
    await dio.fetch<String>(first.requestOptions);

    final header = script.cookieHeaders.last!;
    expect(RegExp('_normandy_session=').allMatches(header).length, 1);
    expect(header, contains('_normandy_session=NEW'));
    expect(header, isNot(contains('OLD')));
  });

  test('호출자가 넣은 다른 이름의 쿠키는 유지한다', () async {
    await saveSession('NEW');

    await dio.get<String>('https://canvas.kumoh.ac.kr/api/v1/courses',
        options: Options(headers: {'cookie': 'lang=ko; _normandy_session=X'}));

    expect(script.cookieHeaders.single, 'lang=ko; _normandy_session=NEW');
  });

  test('SAML 흐름에서 호스트마다 알맞은 쿠키를 싣는다', () async {
    await jar.saveFromResponse(Uri.parse('https://lms.kumoh.ac.kr'), [
      Cookie('_linus_saml_login', 'jwt')
        ..domain = '.kumoh.ac.kr'
        ..path = '/',
    ]);

    final saml = await dio.get<String>('https://canvas.kumoh.ac.kr/login/saml',
        options: Options(followRedirects: false));
    expect(saml.statusCode, 302);
    await dio.get<String>('https://lms.kumoh.ac.kr:82/api/v1/saml/login.do');
    await dio.get<String>('https://canvas.kumoh.ac.kr/api/v1/courses');

    expect(script.cookieHeaders[1], '_linus_saml_login=jwt');
    expect(script.cookieHeaders[2], contains('_normandy_session=saml'));
  });
}
