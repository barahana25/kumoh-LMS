import '../../../core/error/failure.dart';
import '../../../core/storage/db/app_database.dart';
import 'notification_models.dart';
import 'notification_store.dart';
import 'notification_schedule.dart';

class NotificationPoller {
  NotificationPoller(
      {required this.store,
      required this.sourceFactory,
      required this.sink,
      DateTime Function()? clock,
      this.budget = const Duration(minutes: 4)})
      : clock = clock ?? DateTime.now;
  final NotificationStore store;
  final NotificationSource Function() sourceFactory;
  final NoticeSink sink;
  final DateTime Function() clock;
  final Duration budget;

  Future<String> run({bool force = false}) async {
    bool allowed() => force || NotificationSchedule.slot(clock()) != null;
    if (!allowed()) return '자동 확인 휴식 시간입니다. 다음 예약에 확인합니다.';
    final run = await store.acquire(clock(), force: force);
    if (run == null) return '확인 주기가 지나지 않았거나 이미 확인 중입니다.';
    NotificationSource? source;
    var status = '확인하지 못했습니다. 다음 주기에 다시 시도합니다.';
    var success = false;
    final timer = Stopwatch()..start();
    try {
      if (!await sink.permitted()) {
        status = '기기 설정에서 알림 권한을 허용해 주세요.';
        return status;
      }
      if (!await store.current(run)) return '알림 확인이 취소되었습니다.';
      source = sourceFactory();
      final owner = await source.authenticate();
      if (owner.toUpperCase().trim() != run.owner.toUpperCase().trim()) {
        status = '계정이 변경되었습니다. 알림을 다시 켜 주세요.';
        await store.pause(run, status);
        return status;
      }
      if (!allowed()) {
        status = '자동 확인 휴식 시간입니다. 다음 예약에 확인합니다.';
        return status;
      }
      final courses = await source.courses();
      // 수강 취소한 강좌에 대한 미전송 알림은 보내지 않는다.
      final activeCourses = courses.map((c) => c.id).toSet();
      var delivered = await _deliver(run, activeCourses, allowed);
      var failed = 0;
      var checked = 0;
      final scopes = [
        for (final course in courses)
          for (final kind in NoticeKind.values) (course, kind)
      ];
      for (var offset = 0; offset < scopes.length; offset++) {
        if (!allowed()) {
          status = '자동 확인 휴식 시간입니다. 남은 목록은 다음 예약에 확인합니다.';
          return status;
        }
        final index = (run.cursor + offset) % scopes.length;
        final (course, kind) = scopes[index];
        if (!await store.current(run)) return '알림 확인이 취소되었습니다.';
        if (timer.elapsed > budget) {
          status = '$checked개 목록 확인 · 남은 목록은 다음 주기에 확인합니다.';
          return status;
        }
        try {
          final items = await source.items(course.id, kind);
          await store.record(run, course, kind, items);
          checked++;
        } on Failure {
          // 한 강좌의 권한 오류/일시적 실패가 다른 강좌의 확인을 막지 않는다.
          failed++;
        }
        await store.checkpoint(run, (index + 1) % scopes.length);
        delivered += await _deliver(run, activeCourses, allowed);
      }
      success = failed == 0;
      status = failed == 0
          ? '${courses.length}개 강좌 확인 · 새 알림 $delivered개'
          : '$checked개 목록 확인 · $failed개 목록은 다음 주기에 재시도합니다.';
      return status;
    } on AuthFailure {
      status = '자동 로그인을 켜고 다시 로그인해 주세요.';
      await store.pause(run, status);
      return status;
    } on Failure {
      status = '학교 서버에 연결하지 못했습니다. 다음 주기에 재시도합니다.';
      return status;
    } on Exception {
      // 자격증명이나 서버 응답을 OS 작업 로그/알림에 출력하지 않는다.
      return status;
    } finally {
      source?.close();
      await store.finish(run, clock(), status, success: success);
    }
  }

  Future<int> _deliver(NotificationSetting run, Set<int> activeCourses,
      bool Function() allowed) async {
    var count = 0;
    for (final notice in await store.pending(run)) {
      if (!allowed()) break;
      if (!await store.current(run)) break;
      if (!activeCourses.contains(notice.courseId)) {
        await store.acknowledge(notice.id);
        continue;
      }
      await sink.show(notice);
      if (!await store.current(run)) {
        await sink.cancel(notice.id);
        break;
      }
      await store.acknowledge(notice.id);
      count++;
    }
    return count;
  }
}
