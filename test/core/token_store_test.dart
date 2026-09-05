import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/network/token_store.dart';

void main() {
  late InMemoryTokenStore store;

  setUp(() => store = InMemoryTokenStore());

  test('초기 상태에서는 토큰이 없다', () async {
    expect(await store.readAccessToken(), isNull);
    expect(await store.readRefreshToken(), isNull);
  });

  test('저장한 토큰을 그대로 읽는다', () async {
    await store.saveTokens(accessToken: 'AAA', refreshToken: 'RRR');
    expect(await store.readAccessToken(), 'AAA');
    expect(await store.readRefreshToken(), 'RRR');
  });

  test('clearTokens는 토큰만 지우고 자격증명은 남긴다', () async {
    await store.saveTokens(accessToken: 'AAA', refreshToken: 'RRR');
    await store.saveCredentials(userId: '20250000', password: 'pw');
    await store.clearTokens();
    expect(await store.readAccessToken(), isNull);
    expect((await store.readCredentials())?.userId, '20250000');
  });

  test('clearAll은 토큰과 자격증명을 모두 지운다', () async {
    await store.saveTokens(accessToken: 'AAA', refreshToken: 'RRR');
    await store.saveCredentials(userId: '20250000', password: 'pw');
    await store.clearAll();
    expect(await store.readAccessToken(), isNull);
    expect(await store.readCredentials(), isNull);
  });

  test('ensureDbKey는 최초에 키를 만들고 이후 같은 키를 돌려준다', () async {
    final first = await store.ensureDbKey();
    final second = await store.ensureDbKey();
    expect(first, isNotEmpty);
    expect(first.length, greaterThanOrEqualTo(32));
    expect(second, first);
  });

  test('자격증명을 저장하지 않으면 null이다', () async {
    expect(await store.readCredentials(), isNull);
  });
}
