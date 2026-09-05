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
}
