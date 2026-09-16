import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/features/auth/data/auth_api.dart';

import '../../fixtures/fixtures.dart';

/// LINUS /reissue는 refreshToken만 보내면 401 T003으로 거부한다.
/// accessToken(Bearer)을 함께 보내야 새 토큰을 준다(2026-09-15 실계정 실험).
void main() {
  test('재발급 요청에 Bearer accessToken과 X-Refresh-Token을 함께 보낸다', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://lms.example.test/api/v1'));
    final adapter = DioAdapter(dio: dio);
    Map<String, dynamic>? sent;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      sent = o.headers;
      h.next(o);
    }));
    adapter.onPost('/reissue', (s) => s.reply(200, loginSuccessJson));

    await AuthApi(dio).reissue('refresh-1', accessToken: 'access-1');

    expect(sent!['Authorization'], 'Bearer access-1');
    expect(sent!['X-Refresh-Token'], 'refresh-1');
  });

  test('accessToken을 넘기지 않으면 저장된 accessToken을 함께 보낸다', () async {
    // 자동 재발급(AuthInterceptor)과 앱 시작 시 세션 복원이 이 경로를 쓴다.
    final dio = Dio(BaseOptions(baseUrl: 'https://lms.example.test/api/v1'));
    final adapter = DioAdapter(dio: dio);
    Map<String, dynamic>? sent;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      sent = o.headers;
      h.next(o);
    }));
    adapter.onPost('/reissue', (s) => s.reply(200, loginSuccessJson));
    final store = InMemoryTokenStore();
    await store.saveTokens(accessToken: 'stored-access', refreshToken: 'stored-refresh');

    await AuthApi(dio, tokenStore: store).reissue('stored-refresh');

    expect(sent!['Authorization'], 'Bearer stored-access');
    expect(sent!['X-Refresh-Token'], 'stored-refresh');
  });
}
