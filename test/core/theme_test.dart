import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/config/theme.dart';

void main() {
  test('브랜드 색은 금오공대 테마색이다', () {
    expect(kKitBrand, const Color(0xFF00A9CE));
  });

  test('라이트/다크 테마 모두 Material3이며 브랜드 시드를 쓴다', () {
    final light = buildLightTheme();
    final dark = buildDarkTheme();

    expect(light.useMaterial3, isTrue);
    expect(dark.useMaterial3, isTrue);
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
  });
}
