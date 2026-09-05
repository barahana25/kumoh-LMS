import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/announcements/presentation/announcements_screen.dart';
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
        child: const MaterialApp(home: AnnouncementsScreen()),
      );

  testWidgets('공지 제목과 강좌명을 보여준다', (tester) async {
    await db.announcementsDao.replaceForTerm(8, [
      AnnouncementsCompanion.insert(
        id: '991',
        termId: 8,
        courseId: const Value(4831),
        title: '2주차 실습 안내',
        message: const Value('<p>실습실은 D동 401호입니다.</p>'),
        contextName: const Value('리눅스시스템프로그래밍-01'),
        authorName: const Value('윤현주'),
        postedAt: Value(DateTime.utc(2026, 9, 3, 1)),
      ),
    ]);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('2주차 실습 안내'), findsOneWidget);
    expect(find.textContaining('리눅스시스템프로그래밍-01'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('공지가 없으면 빈 상태를 보여준다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('새로운 공지가 없습니다'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
