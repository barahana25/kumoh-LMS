import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_store.dart';
import 'package:kumoh_lms/features/notifications/data/lms_notification_source.dart';
import 'package:kumoh_lms/core/network/token_store.dart';

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
}
