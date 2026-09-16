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

CanvasTokenService _service(
  _FakeTokenApi api,
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

    expect(await _service(api, store).reissueAfterInvalid(), '7~new');
    expect(api.createCount, 1);
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
}
