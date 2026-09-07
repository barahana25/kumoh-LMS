import 'dart:math';
import 'package:drift/drift.dart';
import '../../../core/storage/db/app_database.dart';
import 'notification_models.dart';
import 'notification_schedule.dart';

String _nonce() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

class NotificationStore {
  NotificationStore(this.db);
  final AppDatabase db;

  Future<NotificationSetting?> settings() =>
      (db.select(db.notificationSettings)..where((t) => t.id.equals(1)))
          .getSingleOrNull();

  Future<void> enable(String owner) async {
    await db.transaction(() async {
      await db.delete(db.notificationBaselines).go();
      await db.delete(db.notificationSeenItems).go();
      await db.delete(db.notificationOutbox).go();
      await db.into(db.notificationSettings).insertOnConflictUpdate(
            NotificationSettingsCompanion.insert(
                id: const Value(1),
                owner: owner,
                generation: _nonce(),
                enabled: true,
                lastAttempt: const Value(null),
                lastSuccess: const Value(null),
                lease: const Value(null),
                leaseUntil: const Value(null),
                cursor: const Value(0),
                status: const Value('처음 확인한 항목은 기준으로 저장합니다.')),
          );
    });
  }

  Future<void> disable() async {
    await db.transaction(() async {
      await (db.update(db.notificationSettings)..where((t) => t.id.equals(1)))
          .write(
        NotificationSettingsCompanion(
            enabled: const Value(false),
            generation: Value(_nonce()),
            lease: const Value(null),
            leaseUntil: const Value(null),
            status: const Value('알림 확인이 꺼져 있습니다.')),
      );
      await db.delete(db.notificationOutbox).go();
    });
  }

  Future<NotificationSetting?> acquire(DateTime now,
      {bool force = false}) async {
    final lease = _nonce();
    final slot = NotificationSchedule.slot(now);
    if (!force && slot == null) return null;
    final ms = now.millisecondsSinceEpoch;
    final count = await db.customUpdate('''UPDATE notification_settings
      SET lease = ?, lease_until = ?, last_attempt = ?
      WHERE id = 1 AND enabled = 1 AND (lease_until IS NULL OR lease_until < ?)
      AND (? = 1 OR last_attempt IS NULL OR last_attempt < ?)''', variables: [
      Variable(lease),
      Variable(ms + const Duration(minutes: 10).inMilliseconds),
      Variable(ms),
      Variable(ms),
      Variable(force ? 1 : 0),
      Variable(slot?.millisecondsSinceEpoch ?? ms),
    ], updates: {
      db.notificationSettings
    });
    if (count != 1) return null;
    final run = await settings();
    return run?.lease == lease && run?.enabled == true ? run : null;
  }

  Future<bool> current(NotificationSetting run) async {
    final state = await settings();
    return state?.enabled == true &&
        state?.generation == run.generation &&
        state?.lease == run.lease;
  }

  Future<int> record(NotificationSetting run, WatchedCourse course,
          NoticeKind kind, List<WatchedItem> items) =>
      db.transaction(() async {
        if (!await current(run)) return 0;
        final scope = '${run.owner}/${course.id}/${kind.name}';
        final baseline = await (db.select(db.notificationBaselines)
              ..where((t) => t.scope.equals(scope)))
            .getSingleOrNull();
        final old = await (db.select(db.notificationSeenItems)
              ..where((t) => t.scope.equals(scope)))
            .get();
        final ids = old.map((r) => r.itemId).toSet();
        var created = 0;
        for (final item in items) {
          if (!ids.add(item.id)) continue;
          await db.into(db.notificationSeenItems).insert(
              NotificationSeenItemsCompanion.insert(
                  scope: scope, itemId: item.id));
          if (baseline != null) {
            await db
                .into(db.notificationOutbox)
                .insert(NotificationOutboxCompanion.insert(
                  generation: run.generation,
                  owner: run.owner,
                  courseId: course.id,
                  courseName: course.name,
                  kind: kind.name,
                  title: item.title,
                ));
            created++;
          }
        }
        await db.into(db.notificationBaselines).insertOnConflictUpdate(
            NotificationBaselinesCompanion.insert(scope: scope));
        return created;
      });

  Future<List<PendingNotice>> pending(NotificationSetting run) async {
    final rows = await (db.select(db.notificationOutbox)
          ..where((t) => t.generation.equals(run.generation))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    return rows
        .map((r) => PendingNotice(
            id: r.id,
            owner: r.owner,
            courseId: r.courseId,
            courseName: r.courseName,
            kind: NoticeKind.values.byName(r.kind),
            title: r.title))
        .toList();
  }

  Future<void> acknowledge(int id) =>
      (db.delete(db.notificationOutbox)..where((t) => t.id.equals(id))).go();

  Future<void> checkpoint(NotificationSetting run, int cursor) async {
    await (db.update(db.notificationSettings)
          ..where((t) =>
              t.generation.equals(run.generation) & t.lease.equals(run.lease!)))
        .write(NotificationSettingsCompanion(cursor: Value(cursor)));
  }

  Future<void> pause(NotificationSetting run, String status) async {
    await (db.update(db.notificationSettings)
          ..where((t) =>
              t.generation.equals(run.generation) & t.lease.equals(run.lease!)))
        .write(NotificationSettingsCompanion(
            enabled: const Value(false), status: Value(status)));
  }

  Future<void> finish(NotificationSetting run, DateTime now, String status,
      {bool success = false}) async {
    await (db.update(db.notificationSettings)
          ..where((t) =>
              t.generation.equals(run.generation) & t.lease.equals(run.lease!)))
        .write(NotificationSettingsCompanion(
            lease: const Value(null),
            leaseUntil: const Value(null),
            status: Value(status),
            lastSuccess: success
                ? Value(now.millisecondsSinceEpoch)
                : const Value.absent()));
  }
}
