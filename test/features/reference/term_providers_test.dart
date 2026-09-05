import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/reference/data/reference_api.dart';
import 'package:kumoh_lms/features/reference/data/reference_repository.dart';
import 'package:kumoh_lms/features/reference/presentation/term_providers.dart';
import 'package:kumoh_lms/providers.dart';

import '../../fixtures/fixtures.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late Dio dio;
  late DioAdapter adapter;
  late ProviderContainer container;

  setUp(() {
    db = createTestDatabase();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    adapter = DioAdapter(dio: dio);
    container = ProviderContainer(overrides: [
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      appDatabaseProvider.overrideWithValue(db),
      referenceRepositoryProvider.overrideWithValue(
        ReferenceRepository(api: ReferenceApi(dio), db: db),
      ),
    ]);
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  test('termsProvider는 캐시된 학기를 흘려보낸다', () async {
    adapter.onGet('/terms', (s) => s.reply(200, termsJson),
        queryParameters: {'accountId': 1});
    await container.read(referenceRepositoryProvider).refreshTerms();

    final rows = await container.read(termsProvider.future);

    expect(rows.map((t) => t.id), [8, 6]);
  });

  test('activeTermIdProvider는 선택 학기가 없으면 현재 학기를 고른다', () async {
    adapter.onGet('/terms', (s) => s.reply(200, termsJson),
        queryParameters: {'accountId': 1});
    await container.read(referenceRepositoryProvider).refreshTerms();

    final id = await container.read(activeTermIdProvider.future);

    expect(id, 8);
  });

  test('선택 학기가 지정되면 그것을 그대로 쓴다', () async {
    container.read(selectedTermIdProvider.notifier).state = 6;

    final id = await container.read(activeTermIdProvider.future);

    expect(id, 6);
  });

  test('네트워크가 실패해도 캐시된 학기를 돌려준다 (오프라인)', () async {
    // 캐시에는 학기가 있지만 CacheMeta가 없어 TTL상 "새로고침 필요" 상태다.
    // 이때 네트워크가 실패해도 캐시된 학기가 나와야 한다. 예외가 새면
    // 강좌·과제·공지 세 화면이 전부 에러 화면이 된다.
    await db.termsDao.upsertAll([
      TermsCompanion.insert(
        id: const Value(8),
        name: '2026-2학기',
        startAt: Value(DateTime.utc(2026, 9, 1)),
        endAt: Value(DateTime.utc(2026, 12, 22)),
      ),
    ]);
    adapter.onGet('/terms', (s) => s.reply(500, springAuthErrorJson),
        queryParameters: {'accountId': 1});

    final id = await container
        .read(activeTermIdProvider.future)
        .timeout(const Duration(seconds: 5));

    expect(id, 8, reason: '오프라인이어도 캐시된 현재 학기가 나와야 한다');
  });
}
