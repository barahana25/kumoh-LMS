import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_cache.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late CanvasCache cache;

  setUp(() {
    db = createTestDatabase();
    cache = CanvasCache(db);
  });
  tearDown(() => db.close());

  group('저장소', () {
    test('쓴 것을 그대로 읽는다', () async {
      await cache.write('assignments:4831', [
        {'id': 1, 'name': '과제'}
      ]);

      final entry = await cache.read('assignments:4831');

      expect(entry, isNotNull);
      expect((entry!.payload as List).single, {'id': 1, 'name': '과제'});
      expect(entry.fetchedAt.isUtc, isTrue);
    });

    test('없는 키는 null', () async {
      expect(await cache.read('없음'), isNull);
    });

    test('같은 키를 다시 쓰면 덮어쓴다', () async {
      await cache.write('k', {'v': 1});
      await cache.write('k', {'v': 2});

      expect((await cache.read('k'))!.payload, {'v': 2});
    });
  });

  group('watchCanvas', () {
    test('캐시가 없으면 네트워크 결과만 내보낸다', () async {
      final snaps = await watchCanvas<int>(
        cache: cache,
        key: 'k',
        ttl: Duration.zero,
        fetch: () async => 7,
        parse: (j) => j! as int,
      ).toList();

      expect(snaps.length, 1);
      expect(snaps.single.data, 7);
      expect(snaps.single.stale, isFalse);
    });

    test('캐시가 있으면 먼저 캐시를, 이어서 새 값을 내보낸다', () async {
      await cache.write('k', 1);

      final snaps = await watchCanvas<int>(
        cache: cache,
        key: 'k',
        ttl: Duration.zero,
        fetch: () async => 2,
        parse: (j) => j! as int,
      ).toList();

      expect(snaps.map((s) => s.data), [1, 2],
          reason: '빈 화면을 보여주지 않고 즉시 캐시를 그린 뒤 갱신해야 한다');
      expect(snaps.first.stale, isTrue);
      expect(snaps.last.stale, isFalse);
    });

    test('TTL이 0이면 캐시가 아무리 새것이어도 네트워크를 친다', () async {
      await cache.write('k', 1);
      var fetched = 0;

      await watchCanvas<int>(
        cache: cache,
        key: 'k',
        ttl: Duration.zero,
        fetch: () async {
          fetched++;
          return 2;
        },
        parse: (j) => j! as int,
      ).toList();

      expect(fetched, 1,
          reason: '언제 바뀔지 모르는 데이터는 TTL로 건너뛰면 안 된다');
    });

    test('TTL 안이면 네트워크를 건너뛴다', () async {
      await cache.write('k', 1);
      var fetched = 0;

      final snaps = await watchCanvas<int>(
        cache: cache,
        key: 'k',
        ttl: const Duration(hours: 24),
        fetch: () async {
          fetched++;
          return 2;
        },
        parse: (j) => j! as int,
      ).toList();

      expect(fetched, 0, reason: '거의 안 바뀌는 데이터까지 매번 치면 서버 부하다');
      expect(snaps.single.data, 1);
      expect(snaps.single.stale, isFalse, reason: 'TTL 안의 캐시는 낡은 게 아니다');
    });

    test('네트워크가 실패해도 캐시가 있으면 캐시를 유지하고 오류를 함께 알린다', () async {
      await cache.write('k', 1);

      final snaps = await watchCanvas<int>(
        cache: cache,
        key: 'k',
        ttl: Duration.zero,
        fetch: () async => throw const NetworkFailure(),
        parse: (j) => j! as int,
      ).toList();

      expect(snaps.map((s) => s.data), [1, 1]);
      expect(snaps.last.stale, isTrue);
      expect(snaps.last.error, isA<NetworkFailure>());
    });

    test('캐시도 없고 네트워크도 실패하면 그대로 던진다', () async {
      final stream = watchCanvas<int>(
        cache: cache,
        key: 'k',
        ttl: Duration.zero,
        fetch: () async => throw const NetworkFailure(),
        parse: (j) => j! as int,
      );

      await expectLater(stream.toList(), throwsA(isA<NetworkFailure>()));
    });

    test('성공하면 새 값을 캐시에 남긴다', () async {
      await watchCanvas<int>(
        cache: cache,
        key: 'k',
        ttl: Duration.zero,
        fetch: () async => 42,
        parse: (j) => j! as int,
      ).toList();

      expect((await cache.read('k'))!.payload, 42);
    });

    test('캐시 내용이 깨져 있으면 무시하고 네트워크로 간다', () async {
      await cache.write('k', {'모양이': '다름'});

      final snaps = await watchCanvas<int>(
        cache: cache,
        key: 'k',
        ttl: Duration.zero,
        fetch: () async => 9,
        parse: (j) => j! as int,
      ).toList();

      expect(snaps.single.data, 9,
          reason: '스키마가 바뀐 낡은 캐시 때문에 화면이 죽으면 안 된다');
    });
  });

  test('로그아웃 시 캐시가 함께 지워진다', () async {
    await cache.write('assignments:4831', [1]);
    await db.wipe();
    expect(await cache.read('assignments:4831'), isNull);
  });
}
