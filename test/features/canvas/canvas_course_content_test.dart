import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_api.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late CanvasApi api;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://canvas.kumoh.ac.kr/api/v1'));
    adapter = DioAdapter(dio: dio);
    api = CanvasApi(dio);
  });

  group('강의 계획', () {
    test('syllabus_body를 돌려준다', () async {
      adapter.onGet('/courses/4831', (s) => s.reply(200, {
            'id': 4831,
            'name': '리눅스시스템프로그래밍-01',
            'syllabus_body': '<p>주차별 계획</p>',
          }), queryParameters: {'include[]': 'syllabus_body'});

      expect(await api.fetchSyllabus(4831), '<p>주차별 계획</p>');
    });

    test('강의 계획이 비어 있으면 null', () async {
      adapter.onGet('/courses/4831', (s) => s.reply(200, {'id': 4831}),
          queryParameters: {'include[]': 'syllabus_body'});

      expect(await api.fetchSyllabus(4831), isNull);
    });
  });

  group('강의실(모듈)', () {
    test('모듈을 position 순서로 파싱한다', () async {
      adapter.onGet('/courses/4831/modules', (s) => s.reply(200, [
            {'id': 2, 'name': '2주차', 'position': 2, 'items_count': 1, 'state': 'locked'},
            {'id': 1, 'name': '1주차', 'position': 1, 'items_count': 3, 'state': 'completed'},
          ]), queryParameters: {'per_page': 50});

      final mods = await api.fetchModules(4831);

      expect(mods.map((m) => m.name), ['1주차', '2주차']);
      expect(mods.first.itemsCount, 3);
      expect(mods.first.completed, isTrue);
      expect(mods.last.locked, isTrue);
    });
  });

  group('강의자료실', () {
    test('파일 이름·크기·유형을 파싱한다', () async {
      adapter.onGet('/courses/4831/files', (s) => s.reply(200, [
            {
              'id': 275034,
              'display_name': '00_Introduction2026.pdf',
              'content-type': 'application/pdf',
              'size': 155840,
              'url': 'https://canvas.kumoh.ac.kr/files/275034/download',
              'locked_for_user': false,
            },
          ]), queryParameters: {'per_page': 50, 'sort': 'created_at', 'order': 'desc'});

      final files = await api.fetchFiles(4831);

      expect(files.single.displayName, '00_Introduction2026.pdf');
      expect(files.single.sizeBytes, 155840);
      expect(files.single.contentType, 'application/pdf');
      expect(files.single.locked, isFalse);
    });

    test('잠긴 파일도 목록에는 두되 잠금 상태를 표시한다', () async {
      adapter.onGet('/courses/4831/files', (s) => s.reply(200, [
            {'id': 1, 'display_name': '기말.pdf', 'locked_for_user': true},
          ]), queryParameters: {'per_page': 50, 'sort': 'created_at', 'order': 'desc'});

      expect((await api.fetchFiles(4831)).single.locked, isTrue);
    });
  });

  group('사용자 및 그룹', () {
    test('수강생과 교수를 역할과 함께 파싱한다', () async {
      adapter.onGet('/courses/4831/enrollments', (s) => s.reply(200, [
            {
              'type': 'TeacherEnrollment',
              'user': {'id': 1, 'name': '홍교수', 'sortable_name': '홍교수'},
            },
            {
              'type': 'StudentEnrollment',
              'user': {'id': 2, 'name': '김학생', 'sortable_name': '김학생'},
            },
          ]), queryParameters: {'per_page': 100});

      final people = await api.fetchPeople(4831);

      expect(people.length, 2);
      expect(people.first.name, '홍교수');
      expect(people.first.isTeacher, isTrue);
      expect(people.last.isTeacher, isFalse);
    });

    test('그룹을 파싱한다', () async {
      adapter.onGet('/courses/4831/groups', (s) => s.reply(200, [
            {'id': 870, 'name': '1조', 'members_count': 2},
          ]), queryParameters: {'per_page': 50});

      final groups = await api.fetchGroups(4831);
      expect(groups.single.name, '1조');
      expect(groups.single.membersCount, 2);
    });
  });

  group('성적', () {
    test('이 강좌의 내 성적만 골라낸다', () async {
      adapter.onGet('/users/self/enrollments', (s) => s.reply(200, [
            {
              'course_id': 4830,
              'type': 'StudentEnrollment',
              'grades': {'current_score': 90, 'current_grade': 'A'},
            },
            {
              'course_id': 4831,
              'type': 'StudentEnrollment',
              'grades': {'current_score': 85.5, 'current_grade': 'B+', 'final_score': 80},
            },
          ]), queryParameters: {'per_page': 100, 'state[]': 'active'});

      final grade = await api.fetchMyGrade(4831);

      expect(grade, isNotNull);
      expect(grade!.currentScore, 85.5);
      expect(grade.currentGrade, 'B+');
      expect(grade.finalScore, 80);
    });

    test('해당 강좌 수강 정보가 없으면 null', () async {
      adapter.onGet('/users/self/enrollments', (s) => s.reply(200, []),
          queryParameters: {'per_page': 100, 'state[]': 'active'});

      expect(await api.fetchMyGrade(4831), isNull);
    });
  });

  group('토론', () {
    test('공지는 제외하고 토론만 돌려준다', () async {
      adapter.onGet('/courses/4831/discussion_topics', (s) => s.reply(200, [
            {
              'id': 10,
              'title': '자유 토론',
              'posted_at': '2026-09-02T06:00:00Z',
              'discussion_subentry_count': 4,
              'html_url': 'https://canvas.kumoh.ac.kr/courses/4831/discussion_topics/10',
            },
          ]), queryParameters: {'per_page': 50});

      final items = await api.fetchDiscussions(4831);

      expect(items.single.title, '자유 토론');
      expect(items.single.replyCount, 4);
      expect(items.single.postedAt, DateTime.utc(2026, 9, 2, 6));
    });
  });

  test('연결 실패는 NetworkFailure', () async {
    adapter.onGet(
      '/courses/4831/modules',
      (s) => s.throws(
        0,
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/courses/4831/modules'),
          reason: 'offline',
        ),
      ),
      queryParameters: {'per_page': 50},
    );

    await expectLater(api.fetchModules(4831), throwsA(isA<NetworkFailure>()));
  });
}
