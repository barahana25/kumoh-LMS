import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/ui/open_link.dart';

import '../../../../core/storage/db/app_database.dart';

/// '9월 2일 (수) 23:59' 형태. 기한이 없으면 안내 문구.
String formatDue(DateTime? at) {
  if (at == null) return '기한 없음';
  return DateFormat('M월 d일 (E) HH:mm', 'ko_KR').format(at.toLocal());
}

/// 마감까지 남은 시간을 사람이 읽는 문구로.
String dueRelative(DateTime? at, {DateTime? now}) {
  if (at == null) return '';
  final base = now ?? DateTime.now();
  final diff = at.toLocal().difference(base);
  if (diff.isNegative) return '마감됨';
  if (diff.inHours < 24) return 'D-DAY';
  return 'D-${diff.inDays}';
}

class EventTile extends StatelessWidget {
  const EventTile({required this.event, super.key});

  final CalendarEventRow event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badge = dueRelative(event.startAt);
    final overdue = badge == '마감됨';

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(event.title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${event.contextName}\n${formatDue(event.startAt)}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.outline),
          ),
        ),
        isThreeLine: true,
        trailing: badge.isEmpty
            ? null
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: overdue ? scheme.surfaceContainerHighest : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: overdue ? scheme.outline : scheme.onPrimaryContainer,
                  ),
                ),
              ),
        onTap: event.htmlUrl.isEmpty
            ? null
            : () => openLink(context, event.htmlUrl),
      ),
    );
  }
}
