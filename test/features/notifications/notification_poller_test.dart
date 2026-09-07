import 'dart:async';
import 'package:drift/drift.dart' show Migrator, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/notifications/data/notification_models.dart';
import 'package:kumoh_lms/features/notifications/data/notification_poller.dart';
import 'package:kumoh_lms/features/notifications/data/notification_store.dart';
import '../../helpers/test_db.dart';

class FakeSource implements NotificationSource {
  String owner = 'student';
  int logins = 0;
  Failure? authFailure;
  final values = <String, List<WatchedItem>>{};
  final failures = <String>{};
  List<WatchedCourse> watched = [const WatchedCourse(1, '테스트 강좌')];
  Future<void> Function()? beforeItems;
  @override
  Future<String> authenticate() async {
    logins++;
    if (authFailure != null) throw authFailure!;
    return owner;
  }

  @override
  Future<List<WatchedCourse>> courses() async => watched;
  @override
  Future<List<WatchedItem>> items(int id, NoticeKind kind) async {
    await beforeItems?.call();
    final key = '$id/${kind.name}';
    if (failures.contains(key)) throw const NetworkFailure();
    return values[key] ?? [];
  }

  @override
  void close() {}
}

class FakeSink implements NoticeSink {
  bool allowed = true;
  bool fail = false;
  final shown = <PendingNotice>[];
  final cancelled = <int>[];
  @override
  Future<bool> permitted() async => allowed;
  @override
  Future<void> show(PendingNotice n) async {
    shown.add(n);
    if (fail) throw Exception('OS unavailable');
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

void main() {
  late AppDatabase db;
  late NotificationStore store;
  late FakeSource source;
  late FakeSink sink;
  late NotificationPoller poller;
  late DateTime now;
  setUp(() async {
    db = createTestDatabase();
    store = NotificationStore(db);
    source = FakeSource();
    sink = FakeSink();
    now = DateTime.utc(2026, 9, 6, 0, 1);
    poller = NotificationPoller(
        store: store,
        sourceFactory: () => source,
        sink: sink,
        clock: () => now);
    await store.enable('student');
  });
  tearDown(() => db.close());
  Future<void> tick() async {
    now = now.add(const Duration(hours: 1));
    await poller.run();
  }

  test('첫 조회는 기준만 저장하고 세 종류의 신규 항목만 한 번씩 알린다', () async {
    for (final kind in NoticeKind.values) {
      source.values['1/${kind.name}'] = [const WatchedItem('100', '기존')];
    }
    await poller.run();
    expect(sink.shown, isEmpty);
    for (final kind in NoticeKind.values) {
      source.values['1/${kind.name}'] = [
        const WatchedItem('9', '새 항목'),
        const WatchedItem('100', '기존')
      ];
    }
    await tick();
    expect(sink.shown.map((n) => n.kind), containsAll(NoticeKind.values));
    expect(sink.shown.length, 3);
    // 재시작해도 메모리 집합이 아닌 DB 기록으로 중복을 막는다.
    poller = NotificationPoller(
        store: NotificationStore(db),
        sourceFactory: () => source,
        sink: sink,
        clock: () => now);
    await tick();
    expect(sink.shown.length, 3);
  });

  test('빈 목록도 기준이 된다. 삭제 후 재등장이나 제목 수정은 신규가 아니다', () async {
    await poller.run();
    source.values['1/file'] = [const WatchedItem('1', '자료.pdf')];
    await tick();
    source.values['1/file'] = [];
    await tick();
    source.values['1/file'] = [const WatchedItem('1', '이름 변경.pdf')];
    await tick();
    expect(sink.shown.length, 1);
  });

  test('실패한 목록은 기준을 만들지 않고 다른 목록은 계속 확인한다', () async {
    source.failures.add('1/file');
    await poller.run();
    source.values['1/file'] = [const WatchedItem('1', '예전 자료')];
    source.values['1/assignment'] = [const WatchedItem('2', '새 과제')];
    source.failures.clear();
    await tick();
    expect(sink.shown.map((n) => n.title), ['새 과제']);
  });

  test('한 시간 이내의 자동 확인과 중복 실행은 네트워크를 시작하지 않는다', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    source.beforeItems = () async {
      if (!started.isCompleted) started.complete();
      await release.future;
    };
    final first = poller.run();
    await started.future;
    await poller.run(force: true);
    expect(source.logins, 1);
    release.complete();
    await first;
    await poller.run();
    expect(source.logins, 1);
    await tick();
    expect(source.logins, 2);
  });

  test('OS 알림 실패는 보낼 목록을 보존하고 같은 알림 ID로 재시도한다', () async {
    await poller.run();
    source.values['1/announcement'] = [const WatchedItem('1', '공지')];
    sink.fail = true;
    await tick();
    expect((await db.select(db.notificationOutbox).get()).length, 1);
    final attemptedId = sink.shown.single.id;
    sink.fail = false;
    await tick();
    expect(sink.shown.last.id, attemptedId);
    expect(await db.select(db.notificationOutbox).get(), isEmpty);
  });

  test('권한 거부는 크롤링과 기준 갱신을 하지 않는다', () async {
    sink.allowed = false;
    await poller.run();
    expect(source.logins, 0);
    expect(await db.select(db.notificationBaselines).get(), isEmpty);
  });

  test('로그아웃 중 돌아온 응답은 알림이나 확인 기록을 남기지 않는다', () async {
    await poller.run();
    source.values['1/file'] = [const WatchedItem('1', '새 파일')];
    source.beforeItems = () async {
      await store.disable();
      await db.wipe();
    };
    await tick();
    expect(sink.shown, isEmpty);
    expect(await db.select(db.notificationSeenItems).get(), isEmpty);
    expect(await store.settings(), isNull);
  });

  test('설정 소유자와 로그인 계정이 다르면 확인하지 않는다', () async {
    source.owner = 'other';
    await poller.run();
    expect(await db.select(db.notificationBaselines).get(), isEmpty);
    expect(sink.shown, isEmpty);
  });

  test('비정상 종료된 작업의 잠금은 만료 후 다시 얻는다', () async {
    expect(await store.acquire(now), isNotNull);
    expect(await store.acquire(now, force: true), isNull);
    expect(await store.acquire(now.add(const Duration(hours: 1))), isNotNull);
  });

  test('로그인 실패는 자동 확인을 꺼서 잘못된 암호로 반복 로그인하지 않는다', () async {
    source.authFailure = const AuthFailure();
    await poller.run();
    expect((await store.settings())!.enabled, isFalse);
    await tick();
    expect(source.logins, 1);
  });

  test('시간 예산이 끝나면 다음 실행은 남은 목록부터 이어간다', () async {
    source.beforeItems =
        () => Future<void>.delayed(const Duration(milliseconds: 100));
    final limited = NotificationPoller(
        store: store,
        sourceFactory: () => source,
        sink: sink,
        clock: () => now,
        budget: const Duration(milliseconds: 70));
    await limited.run();
    expect((await store.settings())!.cursor, 1);
    now = now.add(const Duration(hours: 1));
    await limited.run();
    expect((await store.settings())!.cursor, 2);
    expect((await db.select(db.notificationBaselines).get()).length, 2);
  });

  test('알림을 다시 켜면 꺼져 있던 동안의 항목으로 알림이 쏟아지지 않는다', () async {
    await poller.run();
    await store.disable();
    source.values['1/file'] = [const WatchedItem('1', '오래된 파일')];
    await store.enable('student');
    await tick();
    expect(sink.shown, isEmpty);
  });

  test('새로 수강한 강좌의 기존 항목은 기준으로만 저장한다', () async {
    await poller.run();
    source.watched.add(const WatchedCourse(2, '추가 강좌'));
    source.values['2/file'] = [const WatchedItem('1', '기존 자료')];
    await tick();
    expect(sink.shown, isEmpty);
  });

  test('v2 업그레이드는 강좌 데이터를 유지하며 알림 테이블을 만든다', () async {
    await db.coursesDao.upsertAll([
      CoursesCompanion.insert(
          id: const Value(1), termId: 8, name: '강좌', courseCode: 'C')
    ]);
    for (final name in [
      'notification_settings',
      'notification_baselines',
      'notification_seen_items',
      'notification_outbox'
    ]) {
      await db.customStatement('DROP TABLE $name');
    }
    await db.migration.onUpgrade(Migrator(db), 2, 3);
    expect((await db.select(db.courses).get()).single.name, '강좌');
    await store.enable('student');
    expect((await store.settings())!.enabled, isTrue);
    await poller.run();
    expect((await db.select(db.notificationBaselines).get()).length, 3);
  });
}
