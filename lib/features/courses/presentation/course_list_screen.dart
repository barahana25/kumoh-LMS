import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/async_section.dart';
import '../../../core/ui/empty_state.dart';
import '../../../providers.dart';
import '../../reference/presentation/term_providers.dart';
import 'courses_providers.dart';
import 'widgets/course_card.dart';

class CourseListScreen extends ConsumerWidget {
  const CourseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termAsync = ref.watch(activeTermIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('강좌')),
      body: Column(
        children: [
          const RefreshBanner(),
          Expanded(
            child: termAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                icon: Icons.error_outline,
                title: '학기 정보를 불러오지 못했습니다',
                description: userMessage(e),
              ),
              data: (termId) {
                if (termId == null) {
                  return const EmptyState(
                    icon: Icons.calendar_today_outlined,
                    title: '학기 정보가 없습니다',
                  );
                }
                return _CourseList(key: ValueKey(termId), termId: termId);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseList extends ConsumerStatefulWidget {
  const _CourseList({required this.termId, super.key});
  final int termId;

  @override
  ConsumerState<_CourseList> createState() => _CourseListState();
}

class _CourseListState extends ConsumerState<_CourseList> {
  @override
  void initState() {
    super.initState();
    // 화면 진입 시 한 번 시도. TTL 안이면 리포지토리가 알아서 건너뛴다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh({bool force = false}) => runRefresh(
        ref,
        () => ref
            .read(coursesRepositoryProvider)
            .refresh(widget.termId, force: force),
      );

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider(widget.termId));

    return RefreshIndicator(
      onRefresh: () => _refresh(force: true),
      child: coursesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: '강좌를 불러오지 못했습니다',
          description: userMessage(e),
        ),
        data: (courses) {
          if (courses.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: '수강 중인 강좌가 없습니다',
                  description: '아래로 당겨 새로고침해 보세요.',
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: courses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => CourseCard(course: courses[i]),
          );
        },
      ),
    );
  }
}
