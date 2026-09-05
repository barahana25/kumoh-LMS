import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/courses/presentation/course_list_screen.dart';
import 'package:kumoh_lms/features/reference/presentation/term_providers.dart';
import 'package:kumoh_lms/providers.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late Dio dio;
  late DioAdapter adapter;
  late List<int> requestedTerms;

  setUp(() {
    db = createTestDatabase();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    adapter = DioAdapter(dio: dio);
    adapter.onGet('/courses', (s) => s.reply(500, {}));
    requestedTerms = [];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      requestedTerms.add(o.queryParameters['termId'] as int);
      h.next(o);
    }));
  });
  tearDown(() => db.close());

  Widget wrap() => ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          dioProvider.overrideWithValue(dio),
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          // 네트워크를 타지 않도록 학기를 고정한다.
          activeTermIdProvider.overrideWith((ref) => ref.watch(selectedTermIdProvider) ?? 8),
        ],
        child: const MaterialApp(home: CourseListScreen()),
      );

  testWidgets('캐시된 강좌를 카드로 보여준다', (tester) async {
    await db.coursesDao.upsertAll([
      CoursesCompanion.insert(
        id: const Value(4831),
        termId: 8,
        name: '리눅스시스템프로그래밍-01',
        courseCode: 'GA2015-01',
        institution: const Value('인공지능공학전공'),
        teacherNames: const Value('[컴퓨터공학부] 윤현주'),
        totalStudents: const Value(28),
      ),
    ]);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('리눅스시스템프로그래밍-01'), findsOneWidget);
    expect(find.textContaining('윤현주'), findsOneWidget);
    expect(find.textContaining('인공지능공학전공'), findsOneWidget);
    expect(find.textContaining('저장된 데이터를 표시합니다'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('학기 변경은 새 강좌를 조회하고 짧은 목록도 강제로 새로고침한다', (tester) async {
    adapter.onGet('/courses', (s) => s.replyCallback(200, (o) {
      final term = o.queryParameters['termId'] as int;
      return {'code': '200', 'data': {'courses': [
        {'id': term * 10, 'name': '학기 $term 강좌', 'courseCode': 'TEST'},
      ]}};
    }));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.text('학기 8 강좌'), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.byType(CourseListScreen)));
    container.read(selectedTermIdProvider.notifier).state = 6;
    await tester.pumpAndSettle();
    expect(find.text('학기 6 강좌'), findsOneWidget);
    expect(find.text('학기 8 강좌'), findsNothing);
    expect(requestedTerms, [8, 6]);
    await tester.drag(find.byType(ListView), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(requestedTerms, [8, 6, 6]);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('강좌가 없으면 빈 상태를 보여준다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('수강 중인 강좌가 없습니다'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
