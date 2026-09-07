/// 학교 시간(KST)을 기준으로 한다. 기기의 시간대 설정과 무관하다.
class NotificationSchedule {
  static const zone = Duration(hours: 9);

  /// 자동 조회를 허용하는 현재 회차. 매시 00분과 01~07시는 실행하지 않는다.
  static DateTime? slot(DateTime now) {
    final kst = now.toUtc().add(zone);
    if ((kst.hour >= 1 && kst.hour <= 7) || kst.minute == 0) return null;
    return DateTime.utc(kst.year, kst.month, kst.day, kst.hour, 1)
        .subtract(zone);
  }

  /// 현재 시각보다 뒤에 있는 다음 예약: 00:01, 08:01, ... 23:01.
  static DateTime next(DateTime now) {
    final utc = now.toUtc();
    final kst = utc.add(zone);
    var candidate = DateTime.utc(kst.year, kst.month, kst.day, kst.hour, 1);
    if (!candidate.subtract(zone).isAfter(utc)) {
      candidate = candidate.add(const Duration(hours: 1));
    }
    if (candidate.hour >= 1 && candidate.hour <= 7) {
      candidate =
          DateTime.utc(candidate.year, candidate.month, candidate.day, 8, 1);
    }
    return candidate.subtract(zone);
  }
}
