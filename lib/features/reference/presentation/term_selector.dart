import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/db/app_database.dart';
import '../../../providers.dart';
import 'term_providers.dart';

/// 지금 보고 있는 학기를 보여주고, 누르면 다른 학기를 고르게 한다.
class TermSelector extends ConsumerWidget {
  const TermSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final terms = ref.watch(termsProvider).valueOrNull ?? const <TermRow>[];
    final selected = ref.watch(selectedTermIdProvider);
    final activeId = ref.watch(activeTermIdProvider).valueOrNull;
    final name = terms.where((t) => t.id == activeId).map((t) => t.name).firstOrNull;

    return Material(
      color: scheme.secondaryContainer,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('term_selector'),
        onTap: terms.isEmpty ? null : () => _pick(context, ref, terms, selected),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.calendar_month_outlined,
                size: 18, color: scheme.onSecondaryContainer),
            const SizedBox(width: 6),
            Text(
              name ?? '학기 선택',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (selected == null && name != null) ...[
              const SizedBox(width: 6),
              Text('현재',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSecondaryContainer.withValues(alpha: 0.7))),
            ],
            Icon(Icons.arrow_drop_down, color: scheme.onSecondaryContainer),
          ]),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref, List<TermRow> terms,
      int? selected) async {
    final picked = await showModalBottomSheet<({int? id})>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('학기 선택',
                  style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('현재 학기 자동 선택'),
              selected: selected == null,
              trailing: selected == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(sheetContext, (id: null)),
            ),
            for (final t in terms)
              ListTile(
                leading: const SizedBox(width: 24),
                title: Text(t.name),
                selected: t.id == selected,
                trailing: t.id == selected ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(sheetContext, (id: t.id)),
              ),
          ],
        ),
      ),
    );
    if (context.mounted && picked != null) {
      ref.read(selectedTermIdProvider.notifier).state = picked.id;
      ref.read(refreshErrorProvider.notifier).state = null;
    }
  }
}
