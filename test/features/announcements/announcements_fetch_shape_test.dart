import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/announcements/data/announcements_api.dart';
import 'package:kumoh_lms/features/announcements/data/announcements_repository.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_api.dart';

import '../../helpers/test_db.dart';

/// 공지 새로고침이 서버를 치는 '모양'을 고정한다.
/// 느린 새로고침의 원인이 왕복 횟수와 직렬화였으므로, 응답 내용이 아니라
/// 요청 수·생략·동시성을 검사한다.
void main() {
  late AppDatabase db;
  late Dio dio;
  late AnnouncementsRepository repo;

  /// 실제로 나간 요청. 경로와 질의를 그대로 담는다.
  late List<RequestOptions> sent;

  /// 동시에 떠 있던 서로 다른 강좌 수의 최댓값.
  late int peakCourses;

  /// 토론 글이 있는 강좌. 나머지는 토론 목록이 비어 있다.
  late Set<int> coursesWithDiscussion;

  int? courseIdOf(String path) {
    final m = RegExp(r'/courses/(\d+)/').firstMatch(path);
    return m == null ? null : int.parse(m.group(1)!);
  }

  setUp(() async {
    db = createTestDatabase();
    sent = [];
    peakCourses = 0;
    coursesWithDiscussion = {101, 102, 103, 104, 105, 106, 107, 108};
    final inFlight = <int>[];

    dio = Dio(BaseOptions(baseUrl: 'https://canvas.kumoh.ac.kr/api/v1'));
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      sent.add(options);
      final courseId = courseIdOf(options.path);
      if (courseId != null) {
        inFlight.add(courseId);
        final distinct = inFlight.toSet().length;
        if (distinct > peakCourses) peakCourses = distinct;
      }
      // 응답을 늦춰야 동시성이 보인다. 즉시 돌려주면 전부 차례로 보인다.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (courseId != null) inFlight.remove(courseId);

      final path = options.path;
      final Object data;
      if (path.endsWith('/enrollments')) {
        data = [
          {
            'type': 'TeacherEnrollment',
            'user_id': 900,
            'user': {'id': 900, 'name': '김교수'},
          },
        ];
      } else if (path.endsWith('/discussion_topics')) {
        final onlyAnnouncements =
            options.queryParameters['only_announcements'] == true;
        if (!onlyAnnouncements && coursesWithDiscussion.contains(courseId)) {
          data = [
            {
              'id': 900 + courseId!,
              'title': '토론',
              'user_id': 900,
              'created_at': '2026-09-10T00:00:00Z',
            },
          ];
        } else {
          data = const [];
        }
      } else {
        data = const [];
      }
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: data,
      ));
    }));

    repo = AnnouncementsRepository(
      api: AnnouncementsApi(dio),
      canvas: CanvasApi(dio),
      db: db,
    );
    await db.coursesDao.upsertAll([
      for (var i = 101; i <= 108; i++)
        CoursesCompanion.insert(
          id: Value(i),
          termId: 8,
          name: '강좌 $i',
          courseCode: 'C$i',
        ),
    ]);
  });
  tearDown(() async {
    dio.close(force: true);
    await db.close();
  });

  List<RequestOptions> enrollmentCalls() =>
      sent.where((r) => r.path.endsWith('/enrollments')).toList();

  test('수강 목록은 강좌당 한 번만, 두 역할을 함께 묻는다', () async {
    await repo.refresh(8, force: true);

    final calls = enrollmentCalls();
    expect(calls.length, 8, reason: '강좌마다 한 번이어야 한다');
    expect(
      calls.first.queryParameters['type[]'],
      containsAll(<String>['TeacherEnrollment', 'TaEnrollment']),
      reason: '역할마다 따로 묻지 않고 한 요청에 담아야 한다',
    );
  });

  test('토론 글이 없는 강좌는 수강 목록을 아예 묻지 않는다', () async {
    coursesWithDiscussion = {101, 102};

    await repo.refresh(8, force: true);

    expect(
      enrollmentCalls().map((r) => courseIdOf(r.path)).toSet(),
      {101, 102},
      reason: '거를 토론 글이 없으면 강의자를 조회할 이유가 없다',
    );
  });

  test('두 번째 새로고침은 수강 목록을 다시 묻지 않는다', () async {
    await repo.refresh(8, force: true);
    expect(enrollmentCalls().length, 8);

    sent.clear();
    await repo.refresh(8, force: true);

    expect(enrollmentCalls(), isEmpty,
        reason: '강의자는 학기 중 바뀌지 않으므로 기억해 둔 값을 쓴다');
  });

  test('강좌를 동시에 받되 한꺼번에 몰지는 않는다', () async {
    await repo.refresh(8, force: true);

    expect(peakCourses, greaterThan(1), reason: '강좌를 하나씩 기다리면 안 된다');
    expect(peakCourses, lessThanOrEqualTo(4),
        reason: '학교 서버에 8개 강좌를 한꺼번에 몰면 안 된다');
  });
}
