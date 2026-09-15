import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// libcurl.js는 최상위 `const libcurl`로 선언해 window 속성을 만들지 않는다.
/// 앱의 @JS('libcurl')은 globalThis.libcurl을 읽으므로 index.html이 따로
/// 내보내지 않으면 "libcurl.js를 불러오지 못했습니다"로 모든 요청이 실패했다.
void main() {
  test('index.html이 libcurl을 window 전역으로 내보낸 뒤 Flutter를 시작한다', () {
    final html = File('web/index.html').readAsStringSync();

    final load = html.indexOf('<script src="vendor/libcurl.js"></script>');
    final export = html.indexOf('window.libcurl = libcurl;');
    final bootstrap = html.indexOf('<script src="flutter_bootstrap.js"');

    expect(load, isNonNegative);
    expect(export, greaterThan(load));
    expect(bootstrap, greaterThan(export));
  });
}
