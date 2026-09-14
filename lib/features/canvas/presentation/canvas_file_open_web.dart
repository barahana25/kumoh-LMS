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
            options: Options(responseType: ResponseType.bytes),
          );
    } on DioException catch (e) {
      throwAsFailure(e);
    }

    final bytes = Uint8List.fromList(res.data ?? const []);
    final type = res.headers.value('content-type') ?? 'application/octet-stream';
    final blob = web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: type));
    final objectUrl = web.URL.createObjectURL(blob);

    if (win != null) {
      win.location.href = objectUrl;
    } else {
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
