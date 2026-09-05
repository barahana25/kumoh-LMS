import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_api.dart';


/// 같은 경로에 대해 정해진 순서로 응답한다.
/// http_mock_adapter는 같은 경로를 두 번 등록하면 마지막 것만 매칭하므로
/// "먼저 401, 다음 200" 같은 시퀀스를 표현할 수 없다.
class _Sequence implements HttpClientAdapter {
  _Sequence(this.statuses, this.body);
  final List<int> statuses;
  final Object body;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? s,
      Future<void>? c) async {
    calls++;
    final status = statuses.isEmpty
        ? 200
        : statuses[calls - 1 < statuses.length ? calls - 1 : statuses.length - 1];
    return ResponseBody.fromString(
      status == 200 ? jsonEncode(body) : '{"status":"unauthenticated"}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late CanvasApi api;
  late int bridges;

  setUp(() {
    bridges = 0;
    dio = Dio(BaseOptions(baseUrl: 'https://canvas.kumoh.ac.kr/api/v1'));
    adapter = DioAdapter(dio: dio);
    api = CanvasApi(dio);
  });

  group('탭 목록', () {
    test('네이티브로 그릴 수 있는 탭만 순서대로 돌려준다', () async {
      adapter.onGet('/courses/4831/tabs', (s) => s.reply(200, [
            {'id': 'home', 'label': '홈', 'position': 1, 'type': 'internal'},
            {'id': 'assignments', 'label': '과제', 'position': 2, 'type': 'internal'},
            {'id': 'syllabus', 'label': '강의 계획', 'position': 3, 'type': 'internal'},
            {
              'id': 'context_external_tool_7',
              'label': '콘텐츠제작',
              'position': 4,
              'type': 'external',
              'url': 'https://canvas.kumoh.ac.kr/courses/4831/external_tools/7',
            },
          ]));

      final tabs = await api.fetchTabs(4831);

      expect(tabs.map((t) => t.id), ['home', 'assignments', 'syllabus']);
      expect(tabs.first.label, '홈');
    });

    test('숨김 처리된 탭은 제외한다', () async {
      adapter.onGet('/courses/4831/tabs', (s) => s.reply(200, [
            {'id': 'home', 'label': '홈', 'position': 1},
            {'id': 'grades', 'label': '성적', 'position': 2, 'hidden': true},
          ]));

      final tabs = await api.fetchTabs(4831);

      expect(tabs.map((t) => t.id), ['home'],
          reason: '교수가 숨긴 탭을 학생에게 보여주면 안 된다');
    });

    test('position 순서를 지킨다', () async {
      adapter.onGet('/courses/4831/tabs', (s) => s.reply(200, [
            {'id': 'syllabus', 'label': '강의 계획', 'position': 3},
            {'id': 'home', 'label': '홈', 'position': 1},
            {'id': 'assignments', 'label': '과제', 'position': 2},
          ]));

      final tabs = await api.fetchTabs(4831);

      expect(tabs.map((t) => t.id), ['home', 'assignments', 'syllabus']);
    });
  });

  group('세션 만료', () {
    test('401이면 재브릿지 후 원요청을 재시도한다', () async {
      final seq = _Sequence([401, 200], [
        {'id': 'home', 'label': '홈', 'position': 1},
      ]);
      dio.httpClientAdapter = seq;
      dio.interceptors.add(canvasSessionInterceptor(
        dio: dio,
        reBridge: () async => bridges++,
      ));

      final tabs = await api.fetchTabs(4831);

      expect(bridges, 1, reason: '세션이 끊기면 다시 다리를 건너야 한다');
      expect(tabs.single.id, 'home');
      expect(seq.calls, 2, reason: '원요청이 재시도되어야 한다');
    });

    test('재시도한 요청이 또 401이면 무한 반복하지 않는다', () async {
      final seq = _Sequence([401, 401, 401], const <Object>[]);
      dio.httpClientAdapter = seq;
      dio.interceptors.add(canvasSessionInterceptor(
        dio: dio,
        reBridge: () async => bridges++,
      ));

      await expectLater(api.fetchTabs(4831), throwsA(isA<Failure>()));
      expect(bridges, 1, reason: '재브릿지는 한 번만 시도해야 한다');
      expect(seq.calls, 2, reason: '원요청 + 재시도 1회로 끝나야 한다');
    });
  });

  test('본문이 배열이 아니면 ParseFailure', () async {
    adapter.onGet('/courses/4831/tabs', (s) => s.reply(200, {'oops': true}));
    await expectLater(api.fetchTabs(4831), throwsA(isA<ParseFailure>()));
  });

  test('연결 실패는 NetworkFailure', () async {
    adapter.onGet(
      '/courses/4831/tabs',
      (s) => s.throws(
        0,
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/courses/4831/tabs'),
          reason: 'offline',
        ),
      ),
    );
    await expectLater(api.fetchTabs(4831), throwsA(isA<NetworkFailure>()));
  });

  test('CookieJar는 세션 쿠키를 canvas 호스트에 보관한다', () async {
    final jar = CookieJar();
    await jar.saveFromResponse(Uri.parse('https://canvas.kumoh.ac.kr'), [
      Cookie('_normandy_session', 'abc'),
    ]);
    final cookies =
        await jar.loadForRequest(Uri.parse('https://canvas.kumoh.ac.kr/api/v1/courses'));
    expect(cookies.map((c) => c.name), contains('_normandy_session'));
  });
}
