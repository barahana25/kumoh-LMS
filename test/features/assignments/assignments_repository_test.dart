import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/error/failure.dart';
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

  test('여러 강좌의 이벤트를 한 학기로 모은다', () async {
    // 서버는 강좌 하나씩만 캘린더를 준다. 이 루프가 이 리포지토리의 핵심이다.
    await db.coursesDao.upsertAll([
      CoursesCompanion.insert(
        id: const Value(5682),
        termId: 8,
        name: '모두를위한아두이노-02',
        courseCode: 'LA0424-02',
      ),
    ]);

    const secondCourseJson = {
      'code': '200',
      'message': 'Success',
      'data': {
        'calendarEvents': [
          {
            'id': 'assignment_8888',
            'title': '아두이노 1주차 과제',
            'start_at': '2026-09-10T14:59:00Z',
            'end_at': '2026-09-10T14:59:00Z',
            'workflow_state': 'published',
            'description': '',
            'context_code': 'course_5682',
            'context_name': '모두를위한아두이노-02',
            'html_url': 'https://canvas.kumoh.ac.kr/courses/5682/assignments/8888',
            'all_day': false,
          },
        ],
      },
    };

    adapter.onGet('/calendar-events', (s) => s.reply(200, calendarEventsJson),
        queryParameters: {
          'start_date': '2026-09-01',
          'end_date': '2026-12-31',
          'context_code': 'course_4831',
        });
    adapter.onGet('/calendar-events', (s) => s.reply(200, secondCourseJson),
        queryParameters: {
          'start_date': '2026-09-01',
          'end_date': '2026-12-31',
          'context_code': 'course_5682',
        });

    await repo.refresh(8,
        from: DateTime.utc(2026, 9, 1), to: DateTime.utc(2026, 12, 31));

    final rows = await repo.watchTerm(8).first;
    expect(rows.map((e) => e.id).toSet(),
        {'assignment_7931', 'assignment_8888'});
    expect(rows.map((e) => e.courseId).toSet(), {4831, 5682});
  });

  test('네트워크가 실패해도 기존 캐시는 남는다', () async {
    adapter.onGet('/calendar-events', (s) => s.reply(200, calendarEventsJson),
        queryParameters: {
          'start_date': '2026-09-01',
          'end_date': '2026-12-31',
          'context_code': 'course_4831',
        });
    await repo.refresh(8,
        from: DateTime.utc(2026, 9, 1), to: DateTime.utc(2026, 12, 31));
    expect((await repo.watchTerm(8).first).length, 1);

    adapter.onGet('/calendar-events', (s) => s.reply(401, springAuthErrorJson),
        queryParameters: {
          'start_date': '2026-09-01',
          'end_date': '2026-12-31',
          'context_code': 'course_4831',
        });

    await expectLater(
      repo.refresh(8,
          force: true,
          from: DateTime.utc(2026, 9, 1),
          to: DateTime.utc(2026, 12, 31)),
      throwsA(isA<Failure>()),
    );
    expect((await repo.watchTerm(8).first).length, 1,
        reason: '실패한 새로고침이 캐시를 지우면 안 된다');
  });
}
