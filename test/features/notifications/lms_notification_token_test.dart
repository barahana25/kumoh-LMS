import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_api.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_store.dart';
import 'package:kumoh_lms/features/notifications/data/lms_notification_source.dart';
import 'package:kumoh_lms/core/network/token_store.dart';

/// 붙은 Authorization이 죽은 토큰이면 401을, 아니면 200을 준다.
class _Script implements HttpClientAdapter {
  final List<String?> authHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final auth = options.headers['Authorization'] as String?;
    authHeaders.add(auth);
    final status = auth == 'Bearer 7~dead' ? 401 : 200;
    return ResponseBody.fromString('{}', status, headers: {
      'content-type': ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

class _ThrowingCanvasTokenStore implements CanvasTokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String> ensurePurpose(String platformLabel) async => '';

  @override
  Future<StoredCanvasToken?> read() async {
    throw Exception('Keystore error');
  }

  @override
  Future<void> save(StoredCanvasToken token) async {}
}

void main() {
  test('Canvas 토큰 보관소를 받아 둔다', () async {
    final canvasTokens = InMemoryCanvasTokenStore();
    await canvasTokens.save(const StoredCanvasToken(
        token: '7~abc', id: 1, purpose: '금오LMS 앱 · Android · a3f9'));

    final source = LmsNotificationSource(
      InMemoryTokenStore(),
      canvasTokenStore: canvasTokens,
    );

    expect(await source.canvasAccessToken(), '7~abc');
  });

  test('보관소를 넘기지 않으면 토큰 없이 동작한다', () async {
    final source = LmsNotificationSource(InMemoryTokenStore());
    expect(await source.canvasAccessToken(), isNull);
  });

  test('보관소 읽기 실패를 조용히 처리해 쿠키로 폴백한다', () async {
    final source = LmsNotificationSource(
      InMemoryTokenStore(),
      canvasTokenStore: _ThrowingCanvasTokenStore(),
    );

    expect(await source.canvasAccessToken(), isNull);
  });

  test('retireCanvasToken은 그 토큰을 다시 돌려주지 않는다', () async {
    final canvasTokens = InMemoryCanvasTokenStore();
    await canvasTokens.save(const StoredCanvasToken(
        token: '7~dead', id: 1, purpose: '금오LMS 앱 · Android · a3f9'));
    final source = LmsNotificationSource(
      InMemoryTokenStore(),
      canvasTokenStore: canvasTokens,
    );

    expect(await source.canvasAccessToken(), '7~dead');
    expect(await source.retireCanvasToken('7~dead'), isNull);
    expect(await source.canvasAccessToken(), isNull);
    // 공유 저장소 자체는 건드리지 않는다 — 지우면 그사이 포그라운드가 새로
    // 발급한 토큰까지 함께 날아갈 수 있다.
    expect((await canvasTokens.read())?.token, '7~dead');
  });

  test('죽은 토큰의 401 이후, 같은 실행의 나머지 요청은 헤더 없이 나가고 '
      '다리를 다시 건너지 않는다', () async {
    final canvasTokens = InMemoryCanvasTokenStore();
    await canvasTokens.save(const StoredCanvasToken(
        token: '7~dead', id: 1, purpose: '금오LMS 앱 · Android · a3f9'));
    final source = LmsNotificationSource(
      InMemoryTokenStore(),
      canvasTokenStore: canvasTokens,
    );

    var bridgeCalls = 0;
    final script = _Script();
    final dio = Dio(BaseOptions(
      baseUrl: 'https://canvas.kumoh.ac.kr/api/v1',
      validateStatus: (s) => s != null && s < 500,
    ))
      ..httpClientAdapter = script;
    dio.interceptors.insert(
      0,
      canvasSessionInterceptor(
        dio: dio,
        accessToken: source.canvasAccessToken,
        reissueToken: source.retireCanvasToken,
        reBridge: () async => bridgeCalls++,
      ),
    );

    await dio.get<dynamic>('/users/self');
    await dio.get<dynamic>('/courses');

    expect(script.authHeaders, ['Bearer 7~dead', isNull, isNull]);
    expect(bridgeCalls, 1);
  });
}
