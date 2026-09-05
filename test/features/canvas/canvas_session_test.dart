import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_client.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_session.dart';

/// SAML 왕복을 대본대로 재현하는 최소 어댑터.
/// 실제 흐름: redirect.do -> (IdP) 자동제출 폼 HTML -> Canvas ACS로 POST -> 302
class _SamlScript implements HttpClientAdapter {
  _SamlScript({this.idpBody});

  final String? idpBody;
  final List<String> calls = [];

  static const ssoUrl = 'https://canvas.kumoh.ac.kr/login/saml?RelayState=/courses';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.uri.host}${options.uri.path}');

    if (options.uri.path.endsWith('/saml/redirect.do')) {
      return ResponseBody.fromString(ssoUrl, 200);
    }
    // IdP가 자동제출 폼을 돌려주는 지점
    if (options.uri.host == 'canvas.kumoh.ac.kr' &&
        options.method == 'GET' &&
        options.uri.path == '/login/saml') {
      return ResponseBody.fromString(idpBody ?? '', 200);
    }
    // Canvas ACS
    if (options.uri.host == 'canvas.kumoh.ac.kr' &&
        options.method == 'POST' &&
        options.uri.path == '/login/saml') {
      return ResponseBody.fromString(
        '',
        302,
        headers: {
          'set-cookie': ['_normandy_session=abc123; path=/; HttpOnly'],
        },
      );
    }
    return ResponseBody.fromString('', 404);
  }

  @override
  void close({bool force = false}) {}
}

String autoSubmitForm(String samlResponse) => '''
<!DOCTYPE html><html><head><title>SAML Redirect</title>
<script>window.onload = () => document.getElementById('saml_form').submit();</script></head>
<body><form action="https://canvas.kumoh.ac.kr/login/saml" method="post" id="saml_form">
<input type="hidden" name="SAMLResponse" value="$samlResponse" />
<input type="hidden" name="RelayState" value="/courses" />
</form></body></html>''';

void main() {
  late CookieJar jar;

  setUp(() => jar = CookieJar());

  CanvasSession build(_SamlScript script) {
    // 운영과 동일한 배선(쿠키 매니저 포함)을 쓴다.
    final dio = buildCanvasDio(jar, adapter: script);
    return CanvasSession(
      dio: dio,
      jar: jar,
      fetchSsoUrl: (relayState) async => _SamlScript.ssoUrl,
      loginId: () async => '20250000',
    );
  }

  test('SAML 폼에서 SAMLResponse와 RelayState를 뽑아낸다', () {
    final form = parseSamlForm(autoSubmitForm('BLOB=='));
    expect(form, isNotNull);
    expect(form!.action, 'https://canvas.kumoh.ac.kr/login/saml');
    expect(form.samlResponse, 'BLOB==');
    expect(form.relayState, '/courses');
  });

  test('폼이 없는 HTML이면 null이다', () {
    expect(parseSamlForm('<html><body>로그인 실패</body></html>'), isNull);
  });

  test('브릿지를 끝내면 Canvas 세션 쿠키를 얻는다', () async {
    final script = _SamlScript(idpBody: autoSubmitForm('BLOB=='));
    final session = build(script);

    await session.ensure();

    final cookies = await jar.loadForRequest(
      Uri.parse('https://canvas.kumoh.ac.kr/api/v1/courses'),
    );
    expect(
      cookies.map((c) => c.name),
      contains('_normandy_session'),
      reason: '세션 쿠키가 없으면 Canvas API가 열리지 않는다',
    );
    expect(session.isActive, isTrue);
  });

  test('브릿지 전에 SAML 힌트 쿠키를 .kumoh.ac.kr에 심는다', () async {
    // 이 쿠키가 없으면 IdP가 A001(SSO 연동 ID 없음)로 거부한다.
    final script = _SamlScript(idpBody: autoSubmitForm('BLOB=='));
    await build(script).ensure();

    final cookies = await jar.loadForRequest(
      Uri.parse('https://lms.kumoh.ac.kr/api/v1/saml/redirect.do'),
    );
    final names = cookies.map((c) => c.name).toList();
    expect(names, contains('_linus_saml_login'));
    expect(
      cookies.firstWhere((c) => c.name == '_linus_saml_login').value,
      '20250000',
    );
  });

  test('이미 활성 세션이면 다시 브릿지하지 않는다', () async {
    final script = _SamlScript(idpBody: autoSubmitForm('BLOB=='));
    final session = build(script);

    await session.ensure();
    final afterFirst = script.calls.length;
    await session.ensure();

    expect(script.calls.length, afterFirst, reason: '불필요한 재브릿지는 학교 서버 부하다');
  });

  test('동시에 여러 번 요청해도 브릿지는 한 번만 수행한다', () async {
    final script = _SamlScript(idpBody: autoSubmitForm('BLOB=='));
    final session = build(script);

    await Future.wait([
      session.ensure(),
      session.ensure(),
      session.ensure(),
    ]);

    final acsPosts =
        script.calls.where((c) => c.startsWith('POST canvas')).length;
    expect(acsPosts, 1, reason: '동시 요청이 N번 로그인하면 계정이 잠길 수 있다');
  });

  test('IdP가 폼 대신 오류를 주면 AuthFailure로 실패한다', () async {
    final script = _SamlScript(idpBody: '{"code":"A001","message":"SSO 연동 ID가 없습니다"}');
    final session = build(script);

    await expectLater(session.ensure(), throwsA(isA<AuthFailure>()));
    expect(session.isActive, isFalse);
  });

  test('invalidate 후에는 다시 브릿지한다', () async {
    final script = _SamlScript(idpBody: autoSubmitForm('BLOB=='));
    final session = build(script);

    await session.ensure();
    final afterFirst = script.calls.length;
    session.invalidate();
    await session.ensure();

    expect(script.calls.length, greaterThan(afterFirst));
  });
}
