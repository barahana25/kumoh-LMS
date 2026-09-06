import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_api.dart';
import 'package:kumoh_lms/features/canvas/presentation/course_detail_screen.dart';
import 'package:kumoh_lms/providers.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUpAll(() => initializeDateFormatting('ko_KR'));
  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Widget wrap({
    required List<CourseTab> tabs,
    Object? tabsError,
  }) =>
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          courseTabsProvider(4831).overrideWith((ref) async {
            if (tabsError != null) throw tabsError;
            return tabs;
          }),
        ],
        child: const MaterialApp(
          home: CourseDetailScreen(courseId: 4831, courseName: '리눅스시스템프로그래밍-01'),
        ),
      );

  const sample = [
    CourseTab(id: 'home', label: '홈', position: 1),
    CourseTab(id: 'assignments', label: '과제', position: 2),
    CourseTab(id: 'syllabus', label: '강의 계획', position: 3),
  ];

  testWidgets('강좌 이름을 제목으로 보여준다', (tester) async {
    await tester.pumpWidget(wrap(tabs: sample));
    await tester.pumpAndSettle();

    expect(find.text('리눅스시스템프로그래밍-01'), findsOneWidget);
  });

  testWidgets('서버가 준 탭을 순서대로 그린다', (tester) async {
    await tester.pumpWidget(wrap(tabs: sample));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Tab, '홈'), findsOneWidget);
    expect(find.widgetWithText(Tab, '과제'), findsOneWidget);
    expect(find.widgetWithText(Tab, '강의 계획'), findsOneWidget);
    // 서버가 주지 않은 탭은 그리지 않는다.
    expect(find.widgetWithText(Tab, '성적'), findsNothing);
  });

  testWidgets('강좌마다 다른 탭 구성을 그대로 따른다', (tester) async {
    await tester.pumpWidget(wrap(tabs: const [
      CourseTab(id: 'home', label: '홈', position: 1),
      CourseTab(id: 'grades', label: '성적', position: 2),
    ]));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Tab, '성적'), findsOneWidget);
    expect(find.widgetWithText(Tab, '과제'), findsNothing,
        reason: '탭 목록을 하드코딩하면 강좌별 차이를 반영하지 못한다');
  });

  testWidgets('탭 목록을 못 받으면 사용자 문구로 알린다', (tester) async {
    await tester.pumpWidget(wrap(
      tabs: const [],
      tabsError: const NetworkFailure(),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('네트워크에 연결할 수 없습니다'), findsOneWidget);
    // raw 예외가 한국어 UI에 새면 안 된다.
    expect(find.textContaining('NetworkFailure'), findsNothing);
  });

  testWidgets('탭이 하나도 없으면 빈 상태를 보여준다', (tester) async {
    await tester.pumpWidget(wrap(tabs: const []));
    await tester.pumpAndSettle();

    expect(find.textContaining('표시할 탭이 없습니다'), findsOneWidget);
  });
}
