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

  void start() {
    _revision++;
    _active = true;
  }
}
