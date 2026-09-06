import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/env.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../providers.dart';
import '../../data/canvas_api.dart';
import '../../data/canvas_cache.dart';
import '../canvas_web_target.dart';
import 'assignments_tab.dart';
import 'content_tabs.dart';
import 'stale_notice.dart';

/// 강좌가 홈에 무엇을 띄울지는 강좌마다 다르다(`default_view`).
/// 웹과 다르게 보이지 않도록 그 설정을 그대로 따른다.
final courseHomeViewProvider =
    StreamProvider.family<CanvasSnapshot<String>, int>((ref, courseId) {
  final api = ref.watch(canvasApiProvider);
  return watchCanvas<String>(
    cache: ref.watch(canvasCacheProvider),
    key: 'home_view:$courseId',
    // 홈 구성은 학기 중 거의 바뀌지 않는다.
    ttl: Env.canvasStableTtl,
    fetch: () => api.getRaw('/courses/$courseId'),
    parse: parseDefaultView,
  );
});

final courseFrontPageProvider =
    StreamProvider.family<CanvasSnapshot<String?>, int>((ref, courseId) {
  final api = ref.watch(canvasApiProvider);
  return watchCanvas<String?>(
    cache: ref.watch(canvasCacheProvider),
    key: 'front_page:$courseId',
    ttl: Env.canvasAlwaysRevalidate,
    fetch: () => api.getRaw('/courses/$courseId/front_page'),
    parse: parseFrontPage,
  );
});

final courseCanvasAnnouncementsProvider =
    StreamProvider.family<CanvasSnapshot<List<CanvasDiscussion>>, int>(
        (ref, courseId) {
  final api = ref.watch(canvasApiProvider);
  return watchCanvas<List<CanvasDiscussion>>(
    cache: ref.watch(canvasCacheProvider),
    key: 'course_announcements:$courseId',
    ttl: Env.canvasAlwaysRevalidate,
    fetch: () => api.getRaw(
      '/courses/$courseId/discussion_topics',
      query: const {'per_page': 30, 'only_announcements': true},
    ),
    parse: parseDiscussions,
  );
});

/// 강좌 홈. 무엇을 보여줄지는 강좌 설정을 따른다.
class HomeTab extends ConsumerWidget {
  const HomeTab({required this.courseId, super.key});

  final int courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(courseHomeViewProvider(courseId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(
            icon: Icons.error_outline,
            title: '홈을 불러오지 못했습니다',
            description: userMessage(e),
          ),
          data: (snap) => switch (snap.data) {
            'modules' => ModulesTab(courseId: courseId),
            'syllabus' => SyllabusTab(courseId: courseId),
            'assignments' => AssignmentsTab(courseId: courseId),
            'wiki' => _FrontPage(courseId: courseId),
            'feed' => _CourseFeed(courseId: courseId),
            // Canvas가 새 종류를 추가할 수 있다. 조용히 빈 화면을 두면
            // 학생이 "강좌에 내용이 없다"고 오해하므로 분명히 말한다.
            _ => EmptyState(
                icon: Icons.help_outline,
                title: '홈 화면 종류(${snap.data})를 앱에서 지원하지 않습니다',
                description: '다른 탭에서 내용을 확인할 수 있습니다.',
              ),
          },
        );
  }
}

class _FrontPage extends ConsumerWidget {
  const _FrontPage({required this.courseId});
  final int courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(courseFrontPageProvider(courseId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(
            icon: Icons.error_outline,
            title: '홈을 불러오지 못했습니다',
            description: userMessage(e),
          ),
          data: (snap) {
            final html = snap.data;
            if (html == null) {
              return const EmptyState(
                icon: Icons.home_outlined,
                title: '홈에 등록된 내용이 없습니다',
              );
            }
            return Column(
              children: [
                if (snap.stale)
                  StaleNotice(fetchedAt: snap.fetchedAt, error: snap.error),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: HtmlWidget(
                      html,
                      textStyle: Theme.of(context).textTheme.bodyMedium,
                      onTapUrl: (url) async {
                        await openCanvasPage(context, title: '홈', url: url);
                        return true;
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        );
  }
}

class _CourseFeed extends ConsumerWidget {
  const _CourseFeed({required this.courseId});
  final int courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return ref.watch(courseCanvasAnnouncementsProvider(courseId)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(
            icon: Icons.error_outline,
            title: '홈을 불러오지 못했습니다',
            description: userMessage(e),
          ),
          data: (snap) {
            final items = snap.data;
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.campaign_outlined,
                title: '최근 소식이 없습니다',
              );
            }
            return Column(
              children: [
                if (snap.stale)
                  StaleNotice(fetchedAt: snap.fetchedAt, error: snap.error),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final d = items[i];
                      return Card(
                        child: ListTile(
                          title: Text(d.title),
                          subtitle: d.postedAt == null
                              ? null
                              : Text(
                                  DateFormat('M월 d일', 'ko_KR')
                                      .format(d.postedAt!.toLocal()),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: scheme.outline),
                                ),
                          onTap: d.htmlUrl.isEmpty
                              ? null
                              : () => openCanvasPage(context,
                                  title: d.title, url: d.htmlUrl),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
  }
}
