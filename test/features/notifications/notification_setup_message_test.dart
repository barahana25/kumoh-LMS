import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:kumoh_lms/features/notifications/presentation/notification_settings_section.dart';

void main() {
  group('notificationSetupMessage', () {
    test('PlatformException은 실패 단계와 코드를 보여준다', () {
      final message = notificationSetupMessage(
          '자동 로그인 정보 확인', PlatformException(code: 'BadPaddingException'));
      expect(message, contains('자동 로그인 정보 확인'));
      expect(message, contains('BadPaddingException'));
    });

    test('형식을 벗어난 코드는 고정 식별자로 대체한다', () {
      final message = notificationSetupMessage(
          '자동 확인 예약', PlatformException(code: 'user=A1234 실패: 원문 메시지'));
      expect(message, contains('platform_error'));
      expect(message, isNot(contains('A1234')));
    });

    test('네이티브 상세 메시지는 노출하지 않는다', () {
      final message = notificationSetupMessage(
          '알림 권한 요청',
          PlatformException(
              code: 'error', message: 'password=secret', details: 'A1234'));
      expect(message, isNot(contains('secret')));
      expect(message, isNot(contains('A1234')));
    });

    test('SqliteException은 숫자 코드만 보여준다', () {
      final message =
          notificationSetupMessage('알림 설정 저장', SqliteException(11, 'db corrupt'));
      expect(message, contains('알림 설정 저장'));
      expect(message, contains('11'));
      expect(message, isNot(contains('corrupt')));
    });

    test('그 밖의 예외는 단계만 알려준다', () {
      final message = notificationSetupMessage('첫 확인', Exception('boom'));
      expect(message, contains('첫 확인'));
      expect(message, isNot(contains('boom')));
    });
  });
}
