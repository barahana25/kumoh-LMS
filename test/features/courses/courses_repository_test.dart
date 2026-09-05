import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/courses/data/courses_api.dart';
import 'package:kumoh_lms/features/courses/data/courses_repository.dart';

import '../../fixtures/fixtures.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late Dio dio;
  late DioAdapter adapter;
  late CoursesRepository repo;

  const query = {'isMyCourse': 'true', 'accountId': 1, 'termId': 8};

  setUp(() {
    db = createTestDatabase();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    adapter = DioAdapter(dio: dio);
    repo = CoursesRepository(api: CoursesApi(dio), db: db);
  });
  tearDown(() => db.close());

  test('강좌를 받아 캐시에 저장하고 스트림으로 내보낸다', () async {
    adapter.onGet('/courses', (s) => s.reply(200, coursesJson),
        queryParameters: query);

    await repo.refresh(8);
    final rows = await repo.watch(8).first;

    expect(rows.length, 2);
    final linux = rows.firstWhere((c) => c.id == 4831);
    expect(linux.name, '리눅스시스템프로그래밍-01');
    expect(linux.courseCode, '리눅스시스템프로그래밍-GA2015-01');
    expect(linux.institution, '인공지능공학전공');
    expect(linux.totalStudents, 28);
    expect(linux.termId, 8);
  });

  test('교수 이름 배열을 표시용 문자열로 평탄화한다', () async {
    adapter.onGet('/courses', (s) => s.reply(200, coursesJson),
        queryParameters: query);

    await repo.refresh(8);
    final rows = await repo.watch(8).first;

    expect(rows.firstWhere((c) => c.id == 4831).teacherNames, '[컴퓨터공학부] 윤현주');
  });

  test('TTL 안에서는 네트워크를 다시 치지 않는다', () async {
    var calls = 0;
    // http_mock_adapter의 onGet 콜백은 등록 시점에 1회만 실행되고 실제 요청
    // 횟수와 무관하다. 진짜 네트워크 호출 수는 Dio 인터셉터로 센다.
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls++;
      handler.next(options);
    }));
    adapter.onGet('/courses', (s) => s.reply(200, coursesJson), queryParameters: query);

    await repo.refresh(8);
    await repo.refresh(8);

    expect(calls, 1);
  });

  test('수강 취소된 강좌는 새로고침 후 캐시에서 사라진다', () async {
    adapter.onGet('/courses', (s) => s.reply(200, coursesJson),
        queryParameters: query);
    await repo.refresh(8);
    expect((await repo.watch(8).first).length, 2);

    // 두 번째 응답에는 강좌가 하나만 남아 있다.
    // 공유 const 픽스처를 변형하지 않도록 별도 리터럴로 만든다.
    const shrunk = {
      'code': '200',
      'message': 'Success',
      'data': {
        'courses': [
          {
            'id': 4831,
            'name': '리눅스시스템프로그래밍-01',
            'courseCode': '리눅스시스템프로그래밍-GA2015-01',
            'totalStudents': 28,
            'teachers': <Map<String, dynamic>>[],
            'institution': '인공지능공학전공',
            'enrollmentTermId': 8,
            'workflowState': 'available',
            'courseFormat': 'ONLINE',
          },
        ],
      },
    };

    adapter.onGet('/courses', (s) => s.reply(200, shrunk), queryParameters: query);
    await repo.refresh(8, force: true);

    final rows = await repo.watch(8).first;
    expect(rows.length, 1);
    expect(rows.single.id, 4831);
  });

  test('네트워크가 실패해도 기존 캐시는 남는다', () async {
    adapter.onGet('/courses', (s) => s.reply(200, coursesJson),
        queryParameters: query);
    await repo.refresh(8);

    adapter.onGet('/courses', (s) => s.reply(401, springAuthErrorJson),
        queryParameters: query);

    await expectLater(repo.refresh(8, force: true), throwsA(isA<AuthFailure>()));
    expect((await repo.watch(8).first).length, 2, reason: '캐시는 유지돼야 한다');
  });
}
