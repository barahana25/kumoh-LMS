import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

/// 네이티브는 dio 기본 어댑터를 그대로 쓴다.
HttpClientAdapter? platformHttpAdapter() => null;

Interceptor platformCookieInterceptor(CookieJar jar) => CookieManager(jar);
