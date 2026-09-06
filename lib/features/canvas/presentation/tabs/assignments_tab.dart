import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/open_link.dart';
import '../../../../core/config/env.dart';
import '../../../../providers.dart';
import '../../data/canvas_cache.dart';
import 'stale_notice.dart';
import '../../data/canvas_api.dart';

/// 과제 목록 + 내 제출 상태.
typedef AssignmentsData = ({
  List<CanvasAssignment> items,
  Map<int, CanvasSubmission> submissions,
});

/// 과제는 마감일이 걸려 있어 낡은 값을 최신인 척 보여주면 실제 손해가 난다.
/// 캐시는 즉시 그리되 온라인이면 반드시 다시 받는다.
final courseAssignmentsProvider =
    StreamProvider.family<CanvasSnapshot<AssignmentsData>, int>((ref, courseId) {
  final api = ref.watch(canvasApiProvider);
  return watchCanvas<AssignmentsData>(
    cache: ref.watch(canvasCacheProvider),
    key: 'assignments:$courseId',
    ttl: Env.canvasAlwaysRevalidate,
    fetch: () async => {
      'assignments': await api.getRaw(
        '/courses/$courseId/assignments',
        query: const {'per_page': 50, 'order_by': 'due_at'},
      ),
      // 제출 상태가 없어도 과제는 보여줄 수 있다. 실패해도 목록을 막지 않는다.
      'submissions': await () async {
        try {
          return await api.getRaw(
            '/courses/$courseId/students/submissions',
            query: const {'per_page': 50, 'student_ids[]': 'self'},
          );
        } on Object {
          return const <Object>[];
        }
      }(),
    },
    parse: (json) {
      final map = json! as Map;
      return (
        items: parseAssignments(map['assignments']),
        submissions: parseSubmissions(map['submissions']),
      );
    },
  );
});

String formatDue(DateTime? at) {
  if (at == null) return '기한 없음';
  return DateFormat('M월 d일 (E) HH:mm', 'ko_KR').format(at.toLocal());
}

class AssignmentsTab extends ConsumerWidget {
  const AssignmentsTab({required this.courseId, super.key});

  final int courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(courseAssignmentsProvider(courseId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: '과제를 불러오지 못했습니다',
        description: userMessage(e),
      ),
      data: (snap) {
        final data = snap.data;
        if (data.items.isEmpty) {
          return const EmptyState(
            icon: Icons.assignment_outlined,
            title: '등록된 과제가 없습니다',
          );
        }
        return Column(
          children: [
            if (snap.stale)
              StaleNotice(fetchedAt: snap.fetchedAt, error: snap.error),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(courseAssignmentsProvider(courseId)),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _AssignmentCard(
                    assignment: data.items[i],
                    submission: data.submissions[data.items[i].id],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.assignment, this.submission});

  final CanvasAssignment assignment;
  final CanvasSubmission? submission;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final meta = [
      formatDue(assignment.dueAt),
      if (assignment.pointsPossible != null) '${assignment.pointsPossible}점',
    ].join(' · ');

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(assignment.name),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            meta,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.outline),
          ),
        ),
        trailing: _StatusChip(submission: submission),
        onTap: assignment.htmlUrl.isEmpty
            ? null
            : () => openLink(context, assignment.htmlUrl),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({this.submission});

  final CanvasSubmission? submission;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (String label, Color bg, Color fg) = switch (submission) {
      null => ('미확인', scheme.surfaceContainerHighest, scheme.outline),
      final s when s.submitted => ('제출함', scheme.primaryContainer, scheme.onPrimaryContainer),
      final s when s.missing => ('미제출', scheme.errorContainer, scheme.onErrorContainer),
      _ => ('대기', scheme.surfaceContainerHighest, scheme.outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
