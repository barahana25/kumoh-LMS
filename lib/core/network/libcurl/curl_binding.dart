import 'dart:typed_data';

/// libcurl.js 한 번의 요청. 쿠키와 리다이렉트 판단은 Dart(Dio)가 한다.
class CurlRequest {
  const CurlRequest({
    required this.url,
    required this.method,
    required this.headers,
    required this.followRedirects,
    this.body,
    this.cancel,
  });

  final String url;
  final String method;
  final Map<String, String> headers;
  final Uint8List? body;
  final bool followRedirects;
  final Future<void>? cancel;
}

class CurlResponse {
  const CurlResponse({
    required this.status,
    required this.headers,
    required this.body,
  });

  final int status;

  /// 서버가 보낸 순서 그대로의 (이름, 값). Set-Cookie처럼 같은 이름이 여러 번 온다.
  final List<(String, String)> headers;
  final Uint8List body;
}

/// 중계 서버 연결 실패, TLS 실패 등 응답을 받지 못한 경우.
class CurlException implements Exception {
  const CurlException(this.message);
  final String message;

  @override
  String toString() => 'CurlException: $message';
}

/// 테스트에서는 가짜로, 웹에서는 libcurl.js로 구현한다.
abstract interface class CurlBinding {
  Future<CurlResponse> fetch(CurlRequest request);
}
