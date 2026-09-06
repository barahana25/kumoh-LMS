import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:intl/intl.dart';

import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/open_link.dart';
import '../../../../providers.dart';
import '../../data/canvas_api.dart';

// ---------- providers ----------

final courseSyllabusProvider = FutureProvider.family<String?, int>(
  (ref, courseId) => ref.watch(canvasApiProvider).fetchSyllabus(courseId),
);

final courseModulesProvider = FutureProvider.family<List<CanvasModule>, int>(
  (ref, courseId) => ref.watch(canvasApiProvider).fetchModules(courseId),
);

final courseFilesProvider = FutureProvider.family<List<CanvasFile>, int>(
  (ref, courseId) => ref.watch(canvasApiProvider).fetchFiles(courseId),
);

final courseDiscussionsProvider =
    FutureProvider.family<List<CanvasDiscussion>, int>(
  (ref, courseId) => ref.watch(canvasApiProvider).fetchDiscussions(courseId),
);

final courseGradeProvider = FutureProvider.family<CanvasGrade?, int>(
  (ref, courseId) => ref.watch(canvasApiProvider).fetchMyGrade(courseId),
);

final coursePeopleProvider = FutureProvider.family<
    ({List<CanvasPerson> people, List<CanvasGroup> groups}), int>(
  (ref, courseId) async {
    final api = ref.watch(canvasApiProvider);
    final people = await api.fetchPeople(courseId);
    // 그룹이 없는 강좌가 흔하다. 그룹 조회 실패가 명단을 막지 않게 한다.
    List<CanvasGroup> groups = const [];
    try {
      groups = await api.fetchGroups(courseId);
    } on Object {
      groups = const [];
    }
    return (people: people, groups: groups);
  },
);

// ---------- 공통 껍데기 ----------

/// 로딩·오류·빈 상태를 한 곳에서 처리한다. 탭마다 다르게 처리하면
/// 어떤 탭은 raw 예외를 노출하는 식으로 어긋난다.
class _TabBody<T> extends ConsumerWidget {
  const _TabBody({
    required this.provider,
    required this.errorTitle,
    required this.builder,
    super.key,
  });

  final ProviderListenable<AsyncValue<T>> provider;
  final String errorTitle;
  final Widget Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(provider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(
            icon: Icons.error_outline,
            title: errorTitle,
            description: userMessage(e),
          ),
          data: (data) => builder(context, data),
        );
  }
}

// ---------- 강의 계획 ----------

class SyllabusTab extends StatelessWidget {
  const SyllabusTab({required this.courseId, super.key});
  final int courseId;

  @override
  Widget build(BuildContext context) {
    return _TabBody<String?>(
      provider: courseSyllabusProvider(courseId),
      errorTitle: '강의 계획을 불러오지 못했습니다',
      builder: (context, html) {
        if (html == null) {
          return const EmptyState(
            icon: Icons.description_outlined,
            title: '등록된 강의 계획이 없습니다',
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: HtmlWidget(
            html,
            textStyle: Theme.of(context).textTheme.bodyMedium,
            onTapUrl: (url) => openLink(context, url),
          ),
        );
      },
    );
  }
}

// ---------- 강의실(모듈) ----------

class ModulesTab extends StatelessWidget {
  const ModulesTab({required this.courseId, super.key});
  final int courseId;

  @override
  Widget build(BuildContext context) {
    return _TabBody<List<CanvasModule>>(
      provider: courseModulesProvider(courseId),
      errorTitle: '강의실을 불러오지 못했습니다',
      builder: (context, mods) {
        if (mods.isEmpty) {
          return const EmptyState(
            icon: Icons.view_module_outlined,
            title: '등록된 학습 모듈이 없습니다',
          );
        }
        final scheme = Theme.of(context).colorScheme;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: mods.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final m = mods[i];
            return Card(
              child: ListTile(
                leading: Icon(
                  m.locked
                      ? Icons.lock_outline
                      : m.completed
                          ? Icons.check_circle_outline
                          : Icons.play_circle_outline,
                  color: m.locked ? scheme.outline : scheme.primary,
                ),
                title: Text(m.name),
                subtitle: Text(
                  m.locked ? '잠김' : '항목 ${m.itemsCount}개',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.outline),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------- 강의자료실 ----------

String formatBytes(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class FilesTab extends StatelessWidget {
  const FilesTab({required this.courseId, super.key});
  final int courseId;

  @override
  Widget build(BuildContext context) {
    return _TabBody<List<CanvasFile>>(
      provider: courseFilesProvider(courseId),
      errorTitle: '강의자료를 불러오지 못했습니다',
      builder: (context, files) {
        if (files.isEmpty) {
          return const EmptyState(
            icon: Icons.folder_outlined,
            title: '등록된 강의자료가 없습니다',
          );
        }
        final scheme = Theme.of(context).colorScheme;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: files.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final f = files[i];
            return Card(
              child: ListTile(
                leading: Icon(
                  f.locked ? Icons.lock_outline : Icons.insert_drive_file_outlined,
                  color: f.locked ? scheme.outline : scheme.primary,
                ),
                title: Text(f.displayName),
                subtitle: Text(
                  f.locked ? '잠긴 자료입니다' : formatBytes(f.sizeBytes),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.outline),
                ),
                onTap: (f.locked || f.url.isEmpty)
                    ? null
                    : () => openLink(context, f.url),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------- 성적 ----------

class GradesTab extends StatelessWidget {
  const GradesTab({required this.courseId, super.key});
  final int courseId;

  @override
  Widget build(BuildContext context) {
    return _TabBody<CanvasGrade?>(
      provider: courseGradeProvider(courseId),
      errorTitle: '성적을 불러오지 못했습니다',
      builder: (context, grade) {
        if (grade == null || grade.isEmpty) {
          return const EmptyState(
            icon: Icons.grade_outlined,
            title: '아직 공개된 성적이 없습니다',
            description: '교수가 성적을 공개하면 여기에 표시됩니다.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _GradeCard(
              label: '현재 성적',
              score: grade.currentScore,
              letter: grade.currentGrade,
            ),
            const SizedBox(height: 12),
            _GradeCard(
              label: '최종 성적',
              score: grade.finalScore,
              letter: grade.finalGrade,
            ),
          ],
        );
      },
    );
  }
}

class _GradeCard extends StatelessWidget {
  const _GradeCard({required this.label, this.score, this.letter});

  final String label;
  final num? score;
  final String? letter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = [
      if (letter != null) letter!,
      if (score != null) '$score점',
    ].join(' · ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            Text(
              value.isEmpty ? '—' : value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: scheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- 토론 ----------

class DiscussionsTab extends StatelessWidget {
  const DiscussionsTab({required this.courseId, super.key});
  final int courseId;

  @override
  Widget build(BuildContext context) {
    return _TabBody<List<CanvasDiscussion>>(
      provider: courseDiscussionsProvider(courseId),
      errorTitle: '토론을 불러오지 못했습니다',
      builder: (context, items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.forum_outlined,
            title: '등록된 토론이 없습니다',
          );
        }
        final scheme = Theme.of(context).colorScheme;
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final d = items[i];
            final meta = [
              if (d.postedAt != null)
                DateFormat('M월 d일', 'ko_KR').format(d.postedAt!.toLocal()),
              '댓글 ${d.replyCount}개',
            ].join(' · ');
            return Card(
              child: ListTile(
                title: Text(d.title),
                subtitle: Text(
                  meta,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.outline),
                ),
                onTap: d.htmlUrl.isEmpty
                    ? null
                    : () => openLink(context, d.htmlUrl),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------- 사용자 및 그룹 ----------

class PeopleTab extends StatelessWidget {
  const PeopleTab({required this.courseId, super.key});
  final int courseId;

  @override
  Widget build(BuildContext context) {
    return _TabBody<({List<CanvasPerson> people, List<CanvasGroup> groups})>(
      provider: coursePeopleProvider(courseId),
      errorTitle: '구성원을 불러오지 못했습니다',
      builder: (context, data) {
        if (data.people.isEmpty && data.groups.isEmpty) {
          return const EmptyState(
            icon: Icons.people_outline,
            title: '구성원 정보가 없습니다',
          );
        }
        final teachers = data.people.where((p) => p.isTeacher).toList();
        final students = data.people.where((p) => !p.isTeacher).toList();
        final scheme = Theme.of(context).colorScheme;

        Widget header(String text) => Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Text(text,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: scheme.outline)),
            );

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            if (teachers.isNotEmpty) ...[
              header('교수 · 조교'),
              for (final p in teachers) _PersonTile(person: p),
            ],
            if (data.groups.isNotEmpty) ...[
              header('그룹'),
              for (final g in data.groups)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: Text(g.name),
                    subtitle: Text('${g.membersCount}명'),
                  ),
                ),
            ],
            if (students.isNotEmpty) ...[
              header('수강생 ${students.length}명'),
              for (final p in students) _PersonTile(person: p),
            ],
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person});
  final CanvasPerson person;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          child: Text(
            person.name.isEmpty ? '?' : person.name.characters.first,
          ),
        ),
        title: Text(person.name),
      ),
    );
  }
}
