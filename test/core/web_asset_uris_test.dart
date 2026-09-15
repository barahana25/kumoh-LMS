import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/storage/db/web_asset_uris.dart';

/// drift는 sqlite3.wasm 주소를 문자열로 워커에 넘기고 워커 안에서 받는다.
/// 상대 주소면 워커 파일(vendor/drift_worker.js) 기준으로 풀려
/// vendor/vendor/sqlite3.wasm이 되고, 서버가 HTML을 돌려줘 DB가 열리지 않았다.
void main() {
  test('GitHub Pages 하위 경로 기준으로 절대 주소를 만든다', () {
    final uris = webDatabaseAssetUris('https://barahana25.github.io/kumoh-LMS/');

    expect(uris.sqlite3.toString(),
        'https://barahana25.github.io/kumoh-LMS/vendor/sqlite3.wasm');
    expect(uris.driftWorker.toString(),
        'https://barahana25.github.io/kumoh-LMS/vendor/drift_worker.js');
  });

  test('해시 경로가 붙은 주소에서도 루트 기준 절대 주소를 만든다', () {
    final uris = webDatabaseAssetUris('http://localhost:8000/#/login');

    expect(uris.sqlite3.toString(), 'http://localhost:8000/vendor/sqlite3.wasm');
    expect(uris.sqlite3.isAbsolute, isTrue);
    expect(uris.driftWorker.toString(),
        'http://localhost:8000/vendor/drift_worker.js');
  });
}
