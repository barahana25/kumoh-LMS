import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/network/token_store.dart';

void main() {
  test('웹 저장소는 비밀번호를 저장하지 않고 토큰은 유지한다', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final store = WebTokenStore();

    await store.saveCredentials(userId: '20250001', password: 'secret');
    await store.saveTokens(accessToken: 'a', refreshToken: 'r');

    expect(await store.readCredentials(), isNull);
    expect(await const FlutterSecureStorage().read(key: 'cred_password'), isNull);
    expect(await store.readAccessToken(), 'a');
    expect(await store.readRefreshToken(), 'r');
  });
}
