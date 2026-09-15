import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

/// 웹용 쿠키 인터셉터. dio_cookie_manager는 웹에서 생성자가 assert로 막힌다.
///
/// 웹에서도 쿠키는 브라우저가 아니라 이 저장소가 관리한다. libcurl.js 응답은
/// Set-Cookie를 숨기지 않으므로 네이티브와 같은 SAML 브리지를 쓸 수 있다.
class JarCookieInterceptor extends Interceptor {
  JarCookieInterceptor(this.jar);

  final CookieJar jar;

  /// 요청마다 이 인터셉터가 cookie 헤더에 붙인 쿠키 이름.
  final _added = Expando<Set<String>>();

  static String _nameOf(String pair) {
    final eq = pair.indexOf('=');
    return (eq < 0 ? pair : pair.substring(0, eq)).trim();
  }

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      final cookies = await jar.loadForRequest(options.uri);
      // 세션 복구는 같은 RequestOptions를 다시 보낸다. 지난번에 붙인 쿠키를
      // 호출자 쿠키로 보고 또 덧붙이면 옛 _normandy_session이 앞에 남고,
      // Rack은 첫 값을 써서 401이 반복된다. 저장소가 주는 이름과 지난번에
      // 이 인터셉터가 붙인 이름은 빼고 저장소 값으로 다시 채운다.
      final replaced = {...?_added[options], for (final c in cookies) c.name};
      final existing = [
        for (final pair in ((options.headers['cookie'] as String?) ?? '').split(';'))
          if (pair.trim().isNotEmpty && !replaced.contains(_nameOf(pair)))
            pair.trim(),
      ];
      _added[options] = {for (final c in cookies) c.name};
      final values = [
        ...existing,
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
