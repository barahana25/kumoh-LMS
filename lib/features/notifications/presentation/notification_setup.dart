import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/token_store.dart';
import '../../../providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../background_settings.dart';
import '../data/notification_store.dart';
import '../notification_runtime.dart';
import 'notification_settings_section.dart';

/// 새 소식 알림을 켠다. 켰으면 null, 못 켰으면 사용자에게 보여줄 안내를 돌려준다.
///
/// 설정 탭의 스위치와 첫 실행 안내 화면이 함께 쓴다. [stillValid]가 false면
/// 권한 창을 닫는 사이 화면이 사라졌거나 계정이 바뀐 것이므로 저장하지 않는다.
Future<String?> enableNotifications(WidgetRef ref,
    {required bool Function() stillValid}) async {
  final db = ref.read(appDatabaseProvider);
  final tokens = ref.read(tokenStoreProvider);
  final auth = ref.read(authControllerProvider).valueOrNull;
  var stage = '자동 로그인 정보 확인';
  try {
    if (!await hasMatchingCredentials(auth, tokens)) {
      return '자동 로그인을 켜고 다시 로그인한 후 알림을 켜 주세요.';
    }
    stage = '알림 기능 준비';
    await NotificationRuntime.initialize();
    stage = '알림 권한 요청';
    if (!await NotificationRuntime.sink.requestPermission()) {
      return '기기 설정에서 금오 LMS의 알림을 허용해 주세요.';
    }
    if (!stillValid() || ref.read(authControllerProvider).valueOrNull != auth) {
      return null;
    }
    stage = '알림 설정 저장';
    final login = (auth! as AuthAuthenticated).profile.loginId;
    await NotificationStore(db).enable(login);
    try {
      stage = '자동 확인 예약';
      await NotificationRuntime.schedule();
    } on Exception {
      await NotificationStore(db).disable();
      rethrow;
    }
    // 켜기만 한다. 첫 조회는 예약된 회차나 '지금 확인'에서 수행한다.
    return null;
  } on Exception catch (e) {
    return notificationSetupMessage(stage, e);
  } finally {
    ref.invalidate(notificationSettingsProvider);
  }
}

/// 자동 로그인으로 저장한 계정이 지금 로그인한 계정과 같은가.
/// 백그라운드 확인은 저장된 자격증명으로 따로 로그인하므로 이게 없으면 알림을 켤 수 없다.
Future<bool> hasMatchingCredentials(Object? auth, TokenStore tokens) async {
  if (auth is! AuthAuthenticated) return false;
  final credentials = await tokens.readCredentials();
  return credentials != null &&
      credentials.userId.trim().toUpperCase() ==
          auth.profile.loginId.trim().toUpperCase();
}

const backgroundSetupSeenKey = 'onboarding:background-setup';

/// 로그인 뒤 알림·백그라운드 안내를 띄울 기기인가. 테스트에서 덮어쓴다.
final backgroundSetupSupportedProvider =
    Provider<bool>((ref) => BackgroundSettings.supported);

/// 첫 실행 안내를 띄워야 하는가.
///
/// Android에서 자동 로그인한 계정이고, 아직 안내를 본 적이 없을 때만 띄운다.
/// 기록은 로그아웃 때 캐시와 함께 지워지므로 다시 로그인하면 한 번 더 안내한다.
/// 그때는 알림 설정도 지워져 다시 켜야 하기 때문이다.
final backgroundSetupDueProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (!ref.watch(backgroundSetupSupportedProvider)) return false;
  final auth = ref.watch(authControllerProvider).valueOrNull;
  if (!await hasMatchingCredentials(auth, ref.read(tokenStoreProvider))) {
    return false;
  }
  final db = ref.read(appDatabaseProvider);
  return await db.cacheMetaDao.fetchedAt(backgroundSetupSeenKey) == null;
});
