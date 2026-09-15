import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kumoh_lms/features/announcements/presentation/announcements_providers.dart';
import 'package:kumoh_lms/features/shell/home_shell.dart';

void main() {
  testWidgets('지금 탭을 다시 누르면 그 위에 띄운 화면을 닫는다', (tester) async {
    final keys = List.generate(4, (_) => GlobalKey<NavigatorState>());
    Widget page(String name) => Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('웹뷰')))),
              child: Text(name),
            ),
          ),
        );
    final router = GoRouter(initialLocation: '/announcements', routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) =>
            HomeShell(navigationShell: shell, branchKeys: keys),
        branches: [
          for (final (i, path) in ['/courses', '/assignments', '/announcements', '/settings'].indexed)
            StatefulShellBranch(navigatorKey: keys[i], routes: [
              GoRoute(path: path, builder: (_, __) => page(path)),
            ]),
        ],
      ),
    ]);
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [unreadNoticeCountProvider.overrideWith((ref) => 0)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('/announcements'));
    await tester.pumpAndSettle();
    expect(find.text('웹뷰'), findsOneWidget);

    await tester.tap(find.text('공지'));
    await tester.pumpAndSettle();

    expect(find.text('웹뷰'), findsNothing);
    expect(find.text('/announcements'), findsOneWidget);
  });
}
