import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/notifications/data/due_reminder_models.dart';
import 'package:kumoh_lms/features/notifications/data/due_reminder_store.dart';
import 'package:kumoh_lms/features/notifications/data/notification_models.dart';
import 'package:kumoh_lms/features/notifications/data/notification_store.dart';
import 'package:kumoh_lms/features/notifications/data/shared_alerts.dart';
import 'package:kumoh_lms/features/notifications/data/shared_lms_session.dart';
import '../../helpers/test_db.dart';

class CountingSource implements LmsSource {
  int logins = 0;
  int closed = 0;

  @override
  Future<String> authenticate() async {
    logins++;
    return 'student';
  }

  @override
  Future<List<WatchedCourse>> courses() async => const [];

  @override
  Future<List<WatchedItem>> items(int courseId, NoticeKind kind) async =>
      const [];

  @override
  Future<List<DueAssignment>> dueAssignments(int courseId) async => const [];

  @override
  void close() => closed++;
}

void main() {
  late AppDatabase db;
  late NotificationStore notices;
  late DueReminderStore due;
  late List<CountingSource> opened;
  late int polled;
  late int reminded;
  late DateTime now;
  Completer<void>? gate;
  Object? pollError;

  int logins() => opened.fold(0, (sum, s) => sum + s.logins);

  Future<void> run({bool noticesOn = true, bool dueOn = true}) =>
      runSharedAlerts(
        now: now,
        notices: notices,
        due: due,
        noticesOn: noticesOn,
        dueOn: dueOn,
        openSource: () {
          final source = CountingSource();
          opened.add(source);
          return source;
        },
        poll: (run, source) async {
          polled++;
          await source.authenticate();
          await gate?.future;
          if (pollError != null) throw pollError!;
        },
        remind: (run, source) async {
          reminded++;
          await source.authenticate();
        },
      );

  setUp(() async {
    db = createTestDatabase();
    notices = NotificationStore(db);
    due = DueReminderStore(db);
    opened = [];
    polled = 0;
    reminded = 0;
    gate = null;
    pollError = null;
    now = DateTime.utc(2026, 9, 21, 1, 1); // KST 10:01
    await notices.enable('student');
    await due.enable('student');
  });
  tearDown(() => db.close());

  test('둘 다 켜져 있으면 로그인 한 번으로 둘 다 돌고 소스를 닫는다', () async {
    await run();
    expect(polled, 1);
    expect(reminded, 1);
    expect(logins(), 1);
    expect(opened.single.closed, 1);
  });

  test('같은 회차에 겹쳐 들어온 작업은 로그인하지 않는다', () async {
    gate = Completer<void>();
    final first = run();
    while (polled == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await run();
    expect(opened, hasLength(1), reason: '두 번째 작업은 소스를 열지 않는다');
    expect(logins(), 1);
    gate!.complete();
    await first;
    expect(logins(), 1);
    expect(polled, 1);
    expect(reminded, 1);
  });

  test('새 소식 잠금을 다른 작업이 잡고 있으면 마감 알림만 돈다', () async {
    expect(await notices.acquire(now), isNotNull);
    await run();
    expect(polled, 0);
    expect(reminded, 1);
    expect(logins(), 1);
  });

  test('새 소식이 던져도 마감 알림은 돌고 소스를 닫는다', () async {
    pollError = Exception('boom');
    await expectLater(run(), throwsException);
    expect(reminded, 1);
    expect(opened.single.closed, 1);
  });

  test('00:01 회차에는 새 소식만 돈다', () async {
    now = DateTime.utc(2026, 9, 21, 15, 1); // KST 9/22 00:01
    await run();
    expect(polled, 1);
    expect(reminded, 0);
    expect(logins(), 1);
  });

  test('둘 다 꺼져 있으면 소스를 열지 않는다', () async {
    await run(noticesOn: false, dueOn: false);
    expect(opened, isEmpty);
    expect(polled, 0);
    expect(reminded, 0);
  });

  test('마감 알림만 켜져 있으면 마감 알림만 돈다', () async {
    await run(noticesOn: false);
    expect(polled, 0);
    expect(reminded, 1);
    expect(logins(), 1);
  });
}
