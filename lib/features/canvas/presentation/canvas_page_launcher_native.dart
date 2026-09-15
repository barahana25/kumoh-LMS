import 'package:flutter/material.dart';

import 'canvas_web_screen.dart';

/// 네이티브는 쿠키를 주입할 수 있는 앱 내 WebView로 연다.
Future<void> launchCanvasPage(
  BuildContext context, {
  required String title,
  required String url,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CanvasWebScreen(title: title, url: url),
    ),
  );
}
