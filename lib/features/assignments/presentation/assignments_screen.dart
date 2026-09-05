import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/storage/db/app_database.dart';
import '../../../core/ui/async_section.dart';
import '../../../core/ui/empty_state.dart';
import '../../../providers.dart';
import '../../reference/presentation/term_providers.dart';
import 'assignments_providers.dart';
import 'widgets/event_tile.dart';

export 'widgets/event_tile.dart' show formatDue;

class AssignmentsScreen extends ConsumerWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termAsync = ref.watch(activeTermIdProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('과제'),
          bottom: const TabBar(
            tabs: [Tab(text: '캘린더'), Tab(text: '목록')],
          ),
        ),
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
                    : _AssignmentsBody(key: ValueKey(termId), termId: termId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentsBody extends ConsumerStatefulWidget {
  const _AssignmentsBody({required this.termId, super.key});
  final int termId;

  @override
  ConsumerState<_AssignmentsBody> createState() => _AssignmentsBodyState();
}

class _AssignmentsBodyState extends ConsumerState<_AssignmentsBody> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  Future<void> _refresh({bool force = false}) => runRefresh(
        ref,
        () async {
          // 캘린더는 강좌 캐시가 있어야 조회할 수 있다.
          final courses = ref.read(coursesRepositoryProvider);
          final assignments = ref.read(assignmentsRepositoryProvider);
          final termId = widget.termId;
          await courses.refresh(termId, force: force);
          await assignments.refresh(termId, force: force);
        },
      );

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(termEventsProvider(widget.termId));

    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: '과제를 불러오지 못했습니다',
        description: '$e',
      ),
      data: (events) => TabBarView(
        children: [
          _CalendarTab(
            events: events,
            focusedDay: _focusedDay,
            selectedDay: _selectedDay,
            sameDay: _sameDay,
            onDaySelected: (selected, focused) => setState(() {
              _selectedDay = selected;
              _focusedDay = focused;
            }),
            onPageChanged: (focused) => _focusedDay = focused,
            onRefresh: () => _refresh(force: true),
          ),
          _ListTab(events: events, onRefresh: () => _refresh(force: true)),
        ],
      ),
    );
  }
}

class _CalendarTab extends StatelessWidget {
  const _CalendarTab({
    required this.events,
    required this.focusedDay,
    required this.selectedDay,
    required this.sameDay,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.onRefresh,
  });

  final List<CalendarEventRow> events;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final bool Function(DateTime, DateTime) sameDay;
  final void Function(DateTime, DateTime) onDaySelected;
  final void Function(DateTime) onPageChanged;
  final Future<void> Function() onRefresh;

  List<CalendarEventRow> _eventsOn(DateTime day) => events
      .where((e) => e.startAt != null && sameDay(e.startAt!.toLocal(), day))
      .toList();

  @override
  Widget build(BuildContext context) {
    final day = selectedDay ?? focusedDay;
    final dayEvents = _eventsOn(day);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          TableCalendar<CalendarEventRow>(
            locale: 'ko_KR',
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: focusedDay,
            selectedDayPredicate: (d) => sameDay(d, day),
            eventLoader: _eventsOn,
            onDaySelected: onDaySelected,
            onPageChanged: onPageChanged,
            calendarFormat: CalendarFormat.month,
            availableGestures: AvailableGestures.horizontalSwipe,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
          const Divider(height: 1),
          if (dayEvents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: EmptyState(
                icon: Icons.event_available_outlined,
                title: '이 날짜에는 마감이 없습니다',
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final e in dayEvents) ...[
                    EventTile(event: e),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ListTab extends StatelessWidget {
  const _ListTab({required this.events, required this.onRefresh});

  final List<CalendarEventRow> events;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = events
        .where((e) => e.startAt != null && e.startAt!.toLocal().isAfter(now))
        .toList()
      ..sort((a, b) => a.startAt!.compareTo(b.startAt!));

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: upcoming.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: Icons.assignment_outlined,
                  title: '예정된 과제가 없습니다',
                  description: '아래로 당겨 새로고침해 보세요.',
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: upcoming.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => EventTile(event: upcoming[i]),
            ),
    );
  }
}
