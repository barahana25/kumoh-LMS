import 'package:dio/dio.dart';

import '../config/env.dart';
import '../error/failure.dart';
import 'auth_interceptor.dart';
import 'token_store.dart';
import '../../features/auth/data/auth_dto.dart';

/// DioException 안에 감싸인 Failure를 그대로 던져 주는 마지막 인터셉터.
/// 이게 없으면 호출부가 DioException을 받게 되어 UI 분기가 지저분해진다.
class _UnwrapFailureInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final inner = err.error;
    if (inner is Failure) {
      handler.reject(DioException(
        requestOptions: err.requestOptions,
        type: err.type,
        error: inner,
      ));
      return;
    }
    handler.next(err);
  }
}

/// 앱이 쓰는 dio 인스턴스를 만든다.
/// [reissue] 와 [onSessionExpired] 는 순환 의존을 피하려고 콜백으로 받는다.
Dio buildDio({
  required TokenStore tokenStore,
  required Future<AuthTokens> Function(String refreshToken) reissue,
  required Future<void> Function() onSessionExpired,
}) {
  final dio = Dio(BaseOptions(
    baseUrl: Env.apiBaseUrl,
    connectTimeout: Env.connectTimeout,
    receiveTimeout: Env.receiveTimeout,
    headers: {
      'Content-Type': 'application/json',
      'Origin': Env.webOrigin,
      'Referer': '${Env.webOrigin}/',
    },
    // 204/401을 예외가 아닌 응답으로 받아 인터셉터에서 처리한다.
    validateStatus: (status) => status != null && status < 500,
  ));

  dio.interceptors.add(AuthInterceptor(
    tokenStore: tokenStore,
    reissue: reissue,
    onSessionExpired: onSessionExpired,
    retryClient: dio,
  ));
  dio.interceptors.add(_UnwrapFailureInterceptor());

  return dio;
}

/// 로그인·재발급 전용 dio. 인터셉터가 없어 재발급 재귀가 생기지 않는다.
Dio buildAuthDio() => Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: Env.connectTimeout,
      receiveTimeout: Env.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Origin': Env.webOrigin,
        'Referer': '${Env.webOrigin}/',
      },
    ));
