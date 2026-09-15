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

const _filesQuery = {'per_page': 100, 'sort': 'created_at', 'order': 'desc'};

void main() {
  late AppDatabase db;
  late Dio dio;
  late DioAdapter adapter;
  late CanvasApi canvas;
  late AssignmentsRepository assignments;
  late AnnouncementsRepository announcements;
  // 목 어댑터는 나중에 등록한 경로가 이긴다. 토론 목을 바꾸면 공지 목을 다시 건다.
  void mockAnnouncements() => adapter.onGet(
      '/courses/5342/discussion_topics',
      (s) => s.reply(200, [
            {'id': 9002, 'title': '레포트 안내', 'message': '레포트에 대해 안내합니다.'},
          ]),
      queryParameters: {'only_announcements': true});
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
    adapter.onGet('/courses/5342/files', (s) => s.reply(200, []),
        queryParameters: _filesQuery);
    adapter.onGet('/courses/5342/discussion_topics', (s) => s.reply(200, []),
        queryParameters: {'per_page': 100});
    adapter.onGet(
        '/courses/5342/enrollments',
        (s) => s.reply(200, [
              {
                'type': 'TeacherEnrollment',
                'user_id': 900,
                'user': {'id': 900, 'name': '김교수'}
              },
            ]));
    mockAnnouncements();
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

  test('Canvas 과제의 내 제출 여부를 과제 목록에 저장한다', () async {
    adapter.onGet(
        '/courses/5342/assignments',
        (s) => s.reply(200, [
              {
                'id': 1,
                'name': '낸 과제',
                'submission': {'workflow_state': 'graded', 'submitted_at': '2026-09-10T00:00:00Z'},
              },
              {
                'id': 2,
                'name': '안 낸 과제',
                'submission': {'workflow_state': 'unsubmitted', 'submitted_at': null},
              },
              {
                'id': 3,
                'name': '점수만 입력된 과제',
                'submission': {'workflow_state': 'graded', 'submitted_at': null},
              },
            ]));
    await assignments.refresh(8, force: true);
    final byTitle = {
      for (final e in await assignments.watchTerm(8).first) e.title: e.submitted
    };
    expect(byTitle, {'낸 과제': true, '안 낸 과제': false, '점수만 입력된 과제': false});
  });

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
    final row = (await announcements.watch(8).first)
        .where((r) => r.kind == 'announcement')
        .single;
    expect(row.contextName, '정치학입문-01');
    expect(row.title, '레포트 안내');
    expect(row.htmlUrl, '/courses/5342/discussion_topics/9002');
  });

  test('공지 새로고침이 과제·강의자료·토론 탭도 함께 모은다', () async {
    final recent = DateTime.now().toUtc().subtract(const Duration(days: 1));
    adapter.onGet(
        '/courses/5342/assignments',
        (s) => s.reply(200, [
              {
                'id': 9001,
                'name': '레포트 제출',
                'description': '<p>A4 2장</p>',
                'created_at': recent.toIso8601String(),
                'submission': {
                  'workflow_state': 'submitted',
                  'submitted_at': recent.toIso8601String(),
                },
              },
              {'id': 9003, 'name': '비공개 과제', 'published': false},
            ]));
    adapter.onGet(
        '/courses/5342/files',
        (s) => s.reply(200, [
              {
                'id': 77,
                'display_name': '1주차.pdf',
                'created_at': '2026-03-02T00:00:00Z',
              },
            ]),
        queryParameters: _filesQuery);
    adapter.onGet(
        '/courses/5342/discussion_topics',
        (s) => s.reply(200, [
              {'id': 9002, 'title': '레포트 안내', 'is_announcement': true},
              {
                'id': 55,
                'title': '자기소개',
                'author': {'id': 900, 'display_name': '김교수'},
                'posted_at': recent.toIso8601String(),
              },
              {
                'id': 56,
                'title': '학생이 올린 질문',
                'author': {'id': 1234, 'display_name': '홍학생'},
                'posted_at': recent.toIso8601String(),
              },
            ]),
        queryParameters: {'per_page': 100});
    mockAnnouncements();

    await announcements.refresh(8, force: true);

    final rows = await announcements.watch(8).first;
    final byId = {for (final r in rows) r.id: r};
    expect(byId.keys, containsAll(['9002', 'assignment:9001', 'file:77', 'discussion:55']));
    expect(byId.containsKey('assignment:9003'), isFalse, reason: '비공개 과제는 숨긴다');
    expect(byId.containsKey('discussion:9002'), isFalse, reason: '공지는 토론으로 중복되면 안 된다');
    expect(byId.containsKey('discussion:56'), isFalse,
        reason: '학생이 올린 토론은 공지 탭에 필요 없다');
    expect(byId['assignment:9001']!.kind, 'assignment');
    expect(byId['assignment:9001']!.submitted, isTrue);
    expect(byId['file:77']!.htmlUrl, '/courses/5342/files/77');
    expect(byId['discussion:55']!.authorName, '김교수');

    final read = (await db.select(db.readNotices).get()).map((r) => r.key);
    expect(read, contains('file:77'), reason: '첫 동기화에서 오래된 소식은 읽음으로 둔다');
    expect(read, isNot(contains('assignment:9001')));
    expect(read, isNot(contains('discussion:55')));
  });

  test('수강 목록을 볼 수 없으면 담당 교수 이름으로 강의자 토론을 가린다', () async {
    await db.coursesDao.upsertAll([
      CoursesCompanion.insert(
          id: const Value(5342),
          termId: 8,
          name: '정치학입문-01',
          courseCode: 'POL-01',
          teacherNames: const Value('이교수, 박조교'))
    ]);
    adapter.onGet('/courses/5342/enrollments', (s) => s.reply(403, {}));
    adapter.onGet(
        '/courses/5342/discussion_topics',
        (s) => s.reply(200, [
              {
                'id': 1,
                'title': '조교 안내',
                'author': {'id': 7, 'display_name': '박조교'}
              },
              {
                'id': 2,
                'title': '학생 글',
                'author': {'id': 8, 'display_name': '박조'}
              },
            ]),
        queryParameters: {'per_page': 100});
    mockAnnouncements();

    await announcements.refresh(8, force: true);

    final titles = (await announcements.watch(8).first)
        .where((r) => r.kind == 'discussion')
        .map((r) => r.title);
    expect(titles, ['조교 안내'], reason: '이름 일부만 같은 학생 글은 거른다');
  });

  test('강의자료실이 닫힌 강좌는 실패로 보지 않는다', () async {
    adapter.onGet('/courses/5342/files', (s) => s.reply(403, {}),
        queryParameters: _filesQuery);

    await announcements.refresh(8, force: true);

    expect((await announcements.watch(8).first).map((r) => r.kind),
        containsAll(['announcement', 'assignment']));
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
    expect(find.textContaining('정치학입문'), findsWidgets);
    expect(find.textContaining('정치학입문-01'), findsNothing,
        reason: '분반 번호는 목록을 길게 만들 뿐이다');
    await tester.tap(find.text('레포트 안내'));
    await settle(tester);
    expect(find.byType(CanvasWebScreen), findsOneWidget);
    expect(await db.select(db.readNotices).get(), isNotEmpty,
        reason: '열어 본 공지는 읽음으로 남아야 빨간 점이 사라진다');
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
