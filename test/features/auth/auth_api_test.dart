import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/config/env.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/features/auth/data/auth_api.dart';

import '../../fixtures/fixtures.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late AuthApi api;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: Env.apiBaseUrl));
    adapter = DioAdapter(dio: dio);
    api = AuthApi(dio);
  });

  test('login은 학번을 대문자로 보내고 토큰을 파싱한다', () async {
    adapter.onPost(
      '/login',
      (server) => server.reply(200, loginSuccessJson),
      data: {'userId': '20250000', 'password': 'pw'},
    );

    final tokens = await api.login(userId: '20250000', password: 'pw');

    expect(tokens.accessToken, 'header.accessPayload.sig');
    expect(tokens.refreshToken, 'header.refreshPayload.sig');
  });

  test('login이 봉투 에러를 주면 ServerFailure를 던진다', () async {
    adapter.onPost(
      '/login',
      (server) => server.reply(200, {
        'code': 'U001',
        'message': '아이디 또는 비밀번호가 올바르지 않습니다.',
        'data': null,
      }),
      data: {'userId': '20250000', 'password': 'wrong'},
    );

    expect(
      () => api.login(userId: '20250000', password: 'wrong'),
      throwsA(isA<ServerFailure>().having((f) => f.code, 'code', 'U001')),
    );
  });

  test('reissue는 X-Refresh-Token 헤더로 보내고 회전된 토큰 두 개를 돌려준다', () async {
    adapter.onPost(
      '/reissue',
      (server) => server.reply(200, {
        'code': '200',
        'message': 'Success',
        'data': {'accessToken': 'newAccess', 'refreshToken': 'newRefresh'},
      }),
      headers: {'X-Refresh-Token': 'oldRefresh'},
    );

    final tokens = await api.reissue('oldRefresh');

    expect(tokens.accessToken, 'newAccess');
    expect(tokens.refreshToken, 'newRefresh');
  });

  test('fetchProfile은 사용자 프로필을 파싱한다', () async {
    adapter.onGet('/user/profile', (server) => server.reply(200, userProfileJson));

    final profile = await api.fetchProfile();

    expect(profile.loginId, '20250000');
    expect(profile.name, '홍길동');
    expect(profile.canvasId, 59580);
    expect(profile.division, '컴퓨터공학부');
    expect(profile.role, 'STUDENT');
  });

  test('401 원시 Spring 에러는 AuthFailure로 변환된다', () async {
    adapter.onGet('/user/profile', (server) => server.reply(401, springAuthErrorJson));

    expect(() => api.fetchProfile(), throwsA(isA<AuthFailure>()));
  });

  test('연결 실패는 NetworkFailure로 변환된다', () async {
    adapter.onGet(
      '/user/profile',
      (server) => server.throws(
        0,
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/user/profile'),
          reason: 'no route',
        ),
      ),
    );

    expect(() => api.fetchProfile(), throwsA(isA<NetworkFailure>()));
  });
}
