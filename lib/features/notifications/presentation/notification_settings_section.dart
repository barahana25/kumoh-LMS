import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/storage/db/app_database.dart';
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SwitchListTile(
        key: const Key('hourly_notifications'),
        secondary: const Icon(Icons.notifications_outlined),
        title: const Text('LMS 새 소식 알림'),
        subtitle: const Text('현재 학기의 새 공지·파일·과제·토론를 매시 1분에 확인'),
        value: config?.enabled ?? false,
        onChanged: _busy ||
                settings.isLoading ||
                settings.hasError ||
                !NotificationRuntime.supported
            ? null
            : _change,
      ),
      const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '매시 1분(08:01~23:01, 00:01)에 새 소식을 자동 확인합니다. '
            '자동 로그인이 필요하며, 절전 모드 시 알림이 지연될 수 있습니다.',
            style: TextStyle(fontSize: 12),
          )),
      if (!NotificationRuntime.supported)
        const ListTile(title: Text('알림은 Android와 iOS에서 사용할 수 있습니다.')),
      if (BackgroundSettings.supported)
        ListTile(
          leading: const Icon(Icons.battery_saver_outlined),
          title: const Text('백그라운드 실행 설정'),
          subtitle: Text(
            '${ref.watch(backgroundBatteryProvider).valueOrNull == true ? '배터리 최적화 제외 상태입니다.' : '앱 정보 → 배터리에서 제한 없음을 선택해 주세요.'}\n'
            '절전 앱·초절전 앱 목록에서도 제외해 주세요. 최근 앱에서 닫아도 예약은 유지되지만 절전 중에는 확인이 늦어질 수 있습니다.',
          ),
          trailing: const Icon(Icons.open_in_new),
          onTap: () async {
            try {
              await BackgroundSettings.openAppSettings();
            } on Exception {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('휴대폰 설정 → 앱 → 금오공대 LMS → 배터리에서 확인해 주세요.'),
                ));
              }
            }
          },
        ),
      if (settings.hasError)
        ListTile(
            title: const Text('알림 설정을 읽지 못했습니다.'),
            trailing: TextButton(
                onPressed: () => ref.invalidate(notificationSettingsProvider),
                child: const Text('다시 시도'))),
      if (config != null || _message != null || _busy)
        ListTile(
          title: Text(_busy ? '새 소식을 확인하고 있습니다…' : _message ?? config!.status),
          subtitle: config?.lastAttempt == null
              ? null
              : Text(
                  '최근 확인 시도: ${DateFormat('M/d HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(config!.lastAttempt!))}\n'
                  '최근 완료: ${config.lastSuccess == null ? '아직 없음' : DateFormat('M/d HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(config.lastSuccess!))}'),
          trailing: config?.enabled != true
              ? null
              : TextButton(
                  onPressed: _busy ? null : _check, child: const Text('지금 확인')),
        ),
    ]);
  }
}
