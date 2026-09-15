import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/features/auth/presentation/install_hint.dart';
import 'package:kumoh_lms/features/auth/presentation/login_screen.dart';
import 'package:kumoh_lms/providers.dart';

void main() {
  Widget app(Widget child) => ProviderScope(
        overrides: [tokenStoreProvider.overrideWithValue(InMemoryTokenStore())],
        child: MaterialApp(home: child),
      );

  testWidgets('설치 안내는 Safari 공유 → 홈 화면에 추가 순서를 알려준다', (tester) async {
    await tester.pumpWidget(app(const Scaffold(body: InstallHint())));
    expect(find.textContaining('홈 화면에 추가'), findsOneWidget);
  });

  testWidgets('로그인 화면은 요청할 때만 설치 안내를 보여준다', (tester) async {
    await tester.pumpWidget(app(const LoginScreen(showInstallHint: true)));
    expect(find.byType(InstallHint), findsOneWidget);

    await tester.pumpWidget(app(const LoginScreen(showInstallHint: false)));
    expect(find.byType(InstallHint), findsNothing);
  });
}
