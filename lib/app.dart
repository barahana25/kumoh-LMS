import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/theme.dart';
import 'core/router/app_router.dart';
import 'providers.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/notifications/notification_runtime.dart';
import 'features/notifications/foreground_notification_check.dart';
import 'features/notifications/data/notification_schedule.dart';
import 'features/reference/presentation/term_providers.dart';
import 'features/canvas/presentation/tabs/content_tabs.dart';
import 'features/canvas/presentation/tabs/assignments_tab.dart';

class KumohLmsApp extends ConsumerStatefulWidget {
  const KumohLmsApp({super.key});

  @override
  ConsumerState<KumohLmsApp> createState() => _KumohLmsAppState();
}

class _KumohLmsAppState extends ConsumerState<KumohLmsApp>
    with WidgetsBindingObserver {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationRuntime.destination.addListener(_openNotice);
    if (NotificationRuntime.supported) {
      _armNotificationTimer();
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _resumeNotifications());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    NotificationRuntime.destination.removeListener(_openNotice);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _armNotificationTimer();
      _resumeNotifications();
    }
  }

  void _armNotificationTimer() {
    _timer?.cancel();
    if (!mounted || !NotificationRuntime.supported) return;
    final now = DateTime.now().toUtc();
    _timer = Timer(NotificationSchedule.next(now).difference(now), () {
      _armNotificationTimer();
      _resumeNotifications();
    });
  }

  Future<void> _resumeNotifications() async {
    if (!mounted || !NotificationRuntime.supported) return;
    final db = ref.read(appDatabaseProvider);
    final tokens = ref.read(tokenStoreProvider);
    try {
      if (await NotificationRuntime.hasBackgroundWork(db)) {
        await runForegroundNotificationCheck(
          schedule: NotificationRuntime.schedule,
          check: () => NotificationRuntime.checkAll(db, tokens),
        );
      } else {
        await NotificationRuntime.cancelScheduled();
      }
    } on Exception {
      // 화면 동작과 독립적이다. 다음 주기/설정 화면에서 다시 시도한다.
    }
  }

  void _openNotice() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = NotificationRuntime.destination.value;
      if (target == null) return;
      final auth = ref.read(authControllerProvider);
      if (auth.isLoading) return;
      final user = auth.valueOrNull;
      NotificationRuntime.destination.value = null;
      if (user is AuthAuthenticated && user.profile.loginId == target.owner) {
        ref.invalidate(courseFilesProvider(target.courseId));
        ref.invalidate(courseAssignmentsProvider(target.courseId));
        if (target.tab == 'announcements') {
          ref.read(selectedTermIdProvider.notifier).state = null;
          _refreshNoticeAnnouncements(user);
        }
        ref.read(routerProvider).go(target.route);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _refreshNoticeAnnouncements(AuthAuthenticated user) async {
    final terms = ref.read(activeTermIdProvider.future);
    final repo = ref.read(announcementsRepositoryProvider);
    try {
      final id = await terms;
      if (mounted &&
          ref.read(authControllerProvider).valueOrNull == user &&
          id != null) {
        await repo.refresh(id, force: true);
      }
    } on Exception {
      // 캐시는 유지하며 화면의 당겨서 새로고침으로 다시 확인할 수 있다.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, __) => _openNotice());
    if (NotificationRuntime.destination.value != null) _openNotice();
    return MaterialApp.router(
      title: '금오 LMS',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
