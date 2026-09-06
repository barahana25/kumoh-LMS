import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_api.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_cache.dart';
import 'package:kumoh_lms/features/canvas/presentation/tabs/content_tabs.dart';
import 'package:kumoh_lms/features/canvas/presentation/tabs/home_tab.dart';

Stream<CanvasSnapshot<T>> fresh<T>(T data) =>
    Stream.value(CanvasSnapshot<T>(data: data, stale: false));

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  group('default_view 파싱', () {
    late Dio dio;
    late DioAdapter adapter;
    late CanvasApi api;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://canvas.kumoh.ac.kr/api/v1'));
      adapter = DioAdapter(dio: dio);
      api = CanvasApi(dio);
    });

    test('강좌가 지정한 홈 화면 종류를 읽는다', () {
      expect(parseDefaultView({'default_view': 'modules'}), 'modules');
      expect(parseDefaultView({'default_view': 'wiki'}), 'wiki');
    });

    test('값이 없으면 feed로 본다', () {
      // Canvas 기본값이 feed다. 임의로 다른 걸 고르면 웹과 달라진다.
      expect(parseDefaultView(const <String, dynamic>{}), 'feed');
    });

    test('front_page 본문을 가져온다', () async {
      adapter.onGet('/courses/4831/front_page',
          (s) => s.reply(200, {'body': '<p>환영합니다</p>', 'title': '홈'}));

      expect(await api.fetchFrontPage(4831), '<p>환영합니다</p>');
    });

    test('front_page가 없으면 null', () async {
      adapter.onGet('/courses/4831/front_page', (s) => s.reply(200, {'body': ''}));

      expect(await api.fetchFrontPage(4831), isNull);
    });
  });

  group('홈 탭 위임', () {
    Widget wrap(List<Override> overrides) => ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            home: Scaffold(body: HomeTab(courseId: 1)),
          ),
        );

    testWidgets('modules면 강의실 내용을 보여준다', (tester) async {
      await tester.pumpWidget(wrap([
        courseHomeViewProvider(1).overrideWith((ref) => fresh('modules')),
        courseModulesProvider(1).overrideWith((ref) => fresh(const [
              CanvasModule(
                  id: 1, name: '1주차', position: 1, itemsCount: 2, state: '')
            ])),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('1주차'), findsOneWidget);
    });

    testWidgets('syllabus면 강의 계획을 보여준다', (tester) async {
      await tester.pumpWidget(wrap([
        courseHomeViewProvider(1).overrideWith((ref) => fresh('syllabus')),
        courseSyllabusProvider(1).overrideWith((ref) => fresh('<p>계획서</p>')),
      ]));
      await tester.pumpAndSettle();

      expect(find.textContaining('계획서', findRichText: true), findsOneWidget);
    });

    testWidgets('wiki면 대문 페이지를 보여준다', (tester) async {
      await tester.pumpWidget(wrap([
        courseHomeViewProvider(1).overrideWith((ref) => fresh('wiki')),
        courseFrontPageProvider(1)
            .overrideWith((ref) => fresh<String?>('<p>환영합니다</p>')),
      ]));
      await tester.pumpAndSettle();

      expect(find.textContaining('환영합니다', findRichText: true), findsOneWidget);
    });

    testWidgets('feed면 강좌 공지를 보여준다', (tester) async {
      await tester.pumpWidget(wrap([
        courseHomeViewProvider(1).overrideWith((ref) => fresh('feed')),
        courseCanvasAnnouncementsProvider(1).overrideWith((ref) => fresh(const [
              CanvasDiscussion(id: 1, title: '휴강 안내', replyCount: 0),
            ])),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('휴강 안내'), findsOneWidget);
    });

    testWidgets('처음 보는 종류면 빈 화면 대신 그렇게 말한다', (tester) async {
      // 조용히 빈 화면을 두면 학생이 "강좌에 내용이 없다"고 오해한다.
      await tester.pumpWidget(wrap([
        courseHomeViewProvider(1).overrideWith((ref) => fresh('무언가_새로운값')),
      ]));
      await tester.pumpAndSettle();

      expect(find.textContaining('앱에서 지원하지 않습니다'), findsOneWidget);
    });
  });
}
