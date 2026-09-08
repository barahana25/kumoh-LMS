import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/notifications/foreground_notification_check.dart';

void main() {
  test('OS 예약 오류가 발생해도 화면의 현재 조회와 다음 회차는 실행된다', () async {
    var checks = 0;
    var registrations = 0;
    for (var tick = 0; tick < 2; tick++) {
      await runForegroundNotificationCheck(
        schedule: () async {
          registrations++;
          throw PlatformException(code: 'registration_failed');
        },
        check: () async { checks++; },
      );
    }
    expect(registrations, 2);
    expect(checks, 2);
  });
}
