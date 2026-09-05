import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers.dart';
import '../data/auth_dto.dart';

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

class AuthController extends AsyncNotifier<AuthState> {
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
        await store.saveTokens(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        );
        final profile = await authApi.fetchProfile();
        return AuthAuthenticated(profile: profile);
      } on Object {
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
    } on Object {
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

    final tokens = await authApi.login(userId: userId, password: password);
    await store.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );

    if (rememberMe) {
      await store.saveCredentials(userId: userId, password: password);
    } else {
      await store.clearCredentials();
    }

    final profile = await authApi.fetchProfile();
    return AuthAuthenticated(profile: profile);
  }

  Future<void> login({
    required String userId,
    required String password,
    required bool rememberMe,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _performLogin(
        userId: userId,
        password: password,
        rememberMe: rememberMe,
      ),
    );
  }

  Future<void> logout() async {
    final store = ref.read(tokenStoreProvider);
    final db = ref.read(appDatabaseProvider);
    await ref.read(authApiProvider).logout();
    await store.clearAll();
    await db.wipe();
    state = const AsyncData(AuthUnauthenticated());
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
    final result = await _autoLoginOrUnauthenticated();
    state = AsyncData(result);
  }
}
