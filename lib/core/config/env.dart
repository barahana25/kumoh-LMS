/// 앱 전역 상수. 백엔드 서버가 없으므로 모든 엔드포인트는 여기에 고정된다.
class Env {
  const Env._();

  static const String apiBaseUrl = 'https://lms.kumoh.ac.kr:82/api/v1';
  static const String canvasHost = 'https://canvas.kumoh.ac.kr';
  static const String canvasApiBaseUrl = '$canvasHost/api/v1';

  /// SAML 힌트 쿠키를 심는 기준 URL. 쿠키 도메인은 .kumoh.ac.kr 이라
  /// lms/canvas 양쪽 요청에 함께 실린다.
  static const String canvasBridgeCookieHost = 'https://lms.kumoh.ac.kr';

  /// 내부 API가 CORS/Referer 검사를 하므로 웹앱과 동일한 Origin을 보낸다.
  static const String webOrigin = 'https://lms.kumoh.ac.kr';

  /// KIT 기관 계정 id.
  static const int defaultAccountId = 1;

  /// 캐시 TTL — 학교 서버 부하를 줄이기 위해 이 시간 안에는 네트워크를 치지 않는다.
  static const Duration coursesTtl = Duration(hours: 6);
  static const Duration calendarTtl = Duration(minutes: 30);
  static const Duration announcementsTtl = Duration(minutes: 30);
  static const Duration referenceTtl = Duration(hours: 24);

  /// 강좌 상세 탭 캐시 정책.
  ///
  /// 과제·공지·성적·자료실·토론·강의실은 언제 바뀔지 알 수 없다. TTL로 요청을
  /// 건너뛰면 학생이 새 마감일이나 새 자료를 놓친다. 캐시는 첫 화면과 오프라인
  /// 대비로만 쓰고, 온라인이면 항상 다시 받는다.
  static const Duration canvasAlwaysRevalidate = Duration.zero;

  /// 강의 계획과 구성원 명단은 학기 초 이후 거의 바뀌지 않는다.
  static const Duration canvasStableTtl = Duration(hours: 24);

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
