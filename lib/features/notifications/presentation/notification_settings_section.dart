import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/storage/db/app_database.dart';
import '../../../core/ui/settings_widgets.dart';
import '../../../providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/notification_store.dart';
import '../notification_runtime.dart';
import '../background_settings.dart';

final backgroundBatteryProvider = FutureProvider<bool?>(
    (ref) => BackgroundSettings.batteryUnrestricted());

final notificationSettingsProvider = StreamProvider<NotificationSetting?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.notificationSettings)..where((t) => t.id.equals(1)))
      .watchSingleOrNull();
});

/// 알림 설정 실패를 실패한 단계와 제한된 식별자로만 설명한다.
/// 자격증명·네이티브 원문 메시지·서버 응답은 절대 포함하지 않는다.
String notificationSetupMessage(String stage, Exception error) {
  if (error is PlatformException) {
    final code = RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(error.code)
        ? error.code
        : 'platform_error';
    return '$stage 실패 ($code). 다시 시도해 주세요.';
  }
  if (error is SqliteException) {
    return '$stage 실패 (저장소 ${error.resultCode}). 앱을 다시 열어 주세요.';
  }
  return '$stage 중 오류가 발생했습니다. 다시 시도해 주세요.';
}

class NotificationSettingsSection extends ConsumerStatefulWidget {
  const NotificationSettingsSection({super.key});
  @override
  ConsumerState<NotificationSettingsSection> createState() =>
      _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState
    extends ConsumerState<NotificationSettingsSection>
    with WidgetsBindingObserver {
  bool _busy = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(notificationSettingsProvider);
      ref.invalidate(backgroundBatteryProvider);
    }
  }

  Future<void> _change(bool enable) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final db = ref.read(appDatabaseProvider);
    final tokens = ref.read(tokenStoreProvider);
    final auth = ref.read(authControllerProvider).valueOrNull;
    var stage = '알림 설정 시작';
    try {
      if (!enable) {
        stage = '알림 끄기';
        await NotificationRuntime.stop(db);
      } else {
        stage = '자동 로그인 정보 확인';
        final credentials = await tokens.readCredentials();
        if (auth is! AuthAuthenticated ||
            credentials == null ||
            credentials.userId.trim().toUpperCase() !=
                auth.profile.loginId.trim().toUpperCase()) {
          _message = '자동 로그인을 켜고 다시 로그인한 후 알림을 켜 주세요.';
          return;
        }
        stage = '알림 기능 준비';
        await NotificationRuntime.initialize();
        stage = '알림 권한 요청';
        if (!await NotificationRuntime.sink.requestPermission()) {
          _message = '기기 설정에서 금오 LMS의 알림을 허용해 주세요.';
          return;
        }
        if (!mounted || ref.read(authControllerProvider).valueOrNull != auth) {
          return;
        }
        stage = '알림 설정 저장';
        await NotificationStore(db).enable(auth.profile.loginId);
        try {
          stage = '자동 확인 예약';
          await NotificationRuntime.schedule();
        } on Exception {
          await NotificationStore(db).disable();
          rethrow;
        }
        // 토글은 켜기만 한다. 첫 조회는 예약된 회차나 '지금 확인'에서 수행한다.
      }
    } on Exception catch (e) {
      _message = notificationSetupMessage(stage, e);
    } finally {
      if (mounted) {
        ref.invalidate(notificationSettingsProvider);
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final db = ref.read(appDatabaseProvider);
    final tokens = ref.read(tokenStoreProvider);
    try {
      _message = await NotificationRuntime.poll(db, tokens, force: true);
    } on Exception {
      _message = '확인하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    } finally {
      if (mounted) {
        ref.invalidate(notificationSettingsProvider);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(notificationSettingsProvider);
    final config = settings.valueOrNull;
    final batteryFree = ref.watch(backgroundBatteryProvider).valueOrNull == true;
    String time(int? ms) => ms == null
        ? '아직 없음'
        : DateFormat('M/d HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ms));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SwitchListTile(
        key: const Key('hourly_notifications'),
        secondary: const Icon(Icons.notifications_outlined),
        title: const Text('LMS 새 소식 알림'),
        subtitle: const Text('공지·파일·과제·토론이 올라오면 알려드려요'),
        value: config?.enabled ?? false,
        onChanged: _busy ||
                settings.isLoading ||
                settings.hasError ||
                !NotificationRuntime.supported
            ? null
            : _change,
      ),
      if (!NotificationRuntime.supported)
        const ListTile(title: Text('알림은 Android와 iOS에서 사용할 수 있습니다.')),
      if (settings.hasError)
        ListTile(
            title: const Text('알림 설정을 읽지 못했습니다.'),
            trailing: TextButton(
                onPressed: () => ref.invalidate(notificationSettingsProvider),
                child: const Text('다시 시도'))),
      if (config != null || _message != null || _busy)
        SettingsStatusCard(
          busy: _busy,
          active: config?.enabled == true,
          message: _busy ? '새 소식을 확인하고 있습니다…' : _message ?? config!.status,
          detail: config?.lastAttempt == null
              ? null
              : '최근 완료 ${time(config!.lastSuccess)} · 시도 ${time(config.lastAttempt)}',
          actionLabel: config?.enabled == true ? '지금 확인' : null,
          onAction: _busy ? null : _check,
        ),
      if (BackgroundSettings.supported)
        ListTile(
          leading: const Icon(Icons.battery_saver_outlined),
          title: const Text('백그라운드 실행'),
          subtitle: Text(batteryFree ? '배터리 제한 없이 실행 중' : '배터리 사용을 "제한 없음"으로 바꿔 주세요'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            _StatusPill(ok: batteryFree),
            IconButton(
              tooltip: '알림이 늦게 올 때',
              icon: const Icon(Icons.help_outline, size: 20),
              onPressed: () => _showBackgroundGuide(context),
            ),
          ]),
          onTap: _openBatterySettings,
        ),
    ]);
  }

  Future<void> _openBatterySettings() async {
    try {
      await BackgroundSettings.openAppSettings();
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('휴대폰 설정 → 앱 → 금오공대 LMS → 배터리에서 확인해 주세요.'),
        ));
      }
    }
  }

  Future<void> _showBackgroundGuide(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) {
          final theme = Theme.of(sheetContext);
          Widget step(int n, String text) => ListTile(
                leading: CircleAvatar(
                  radius: 13,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text('$n',
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer)),
                ),
                title: Text(text),
              );
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                  child: Text('알림이 늦게 온다면',
                      style: theme.textTheme.titleMedium),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    '매시 1분(08:01~23:01, 00:01)에 새 소식을 확인합니다. '
                    '휴대폰이 절전 중이면 확인이 늦어질 수 있어요.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                step(1, '앱 정보 → 배터리에서 "제한 없음"을 선택해 주세요.'),
                step(2, '절전 앱·초절전 앱 목록에서 금오 LMS를 빼 주세요.'),
                step(3, '최근 앱에서 닫아도 예약은 유지돼요. 앱을 강제 종료하지만 않으면 됩니다.'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: FilledButton.tonal(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _openBatterySettings();
                    },
                    child: const Text('배터리 설정 열기'),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.ok});
  final bool ok;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF1E7A34);
    const orange = Color(0xFFB35C00);
    final color = ok ? green : orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(ok ? '설정됨' : '설정 필요',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
