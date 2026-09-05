import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import '../../../core/config/env.dart';
import '../../../core/error/failure.dart';

/// IdP가 돌려주는 자동 제출 폼의 내용.
class SamlForm {
  const SamlForm({
    required this.action,
    required this.samlResponse,
    required this.relayState,
  });

  final String action;
  final String samlResponse;
  final String relayState;
}

final _formAction = RegExp(r'''<form[^>]*action="([^"]+)"''', caseSensitive: false);
RegExp _hidden(String name) => RegExp(
      '''<input[^>]*name="$name"[^>]*value="([^"]*)"''',
      caseSensitive: false,
    );

/// IdP는 브라우저에서 JS로 자동 제출되는 폼을 돌려준다. 클라이언트에는 JS가
/// 없으므로 폼을 파싱해 직접 POST 해야 한다. 폼이 아니면 null.
SamlForm? parseSamlForm(String html) {
  final action = _formAction.firstMatch(html)?.group(1);
  final saml = _hidden('SAMLResponse').firstMatch(html)?.group(1);
  if (action == null || saml == null) return null;
  return SamlForm(
    action: action,
    samlResponse: saml,
    relayState: _hidden('RelayState').firstMatch(html)?.group(1) ?? '/',
  );
}

/// Canvas REST API는 LINUS 토큰을 모른다. LINUS의 SAML 다리를 건너
/// Canvas 세션 쿠키(`_normandy_session`)를 얻어야 열린다.
///
/// 브릿지는 비싸고 학교 서버를 거치므로, 한 번 얻은 세션은 만료될 때까지 쓰고
/// 동시 요청은 하나의 브릿지를 공유한다(single-flight).
class CanvasSession {
  CanvasSession({
    required Dio dio,
    required CookieJar jar,
    required Future<String> Function(String relayState) fetchSsoUrl,
    required Future<String?> Function() loginId,
  })  : _dio = dio,
        _jar = jar,
        _fetchSsoUrl = fetchSsoUrl,
        _loginId = loginId;

  final Dio _dio;
  final CookieJar _jar;
  final Future<String> Function(String relayState) _fetchSsoUrl;
  final Future<String?> Function() _loginId;

  bool _active = false;
  Future<void>? _bridging;

  bool get isActive => _active;

  /// 세션을 무효로 표시한다. 다음 [ensure]에서 다시 브릿지한다.
  void invalidate() => _active = false;

  /// 유효한 Canvas 세션을 보장한다. 이미 있으면 아무 것도 하지 않는다.
  ///
  /// 동시 호출은 진행 중인 브릿지를 공유한다. 그러지 않으면 만료된 순간
  /// 쌓여 있던 요청 수만큼 학교 서버에 동시 로그인이 발생한다.
  Future<void> ensure() {
    if (_active) return Future<void>.value();
    return _bridging ??= _bridge().whenComplete(() => _bridging = null);
  }

  Future<void> _bridge({String relayState = '/courses'}) async {
    final id = await _loginId();
    if (id == null || id.isEmpty) {
      throw const AuthFailure('로그인 정보가 없어 Canvas에 연결할 수 없습니다.');
    }

    // IdP는 이 쿠키로 사용자를 식별한다. 없으면 A001로 거부한다.
    await _jar.saveFromResponse(Uri.parse(Env.canvasBridgeCookieHost), [
      Cookie('_linus_saml_login', id)
        ..domain = '.kumoh.ac.kr'
        ..path = '/',
      Cookie('_linus_saml_domain', relayState)
        ..domain = '.kumoh.ac.kr'
        ..path = '/',
    ]);

    final ssoUrl = await _fetchSsoUrl(relayState);

    // IdP까지 리다이렉트를 따라가면 자동 제출 폼 HTML이 돌아온다.
    final idp = await _dio.getUri<String>(
      Uri.parse(ssoUrl),
      options: Options(
        responseType: ResponseType.plain,
        followRedirects: true,
        maxRedirects: 10,
        validateStatus: (s) => s != null && s < 400,
      ),
    );

    final form = parseSamlForm(idp.data ?? '');
    if (form == null) {
      throw const AuthFailure('Canvas 연결에 실패했습니다. 다시 로그인해 주세요.');
    }

    // 브라우저의 JS 자동 제출을 대신한다.
    await _dio.postUri<void>(
      Uri.parse(form.action),
      data: {
        'SAMLResponse': form.samlResponse,
        'RelayState': form.relayState,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        followRedirects: false,
        // 302가 정상 종료다.
        validateStatus: (s) => s != null && s < 400,
      ),
    );

    _active = true;
  }
}
