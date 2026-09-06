import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/env.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../providers.dart';
import '../../data/canvas_api.dart';
import '../../data/canvas_cache.dart';
import '../canvas_file_open.dart';
import '../canvas_web_target.dart';
import 'stale_notice.dart';

typedef ModuleRef = ({int courseId, int moduleId});

/// 주차 안의 항목. 자료가 추가되는 즉시 보여야 하므로 항상 다시 받는다.
final moduleItemsProvider =
    StreamProvider.family<CanvasSnapshot<List<CanvasModuleItem>>, ModuleRef>(
        (ref, key) {
  final api = ref.watch(canvasApiProvider);
  return watchCanvas<List<CanvasModuleItem>>(
    cache: ref.watch(canvasCacheProvider),
    key: 'module_items:${key.courseId}:${key.moduleId}',
    ttl: Env.canvasAlwaysRevalidate,
    fetch: () => api.getRaw(
      '/courses/${key.courseId}/modules/${key.moduleId}/items',
      query: const {'per_page': 100},
    ),
    parse: parseModuleItems,
  );
});

/// 한 주차에 들어 있는 자료·과제 목록.
class ModuleItemsScreen extends ConsumerWidget {
  const ModuleItemsScreen({
    required this.courseId,
    required this.moduleId,
    required this.moduleName,
    super.key,
  });

  final int courseId;
  final int moduleId;
  final String moduleName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async =
        ref.watch(moduleItemsProvider((courseId: courseId, moduleId: moduleId)));

    return Scaffold(
      appBar: AppBar(title: Text(moduleName)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: '항목을 불러오지 못했습니다',
          description: userMessage(e),
        ),
        data: (snap) {
          final items = snap.data;
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.inbox_outlined,
              title: '이 주차에는 등록된 항목이 없습니다',
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
                  itemBuilder: (_, i) =>
                      _ItemTile(courseId: courseId, item: items[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({required this.courseId, required this.item});

  final int courseId;
  final CanvasModuleItem item;

  static const _icons = <String, IconData>{
    'File': Icons.insert_drive_file_outlined,
    'Assignment': Icons.assignment_outlined,
    'Quiz': Icons.quiz_outlined,
    'Discussion': Icons.forum_outlined,
    'Page': Icons.article_outlined,
    'ExternalUrl': Icons.link,
    'ExternalTool': Icons.open_in_new,
  };

  static const _labels = <String, String>{
    'File': '자료',
    'Assignment': '과제',
    'Quiz': '퀴즈',
    'Discussion': '토론',
    'Page': '페이지',
    'ExternalUrl': '링크',
    'ExternalTool': '외부 도구',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    // 소제목은 카드가 아니라 구분선처럼 보여준다.
    if (item.type == 'SubHeader') {
      return Padding(
        padding: EdgeInsets.only(left: 4 + item.indent * 16.0, top: 8),
        child: Text(
          item.title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: scheme.outline),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: item.indent * 16.0),
      child: Card(
        child: ListTile(
          leading: Icon(
            _icons[item.type] ?? Icons.circle_outlined,
            color: item.isOpenable ? scheme.primary : scheme.outline,
          ),
          title: Text(item.title),
          subtitle: Text(
            _labels[item.type] ?? item.type,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.outline),
          ),
          trailing: item.isOpenable
              ? Icon(item.isFile ? Icons.download_outlined : Icons.chevron_right,
                  size: 20, color: scheme.outline)
              : null,
          onTap: !item.isOpenable
              ? null
              : () {
                  // 파일을 WebView로 열면 빈 화면이 된다. 받아서 뷰어로 넘긴다.
                  if (item.isFile) {
                    openCanvasFile(context, ref,
                        url: item.downloadUrl, displayName: item.title);
                  } else {
                    openCanvasPage(context,
                        title: item.title, url: item.htmlUrl);
                  }
                },
        ),
      ),
    );
  }
}
