import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/announcements/data/announcements_api.dart';
import 'package:kumoh_lms/features/announcements/data/announcements_repository.dart';

import '../../fixtures/fixtures.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late Dio dio;
  late DioAdapter adapter;
  late AnnouncementsRepository repo;

  setUp(() {
    db = createTestDatabase();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    adapter = DioAdapter(dio: dio);
    repo = AnnouncementsRepository(api: AnnouncementsApi(dio), db: db);
  });
  tearDown(() => db.close());

  test('공지를 받아 캐시에 저장한다', () async {
    adapter.onGet('/dashboard/total/announcement',
        (s) => s.reply(200, announcementsJson),
        queryParameters: {'termId': 8});

    await repo.refresh(8);
    final rows = await repo.watch(8).first;

    expect(rows.length, 1);
    expect(rows.single.title, '2주차 실습 안내');
    expect(rows.single.courseId, 4831);
    expect(rows.single.contextName, '리눅스시스템프로그래밍-01');
    expect(rows.single.authorName, '윤현주');
    expect(rows.single.postedAt, DateTime.utc(2026, 9, 3, 1));
  });

  test('공지가 없으면 빈 목록이다', () async {
    adapter.onGet('/dashboard/total/announcement',
        (s) => s.reply(200, emptyAnnouncementsJson),
        queryParameters: {'termId': 8});

    await repo.refresh(8);

    expect(await repo.watch(8).first, isEmpty);
  });

  test('TTL 안에서는 네트워크를 다시 치지 않는다', () async {
    var calls = 0;
    // http_mock_adapter의 onGet 콜백은 등록 시점에 1회만 실행되고 실제 요청
    // 횟수와 무관하다. 진짜 네트워크 호출 수는 Dio 인터셉터로 센다.
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls++;
      handler.next(options);
    }));
    adapter.onGet('/dashboard/total/announcement', (s) => s.reply(200, announcementsJson), queryParameters: {'termId': 8});

    await repo.refresh(8);
    await repo.refresh(8);

    expect(calls, 1);
  });

  test('force면 다시 받아온다', () async {
    var calls = 0;
    // http_mock_adapter의 onGet 콜백은 등록 시점에 1회만 실행되고 실제 요청
    // 횟수와 무관하다. 진짜 네트워크 호출 수는 Dio 인터셉터로 센다.
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls++;
      handler.next(options);
    }));
    adapter.onGet('/dashboard/total/announcement', (s) => s.reply(200, announcementsJson), queryParameters: {'termId': 8});

    await repo.refresh(8);
    await repo.refresh(8, force: true);

    expect(calls, 2);
  });
}
