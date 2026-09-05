import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/assignments/data/assignments_repository.dart';
import 'package:kumoh_lms/features/assignments/data/calendar_api.dart';

import '../../fixtures/fixtures.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late Dio dio;
  late DioAdapter adapter;
  late AssignmentsRepository repo;

  setUp(() async {
    db = createTestDatabase();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    adapter = DioAdapter(dio: dio);
    repo = AssignmentsRepository(api: CalendarApi(dio), db: db);

    // 캘린더는 캐시된 강좌를 기준으로 조회하므로 강좌를 먼저 심는다.
    await db.coursesDao.upsertAll([
      CoursesCompanion.insert(
        id: const Value(4831),
        termId: 8,
        name: '리눅스시스템프로그래밍-01',
        courseCode: 'GA2015-01',
      ),
    ]);
  });
  tearDown(() => db.close());

  test('강좌별 캘린더 이벤트를 받아 캐시에 저장한다', () async {
    adapter.onGet('/calendar-events', (s) => s.reply(200, calendarEventsJson),
        queryParameters: {
          'start_date': '2026-09-01',
          'end_date': '2026-12-31',
          'context_code': 'course_4831',
        });

    await repo.refresh(8,
        from: DateTime.utc(2026, 9, 1), to: DateTime.utc(2026, 12, 31));

    final rows = await repo.watchTerm(8).first;
    expect(rows.length, 1);
    expect(rows.single.id, 'assignment_7931');
    expect(rows.single.title, '[토의 과제] 리눅스 상식');
    expect(rows.single.courseId, 4831);
    expect(rows.single.contextName, '리눅스시스템프로그래밍-01');
    expect(rows.single.htmlUrl,
        'https://canvas.kumoh.ac.kr/courses/4831/assignments/7931');
    expect(rows.single.startAt, DateTime.utc(2026, 9, 2, 14, 59));
  });

  test('context_code에서 courseId를 뽑아낸다', () {
    expect(courseIdFromContextCode('course_4831'), 4831);
    expect(courseIdFromContextCode('user_59580'), isNull);
    expect(courseIdFromContextCode(null), isNull);
  });

  test('watchBetween은 기간 안의 이벤트만 돌려준다', () async {
    adapter.onGet('/calendar-events', (s) => s.reply(200, calendarEventsJson),
        queryParameters: {
          'start_date': '2026-09-01',
          'end_date': '2026-12-31',
          'context_code': 'course_4831',
        });
    await repo.refresh(8,
        from: DateTime.utc(2026, 9, 1), to: DateTime.utc(2026, 12, 31));

    final inRange = await repo
        .watchBetween(from: DateTime.utc(2026, 9, 1), to: DateTime.utc(2026, 9, 3))
        .first;
    final outOfRange = await repo
        .watchBetween(from: DateTime.utc(2026, 10, 1), to: DateTime.utc(2026, 10, 5))
        .first;

    expect(inRange.length, 1);
    expect(outOfRange, isEmpty);
  });

  test('TTL 안에서는 네트워크를 다시 치지 않는다', () async {
    var calls = 0;
    // http_mock_adapter의 onGet 콜백은 등록 시점에 1회만 실행되고 실제 요청
    // 횟수와 무관하다. 진짜 네트워크 호출 수는 Dio 인터셉터로 센다.
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls++;
      handler.next(options);
    }));
    adapter.onGet('/calendar-events', (s) => s.reply(200, calendarEventsJson), queryParameters: {
      'start_date': '2026-09-01',
      'end_date': '2026-12-31',
      'context_code': 'course_4831',
    });

    await repo.refresh(8,
        from: DateTime.utc(2026, 9, 1), to: DateTime.utc(2026, 12, 31));
    await repo.refresh(8,
        from: DateTime.utc(2026, 9, 1), to: DateTime.utc(2026, 12, 31));

    expect(calls, 1);
  });

  test('캐시된 강좌가 없으면 네트워크를 치지 않는다', () async {
    await db.wipe();
    var calls = 0;
    // http_mock_adapter의 onGet 콜백은 등록 시점에 1회만 실행되고 실제 요청
    // 횟수와 무관하다. 진짜 네트워크 호출 수는 Dio 인터셉터로 센다.
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls++;
      handler.next(options);
    }));
    adapter.onGet('/calendar-events', (s) => s.reply(200, calendarEventsJson));

    await repo.refresh(8,
        from: DateTime.utc(2026, 9, 1), to: DateTime.utc(2026, 12, 31));

    expect(calls, 0);
    expect(await repo.watchTerm(8).first, isEmpty);
  });
}
