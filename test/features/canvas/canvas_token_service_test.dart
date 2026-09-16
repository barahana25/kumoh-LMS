import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_client.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_api.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_service.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_store.dart';

/// 토큰 API를 대본대로 흉내낸다. 실제 HTTP는 Task 1에서 검증했다.
class _FakeTokenApi implements CanvasTokenApi {
  _FakeTokenApi({this.existing = const [], this.failCreate = false});

  List<CanvasTokenSummary> existing;
  bool failCreate;
  int createCount = 0;
  final List<int> deleted = [];
  bool failDelete = false;

  @override
  Future<IssuedCanvasToken> create(String purpose) async {
    createCount++;
    if (failCreate) throw const CanvasTokenUnavailable();
    return IssuedCanvasToken(id: 44, token: '7~new', purpose: purpose);
  }

  @override
  Future<List<CanvasTokenSummary>> list() async => existing;

  @override
  Future<void> delete(int id) async {
    if (failDelete) throw const CanvasTokenUnavailable();
    deleted.add(id);
  }
}

/// create()가 완료될 때까지 멈춰 있는 API. 발급이 진행 중인 사이에
/// revoke()가 끼어드는 경합을 재현하는 데 쓴다.
class _SlowCreateTokenApi implements CanvasTokenApi {
  _SlowCreateTokenApi(this._completer, {this.failDelete = false});

  final Completer<IssuedCanvasToken> _completer;
  final bool failDelete;
  final List<int> deleted = [];

  @override
  Future<IssuedCanvasToken> create(String purpose) => _completer.future;

  @override
  Future<List<CanvasTokenSummary>> list() async => const [];

  @override
  Future<void> delete(int id) async {
    if (failDelete) throw const CanvasTokenUnavailable();
    deleted.add(id);
  }
}

/// 저장소 read와 clear가 실패하는 경우를 흉내낸다.
/// PlatformException (flutter_secure_storage)처럼 던진다.
class _ThrowingCanvasTokenStore implements CanvasTokenStore {
  @override
  Future<StoredCanvasToken?> read() async =>
      throw Exception('Storage failed to read');

  @override
  Future<void> save(StoredCanvasToken value) async {}

  @override
  Future<void> clear() async =>
      throw Exception('Storage failed to clear');

  @override
  Future<String> ensurePurpose(String platformLabel) async => 'purpose';
}

CanvasTokenService _service(
  CanvasTokenApi api,
  CanvasTokenStore store, {
  Future<void> Function()? ensureSession,
}) =>
    CanvasTokenService(
      api: api,
      store: store,
      ensureSession: ensureSession ?? () async {},
      platformLabel: 'Android',
    );

void main() {
  test('토큰이 없으면 발급해 저장한다', () async {
    final api = _FakeTokenApi();
    final store = InMemoryCanvasTokenStore();

    expect(await _service(api, store).ensure(), '7~new');
    expect((await store.read())!.id, 44);
  });

  test('이미 있으면 발급하지 않는다', () async {
    final api = _FakeTokenApi();
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~old', id: 1, purpose: '금오LMS 앱 · Android · a3f9'));

    expect(await _service(api, store).ensure(), '7~old');
    expect(api.createCount, 0);
  });

  test('같은 이름의 남은 토큰을 지우고 새로 만든다', () async {
    final store = InMemoryCanvasTokenStore();
    final purpose = await store.ensurePurpose('Android');
    final api = _FakeTokenApi(existing: [
      CanvasTokenSummary(id: 41, purpose: purpose),
      const CanvasTokenSummary(id: 42, purpose: '내가 만든 토큰'),
    ]);

    await _service(api, store).ensure();

    expect(api.deleted, [41]);
  });

  test('접두어가 같아도 접미사가 다른 다른 기기(또는 재설치 전 예전 설치)의 '
      '토큰은 건드리지 않는다', () async {
    // 두 기기가 한 계정을 같이 쓸 때(예: 폰과 태블릿), _platformLabel은
    // 둘 다 'Android'로 같다. 접두어까지 넓혀 지우면 한 기기가 발급할
    // 때마다 다른 기기의 살아 있는 토큰을 지우는 핑퐁이 생긴다. 정확
    // 일치만 지워야 이 핑퐁이 생기지 않는다.
    final store = InMemoryCanvasTokenStore();
    await store.ensurePurpose('Android');
    final api = _FakeTokenApi(existing: [
      // 접두어(`금오LMS 앱 · Android · `)는 같지만 접미사가 다르다 —
      // 다른 기기의 토큰이거나, 재설치로 접미사가 바뀐 예전 설치의 토큰.
      const CanvasTokenSummary(id: 40, purpose: '금오LMS 앱 · Android · dead1'),
    ]);

    await _service(api, store).ensure();

    expect(api.deleted, isEmpty);
  });

  test('발급 중 스윕은 이 기기의 예전 토큰(정확히 같은 purpose)은 지우고, '
      '사용자가 직접 만든 토큰은 건드리지 않는다', () async {
    // ensure()가 current()에서 바로 반환하면 _issue()도 _deleteStale()도
    // 돌지 않는다. 저장소를 비운 채로 시작해 스윕이 실제로 실행되게 한다.
    final store = InMemoryCanvasTokenStore();
    final purpose = await store.ensurePurpose('Android');
    final api = _FakeTokenApi(existing: [
      // 이 기기의 예전 발급(예: 앱을 껐다 켠 사이 남은 토큰). purpose가
      // 지금 저장소의 것과 정확히 같다.
      CanvasTokenSummary(id: 41, purpose: purpose),
      // 사용자가 Canvas 설정에서 직접 만든, 이름이 겹치지 않는 토큰.
      const CanvasTokenSummary(id: 42, purpose: '내가 만든 토큰'),
    ]);

    await _service(api, store).ensure();

    expect(api.deleted, [41]);
  });

  test('발급이 실패하면 null을 돌려주고 저장하지 않는다', () async {
    final api = _FakeTokenApi(failCreate: true);
    final store = InMemoryCanvasTokenStore();

    expect(await _service(api, store).ensure(), isNull);
    expect(await store.read(), isNull);
  });

  test('세션 준비가 실패해도 예외를 밖으로 던지지 않는다', () async {
    final api = _FakeTokenApi();
    final store = InMemoryCanvasTokenStore();
    final service = _service(api, store,
        ensureSession: () async => throw StateError('브릿지 실패'));

    expect(await service.ensure(), isNull);
    expect(api.createCount, 0);
  });

  test('동시에 불러도 발급은 한 번만 한다', () async {
    final api = _FakeTokenApi();
    final service = _service(api, InMemoryCanvasTokenStore());

    final results = await Future.wait([service.ensure(), service.ensure()]);

    expect(results, ['7~new', '7~new']);
    expect(api.createCount, 1);
  });

  test('reissueAfterInvalid는 저장된 토큰을 버리고 새로 발급한다', () async {
    final api = _FakeTokenApi();
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~old', id: 1, purpose: '금오LMS 앱 · Android · a3f9'));

    expect(await _service(api, store).reissueAfterInvalid('7~old'), '7~new');
    expect(api.createCount, 1);
  });

  test(
      '같은 만료 토큰으로 겹친 두 번째 401은 방금 저장된 새 토큰을 지우지 않는다',
      () async {
    final api = _FakeTokenApi();
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~old', id: 1, purpose: '금오LMS 앱 · Android · a3f9'));
    final service = _service(api, store);

    final first = await service.reissueAfterInvalid('7~old');
    // 두 번째 401도 같은 '7~old'를 들고 있었다. 이미 새 토큰이 저장된 뒤라
    // 다시 지우거나 재발급하면 안 된다.
    final second = await service.reissueAfterInvalid('7~old');

    expect(first, '7~new');
    expect(second, '7~new');
    expect(api.createCount, 1);
    expect((await store.read())!.token, '7~new');
  });

  test('저장된 토큰이 이미 다른 값이면 재발급 없이 그 값을 돌려준다', () async {
    final api = _FakeTokenApi();
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~current', id: 2, purpose: '금오LMS 앱 · Android · a3f9'));
    final service = _service(api, store);

    final result = await service.reissueAfterInvalid('7~stale');

    expect(result, '7~current');
    expect(api.createCount, 0);
    expect((await store.read())!.token, '7~current');
  });

  test('revoke는 Canvas에서 지우고 로컬도 비운다', () async {
    final api = _FakeTokenApi();
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~old', id: 7, purpose: '금오LMS 앱 · Android · a3f9'));

    await _service(api, store).revoke();

    expect(api.deleted, [7]);
    expect(await store.read(), isNull);
  });

  test('Canvas 삭제가 실패해도 로컬은 비운다', () async {
    final api = _FakeTokenApi()..failDelete = true;
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~old', id: 7, purpose: '금오LMS 앱 · Android · a3f9'));

    await _service(api, store).revoke();

    expect(await store.read(), isNull);
  });

  test('진행 중인 revoke는 그사이 시작한 다음 세션의 토큰을 지우지 않는다',
      () async {
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~A', id: 1, purpose: '금오LMS 앱 · Android · a3f9'));
    final api = _FakeTokenApi();
    final gate = Completer<void>();
    var ensureCalls = 0;
    final service = CanvasTokenService(
      api: api,
      store: store,
      // A의 로그아웃 브릿지만 멈춘다. B의 로그인 브릿지는 바로 끝난다.
      ensureSession: () async {
        ensureCalls++;
        if (ensureCalls == 1) await gate.future;
      },
      platformLabel: 'Android',
    );

    final revokeFuture = service.revoke(); // A 로그아웃 시작, 다리에서 멈춤
    await Future<void>.delayed(Duration.zero);

    // B가 로그인해 새 세션을 시작하고, 그 사이 토큰 발급까지 끝낸다.
    final freshToken = await service.issueFresh();

    // A의 정체됐던 로그아웃 다리가 뒤늦게 풀린다.
    gate.complete();
    await revokeFuture;

    expect(freshToken, '7~new');
    expect((await store.read())?.token, '7~new',
        reason: 'A의 늦은 revoke가 B의 토큰을 지우면 안 된다');
    expect(api.deleted, contains(1), reason: 'A의 예전 토큰은 여전히 지운다');
  });

  test('current는 저장된 값만 본다. 발급하지 않는다', () async {
    final api = _FakeTokenApi();
    final service = _service(api, InMemoryCanvasTokenStore());

    expect(await service.current(), isNull);
    expect(api.createCount, 0);
  });

  test('CanvasTokenApi는 실제 Dio로도 만들 수 있다', () {
    // 가짜가 실제 타입에서 벗어나지 않았는지 확인한다.
    final jar = DefaultCookieJar();
    expect(CanvasTokenApi(buildCanvasDio(jar), jar), isA<CanvasTokenApi>());
  });

  test('저장소가 read에서 실패하면 current는 null을 돌려주고 던지지 않는다',
      () async {
    final store = _ThrowingCanvasTokenStore();
    final service = _service(_FakeTokenApi(), store);

    expect(await service.current(), isNull);
  });

  test('저장소가 던져도 ensure는 예외를 밖으로 던지지 않는다', () async {
    final store = _ThrowingCanvasTokenStore();
    final service = _service(_FakeTokenApi(), store);

    // ensure()는 current()를 호출하는데, current가 실패해도
    // _issue()는 API를 호출해 토큰을 발급한다.
    // 예외를 던지지 않아야 한다.
    final result = await service.ensure();
    expect(result, isNotNull);
  });

  test('저장소 clear 실패해도 reissueAfterInvalid는 던지지 않는다', () async {
    final store = _ThrowingCanvasTokenStore();
    final service = _service(_FakeTokenApi(), store);

    // reissueAfterInvalid()는 clear()에서 실패할 수 있다.
    // 예외를 던지지 않고 새 토큰을 발급해야 한다.
    final result = await service.reissueAfterInvalid('7~old');
    expect(result, isNotNull);
  });

  test('저장소가 실패해도 revoke는 예외를 던지지 않는다', () async {
    final store = _ThrowingCanvasTokenStore();
    final service = _service(_FakeTokenApi(), store);

    // revoke()는 read()와 clear()에서 실패할 수 있다.
    // 예외를 던지지 않아야 한다.
    await service.revoke();
  });

  test('발급 도중 로그아웃하면 저장하지 않고 Canvas에서 만든 토큰을 지운다',
      () async {
    final completer = Completer<IssuedCanvasToken>();
    final api = _SlowCreateTokenApi(completer);
    final store = InMemoryCanvasTokenStore();
    final service = _service(api, store);

    // create()가 completer를 기다리는 사이에 로그아웃이 끼어든다.
    final ensureFuture = service.ensure();
    await service.revoke();
    completer.complete(
        const IssuedCanvasToken(id: 99, token: '7~late', purpose: 'p'));

    expect(await ensureFuture, isNull);
    expect(await store.read(), isNull);
    expect(api.deleted, [99]);
  });

  test('issueFresh는 이전 세션이 남긴 토큰을 이어받지 않고 새로 발급한다',
      () async {
    final api = _FakeTokenApi();
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~old', id: 1, purpose: '금오LMS 앱 · Android · a3f9'));

    final result = await _service(api, store).issueFresh();

    expect(result, '7~new');
    expect(api.createCount, 1);
    expect((await store.read())!.token, '7~new');
  });

  test('세션이 끝난 뒤 정리 삭제가 실패해도 아무것도 던지지 않는다',
      () async {
    final completer = Completer<IssuedCanvasToken>();
    final api = _SlowCreateTokenApi(completer, failDelete: true);
    final store = InMemoryCanvasTokenStore();
    final service = _service(api, store);

    final ensureFuture = service.ensure();
    await service.revoke();
    completer.complete(
        const IssuedCanvasToken(id: 99, token: '7~late', purpose: 'p'));

    expect(await ensureFuture, isNull);
    expect(await store.read(), isNull);
  });
}
