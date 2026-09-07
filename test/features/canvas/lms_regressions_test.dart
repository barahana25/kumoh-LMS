import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/announcements/data/announcements_api.dart';
import 'package:kumoh_lms/features/announcements/data/announcements_repository.dart';
import 'package:kumoh_lms/features/announcements/presentation/announcements_screen.dart';
import 'package:kumoh_lms/features/assignments/data/assignments_repository.dart';
import 'package:kumoh_lms/features/assignments/data/calendar_api.dart';
import 'package:kumoh_lms/features/assignments/presentation/assignments_screen.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_api.dart';
import 'package:kumoh_lms/features/canvas/presentation/canvas_web_screen.dart';
import 'package:kumoh_lms/features/canvas/presentation/course_detail_screen.dart';
import 'package:kumoh_lms/features/reference/presentation/term_providers.dart';
import 'package:kumoh_lms/providers.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late Dio dio;
  late DioAdapter adapter;
  late CanvasApi canvas;
  late AssignmentsRepository assignments;
  late AnnouncementsRepository announcements;
  setUpAll(() => initializeDateFormatting('ko_KR'));
  setUp(() async {
    db = createTestDatabase();
    dio = Dio(BaseOptions(baseUrl: 'https://canvas.kumoh.ac.kr/api/v1'));
    adapter = DioAdapter(dio: dio);
    canvas = CanvasApi(dio);
    assignments =
        AssignmentsRepository(api: CalendarApi(dio), canvas: canvas, db: db);
    announcements = AnnouncementsRepository(
        api: AnnouncementsApi(dio), canvas: canvas, db: db);
    await db.coursesDao.upsertAll([
      CoursesCompanion.insert(
          id: const Value(5342),
          termId: 8,
          name: '정치학입문-01',
          courseCode: 'POL-01')
    ]);
    adapter.onGet(
        '/calendar-events',
        (s) => s.reply(200, {
              'code': '200',
              'data': {'calendarEvents': []}
            }));
    adapter.onGet(
        '/courses/5342/assignments',
        (s) => s.reply(200, [
              {'id': 9001, 'name': '레포트 제출', 'due_at': null},
            ]));
    adapter.onGet(
        '/courses/5342/discussion_topics',
        (s) => s.reply(200, [
              {'id': 9002, 'title': '레포트 안내', 'message': '레포트에 대해 안내합니다.'},
            ]),
        queryParameters: {'only_announcements': true});
    adapter.onGet(
        '/courses',
        (s) => s.reply(200, {
              'code': '200',
              'data': {
                'courses': [
                  {
                    'id': 5342,
                    'enrollmentTermId': 8,
                    'name': '정치학입문-01',
                    'courseCode': 'POL-01'
                  },
                ]
              }
            }));
  });
  tearDown(() async {
    dio.close(force: true);
    await db.close();
  });

  Widget wrap(Widget child) => ProviderScope(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        dioProvider.overrideWithValue(dio),
        canvasDioProvider.overrideWithValue(dio),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        activeTermIdProvider.overrideWith((ref) async => 8),
      ], child: MaterialApp(home: child));
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
  }

  test('캘린더 API가 0건이어도 기한 없는 Canvas 과제를 수집한다', () async {
    await assignments.refresh(8, force: true);
    final row = (await assignments.watchTerm(8).first).single;
    expect(row.title, '레포트 제출');
    expect(row.startAt, isNull);
    expect(row.contextName, '정치학입문-01');
    expect(row.htmlUrl, '/courses/5342/assignments/9001');
  });

  test('공지 원본에 강좌명과 URL이 없어도 소속과 웹뷰 경로를 채운다', () async {
    await announcements.refresh(8, force: true);
    final row = (await announcements.watch(8).first).single;
    expect(row.contextName, '정치학입문-01');
    expect(row.title, '레포트 안내');
    expect(row.htmlUrl, '/courses/5342/discussion_topics/9002');
  });

  test('마감 변경과 삭제를 반영하고 캘린더와 과제 중복은 하나로 합친다', () async {
    adapter.onGet(
        '/calendar-events',
        (s) => s.reply(200, {
              'code': '200',
              'data': {
                'calendarEvents': [
                  {
                    'id': 'assignment_9001',
                    'title': '이전 제목',
                    'start_at': '2026-09-10T00:00:00Z'
                  },
                ]
              }
            }));
    await assignments.refresh(8, force: true);
    expect((await assignments.watchTerm(8).first).single.startAt, isNull);
    adapter.onGet('/courses/5342/assignments', (s) => s.reply(200, []));
    await assignments.refresh(8, force: true);
    expect(await assignments.watchTerm(8).first, isEmpty);
  });

  test('과제 조회 실패 시 저장된 과제를 지우지 않는다', () async {
    await assignments.refresh(8, force: true);
    adapter.onGet('/courses/5342/assignments', (s) => s.reply(500, {}));
    await expectLater(
        assignments.refresh(8, force: true), throwsA(isA<Failure>()));
    expect((await assignments.watchTerm(8).first).single.title, '레포트 제출');
  });

  test('과제 다음 페이지를 읽어 첫 페이지 뒤의 항목도 표시한다', () async {
    adapter.onGet(
        '/courses/5342/assignments',
        (s) => s.reply(200, [
              {'id': 1, 'name': '첫 과제'}
            ], headers: {
              'content-type': ['application/json'],
              'link': [
                '<https://canvas.kumoh.ac.kr/api/v1/courses/5342/assignments?page=2>; rel="next"'
              ]
            }));
    adapter.onGet(
        'https://canvas.kumoh.ac.kr/api/v1/courses/5342/assignments?page=2',
        (s) => s.reply(200, [
              {'id': 2, 'name': '다음 과제'}
            ]));
    expect((await canvas.fetchAssignments(5342)).map((a) => a.name),
        ['첫 과제', '다음 과제']);
  });

  testWidgets('모든 강좌에 9개 고정 탭을 표시하고 공지 원본을 연다', (tester) async {
    await tester.pumpWidget(wrap(const CourseDetailScreen(
        courseId: 5342, courseName: '정치학입문-01', initialTab: 'announcements')));
    await settle(tester);
    final tabs = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabs.tabs.cast<Tab>().map((t) => t.text),
        ['홈', '공지', '강의실', '과제', '강의자료실', '토론', '성적', '사용자 및 그룹', '강의 계획']);
    expect(find.text('레포트 안내'), findsOneWidget);
    expect(find.textContaining('준비 중'), findsNothing);
    await tester.tap(find.text('레포트 안내'));
    await settle(tester);
    expect(tester.widget<CanvasWebScreen>(find.byType(CanvasWebScreen)).url,
        '/courses/5342/discussion_topics/9002');
    await close(tester);
  });

  testWidgets('전체 공지에 강좌명을 표시하고 클릭하면 내부 웹뷰로 연다', (tester) async {
    await tester.pumpWidget(wrap(const AnnouncementsScreen()));
    await settle(tester);
    expect(find.textContaining('정치학입문-01'), findsOneWidget);
    await tester.tap(find.text('레포트 안내'));
    await settle(tester);
    expect(find.byType(CanvasWebScreen), findsOneWidget);
    await close(tester);
  });

  testWidgets('기한 없는 레포트가 캘린더 하단과 목록에 모두 나타난다', (tester) async {
    await tester.pumpWidget(wrap(const AssignmentsScreen()));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('기한 없는 과제'), 200,
        scrollable: find
            .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('레포트 제출'), findsOneWidget);
    await tester.tap(find.text('목록'));
    await settle(tester);
    expect(find.text('레포트 제출'), findsOneWidget);
    expect(find.textContaining('기한 없음'), findsOneWidget);
    await close(tester);
  });
}
