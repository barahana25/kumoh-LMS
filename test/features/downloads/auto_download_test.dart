import 'dart:io';
import 'package:drift/drift.dart' show Migrator;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/downloads/auto_download.dart';
import 'package:kumoh_lms/features/downloads/download_store.dart';
import 'package:kumoh_lms/features/downloads/folder_storage.dart';
import 'package:kumoh_lms/features/notifications/data/notification_models.dart';
import '../../helpers/test_db.dart';

class TestSource implements DownloadSource {
  TestSource(this.directory);
  final Directory directory;
  int logins = 0;
  int downloads = 0;
  String owner = 'student';
  List<WatchedItem> items = [const WatchedItem('42', '1주차.pdf')];
  Future<void> Function()? beforeDownload;
  @override
  Future<String> authenticate() async {
    logins++;
    return owner;
  }

  @override
  Future<List<WatchedCourse>> courses() async =>
      [const WatchedCourse(7, '정치학입문-01')];
  @override
  Future<List<WatchedItem>> files(int course) async => items;
  @override
  Future<File> download(String id, {Duration? timeout}) async {
    downloads++;
    await beforeDownload?.call();
    return File('${directory.path}/$id.bin').writeAsBytes([1, 2, 3]);
  }

  @override
  Future<void> close() async {}
}

class TestFolders implements FolderStorage {
  final paths = <String>[];
  final documents = <String>{};
  bool permission = true;
  bool fail = false;
  @override
  Future<void> validate(String tree) async {
    if (!permission) throw PlatformException(code: 'folder_permission');
  }

  @override
  Future<bool> exists(String uri) async => documents.contains(uri);
  @override
  Future<String> save(
      String tree, String course, String name, File file) async {
    if (fail) throw PlatformException(code: 'folder_io');
    expect(await file.readAsBytes(), [1, 2, 3]);
    final uri = '$tree/$course/$name';
    paths.add(uri);
    documents.add(uri);
    return uri;
  }
}

void main() {
  late AppDatabase db;
  late Directory temp;
  late DownloadStore store;
  late TestSource source;
  late TestFolders folders;
  late AutoDownloader downloader;
  var now = DateTime.utc(2026, 9, 8, 0, 1);
  setUp(() async {
    db = createTestDatabase();
    temp = await Directory.systemTemp.createTemp('lms-download-test-');
    store = DownloadStore(db);
    source = TestSource(temp);
    folders = TestFolders();
    now = DateTime.utc(2026, 9, 8, 0, 1);
    downloader = AutoDownloader(
        store: store,
        storage: folders,
        sourceFactory: () => source,
        clock: () => now);
    await store.configure('student', 'content://semester', '2학년 2학기');
    await store.setEnabled(true);
  });
  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });
  test('기존 자료를 강의별로 저장하고 재실행에서는 중복 없이 새 자료만 받는다', () async {
    expect(await downloader.run(force: true), contains('1개 파일 저장'));
    expect(folders.paths.single, 'content://semester/정치학입문-01 (7)/1주차__42.pdf');
    await downloader.run(force: true);
    expect(source.downloads, 1);
    source.items.add(const WatchedItem('43', '1주차.pdf'));
    await downloader.run(force: true);
    expect(source.downloads, 2);
    expect(folders.paths.last, endsWith('1주차__43.pdf'));
    expect(await temp.list().toList(), isEmpty);
  });
  test('저장 실패는 완료 처리하지 않고 다음 확인에서 재시도한다', () async {
    folders.fail = true;
    await downloader.run(force: true);
    expect(await db.select(db.downloadedFiles).get(), isEmpty);
    expect((await store.settings())!.enabled, true);
    folders.fail = false;
    await downloader.run(force: true);
    expect((await db.select(db.downloadedFiles).get()).length, 1);
  });
  test('사용자가 파일을 지웠으면 다시 받을 수 있다', () async {
    await downloader.run(force: true);
    folders.documents.clear();
    await downloader.run(force: true);
    expect(source.downloads, 2);
  });
  test('폴더 권한을 잃으면 다운로드를 멈추고 재선택을 안내한다', () async {
    folders.permission = false;
    expect(await downloader.run(force: true), contains('다시 선택'));
    expect(source.logins, 0);
    expect((await store.settings())!.enabled, false);
  });
  test('중간에 끄거나 로그아웃하면 뒤늦은 파일을 선택 폴더에 쓰지 않는다', () async {
    source.beforeDownload = () => store.setEnabled(false);
    await downloader.run(force: true);
    expect(folders.paths, isEmpty);
    expect(await temp.list().toList(), isEmpty);
  });
  test('계정 불일치는 파일 저장 없이 중지한다', () async {
    source.owner = 'someone_else';
    await downloader.run(force: true);
    expect(folders.paths, isEmpty);
    expect((await store.settings())!.enabled, false);
  });
  test('같은 회차 중복 및 휴식 시간 조회를 막고 수동 요청은 허용한다', () async {
    await downloader.run();
    await downloader.run();
    expect(source.logins, 1);
    now = DateTime.utc(2026, 9, 8, 18, 1); // KST 다음날 03:01
    await downloader.run();
    expect(source.logins, 1);
    await downloader.run(force: true);
    expect(source.logins, 2);
  });
  test('v4 업그레이드가 기존 내역을 건드리지 않고 다운로드 테이블을 추가한다', () async {
    await db.customStatement('DROP TABLE download_settings');
    await db.customStatement('DROP TABLE downloaded_files');
    await db.migration.onUpgrade(Migrator(db), 4, 5);
    expect(await store.settings(), isNull);
    expect(await db.select(db.downloadedFiles).get(), isEmpty);
  });
  test('다운로드 이름에서 경로 문자를 제거하고 확장자를 유지한다', () {
    final name = downloadName(const WatchedItem('9', '../../a/b.pdf'));
    expect(name, 'a_b__9.pdf');
    expect(name, isNot(contains('/')));
  });
}
