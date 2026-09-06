import 'package:flutter/material.dart';

/// 이 데이터를 언제 받아왔는지 알린다.
///
/// 배너만으로는 약하다. 오프라인에서 학생이 낡은 마감일을 최신으로 믿고
/// 행동하면 실제 손해가 나므로, 시간을 직접 보여주고 스스로 판단하게 한다.
class StaleNotice extends StatelessWidget {
  const StaleNotice({required this.fetchedAt, this.error, super.key});

  final DateTime? fetchedAt;
  final Object? error;

  static String describe(DateTime? at, {DateTime? now}) {
    if (at == null) return '';
    final diff = (now ?? DateTime.now()).difference(at.toLocal());
    if (diff.inMinutes < 1) return '방금 기준';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전 기준';
    if (diff.inHours < 24) return '${diff.inHours}시간 전 기준';
    return '${diff.inDays}일 전 기준';
  }

  @override
  Widget build(BuildContext context) {
    final label = describe(fetchedAt);
    if (label.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.history, size: 15, color: scheme.onSecondaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error == null
                    ? '$label · 최신 정보를 확인하는 중입니다'
                    : '$label · 지금은 새로고침할 수 없습니다',
                style:
                    TextStyle(fontSize: 12, color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
