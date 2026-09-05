/// 로그인/재발급 응답의 토큰 쌍. 재발급 시 둘 다 회전되므로 항상 함께 저장한다.
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['accessToken'] as String? ?? '',
        refreshToken: json['refreshToken'] as String? ?? '',
      );

  bool get isValid => accessToken.isNotEmpty && refreshToken.isNotEmpty;
}

/// `/user/profile` 응답. 널 허용 필드가 많아 방어적으로 파싱한다.
class UserProfile {
  const UserProfile({
    required this.loginId,
    required this.name,
    required this.role,
    this.canvasId,
    this.division = '',
    this.subDivision = '',
    this.profileUrl,
    this.email = '',
  });

  final String loginId;
  final String name;
  final String role;
  final int? canvasId;
  final String division;
  final String subDivision;
  final String? profileUrl;
  final String email;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        loginId: json['loginId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        role: json['role'] as String? ?? 'STUDENT',
        canvasId: (json['canvasId'] as num?)?.toInt(),
        division: json['division'] as String? ?? '',
        subDivision: json['subDivision'] as String? ?? '',
        profileUrl: json['profileUrl'] as String?,
        email: json['email'] as String? ?? '',
      );

  /// "컴퓨터공학부 · 인공지능공학전공" 형태. 빈 값은 알아서 빠진다.
  String get affiliation =>
      [division, subDivision].where((s) => s.isNotEmpty).join(' · ');
}
