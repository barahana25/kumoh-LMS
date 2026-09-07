import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import '../../core/network/token_store.dart';
import '../../core/storage/db/app_database.dart';
import 'data/lms_notification_source.dart';
import 'data/notification_models.dart';
import 'data/notification_poller.dart';
import 'data/notification_store.dart';
import 'data/notification_schedule.dart';

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
      if ((await NotificationStore(db).settings())?.enabled != true) {
        return true;
      }
      // 네트워크 조회 중 종료되어도 다음 회차 예약은 남긴다.
      await NotificationRuntime.schedule();
      await NotificationRuntime.sink.initialize();
      await NotificationRuntime.poll(db, secure);
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

class LocalNoticeSink implements NoticeSink {
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
    if (Platform.isAndroid) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (Platform.isIOS) {
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
    if (Platform.isAndroid) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.areNotificationsEnabled() ??
          false;
    }
    if (Platform.isIOS) {
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
        title: '새 ${notice.kind.label} · ${notice.courseName}',
        body: notice.title,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('lms_updates', 'LMS 새 소식',
              channelDescription: '새 공지사항, 강의자료 파일, 과제',
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
  Future<void> cancel(int id) => plugin.cancel(id: id);
}

class NotificationRuntime {
  static bool get supported => Platform.isAndroid || Platform.isIOS;
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
    if (Platform.isAndroid) {
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
      await cancelScheduled();
    } finally {
      await sink.plugin.cancelAll();
    }
  }

  static Future<void> cancelScheduled() async {
    if (!supported) return;
    await Workmanager().cancelByUniqueName(notificationTask);
    if (Platform.isAndroid) {
      await Workmanager().cancelByTag(notificationScheduleTag);
      await Workmanager().cancelByUniqueName(notificationRecoveryTask);
    }
  }

  static Future<String> poll(AppDatabase db, TokenStore secure,
      {bool force = false}) async {
    if (!supported) return '알림은 Android와 iOS에서 사용할 수 있습니다.';
    return NotificationPoller(
      store: NotificationStore(db),
      sink: sink,
      sourceFactory: () => LmsNotificationSource(secure),
      budget: Platform.isIOS
          ? const Duration(seconds: 20)
          : const Duration(minutes: 4),
    ).run(force: force);
  }
}
