import 'package:flutter/material.dart';

import '../../../core/config/env.dart';
import 'canvas_web_screen.dart';

/// SSO에 넘길 relayState(경로)를 만든다.
///
/// Canvas 밖 주소는 받지 않는다. 외부 링크를 SSO에 태우면 학교 세션이 남의
/// 사이트로 흘러갈 수 있다.
String? canvasRelayState(String rawUrl) {
  final url = rawUrl.trim();
  if (url.isEmpty) return null;

  // 이미 경로면 그대로.
  if (url.startsWith('/')) return url;

  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasAuthority) return null;

  final canvasHost = Uri.parse(Env.canvasHost).host;
  if (uri.host != canvasHost) return null;

  final path = uri.path.isEmpty ? '/' : uri.path;
  final query = uri.hasQuery ? '?${uri.query}' : '';
  final fragment = uri.hasFragment ? '#${uri.fragment}' : '';
  return '$path$query$fragment';
}

/// Canvas 링크는 로그인된 WebView로 연다.
///
/// 외부 브라우저로 보내면 세션이 없어 매번 로그인 화면이 뜬다.
/// Canvas 밖 주소는 애초에 이 앱이 다룰 대상이 아니므로 열지 않는다.
Future<void> openCanvasPage(
  BuildContext context, {
  required String title,
  required String url,
}) async {
  if (canvasRelayState(url) == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('이 링크는 앱에서 열 수 없습니다.')),
    );
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CanvasWebScreen(title: title, url: url),
    ),
  );
}
