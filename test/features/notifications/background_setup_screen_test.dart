import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/auth/data/auth_dto.dart';
import 'package:kumoh_lms/features/auth/presentation/auth_controller.dart';
import 'package:kumoh_lms/features/notifications/data/notification_store.dart';
import 'package:kumoh_lms/features/notifications/presentation/background_setup_screen.dart';
import 'package:kumoh_lms/features/notifications/presentation/notification_settings_section.dart';
import 'package:kumoh_lms/features/notifications/presentation/notification_setup.dart';
import 'package:kumoh_lms/providers.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Widget wrap(Widget home, {bool battery = false, bool due = false}) =>
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          backgroundBatteryProvider.overrideWith((ref) async => battery),
          backgroundSetupDueProvider.overrideWith((ref) async => due),
        ],
        child: MaterialApp(home: home),
      );

  testWidgets('아직 허용하지 않은 단계는 버튼과 나중에 하기를 보여준다', (tester) async {
    await tester.pumpWidget(wrap(const BackgroundSetupScreen()));
    await tester.pumpAndSettle();
    expect(find.text('허용하기'), findsOneWidget);
    expect(find.text('설정 열기'), findsOneWidget);
    expect(find.text('나중에 설정에서 할게요'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('허용한 단계는 완료로 바뀌고 모두 끝나면 시작하기만 남는다', (tester) async {
    await NotificationStore(db).enable('student');
    await tester.pumpWidget(wrap(const BackgroundSetupScreen(), battery: true));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('setup_done_1')), findsOneWidget);
    expect(find.byKey(const Key('setup_done_2')), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
    expect(find.text('나중에 설정에서 할게요'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('안내가 필요하면 한 번만 띄우고 본 것으로 기록한다', (tester) async {
    await tester.pumpWidget(wrap(const Scaffold(body: BackgroundSetupLauncher()),
        due: true));
    await tester.pumpAndSettle();

    expect(find.byType(BackgroundSetupScreen), findsOneWidget);
    expect(await db.cacheMetaDao.fetchedAt(backgroundSetupSeenKey), isNotNull,
        reason: '도중에 앱을 꺼도 다시 조르지 않도록 띄우는 순간 기록한다');

    await tester.tap(find.text('나중에 설정에서 할게요'));
    await tester.pumpAndSettle();
    expect(find.byType(BackgroundSetupScreen), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(BackgroundSetupScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('안내가 필요 없으면 띄우지 않는다', (tester) async {
    await tester.pumpWidget(wrap(const Scaffold(body: BackgroundSetupLauncher())));
    await tester.pumpAndSettle();
    expect(find.byType(BackgroundSetupScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  test('자동 로그인으로 저장한 계정이 지금 계정과 같을 때만 알림을 켤 수 있다', () async {
    const auth = AuthAuthenticated(
        profile: UserProfile(loginId: '20250000', name: '홍길동', role: 'student'));
    final tokens = InMemoryTokenStore();
    expect(await hasMatchingCredentials(auth, tokens), isFalse,
        reason: '자동 로그인을 끄면 백그라운드에서 로그인할 수 없다');

    await tokens.saveCredentials(userId: ' 20250000 ', password: 'pw');
    expect(await hasMatchingCredentials(auth, tokens), isTrue);

    await tokens.saveCredentials(userId: '20259999', password: 'pw');
    expect(await hasMatchingCredentials(auth, tokens), isFalse);
    expect(await hasMatchingCredentials(const AuthOffline(), tokens), isFalse);
  });
}
