import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers.dart';
import '../background_settings.dart';
import 'notification_settings_section.dart';
import 'notification_setup.dart';

/// 로그인 뒤 한 번 띄우는 알림·백그라운드 실행 안내.
///
/// 배터리 최적화 제외는 시스템 "허용" 창으로 바로 받지 않는다. Google Play는
/// 주기적으로 서버를 확인하는 앱의 직접 요청을 허용하지 않으므로, 앱 설정
/// 화면으로 보낸 뒤 돌아왔을 때 상태만 다시 읽는다.
class BackgroundSetupScreen extends ConsumerStatefulWidget {
  const BackgroundSetupScreen({super.key});

  @override
  ConsumerState<BackgroundSetupScreen> createState() =>
      _BackgroundSetupScreenState();
}

class _BackgroundSetupScreenState extends ConsumerState<BackgroundSetupScreen>
    with WidgetsBindingObserver {
  var _busy = false;
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
    // 배터리 설정에서 돌아오면 바뀐 상태를 다시 읽는다.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(backgroundBatteryProvider);
      ref.invalidate(notificationSettingsProvider);
    }
  }

  Future<void> _enableNotifications() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final message = await enableNotifications(ref, stillValid: () => mounted);
    if (mounted) {
      setState(() {
        _busy = false;
        _message = message;
      });
    }
  }

  Future<void> _openBattery() async {
    try {
      await BackgroundSettings.openAppSettings();
    } on Exception {
      if (mounted) {
        setState(() => _message = '휴대폰 설정 → 앱 → 금오 LMS → 배터리에서 "제한 없음"을 골라 주세요.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notificationsOn =
        ref.watch(notificationSettingsProvider).valueOrNull?.enabled == true;
    final batteryFree = ref.watch(backgroundBatteryProvider).valueOrNull == true;
    final allDone = notificationsOn && batteryFree;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.notifications_active_outlined,
                        size: 32, color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: 20),
                  Text('새 소식을 놓치지 않게',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    '공지·과제·강의자료가 올라오면 알려드려요.\n두 가지만 허용해 주세요.',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  _SetupStep(
                    number: 1,
                    icon: Icons.notifications_outlined,
                    title: '알림 받기',
                    description: '새 소식이 오면 휴대폰 알림으로 보여드려요.',
                    done: notificationsOn,
                    busy: _busy,
                    actionLabel: '허용하기',
                    onAction: _busy ? null : _enableNotifications,
                  ),
                  const SizedBox(height: 12),
                  _SetupStep(
                    number: 2,
                    icon: Icons.battery_saver_outlined,
                    title: '백그라운드 실행 허용',
                    description: '배터리 설정에서 "제한 없음"을 고르고 돌아와 주세요. '
                        '앱을 닫아 두어도 매시간 확인할 수 있어요.',
                    done: batteryFree,
                    actionLabel: '설정 열기',
                    onAction: _openBattery,
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(_message!,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.error)),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '삼성 휴대폰은 설정 → 배터리 → 백그라운드 사용 한도에서 '
                            '절전 앱·초절전 앱 목록에 금오 LMS가 있으면 빼 주세요.',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    child: Text(allDone ? '시작하기' : '완료'),
                  ),
                  if (!allDone)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('나중에 설정에서 할게요'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
    required this.done,
    required this.actionLabel,
    required this.onAction,
    this.busy = false,
  });

  final int number;
  final IconData icon;
  final String title;
  final String description;
  final bool done;
  final bool busy;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const green = Color(0xFF1E7A34);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: done ? green.withValues(alpha: 0.4) : scheme.outlineVariant),
      ),
      child: Row(children: [
        Icon(icon, color: done ? green : scheme.primary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$number. $title',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(description,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant, height: 1.45)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (done)
          Container(
            key: Key('setup_done_$number'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check, size: 14, color: green),
              SizedBox(width: 3),
              Text('완료',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: green)),
            ]),
          )
        else if (busy)
          const Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          FilledButton.tonal(onPressed: onAction, child: Text(actionLabel)),
      ]),
    );
  }
}

/// 셸에 붙어 있다가 안내가 필요하면 한 번만 띄운다.
class BackgroundSetupLauncher extends ConsumerStatefulWidget {
  const BackgroundSetupLauncher({super.key});

  @override
  ConsumerState<BackgroundSetupLauncher> createState() =>
      _BackgroundSetupLauncherState();
}

class _BackgroundSetupLauncherState
    extends ConsumerState<BackgroundSetupLauncher> {
  var _opened = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(backgroundSetupDueProvider, (_, next) {
      if (next.valueOrNull == true) _open();
    }, fireImmediately: true);
  }

  void _open() {
    if (_opened) return;
    _opened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // 띄우는 순간 본 것으로 기록한다. 도중에 앱을 꺼도 다시 조르지 않는다.
      await ref.read(appDatabaseProvider).cacheMetaDao.touch(backgroundSetupSeenKey);
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const BackgroundSetupScreen(),
      ));
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
