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

  // 실제 서버 응답에서 뽑은 형태
  const assignmentsJson = [
    {
      'id': 7931,
      'name': '[토의 과제] 리눅스 상식',
      'due_at': '2026-09-02T14:59:00Z',
      'points_possible': 20,
      'html_url': 'https://canvas.kumoh.ac.kr/courses/4831/assignments/7931',
      'submission_types': ['online_text_entry', 'online_upload'],
      'published': true,
    },
    {
      'id': 8000,
      'name': '기한 없는 과제',
      'due_at': null,
      'points_possible': null,
      'html_url': 'https://canvas.kumoh.ac.kr/courses/4831/assignments/8000',
      'submission_types': ['none'],
      'published': true,
    },
  ];

  test('과제를 파싱한다', () async {
    adapter.onGet('/courses/4831/assignments',
        (s) => s.reply(200, assignmentsJson),
        queryParameters: {'per_page': 50, 'order_by': 'due_at'});

    final items = await api.fetchAssignments(4831);

    expect(items.length, 2);
    final first = items.first;
    expect(first.id, 7931);
    expect(first.name, '[토의 과제] 리눅스 상식');
    expect(first.dueAt, DateTime.utc(2026, 9, 2, 14, 59));
    expect(first.pointsPossible, 20);
    expect(first.htmlUrl, contains('/assignments/7931'));
  });

  test('마감일과 배점이 없어도 안전하게 파싱한다', () async {
    adapter.onGet('/courses/4831/assignments',
        (s) => s.reply(200, assignmentsJson),
        queryParameters: {'per_page': 50, 'order_by': 'due_at'});

    final items = await api.fetchAssignments(4831);

    expect(items.last.dueAt, isNull);
    expect(items.last.pointsPossible, isNull);
  });

  test('게시되지 않은 과제는 제외한다', () async {
    adapter.onGet('/courses/4831/assignments', (s) => s.reply(200, [
          {'id': 1, 'name': '공개', 'published': true},
          {'id': 2, 'name': '미공개 초안', 'published': false},
        ]), queryParameters: {'per_page': 50, 'order_by': 'due_at'});

    final items = await api.fetchAssignments(4831);

    expect(items.map((a) => a.id), [1],
        reason: '교수가 아직 공개하지 않은 과제를 학생에게 보여주면 안 된다');
  });

  test('제출 상태를 과제별로 묶어 돌려준다', () async {
    adapter.onGet('/courses/4831/students/submissions', (s) => s.reply(200, [
          {
            'assignment_id': 7931,
            'workflow_state': 'submitted',
            'score': null,
            'submitted_at': '2026-09-02T06:24:49Z',
            'late': false,
            'missing': false,
          },
          {
            'assignment_id': 8000,
            'workflow_state': 'unsubmitted',
            'score': null,
            'late': false,
            'missing': true,
          },
        ]), queryParameters: {'per_page': 50, 'student_ids[]': 'self'});

    final byId = await api.fetchSubmissions(4831);

    expect(byId[7931]!.submitted, isTrue);
    expect(byId[7931]!.submittedAt, DateTime.utc(2026, 9, 2, 6, 24, 49));
    expect(byId[8000]!.submitted, isFalse);
    expect(byId[8000]!.missing, isTrue);
  });

  test('연결 실패는 NetworkFailure', () async {
    adapter.onGet(
      '/courses/4831/assignments',
      (s) => s.throws(
        0,
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/courses/4831/assignments'),
          reason: 'offline',
        ),
      ),
      queryParameters: {'per_page': 50, 'order_by': 'due_at'},
    );

    await expectLater(api.fetchAssignments(4831), throwsA(isA<NetworkFailure>()));
  });
}
