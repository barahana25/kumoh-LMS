import 'dart:async';

import 'package:dio/dio.dart';

import '../error/failure.dart';
import '../../features/auth/data/auth_dto.dart';
import 'token_store.dart';

/// RequestOptions.extra 에 저장하는 재시도 표시. 무한 재발급 루프를 막는다.
const String kRetryFlag = 'auth_retry';

/// 재발급 신호. 운영 웹앱은 204만 보지만 401도 방어적으로 함께 처리한다.
bool _needsReissue(int? statusCode) => statusCode == 204 || statusCode == 401;

/// 토큰 부착 + 만료 시 자동 재발급 + 원요청 재시도.
///
/// 동시에 여러 요청이 만료를 만나면 첫 요청만 재발급을 수행하고
/// 나머지는 [_waiters] 에 모였다가 새 토큰으로 한꺼번에 재개된다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStore tokenStore,
    required Future<AuthTokens> Function(String refreshToken) reissue,
    required Future<void> Function() onSessionExpired,
    required Dio retryClient,
  })  : _tokenStore = tokenStore,
        _reissue = reissue,
        _onSessionExpired = onSessionExpired,
        _retryClient = retryClient;

  final TokenStore _tokenStore;
  final Future<AuthTokens> Function(String refreshToken) _reissue;
  final Future<void> Function() _onSessionExpired;
  final Dio _retryClient;

  bool _refreshing = false;
  final List<Completer<String>> _waiters = [];

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final access = await _tokenStore.readAccessToken();
    final refresh = await _tokenStore.readRefreshToken();
    if (access != null && access.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    if (refresh != null && refresh.isNotEmpty) {
      options.headers['X-Refresh-Token'] = refresh;
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final options = response.requestOptions;
    final statusCode = response.statusCode;
    if (_shouldHandle(options, statusCode)) {
      await _recover(options, handler.resolve, handler.reject);
      return;
    }
    if (_isBlockedAuthError(options, statusCode)) {
      handler.reject(_authError(options));
      return;
    }
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final statusCode = err.response?.statusCode;
    if (_shouldHandle(options, statusCode)) {
      await _recover(options, handler.resolve, handler.reject);
      return;
    }
    if (_isBlockedAuthError(options, statusCode)) {
      handler.reject(_authError(options));
      return;
    }
    handler.next(err);
  }

  /// 재발급을 새로 시작해도 되는 상황: 인증 오류 상태이고, /reissue 요청이 아니며,
  /// 아직 재시도한 적 없는 원요청이다.
  bool _shouldHandle(RequestOptions options, int? statusCode) {
    if (!_needsReissueFor(statusCode)) return false;
    if (options.path.contains('/reissue')) return false;
    if (options.extra[kRetryFlag] == true) return false;
    return true;
  }

  /// 인증 오류 상태인데도 더 재발급을 시도할 수 없는 경우
  /// (이미 재시도한 요청이 새 토큰으로도 다시 204/401을 받았거나, /reissue 자체가 실패한 경우).
  /// 무한 루프 대신 곧장 AuthFailure로 거절한다. 세션 정리는 이 실패를 관찰하는
  /// 바깥쪽 [_recover] 호출(재발급 실패와 동일한 경로)이 한 번만 수행한다.
  bool _isBlockedAuthError(RequestOptions options, int? statusCode) {
    if (!_needsReissueFor(statusCode)) return false;
    return options.path.contains('/reissue') || options.extra[kRetryFlag] == true;
  }

  bool _needsReissueFor(int? statusCode) => _needsReissue(statusCode);

  /// 재발급 → 원요청 재시도. 실패하면 세션을 비우고 AuthFailure로 거절한다.
  Future<void> _recover(
    RequestOptions options,
    void Function(Response<dynamic>) resolve,
    void Function(DioException) reject,
  ) async {
    options.extra[kRetryFlag] = true;

    // 이미 다른 요청이 재발급 중이면 새 토큰을 기다렸다가 재개한다.
    if (_refreshing) {
      final waiter = Completer<String>();
      _waiters.add(waiter);
      try {
        final token = await waiter.future;
        resolve(await _replay(options, token));
      } on Object {
        reject(_authError(options));
      }
      return;
    }

    final refresh = await _tokenStore.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      await _failSession();
      reject(_authError(options));
      return;
    }

    _refreshing = true;
    try {
      final tokens = await _reissue(refresh);
      if (!tokens.isValid) {
        throw const AuthFailure();
      }
      await _tokenStore.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      _refreshing = false;
      for (final w in _waiters) {
        w.complete(tokens.accessToken);
      }
      _waiters.clear();

      resolve(await _replay(options, tokens.accessToken));
    } on Object catch (e) {
      _refreshing = false;
      for (final w in _waiters) {
        w.completeError(e);
      }
      _waiters.clear();
      await _failSession();
      reject(_authError(options));
    }
  }

  Future<Response<dynamic>> _replay(RequestOptions options, String accessToken) {
    options.headers['Authorization'] = 'Bearer $accessToken';
    return _retryClient.fetch<dynamic>(options);
  }

  Future<void> _failSession() async {
    await _tokenStore.clearTokens();
    await _onSessionExpired();
  }

  DioException _authError(RequestOptions options) => DioException(
        requestOptions: options,
        type: DioExceptionType.unknown,
        error: const AuthFailure(),
      );
}
