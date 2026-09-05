import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/api_envelope.dart';
import 'auth_dto.dart';

/// DioException을 앱의 Failure 타입으로 정규화한다.
/// 모든 API 클래스가 이 함수를 통해 예외를 던진다.
Never throwAsFailure(DioException e) {
  // 인터셉터가 이미 판정한 Failure(예: 세션 만료 AuthFailure)는 그대로 통과시킨다.
  final carried = e.error;
  if (carried is Failure) throw carried;

  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      throw const NetworkFailure();
    case DioExceptionType.badCertificate:
      throw const NetworkFailure('보안 연결에 실패했습니다.');
    case DioExceptionType.cancel:
      throw const NetworkFailure('요청이 취소되었습니다.');
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      final res = e.response;
      if (res == null) throw const NetworkFailure();
      throw failureFromResponse(res.statusCode, res.data);
  }
}

class AuthApi {
  AuthApi(this._dio);
  final Dio _dio;

  /// 학번은 서버가 대문자를 기대한다(웹앱도 대문자로 변환해 보낸다).
  Future<AuthTokens> login({required String userId, required String password}) async {
    try {
      final res = await _dio.post<Object?>(
        '/login',
        data: {'userId': userId.toUpperCase().trim(), 'password': password},
      );
      return unwrapEnvelope<AuthTokens>(
        res.data,
          (d) => AuthTokens.fromJson(d! as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }

  /// refreshToken은 반드시 X-Refresh-Token 헤더로 보낸다.
  /// (쿠키·바디·Bearer 방식은 서버가 거부한다.)
  Future<AuthTokens> reissue(String refreshToken) async {
    try {
      final res = await _dio.post<Object?>(
        '/reissue',
        options: Options(headers: {'X-Refresh-Token': refreshToken}),
      );
      return unwrapEnvelope<AuthTokens>(
        res.data,
          (d) => AuthTokens.fromJson(d! as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }

  Future<UserProfile> fetchProfile() async {
    try {
      final res = await _dio.get<Object?>('/user/profile');
      return unwrapEnvelope<UserProfile>(
        res.data,
          (d) => UserProfile.fromJson(d! as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }

  /// 서버 세션 정리. 실패해도 로컬 로그아웃은 진행해야 하므로 예외를 삼킨다.
  Future<void> logout() async {
    try {
      await _dio.post<Object?>('/logout');
    } on DioException {
      return;
    }
  }
}
