import 'package:drift/drift.dart';
import '../../core/storage/db/app_database.dart';
import '../notifications/data/notification_schedule.dart';

class DownloadStore {
  DownloadStore(this.db);
  final AppDatabase db;
  Future<DownloadSetting?> settings() =>
      (db.select(db.downloadSettings)..where((t) => t.id.equals(1)))
          .getSingleOrNull();
  Future<void> configure(String owner, String uri, String name) async {
    await db
        .into(db.downloadSettings)
        .insertOnConflictUpdate(DownloadSettingsCompanion.insert(
          id: const Value(1),
          owner: owner,
          treeUri: uri,
          folderName: name,
          generation: DateTime.now().microsecondsSinceEpoch.toString(),
          enabled: const Value(false),
          lease: const Value(null),
          leaseUntil: const Value(null),
          lastAttempt: const Value(null),
          status: const Value('저장 폴더를 선택했습니다. 자동 다운로드를 켜 주세요.'),
        ));
  }

  Future<void> setEnabled(bool value) async {
    await (db.update(db.downloadSettings)..where((t) => t.id.equals(1)))
        .write(DownloadSettingsCompanion(
      enabled: Value(value),
      generation: Value(DateTime.now().microsecondsSinceEpoch.toString()),
      lease: const Value(null),
      leaseUntil: const Value(null),
      lastAttempt: const Value(null),
      status: Value(value ? '다운로드를 준비합니다.' : '자동 다운로드가 꺼져 있습니다.'),
    ));
  }

  Future<DownloadSetting?> acquire(DateTime now, bool force) async {
    final slot = NotificationSchedule.slot(now);
    if (!force && slot == null) return null;
    final ms = now.millisecondsSinceEpoch;
    final lease = now.microsecondsSinceEpoch.toString();
    final count = await db.customUpdate('''UPDATE download_settings
      SET lease = ?, lease_until = ?, last_attempt = ?
      WHERE id = 1 AND enabled = 1 AND (lease_until IS NULL OR lease_until < ?)
      AND (? = 1 OR last_attempt IS NULL OR last_attempt < ?)''', variables: [
      Variable(lease),
      Variable(ms + 600000),
      Variable(ms),
      Variable(ms),
      Variable(force ? 1 : 0),
      Variable(slot?.millisecondsSinceEpoch ?? ms),
    ], updates: {
      db.downloadSettings
    });
    return count == 1 ? settings() : null;
  }

  Future<bool> current(DownloadSetting run) async {
    final s = await settings();
    return s?.enabled == true &&
        s?.generation == run.generation &&
        s?.lease == run.lease;
  }

  Future<String?> saved(DownloadSetting run, int course, String file) async =>
      (await (db.select(db.downloadedFiles)
                ..where((t) =>
                    t.owner.equals(run.owner) &
                    t.treeUri.equals(run.treeUri) &
                    t.courseId.equals(course) &
                    t.fileId.equals(file)))
              .getSingleOrNull())
          ?.documentUri;
  Future<void> record(
      DownloadSetting run, int course, String file, String uri) async {
    await db.transaction(() async {
      if (!await current(run)) return;
      await db
          .into(db.downloadedFiles)
          .insertOnConflictUpdate(DownloadedFilesCompanion.insert(
            owner: run.owner,
            treeUri: run.treeUri,
            courseId: course,
            fileId: file,
            documentUri: uri,
          ));
    });
  }

  Future<void> finish(DownloadSetting run, String status,
      {bool pause = false}) async {
    await (db.update(db.downloadSettings)
          ..where((t) =>
              t.generation.equals(run.generation) & t.lease.equals(run.lease!)))
        .write(DownloadSettingsCompanion(
            lease: const Value(null),
            leaseUntil: const Value(null),
            status: Value(status),
            enabled: pause ? const Value(false) : const Value.absent()));
  }
}
