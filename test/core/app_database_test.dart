import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
// `isNull`/`isNotNull` are deprecated top-level free functions in drift that
// collide with flutter_test's matchers of the same name; hide them since this
// file only needs drift's `Value` wrapper.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/storage/cache_policy.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';

import '../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  TermsCompanion term(int id, String name) => TermsCompanion.insert(
        id: Value(id),
        name: name,
        startAt: Value(DateTime.utc(2026, 9, 1)),
        endAt: Value(DateTime.utc(2026, 12, 22)),
        workflowState: const Value('active'),
      );

  CoursesCompanion course(int id, int termId, String name) => CoursesCompanion.insert(
        id: Value(id),
        termId: termId,
        name: name,
        courseCode: '$name-CODE',
        institution: const Value('컴퓨터공학부'),
        teacherNames: const Value('윤현주'),
        workflowState: const Value('available'),
      );

  CalendarEventsCompanion event(String id, int courseId, DateTime dueAt) =>
      CalendarEventsCompanion.insert(
        id: id,
        courseId: Value(courseId),
        termId: 8,
        title: '과제 $id',
        contextName: const Value('리눅스시스템프로그래밍-01'),
        startAt: Value(dueAt),
        endAt: Value(dueAt),
        htmlUrl: const Value('https://canvas.kumoh.ac.kr/x'),
      );

  test('학기를 upsert하고 최신순으로 읽는다', () async {
    await db.termsDao.upsertAll([term(6, '2026-1학기'), term(8, '2026-2학기')]);
    final rows = await db.termsDao.watchAll().first;
    expect(rows.map((t) => t.id), [8, 6], reason: 'id 내림차순 = 최신 학기 우선');
  });

  test('강좌는 학기별로 조회된다', () async {
    await db.coursesDao.upsertAll([
      course(4831, 8, '리눅스시스템프로그래밍-01'),
      course(5682, 8, '모두를위한아두이노-02'),
      course(1111, 6, '지난학기강좌'),
    ]);
    final rows = await db.coursesDao.watchByTerm(8).first;
    expect(rows.length, 2);
    expect(rows.every((c) => c.termId == 8), isTrue);
  });

  test('같은 id를 다시 upsert하면 덮어쓴다', () async {
    await db.coursesDao.upsertAll([course(4831, 8, '옛이름')]);
    await db.coursesDao.upsertAll([course(4831, 8, '새이름')]);
    final rows = await db.coursesDao.watchByTerm(8).first;
    expect(rows.single.name, '새이름');
  });

  test('replaceForTerm은 해당 학기의 사라진 강좌를 제거한다', () async {
    await db.coursesDao.replaceForTerm(8, [course(4831, 8, 'A'), course(5682, 8, 'B')]);
    await db.coursesDao.replaceForTerm(8, [course(4831, 8, 'A')]);
    final rows = await db.coursesDao.watchByTerm(8).first;
    expect(rows.map((c) => c.id), [4831]);
  });

  test('마감 임박 이벤트를 기간으로 조회한다', () async {
    final now = DateTime.utc(2026, 9, 5, 12);
    await db.calendarEventsDao.upsertAll([
      event('assignment_1', 4831, now.add(const Duration(days: 1))),
      event('assignment_2', 4831, now.add(const Duration(days: 30))),
      event('assignment_3', 4831, now.subtract(const Duration(days: 2))),
    ]);

    final upcoming = await db.calendarEventsDao
        .watchBetween(from: now, to: now.add(const Duration(days: 7)))
        .first;

    expect(upcoming.map((e) => e.id), ['assignment_1']);
  });

  test('CacheMeta로 신선도를 판정한다', () async {
    expect(await db.cacheMetaDao.fetchedAt('courses:8'), isNull);

    await db.cacheMetaDao.touch('courses:8');
    final at = await db.cacheMetaDao.fetchedAt('courses:8');

    expect(at, isNotNull);
    expect(CachePolicy.isFresh(at, const Duration(hours: 6)), isTrue);
    expect(CachePolicy.isFresh(at, Duration.zero), isFalse);
    expect(CachePolicy.isFresh(null, const Duration(hours: 6)), isFalse);
  });

  test('wipe는 모든 캐시를 비운다', () async {
    await db.termsDao.upsertAll([term(8, '2026-2학기')]);
    await db.coursesDao.upsertAll([course(4831, 8, 'A')]);
    await db.cacheMetaDao.touch('courses:8');

    await db.wipe();

    expect(await db.termsDao.watchAll().first, isEmpty);
    expect(await db.coursesDao.watchByTerm(8).first, isEmpty);
    expect(await db.cacheMetaDao.fetchedAt('courses:8'), isNull);
  });

  test('저장한 UTC 시각은 여러 테이블에서 UTC로 되읽힌다', () async {
    // drift 기본(정수 타임스탬프) 저장은 읽을 때 isUtc를 잃는다.
    // DateTime.==는 isUtc까지 비교하므로 UTC로 쓴 값이 왕복 후 달라진다.
    final termAt = DateTime.utc(2026, 9, 1, 0, 1);
    final postedAt = DateTime.utc(2026, 9, 3, 1);

    await db.termsDao.upsertAll([
      TermsCompanion.insert(id: const Value(8), name: '2026-2학기', startAt: Value(termAt)),
    ]);
    await db.announcementsDao.replaceForTerm(8, [
      AnnouncementsCompanion.insert(
        id: '991',
        termId: 8,
        title: '공지',
        postedAt: Value(postedAt),
      ),
    ]);

    final term = (await db.termsDao.watchAll().first).single;
    final ann = (await db.announcementsDao.watchByTerm(8).first).single;

    expect(term.startAt!.isUtc, isTrue, reason: 'Terms.startAt이 UTC로 되읽혀야 한다');
    expect(ann.postedAt!.isUtc, isTrue, reason: 'Announcements.postedAt이 UTC로 되읽혀야 한다');
    expect(term.startAt, termAt);
    expect(ann.postedAt, postedAt);
  });

  test('읽을 수 없는 캐시 파일은 버리고 새로 만든다', () async {
    // 키스토어 초기화 등으로 키와 파일이 어긋나면 모든 쿼리가 영구히 실패하고,
    // 로그아웃의 wipe()마저 실패해 사용자가 스스로 되돌릴 수 없다.
    final dir = await Directory.systemTemp.createTemp('kumoh_db_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final broken = File(p.join(dir.path, 'broken.sqlite'));
    await broken.writeAsString('이건 데이터베이스가 아니다');

    await discardUnreadableCache(broken, 'anykey');

    expect(broken.existsSync(), isFalse, reason: '열 수 없으면 버려야 한다');
  });

  test('정상 캐시 파일은 지우지 않는다', () async {
    final dir = await Directory.systemTemp.createTemp('kumoh_db_ok');
    addTearDown(() => dir.deleteSync(recursive: true));
    final healthy = File(p.join(dir.path, 'ok.sqlite'));
    final created = sqlite3.open(healthy.path);
    created.execute('CREATE TABLE t (a INTEGER);');
    created.dispose();

    await discardUnreadableCache(healthy, 'anykey');

    expect(healthy.existsSync(), isTrue, reason: '멀쩡한 캐시를 버리면 안 된다');
  });

  group('스키마 마이그레이션', () {
    // 버전을 올리면서 마이그레이션을 빠뜨리면 기존 사용자의 기기에서 DB가
    // 아예 열리지 않는다. 새 설치에서는 재현되지 않아 일반 테스트로는
    // 잡히지 않으므로 업그레이드 경로를 직접 태운다.
    test('v1 -> v2 업그레이드가 캔버스 캐시 테이블을 만든다', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      // v1 상태 재현: v2에서 추가된 테이블을 없앤다.
      await db.customStatement('DROP TABLE canvas_cache_entries');

      await db.migration.onUpgrade(Migrator(db), 1, 2);

      // 업그레이드 후에는 읽고 쓸 수 있어야 한다.
      await db.into(db.canvasCacheEntries).insertOnConflictUpdate(
            CanvasCacheEntriesCompanion.insert(
              key: 'k',
              payload: '1',
              fetchedAt: DateTime.now().toUtc(),
            ),
          );
      final row = await (db.select(db.canvasCacheEntries)
            ..where((e) => e.key.equals('k')))
          .getSingleOrNull();
      expect(row, isNotNull);
    });

    test('현재 schemaVersion과 마이그레이션 단계가 어긋나지 않는다', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      // 버전을 올렸는데 단계를 안 넣으면 이 테스트가 신호를 준다.
      expect(db.schemaVersion, 2,
          reason: 'schemaVersion을 올렸다면 onUpgrade에 해당 단계를 추가할 것');
    });
  });
}
