import 'canvas_token_api.dart';
import 'canvas_token_store.dart';

/// Canvas 개인 액세스 토큰의 수명을 관리한다.
///
/// 발급은 SAML 다리로 얻은 Canvas 세션이 필요하므로 [ensureSession]을 받는다.
/// 실패는 밖으로 던지지 않는다. 토큰이 없으면 호출자가 쿠키 경로로 폴백한다.
class CanvasTokenService {
  CanvasTokenService({
    required CanvasTokenApi api,
    required CanvasTokenStore store,
    required Future<void> Function() ensureSession,
    required String platformLabel,
  })  : _api = api,
        _store = store,
        _ensureSession = ensureSession,
        _platformLabel = platformLabel;

  final CanvasTokenApi _api;
  final CanvasTokenStore _store;
  final Future<void> Function() _ensureSession;
  final String _platformLabel;

  Future<String?>? _issuing;

  /// 저장된 토큰. 없으면 null. 발급하지 않는다.
  Future<String?> current() async {
    try {
      return (await _store.read())?.token;
    } on Object {
      // 저장소 읽기 실패. 토큰이 없는 것처럼 처리한다.
      return null;
    }
  }

  /// 없으면 발급한다. 동시 호출은 한 번의 발급을 공유한다.
  Future<String?> ensure() async {
    final existing = await current();
    if (existing != null) return existing;
    return _issuing ??= _issue().whenComplete(() => _issuing = null);
  }

  /// 401을 만난 뒤 쓴다. 저장된 토큰을 버리고 한 번 다시 발급한다.
  Future<String?> reissueAfterInvalid() async {
    try {
      await _store.clear();
    } on Object {
      // 저장소 지우기 실패해도 새 토큰 발급을 계속한다.
    }
    return ensure();
  }

  /// Canvas에서 이 기기 토큰을 지우고 로컬도 비운다.
  Future<void> revoke() async {
    late final StoredCanvasToken? stored;
    try {
      stored = await _store.read();
    } on Object {
      // 저장소 읽기 실패. null로 처리하고 계속한다.
      stored = null;
    }
    try {
      if (stored != null) {
        await _ensureSession();
        await _api.delete(stored.id);
      }
    } on Object {
      // 지우지 못해도 로컬은 비운다. 사용자는 Canvas 설정에서 직접 지울 수 있다.
    } finally {
      try {
        await _store.clear();
      } on Object {
        // 저장소 지우기도 실패할 수 있다. 그래도 계속한다.
      }
    }
  }

  Future<String?> _issue() async {
    try {
      await _ensureSession();
      final purpose = await _store.ensurePurpose(_platformLabel);
      await _deleteStale(purpose);
      final issued = await _api.create(purpose);
      await _store.save(StoredCanvasToken(
        token: issued.token,
        id: issued.id,
        purpose: issued.purpose,
      ));
      return issued.token;
    } on Object {
      return null;
    }
  }

  /// 같은 이름의 토큰이 남아 있으면 지운다. 값을 다시 볼 수 없어 쓸 수 없고,
  /// 그대로 두면 재설치할 때마다 계정에 쌓인다.
  Future<void> _deleteStale(String purpose) async {
    try {
      for (final token in await _api.list()) {
        if (token.purpose == purpose) await _api.delete(token.id);
      }
    } on Object {
      // 목록을 못 봐도 발급은 계속한다.
    }
  }
}
