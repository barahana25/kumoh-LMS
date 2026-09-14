import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// 웹은 SQLCipher가 없어 암호화하지 않는다. 서버에서 다시 받을 수 있는
/// 캐시만 들어가고, 비밀번호는 웹에서 저장하지 않는다.
///
/// GitHub Pages는 COOP/COEP 헤더를 줄 수 없어 drift가 OPFS 대신
/// IndexedDB 등 가능한 저장소를 고른다.
QueryExecutor openAppDatabaseExecutor(Future<String> Function() keyProvider) {
  return DatabaseConnection.delayed(Future(() async {
    final result = await WasmDatabase.open(
      databaseName: 'kumoh_lms',
      sqlite3Uri: Uri.parse('vendor/sqlite3.wasm'),
      driftWorkerUri: Uri.parse('vendor/drift_worker.js'),
    );
    return result.resolvedExecutor;
  }));
}
