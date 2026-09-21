import 'package:drift/drift.dart';

import 'connection.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Terms,
    Courses,
    CalendarEvents,
    Announcements,
    CacheMetaEntries,
    CanvasCacheEntries,
    NotificationSettings,
    NotificationBaselines,
    NotificationSeenItems,
    NotificationOutbox,
    DownloadSettings,
    DownloadedFiles,
    ReadNotices,
    DueReminderSettings,
    DueReminderSent
  ],
  daos: [
    TermsDao,
    CoursesDao,
    CalendarEventsDao,
    AnnouncementsDao,
    CacheMetaDao
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// 실기기는 SQLCipher 암호화 파일 DB, 웹은 WasmDatabase를 연다.
  factory AppDatabase.encrypted(Future<String> Function() keyProvider) =>
      AppDatabase(openAppDatabaseExecutor(keyProvider));

  /// 테스트용. 보통 NativeDatabase.memory()를 넘긴다.
  factory AppDatabase.forTesting(QueryExecutor executor) =>
      AppDatabase(executor);

  /// drift 기본값은 DateTime을 정수 타임스탬프로 저장해 읽을 때 isUtc를 잃는다.
  /// DateTime.==는 isUtc까지 비교하므로 UTC로 쓴 값이 왕복 후 달라진다.
  /// 텍스트(ISO-8601) 저장으로 전 테이블에서 UTC를 보존한다.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  @override
  int get schemaVersion => 9;

  /// 스키마를 올릴 때마다 여기에 단계를 추가한다.
  ///
  /// 이걸 빠뜨리면 기존 사용자의 기기에서 DB가 아예 열리지 않는다. 새로
  /// 설치한 기기에서는 재현되지 않아 테스트로도 잡히지 않으므로, 버전을
  /// 올리면 반드시 대응하는 단계를 함께 넣어야 한다.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v9: 과제 마감 알림
          if (from < 9 && to >= 9) {
            await m.createTable(dueReminderSettings);
            await m.createTable(dueReminderSent);
          }
          // v8: 과제 제출 여부
          if (from < 8 && to >= 8) {
            await m.addColumn(calendarEvents, calendarEvents.submitted);
            await m.addColumn(announcements, announcements.submitted);
          }
          // v7: 공지 화면에 과제·강의자료·토론을 함께 담는다
          if (from < 7 && to >= 7) {
            await m.addColumn(announcements, announcements.kind);
          }
          // v6: 공지 읽음 표시
          if (from < 6 && to >= 6) {
            await m.createTable(readNotices);
          }
          if (from < 5 && to >= 5) {
            await m.createTable(downloadSettings);
            await m.createTable(downloadedFiles);
          }
          // v2: 강좌 상세 탭 캐시 추가
          if (from < 2 && to >= 2) {
            await m.createTable(canvasCacheEntries);
          }
          if (from < 3 && to >= 3) {
            await m.createTable(notificationSettings);
            await m.createTable(notificationBaselines);
            await m.createTable(notificationSeenItems);
            await m.createTable(notificationOutbox);
          }
          if (from == 3 && to >= 4) {
            await m.addColumn(notificationOutbox, notificationOutbox.itemId);
            // SQLite cannot ADD COLUMN with a non-constant timestamp default.
            await customStatement(
                'ALTER TABLE notification_outbox ADD COLUMN detected_at TEXT NOT NULL DEFAULT \'1970-01-01T00:00:00.000Z\'');
            await m.addColumn(notificationOutbox, notificationOutbox.delivered);
          }
        },
      );

  /// 로그아웃 시 캐시 전체 삭제.
  Future<void> wipe() async {
    await transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }
}

@DriftAccessor(tables: [Terms])
class TermsDao extends DatabaseAccessor<AppDatabase> with _$TermsDaoMixin {
  TermsDao(super.db);

  /// id 내림차순 = 최신 학기 우선.
  /// 일회성 조회. `watchAll().first`로 대신하면 스트림 구독과 타이머가
  /// 만들어져, 위젯 트리가 사라진 뒤에도 남아 테스트가 끝나지 않는다.
  Future<List<TermRow>> getAll() =>
      (select(terms)..orderBy([(t) => OrderingTerm.desc(t.id)])).get();

  Stream<List<TermRow>> watchAll() =>
      (select(terms)..orderBy([(t) => OrderingTerm.desc(t.id)])).watch();

  Future<void> upsertAll(List<TermsCompanion> rows) async {
    await batch((b) => b.insertAllOnConflictUpdate(terms, rows));
  }
}

@DriftAccessor(tables: [Courses])
class CoursesDao extends DatabaseAccessor<AppDatabase> with _$CoursesDaoMixin {
  CoursesDao(super.db);

  Stream<List<CourseRow>> watchByTerm(int termId) => (select(courses)
        ..where((c) => c.termId.equals(termId))
        ..orderBy([(c) => OrderingTerm.asc(c.name)]))
      .watch();

  Future<void> upsertAll(List<CoursesCompanion> rows) async {
    await batch((b) => b.insertAllOnConflictUpdate(courses, rows));
  }

  /// 서버에서 사라진 강좌(수강 취소 등)를 캐시에서도 없애기 위해
  /// 해당 학기를 통째로 교체한다.
  Future<void> replaceForTerm(int termId, List<CoursesCompanion> rows) async {
    await transaction(() async {
      await (delete(courses)..where((c) => c.termId.equals(termId))).go();
      await batch((b) => b.insertAllOnConflictUpdate(courses, rows));
    });
  }
}

@DriftAccessor(tables: [CalendarEvents])
class CalendarEventsDao extends DatabaseAccessor<AppDatabase>
    with _$CalendarEventsDaoMixin {
  CalendarEventsDao(super.db);

  Stream<List<CalendarEventRow>> watchByTerm(int termId) =>
      (select(calendarEvents)
            ..where((e) => e.termId.equals(termId))
            ..orderBy([(e) => OrderingTerm.asc(e.startAt)]))
          .watch();

  /// [from] 이상 [to] 미만인 이벤트. 마감 임박 목록과 월별 캘린더에 함께 쓴다.
  Stream<List<CalendarEventRow>> watchBetween({
    required DateTime from,
    required DateTime to,
  }) =>
      (select(calendarEvents)
            ..where((e) =>
                e.startAt.isBiggerOrEqualValue(from) &
                e.startAt.isSmallerThanValue(to))
            ..orderBy([(e) => OrderingTerm.asc(e.startAt)]))
          .watch();

  Future<void> upsertAll(List<CalendarEventsCompanion> rows) async {
    await batch((b) => b.insertAllOnConflictUpdate(calendarEvents, rows));
  }

  Future<void> replaceForTerm(
      int termId, List<CalendarEventsCompanion> rows) async {
    await transaction(() async {
      await (delete(calendarEvents)..where((e) => e.termId.equals(termId)))
          .go();
      await batch((b) => b.insertAllOnConflictUpdate(calendarEvents, rows));
    });
  }
}

@DriftAccessor(tables: [Announcements])
class AnnouncementsDao extends DatabaseAccessor<AppDatabase>
    with _$AnnouncementsDaoMixin {
  AnnouncementsDao(super.db);

  Stream<List<AnnouncementRow>> watchByTerm(int termId) =>
      (select(announcements)
            ..where((a) => a.termId.equals(termId))
            ..orderBy([(a) => OrderingTerm.desc(a.postedAt)]))
          .watch();

  Future<void> replaceForTerm(
      int termId, List<AnnouncementsCompanion> rows) async {
    await transaction(() async {
      await (delete(announcements)..where((a) => a.termId.equals(termId))).go();
      await batch((b) => b.insertAllOnConflictUpdate(announcements, rows));
    });
  }
}

@DriftAccessor(tables: [CacheMetaEntries])
class CacheMetaDao extends DatabaseAccessor<AppDatabase>
    with _$CacheMetaDaoMixin {
  CacheMetaDao(super.db);

  Future<DateTime?> fetchedAt(String key) async {
    final row = await (select(cacheMetaEntries)
          ..where((e) => e.key.equals(key)))
        .getSingleOrNull();
    return row?.fetchedAt;
  }

  Future<void> touch(String key) async {
    await into(cacheMetaEntries).insertOnConflictUpdate(
      CacheMetaEntriesCompanion.insert(
        key: key,
        fetchedAt: DateTime.now().toUtc(),
      ),
    );
  }
}
