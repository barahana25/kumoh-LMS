import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../../core/ui/empty_state.dart';
import '../../../providers.dart';
import '../../auth/data/auth_api.dart' show throwAsFailure;
import '../data/canvas_download.dart' show safeFileName;
import '../data/inline_file_type.dart';

/// 세션이 붙은 dio(libcurl 터널)로 받아 Blob URL로 연다.
Future<void> openCanvasFile(
  BuildContext context,
  WidgetRef ref, {
  required String url,
  required String displayName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  // 사용자 탭 처리 안에서 먼저 연다. await 뒤에 열면 iOS Safari가 막는다.
  final win = web.window.open('', '_blank');
  messenger.showSnackBar(SnackBar(content: Text('$displayName 받는 중…')));

  try {
    final Response<List<int>> res;
    try {
      res = await ref.read(canvasDioProvider).getUri<List<int>>(
            Uri.parse(url),
            options: Options(
              responseType: ResponseType.bytes,
              // 웹 어댑터는 connect+receive를 요청 전체 제한으로 쓴다. 기본값(35초)이면
              // 큰 강의 자료는 받는 도중에 끊긴다.
              receiveTimeout: const Duration(minutes: 5),
            ),
          );
    } on DioException catch (e) {
      throwAsFailure(e);
    }

    final bytes = Uint8List.fromList(res.data ?? const []);
    // Blob URL은 PWA 출처를 물려받는다. 서버 MIME을 그대로 쓰면 HTML·SVG 안의
    // 스크립트가 PWA 저장소의 토큰을 읽을 수 있어, 허용 형식만 창에서 연다.
    final inlineType = inlineViewableType(res.headers.value('content-type'));
    final blob = web.Blob(<JSAny>[bytes.toJS].toJS,
        web.BlobPropertyBag(type: inlineType ?? 'application/octet-stream'));
    final objectUrl = web.URL.createObjectURL(blob);

    if (inlineType != null && win != null) {
      // 받는 사이 사용자가 창을 닫았으면 닫힌 창으로 보내지 않고 알린다.
      if (win.closed) {
        web.URL.revokeObjectURL(objectUrl);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
            const SnackBar(content: Text('창이 닫혀 파일을 열지 못했습니다.')));
        return;
      }
      win.location.href = objectUrl;
    } else {
      win?.close();
      (web.HTMLAnchorElement()
            ..href = objectUrl
            ..download = safeFileName(displayName))
          .click();
    }
    messenger.hideCurrentSnackBar();
    Future<void>.delayed(
        const Duration(minutes: 1), () => web.URL.revokeObjectURL(objectUrl));
  } on Object catch (e) {
    win?.close();
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(userMessage(e))));
  }
}
