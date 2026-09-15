import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

/// 암호화 키와 DB 파일이 어긋나면(기기 키스토어 초기화, 앱 재설치 잔여 파일 등)
/// 모든 쿼리가 영구히 실패한다. 로그아웃의 wipe()조차 실패해서 사용자가 스스로
/// 되돌릴 방법이 없다. 이 DB는 서버에서 언제든 다시 받을 수 있는 캐시일 뿐이므로,
/// 읽히지 않으면 버리고 새로 만드는 편이 낫다.
Future<void> discardUnreadableCache(File file, String escapedKey) async {
  if (!file.existsSync()) return;
  try {
    final db = sqlite3.open(file.path);
    try {
      db.execute("PRAGMA key = '$escapedKey';");
      db.select('SELECT count(*) FROM sqlite_master;');
    } finally {
      db.dispose();
    }
  } on SqliteException catch (e) {
    // 다른 isolate의 백그라운드 조회 중 잠긴 DB를 손상으로 오인하지 않는다.
    if (e.resultCode != 26 && e.resultCode != 11) rethrow;
    await file.delete();
  }
}

/// 실기기용. SQLCipher로 암호화된 파일 DB를 연다.
LazyDatabase openAppDatabaseExecutor(
    Future<String> Function() keyProvider) {
  return LazyDatabase(() async {
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();

    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'kumoh_lms.sqlite'));
    final key = await keyProvider();
    final escaped = key.replaceAll("'", "''");

    // 열기 전에 확인한다. 여기서 걸러내지 않으면 이후 모든 쿼리가 던진다.
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
    await discardUnreadableCache(file, escaped);

    return NativeDatabase.createInBackground(
      file,
      isolateSetup: () {
        open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
      },
      setup: (db) {
        if (db.select('PRAGMA cipher_version;').isEmpty) {
          throw StateError('SQLCipher is not available');
        }
        db.execute("PRAGMA key = '$escaped';");
        db.execute('PRAGMA busy_timeout = 5000;');
      },
    );
  });
}
