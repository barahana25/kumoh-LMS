import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/notifications/data/due_reminder_store.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late DueReminderStore store;
  final slot = DateTime.utc(2026, 9, 21, 1, 1); // KST 10:01
  final now = slot.add(const Duration(seconds: 5));

  setUp(() {
    db = createTestDatabase();
    store = DueReminderStore(db);
  });
  tearDown(() => db.close());

  test('켜고 끈다', () async {
    expect(await store.settings(), isNull);
    await store.enable('student');
    final on = (await store.settings())!;
    expect(on.enabled, isTrue);
    expect(on.owner, 'student');
    await store.disable();
    final off = (await store.settings())!;
    expect(off.enabled, isFalse);
    expect(off.generation, isNot(on.generation));
  });

  test('꺼져 있으면 잠금을 잡지 않는다', () async {
    expect(await store.acquire(now, slot), isNull);
    await store.enable('student');
    await store.disable();
    expect(await store.acquire(now, slot), isNull);
  });

  test('같은 회차에는 한 번만 잡고 다음 회차에는 다시 잡는다', () async {
    await store.enable('student');
    final run = (await store.acquire(now, slot))!;
    expect(await store.current(run), isTrue);
    expect(await store.acquire(now, slot), isNull, reason: '실행 중');
    await store.finish(run, now, '완료', success: true);
    expect(await store.acquire(now.add(const Duration(minutes: 15)), slot), isNull,
        reason: '이번 회차는 이미 돌았다');
    final nextSlot = slot.add(const Duration(hours: 1));
    expect(await store.acquire(nextSlot.add(const Duration(seconds: 5)), nextSlot),
        isNotNull);
    final saved = (await store.settings())!;
    expect(saved.status, '완료');
    expect(saved.lastSuccess, now.millisecondsSinceEpoch);
  });

  test('끄면 진행 중인 실행은 더 이상 유효하지 않다', () async {
    await store.enable('student');
    final run = (await store.acquire(now, slot))!;
    await store.disable();
    expect(await store.current(run), isFalse);
  });

  test('보낸 키를 기록한다', () async {
    const key = '1:7:oneDay:2026-09-23T01:40:00.000Z';
    expect(await store.sent(key), isFalse);
    await store.markSent(key, now);
    await store.markSent(key, now); // 다시 써도 오류가 나지 않는다
    expect(await store.sent(key), isTrue);
  });

  test('멈추면 꺼지고 상태를 남긴다', () async {
    await store.enable('student');
    final run = (await store.acquire(now, slot))!;
    await store.pause(run, '자동 로그인을 켜고 다시 로그인해 주세요.');
    final saved = (await store.settings())!;
    expect(saved.enabled, isFalse);
    expect(saved.status, '자동 로그인을 켜고 다시 로그인해 주세요.');
  });
}
