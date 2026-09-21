import '../../../core/storage/db/app_database.dart';
import 'due_reminder.dart';
import 'due_reminder_models.dart';
import 'due_reminder_store.dart';
import 'notification_models.dart';
import 'notification_store.dart';
import 'shared_lms_session.dart';

/// 매시 작업에서 새 소식과 마감 알림을 돌린다.
///
/// 두 러너의 잠금을 네트워크를 쓰기 전에 한꺼번에 잡는다. 15분 복구 작업과
/// 앱 타이머가 같은 회차에 겹쳐 들어와도 잠금을 못 잡은 쪽은 로그인하지 않고
/// 끝난다. 잠금을 잡은 러너들은 로그인 한 번을 나눠 쓴다. LINUS는 계정당
/// 최근 로그인 하나만 유효해서 로그인이 늘면 다른 기기 세션이 끊긴다.
Future<void> runSharedAlerts({
  required DateTime now,
  required NotificationStore notices,
  required DueReminderStore due,
  required bool noticesOn,
  required bool dueOn,
  required LmsSource Function() openSource,
  required Future<void> Function(NotificationSetting run, NotificationSource source) poll,
  required Future<void> Function(DueReminderSetting run, DueSource source) remind,
}) async {
  final noticeRun = noticesOn ? await notices.acquire(now) : null;
  final dueSlot = dueOn ? DueReminder.sendSlot(now) : null;
  final dueRun = dueSlot == null ? null : await due.acquire(now, dueSlot);
  if (noticeRun == null && dueRun == null) return;
  final session = SharedLmsSession(openSource());
  try {
    try {
      if (noticeRun != null) await poll(noticeRun, session);
    } finally {
      if (dueRun != null) await remind(dueRun, session);
    }
  } finally {
    session.dispose();
  }
}
