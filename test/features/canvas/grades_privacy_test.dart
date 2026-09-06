import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_api.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_cache.dart';
import 'package:kumoh_lms/features/canvas/presentation/tabs/content_tabs.dart';
import 'package:kumoh_lms/providers.dart';

import '../../helpers/test_db.dart';

/// 성적은 다른 탭과 달리 최신성이 아니라 프라이버시가 걸린다.
/// 기기를 잃어버렸을 때 로컬에 남아 있으면 안 되므로, 캐시에 절대 쓰지 않는다.
void main() {
  late AppDatabase db;
  late CanvasCache cache;
  late Dio dio;
  late DioAdapter adapter;
  late ProviderContainer container;

  const enrollmentsJson = [
    {
      'course_id': 4831,
      'type': 'StudentEnrollment',
      'grades': {'current_score': 85.5, 'current_grade': 'B+'},
    },
  ];

  setUp(() {
    db = createTestDatabase();
    cache = CanvasCache(db);
    dio = Dio(BaseOptions(baseUrl: 'https://canvas.kumoh.ac.kr/api/v1'));
    adapter = DioAdapter(dio: dio);
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      canvasApiProvider.overrideWithValue(CanvasApi(dio)),
    ]);
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  test('성적을 불러와도 캐시에 남기지 않는다', () async {
    adapter.onGet('/users/self/enrollments',
        (s) => s.reply(200, enrollmentsJson),
        queryParameters: {'per_page': 100, 'state[]': 'active'});

    final snap = await container.read(courseGradeProvider(4831).future);

    expect(snap.data!.currentScore, 85.5);
    expect(await cache.read('grade:4831'), isNull,
        reason: '분실한 기기에 성적이 남아 있으면 안 된다');
  });

  test('이전 빌드가 남긴 성적 캐시는 열 때 지운다', () async {
    // 캐시하던 시절의 잔여물이 디스크에 남아 있을 수 있다.
    await cache.write('grade:4831', [
      {'course_id': 4831, 'grades': {'current_score': 99}}
    ]);
    adapter.onGet('/users/self/enrollments',
        (s) => s.reply(200, enrollmentsJson),
        queryParameters: {'per_page': 100, 'state[]': 'active'});

    await container.read(courseGradeProvider(4831).future);

    expect(await cache.read('grade:4831'), isNull,
        reason: '남아 있던 성적도 정리해야 한다');
  });

  test('오프라인이면 캐시로 대신하지 않고 실패한다', () async {
    await cache.write('grade:4831', enrollmentsJson);
    adapter.onGet(
      '/users/self/enrollments',
      (s) => s.throws(
        0,
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/users/self/enrollments'),
          reason: 'offline',
        ),
      ),
      queryParameters: {'per_page': 100, 'state[]': 'active'},
    );

    await expectLater(
      container.read(courseGradeProvider(4831).future),
      throwsA(isA<NetworkFailure>()),
    );
    expect(await cache.read('grade:4831'), isNull,
        reason: '실패했더라도 남아 있던 성적은 지워야 한다');
  });

  test('다른 탭은 여전히 캐시한다', () async {
    // 성적만 예외라는 것을 분명히 한다.
    adapter.onGet('/courses/4831/modules', (s) => s.reply(200, [
          {'id': 1, 'name': '1주차', 'position': 1, 'items_count': 2}
        ]), queryParameters: {'per_page': 50});

    await container.read(courseModulesProvider(4831).future);

    expect(await cache.read('modules:4831'), isNotNull,
        reason: '오프라인 대비 캐시는 성적을 뺀 나머지에서 계속 동작해야 한다');
  });
}
