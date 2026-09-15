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

  testWidgets('통합 알림을 파일·과제로 분류하고 예전 토론 알림은 숨긴다', (tester) async {
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
    expect(find.text('discussion 새 소식'), findsNothing,
        reason: '예전 알림 내역에는 학생 토론이 섞여 있어 강의자 글만 모은 목록으로 대신한다');
    await tester.tap(find.widgetWithText(ChoiceChip, '파일'));
    await tester.pumpAndSettle();
    expect(find.text('file 새 소식'), findsOneWidget);
    expect(find.text('assignment 새 소식'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, '토론'));
    await tester.pumpAndSettle();
    expect(find.text('토론 소식이 없습니다'), findsOneWidget);
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
    expect(find.text('리눅스시스템프로그래밍'), findsOneWidget);
    expect(find.textContaining('윤현주'), findsNothing, reason: '목록에는 강의명만 둔다');
    expect(find.text('실습실은 D동 401호입니다.'), findsOneWidget,
        reason: '본문은 태그를 걷어낸 미리보기로 보여준다');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('안 읽은 소식에 빨간 점을 달고 모두 읽음으로 지운다', (tester) async {
    await db.announcementsDao.replaceForTerm(8, [
      for (final id in ['1', '2'])
        AnnouncementsCompanion.insert(
          id: id,
          termId: 8,
          courseId: const Value(4831),
          title: '공지 $id',
          postedAt: Value(DateTime.utc(2026, 9, 3, 1)),
        ),
    ]);
    await db.into(db.readNotices).insert(ReadNoticesCompanion.insert(
        key: 'announcement:2', readAt: DateTime.utc(2026, 9, 4)));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('unread:announcement:1')), findsOneWidget);
    expect(find.byKey(const ValueKey('unread:announcement:2')), findsNothing);
    expect(find.text('1'), findsOneWidget, reason: '공지사항 상자 제목 옆에 안 읽은 개수');

    await tester.tap(find.text('모두 읽음'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('unread:announcement:1')), findsNothing);
    expect(find.text('모두 읽음'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('공지는 위 상자에 3개씩, 화살표로 오래된 공지를 넘긴다', (tester) async {
    await db.announcementsDao.replaceForTerm(8, [
      for (var i = 1; i <= 7; i++)
        AnnouncementsCompanion.insert(
          id: '$i',
          termId: 8,
          courseId: const Value(4831),
          title: '공지 $i',
          postedAt: Value(DateTime.utc(2026, 9, i)),
        ),
      AnnouncementsCompanion.insert(
        id: 'assignment:9',
        kind: const Value('assignment'),
        termId: 8,
        courseId: const Value(4831),
        title: '과제 소식',
        postedAt: Value(DateTime.utc(2026, 9, 10)),
      ),
    ]);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('공지 7'), findsOneWidget, reason: '최신 공지부터');
    expect(find.text('공지 5'), findsOneWidget);
    expect(find.text('공지 4'), findsNothing);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('과제 소식'), findsOneWidget, reason: '공지가 아닌 소식은 아래 상자에');

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('공지 4'), findsOneWidget);
    expect(find.text('공지 7'), findsNothing);
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('공지 1'), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(
                find.widgetWithIcon(IconButton, Icons.chevron_right))
            .onPressed,
        isNull,
        reason: '가장 오래된 페이지에서는 더 넘길 수 없다');

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  test('강좌명에서 학과 표기와 분반 번호를 뗀다', () {
    expect(shortCourseName('AI기초프로젝트 01 [컴퓨터공학부]'), 'AI기초프로젝트');
    expect(shortCourseName('AI기초프로젝트 01 [컴퓨터공학부] 시종욱'), 'AI기초프로젝트');
    expect(shortCourseName('운영체제(02) [컴퓨터공학부]'), '운영체제');
    expect(shortCourseName('리눅스시스템프로그래밍-01'), '리눅스시스템프로그래밍');
    expect(shortCourseName('캡스톤디자인 2'), '캡스톤디자인 2');
  });

  test('오늘은 시각, 어제는 어제, 그 전은 날짜로 표시한다', () {
    final now = DateTime(2026, 9, 14, 18);
    expect(formatNoticeTime(DateTime(2026, 9, 14, 15, 5), now), '오후 3:05');
    expect(formatNoticeTime(DateTime(2026, 9, 13, 23), now), '어제');
    expect(formatNoticeTime(DateTime(2026, 9, 9, 10), now), '9월 9일');
    expect(formatNoticeTime(DateTime(2025, 12, 1), now), '25.12.1');
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
