import 'dart:io';
import 'package:flutter/services.dart';

class BackgroundSettings {
  static bool get supported => Platform.isAndroid;
  static const _channel = MethodChannel('ac.kumoh.kumoh_lms/background');

  static Future<bool?> batteryUnrestricted() async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<bool>('isBatteryUnrestricted');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Future<void> openAppSettings() =>
      _channel.invokeMethod<void>('openAppSettings');
}
