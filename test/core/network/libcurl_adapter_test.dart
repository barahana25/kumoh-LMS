import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/core/network/libcurl/curl_binding.dart';
import 'package:kumoh_lms/core/network/libcurl/libcurl_adapter.dart';
import 'package:kumoh_lms/features/auth/data/auth_api.dart' show throwAsFailure;

class _FakeBinding implements CurlBinding {
  _FakeBinding(this.respond);
  final Future<CurlResponse> Function(CurlRequest request) respond;
  final requests = <CurlRequest>[];

  @override
  Future<CurlResponse> fetch(CurlRequest request) {
    requests.add(request);
    return respond(request);
  }
}

CurlResponse _ok(String body, [List<(String, String)> headers = const []]) =>
    CurlResponse(
        status: 200,
        headers: headers,
        body: Uint8List.fromList(utf8.encode(body)));

void main() {
  test('요청 URL·메서드·헤더·본문을 그대로 넘긴다', () async {
    final binding = _FakeBinding((_) async => _ok('{"code":"200"}',
        [('Content-Type', 'application/json')]));
    final dio = Dio(BaseOptions(
        baseUrl: 'https://lms.kumoh.ac.kr:82/api/v1',
        headers: {'Origin': 'https://lms.kumoh.ac.kr'}))
      ..httpClientAdapter = LibcurlHttpClientAdapter(binding);

    final res = await dio.post<Map<String, dynamic>>('/login',
        data: {'userId': 'A', 'password': 'B'});

    final sent = binding.requests.single;
    expect(sent.url, 'https://lms.kumoh.ac.kr:82/api/v1/login');
    expect(sent.method, 'POST');
    expect(sent.headers['origin'] ?? sent.headers['Origin'],
        'https://lms.kumoh.ac.kr');
    expect(jsonDecode(utf8.decode(sent.body!)),
        {'userId': 'A', 'password': 'B'});
    expect(res.data, {'code': '200'});
  });

  test('중복 Set-Cookie를 모두 소문자 헤더로 전달한다', () async {
    final binding = _FakeBinding((_) async => _ok('', [
          ('Set-Cookie', 'a=1; path=/'),
          ('set-cookie', 'b=2; path=/'),
        ]));
    final dio = Dio()..httpClientAdapter = LibcurlHttpClientAdapter(binding);

    final res = await dio.get<String>('https://canvas.kumoh.ac.kr/');

    expect(res.headers['set-cookie'], ['a=1; path=/', 'b=2; path=/']);
  });

  test('followRedirects: false면 수동 리다이렉트를 요청하고 3xx와 Location을 돌려준다',
      () async {
    final binding = _FakeBinding((_) async => CurlResponse(
        status: 302,
        headers: const [('Location', 'https://lms.kumoh.ac.kr/idp')],
        body: Uint8List(0)));
    final dio = Dio()..httpClientAdapter = LibcurlHttpClientAdapter(binding);

    final res = await dio.get<String>('https://canvas.kumoh.ac.kr/login/saml',
        options: Options(
            followRedirects: false,
            validateStatus: (s) => s != null && s < 400));

    expect(binding.requests.single.followRedirects, isFalse);
    expect(res.statusCode, 302);
    expect(res.headers.value('location'), 'https://lms.kumoh.ac.kr/idp');
  });

  test('libcurl 실패는 연결 오류가 되어 NetworkFailure로 정규화된다', () async {
    final binding = _FakeBinding(
        (_) async => throw const CurlException('websocket closed'));
    final dio = Dio()..httpClientAdapter = LibcurlHttpClientAdapter(binding);

    await expectLater(
      () async {
        try {
          await dio.get<String>('https://canvas.kumoh.ac.kr/');
        } on DioException catch (e) {
          throwAsFailure(e);
        }
      }(),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('응답이 connect+receive 제한을 넘기면 receiveTimeout으로 실패한다', () async {
    final binding = _FakeBinding((_) => Completer<CurlResponse>().future);
    final dio = Dio(BaseOptions(
        connectTimeout: const Duration(milliseconds: 10),
        receiveTimeout: const Duration(milliseconds: 10)))
      ..httpClientAdapter = LibcurlHttpClientAdapter(binding);

    await expectLater(
      dio.get<String>('https://canvas.kumoh.ac.kr/'),
      throwsA(isA<DioException>().having(
          (e) => e.type, 'type', DioExceptionType.receiveTimeout)),
    );
  });
}
