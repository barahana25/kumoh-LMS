/// 마감까지 남은 날 수. 화면 배지와 마감 알림이 같은 기준을 쓰도록 한 곳에 둔다.
///
/// 24시간 미만이면 0(D-DAY), 그 이상이면 남은 시간을 일 단위로 내린 값,
/// 이미 지났으면 null이다. 시간대와 무관하게 두 시각의 차이만 본다.
int? dueDays(DateTime dueAt, DateTime now) {
  final diff = dueAt.difference(now);
  if (diff.isNegative) return null;
  if (diff.inHours < 24) return 0;
  return diff.inDays;
}
