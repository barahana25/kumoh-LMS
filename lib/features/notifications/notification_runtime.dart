import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import '../../core/network/token_store.dart';
import '../../core/platform/app_platform.dart';
import '../../core/storage/db/app_database.dart';
import '../canvas/data/canvas_token_store.dart';
import 'data/lms_notification_source.dart';
import 'data/notification_models.dart';
import 'data/notification_poller.dart';
import 'data/notification_store.dart';
import 'data/notification_schedule.dart';
import 'data/due_reminder.dart';
import 'data/due_reminder_models.dart';
import 'data/due_reminder_store.dart';
import 'data/shared_lms_session.dart';
import '../downloads/auto_download.dart';
import '../downloads/download_store.dart';
import '../downloads/folder_storage.dart';

const notificationTask = 'ac.kumoh.kumoh_lms.hourly_notifications';
const notificationScheduleTag = 'lms_clock_schedule_v2';
const notificationRecoveryTask = 'lms_schedule_recovery_v1';

@pragma('vm:entry-point')
void notificationDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    if (task != notificationTask) return true;
    final secure = SecureTokenStore();
    final db = AppDatabase.encrypted(secure.ensureDbKey);
    try {
      if (!await NotificationRuntime.hasBackgroundWork(db)) {
        return true;
      }
      // 네트워크 조회 중 종료되어도 다음 회차 예약은 남긴다.
      await NotificationRuntime.schedule();
      await NotificationRuntime.checkAll(db, secure);
      return true;
    } on Exception {
      // 다음 예약 자체에 실패했다면 OS 재시도로 예약 연결을 복구한다.
      // 서버 조회 실패는 poller에서 처리하므로 여기서 반복 로그인하지 않는다.
      return false;
    } finally {
      await db.close();
    }
  });
}

class NotificationDestination {
  const NotificationDestination(
      this.owner, this.courseId, this.courseName, this.tab);
  final String owner;
  final int courseId;
  final String courseName;
  final String tab;
  String get route => tab == 'announcements'
      ? '/announcements'
      : Uri(
          path: '/courses/$courseId',
          queryParameters: {'name': courseName, 'tab': tab}).toString();

  static NotificationDestination? parse(String? payload) {
    try {
      final value = jsonDecode(payload ?? '') as Map<String, dynamic>;
      final id = value['courseId'];
      final owner = value['owner'];
      final tab = value['tab'];
      if (id is! int ||
          id <= 0 ||
          owner is! String ||
          !NoticeKind.values.any((k) => k.tab == tab)) {
        return null;
      }
      return NotificationDestination(
          owner, id, value['courseName'] as String? ?? '강좌', tab as String);
    } on Object {
      return null;
    }
  }
}

class LocalNoticeSink implements NoticeSink, DueSink {
  final plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initializing;
  Future<void> initialize({void Function(String?)? onTap}) =>
      _initializing ??= _initialize(onTap).catchError((Object e) {
        _initializing = null;
        throw e;
      });
  Future<void> _initialize(void Function(String?)? onTap) async {
    await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_lms'),
          iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false),
        ),
        onDidReceiveNotificationResponse: (response) =>
            onTap?.call(response.payload));
  }

  Future<bool> requestPermission() async {
    if (isAndroidApp) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (isIOSApp) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  @override
  Future<bool> permitted() async {
    if (isAndroidApp) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          false;
    }
    if (isIOSApp) {
      return (await plugin
                  .resolvePlatformSpecificImplementation<
                      IOSFlutterLocalNotificationsPlugin>()
                  ?.checkPermissions())
              ?.isEnabled ??
          false;
    }
    return false;
  }

  @override
  Future<void> show(PendingNotice notice) async {
    if (!await permitted()) {
      throw Exception('Notification permission unavailable');
    }
    await plugin.show(
        id: notice.id,
        title: notice.heading,
        body: notice.title,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('lms_updates', 'LMS 새 소식',
              channelDescription: '새 공지사항, 강의자료 파일, 과제, 토론',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              onlyAlertOnce: true,
              visibility: NotificationVisibility.private),
          iOS:
              DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        payload: jsonEncode({
          'owner': notice.owner,
          'courseId': notice.courseId,
          'courseName': notice.courseName,
          'tab': notice.kind.tab
        }));
  }

  @override
  Future<void> showDue(DueNotice notice) async {
    if (!await permitted()) {
      throw Exception('Notification permission unavailable');
    }
    await plugin.show(
        id: notice.id,
        title: notice.heading,
        body: notice.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('lms_due', '과제 마감',
              channelDescription: '제출하지 않은 과제의 마감 3일 전·1일 전·당일 알림',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              visibility: NotificationVisibility.private),
          iOS:
              DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        payload: jsonEncode({
          'owner': notice.owner,
          'courseId': notice.courseId,
          'courseName': notice.courseName,
          'tab': NoticeKind.assignment.tab
        }));
  }

  @override
  Future<void> cancel(int id) => plugin.cancel(id: id);
}

class NotificationRuntime {
  static bool get supported => isAndroidApp || isIOSApp;

  /// 마감 알림은 Android에서만 돈다.
  static bool get dueSupported => isAndroidApp;
  static final sink = LocalNoticeSink();
  static final destination = ValueNotifier<NotificationDestination?>(null);
  static Future<void>? _initialized;

  static Future<void> initialize() =>
      _initialized ??= _initialize().catchError((Object e) {
        _initialized = null;
        throw e;
      });
  static Future<void> _initialize() async {
    if (!supported) return;
    await sink.initialize(
        onTap: (payload) =>
            destination.value = NotificationDestination.parse(payload));
    final launch = await sink.plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      destination.value =
          NotificationDestination.parse(launch?.notificationResponse?.payload);
    }
    await Workmanager().initialize(notificationDispatcher);
  }

  static Future<void> schedule() async {
    if (!supported) return;
    await initialize();
    final now = DateTime.now().toUtc();
    final next = NotificationSchedule.next(now);
    if (isAndroidApp) {
      // 단발 작업이 중단되어도 독립된 정기 작업이 예약과 누락 회차를 복구한다.
      // poller의 회차 잠금과 휴식 시간 검사를 그대로 사용한다.
      await Workmanager().registerPeriodicTask(
          notificationRecoveryTask, notificationTask,
          frequency: const Duration(minutes: 15),
          initialDelay: next.difference(now),
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.keep);
      // 이전 버전의 '활성화 후 1시간' 정기 작업을 제거한다.
      await Workmanager().registerOneOffTask(
          '$notificationScheduleTag.${next.millisecondsSinceEpoch}',
          notificationTask,
          tag: notificationScheduleTag,
          initialDelay: next.difference(now),
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingWorkPolicy.keep);
      await Workmanager().cancelByUniqueName(notificationTask);
      return;
    }
    await Workmanager().registerPeriodicTask(notificationTask, notificationTask,
        frequency: const Duration(hours: 1),
        initialDelay: next.difference(now),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep);
  }

  static Future<void> stop(AppDatabase db) async {
    await NotificationStore(db).disable();
    destination.value = null;
    if (!supported) return;
    try {
      if (!await hasBackgroundWork(db)) await cancelScheduled();
    } finally {
      await sink.plugin.cancelAll();
    }
  }

  static Future<void> cancelScheduled() async {
    if (!supported) return;
    await Workmanager().cancelByUniqueName(notificationTask);
    if (isAndroidApp) {
      await Workmanager().cancelByTag(notificationScheduleTag);
      await Workmanager().cancelByUniqueName(notificationRecoveryTask);
    }
  }

  static Future<bool> hasBackgroundWork(AppDatabase db) async =>
      (await NotificationStore(db).settings())?.enabled == true ||
      (dueSupported &&
          (await DueReminderStore(db).settings())?.enabled == true) ||
      (isAndroidApp &&
          (await DownloadStore(db).settings())?.enabled == true);

  static Future<String> download(AppDatabase db, TokenStore secure,
      {bool force = false}) {
    return AutoDownloader(
        store: DownloadStore(db),
        storage: AndroidFolderStorage(),
        sourceFactory: () => CanvasDownloadSource(secure)).run(force: force);
  }

  static LmsNotificationSource _lmsSource(TokenStore secure) =>
      LmsNotificationSource(secure, canvasTokenStore: SecureCanvasTokenStore());

  static Future<void> checkAll(AppDatabase db, TokenStore secure) async {
    final notices = (await NotificationStore(db).settings())?.enabled == true;
    final due = dueSupported &&
        (await DueReminderStore(db).settings())?.enabled == true;
    // LINUS는 최근 로그인 하나만 유효해서 로그인할 때마다 다른 기기 세션이
    // 끊긴다. 새 소식과 마감 알림이 한 세션을 쓰고, 로그인은 처음 필요할 때 한다.
    final shared =
        notices || due ? SharedLmsSession(_lmsSource(secure)) : null;
    try {
      try {
        if (notices) await poll(db, secure, source: shared);
      } finally {
        if (due) await remindDue(db, shared!);
      }
    } finally {
      shared?.dispose();
      if (isAndroidApp &&
          (await DownloadStore(db).settings())?.enabled == true) {
        await download(db, secure);
      }
    }
  }

  static Future<String> poll(AppDatabase db, TokenStore secure,
      {bool force = false, NotificationSource? source}) async {
    if (!supported) return '알림은 Android와 iOS에서 사용할 수 있습니다.';
    // A failed WorkManager initialization must not prevent manual checks.
    await sink.initialize(
        onTap: (payload) =>
            destination.value = NotificationDestination.parse(payload));
    return NotificationPoller(
      store: NotificationStore(db),
      sink: sink,
      sourceFactory: () => source ?? _lmsSource(secure),
      budget: isIOSApp
          ? const Duration(seconds: 20)
          : const Duration(minutes: 4),
    ).run(force: force);
  }

  static Future<String> remindDue(AppDatabase db, DueSource source) async {
    await sink.initialize(
        onTap: (payload) =>
            destination.value = NotificationDestination.parse(payload));
    return DueReminder(store: DueReminderStore(db), source: source, sink: sink)
        .run();
  }

  /// 마감 알림만 끈다. 새 소식이나 자동 다운로드가 켜져 있으면 예약은 둔다.
  /// 이미 뜬 알림은 지우지 않는다. 새 소식 알림까지 함께 지워지기 때문이다.
  static Future<void> stopDue(AppDatabase db) async {
    await DueReminderStore(db).disable();
    if (!await hasBackgroundWork(db)) await cancelScheduled();
  }
}
