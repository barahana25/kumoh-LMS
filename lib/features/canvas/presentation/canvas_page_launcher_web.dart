import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../../core/error/failure.dart';
import '../../../core/ui/empty_state.dart';
import '../../../providers.dart';
import '../data/canvas_session.dart' show isTrustedSamlAction;
import 'canvas_web_target.dart' show canvasRelayState;

/// 웹은 `.kumoh.ac.kr` 쿠키를 만들 수 없다. 대신 터널로 SAML 폼까지 받고,
/// 마지막 ACS POST를 브라우저 창이 직접 해서 Canvas 세션을 브라우저에 만든다.
/// SAMLResponse와 토큰은 브라우저와 학교 서버 사이에서만 오간다.
Future<void> launchCanvasPage(
  BuildContext context, {
  required String title,
  required String url,
}) async {
  final relayState = canvasRelayState(url)!;
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  // 사용자 탭 처리 안에서 먼저 연다. await 뒤에 열면 팝업으로 막힌다.
  final win = web.window.open('', '_blank');
  // Canvas 탭이 window.opener로 PWA 창에 손대지 못하게 끊는다.
  // 폼은 우리가 쥔 참조로 채우므로 opener가 없어도 된다.
  win?.opener = null;
  win?.document.body?.textContent = '$title 여는 중…';

  try {
    final form = await container
        .read(canvasSessionProvider)
        .fetchSamlForm(relayState: relayState);
    if (!isTrustedSamlAction(form.action)) {
      throw const AuthFailure('Canvas 연결 주소가 올바르지 않습니다.');
    }
    // 기다리는 사이 사용자가 창을 닫았으면 죽은 문서에 제출하지 않는다.
    if (win != null && win.closed) {
      messenger.showSnackBar(
          const SnackBar(content: Text('창이 닫혀 원문을 열지 못했습니다.')));
      return;
    }
    // 창을 못 열었으면 현재 창에서 제출한다. PWA가 Canvas로 넘어간다.
    final doc = (win ?? web.window).document;
    final formEl = doc.createElement('form') as web.HTMLFormElement
      ..method = 'POST'
      ..action = form.action;
    for (final (name, value) in [
      ('SAMLResponse', form.samlResponse),
      ('RelayState', form.relayState),
    ]) {
      formEl.append(doc.createElement('input') as web.HTMLInputElement
        ..type = 'hidden'
        ..name = name
        ..value = value);
    }
    doc.body!.append(formEl);
    formEl.submit();
  } on Object catch (e) {
    win?.close();
    messenger.showSnackBar(SnackBar(content: Text(userMessage(e))));
  }
}
