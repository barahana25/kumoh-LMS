import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:intl/intl.dart';

import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/open_link.dart';
import '../../../../core/config/env.dart';
import '../../../../providers.dart';
import '../../data/canvas_api.dart';
import '../../data/canvas_cache.dart';
import 'stale_notice.dart';

// ---------- providers ----------
//
// TTL 0 = 온라인이면 항상 다시 받는다. 언제 바뀔지 모르는 자료·토론·모듈까지
// TTL로 요청을 건너뛰면 학생이 새 내용을 놓친다. 캐시는 첫 화면과 오프라인용.
// 강의 계획과 구성원 명단만 학기 초 이후 거의 안 바뀌므로 24시간을 둔다.

final courseSyllabusProvider =
    StreamProvider.family<CanvasSnapshot<String?>, int>((ref, courseId) {
  final api = ref.watch(canvasApiProvider);
  return watchCanvas<String?>(
    cache: ref.watch(canvasCacheProvider),
    key: 'syllabus:$courseId',
    ttl: Env.canvasStableTtl,
    fetch: () => api.getRaw('/courses/$courseId',
        query: const {'include[]': 'syllabus_body'}),
    parse: parseSyllabus,
  );
});

final courseModulesProvider =
    StreamProvider.family<CanvasSnapshot<List<CanvasModule>>, int>(
        (ref, courseId) {
  final api = ref.watch(canvasApiProvider);
  return watchCanvas<List<CanvasModule>>(
    cache: ref.watch(canvasCacheProvider),
    key: 'modules:$courseId',
    ttl: Env.canvasAlwaysRevalidate,
    fetch: () =>
        api.getRaw('/courses/$courseId/modules', query: const {'per_page': 50}),
    parse: parseModules,
  );
});

final courseFilesProvider =
    StreamProvider.family<CanvasSnapshot<List<CanvasFile>>, int>(
        (ref, courseId) {
  final api = ref.watch(canvasApiProvider);
  return watchCanvas<List<CanvasFile>>(
    cache: ref.watch(canvasCacheProvider),
    key: 'files:$courseId',
    ttl: Env.canvasAlwaysRevalidate,
    fetch: () => api.getRaw('/courses/$courseId/files',
        query: const {'per_page': 50, 'sort': 'created_at', 'order': 'desc'}),
    parse: parseFiles,
  );
});

final courseDiscussionsProvider =
    StreamProvider.family<CanvasSnapshot<List<CanvasDiscussion>>, int>(
        (ref, courseId) {
  final api = ref.watch(canvasApiProvider);
  return watchCanvas<List<CanvasDiscussion>>(
    cache: ref.watch(canvasCacheProvider),
    key: 'discussions:$courseId',
    ttl: Env.canvasAlwaysRevalidate,
    fetch: () => api.getRaw('/courses/$courseId/discussion_topics',
        query: const {'per_page': 50}),
    parse: parseDiscussions,
  );
});

final courseGradeProvider =
    StreamProvider.family<CanvasSnapshot<CanvasGrade?>, int>((ref, courseId) {
  final api = ref.watch(canvasApiProvider);
  return watchCanvas<CanvasGrade?>(
    cache: ref.watch(canvasCacheProvider),
    key: 'grade:$courseId',
    ttl: Env.canvasAlwaysRevalidate,
    fetch: () => api.getRaw('/users/self/enrollments',
        query: const {'per_page': 100, 'state[]': 'active'}),
    parse: (json) => parseMyGrade(json, courseId),
  );
});

typedef PeopleData = ({List<CanvasPerson> people, List<CanvasGroup> groups});

final coursePeopleProvider =
    StreamProvider.family<CanvasSnapshot<PeopleData>, int>((ref, courseId) {
  final api = ref.watch(canvasApiProvider);
  return watchCanvas<PeopleData>(
    cache: ref.watch(canvasCacheProvider),
    key: 'people:$courseId',
    ttl: Env.canvasStableTtl,
    fetch: () async => {
      'people': await api
          .getRaw('/courses/$courseId/enrollments', query: const {'per_page': 100}),
      // 그룹이 없는 강좌가 흔하다. 그룹 실패가 명단을 막지 않게 한다.
      'groups': await () async {
        try {
          return await api.getRaw('/courses/$courseId/groups',
              query: const {'per_page': 50});
        } on Object {
          return const <Object>[];
        }
      }(),
    },
    parse: (json) {
      final map = json! as Map;
      return (
        people: parsePeople(map['people']),
        groups: parseGroups(map['groups']),
      );
    },
  );
});

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

  final ProviderListenable<AsyncValue<CanvasSnapshot<T>>> provider;
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
          data: (snap) => Column(
            children: [
              if (snap.stale)
                StaleNotice(fetchedAt: snap.fetchedAt, error: snap.error),
              Expanded(child: builder(context, snap.data)),
            ],
          ),
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
