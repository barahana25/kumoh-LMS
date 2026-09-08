import 'dart:io';
import 'package:flutter/services.dart';

abstract interface class FolderStorage {
  Future<void> validate(String tree);
  Future<bool> exists(String uri);
  Future<String> save(String tree, String course, String name, File file);
}

class AndroidFolderStorage implements FolderStorage {
  static const channel = MethodChannel('kumoh/folders');
  static bool get supported => Platform.isAndroid;
  static Future<({String uri, String name})?> pick() async {
    final result = await channel.invokeMapMethod<String, String>('pick');
    if (result == null) return null;
    return (uri: result['uri']!, name: result['name']!);
  }

  @override
  Future<void> validate(String tree) async {
    await channel.invokeMethod<String>('validate', {'tree': tree});
  }

  @override
  Future<bool> exists(String uri) async =>
      await channel.invokeMethod<bool>('exists', {'uri': uri}) ?? false;
  @override
  Future<String> save(
          String tree, String course, String name, File file) async =>
      (await channel.invokeMethod<String>('save', {
        'tree': tree,
        'course': course,
        'name': name,
        'path': file.path,
      }))!;
}
