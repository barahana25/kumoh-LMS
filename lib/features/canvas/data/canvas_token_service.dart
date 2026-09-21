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

  /// 로그인/로그아웃이 바뀔 때마다 올라간다. 진행 중인 발급이 이 번호가
  /// 바뀐 걸 보면, 자신을 요청한 세션이 이미 끝났다는 뜻이다.
  int _session = 0;

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
    // 저장소를 들여다보기(await) 전에, 지금 이 요청이 속한 세션 번호부터
    // 동기적으로 찍어 둔다. 그러지 않으면 이 await가 도는 사이에 로그아웃이
    // 끼어들어 세션 번호를 올려도, 뒤늦게 찍는 번호는 이미 바뀐 값을 보게
    // 되어 경합을 놓친다.
    final sessionAtStart = _session;
    final existing = await current();
    if (existing != null) return existing;
    return _issuing ??= _runIssue(sessionAtStart);
  }

  /// 401을 만난 뒤 쓴다. 실패한 요청이 실제로 들고 있던 토큰([invalidToken])이
  /// 지금 저장된 값과 같을 때만 지우고 한 번 다시 발급한다. 세션 번호는
  /// 올리지 않는다 — 로그인은 그대로이고 토큰만 무효가 됐을 뿐이라, 새
  /// 로그인([issueFresh])과는 의도가 다르다.
  ///
  /// 같은 만료 토큰으로 보낸 요청 여럿이 겹쳐 401을 여러 번 받을 수 있다.
  /// 먼저 도착한 401이 이미 새 토큰을 저장해 둔 뒤, 뒤늦게 도착한 401이
  /// [invalidToken]만 보고 무조건 지우면 방금 저장한 유효한 토큰을 날리고
  /// 또 재발급하게 된다 — 그사이 저장소가 비어 다른 요청이 불필요하게
  /// 쿠키/SAML 경로로 떨어진다. 저장된 값이 [invalidToken]과 다르면 이미
  /// 누군가 처리를 끝냈다는 뜻이니 그 값을 그대로 돌려준다.
  Future<String?> reissueAfterInvalid(String invalidToken) async {
    StoredCanvasToken? stored;
    try {
      stored = await _store.read();
    } on Object {
      // 저장소 읽기 실패. 지울 대상이 없는 것처럼 처리한다.
      stored = null;
    }
    if (stored != null && stored.token != invalidToken) {
      return stored.token;
    }
    try {
      await _store.clear();
    } on Object {
      // 저장소 지우기 실패해도 새 토큰 발급을 계속한다.
    }
    final sessionAtStart = _session;
    return _issuing ??= _runIssue(sessionAtStart, deleteBeforeIssueId: stored?.id);
  }

  /// 새 로그인에서 쓴다. 세션 번호를 올려 이전 세션이 발급하던 토큰을
  /// 무효화하고, 저장된 토큰(로그아웃 경합으로 남았다면 이전 사용자 것일
  /// 수 있다)을 지운 뒤 새로 발급한다. 기기를 함께 쓰는 다음 사용자가
  /// 이전 사용자의 Canvas 토큰을 이어받지 않게 하는 것이 목적이라
  /// [reissueAfterInvalid]와는 의도가 다르다.
  Future<String?> issueFresh() async {
    _session++;
    final sessionAtStart = _session;
    StoredCanvasToken? previous;
    try {
      previous = await _store.read();
    } on Object {
      // 저장소 읽기 실패. 지울 대상이 없는 것처럼 처리한다.
      previous = null;
    }
    try {
      await _store.clear();
    } on Object {
      // 저장소 지우기 실패해도 새 토큰 발급을 계속한다.
    }
    return _issuing = _runIssue(sessionAtStart, deleteBeforeIssueId: previous?.id);
  }

  /// Canvas에서 이 기기 토큰을 지우고 로컬도 비운다.
  /// 세션 번호를 올려, 지금 막 발급 중인 토큰이 있다면 그 결과를 저장하지
  /// 않고 Canvas에서도 지우게 한다 — 로그아웃과 경합하는 발급이 로그아웃
  /// 이후 디스크에 새 토큰을 남기는 걸 막는다.
  Future<void> revoke() async {
    _session++;
    // _issue()와 같은 이유로, await 전에 동기적으로 세션 번호를 찍어 둔다.
    // 기기를 공유하는 다음 사용자가 로그인해 세션이 또 바뀌면(_session이
    // sessionAtStart와 달라지면), 이 revoke는 이미 끝난 세션 소관이라 마지막에
    // 저장소를 지우면 안 된다 — 다음 사용자가 막 받은 토큰을 지워 버린다.
    final sessionAtStart = _session;
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
      if (_session == sessionAtStart) {
        try {
          await _store.clear();
        } on Object {
          // 저장소 지우기도 실패할 수 있다. 그래도 계속한다.
        }
      }
    }
  }

  /// [_issue]를 시작하고, 이 시도가 끝났을 때 그사이 아무도 새 시도로
  /// [_issuing]을 바꿔치기하지 않았을 때만 [_issuing]을 비운다.
  ///
  /// [deleteBeforeIssueId]가 있으면, 새 토큰을 만들기 전에 Canvas에서 그
  /// id의 토큰을 최선을 다해 지운다(실패해도 발급은 계속한다) — 이 기기가
  /// 방금 저장소에서 지운(또는 지우려던) 예전 토큰이다. `ensure()`가 기존
  /// 토큰을 그대로 쓰는 지름길에는 이 값이 전달되지 않는다: 멀쩡한 토큰을
  /// 지울 이유가 없기 때문이다.
  Future<String?> _runIssue(int sessionAtStart, {int? deleteBeforeIssueId}) {
    late final Future<String?> attempt;
    attempt = _issue(sessionAtStart, deleteBeforeIssueId: deleteBeforeIssueId)
        .whenComplete(() {
      if (identical(_issuing, attempt)) _issuing = null;
    });
    return attempt;
  }

  Future<String?> _issue(int sessionAtStart, {int? deleteBeforeIssueId}) async {
    try {
      await _ensureSession();
      final purpose = await _store.ensurePurpose(_platformLabel);
      if (deleteBeforeIssueId != null) {
        await _bestEffortDelete(deleteBeforeIssueId);
      }
      final issued = await _api.create(purpose);
      if (_session != sessionAtStart) {
        // 이 발급을 요청한 세션은 이미 끝났다(로그아웃/재로그인이 먼저
        // 끝남). 저장하면 로그아웃 이후 디스크에 토큰이 남거나, 다음
        // 사용자가 이전 사용자의 토큰을 이어받는다. 저장하지 않고
        // 최선을 다해 Canvas에서도 지운다.
        await _bestEffortDelete(issued.id);
        return null;
      }
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

  /// 세션이 바뀌어 저장할 수 없게 된 토큰이나, 새로 발급하기 전 이 기기가
  /// 들고 있던 예전 토큰을 Canvas에서 지운다. 값은 다시 볼 수 없어 쓸 수
  /// 없고, 그대로 두면 계정에 권한 제한 없는 토큰이 만료 없이 쌓인다.
  /// 실패해도 던지지 않는다 — 여기서 할 수 있는 최선을 다했을 뿐이고,
  /// 지우지 못한 토큰은 사용자가 Canvas 설정에서 직접 지울 수 있다.
  ///
  /// 목록을 훑어 지우지 않고 항상 **이 기기가 저장하고 있던 id**로만
  /// 지운다. 이 Canvas 서버는 `GET /api/v1/users/self/tokens`가 404라
  /// 목록 조회 자체가 없다 — `POST`(발급)와 `DELETE /{id}`(삭제)만 있다.
  /// id 기반이라 이 호출이 실패해도(네트워크, 이미 지워짐 등) 새 토큰
  /// 발급은 항상 계속 진행한다.
  ///
  /// 대가: 재설치로 이 기기의 보관소가 통째로 사라지면(Android는
  /// `allowBackup="false"`라 앱을 지우면 저장소도 함께 사라진다) 예전
  /// 설치가 들고 있던 토큰의 id를 더는 알 수 없어 여기서 지워지지 않는다
  /// — 그 토큰은 범위 제한 없이 계정에 남는다. 마찬가지로 이 기능이
  /// 배포되기 전에 이미 발급됐던 토큰(그때는 id를 지우려는 시도조차 하지
  /// 않았다)도 영영 고아로 남는다. 두 경우 모두 Canvas 설정(프로필 → 설정
  /// → 승인된 통합)에서 사용자가 직접 지워야 한다.
  Future<void> _bestEffortDelete(int id) async {
    try {
      await _api.delete(id);
    } on Object {
      // 지우지 못해도 여기서는 더 할 수 있는 게 없다.
    }
  }
}
