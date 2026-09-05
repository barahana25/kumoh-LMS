import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/reference/data/reference_api.dart';
import 'package:kumoh_lms/features/reference/data/reference_repository.dart';

import '../../fixtures/fixtures.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late Dio dio;
  late DioAdapter adapter;
  late ReferenceRepository repo;

  setUp(() {
    db = createTestDatabase();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    adapter = DioAdapter(dio: dio);
    repo = ReferenceRepository(api: ReferenceApi(dio), db: db);
  });
  tearDown(() => db.close());

  test('refreshTerms는 학기를 받아 캐시에 저장한다', () async {
    adapter.onGet('/terms', (s) => s.reply(200, termsJson),
        queryParameters: {'accountId': 1});

    await repo.refreshTerms();

    final rows = await repo.watchTerms().first;
    expect(rows.map((t) => t.id), [8, 6]);
    expect(rows.first.name, '2026-2학기');
  });

  test('TTL 안에서는 두 번째 호출이 네트워크를 치지 않는다', () async {
    // http_mock_adapter의 onGet 콜백은 등록 시점에 1회만 실행되고 이후
    // 실제 요청 횟수와는 무관하다(라이브러리로 확인). 실제 네트워크 호출
    // 횟수를 재려면 Dio 인터셉터로 나가는 요청 자체를 센다.
    var calls = 0;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls++;
      handler.next(options);
    }));
    adapter.onGet('/terms', (s) => s.reply(200, termsJson),
        queryParameters: {'accountId': 1});

    await repo.refreshTerms();
    await repo.refreshTerms();

    expect(calls, 1);
  });

  test('force가 true면 TTL을 무시하고 다시 받아온다', () async {
    var calls = 0;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls++;
      handler.next(options);
    }));
    adapter.onGet('/terms', (s) => s.reply(200, termsJson),
        queryParameters: {'accountId': 1});

    await repo.refreshTerms();
    await repo.refreshTerms(force: true);

    expect(calls, 2);
  });

  test('currentTermId는 오늘 날짜를 포함하는 학기를 고른다', () async {
    adapter.onGet('/terms', (s) => s.reply(200, termsJson),
        queryParameters: {'accountId': 1});
    await repo.refreshTerms();

    // 픽스처의 2026-2학기는 2026-09-01 ~ 2026-12-22
    final id = await repo.currentTermId(now: DateTime.utc(2026, 9, 5));
    expect(id, 8);
  });

  test('현재 날짜에 맞는 학기가 없으면 가장 최근 학기를 고른다', () async {
    adapter.onGet('/terms', (s) => s.reply(200, termsJson),
        queryParameters: {'accountId': 1});
    await repo.refreshTerms();

    final id = await repo.currentTermId(now: DateTime.utc(2030, 1, 1));
    expect(id, 8, reason: 'id가 가장 큰 학기로 폴백');
  });

  test('캐시가 비어 있으면 currentTermId는 null이다', () async {
    expect(await repo.currentTermId(), isNull);
  });
}
