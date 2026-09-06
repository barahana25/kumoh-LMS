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

class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authControllerProvider, (_, __) => refresh.refresh());
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
      GoRoute(path: '/loading', builder: (_, __) => const Scaffold(
        body: Center(child: CircularProgressIndicator(semanticsLabel: '세션 복원 중')),
      )),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => HomeShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/courses',
              builder: (_, __) => const CourseListScreen(),
              routes: [
                GoRoute(
                  path: ':courseId',
                  builder: (_, state) => CourseDetailScreen(
                    courseId: int.tryParse(state.pathParameters['courseId'] ?? '') ?? 0,
                    courseName: state.uri.queryParameters['name'] ?? '강좌',
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/assignments', builder: (_, __) => const AssignmentsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/announcements', builder: (_, __) => const AnnouncementsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen())]),
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
