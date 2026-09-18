import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers.dart';
import '../announcements/presentation/announcements_providers.dart';
import '../auth/presentation/auth_controller.dart';
import '../notifications/presentation/background_setup_screen.dart';

/// 하단 탭 네비게이션 셸. 각 탭은 자기 네비게이션 스택을 유지한다.
class HomeShell extends ConsumerWidget {
  const HomeShell(
      {required this.navigationShell, this.branchKeys = const [], super.key});

  final StatefulNavigationShell navigationShell;

  /// 탭별 네비게이터. 지금 탭을 다시 누르면 그 위에 push한 화면(웹뷰 등)을 닫는다.
  final List<GlobalKey<NavigatorState>> branchKeys;

  void _select(int i) {
    if (i == navigationShell.currentIndex && i < branchKeys.length) {
      // Navigator.push로 띄운 화면은 go_router가 모르므로 직접 걷어낸다.
      // go_router 페이지(강좌 상세 등)는 아래 goBranch가 처음으로 되돌린다.
      branchKeys[i].currentState?.popUntil((route) => route.settings is Page);
    }
    navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNoticeCountProvider);
    return Scaffold(
      body: Column(children: [
        if (ref.watch(authControllerProvider).valueOrNull is AuthOffline)
          SafeArea(bottom: false, child: MaterialBanner(
            content: const Text('오프라인에서 저장된 데이터를 보고 있습니다.'),
            actions: [TextButton(
              onPressed: () => ref.read(authControllerProvider.notifier).retrySession(),
              child: const Text('다시 연결'),
            )],
          )),
        const BackgroundSetupLauncher(),
        Expanded(child: navigationShell),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _select,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '강의',
          ),
          const NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: '과제',
          ),
          NavigationDestination(
            icon: Badge.count(
              count: unread,
              isLabelVisible: unread > 0,
              child: const Icon(Icons.campaign_outlined),
            ),
            selectedIcon: Badge.count(
              count: unread,
              isLabelVisible: unread > 0,
              child: const Icon(Icons.campaign),
            ),
            label: '공지',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
