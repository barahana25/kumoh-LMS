import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/canvas/data/inline_file_type.dart';

void main() {
  test('허용 목록의 형식은 그대로 돌려준다', () {
    for (final type in [
      'application/pdf',
      'image/png',
      'image/jpeg',
      'image/gif',
      'image/webp',
      'text/plain',
      'audio/mpeg',
      'video/mp4',
    ]) {
      expect(inlineViewableType(type), type, reason: type);
    }
  });

  test('대소문자와 매개변수를 정규화한다', () {
    expect(inlineViewableType('Application/PDF; charset=binary'),
        'application/pdf');
    expect(inlineViewableType(' text/plain;charset=UTF-8 '), 'text/plain');
    expect(inlineViewableType('VIDEO/QuickTime'), 'video/quicktime');
  });

  test('스크립트가 돌 수 있는 형식과 빈 값은 null이다', () {
    for (final type in [
      'image/svg+xml',
      'text/html',
      'text/html; charset=utf-8',
      'application/xhtml+xml',
      'text/xml',
      'application/xml',
      'application/octet-stream',
      'audio/',
      'video',
      '',
      null,
    ]) {
      expect(inlineViewableType(type), isNull, reason: '$type');
    }
  });
}
