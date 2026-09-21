import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/time/due_days.dart';
import 'package:kumoh_lms/features/assignments/presentation/widgets/event_tile.dart';

void main() {
  final now = DateTime.utc(2026, 9, 21, 1, 1); // KST 10:01
  DateTime after(Duration d) => now.add(d);

  test('24시간 미만이면 0, 지났으면 null', () {
    expect(dueDays(after(const Duration(minutes: 1)), now), 0);
    expect(dueDays(after(const Duration(hours: 23, minutes: 59)), now), 0);
    expect(dueDays(now.subtract(const Duration(seconds: 1)), now), isNull);
  });

  test('24시간부터는 남은 시간을 일 단위로 내린다', () {
    expect(dueDays(after(const Duration(hours: 24)), now), 1);
    expect(dueDays(after(const Duration(hours: 47, minutes: 59)), now), 1);
    expect(dueDays(after(const Duration(hours: 48)), now), 2);
    expect(dueDays(after(const Duration(hours: 72)), now), 3);
    expect(dueDays(after(const Duration(hours: 95, minutes: 59)), now), 3);
    expect(dueDays(after(const Duration(hours: 96)), now), 4);
  });

  test('화면 배지는 같은 계산을 쓴다', () {
    expect(dueRelative(null, now: now), '');
    expect(dueRelative(now.subtract(const Duration(minutes: 1)), now: now), '마감됨');
    expect(dueRelative(after(const Duration(hours: 5)), now: now), 'D-DAY');
    expect(dueRelative(after(const Duration(hours: 30)), now: now), 'D-1');
    expect(dueRelative(after(const Duration(hours: 80)), now: now), 'D-3');
  });
}
