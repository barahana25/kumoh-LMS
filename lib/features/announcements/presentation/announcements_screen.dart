import '../../notifications/data/notification_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/config/env.dart';
import '../../canvas/data/canvas_download.dart';
import '../../canvas/presentation/canvas_file_open.dart';
import '../../canvas/presentation/canvas_web_target.dart';

import '../../../core/ui/async_section.dart';
import '../../../core/ui/empty_state.dart';
import '../../../providers.dart';
import '../../reference/presentation/term_providers.dart';
import '../../assignments/presentation/widgets/event_tile.dart'
    show submittedBackground, submittedForeground;
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

  static String _absolute(String url) =>
      url.startsWith('/') ? '${Env.canvasHost}$url' : url;

  void _open(NoticeEntry entry) {
    ref.read(noticeReadStoreProvider).markRead([entry.readKey]);
    if (entry.item.htmlUrl.isEmpty) return;
    // 파일은 웹뷰로 열면 미리보기 페이지만 뜬다. 받아서 기기 뷰어로 넘긴다.
    if (entry.kind == NoticeKind.file && isCanvasFileUrl(_absolute(entry.item.htmlUrl))) {
      openCanvasFile(context, ref,
          url: _absolute(entry.item.htmlUrl), displayName: entry.item.title);
      return;
    }
    openCanvasPage(context, title: entry.item.title, url: entry.item.htmlUrl)
        .then((_) {
      // 과제 페이지에서 제출하고 돌아왔을 수 있다.
      if (mounted && entry.kind == NoticeKind.assignment) _refresh(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(termAnnouncementsProvider(widget.termId));
    final history = ref.watch(noticeHistoryProvider);
    // 읽음 기록을 아직 못 읽었으면 점을 그리지 않는다. 전부 빨갛게 깜빡이는 걸 막는다.
    final read = ref.watch(readNoticeKeysProvider).valueOrNull;
    final feed = buildNoticeFeed(
      widget.termId,
      async.valueOrNull ?? const [],
      history.valueOrNull ?? const [],
    );
    bool isUnread(NoticeEntry e) => read != null && !read.contains(e.readKey);
    final notices =
        feed.where((e) => e.kind == NoticeKind.announcement).toList();
    final others = feed
        .where((e) =>
            e.kind != NoticeKind.announcement &&
            (_filter == null || e.kind == _filter))
        .toList();
    final unreadOthers = others.where(isUnread).toList();
    final now = DateTime.now();
    final scheme = Theme.of(context).colorScheme;

    Widget tile(NoticeEntry e) => _NoticeTile(
          entry: e,
          unread: isUnread(e),
          now: now,
          onTap: () => _open(e),
        );

    return RefreshIndicator(
      onRefresh: () => _refresh(force: true),
      child: async.isLoading && feed.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 160),
                Center(child: CircularProgressIndicator()),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              // 0: 공지 상자, 1: 강의 소식 머리, 이후: 강의 소식 항목(없으면 빈 안내 1개).
              // 강의 소식은 학기 전체 파일까지 담겨 길어지므로 한 줄씩 지연 생성한다.
              itemCount: 2 + (others.isEmpty ? 1 : others.length),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Column(children: [
                    if (history.hasError)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('알림 내역을 불러오지 못했습니다. 아래로 당겨 다시 시도해 주세요.'),
                      ),
                    _NoticeCarousel(
                      entries: notices,
                      isUnread: isUnread,
                      tile: tile,
                      failed: async.hasError,
                      onMarkAllRead: () => ref
                          .read(noticeReadStoreProvider)
                          .markRead(
                              notices.where(isUnread).map((e) => e.readKey)),
                    ),
                  ]);
                }
                if (i == 1) {
                  return _OthersHeader(
                    filter: _filter,
                    unread: unreadOthers.length,
                    onFilter: (kind) => setState(() => _filter = kind),
                    onMarkAllRead: () => ref
                        .read(noticeReadStoreProvider)
                        .markRead(unreadOthers.map((e) => e.readKey)),
                  );
                }
                final index = i - 2;
                final first = index == 0;
                final last = others.isEmpty || index == others.length - 1;
                // 항목마다 따로 그리되 이어 붙이면 하나의 상자로 보이게 한다.
                return Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    border: Border(
                      left: BorderSide(color: scheme.outlineVariant),
                      right: BorderSide(color: scheme.outlineVariant),
                      top: first
                          ? BorderSide(color: scheme.outlineVariant)
                          : BorderSide.none,
                      bottom: last
                          ? BorderSide(color: scheme.outlineVariant)
                          : BorderSide.none,
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(first ? 16 : 0),
                      bottom: Radius.circular(last ? 16 : 0),
                    ),
                  ),
                  child: others.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              _filter == null
                                  ? '과제·강의자료·토론 소식이 없습니다'
                                  : '${_filter!.label} 소식이 없습니다',
                              style: TextStyle(color: scheme.outline),
                            ),
                          ),
                        )
                      : Column(children: [
                          if (!first)
                            const Divider(height: 1, indent: 68, endIndent: 16),
                          tile(others[index]),
                        ]),
                );
              },
            ),
    );
  }
}

/// 공지사항 상자. 한 번에 [pageSize]개씩 보여주고 화살표(또는 좌우로 밀기)로
/// 오래된 공지를 넘긴다.
class _NoticeCarousel extends StatefulWidget {
  const _NoticeCarousel({
    required this.entries,
    required this.isUnread,
    required this.tile,
    required this.failed,
    required this.onMarkAllRead,
  });

  static const pageSize = 3;

  final List<NoticeEntry> entries;
  final bool Function(NoticeEntry) isUnread;
  final Widget Function(NoticeEntry) tile;
  final bool failed;
  final VoidCallback onMarkAllRead;

  @override
  State<_NoticeCarousel> createState() => _NoticeCarouselState();
}

class _NoticeCarouselState extends State<_NoticeCarousel> {
  var _page = 0;

  // 오래된 쪽(다음 페이지)으로 넘기면 오른쪽에서 들어온다.
  var _forward = true;

  void _go(int page) => setState(() {
        _forward = page > _page;
        _page = page;
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entries = widget.entries;
    final pages = (entries.length / _NoticeCarousel.pageSize).ceil();
    final page = pages == 0 ? 0 : _page.clamp(0, pages - 1);
    final shown = entries
        .skip(page * _NoticeCarousel.pageSize)
        .take(_NoticeCarousel.pageSize)
        .toList();
    final unread = entries.where(widget.isUnread).length;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
            child: SizedBox(
              height: 36,
              child: Row(children: [
                Icon(Icons.campaign_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: 6),
                Text('공지사항',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                if (unread > 0) ...[
                  const SizedBox(width: 6),
                  _CountBadge(count: unread),
                ],
                const Spacer(),
                if (unread > 0)
                  TextButton(
                    onPressed: widget.onMarkAllRead,
                    child: const Text('모두 읽음'),
                  ),
              ]),
            ),
          ),
          const Divider(height: 1),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  widget.failed ? '공지를 불러오지 못했습니다' : '새로운 공지가 없습니다',
                  style: TextStyle(color: scheme.outline),
                ),
              ),
            )
          else
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -200 && page < pages - 1) _go(page + 1);
                if (v > 200 && page > 0) _go(page - 1);
              },
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) {
                    final incoming = child.key == ValueKey(page);
                    final dx = incoming == _forward ? 0.12 : -0.12;
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(begin: Offset(dx, 0), end: Offset.zero)
                            .animate(animation),
                        child: child,
                      ),
                    );
                  },
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, if (current != null) current],
                  ),
                  child: Column(
                    key: ValueKey(page),
                    children: [
                      for (final (i, e) in shown.indexed) ...[
                        if (i > 0)
                          const Divider(height: 1, indent: 68, endIndent: 16),
                        widget.tile(e),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (pages > 1) ...[
            const Divider(height: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '최근 공지',
                  onPressed: page > 0 ? () => _go(page - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '${page + 1} / $pages',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                IconButton(
                  tooltip: '이전 공지',
                  onPressed: page < pages - 1 ? () => _go(page + 1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 강의 소식(과제·강의자료·토론) 머리. 종류 필터와 모두 읽음을 둔다.
class _OthersHeader extends StatelessWidget {
  const _OthersHeader({
    required this.filter,
    required this.unread,
    required this.onFilter,
    required this.onMarkAllRead,
  });

  final NoticeKind? filter;
  final int unread;
  final ValueChanged<NoticeKind?> onFilter;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 40,
            child: Row(children: [
              const SizedBox(width: 4),
              Icon(Icons.dynamic_feed_outlined, size: 20, color: scheme.primary),
              const SizedBox(width: 6),
              Text('강의 소식',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              if (unread > 0) ...[
                const SizedBox(width: 6),
                _CountBadge(count: unread),
              ],
              const Spacer(),
              if (unread > 0)
                TextButton(
                  onPressed: onMarkAllRead,
                  child: const Text('모두 읽음'),
                ),
            ]),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final kind in <NoticeKind?>[
                null,
                NoticeKind.assignment,
                NoticeKind.file,
                NoticeKind.discussion,
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(kind?.label ?? '전체'),
                    selected: filter == kind,
                    onSelected: (_) => onFilter(kind),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

/// 상자 제목 옆의 안 읽은 개수.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: unreadRed,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      );
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile(
      {required this.entry,
      required this.unread,
      required this.now,
      required this.onTap});
  final NoticeEntry entry;
  final bool unread;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = entry.item;
    final course = shortCourseName(item.contextName);
    final preview = htmlPreview(item.message);
    final meta = theme.textTheme.labelMedium?.copyWith(color: scheme.outline);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _KindIcon(kind: entry.kind),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        course.isEmpty ? entry.kind.label : course,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (entry.kind == NoticeKind.assignment && item.submitted)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: SubmittedChip(),
                      ),
                    if (item.postedAt != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(formatNoticeTime(item.postedAt!, now),
                            style: meta),
                      ),
                    if (unread)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _UnreadDot(key: ValueKey('unread:${entry.readKey}')),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      color: unread ? scheme.onSurface : scheme.onSurfaceVariant,
                    ),
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.outline, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.kind});
  final NoticeKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, bg, fg) = switch (kind) {
      NoticeKind.announcement => (
          Icons.campaign_outlined,
          scheme.primaryContainer,
          scheme.onPrimaryContainer
        ),
      NoticeKind.file => (
          Icons.insert_drive_file_outlined,
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer
        ),
      NoticeKind.assignment => (
          Icons.assignment_outlined,
          scheme.secondaryContainer,
          scheme.onSecondaryContainer
        ),
      NoticeKind.discussion => (
          Icons.forum_outlined,
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant
        ),
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 20, color: fg),
    );
  }
}

/// 제출한 과제 표시.
class SubmittedChip extends StatelessWidget {
  const SubmittedChip({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: submittedBackground,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check, size: 12, color: submittedForeground),
          SizedBox(width: 2),
          Text('제출 완료',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: submittedForeground)),
        ]),
      );
}

const unreadRed = Color(0xFFE53935);

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration:
            const BoxDecoration(color: unreadRed, shape: BoxShape.circle),
      );
}

/// 'AI기초프로젝트 01 [컴퓨터공학부] 시종욱', '리눅스시스템프로그래밍-01'에서
/// 강의명만 남긴다. 대괄호부터 뒤(학과·교수)와 분반 번호를 뗀다.
String shortCourseName(String name) {
  final bracket = name.indexOf(RegExp(r'[\[［]'));
  final head = (bracket > 0 ? name.substring(0, bracket) : name).trim();
  return head
      .replaceFirst(RegExp(r'\s*(?:[-\s]\d{2,3}|\(\d{2,3}\))$'), '')
      .trim();
}

/// 목록 미리보기용으로 HTML 태그를 걷어낸 한 덩어리 텍스트.
String htmlPreview(String html) {
  if (html.isEmpty) return '';
  return html
      .replaceAll(RegExp(r'<(br|/p|/div|/li)[^>]*>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// 오늘은 시각, 어제는 '어제', 올해는 날짜, 그 이전은 연도까지.
String formatNoticeTime(DateTime at, DateTime now) {
  final local = at.toLocal();
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(local.year, local.month, local.day))
      .inDays;
  // intl의 ko_KR 'a'가 환경에 따라 AM/PM으로 나와 직접 붙인다.
  if (days == 0) {
    return '${local.hour < 12 ? '오전' : '오후'} ${DateFormat('h:mm').format(local)}';
  }
  if (days == 1) return '어제';
  if (local.year == now.year) return DateFormat('M월 d일', 'ko_KR').format(local);
  return DateFormat('yy.M.d').format(local);
}
