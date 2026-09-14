import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'curl_binding.dart';

/// 웹에서 브라우저 fetch 대신 libcurl.js로 요청한다.
///
/// 브라우저 fetch는 CORS, Origin 헤더 고정, Set-Cookie 숨김, 리다이렉트 자동
/// 추적 때문에 학교 서버와 SAML 브리지를 쓸 수 없다. libcurl.js는 TLS를
/// 브라우저 안에서 맺고 중계 서버에는 암호문 TCP만 보낸다.
class LibcurlHttpClientAdapter implements HttpClientAdapter {
  LibcurlHttpClientAdapter(this._binding);

  final CurlBinding _binding;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = requestStream == null ? null : await _collect(requestStream);
    final headers = <String, String>{
      for (final entry in options.headers.entries)
        if (entry.value != null)
          entry.key: entry.value is Iterable
              ? (entry.value as Iterable).join(', ')
              : '${entry.value}',
    };

    final request = CurlRequest(
      url: options.uri.toString(),
      method: options.method,
      headers: headers,
      body: body,
      followRedirects: options.followRedirects,
      cancel: cancelFuture,
    );

    final CurlResponse response;
    try {
      var pending = _binding.fetch(request);
      final limit = _timeLimit(options);
      if (limit != null) pending = pending.timeout(limit);
      response = await pending;
    } on TimeoutException {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
        message: '응답 시간이 초과되었습니다.',
      );
    } on CurlException catch (e) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: e.message,
        error: e,
      );
    }

    final grouped = <String, List<String>>{};
    for (final (name, value) in response.headers) {
      grouped.putIfAbsent(name.toLowerCase(), () => []).add(value);
    }
    return ResponseBody.fromBytes(response.body, response.status,
        headers: grouped);
  }

  static Duration? _timeLimit(RequestOptions options) {
    final connect = options.connectTimeout;
    final receive = options.receiveTimeout;
    if (connect == null && receive == null) return null;
    return (connect ?? Duration.zero) + (receive ?? Duration.zero);
  }

  static Future<Uint8List> _collect(Stream<Uint8List> stream) async {
    final bytes = <int>[];
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
    return Uint8List.fromList(bytes);
  }

  @override
  void close({bool force = false}) {}
}
