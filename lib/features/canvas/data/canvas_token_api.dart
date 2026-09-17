import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import '../../../core/config/env.dart';

/// 방금 만든 토큰. `token`은 생성 응답에만 들어 있고 다시 볼 수 없다.
class IssuedCanvasToken {
  const IssuedCanvasToken({
    required this.id,
    required this.token,
    required this.purpose,
  });

  final int id;
  final String token;
  final String purpose;
}

/// CSRF 쿠키를 얻지 못해 토큰을 다룰 수 없는 상태.
class CanvasTokenUnavailable implements Exception {
  const CanvasTokenUnavailable();
}

/// Canvas 개인 액세스 토큰 엔드포인트.
///
/// 세션 쿠키로 인증하는 쓰기 요청이라 Canvas가 `X-CSRF-Token`을 요구한다.
/// 값은 쿠키 `_csrf_token`을 URL 디코딩한 것이다.
class CanvasTokenApi {
  CanvasTokenApi(this._dio, this._jar);

  final Dio _dio;
  final CookieJar _jar;

  static final Uri _tokensUri = Uri.parse('${Env.canvasApiBaseUrl}/users/self/tokens');

  Future<String?> _readCsrf() async {
    final cookies = await _jar.loadForRequest(Uri.parse('${Env.canvasHost}/'));
    for (final cookie in cookies) {
      if (cookie.name == '_csrf_token' && cookie.value.isNotEmpty) {
        return Uri.decodeComponent(cookie.value);
      }
    }
    return null;
  }

  /// 브릿지 직후에는 쿠키 자에 CSRF가 없을 수 있다. 한 번만 받아온다.
  Future<String> _csrf() async {
    final existing = await _readCsrf();
    if (existing != null) return existing;
    await _dio.getUri<void>(
      Uri.parse('${Env.canvasHost}/'),
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    final warmed = await _readCsrf();
    if (warmed == null) throw const CanvasTokenUnavailable();
    return warmed;
  }

  Future<IssuedCanvasToken> create(String purpose) async {
    final csrf = await _csrf();
    final res = await _dio.postUri<Map<String, dynamic>>(
      _tokensUri,
      data: {'token[purpose]': purpose},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'X-CSRF-Token': csrf},
      ),
    );
    final body = res.data ?? const <String, dynamic>{};
    final id = body['id'];
    final token = body['visible_token'];
    if (id is! int || token is! String || token.isEmpty) {
      throw const CanvasTokenUnavailable();
    }
    return IssuedCanvasToken(id: id, token: token, purpose: purpose);
  }

  Future<void> delete(int id) async {
    final csrf = await _csrf();
    await _dio.deleteUri<void>(
      Uri.parse('${Env.canvasApiBaseUrl}/users/self/tokens/$id'),
      options: Options(headers: {'X-CSRF-Token': csrf}),
    );
  }
}
