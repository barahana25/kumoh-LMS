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

/// 웹은 IdP가 준 폼을 브라우저 창에서 그대로 제출한다. 목적지가 조작되면
/// SAMLResponse가 다른 곳으로 가거나 `javascript:`가 실행되므로, https Canvas
/// 호스트일 때만 믿는다.
bool isTrustedSamlAction(String action) {
  final uri = Uri.tryParse(action);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host == Uri.parse(Env.canvasHost).host;
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
    required Future<String?> Function() identityToken,
  })  : _dio = dio,
        _jar = jar,
        _fetchSsoUrl = fetchSsoUrl,
        _identityToken = identityToken;

  final Dio _dio;
  final CookieJar _jar;
  final Future<String> Function(String relayState) _fetchSsoUrl;
  final Future<String?> Function() _identityToken;

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


  /// 홉마다 요청을 새로 보내 쿠키 매니저가 매번 동작하게 한다.
  Future<String> _followRedirects(Uri start, {int maxHops = 10}) async {
    var url = start;
    for (var hop = 0; hop < maxHops; hop++) {
      final res = await _dio.getUri<String>(
        url,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (s) => s != null && s < 400,
        ),
      );
      final location = res.headers.value('location');
      final status = res.statusCode ?? 0;
      if (status >= 300 && status < 400 && location != null) {
        url = url.resolve(location);
        continue;
      }
      return res.data ?? '';
    }
    throw const AuthFailure('Canvas 연결이 계속 우회되고 있습니다.');
  }

  /// IdP의 SAML 자동 제출 폼까지만 받는다.
  ///
  /// 네이티브는 이어서 우리가 ACS에 POST한다([_bridge]). 웹은 이 폼을
  /// 브라우저 창에서 제출해야 Canvas 세션 쿠키가 브라우저에 생긴다.
  Future<SamlForm> fetchSamlForm({String relayState = '/courses'}) async {
    // 로그아웃 상태면 학교 서버에 가기 전에 멈춘다.
    final before = await _identityToken();
    if (before == null || before.isEmpty) {
      throw const AuthFailure('로그인 정보가 없어 Canvas에 연결할 수 없습니다.');
    }

    final ssoUrl = await _fetchSsoUrl(relayState);

    // 토큰은 SSO 주소를 받은 뒤 다시 읽는다. 만료된 accessToken은 이 LINUS
    // 호출 중에 재발급되므로, 앞서 읽은 토큰을 심으면 IdP가 S010으로 거부한다.
    final token = await _identityToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('로그인 정보가 없어 Canvas에 연결할 수 없습니다.');
    }

    // IdP는 이 쿠키로 사용자를 식별한다. 값은 서명된 accessToken(JWT)이어야
    // 하며, IdP가 서명을 검증한다. 예전처럼 학번 평문을 심으면 검증에 실패해
    // (S010) 폼 대신 500이 돌아오고, 비어 있으면 A001로 거부한다.
    // IdP 홉에서 필요하므로 리다이렉트를 따라가기 전에 심는다.
    await _jar.saveFromResponse(Uri.parse(Env.canvasBridgeCookieHost), [
      Cookie('_linus_saml_login', token)
        ..domain = '.kumoh.ac.kr'
        ..path = '/',
      Cookie('_linus_saml_domain', relayState)
        ..domain = '.kumoh.ac.kr'
        ..path = '/',
    ]);

    // 리다이렉트를 직접 따라간다. dio는 리다이렉트마다 인터셉터를 다시
    // 실행하지 않아서, followRedirects에 맡기면 쿠키 매니저가 첫 홉(canvas)에만
    // 쿠키를 붙인다. 그러면 리다이렉트된 IdP(lms) 요청에 _linus_saml_login이
    // 빠져 폼 대신 오류가 돌아온다.
    final idp = await _followRedirects(Uri.parse(ssoUrl));

    final form = parseSamlForm(idp);
    if (form == null) {
      throw const AuthFailure('Canvas 연결에 실패했습니다. 다시 로그인해 주세요.');
    }
    return form;
  }

  Future<void> _bridge({String relayState = '/courses'}) async {
    final form = await fetchSamlForm(relayState: relayState);

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
