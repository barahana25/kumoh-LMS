import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InMemoryCanvasTokenStore', () {
    test('저장한 토큰을 그대로 읽고 지운다', () async {
      final store = InMemoryCanvasTokenStore();
      expect(await store.read(), isNull);

      await store.save(const StoredCanvasToken(
          token: '7~abc', id: 44, purpose: '금오LMS 앱 · Android · a3f9'));
      final read = await store.read();
      expect(read!.token, '7~abc');
      expect(read.id, 44);
      expect(read.purpose, '금오LMS 앱 · Android · a3f9');

      await store.clear();
      expect(await store.read(), isNull);
    });

    test('ensurePurpose는 처음에 만들고 이후 같은 값을 돌려준다', () async {
      final store = InMemoryCanvasTokenStore();
      final first = await store.ensurePurpose('Android');
      final second = await store.ensurePurpose('Android');

      expect(first, startsWith('금오LMS 앱 · Android · '));
      expect(second, first);
    });

    test('토큰을 지워도 기기 이름은 남는다', () async {
      final store = InMemoryCanvasTokenStore();
      final purpose = await store.ensurePurpose('Android');
      await store.save(StoredCanvasToken(token: 't', id: 1, purpose: purpose));
      await store.clear();

      expect(await store.ensurePurpose('Android'), purpose);
    });
  });

  group('SecureCanvasTokenStore', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('보안 저장소에 왕복 저장한다', () async {
      final store = SecureCanvasTokenStore();
      await store.save(const StoredCanvasToken(
          token: '7~abc', id: 44, purpose: '금오LMS 앱 · Android · a3f9'));

      final read = await store.read();
      expect(read!.token, '7~abc');
      expect(read.id, 44);
    });

    test('일부만 남아 있으면 없는 것으로 본다', () async {
      FlutterSecureStorage.setMockInitialValues({'canvas_pat_token': '7~abc'});
      expect(await SecureCanvasTokenStore().read(), isNull);
    });
  });

  test('buildCanvasTokenPurpose는 사람이 알아볼 형식을 만든다', () {
    expect(
      buildCanvasTokenPurpose(platformLabel: 'Android', suffix: 'a3f9'),
      '금오LMS 앱 · Android · a3f9',
    );
  });
}
