import 'dart:convert';


import '../../../core/storage/cache_policy.dart';
import '../../../core/storage/db/app_database.dart';

/// 캐시에서 꺼낸 원본 JSON과 그것을 받아온 시각.
class CanvasCacheEntry {
  const CanvasCacheEntry({required this.payload, required this.fetchedAt});
  final Object? payload;
  final DateTime fetchedAt;
}

/// 강좌 상세 탭들의 캐시.
///
/// v1의 강좌·과제·공지와 달리 이 데이터는 테이블 간 조회가 전혀 없다.
/// 게다가 문서 없는 API라 응답 모양이 예고 없이 바뀐다. 탭마다 테이블을
/// 만들면 스키마가 바뀔 때마다 마이그레이션이 필요하므로, 원본 JSON을
/// 그대로 보관하고 읽을 때 해석한다.
class CanvasCache {
  CanvasCache(this._db);
  final AppDatabase _db;

  Future<CanvasCacheEntry?> read(String key) async {
    final row = await (_db.select(_db.canvasCacheEntries)
          ..where((e) => e.key.equals(key)))
        .getSingleOrNull();
    if (row == null) return null;
    try {
      return CanvasCacheEntry(
        payload: jsonDecode(row.payload),
        fetchedAt: row.fetchedAt,
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> delete(String key) async {
    await (_db.delete(_db.canvasCacheEntries)..where((e) => e.key.equals(key)))
        .go();
  }

  Future<void> write(String key, Object? payload) async {
    await _db.into(_db.canvasCacheEntries).insertOnConflictUpdate(
          CanvasCacheEntriesCompanion.insert(
            key: key,
            payload: jsonEncode(payload),
            fetchedAt: DateTime.now().toUtc(),
          ),
        );
  }
}

/// 화면에 내보내는 한 컷.
class CanvasSnapshot<T> {
  const CanvasSnapshot({
    required this.data,
    required this.stale,
    this.fetchedAt,
    this.error,
  });

  final T data;

  /// 서버에서 막 받아온 값이 아니다. 화면에 "○분 전 기준"을 띄워야 한다.
  final bool stale;

  final DateTime? fetchedAt;

  /// 갱신에 실패했지만 캐시로 화면은 유지한 경우의 원인.
  final Object? error;
}

/// 캐시를 먼저 그리고, 필요하면 네트워크로 갱신한다.
///
/// [ttl]이 0이면 캐시가 아무리 새것이어도 반드시 다시 받아온다. 공지·과제처럼
/// 언제 바뀔지 모르는 데이터는 TTL로 요청을 건너뛰면 학생이 새 내용을 놓친다.
/// 그런 탭에서도 캐시는 첫 화면과 오프라인 대비로 여전히 쓸모가 있다.
Stream<CanvasSnapshot<T>> watchCanvas<T>({
  required CanvasCache cache,
  required String key,
  required Duration ttl,
  required Future<Object?> Function() fetch,
  required T Function(Object? json) parse,
}) async* {
  final cached = await cache.read(key);

  T? cachedData;
  if (cached != null) {
    try {
      cachedData = parse(cached.payload);
    } on Object {
      // 스키마가 바뀐 낡은 캐시. 화면을 죽이지 말고 네트워크로 간다.
      cachedData = null;
    }
  }

  final fresh = cached != null && CachePolicy.isFresh(cached.fetchedAt, ttl);

  if (cachedData != null) {
    yield CanvasSnapshot<T>(
      data: cachedData,
      // TTL 안에 있는 캐시는 낡은 게 아니다.
      stale: !fresh,
      fetchedAt: cached!.fetchedAt,
    );
    if (fresh) return;
  }

  try {
    final raw = await fetch();
    await cache.write(key, raw);
    yield CanvasSnapshot<T>(
      data: parse(raw),
      stale: false,
      fetchedAt: DateTime.now().toUtc(),
    );
  } on Object catch (e) {
    // 캐시가 있으면 화면을 지우지 않는다. 없으면 알릴 방법이 없으니 던진다.
    if (cachedData == null) rethrow;
    yield CanvasSnapshot<T>(
      data: cachedData,
      stale: true,
      fetchedAt: cached!.fetchedAt,
      error: e,
    );
  }
}
