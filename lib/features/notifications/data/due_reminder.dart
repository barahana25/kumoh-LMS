import 'package:flutter/services.dart';
import 'package:sqlite3/common.dart' show SqliteException;
import '../../../core/error/failure.dart';
import 'due_reminder_models.dart';
import 'due_reminder_store.dart';
import 'notification_schedule.dart';

/// 제출하지 않은 과제를 D-3·D-1·D-DAY 구간마다 한 번씩 알린다.
///
/// [source]의 수명은 부르는 쪽이 관리한다. 새 소식 알림과 로그인을 나눠
/// 쓰기 때문에 여기서 닫지 않는다.
class DueReminder {
  DueReminder(
      {required this.store,
      required this.source,
      required this.sink,
      DateTime Function()? clock,
      this.budget = const Duration(minutes: 2)})
      : clock = clock ?? DateTime.now;
  final DueReminderStore store;
  final DueSource source;
  final DueSink sink;
  final DateTime Function() clock;
  final Duration budget;

  /// 마감 알림을 보내는 회차. 새 소식과 같은 매시 01분이되 00:01은 뺀다.
  /// 23:59 마감이 흔해 구간 경계가 자정 직전에 몰리기 때문이다. 23:01 다음
  /// 회차는 08:01이라 쉬는 틈이 9시간이고 구간은 24시간이므로 놓치지 않는다.
  static DateTime? sendSlot(DateTime now) {
    final slot = NotificationSchedule.slot(now);
    if (slot == null) return null;
    final kstHour = slot.toUtc().add(NotificationSchedule.zone).hour;
    return kstHour == 0 ? null : slot;
  }

  Future<String> run() async {
    final slot = sendSlot(clock());
    if (slot == null) return '마감 알림은 08:01~23:01에 확인합니다.';
    final run = await store.acquire(clock(), slot);
    if (run == null) return '이번 회차는 이미 확인했거나 확인 중입니다.';
    var status = '확인하지 못했습니다. 다음 주기에 다시 시도합니다.';
    var success = false;
    var stage = '알림 권한 확인';
    final timer = Stopwatch()..start();
    try {
      if (!await sink.permitted()) {
        status = '기기 설정에서 알림 권한을 허용해 주세요.';
        return status;
      }
      stage = '자동 로그인';
      final owner = await source.authenticate();
      if (owner.toUpperCase().trim() != run.owner.toUpperCase().trim()) {
        status = '계정이 변경되었습니다. 마감 알림을 다시 켜 주세요.';
        await store.pause(run, status);
        return status;
      }
      stage = '강의 목록 조회';
      final courses = await source.courses();
      var sent = 0;
      var failed = 0;
      for (final course in courses) {
        if (!await store.current(run)) {
          status = '마감 알림 확인이 취소되었습니다.';
          return status;
        }
        if (timer.elapsed > budget) {
          status = '일부 강좌만 확인했습니다. 남은 강좌는 다음 주기에 확인합니다.';
          return status;
        }
        try {
          stage = '${course.name} 과제 조회';
          final assignments = await source.dueAssignments(course.id);
          for (final assignment in assignments) {
            final due = dueStageFor(assignment.dueAt, clock());
            if (due == null) continue;
            final key = dueReminderKey(course.id, assignment, due);
            if (await store.sent(key)) continue;
            stage = '기기 알림 표시';
            await sink.showDue(DueNotice(
                id: dueNotificationId(key),
                owner: run.owner,
                courseId: course.id,
                courseName: course.name,
                assignment: assignment,
                stage: due));
            stage = '알림 기록 저장';
            await store.markSent(key, clock());
            sent++;
          }
        } on Failure {
          // 한 강좌의 권한 오류·일시적 실패가 다른 강좌를 막지 않는다.
          failed++;
        }
      }
      success = failed == 0;
      status = failed == 0
          ? '${courses.length}개 강좌 확인 · 마감 알림 $sent개'
          : '${courses.length - failed}개 강좌 확인 · $failed개 강좌는 다음 주기에 재시도합니다.';
      return status;
    } on AuthFailure {
      status = '자동 로그인을 켜고 다시 로그인해 주세요.';
      await store.pause(run, status);
      return status;
    } on Failure {
      status = '학교 서버에 연결하지 못했습니다. 다음 주기에 재시도합니다.';
      return status;
    } on PlatformException catch (e) {
      // 제한된 식별자만 남긴다. 네이티브 원문 메시지는 넣지 않는다.
      final code = RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(e.code)
          ? e.code
          : 'platform_error';
      status = '$stage 실패 ($code). 다음 주기에 다시 시도합니다.';
      return status;
    } on SqliteException catch (e) {
      status = '$stage 실패 (저장소 ${e.resultCode}). 앱을 다시 열어 주세요.';
      return status;
    } on Exception {
      status = '$stage 중 오류가 발생했습니다. 다음 주기에 다시 시도합니다.';
      return status;
    } finally {
      await store.finish(run, clock(), status, success: success);
    }
  }
}
