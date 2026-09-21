import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/storage/db/app_database.dart';
import '../../../core/ui/settings_widgets.dart';
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

/// 설정 화면의 "과제 마감 알림" 토글과 최근 확인 상태.
class DueReminderTile extends ConsumerStatefulWidget {
  const DueReminderTile({super.key});
  @override
  ConsumerState<DueReminderTile> createState() => _DueReminderTileState();
}

class _DueReminderTileState extends ConsumerState<DueReminderTile> {
  bool _busy = false;
  String? _message;

  Future<void> _change(bool enable) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (enable) {
        _message = await enableDueReminders(ref, stillValid: () => mounted);
      } else {
        await NotificationRuntime.stopDue(ref.read(appDatabaseProvider));
      }
    } on Exception catch (e) {
      _message = notificationSetupMessage('마감 알림 끄기', e);
    } finally {
      if (mounted) {
        ref.invalidate(dueReminderSettingsProvider);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(dueRemindersSupportedProvider)) {
      return const SizedBox.shrink();
    }
    final settings = ref.watch(dueReminderSettingsProvider);
    final config = settings.valueOrNull;
    String time(int? ms) => ms == null
        ? '아직 없음'
        : DateFormat('M/d HH:mm')
            .format(DateTime.fromMillisecondsSinceEpoch(ms));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SwitchListTile(
        key: const Key('due_reminders'),
        secondary: const Icon(Icons.alarm_outlined),
        title: const Text('과제 마감 알림'),
        subtitle: const Text('제출 안 한 과제를 마감 3일 전·1일 전·당일에 알려드려요'),
        value: config?.enabled ?? false,
        onChanged: _busy || settings.isLoading || settings.hasError
            ? null
            : _change,
      ),
      if (config?.enabled == true || _message != null || _busy)
        SettingsStatusCard(
          busy: _busy,
          active: config?.enabled == true,
          message: _busy
              ? '마감 알림 설정을 바꾸고 있습니다…'
              : _message ?? config!.status,
          detail: config?.lastAttempt == null
              ? null
              : '최근 완료 ${time(config!.lastSuccess)} · 시도 ${time(config.lastAttempt)}',
        ),
    ]);
  }
}
