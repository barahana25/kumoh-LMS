import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kumoh_lms/app.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/auth/presentation/auth_controller.dart';
import 'package:kumoh_lms/features/reference/presentation/term_providers.dart';
import 'package:kumoh_lms/providers.dart';

import 'fixtures/fixtures.dart';
import 'helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late InMemoryTokenStore store;
  late Dio dio;
  late DioAdapter adapter;
  late ProviderContainer container;

  setUpAll(() => initializeDateFormatting('ko_KR'));
  setUp(() {
    db = createTestDatabase();
    store = InMemoryTokenStore();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    adapter = DioAdapter(dio: dio);
    adapter.onPost('/login', (s) => s.reply(200, loginSuccessJson),
      data: {'userId': '20250000', 'password': 'pw'});
    adapter.onGet('/user/profile', (s) => s.reply(200, userProfileJson));
    adapter.onPost('/logout', (s) => s.reply(200, {'code': '200', 'data': null}));
    adapter.onGet('/terms', (s) => s.reply(200, termsJson));
    adapter.onGet('/courses', (s) => s.reply(200, coursesJson));
    adapter.onGet('/calendar-events', (s) => s.reply(200, {
      'code': '200', 'data': {'calendarEvents': []},
    }));
    adapter.onGet('/dashboard/total/announcement', (s) => s.reply(200, {
      'code': '200', 'data': {'announcements': []},
    }));
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      tokenStoreProvider.overrideWithValue(store),
      authDioProvider.overrideWithValue(dio),
      dioProvider.overrideWithValue(dio),
    ]);
  });
  tearDown(() async {
    container.dispose();
    dio.close(force: true);
    await db.close();
  });

  // Drift may schedule work on the real event loop when a cached stream is
  // cancelled and re-subscribed. Flush both loops before settling animations.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    }
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container, child: const KumohLmsApp(),
    ));
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await settle(tester);
  }

  testWidgets('로그인부터 네 탭, 학기 선택 취소, 로그아웃까지 연결된다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await open(tester);
    expect(find.byKey(const Key('login_user_id')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.enterText(find.byKey(const Key('login_user_id')), '20250000');
    await tester.enterText(find.byKey(const Key('login_password')), 'pw');
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await settle(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('리눅스시스템프로그래밍-01'), findsOneWidget);
    expect(await store.readCredentials(), isNull);

    await tester.tap(find.byIcon(Icons.assignment_outlined).last);
    await settle(tester);
    expect(find.text('캘린더'), findsOneWidget);
    await tester.tap(find.text('목록'));
    await settle(tester);
    expect(find.text('예정된 과제가 없습니다'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.campaign_outlined).last);
    await settle(tester);
    expect(find.text('새로운 공지가 없습니다'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined).last);
    await settle(tester);
    expect(find.text('홍길동'), findsOneWidget);
    await tester.tap(find.text('학기'));
    await settle(tester);
    await tester.tap(find.text('2026-1학기'));
    await settle(tester);
    expect(container.read(selectedTermIdProvider), 6);
    await tester.tap(find.text('학기'));
    await settle(tester);
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);
    expect(container.read(selectedTermIdProvider), 6);

    await tester.tap(find.widgetWithText(ListTile, '로그아웃'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, '로그아웃'));
    await settle(tester);
    expect(find.byKey(const Key('login_user_id')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(await store.readRefreshToken(), isNull);
    expect(container.read(selectedTermIdProvider), isNull);
    expect(await tester.runAsync(() => db.coursesDao.watchByTerm(8).first), isEmpty);
    await close(tester);
  });

  testWidgets('오프라인 재시작에서도 캐시된 강좌와 연결 재시도를 표시한다', (tester) async {
    await store.saveTokens(accessToken: 'old', refreshToken: 'refresh');
    adapter.onPost('/reissue', (s) => s.throws(0, DioException(
      requestOptions: RequestOptions(path: '/reissue'),
      type: DioExceptionType.connectionError,
    )));
    adapter.onGet('/terms', (s) => s.reply(500, {}));
    adapter.onGet('/courses', (s) => s.reply(500, {}));
    await db.termsDao.upsertAll([TermsCompanion.insert(id: const Value(8), name: '저장된 학기',
      startAt: Value(DateTime.now().subtract(const Duration(days: 1))),
      endAt: Value(DateTime.now().add(const Duration(days: 1))),
    )]);
    await db.coursesDao.upsertAll([CoursesCompanion.insert(
      id: const Value(10), termId: 8, name: '오프라인 강좌', courseCode: 'TEST',
    )]);
    await open(tester);
    expect(find.text('오프라인 강좌'), findsOneWidget);
    expect(find.text('다시 연결'), findsOneWidget);
    expect(find.byKey(const Key('login_user_id')), findsNothing);
    await close(tester);
  });

  testWidgets('세션 복원이 끝나기 전에는 보호 화면과 요청을 시작하지 않는다', (tester) async {
    final ready = Completer<AuthState>();
    container.dispose();
    container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(() => _PendingAuth(ready.future)),
      activeTermIdProvider.overrideWith((ref) => throw StateError('보호 데이터 조기 요청')),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const KumohLmsApp()));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    ready.complete(const AuthUnauthenticated());
    await settle(tester);
    expect(find.byKey(const Key('login_user_id')), findsOneWidget);
    await close(tester);
  });
}

class _PendingAuth extends AuthController {
  _PendingAuth(this.ready);
  final Future<AuthState> ready;
  @override
  Future<AuthState> build() => ready;
}
