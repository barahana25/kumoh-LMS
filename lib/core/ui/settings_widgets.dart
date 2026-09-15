import 'package:flutter/material.dart';

/// 자동 작업의 현재 상태와 최근 실행 시각, 바로 실행 버튼을 담는 카드.
class SettingsStatusCard extends StatelessWidget {
  const SettingsStatusCard({
    required this.message,
    required this.active,
    this.busy = false,
    this.detail,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final bool active;
  final bool busy;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(
                active ? Icons.check_circle_outline : Icons.pause_circle_outline,
                size: 20,
                color: active ? scheme.primary : scheme.outline),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: theme.textTheme.bodyMedium),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(detail!,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.outline)),
              ],
            ],
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ]),
    );
  }
}
