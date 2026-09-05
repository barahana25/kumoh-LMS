import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/core/network/api_envelope.dart';

void main() {
  group('unwrapEnvelope', () {
    test('code가 200이면 data를 파싱해 반환한다', () {
      final body = {
        'code': '200',
        'message': 'Success',
        'data': {'id': 1, 'name': 'KIT'},
      };
      final result = unwrapEnvelope(body, (d) => (d! as Map)['name'] as String);
      expect(result, 'KIT');
    });

    test('code가 200이 아니면 ServerFailure를 던진다', () {
      final body = {
        'code': 'U004',
        'message': 'No static resource api/v1/user.',
        'data': null,
      };
      expect(
        () => unwrapEnvelope(body, (d) => d),
        throwsA(isA<ServerFailure>()
            .having((f) => f.code, 'code', 'U004')
            .having((f) => f.message, 'message', contains('No static resource'))),
      );
    });

    test('봉투가 아닌 바디는 ParseFailure를 던진다', () {
      expect(() => unwrapEnvelope('보통 문자열', (d) => d), throwsA(isA<ParseFailure>()));
    });

    test('data가 null이어도 parse에 null을 넘긴다', () {
      final body = {'code': '200', 'message': 'Success', 'data': null};
      expect(unwrapEnvelope(body, (d) => d), isNull);
    });
  });

  group('failureFromResponse', () {
    test('401은 AuthFailure로 매핑한다', () {
      final f = failureFromResponse(401, {
        'timestamp': '2026-09-04T15:25:53.939+00:00',
        'status': 401,
        'error': 'Unauthorized',
        'path': '/api/v1/user/profile',
      });
      expect(f, isA<AuthFailure>());
    });

    test('원시 Spring 에러 바디를 ServerFailure로 매핑한다', () {
      final f = failureFromResponse(500, {
        'timestamp': '2026-09-04T15:25:53.810+00:00',
        'status': 500,
        'error': 'Internal Server Error',
        'path': '/api/v1/user/profile',
      });
      expect(f, isA<ServerFailure>());
      expect((f as ServerFailure).code, '500');
      expect(f.message, contains('Internal Server Error'));
    });

    test('앱 봉투 에러 바디를 code와 함께 ServerFailure로 매핑한다', () {
      final f = failureFromResponse(500, {
        'code': 'A001',
        'message': 'SSO 연동 ID가 존재하지 않습니다.',
        'data': null,
      });
      expect(f, isA<ServerFailure>());
      expect((f as ServerFailure).code, 'A001');
      expect(f.message, 'SSO 연동 ID가 존재하지 않습니다.');
    });

    test('바디가 없으면 ServerFailure에 상태코드만 담는다', () {
      final f = failureFromResponse(503, null);
      expect(f, isA<ServerFailure>());
      expect((f as ServerFailure).code, '503');
    });
  });
}
