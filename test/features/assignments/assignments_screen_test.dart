import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/assignments/data/calendar_api.dart' show formatDateParam;
import 'package:kumoh_lms/features/assignments/presentation/assignments_screen.dart';
import 'package:kumoh_lms/features/reference/presentation/term_providers.dart';
import 'package:kumoh_lms/providers.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late Dio dio;
  late DioAdapter adapter;

  setUpAll(() => initializeDateFormatting('ko_KR'));
  setUp(() {
    db = createTestDatabase();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    adapter = DioAdapter(dio: dio);
    // 기본은 실패. 캘린더 경로를 검증하는 테스트가 따로 성공 응답을 등록한다.
    adapter.onGet('/courses', (s) => s.reply(500, {}));
  });
  tearDown(() => db.close());

  Widget wrap() => ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          dioProvider.overrideWithValue(dio),
          canvasDioProvider.overrideWithValue(dio),
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          activeTermIdProvider.overrideWith((ref) async => 8),
        ],
        child: const MaterialApp(home: AssignmentsScreen()),
      );


  /// 네트워크 → Drift 쓰기는 실제 이벤트 루프를 거치므로 pumpAndSettle만으로는
  /// 끝나지 않는다. 두 루프를 번갈아 흘려보낸다(widget_test.dart와 동일한 이유).
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
    await tester.pumpAndSettle();
  }

  Future<void> seedEvent(DateTime dueAt) => db.calendarEventsDao.upsertAll([
        CalendarEventsCompanion.insert(
          id: 'assignment_7931',
          termId: 8,
          courseId: const Value(4831),
          title: '[토의 과제] 리눅스 상식',
          contextName: const Value('리눅스시스템프로그래밍-01'),
          startAt: Value(dueAt),
          endAt: Value(dueAt),
          htmlUrl: const Value('https://canvas.kumoh.ac.kr/courses/4831/assignments/7931'),
        ),
      ]);

  testWidgets('목록 탭에서 과제 제목과 강좌명을 보여준다', (tester) async {
    await seedEvent(DateTime.now().toUtc().add(const Duration(days: 7)));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('목록'));
    await tester.pumpAndSettle();

    expect(find.text('[토의 과제] 리눅스 상식'), findsOneWidget);
    expect(find.textContaining('리눅스시스템프로그래밍-01'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('과제가 없으면 빈 상태를 보여준다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('목록'));
    await tester.pumpAndSettle();

    expect(find.text('예정된 과제가 없습니다'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  test('formatDue는 한국어 날짜 형식을 만든다', () {
    expect(formatDue(DateTime(2026, 9, 2, 23, 59)), '9월 2일 (수) 23:59');
    expect(formatDue(null), '기한 없음');
  });

  testWidgets('캘린더 새로고침이 실제로 이벤트를 받아 화면에 올린다', (tester) async {
    // 이 화면의 새로고침은 강좌를 먼저 받고, 강좌마다 캘린더를 조회한다.
    // /calendar-events 를 등록하지 않으면 그 경로가 아예 실행되지 않아
    // 캘린더 조회가 완전히 깨져 있어도 테스트가 통과한다.
    final due = DateTime.now().toUtc().add(const Duration(days: 3));
    await db.coursesDao.upsertAll([
      CoursesCompanion.insert(
        id: const Value(4831),
        termId: 8,
        name: '리눅스시스템프로그래밍-01',
        courseCode: 'GA2015-01',
      ),
    ]);
    // 강좌 응답이 비면 replaceForTerm이 심어둔 강좌를 지워, 캘린더 조회가
    // 조기 반환된다. 서버가 그 강좌를 계속 준다고 두어야 경로가 실행된다.
    adapter.onGet('/courses', (s) => s.reply(200, {
          'code': '200',
          'message': 'Success',
          'data': {
            'courses': [
              {
                'id': 4831,
                'name': '리눅스시스템프로그래밍-01',
                'courseCode': 'GA2015-01',
                'enrollmentTermId': 8,
                'teachers': <Map<String, dynamic>>[],
                'workflowState': 'available',
              },
            ],
          },
        }), queryParameters: {
          'isMyCourse': 'true',
          'accountId': 1,
          'termId': 8,
        });
    // 리포지토리는 from/to 없이 호출되면 now-60d ~ now+180d 를 쓴다.
    // 쿼리 파라미터를 맞추지 않으면 목이 매칭되지 않아 요청이 실패한다.
    final now = DateTime.now().toUtc();
    adapter.onGet('/calendar-events', (s) => s.reply(200, {
          'code': '200',
          'message': 'Success',
          'data': {
            'calendarEvents': [
              {
                'id': 'assignment_9001',
                'title': '서버에서 받은 과제',
                'start_at': due.toIso8601String(),
                'end_at': due.toIso8601String(),
                'workflow_state': 'published',
                'description': '',
                'context_code': 'course_4831',
                'context_name': '리눅스시스템프로그래밍-01',
                'html_url': 'https://canvas.kumoh.ac.kr/x',
                'all_day': false,
              },
            ],
          },
        }), queryParameters: {
          'start_date': formatDateParam(now.subtract(const Duration(days: 60))),
          'end_date': formatDateParam(now.add(const Duration(days: 180))),
          'context_code': 'course_4831',
        });

    await tester.pumpWidget(wrap());
    await settle(tester);
    await tester.tap(find.text('목록'));
    await settle(tester);

    expect(find.text('서버에서 받은 과제'), findsOneWidget,
        reason: '캘린더 조회 결과가 캐시를 거쳐 화면까지 와야 한다');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('새로고침이 실패하면 캐시를 유지한 채 배너로 알린다', (tester) async {
    await seedEvent(DateTime.now().toUtc().add(const Duration(days: 7)));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.textContaining('저장된 데이터를 표시합니다'), findsOneWidget,
        reason: '실패를 알리지 않으면 학생이 낡은 데이터를 최신으로 오해한다');
    await tester.tap(find.text('목록'));
    await tester.pumpAndSettle();
    expect(find.text('[토의 과제] 리눅스 상식'), findsOneWidget,
        reason: '실패해도 캐시는 화면에 남아야 한다');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
