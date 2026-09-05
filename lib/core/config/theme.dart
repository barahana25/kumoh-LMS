import 'package:flutter/material.dart';

/// 학교 포털이 쓰는 테마색 (/accounts 의 themeColor).
const Color kKitBrand = Color(0xFF00A9CE);

ThemeData _base(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: kKitBrand, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      filled: true,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
  );
}

ThemeData buildLightTheme() => _base(Brightness.light);
ThemeData buildDarkTheme() => _base(Brightness.dark);
