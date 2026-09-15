import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// 웹에서 `Platform.isAndroid`를 읽으면 UnsupportedError가 난다.
/// kIsWeb을 먼저 확인해 VM 테스트의 기존 동작(호스트 OS 기준)은 그대로 둔다.
bool get isAndroidApp => !kIsWeb && Platform.isAndroid;

bool get isIOSApp => !kIsWeb && Platform.isIOS;
