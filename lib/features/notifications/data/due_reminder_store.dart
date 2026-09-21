import 'dart:math';
import 'package:drift/drift.dart';
import '../../../core/storage/db/app_database.dart';

// 1 << 32는 웹에서 0이 되어 nextInt가 RangeError를 던진다. 리터럴을 쓴다.
String _nonce() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0xFFFFFFFF)}';

/// 과제 마감 알림의 설정·실행 잠금·보낸 기록.
/// 백그라운드 isolate와 설정 화면이 함께 읽고 쓴다.
class DueReminderStore {
  DueReminderStore(this.db);
  final AppDatabase db;

  Future<DueReminderSetting?> settings() =>
      (db.select(db.dueReminderSettings)..where((t) => t.id.equals(1)))
          .getSingleOrNull();

  /// [since]를 주면 그 시각이 속한 회차에는 돌지 않는다. 설정 화면에서 켤 때
  /// 지금 시각을 넘겨, 켠 그 회차에 복구 작업이 바로 로그인하지 않게 한다.
  Future<void> enable(String owner, {DateTime? since}) async {
    await db.into(db.dueReminderSettings).insertOnConflictUpdate(
          DueReminderSettingsCompanion.insert(
            id: const Value(1),
            owner: owner,
            generation: _nonce(),
            enabled: true,
            status: const Value('다음 확인부터 마감이 가까운 미제출 과제를 알려드립니다.'),
            lastAttempt: Value(since?.millisecondsSinceEpoch),
            lastSuccess: const Value(null),
            lease: const Value(null),
            leaseUntil: const Value(null),
          ),
        );
  }

  Future<void> disable() async {
    await (db.update(db.dueReminderSettings)..where((t) => t.id.equals(1)))
        .write(DueReminderSettingsCompanion(
      enabled: const Value(false),
      generation: Value(_nonce()),
      lease: const Value(null),
      leaseUntil: const Value(null),
      status: const Value('마감 알림이 꺼져 있습니다.'),
    ));
  }

  /// [slot] 회차에 한 번만 실행 잠금을 잡는다. 이미 돌았거나 돌고 있으면 null.
  ///
  /// 15분 복구 작업과 앱 타이머가 같은 회차에 여러 번 부른다. 잠금 없이
  /// 로그인까지 가면 매번 LINUS 로그인이 늘어 다른 기기 세션이 끊긴다.
  Future<DueReminderSetting?> acquire(DateTime now, DateTime slot) async {
    final lease = _nonce();
    final ms = now.millisecondsSinceEpoch;
    final count = await db.customUpdate('''UPDATE due_reminder_settings
      SET lease = ?, lease_until = ?, last_attempt = ?
      WHERE id = 1 AND enabled = 1 AND (lease_until IS NULL OR lease_until < ?)
      AND (last_attempt IS NULL OR last_attempt < ?)''', variables: [
      Variable(lease),
      Variable(ms + const Duration(minutes: 10).inMilliseconds),
      Variable(ms),
      Variable(ms),
      Variable(slot.millisecondsSinceEpoch),
    ], updates: {
      db.dueReminderSettings
    });
    if (count != 1) return null;
    final run = await settings();
    return run?.lease == lease && run?.enabled == true ? run : null;
  }

  Future<bool> current(DueReminderSetting run) async {
    final state = await settings();
    return state?.enabled == true &&
        state?.generation == run.generation &&
        state?.lease == run.lease;
  }

  Future<bool> sent(String key) async =>
      await (db.select(db.dueReminderSent)..where((t) => t.key.equals(key)))
          .getSingleOrNull() !=
      null;

  Future<void> markSent(String key, DateTime at) =>
      db.into(db.dueReminderSent).insertOnConflictUpdate(
          DueReminderSentCompanion.insert(key: key, sentAt: at.toUtc()));

  Future<void> pause(DueReminderSetting run, String status) async {
    await (db.update(db.dueReminderSettings)
          ..where((t) =>
              t.generation.equals(run.generation) & t.lease.equals(run.lease!)))
        .write(DueReminderSettingsCompanion(
            enabled: const Value(false), status: Value(status)));
  }

  Future<void> finish(DueReminderSetting run, DateTime now, String status,
      {bool success = false}) async {
    await (db.update(db.dueReminderSettings)
          ..where((t) =>
              t.generation.equals(run.generation) & t.lease.equals(run.lease!)))
        .write(DueReminderSettingsCompanion(
            lease: const Value(null),
            leaseUntil: const Value(null),
            status: Value(status),
            lastSuccess: success
                ? Value(now.millisecondsSinceEpoch)
                : const Value.absent()));
  }
}
