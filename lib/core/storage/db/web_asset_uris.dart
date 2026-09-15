/// 웹 DB가 쓰는 런타임 파일의 절대 주소.
///
/// drift는 sqlite3.wasm 주소를 문자열로 워커에 넘기고 워커 안에서 받는다.
/// 상대 주소를 넘기면 워커 파일(vendor/drift_worker.js) 기준으로 풀려
/// vendor/vendor/sqlite3.wasm을 요청하고, 서버가 HTML을 돌려줘 DB가 열리지 않는다.
/// 그래서 페이지의 base URI 기준으로 미리 절대 주소를 만든다.
({Uri sqlite3, Uri driftWorker}) webDatabaseAssetUris(String baseUri) {
  final base = Uri.parse(baseUri);
  return (
    sqlite3: base.resolve('vendor/sqlite3.wasm'),
    driftWorker: base.resolve('vendor/drift_worker.js'),
  );
}
