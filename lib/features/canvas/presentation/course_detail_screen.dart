import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/empty_state.dart';
import '../../../providers.dart';
import 'tabs/course_tab_view.dart';

/// 강좌 하나의 상세. 탭 구성은 강좌마다 다르므로 서버가 준 목록을 그대로 그린다.
class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({
    required this.courseId,
    required this.courseName,
    super.key,
  });

  final int courseId;
  final String courseName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabsAsync = ref.watch(courseTabsProvider(courseId));

    return tabsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(courseName)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(courseName)),
        body: EmptyState(
          icon: Icons.error_outline,
          title: '강좌를 열지 못했습니다',
          description: userMessage(e),
        ),
      ),
      data: (tabs) {
        if (tabs.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(courseName)),
            body: const EmptyState(
              icon: Icons.tab_unselected,
              title: '표시할 탭이 없습니다',
              description: '이 강좌는 아직 열려 있는 메뉴가 없습니다.',
            ),
          );
        }
        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: Text(courseName),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [for (final t in tabs) Tab(text: t.label)],
              ),
            ),
            body: TabBarView(
              children: [
                for (final t in tabs)
                  CourseTabView(courseId: courseId, tab: t),
              ],
            ),
          ),
        );
      },
    );
  }
}
