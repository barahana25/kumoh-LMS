import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'curl_binding.dart';

@JS('libcurl')
external _Libcurl? get _libcurl;

extension type _Libcurl._(JSObject _) implements JSObject {
  @JS('load_wasm')
  external JSPromise<JSAny?> loadWasm(String url);

  @JS('set_websocket')
  external void setWebsocket(String url);

  external JSPromise<_CurlJsResponse> fetch(String url, JSObject params);
}

extension type _CurlJsResponse._(JSObject _) implements JSObject {
  external int get status;

  @JS('raw_headers')
  external JSArray<JSArray<JSString>> get rawHeaders;

  external JSPromise<JSArrayBuffer> arrayBuffer();
}

/// web/index.html이 먼저 불러온 libcurl.js 전역 객체를 쓴다.
class LibcurlJsBinding implements CurlBinding {
  LibcurlJsBinding({required this.relayUrl, this.wasmUrl = 'vendor/libcurl.wasm'});

  final String relayUrl;
  final String wasmUrl;
  Future<void>? _ready;

  Future<void> _ensureReady() {
    return _ready ??= () async {
      final lib = _libcurl;
      if (lib == null) {
        throw const CurlException('libcurl.js를 불러오지 못했습니다.');
      }
      await lib.loadWasm(wasmUrl).toDart;
      lib.setWebsocket(relayUrl);
    }()
        .catchError((Object e) {
      _ready = null;
      throw e is CurlException ? e : CurlException('$e');
    });
  }

  @override
  Future<CurlResponse> fetch(CurlRequest request) async {
    await _ensureReady();

    final headers = JSObject();
    request.headers.forEach((name, value) => headers[name] = value.toJS);

    final params = JSObject()
      ..['method'] = request.method.toJS
      ..['headers'] = headers
      ..['redirect'] = (request.followRedirects ? 'follow' : 'manual').toJS
      // 학교 서버가 HTTP/2를 제대로 받는지 알 수 없어 1.1로 고정한다.
      ..['_libcurl_http_version'] = 1.1.toJS;
    final body = request.body;
    if (body != null) params['body'] = body.toJS;

    final abort = web.AbortController();
    params['signal'] = abort.signal;
    request.cancel?.then((_) => abort.abort());

    try {
      final res = await _libcurl!.fetch(request.url, params).toDart;
      final pairs = <(String, String)>[
        for (final pair in res.rawHeaders.toDart)
          (pair.toDart[0].toDart, pair.toDart[1].toDart),
      ];
      final bytes = (await res.arrayBuffer().toDart).toDart.asUint8List();
      return CurlResponse(
          status: res.status, headers: pairs, body: Uint8List.fromList(bytes));
    } on Object catch (e) {
      throw CurlException('$e');
    }
  }
}
