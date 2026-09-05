import '../error/failure.dart';

/// LINUS API 성공 응답은 {code, message, data} 봉투다.
/// code == '200' 일 때만 성공이며, data를 [parse]에 넘긴 결과를 돌려준다.
T unwrapEnvelope<T>(Object? body, T Function(Object? data) parse) {
  if (body is! Map) {
    throw const ParseFailure();
  }
  final code = body['code']?.toString();
  if (code == null) {
    throw const ParseFailure();
  }
  if (code != '200') {
    throw ServerFailure(
      code: code,
      message: body['message']?.toString() ?? '알 수 없는 오류가 발생했습니다.',
    );
  }
  return parse(body['data']);
}

/// 에러 응답은 두 형태로 온다.
///   1) 앱 봉투     : {code, message, data}
///   2) 원시 Spring : {timestamp, status, error, path}
/// 둘 다 [Failure]로 정규화한다.
Failure failureFromResponse(int? statusCode, Object? body) {
  if (statusCode == 401) {
    return const AuthFailure();
  }

  if (body is Map) {
    // 앱 봉투 형태
    final code = body['code']?.toString();
    if (code != null) {
      return ServerFailure(
        code: code,
        message: body['message']?.toString() ?? '알 수 없는 오류가 발생했습니다.',
      );
    }
    // 원시 Spring 형태
    final error = body['error']?.toString();
    if (error != null) {
      return ServerFailure(
        code: (body['status'] ?? statusCode ?? 0).toString(),
        message: error,
      );
    }
  }

  return ServerFailure(
    code: (statusCode ?? 0).toString(),
    message: '서버 오류가 발생했습니다. (${statusCode ?? '알 수 없음'})',
  );
}
