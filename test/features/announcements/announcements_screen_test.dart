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
import 'package:kumoh_lms/features/notifications/data/notification_store.dart';

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
          canvasDioProvider.overrideWithValue(dio),
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          activeTermIdProvider.overrideWith((ref) async => 8),
        ],
        child: const MaterialApp(home: AnnouncementsScreen()),
      );

  testWidgets('통합 알림을 파일·토론·과제로 분류하고 전송한 내역도 표시한다', (tester) async {
    await NotificationStore(db).enable('student');
    for (final kind in ['file', 'discussion', 'assignment']) {
      await db
          .into(db.notificationOutbox)
          .insert(NotificationOutboxCompanion.insert(
            generation: 'previous',
            owner: 'student',
            courseId: 4831,
            courseName: '테스트 강의',
            kind: kind,
            title: '$kind 새 소식',
            itemId: const Value('42'),
            delivered: const Value(true),
          ));
    }
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.text('file 새 소식'), findsOneWidget);
    expect(find.text('discussion 새 소식'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '파일'));
    await tester.pumpAndSettle();
    expect(find.text('file 새 소식'), findsOneWidget);
    expect(find.text('discussion 새 소식'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, '토론'));
    await tester.pumpAndSettle();
    expect(find.text('discussion 새 소식'), findsOneWidget);
    expect(find.text('file 새 소식'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, '전체'));
    await tester.pumpAndSettle();
    expect(find.text('assignment 새 소식'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

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

  testWidgets('새로고침이 실패하면 캐시를 유지한 채 배너로 알린다', (tester) async {
    await db.announcementsDao.replaceForTerm(8, [
      AnnouncementsCompanion.insert(
        id: '991',
        termId: 8,
        courseId: const Value(4831),
        title: '2주차 실습 안내',
        contextName: const Value('리눅스시스템프로그래밍-01'),
        postedAt: Value(DateTime.utc(2026, 9, 3, 1)),
      ),
    ]);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.textContaining('저장된 데이터를 표시합니다'), findsOneWidget,
        reason: '실패를 알리지 않으면 학생이 낡은 데이터를 최신으로 오해한다');
    expect(find.text('2주차 실습 안내'), findsOneWidget,
        reason: '실패해도 캐시는 화면에 남아야 한다');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
