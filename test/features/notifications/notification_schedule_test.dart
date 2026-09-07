import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/notifications/data/notification_schedule.dart';
import 'package:kumoh_lms/features/notifications/data/notification_poller.dart';
import 'package:kumoh_lms/features/notifications/data/notification_store.dart';
import '../../helpers/test_db.dart';
import 'notification_poller_test.dart' show FakeSource, FakeSink;

DateTime kst(int hour, int minute, [int second = 0]) =>
    DateTime.utc(2026, 9, 7, hour, minute, second)
        .subtract(const Duration(hours: 9));

void main() {
  test('복구 작업은 누락 회차를 처리하고 같은 회차의 15분 재실행은 생략한다', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final store = NotificationStore(db);
    await store.enable('student');
    final source = FakeSource();
    var now = kst(8, 16);
    final poller = NotificationPoller(
        store: store,
        sourceFactory: () => source,
        sink: FakeSink(),
        clock: () => now);
    await poller.run();
    for (final minute in [31, 46]) {
      now = kst(8, minute);
      await poller.run();
    }
    expect(source.logins, 1);
    now = kst(9, 1);
    await poller.run();
    expect(source.logins, 2);
  });
  test('정각에는 1분을 기다리고 실행 뒤에는 다음 시간의 1분을 예약한다', () {
    expect(NotificationSchedule.next(kst(12, 0)), kst(12, 1));
    expect(NotificationSchedule.next(kst(12, 1)), kst(13, 1));
    expect(NotificationSchedule.next(kst(12, 45)), kst(13, 1));
    expect(NotificationSchedule.slot(kst(12, 0, 59)), isNull);
  });
  test('00:01 이후에는 08:01로 건너뛰며 08:00에도 조회하지 않는다', () {
    expect(NotificationSchedule.next(kst(0, 0)), kst(0, 1));
    expect(NotificationSchedule.next(kst(0, 1)), kst(8, 1));
    for (var hour = 1; hour <= 7; hour++) {
      expect(NotificationSchedule.slot(kst(hour, 30)), isNull);
      expect(NotificationSchedule.next(kst(hour, 30)), kst(8, 1));
    }
    expect(NotificationSchedule.slot(kst(8, 0)), isNull);
    expect(NotificationSchedule.slot(kst(8, 1)), kst(8, 1));
  });
  test('자정과 날짜 변경도 한국 시간으로 계산한다', () {
    expect(NotificationSchedule.next(kst(23, 1)), kst(24, 1));
    expect(NotificationSchedule.next(kst(12, 0).toLocal()), kst(12, 1));
  });
  test('늦게 실행되어도 다음 정시 회차를 1시간 제한으로 건너뛰지 않는다', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final store = NotificationStore(db);
    await store.enable('student');
    var now = kst(12, 5);
    final source = FakeSource();
    final poller = NotificationPoller(
        store: store,
        sourceFactory: () => source,
        sink: FakeSink(),
        clock: () => now);
    await poller.run();
    now = kst(12, 45);
    await poller.run();
    expect(source.logins, 1);
    now = kst(13, 1);
    await poller.run();
    expect(source.logins, 2);
  });
  test('휴식 중 자동 로그인·조회·알림이 없고 08:01에 재개한다', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final store = NotificationStore(db);
    await store.enable('student');
    var now = kst(1, 1);
    final source = FakeSource();
    final sink = FakeSink();
    final poller = NotificationPoller(
        store: store,
        sourceFactory: () => source,
        sink: sink,
        clock: () => now);
    await poller.run();
    now = kst(7, 59);
    await poller.run();
    now = kst(8, 0);
    await poller.run();
    expect(source.logins, 0);
    expect((await store.settings())!.lastAttempt, isNull);
    now = kst(8, 1);
    await poller.run();
    expect(source.logins, 1);
  });
  test('지금 확인은 휴식 시간에도 명시적으로 실행할 수 있다', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final store = NotificationStore(db);
    await store.enable('student');
    final source = FakeSource();
    final poller = NotificationPoller(
        store: store,
        sourceFactory: () => source,
        sink: FakeSink(),
        clock: () => kst(3, 0));
    await poller.run(force: true);
    expect(source.logins, 1);
  });
  test('진행 도중 휴식 시간이 되면 나머지 목록 요청을 중단한다', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final store = NotificationStore(db);
    await store.enable('student');
    var now = kst(0, 59);
    final source = FakeSource();
    var requests = 0;
    source.beforeItems = () async {
      requests++;
      now = kst(1, 0);
    };
    final poller = NotificationPoller(
        store: store,
        sourceFactory: () => source,
        sink: FakeSink(),
        clock: () => now);
    await poller.run();
    expect(requests, 1);
  });
}
