import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/notifications/data/due_reminder.dart';
import 'package:kumoh_lms/features/notifications/data/due_reminder_models.dart';
import 'package:kumoh_lms/features/notifications/data/due_reminder_store.dart';
import 'package:kumoh_lms/features/notifications/data/notification_models.dart';
import '../../helpers/test_db.dart';

class FakeDueSource implements DueSource {
  String owner = 'student';
  int logins = 0;
  Failure? authFailure;
  List<WatchedCourse> watched = [const WatchedCourse(1, '알고리즘및실습-01')];
  final values = <int, List<DueAssignment>>{};
  final failures = <int>{};

  @override
  Future<String> authenticate() async {
    logins++;
    if (authFailure != null) throw authFailure!;
    return owner;
  }

  @override
  Future<List<WatchedCourse>> courses() async => watched;

  @override
  Future<List<DueAssignment>> dueAssignments(int courseId) async {
    if (failures.contains(courseId)) throw const NetworkFailure();
    return values[courseId] ?? const [];
  }

  @override
  void close() {}
}

class FakeDueSink implements DueSink {
  bool allowed = true;
  final shown = <DueNotice>[];
  @override
  Future<bool> permitted() async => allowed;
  @override
  Future<void> showDue(DueNotice notice) async => shown.add(notice);
}

void main() {
  late AppDatabase db;
  late DueReminderStore store;
  late FakeDueSource source;
  late FakeDueSink sink;
  late DateTime now;

  DueReminder reminder() => DueReminder(
      store: store, source: source, sink: sink, clock: () => now);
  DueAssignment due(String id, Duration left) =>
      DueAssignment(id: id, name: '과제 $id', dueAt: now.add(left));
  Future<String> tick([Duration by = const Duration(hours: 1)]) {
    now = now.add(by);
    return reminder().run();
  }

  setUp(() async {
    db = createTestDatabase();
    store = DueReminderStore(db);
    source = FakeDueSource();
    sink = FakeDueSink();
    now = DateTime.utc(2026, 9, 21, 1, 1); // KST 10:01
    await store.enable('student');
  });
  tearDown(() => db.close());

  test('구간에 든 미제출 과제만 한 번씩 알린다', () async {
    source.values[1] = [
      due('a', const Duration(hours: 80)), // D-3
      due('b', const Duration(hours: 30)), // D-1
      due('c', const Duration(hours: 5)), // D-DAY
      due('d', const Duration(hours: 60)), // D-2
      due('e', const Duration(hours: 120)), // D-5
    ];
    final status = await reminder().run();
    expect(sink.shown.map((n) => n.stage),
        [DueStage.threeDays, DueStage.oneDay, DueStage.today]);
    expect(sink.shown[1].heading, '[마감 D-1] 알고리즘및실습');
    expect(status, '1개 강좌 확인 · 마감 알림 3개');
    await tick();
    expect(sink.shown, hasLength(3), reason: '같은 구간은 다시 보내지 않는다');
  });

  test('00:01 회차와 새벽에는 확인하지 않는다', () async {
    source.values[1] = [due('a', const Duration(hours: 5))];
    now = DateTime.utc(2026, 9, 21, 15, 1); // KST 9/22 00:01
    await reminder().run();
    now = DateTime.utc(2026, 9, 21, 18, 1); // KST 03:01
    await reminder().run();
    expect(sink.shown, isEmpty);
    expect(source.logins, 0, reason: '확인하지 않는 회차에는 로그인도 하지 않는다');
    expect((await store.settings())!.lastAttempt, isNull);
  });

  test('같은 회차에 여러 번 불려도 로그인은 한 번이다', () async {
    source.values[1] = [due('a', const Duration(hours: 5))];
    await reminder().run();
    now = now.add(const Duration(minutes: 15));
    await reminder().run();
    expect(source.logins, 1);
    expect(sink.shown, hasLength(1));
  });

  test('미제출로 남아 있으면 다음 구간에 다시 알린다', () async {
    source.values[1] = [
      DueAssignment(id: 'a', name: '과제 a', dueAt: now.add(const Duration(hours: 80)))
    ];
    await reminder().run();
    await tick(const Duration(hours: 56)); // 남은 24시간 → D-1
    expect(sink.shown.map((n) => n.stage), [DueStage.threeDays, DueStage.oneDay]);
  });

  test('제출해서 목록에서 빠지면 다음 구간은 보내지 않는다', () async {
    source.values[1] = [due('a', const Duration(hours: 80))];
    await reminder().run();
    source.values[1] = [];
    await tick(const Duration(hours: 56));
    expect(sink.shown, hasLength(1));
  });

  test('처음 켰을 때 이미 D-1이면 D-1만 보낸다', () async {
    source.values[1] = [due('a', const Duration(hours: 30))];
    await reminder().run();
    expect(sink.shown.single.stage, DueStage.oneDay);
  });

  test('마감이 바뀌면 새 마감 기준으로 다시 알린다', () async {
    final first = now.add(const Duration(hours: 30));
    source.values[1] = [DueAssignment(id: 'a', name: '과제 a', dueAt: first)];
    await reminder().run();
    source.values[1] = [
      DueAssignment(id: 'a', name: '과제 a', dueAt: first.add(const Duration(hours: 2)))
    ];
    await tick();
    expect(sink.shown.map((n) => n.stage), [DueStage.oneDay, DueStage.oneDay]);
    expect(sink.shown[0].id, isNot(sink.shown[1].id));
  });

  test('인증이 거부되면 마감 알림을 끈다', () async {
    source.authFailure = const AuthFailure();
    final status = await reminder().run();
    expect(status, '자동 로그인을 켜고 다시 로그인해 주세요.');
    expect((await store.settings())!.enabled, isFalse);
  });

  test('계정이 바뀌면 멈춘다', () async {
    source.owner = 'someone-else';
    final status = await reminder().run();
    expect(status, '계정이 변경되었습니다. 마감 알림을 다시 켜 주세요.');
    expect((await store.settings())!.enabled, isFalse);
  });

  test('한 강좌가 실패해도 다른 강좌는 알린다', () async {
    source.watched = const [WatchedCourse(1, '운영체제-01'), WatchedCourse(2, '네트워크-02')];
    source.failures.add(1);
    source.values[2] = [due('b', const Duration(hours: 5))];
    final status = await reminder().run();
    expect(sink.shown.single.courseId, 2);
    expect(status, '1개 강좌 확인 · 1개 강좌는 다음 주기에 재시도합니다.');
    expect((await store.settings())!.enabled, isTrue);
  });

  test('알림 권한이 없으면 보내지 않고 켜 둔다', () async {
    sink.allowed = false;
    source.values[1] = [due('a', const Duration(hours: 5))];
    final status = await reminder().run();
    expect(status, '기기 설정에서 알림 권한을 허용해 주세요.');
    expect(sink.shown, isEmpty);
    expect(source.logins, 0);
    expect((await store.settings())!.enabled, isTrue);
  });
}
