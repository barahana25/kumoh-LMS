import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/config/env.dart';

void main() {
  test('Env는 LINUS API base URL을 노출한다', () {
    expect(Env.apiBaseUrl, 'https://lms.kumoh.ac.kr:82/api/v1');
    expect(Env.canvasHost, 'https://canvas.kumoh.ac.kr');
    expect(Env.defaultAccountId, 1);
  });
}
