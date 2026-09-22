import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/db/app_database.dart';
import '../../../providers.dart';
import '../notification_runtime.dart';
import 'notification_settings_section.dart' show notificationSetupMessage;
import 'notification_setup.dart';

/// 마감 알림 토글을 보여줄 기기인가. 테스트에서 덮어쓴다.
final dueRemindersSupportedProvider =
    Provider<bool>((ref) => NotificationRuntime.dueSupported);

final dueReminderSettingsProvider =
    StreamProvider<DueReminderSetting?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.dueReminderSettings)..where((t) => t.id.equals(1)))
      .watchSingleOrNull();
});

/// 설정 화면의 "과제 마감 알림" 토글. 상태 카드 없이 실패만 스낵바로 알린다.
class DueReminderTile extends ConsumerStatefulWidget {
  const DueReminderTile({super.key});
  @override
  ConsumerState<DueReminderTile> createState() => _DueReminderTileState();
}

class _DueReminderTileState extends ConsumerState<DueReminderTile> {
  bool _busy = false;

  Future<void> _change(bool enable) async {
    setState(() => _busy = true);
    String? message;
    try {
      if (enable) {
        message = await enableDueReminders(ref, stillValid: () => mounted);
      } else {
        await NotificationRuntime.stopDue(ref.read(appDatabaseProvider));
      }
    } on Exception catch (e) {
      message = notificationSetupMessage('마감 알림 끄기', e);
    } finally {
      if (mounted) {
        ref.invalidate(dueReminderSettingsProvider);
        setState(() => _busy = false);
      }
    }
    if (message != null && mounted) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(dueRemindersSupportedProvider)) {
      return const SizedBox.shrink();
    }
    final settings = ref.watch(dueReminderSettingsProvider);
    return SwitchListTile(
      key: const Key('due_reminders'),
      secondary: const Icon(Icons.alarm_outlined),
      title: const Text('과제 마감 알림'),
      subtitle: const Text('제출 안 한 과제를 마감 3일 전·1일 전·당일에 알려드려요'),
      value: settings.valueOrNull?.enabled ?? false,
      onChanged:
          _busy || settings.isLoading || settings.hasError ? null : _change,
    );
  }
}
