@TestOn('browser')
library;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/providers.dart';

/// CookieJar()는 웹에서 아무것도 저장하지 않는 WebCookieJar를 준다(브라우저 XHR이
/// 쿠키를 처리한다고 가정). 웹은 libcurl.js로 요청해 브라우저가 쿠키를 다루지 않으므로
/// _linus_saml_login이 IdP에 실리지 않아 A001로 Canvas 연결이 실패했다.
void main() {
  test('웹에서도 Canvas 쿠키 저장소가 도메인 쿠키를 저장하고 돌려준다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final jar = container.read(canvasCookieJarProvider);

    await jar.saveFromResponse(Uri.parse('https://lms.kumoh.ac.kr'), [
      Cookie('_linus_saml_login', 'token')
        ..domain = '.kumoh.ac.kr'
        ..path = '/',
    ]);

    final cookies = await jar.loadForRequest(
        Uri.parse('https://lms.kumoh.ac.kr/api/v1/saml/login.do'));
    expect(cookies.map((c) => c.name), contains('_linus_saml_login'));
  });
}
