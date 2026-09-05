/// 컬렉션 단위 캐시 신선도 판정. 이 창 안에서는 네트워크를 치지 않는다.
class CachePolicy {
  const CachePolicy._();

  static bool isFresh(DateTime? fetchedAt, Duration ttl) {
    if (fetchedAt == null) return false;
    return DateTime.now().toUtc().difference(fetchedAt.toUtc()) < ttl;
  }
}
