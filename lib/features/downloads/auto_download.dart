import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/error/failure.dart';
import '../../core/network/token_store.dart';
import '../canvas/data/canvas_download.dart';
import '../notifications/data/lms_notification_source.dart';
import '../notifications/data/notification_models.dart';
import '../notifications/data/notification_schedule.dart';
import 'download_store.dart';
import 'folder_storage.dart';

abstract interface class DownloadSource {
  Future<String> authenticate();
  Future<List<WatchedCourse>> courses();
  Future<List<WatchedItem>> files(int course);
  Future<File> download(String id, {Duration? timeout});
  Future<void> close();
}

class CanvasDownloadSource implements DownloadSource {
  CanvasDownloadSource(TokenStore tokens)
      : source = LmsNotificationSource(tokens);
  final LmsNotificationSource source;
  Directory? temporary;
  @override
  Future<String> authenticate() => source.authenticate();
  @override
  Future<List<WatchedCourse>> courses() => source.courses();
  @override
  Future<List<WatchedItem>> files(int course) =>
      source.items(course, NoticeKind.file);
  @override
  Future<File> download(String id, {Duration? timeout}) async {
    temporary ??=
        await (await getTemporaryDirectory()).createTemp('lms-download-');
    return source.downloadFile(id, temporary!, timeout: timeout);
  }

  @override
  Future<void> close() async {
    source.close();
    if (temporary != null && await temporary!.exists()) {
      await temporary!.delete(recursive: true);
    }
  }
}

String downloadName(WatchedItem file) {
  final name = safeFileName(file.title);
  final ext = p.extension(name);
  return '${p.basenameWithoutExtension(name)}__${safeFileName(file.id)}$ext';
}

class AutoDownloader {
  AutoDownloader(
      {required this.store,
      required this.storage,
      required this.sourceFactory,
      DateTime Function()? clock,
      this.budget = const Duration(minutes: 4)})
      : clock = clock ?? DateTime.now;
  final DownloadStore store;
  final FolderStorage storage;
  final DownloadSource Function() sourceFactory;
  final DateTime Function() clock;
  final Duration budget;
  Future<String> run({bool force = false}) async {
    final run = await store.acquire(clock(), force);
    if (run == null) return '다운로드가 꺼져 있거나 이미 확인한 시간입니다.';
    var status = '다운로드하지 못했습니다. 다음 확인에 재시도합니다.';
    var pause = false;
    DownloadSource? source;
    final elapsed = Stopwatch()..start();
    var saved = 0;
    var failed = 0;
    bool allowed() => force || NotificationSchedule.slot(clock()) != null;
    try {
      await storage.validate(run.treeUri);
      source = sourceFactory();
      final owner = await source.authenticate();
      if (owner.trim().toUpperCase() != run.owner.trim().toUpperCase()) {
        throw const AuthFailure();
      }
      for (final course in await source.courses()) {
        if (!await store.current(run) || !allowed()) break;
        try {
          for (final item in await source.files(course.id)) {
            if (!await store.current(run) || !allowed()) break;
            if (elapsed.elapsed >= budget) {
              status = '$saved개 저장 · 남은 자료는 다음 확인에 이어받습니다.';
              return status;
            }
            try {
              final uri = await store.saved(run, course.id, item.id);
              if (uri != null && await storage.exists(uri)) continue;
              final file = await source.download(item.id,
                  timeout: budget - elapsed.elapsed);
              try {
                if (!await store.current(run) || !allowed()) break;
                final document = await storage.save(
                    run.treeUri,
                    '${safeFileName(course.name)} (${course.id})',
                    downloadName(item),
                    file);
                await store.record(run, course.id, item.id, document);
                saved++;
              } finally {
                if (await file.exists()) await file.delete();
              }
            } on PlatformException {
              rethrow;
            } on AuthFailure {
              rethrow;
            } on Exception {
              failed++;
            }
          }
        } on PlatformException {
          rethrow;
        } on AuthFailure {
          rethrow;
        } on Exception {
          failed++;
        }
      }
      status =
          '$saved개 파일 저장${failed == 0 ? '' : ' · $failed개 실패, 다음 확인에 재시도'}';
    } on AuthFailure {
      pause = true;
      status = '자동 로그인을 켜고 다시 로그인한 뒤 자동 다운로드를 켜 주세요.';
    } on PlatformException catch (e) {
      pause = e.code == 'folder_permission';
      status = pause
          ? '폴더 접근 권한이 없습니다. 저장 폴더를 다시 선택해 주세요.'
          : '파일 저장 실패: 저장 공간과 폴더를 확인해 주세요.';
    } on Exception {
      status = '자료를 받지 못했습니다. 연결을 확인해 주세요. 다음 확인에 재시도합니다.';
    } finally {
      try {
        await source?.close();
      } finally {
        await store.finish(run, status, pause: pause);
      }
    }
    return status;
  }
}
