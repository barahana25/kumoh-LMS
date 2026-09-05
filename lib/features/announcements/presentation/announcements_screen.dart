import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/open_link.dart';

import '../../../core/storage/db/app_database.dart';
import '../../../core/ui/async_section.dart';
import '../../../core/ui/empty_state.dart';
import '../../../providers.dart';
import '../../reference/presentation/term_providers.dart';
import 'announcements_providers.dart';

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termAsync = ref.watch(activeTermIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('공지사항')),
      body: Column(
        children: [
          const RefreshBanner(),
          Expanded(
            child: termAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                icon: Icons.error_outline,
                title: '학기 정보를 불러오지 못했습니다',
                description: '$e',
              ),
              data: (termId) => termId == null
                  ? const EmptyState(
                      icon: Icons.calendar_today_outlined,
                      title: '학기 정보가 없습니다',
                    )
                  : _AnnouncementList(key: ValueKey(termId), termId: termId),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementList extends ConsumerStatefulWidget {
  const _AnnouncementList({required this.termId, super.key});
  final int termId;

  @override
  ConsumerState<_AnnouncementList> createState() => _AnnouncementListState();
}

class _AnnouncementListState extends ConsumerState<_AnnouncementList> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh({bool force = false}) => runRefresh(
        ref,
        () => ref
            .read(announcementsRepositoryProvider)
            .refresh(widget.termId, force: force),
      );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(termAnnouncementsProvider(widget.termId));

    return RefreshIndicator(
      onRefresh: () => _refresh(force: true),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: '공지를 불러오지 못했습니다',
          description: '$e',
        ),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: Icons.campaign_outlined,
                  title: '새로운 공지가 없습니다',
                  description: '아래로 당겨 새로고침해 보세요.',
                ),
              ],
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _AnnouncementCard(item: items[i]),
          );
        },
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item});
  final AnnouncementRow item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final meta = [
      if (item.contextName.isNotEmpty) item.contextName,
      if (item.authorName.isNotEmpty) item.authorName,
      if (item.postedAt != null)
        DateFormat('M월 d일', 'ko_KR').format(item.postedAt!.toLocal()),
    ].join(' · ');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: item.htmlUrl.isEmpty
            ? null
            : () => openLink(context, item.htmlUrl),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: Theme.of(context).textTheme.titleMedium),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  meta,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.outline),
                ),
              ],
              if (item.message.isNotEmpty) ...[
                const SizedBox(height: 10),
                HtmlWidget(
                  item.message,
                  baseUrl: Uri.tryParse(item.htmlUrl),
                  onTapUrl: (url) => openLink(context, url),
                  textStyle: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
