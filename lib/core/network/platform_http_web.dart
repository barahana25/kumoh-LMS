import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import '../config/env.dart';
import 'jar_cookie_interceptor.dart';
import 'libcurl/libcurl_adapter.dart';
import 'libcurl/libcurl_js_binding.dart';

/// 모든 dio가 하나의 libcurl.js 연결(중계 서버 WebSocket)을 공유한다.
final _adapter =
    LibcurlHttpClientAdapter(LibcurlJsBinding(relayUrl: Env.relayUrl));

HttpClientAdapter? platformHttpAdapter() => _adapter;

Interceptor platformCookieInterceptor(CookieJar jar) => JarCookieInterceptor(jar);
