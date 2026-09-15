import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:web/web.dart' as web;

import 'web_asset_uris.dart';

/// 웹은 SQLCipher가 없어 암호화하지 않는다. 서버에서 다시 받을 수 있는
/// 캐시만 들어가고, 비밀번호는 웹에서 저장하지 않는다.
///
/// GitHub Pages는 COOP/COEP 헤더를 줄 수 없어 drift가 OPFS 대신
/// IndexedDB 등 가능한 저장소를 고른다.
QueryExecutor openAppDatabaseExecutor(Future<String> Function() keyProvider) {
  return DatabaseConnection.delayed(Future(() async {
    // <base href>(예: /kumoh-LMS/) 기준으로 푼다. 워커 안에서 다시 풀리지 않게 절대 주소다.
    final uris = webDatabaseAssetUris(web.document.baseURI);
    final result = await WasmDatabase.open(
      databaseName: 'kumoh_lms',
      sqlite3Uri: uris.sqlite3,
      driftWorkerUri: uris.driftWorker,
    );
    return result.resolvedExecutor;
  }));
}
