import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/auth/data/auth_dto.dart';
import 'package:kumoh_lms/features/auth/presentation/auth_controller.dart';
import 'package:kumoh_lms/features/notifications/data/notification_store.dart';
import 'package:kumoh_lms/features/notifications/presentation/notification_setup.dart';
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

  testWidgets('새 소식 알림도 자동 로그인 정보가 없으면 켜지 않고 안내한다', (tester) async {
    String? message;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        authControllerProvider.overrideWith(_SignedIn.new),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async =>
                message = await enableNotifications(ref, stillValid: () => true),
            child: const Text('켜기'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('켜기'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    expect(message, '자동 로그인을 켜고 다시 로그인한 후 알림을 켜 주세요.');
    final saved = await tester.runAsync(() => NotificationStore(db).settings());
    expect(saved?.enabled ?? false, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
