import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasAuthority || !{'http', 'https'}.contains(uri.scheme)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 웹 주소가 아닙니다.')),
      );
    }
    return false;
  }
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return true;
  } on Exception {
    // 외부 브라우저가 없거나 플랫폼이 열기를 거부하면 화면에서 안내한다.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('링크를 열 수 없습니다. 잠시 후 다시 시도해 주세요.')),
    );
  }
  return false;
}
