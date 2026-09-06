import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_api.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_cache.dart';
import 'package:kumoh_lms/features/canvas/presentation/tabs/module_items_screen.dart';

Stream<CanvasSnapshot<T>> fresh<T>(T data) =>
    Stream.value(CanvasSnapshot<T>(data: data, stale: false));

void main() {
  // 실제 서버 응답에서 뽑은 형태
  const itemsJson = [
    {
      'id': 24868,
      'title': '00_Introduction2026.pdf',
      'type': 'File',
      'indent': 0,
      'html_url': 'https://canvas.kumoh.ac.kr/courses/4831/modules/items/24868',
      'content_id': 275034,
    },
    {
      'id': 25304,
      'title': '[토의 과제] 리눅스 상식',
      'type': 'Assignment',
      'indent': 0,
      'html_url': 'https://canvas.kumoh.ac.kr/courses/4831/modules/items/25304',
      'content_id': 7931,
    },
    {
      'id': 999,
      'title': '읽을 자료',
      'type': 'SubHeader',
      'indent': 0,
    },
  ];

  group('모듈 항목 파싱', () {
    late Dio dio;
    late DioAdapter adapter;
    late CanvasApi api;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://canvas.kumoh.ac.kr/api/v1'));
      adapter = DioAdapter(dio: dio);
      api = CanvasApi(dio);
    });

    test('제목과 유형을 읽는다', () async {
      adapter.onGet('/courses/4831/modules/72723/items',
          (s) => s.reply(200, itemsJson),
          queryParameters: {'per_page': 100});

      final items = await api.fetchModuleItems(4831, 72723);

      expect(items.length, 3);
      expect(items.first.title, '00_Introduction2026.pdf');
      expect(items.first.type, 'File');
      expect(items[1].type, 'Assignment');
    });

    test('파일 항목은 내려받을 주소를 만든다', () {
      const file = CanvasModuleItem(
        id: 1,
        title: 'a.pdf',
        type: 'File',
        htmlUrl: 'https://canvas.kumoh.ac.kr/courses/4831/modules/items/1',
        contentId: 275034,
      );

      expect(file.isFile, isTrue);
      expect(file.downloadUrl,
          'https://canvas.kumoh.ac.kr/files/275034/download?download_frd=1');
    });

    test('제목만 있는 구분선은 누를 수 없다', () {
      // SubHeader는 내용이 아니라 목록의 소제목이다.
      const header =
          CanvasModuleItem(id: 1, title: '읽을 자료', type: 'SubHeader');
      expect(header.isOpenable, isFalse);
    });

    test('과제·페이지·토론은 열 수 있다', () {
      for (final type in ['Assignment', 'Page', 'Discussion', 'Quiz']) {
        final item = CanvasModuleItem(
          id: 1,
          title: 't',
          type: type,
          htmlUrl: 'https://canvas.kumoh.ac.kr/courses/1/modules/items/1',
        );
        expect(item.isOpenable, isTrue, reason: '$type 은 열려야 한다');
      }
    });

    test('주소가 없으면 열 수 없다', () {
      const item = CanvasModuleItem(id: 1, title: 't', type: 'Assignment');
      expect(item.isOpenable, isFalse);
    });
  });

  group('모듈 항목 화면', () {
    Widget wrap(List<Override> overrides) => ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            home: ModuleItemsScreen(
              courseId: 4831,
              moduleId: 72723,
              moduleName: '1주차 : 과목 소개',
            ),
          ),
        );

    testWidgets('모듈 이름을 제목으로, 항목을 목록으로 보여준다', (tester) async {
      await tester.pumpWidget(wrap([
        moduleItemsProvider((courseId: 4831, moduleId: 72723))
            .overrideWith((ref) => fresh(const [
                  CanvasModuleItem(
                      id: 1,
                      title: '00_Introduction2026.pdf',
                      type: 'File',
                      contentId: 275034),
                  CanvasModuleItem(
                      id: 2,
                      title: '[토의 과제] 리눅스 상식',
                      type: 'Assignment',
                      htmlUrl: 'https://canvas.kumoh.ac.kr/x'),
                ])),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('1주차 : 과목 소개'), findsOneWidget);
      expect(find.text('00_Introduction2026.pdf'), findsOneWidget);
      expect(find.text('[토의 과제] 리눅스 상식'), findsOneWidget);
    });

    testWidgets('유형을 아이콘으로 구분한다', (tester) async {
      await tester.pumpWidget(wrap([
        moduleItemsProvider((courseId: 4831, moduleId: 72723))
            .overrideWith((ref) => fresh(const [
                  CanvasModuleItem(
                      id: 1, title: 'a.pdf', type: 'File', contentId: 1),
                  CanvasModuleItem(
                      id: 2,
                      title: '과제',
                      type: 'Assignment',
                      htmlUrl: 'https://canvas.kumoh.ac.kr/x'),
                ])),
      ]));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
      expect(find.byIcon(Icons.assignment_outlined), findsOneWidget);
    });

    testWidgets('항목이 없으면 그렇게 말한다', (tester) async {
      await tester.pumpWidget(wrap([
        moduleItemsProvider((courseId: 4831, moduleId: 72723))
            .overrideWith((ref) => fresh(const <CanvasModuleItem>[])),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('이 주차에는 등록된 항목이 없습니다'), findsOneWidget);
    });

    testWidgets('오류는 사용자 문구로 바꿔 보여준다', (tester) async {
      await tester.pumpWidget(wrap([
        moduleItemsProvider((courseId: 4831, moduleId: 72723))
            .overrideWith((ref) => Stream.error(const NetworkFailure())),
      ]));
      await tester.pumpAndSettle();

      expect(find.textContaining('네트워크에 연결할 수 없습니다'), findsOneWidget);
      expect(find.textContaining('NetworkFailure'), findsNothing);
    });
  });
}
