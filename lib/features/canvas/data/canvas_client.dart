import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../../../core/config/env.dart';

/// Canvas는 Bearer 토큰이 아니라 세션 쿠키로 인증한다. 쿠키 매니저가 없으면
/// ACS 응답의 `_normandy_session`이 저장되지 않아 이후 모든 API가 막힌다.
/// 이 팩토리를 테스트와 운영이 함께 써서 배선이 어긋나지 않게 한다.
Dio buildCanvasDio(CookieJar jar, {HttpClientAdapter? adapter}) {
  final dio = Dio(BaseOptions(
    connectTimeout: Env.connectTimeout,
    receiveTimeout: Env.receiveTimeout,
    headers: {'Accept': 'application/json'},
  ));
  if (adapter != null) dio.httpClientAdapter = adapter;
  dio.interceptors.add(CookieManager(jar));
  return dio;
}
