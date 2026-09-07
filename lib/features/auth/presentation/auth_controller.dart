import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers.dart';
import '../../../core/error/failure.dart';
import '../../reference/presentation/term_providers.dart';
import '../data/auth_dto.dart';
import '../../notifications/notification_runtime.dart';

/// 세션 상태. 라우터가 이 값을 보고 로그인 화면 여부를 결정한다.
sealed class AuthState {
  const AuthState();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.profile});
  final UserProfile profile;
}

/// 이전 로그인 토큰이 있는 기기에서 연결 실패 시 캐시를 연다.
class AuthOffline extends AuthState {
  const AuthOffline();
}

/// 일시적 장애(네트워크 단절, 서버 5xx)인가?
/// 이런 실패로 저장된 토큰이나 자격증명을 지우면, 지하철에서 앱을 한 번 연
/// 것만으로 자동 로그인이 영구히 꺼지고 캐시까지 못 보게 된다.
bool _isTransient(Object error) {
  if (error is NetworkFailure) return true;
  if (error is ServerFailure) {
    final status = int.tryParse(error.code);
    return status != null && status >= 500;
  }
  return false;
}

class AuthController extends AsyncNotifier<AuthState> {
  int _generation = 0;
  @override
  Future<AuthState> build() => _restoreSession();

  /// 앱 시작 시 저장된 refreshToken으로 세션을 되살린다.
  /// 실패하면 자동 로그인이 켜져 있을 때만 자격증명으로 재시도한다.
  Future<AuthState> _restoreSession() async {
    final store = ref.read(tokenStoreProvider);
    final authApi = ref.read(authApiProvider);

    final refresh = await store.readRefreshToken();
    if (refresh != null && refresh.isNotEmpty) {
      try {
        final tokens = await authApi.reissue(refresh);
        if (!tokens.isValid) throw const AuthFailure();
        await store.saveTokens(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        );
        final profile = await authApi.fetchProfile();
        return AuthAuthenticated(profile: profile);
      } on Object catch (e) {
        // 서버 점검(5xx)이나 연결 실패로 토큰을 버리면 콜드 스타트 한 번에
        // 재로그인을 강요당한다. 진짜 인증 거부일 때만 토큰을 지운다.
        if (_isTransient(e)) return const AuthOffline();
        await store.clearTokens();
      }
    }

    return _autoLoginOrUnauthenticated();
  }

  /// 자동 로그인이 켜져 있으면 저장된 자격증명으로 다시 로그인하고,
  /// 아니면 미인증 상태로 떨어진다.
  Future<AuthState> _autoLoginOrUnauthenticated() async {
    final store = ref.read(tokenStoreProvider);
    final creds = await store.readCredentials();
    if (creds == null) return const AuthUnauthenticated();
    try {
      return await _performLogin(
        userId: creds.userId,
        password: creds.password,
        rememberMe: true,
      );
    } on Object catch (e) {
      // 일시적 장애면 자격증명을 지키고 캐시를 연다.
      if (_isTransient(e)) return const AuthOffline();
      await store.clearAll();
      return const AuthUnauthenticated();
    }
  }

  Future<AuthState> _performLogin({
    required String userId,
    required String password,
    required bool rememberMe,
  }) async {
    final store = ref.read(tokenStoreProvider);
    final authApi = ref.read(authApiProvider);

    final generation = _generation;
    final tokens = await authApi.login(userId: userId, password: password);
    if (!tokens.isValid) throw const AuthFailure();
    await store.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );

    if (rememberMe) {
      await store.saveCredentials(userId: userId, password: password);
    } else {
      await store.clearCredentials();
    }

    // 저장하는 동안 로그아웃이 끼어들었다면 방금 쓴 것을 되돌린다.
    // 그러지 않으면 로그아웃했는데도 토큰과 비밀번호가 디스크에 남아
    // 다음 실행에서 조용히 다시 로그인된다.
    if (generation != _generation) {
      await store.clearAll();
      return const AuthUnauthenticated();
    }
    final profile = await authApi.fetchProfile();
    return AuthAuthenticated(profile: profile);
  }

  Future<void> login({
    required String userId,
    required String password,
    required bool rememberMe,
  }) async {
    final generation = ++_generation;
    ref.read(cacheSessionProvider).end();
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() async {
      // 새 계정 토큰을 저장하기 전에 이전 계정 데이터를 비운다.
      // 프로필 조회가 실패한 뒤 오프라인 재시작해도 이전 캐시가 노출되지 않는다.
      await NotificationRuntime.stop(ref.read(appDatabaseProvider));
      await ref.read(appDatabaseProvider).wipe();
      final authenticated = await _performLogin(
        userId: userId,
        password: password,
        rememberMe: rememberMe,
      );
      ref.read(selectedTermIdProvider.notifier).state = null;
      ref.invalidate(activeTermIdProvider);
      return authenticated;
    });
    if (generation == _generation) {
      // Failure가 아닌 예외는 화면에 일반 문구로만 나와 원인을 알 수 없다.
      // 개발 중에 원인을 확인할 수 있도록 남긴다.
      final err = result.error;
      if (err != null && err is! Failure) {
        debugPrint('LOGIN_UNEXPECTED ${err.runtimeType}: $err');
      }
      _openCacheIfReadable(result);
      state = result;
    }
  }

  /// 읽을 수 있는 상태(인증/오프라인)로 복귀했으면 캐시 세션을 다시 연다.
  /// 이걸 빠뜨리면 리포지토리들이 조용히 no-op 해서 화면 네 개가 에러도 없이
  /// 텅 빈 채로 남는다.
  void _openCacheIfReadable(AsyncValue<AuthState> result) {
    final value = result.valueOrNull;
    if (value is AuthAuthenticated || value is AuthOffline) {
      ref.read(cacheSessionProvider).start();
    }
  }

  Future<void> retrySession() async {
    final generation = ++_generation;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(_restoreSession);
    if (generation == _generation) {
      _openCacheIfReadable(result);
      state = result;
      ref.invalidate(activeTermIdProvider);
    }
  }

  Future<void> logout() async {
    ++_generation;
    ref.read(cacheSessionProvider).end();
    // AsyncLoading으로 두면 라우터가 /loading으로 보내, 오프라인에서는
    // 서버 응답을 기다리는 내내 빠져나갈 수 없는 스피너에 갇힌다.
    final store = ref.read(tokenStoreProvider);
    final db = ref.read(appDatabaseProvider);
    // 저장소나 DB가 던지더라도 세션은 반드시 끝난 상태로 남겨야 한다.
    // 그러지 않으면 사용자가 쓸 수 없는 세션에 갇힌 채 로그인 화면으로도 못 간다.
    try {
      try {
        await NotificationRuntime.stop(db);
        await ref
            .read(authApiProvider)
            .logout()
            .timeout(const Duration(seconds: 5));
      } finally {
        try {
          await store.clearAll();
        } finally {
          await db.wipe();
        }
      }
    } finally {
      ref.read(selectedTermIdProvider.notifier).state = null;
      ref.read(refreshErrorProvider.notifier).state = null;
      ref.invalidate(activeTermIdProvider);
      state = const AsyncData(AuthUnauthenticated());
    }
  }

  /// 진행 중인 [handleSessionExpired] 복구. null이면 아무도 복구 중이 아니다.
  ///
  /// AuthInterceptor는 만료된 토큰으로 막혀 있던 요청들이 재발급에도 실패하면
  /// 각 요청이 독립적으로 이 콜백을 호출할 수 있다. 그대로 두면 동시에 쌓인
  /// N개의 요청이 학교 서버에 N번의 동시 로그인을 시도하게 되므로, 이미 진행
  /// 중인 복구가 있으면 새로 시작하지 않고 그 Future를 공유한다(single-flight).
  Future<void>? _sessionRecovery;

  /// 인터셉터가 재발급에 실패했을 때 호출된다.
  /// 자동 로그인이 켜져 있으면 조용히 다시 로그인한다.
  ///
  /// 동시에 여러 번 호출돼도 실제 복구(및 그 안의 로그인 시도)는 한 번만
  /// 일어난다 — 이미 진행 중이면 그 결과를 함께 기다린다.
  Future<void> handleSessionExpired() {
    return _sessionRecovery ??= _recoverSession().whenComplete(() {
      _sessionRecovery = null;
    });
  }

  Future<void> _recoverSession() async {
    final generation = _generation;
    final result = await _autoLoginOrUnauthenticated();
    if (generation == _generation) {
      _openCacheIfReadable(AsyncData(result));
      state = AsyncData(result);
    }
  }
}
