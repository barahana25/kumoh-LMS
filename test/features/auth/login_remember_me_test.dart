import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/features/auth/presentation/login_screen.dart';
import 'package:kumoh_lms/providers.dart';

void main() {
  Widget app(LoginScreen screen) => ProviderScope(
        overrides: [tokenStoreProvider.overrideWithValue(InMemoryTokenStore())],
        child: MaterialApp(home: screen),
      );

  testWidgets('자동 로그인을 허용하지 않으면 스위치를 숨긴다', (tester) async {
    await tester.pumpWidget(app(const LoginScreen(allowRememberMe: false)));
    expect(find.text('자동 로그인'), findsNothing);
  });

  testWidgets('기본값(네이티브)은 자동 로그인 스위치를 보여준다', (tester) async {
    await tester.pumpWidget(app(const LoginScreen()));
    expect(find.text('자동 로그인'), findsOneWidget);
  });
}
