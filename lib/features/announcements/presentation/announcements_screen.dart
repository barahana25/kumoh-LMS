import 'package:drift/drift.dart' show OrderingTerm, innerJoin;
import '../../../core/config/env.dart';
import '../../notifications/data/notification_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/open_link.dart';
import '../../canvas/presentation/canvas_web_target.dart';

import '../../../core/storage/db/app_database.dart';
import '../../../core/ui/async_section.dart';
import '../../../core/ui/empty_state.dart';
import '../../../providers.dart';
import '../../reference/presentation/term_providers.dart';
import 'announcements_providers.dart';

final noticeHistoryProvider =
    StreamProvider.autoDispose<List<NotificationOutboxData>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final query = db.select(db.notificationOutbox).join([
    innerJoin(db.notificationSettings,
        db.notificationSettings.owner.equalsExp(db.notificationOutbox.owner)),
  ])
    ..orderBy([
      OrderingTerm.desc(db.notificationOutbox.detectedAt),
      OrderingTerm.desc(db.notificationOutbox.id)
    ]);
  return query.watch().map(
      (rows) => rows.map((r) => r.readTable(db.notificationOutbox)).toList());
});

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
                description: userMessage(e),
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

class _AnnouncementListState extends ConsumerState<_AnnouncementList>
    with WidgetsBindingObserver {
  NoticeKind? _filter;
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(noticeHistoryProvider);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh(force: true);
    });
  }

  Future<void> _refresh({bool force = false}) => runRefresh(
        ref,
        () async {
          ref.invalidate(noticeHistoryProvider);
          final courses = ref.read(coursesRepositoryProvider);
          final announcements = ref.read(announcementsRepositoryProvider);
          await courses.refresh(widget.termId);
          await announcements.refresh(widget.termId, force: force);
        },
      );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(termAnnouncementsProvider(widget.termId));

    final history = ref.watch(noticeHistoryProvider);
    final cards = <({AnnouncementRow item, NoticeKind kind})>[
      for (final item in async.valueOrNull ?? <AnnouncementRow>[])
        (item: item, kind: NoticeKind.announcement),
    ];
    for (final notice in history.valueOrNull ?? <NotificationOutboxData>[]) {
      final kind =
          NoticeKind.values.where((k) => k.name == notice.kind).firstOrNull;
      if (kind == null) continue;
      if (kind == NoticeKind.announcement &&
          cards.any((c) =>
              c.kind == kind &&
              c.item.courseId == notice.courseId &&
              (c.item.id == notice.itemId ||
                  (notice.itemId.isEmpty && c.item.title == notice.title)))) {
        continue;
      }
      final path = switch (kind) {
        NoticeKind.announcement || NoticeKind.discussion => 'discussion_topics',
        NoticeKind.file => 'files',
        NoticeKind.assignment => 'assignments',
      };
      cards.add((
        kind: kind,
        item: AnnouncementRow(
          id: 'notice-${notice.id}',
          termId: widget.termId,
          courseId: notice.courseId,
          contextName: notice.courseName,
          title: notice.title,
          message: '',
          authorName: '',
          postedAt: notice.detectedAt.year > 1970 ? notice.detectedAt : null,
          htmlUrl: '${Env.canvasHost}/courses/${notice.courseId}/$path'
              '${notice.itemId.isEmpty ? '' : '/${Uri.encodeComponent(notice.itemId)}'}',
        )
      ));
    }
    cards.sort((a, b) => (b.item.postedAt ?? DateTime(1970))
        .compareTo(a.item.postedAt ?? DateTime(1970)));
    final visible =
        cards.where((c) => _filter == null || c.kind == _filter).toList();
    return Column(children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          for (final kind in <NoticeKind?>[
            null,
            NoticeKind.announcement,
            NoticeKind.file,
            NoticeKind.discussion,
            NoticeKind.assignment
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(kind == null
                    ? '전체'
                    : kind == NoticeKind.announcement
                        ? '공지사항'
                        : kind.label),
                selected: _filter == kind,
                onSelected: (_) => setState(() => _filter = kind),
              ),
            ),
        ]),
      ),
      if (history.hasError) const Text('알림 내역을 불러오지 못했습니다. 아래로 당겨 다시 시도해 주세요.'),
      Expanded(
          child: RefreshIndicator(
        onRefresh: () => _refresh(force: true),
        child: async.isLoading && cards.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: visible.isEmpty ? 1 : visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => visible.isEmpty
                    ? EmptyState(
                        icon: Icons.notifications_none,
                        title: async.hasError
                            ? '공지를 불러오지 못했습니다'
                            : _filter == null ||
                                    _filter == NoticeKind.announcement
                                ? '새로운 공지가 없습니다'
                                : '${_filter!.label} 알림이 없습니다',
                        description: '새로 감지한 공지·파일·과제·토론 알림이 여기에 쌓입니다.',
                      )
                    : _AnnouncementCard(
                        item: visible[i].item, kind: visible[i].kind),
              ),
      )),
    ]);
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item, required this.kind});
  final AnnouncementRow item;
  final NoticeKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final meta = [
      kind.label,
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
            : () =>
                openCanvasPage(context, title: item.title, url: item.htmlUrl),
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
