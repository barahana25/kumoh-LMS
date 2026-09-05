/// 앱 전역에서 쓰는 타입드 실패. UI는 이 타입만 보고 분기한다.
sealed class Failure implements Exception {
  const Failure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// 네트워크에 닿지 못함 (타임아웃, DNS, 연결 끊김).
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = '네트워크에 연결할 수 없습니다.']);
}

/// 세션이 유효하지 않음 → 재로그인 필요.
class AuthFailure extends Failure {
  const AuthFailure([super.message = '세션이 만료되었습니다. 다시 로그인해 주세요.']);
}

/// 서버가 응답했지만 실패. code는 앱 봉투의 code 또는 HTTP 상태코드 문자열.
class ServerFailure extends Failure {
  const ServerFailure({required this.code, required String message}) : super(message);
  final String code;
}

/// 응답 형태가 예상과 다름.
class ParseFailure extends Failure {
  const ParseFailure([super.message = '서버 응답을 해석할 수 없습니다.']);
}

/// 캐시에 데이터가 없고 네트워크도 실패.
class CacheMissFailure extends Failure {
  const CacheMissFailure([super.message = '표시할 데이터가 없습니다.']);
}
