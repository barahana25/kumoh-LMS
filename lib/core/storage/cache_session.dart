/// 로그아웃 전에 시작한 요청이 이전 계정의 데이터를 다시 쓰지 못하게 한다.
class CacheSession {
  int _revision = 0;
  bool _active = true;

  int get revision => _revision;
  bool accepts(int revision) => _active && revision == _revision;

  void end() {
    _active = false;
    _revision++;
  }

  /// 이미 열려 있으면 아무 것도 하지 않는다. 멱등해야 모든 인증 전환
  /// 지점에서 안전하게 부를 수 있고, 진행 중인 요청을 헛되이 무효화하지 않는다.
  void start() {
    if (_active) return;
    _revision++;
    _active = true;
  }
}
