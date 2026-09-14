import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/features/auth/data/auth_dto.dart';
import 'package:kumoh_lms/features/auth/presentation/auth_controller.dart';
import 'package:kumoh_lms/providers.dart';

/// 브릿지와 내장 웹 화면은 같은 신원 값을 IdP 쿠키에 심는다.
/// SSO 패치 이후 IdP는 학번 평문을 거부(S010)하므로 accessToken이어야 한다.
void main() {
  Future<ProviderContainer> containerWith(AuthState state) async {
    final store = InMemoryTokenStore();
    await store.saveTokens(accessToken: 'signed.jwt.token', refreshToken: 'r');
    final container = ProviderContainer(overrides: [
      tokenStoreProvider.overrideWithValue(store),
      authControllerProvider.overrideWith(() => _FixedAuth(state)),
    ]);
    await container.read(authControllerProvider.future);
    return container;
  }

  test('인증 상태면 학번이 아니라 accessToken을 돌려준다', () async {
    final container = await containerWith(const AuthAuthenticated(
        profile: UserProfile(loginId: '20250001', name: '홍', role: 'student')));
    addTearDown(container.dispose);

    expect(await container.read(canvasIdentityTokenProvider)(),
        'signed.jwt.token');
  });

  test('로그인 전에는 토큰 저장소를 읽지 않고 null을 돌려준다', () async {
    final container = await containerWith(const AuthUnauthenticated());
    addTearDown(container.dispose);

    expect(await container.read(canvasIdentityTokenProvider)(), isNull);
  });
}

class _FixedAuth extends AuthController {
  _FixedAuth(this.state_);
  final AuthState state_;
  @override
  Future<AuthState> build() async => state_;
}
