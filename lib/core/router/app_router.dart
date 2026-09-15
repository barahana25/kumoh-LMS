import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/announcements/presentation/announcements_screen.dart';
import '../../features/assignments/presentation/assignments_screen.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/canvas/presentation/course_detail_screen.dart';
import '../../features/courses/presentation/course_list_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/home_shell.dart';
import '../../providers.dart';
import '../ui/startup_screen.dart';

class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authControllerProvider, (_, __) => refresh.refresh());
  // 탭을 다시 눌렀을 때 그 탭 위에 띄운 웹뷰·화면을 걷어내려고 탭마다 둔다.
  final branchKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());
  final router = GoRouter(
    initialLocation: '/courses',
    refreshListenable: refresh,
    redirect: (_, route) {
      final auth = ref.read(authControllerProvider);
      final location = route.matchedLocation;
      if (auth.isLoading) {
        // 로그인 제출 중에는 폼을 유지하고 최초 복원 중에는 보호 화면을 열지 않는다.
        return location == '/login' || location == '/loading' ? null : '/loading';
      }
      final canRead = auth.valueOrNull is AuthAuthenticated || auth.valueOrNull is AuthOffline;
      if (!canRead) return location == '/login' ? null : '/login';
      return location == '/login' || location == '/loading' ? '/courses' : null;
    },
    routes: [
      GoRoute(path: '/loading', builder: (_, __) => const StartupScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) =>
            HomeShell(navigationShell: shell, branchKeys: branchKeys),
        branches: [
          StatefulShellBranch(navigatorKey: branchKeys[0], routes: [
            GoRoute(
              path: '/courses',
              builder: (_, __) => const CourseListScreen(),
              routes: [
                GoRoute(
                  path: ':courseId',
                  builder: (_, state) => CourseDetailScreen(
                    courseId: int.tryParse(state.pathParameters['courseId'] ?? '') ?? 0,
                    courseName: state.uri.queryParameters['name'] ?? '강좌',
                    initialTab: state.uri.queryParameters['tab'],
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(navigatorKey: branchKeys[1], routes: [GoRoute(path: '/assignments', builder: (_, __) => const AssignmentsScreen())]),
          StatefulShellBranch(navigatorKey: branchKeys[2], routes: [GoRoute(path: '/announcements', builder: (_, __) => const AnnouncementsScreen())]),
          StatefulShellBranch(navigatorKey: branchKeys[3], routes: [GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen())]),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
