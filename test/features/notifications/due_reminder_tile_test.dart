import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/auth/data/auth_dto.dart';
import 'package:kumoh_lms/features/auth/presentation/auth_controller.dart';
import 'package:kumoh_lms/features/notifications/data/due_reminder_store.dart';
import 'package:kumoh_lms/features/notifications/presentation/due_reminder_tile.dart';
import 'package:kumoh_lms/providers.dart';
import '../../helpers/test_db.dart';

class _SignedIn extends AuthController {
  @override
  Future<AuthState> build() async => const AuthAuthenticated(
      profile: UserProfile(loginId: '20250000', name: '홍길동', role: 'student'));
}

void main() {
  late AppDatabase db;
  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Widget wrap({bool supported = true}) => ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          authControllerProvider.overrideWith(_SignedIn.new),
          dueRemindersSupportedProvider.overrideWithValue(supported),
        ],
        child: const MaterialApp(home: Scaffold(body: DueReminderTile())),
      );

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  SwitchListTile toggle(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.byKey(const Key('due_reminders')));

  /// 스위치를 누르고, 그 뒤의 실제 DB 작업이 끝날 때까지 기다린다.
  Future<void> tapToggle(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('due_reminders')));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
  }

  testWidgets('지원하지 않는 기기에서는 보이지 않는다', (tester) async {
    await tester.pumpWidget(wrap(supported: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('due_reminders')), findsNothing);
    await unmount(tester);
  });

  testWidgets('꺼져 있으면 상태 카드 없이 스위치만 보인다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(toggle(tester).value, isFalse);
    expect(find.text('과제 마감 알림'), findsOneWidget);
    expect(find.text('다음 확인부터 마감이 가까운 미제출 과제를 알려드립니다.'), findsNothing);
    await unmount(tester);
  });

  testWidgets('켜져 있어도 상태 카드 없이 스위치만 보인다', (tester) async {
    await tester.runAsync(() => DueReminderStore(db).enable('20250000'));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(toggle(tester).value, isTrue);
    expect(find.text('다음 확인부터 마감이 가까운 미제출 과제를 알려드립니다.'), findsNothing);
    await unmount(tester);
  });

  testWidgets('자동 로그인 정보가 없으면 켜지 않고 안내한다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tapToggle(tester);
    expect(find.text('자동 로그인을 켜고 다시 로그인한 후 마감 알림을 켜 주세요.'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget, reason: '실패 안내는 스낵바로 알린다');
    final saved = await tester.runAsync(() => DueReminderStore(db).settings());
    expect(saved?.enabled ?? false, isFalse);
    await unmount(tester);
  });

  testWidgets('끄면 저장소에서 꺼진다', (tester) async {
    await tester.runAsync(() => DueReminderStore(db).enable('20250000'));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tapToggle(tester);
    final saved = await tester.runAsync(() => DueReminderStore(db).settings());
    expect(saved!.enabled, isFalse);
    expect(toggle(tester).value, isFalse);
    await unmount(tester);
  });
}
