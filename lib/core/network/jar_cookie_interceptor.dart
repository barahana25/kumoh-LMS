import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

/// 웹용 쿠키 인터셉터. dio_cookie_manager는 웹에서 생성자가 assert로 막힌다.
///
/// 웹에서도 쿠키는 브라우저가 아니라 이 저장소가 관리한다. libcurl.js 응답은
/// Set-Cookie를 숨기지 않으므로 네이티브와 같은 SAML 브리지를 쓸 수 있다.
class JarCookieInterceptor extends Interceptor {
  JarCookieInterceptor(this.jar);

  final CookieJar jar;

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final cookies = await jar.loadForRequest(options.uri);
      final existing = (options.headers['cookie'] as String?)?.trim();
      final values = [
        if (existing != null && existing.isNotEmpty) existing,
        for (final c in cookies) '${c.name}=${c.value}',
      ];
      if (values.isEmpty) {
        options.headers.remove('cookie');
      } else {
        options.headers['cookie'] = values.join('; ');
      }
      handler.next(options);
    } on Object catch (e, s) {
      handler.reject(DioException(requestOptions: options, error: e, stackTrace: s));
    }
  }

  @override
  Future<void> onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) async {
    try {
      await _save(response);
      handler.next(response);
    } on Object catch (e, s) {
      handler.reject(DioException(
          requestOptions: response.requestOptions, error: e, stackTrace: s));
    }
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    if (response != null) {
      try {
        await _save(response);
      } on Object {
        // 원래 오류를 우선한다.
      }
    }
    handler.next(err);
  }

  Future<void> _save(Response<dynamic> response) async {
    final values = response.headers['set-cookie'];
    if (values == null || values.isEmpty) return;
    await jar.saveFromResponse(response.requestOptions.uri,
        [for (final v in values) Cookie.fromSetCookieValue(v)]);
  }
}
