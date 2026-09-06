import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Terms, Courses, CalendarEvents, Announcements, CacheMetaEntries, CanvasCacheEntries],
  daos: [TermsDao, CoursesDao, CalendarEventsDao, AnnouncementsDao, CacheMetaDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// 실기기용. SQLCipher로 암호화된 파일 DB를 연다.
  factory AppDatabase.encrypted(Future<String> Function() keyProvider) =>
      AppDatabase(_openEncrypted(keyProvider));

  /// 테스트용. 보통 NativeDatabase.memory()를 넘긴다.
  factory AppDatabase.forTesting(QueryExecutor executor) => AppDatabase(executor);

  /// drift 기본값은 DateTime을 정수 타임스탬프로 저장해 읽을 때 isUtc를 잃는다.
  /// DateTime.==는 isUtc까지 비교하므로 UTC로 쓴 값이 왕복 후 달라진다.
  /// 텍스트(ISO-8601) 저장으로 전 테이블에서 UTC를 보존한다.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  @override
  int get schemaVersion => 2;

  /// 스키마를 올릴 때마다 여기에 단계를 추가한다.
  ///
  /// 이걸 빠뜨리면 기존 사용자의 기기에서 DB가 아예 열리지 않는다. 새로
  /// 설치한 기기에서는 재현되지 않아 테스트로도 잡히지 않으므로, 버전을
  /// 올리면 반드시 대응하는 단계를 함께 넣어야 한다.
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v2: 강좌 상세 탭 캐시 추가
          if (from < 2) {
            await m.createTable(canvasCacheEntries);
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


/// 암호화 키와 DB 파일이 어긋나면(기기 키스토어 초기화, 앱 재설치 잔여 파일 등)
/// 모든 쿼리가 영구히 실패한다. 로그아웃의 wipe()조차 실패해서 사용자가 스스로
/// 되돌릴 방법이 없다. 이 DB는 서버에서 언제든 다시 받을 수 있는 캐시일 뿐이므로,
/// 읽히지 않으면 버리고 새로 만드는 편이 낫다.
Future<void> discardUnreadableCache(File file, String escapedKey) async {
  if (!file.existsSync()) return;
  try {
    final db = sqlite3.open(file.path);
    try {
      db.execute("PRAGMA key = '$escapedKey';");
      db.select('SELECT count(*) FROM sqlite_master;');
    } finally {
      db.dispose();
    }
  } on Object {
    await file.delete();
  }
}

LazyDatabase _openEncrypted(Future<String> Function() keyProvider) {
  return LazyDatabase(() async {
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();

    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'kumoh_lms.sqlite'));
    final key = await keyProvider();
    final escaped = key.replaceAll("'", "''");

    // 열기 전에 확인한다. 여기서 걸러내지 않으면 이후 모든 쿼리가 던진다.
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
    await discardUnreadableCache(file, escaped);

    return NativeDatabase.createInBackground(
      file,
      isolateSetup: () {
        open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
      },
      setup: (db) {
        if (db.select('PRAGMA cipher_version;').isEmpty) {
          throw StateError('SQLCipher is not available');
        }
        db.execute("PRAGMA key = '$escaped';");
      },
    );
  });
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

  Stream<List<CourseRow>> watchByTerm(int termId) =>
      (select(courses)
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
                e.startAt.isBiggerOrEqualValue(from) & e.startAt.isSmallerThanValue(to))
            ..orderBy([(e) => OrderingTerm.asc(e.startAt)]))
          .watch();

  Future<void> upsertAll(List<CalendarEventsCompanion> rows) async {
    await batch((b) => b.insertAllOnConflictUpdate(calendarEvents, rows));
  }

  Future<void> replaceForTerm(int termId, List<CalendarEventsCompanion> rows) async {
    await transaction(() async {
      await (delete(calendarEvents)..where((e) => e.termId.equals(termId))).go();
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

  Future<void> replaceForTerm(int termId, List<AnnouncementsCompanion> rows) async {
    await transaction(() async {
      await (delete(announcements)..where((a) => a.termId.equals(termId))).go();
      await batch((b) => b.insertAllOnConflictUpdate(announcements, rows));
    });
  }
}

@DriftAccessor(tables: [CacheMetaEntries])
class CacheMetaDao extends DatabaseAccessor<AppDatabase> with _$CacheMetaDaoMixin {
  CacheMetaDao(super.db);

  Future<DateTime?> fetchedAt(String key) async {
    final row = await (select(cacheMetaEntries)..where((e) => e.key.equals(key)))
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
