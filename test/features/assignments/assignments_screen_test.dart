import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/assignments/presentation/assignments_screen.dart';
import 'package:kumoh_lms/features/reference/presentation/term_providers.dart';
import 'package:kumoh_lms/providers.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late Dio dio;

  setUpAll(() => initializeDateFormatting('ko_KR'));
  setUp(() {
    db = createTestDatabase();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    final adapter = DioAdapter(dio: dio);
    adapter.onGet('/courses', (s) => s.reply(500, {}));
    adapter.onGet('/dashboard/total/announcement', (s) => s.reply(500, {}));
  });
  tearDown(() => db.close());

  Widget wrap() => ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          dioProvider.overrideWithValue(dio),
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          activeTermIdProvider.overrideWith((ref) async => 8),
        ],
        child: const MaterialApp(home: AssignmentsScreen()),
      );

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
}
