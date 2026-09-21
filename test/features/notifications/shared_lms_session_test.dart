import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/config/env.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/features/notifications/data/due_reminder_models.dart';
import 'package:kumoh_lms/features/notifications/data/lms_notification_source.dart';
import 'package:kumoh_lms/features/notifications/data/notification_models.dart';
import 'package:kumoh_lms/features/notifications/data/shared_lms_session.dart';

class CountingSource implements LmsSource {
  int logins = 0;
  int courseCalls = 0;
  bool closed = false;
  Failure? authFailure;

  @override
  Future<String> authenticate() async {
    logins++;
    if (authFailure != null) throw authFailure!;
    return 'student';
  }

  @override
  Future<List<WatchedCourse>> courses() async {
    courseCalls++;
    return const [WatchedCourse(1, '강좌')];
  }

  @override
  Future<List<WatchedItem>> items(int courseId, NoticeKind kind) async => const [];

  @override
  Future<List<DueAssignment>> dueAssignments(int courseId) async => const [];

  @override
  void close() => closed = true;
}

void main() {
  test('로그인과 강좌 목록은 한 번만 받는다', () async {
    final inner = CountingSource();
    final shared = SharedLmsSession(inner);
    expect(await shared.authenticate(), 'student');
    expect(await shared.authenticate(), 'student');
    await shared.courses();
    await shared.courses();
    expect(inner.logins, 1);
    expect(inner.courseCalls, 1);
  });

  test('로그인 실패도 한 번만 시도하고 같은 실패를 돌려준다', () async {
    final inner = CountingSource()..authFailure = const AuthFailure();
    final shared = SharedLmsSession(inner);
    await expectLater(shared.authenticate(), throwsA(isA<AuthFailure>()));
    await expectLater(shared.authenticate(), throwsA(isA<AuthFailure>()));
    expect(inner.logins, 1);
  });

  test('러너가 부르는 close는 무시하고 dispose에서 한 번 닫는다', () {
    final inner = CountingSource();
    final shared = SharedLmsSession(inner);
    shared.close();
    expect(inner.closed, isFalse);
    shared.dispose();
    expect(inner.closed, isTrue);
  });

  group('LmsNotificationSource 과제 목록', () {
    late Dio dio;
    late DioAdapter adapter;
    late int hits;
    late LmsNotificationSource source;

    setUp(() {
      dio = Dio();
      adapter = DioAdapter(dio: dio);
      hits = 0;
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        hits++;
        handler.next(options);
      }));
      source = LmsNotificationSource(InMemoryTokenStore(), canvasDio: dio);
      final url = Uri.parse('${Env.canvasApiBaseUrl}/courses/1/assignments')
          .replace(queryParameters: {'per_page': '100', 'include[]': 'submission'})
          .toString();
      adapter.onGet(
          url,
          (server) => server.reply(200, [
                {
                  'id': 7,
                  'name': '실습 과제',
                  'due_at': '2026-09-23T01:40:00Z',
                  'submission_types': ['online_upload'],
                  'submission': {'workflow_state': 'unsubmitted', 'submitted_at': null},
                },
              ]));
    });
    tearDown(() => dio.close(force: true));

    test('제출 상태를 함께 받아 마감 대상을 고른다', () async {
      final result = await source.dueAssignments(1);
      expect(result.single.id, '7');
      expect(result.single.name, '실습 과제');
    });

    test('새 과제 감지와 마감 알림이 같은 응답을 쓴다', () async {
      final items = await source.items(1, NoticeKind.assignment);
      final due = await source.dueAssignments(1);
      expect(items.single.id, '7');
      expect(due.single.id, '7');
      expect(hits, 1, reason: '한 실행 안에서 강좌마다 한 번만 요청한다');
    });
  });
}
