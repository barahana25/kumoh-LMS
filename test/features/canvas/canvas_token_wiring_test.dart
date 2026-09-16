import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_service.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_store.dart';
import 'package:kumoh_lms/providers.dart';

class _HeaderProbe implements HttpClientAdapter {
  _HeaderProbe(this.onHeader);
  final void Function(String?) onHeader;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onHeader(options.headers['Authorization'] as String?);
    return ResponseBody.fromString('{}', 200, headers: {
      'content-type': ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('토큰 서비스와 보관소가 배선돼 있다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(canvasTokenStoreProvider), isA<CanvasTokenStore>());
    expect(container.read(canvasTokenServiceProvider), isA<CanvasTokenService>());
  });

  test('토큰 보관소는 앱 전체가 같은 인스턴스를 쓴다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      identical(container.read(canvasTokenStoreProvider),
          container.read(canvasTokenStoreProvider)),
      isTrue,
    );
  });

  test('Canvas dio는 토큰이 있으면 Bearer를 붙인다', () async {
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~abc', id: 1, purpose: '금오LMS 앱 · Android · a3f9'));
    final container = ProviderContainer(overrides: [
      canvasTokenStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);

    final dio = container.read(canvasDioProvider);
    // 인터셉터가 요청 직전에 토큰을 읽는다. 어댑터를 바꿔 헤더만 확인한다.
    String? seen;
    dio.httpClientAdapter = _HeaderProbe((value) => seen = value);
    await dio.get<dynamic>('/users/self');

    expect(seen, 'Bearer 7~abc');
  });

  test('로그아웃하면 저장된 Canvas 토큰이 사라진다', () async {
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~abc', id: 1, purpose: '금오LMS 앱 · Android · a3f9'));
    final container = ProviderContainer(overrides: [
      canvasTokenStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);

    await container.read(canvasTokenServiceProvider).revoke();

    expect(await store.read(), isNull);
  });
}
