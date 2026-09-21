import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../canvas/presentation/canvas_web_target.dart';

import '../../../../core/storage/db/app_database.dart';
import '../../../../core/time/due_days.dart';

/// '9월 2일 (수) 23:59' 형태. 기한이 없으면 안내 문구.
String formatDue(DateTime? at) {
  if (at == null) return '기한 없음';
  return DateFormat('M월 d일 (E) HH:mm', 'ko_KR').format(at.toLocal());
}

/// '제출 완료' 표시 색. 마감 D-day와 헷갈리지 않게 초록 계열을 쓴다.
const submittedBackground = Color(0xFFE3F4E6);
const submittedForeground = Color(0xFF1E7A34);

/// 마감까지 남은 시간을 사람이 읽는 문구로.
String dueRelative(DateTime? at, {DateTime? now}) {
  if (at == null) return '';
  final days = dueDays(at, now ?? DateTime.now());
  if (days == null) return '마감됨';
  if (days == 0) return 'D-DAY';
  return 'D-$days';
}

class EventTile extends StatelessWidget {
  const EventTile({required this.event, this.onReturn, super.key});

  final CalendarEventRow event;

  /// 과제 페이지에서 돌아왔을 때. 거기서 제출했을 수 있으니 다시 받는다.
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badge = event.submitted ? '제출 완료' : dueRelative(event.startAt);
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
                  color: event.submitted
                      ? submittedBackground
                      : overdue
                          ? scheme.surfaceContainerHighest
                          : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (event.submitted) ...[
                    const Icon(Icons.check, size: 13, color: submittedForeground),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    badge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: event.submitted
                          ? submittedForeground
                          : overdue
                              ? scheme.outline
                              : scheme.onPrimaryContainer,
                    ),
                  ),
                ]),
              ),
        onTap: event.htmlUrl.isEmpty
            ? null
            : () async {
                await openCanvasPage(context, title: event.title, url: event.htmlUrl);
                onReturn?.call();
              },
      ),
    );
  }
}
