import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/error/failure.dart';
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

  test('snake_case 필드로 와도 동일하게 파싱한다', () async {
    // 서버가 필드 표기를 섞어 쓴다. camelCase 픽스처만으로는 파서의 절반이
    // 검증되지 않으므로 snake_case 판을 따로 확인한다.
    const snakeJson = {
      'code': '200',
      'message': 'Success',
      'data': {
        'announcements': [
          {
            'id': 992,
            'title': '3주차 휴강 안내',
            'message': '<p>휴강합니다.</p>',
            'posted_at': '2026-09-10T02:00:00Z',
            'context_code': 'course_5682',
            'context_name': '모두를위한아두이노-02',
            'html_url': 'https://canvas.kumoh.ac.kr/courses/5682/discussion_topics/992',
            'user_name': '신승혁',
          },
        ],
      },
    };

    adapter.onGet('/dashboard/total/announcement',
        (s) => s.reply(200, snakeJson),
        queryParameters: {'termId': 8});

    await repo.refresh(8);
    final row = (await repo.watch(8).first).single;

    expect(row.id, '992');
    expect(row.title, '3주차 휴강 안내');
    expect(row.courseId, 5682);
    expect(row.contextName, '모두를위한아두이노-02');
    expect(row.authorName, '신승혁');
    expect(row.htmlUrl,
        'https://canvas.kumoh.ac.kr/courses/5682/discussion_topics/992');
    expect(row.postedAt, DateTime.utc(2026, 9, 10, 2));
  });

  test('네트워크가 실패해도 기존 캐시는 남는다', () async {
    adapter.onGet('/dashboard/total/announcement',
        (s) => s.reply(200, announcementsJson),
        queryParameters: {'termId': 8});
    await repo.refresh(8);
    expect((await repo.watch(8).first).length, 1);

    adapter.onGet('/dashboard/total/announcement',
        (s) => s.reply(401, springAuthErrorJson),
        queryParameters: {'termId': 8});

    await expectLater(repo.refresh(8, force: true), throwsA(isA<Failure>()));
    expect((await repo.watch(8).first).length, 1,
        reason: '실패한 새로고침이 캐시를 지우면 안 된다');
  });

  test('서버에서 사라진 공지는 새로고침 후 캐시에서도 없어진다', () async {
    adapter.onGet('/dashboard/total/announcement',
        (s) => s.reply(200, announcementsJson),
        queryParameters: {'termId': 8});
    await repo.refresh(8);
    expect((await repo.watch(8).first).length, 1);

    adapter.onGet('/dashboard/total/announcement',
        (s) => s.reply(200, emptyAnnouncementsJson),
        queryParameters: {'termId': 8});
    await repo.refresh(8, force: true);

    expect(await repo.watch(8).first, isEmpty);
  });
}
