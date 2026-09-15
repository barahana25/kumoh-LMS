@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/platform/app_platform.dart';
import 'package:kumoh_lms/features/downloads/folder_storage.dart';
import 'package:kumoh_lms/features/notifications/background_settings.dart';
import 'package:kumoh_lms/features/notifications/notification_runtime.dart';

void main() {
  test('웹에서는 네이티브 전용 기능이 예외 없이 꺼진다', () {
    expect(isAndroidApp, isFalse);
    expect(isIOSApp, isFalse);
    expect(NotificationRuntime.supported, isFalse);
    expect(AndroidFolderStorage.supported, isFalse);
    expect(BackgroundSettings.supported, isFalse);
  });
}
