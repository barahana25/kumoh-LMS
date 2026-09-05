import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/auth/presentation/login_screen.dart';
import 'package:kumoh_lms/providers.dart';

import '../../fixtures/fixtures.dart';
import '../../helpers/test_db.dart';

void main() {
  late InMemoryTokenStore store;
  late AppDatabase db;
  late Dio authDio;
  late DioAdapter authAdapter;

  setUp(() {
    store = InMemoryTokenStore();
    db = createTestDatabase();
    authDio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    authAdapter = DioAdapter(dio: authDio);
  });
  tearDown(() => db.close());

  Widget wrap() => ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(store),
          appDatabaseProvider.overrideWithValue(db),
          authDioProvider.overrideWithValue(authDio),
        ],
        child: const MaterialApp(home: LoginScreen()),
      );

  testWidgets('학번과 비밀번호 입력란, 로그인 버튼이 보인다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('학번'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '로그인'), findsOneWidget);
    expect(find.text('자동 로그인'), findsOneWidget);
    // 보안 요구사항: 자동 로그인은 기본값이 꺼짐이어야 한다.
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
  });

  testWidgets('빈 입력으로 제출하면 검증 메시지를 보여준다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();

    expect(find.text('학번을 입력해 주세요.'), findsOneWidget);
    expect(find.text('비밀번호를 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('로그인 실패 시 에러 메시지를 보여준다', (tester) async {
    authAdapter.onPost(
      '/login',
      (s) => s.reply(200, {
        'code': 'U001',
        'message': '아이디 또는 비밀번호가 올바르지 않습니다.',
        'data': null,
      }),
      data: {'userId': '20250000', 'password': 'wrong'},
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('login_user_id')), '20250000');
    await tester.enterText(find.byKey(const Key('login_password')), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();

    expect(find.text('아이디 또는 비밀번호가 올바르지 않습니다.'), findsOneWidget);
  });

  testWidgets('로그인 성공 시 토큰이 저장된다', (tester) async {
    authAdapter.onPost('/login', (s) => s.reply(200, loginSuccessJson),
        data: {'userId': '20250000', 'password': 'pw'});
    authAdapter.onGet('/user/profile', (s) => s.reply(200, userProfileJson));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('login_user_id')), '20250000');
    await tester.enterText(find.byKey(const Key('login_password')), 'pw');
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();

    expect(await store.readAccessToken(), 'header.accessPayload.sig');
    // 자동 로그인 스위치를 켜지 않았으므로 자격증명은 저장되지 않아야 한다.
    expect(await store.readCredentials(), isNull);
  });
}
