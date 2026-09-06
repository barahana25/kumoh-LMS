import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_api.dart';
import 'package:kumoh_lms/features/canvas/presentation/tabs/content_tabs.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  Widget wrap(Widget child, List<Override> overrides) => ProviderScope(
        overrides: overrides,
        child: MaterialApp(home: Scaffold(body: child)),
      );

  group('강의 계획', () {
    testWidgets('HTML 본문을 렌더링한다', (tester) async {
      await tester.pumpWidget(wrap(
        const SyllabusTab(courseId: 1),
        [courseSyllabusProvider(1).overrideWith((ref) async => '<p>주차별 계획</p>')],
      ));
      await tester.pumpAndSettle();

      // HtmlWidget은 Text가 아니라 RichText로 그린다.
      expect(
        find.textContaining('주차별 계획', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('비어 있으면 빈 상태', (tester) async {
      await tester.pumpWidget(wrap(
        const SyllabusTab(courseId: 1),
        [courseSyllabusProvider(1).overrideWith((ref) async => null)],
      ));
      await tester.pumpAndSettle();

      expect(find.text('등록된 강의 계획이 없습니다'), findsOneWidget);
    });
  });

  group('강의실', () {
    testWidgets('모듈 이름과 항목 수를 보여준다', (tester) async {
      await tester.pumpWidget(wrap(
        const ModulesTab(courseId: 1),
        [
          courseModulesProvider(1).overrideWith((ref) async => const [
                CanvasModule(
                    id: 1,
                    name: '1주차 : 리눅스 개요',
                    position: 1,
                    itemsCount: 3,
                    state: 'completed'),
              ])
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('1주차 : 리눅스 개요'), findsOneWidget);
      expect(find.text('항목 3개'), findsOneWidget);
    });

    testWidgets('잠긴 모듈은 잠김으로 표시한다', (tester) async {
      await tester.pumpWidget(wrap(
        const ModulesTab(courseId: 1),
        [
          courseModulesProvider(1).overrideWith((ref) async => const [
                CanvasModule(
                    id: 2,
                    name: '기말',
                    position: 1,
                    itemsCount: 1,
                    state: 'locked'),
              ])
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('잠김'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });

  group('강의자료실', () {
    testWidgets('파일 이름과 크기를 보여준다', (tester) async {
      await tester.pumpWidget(wrap(
        const FilesTab(courseId: 1),
        [
          courseFilesProvider(1).overrideWith((ref) async => const [
                CanvasFile(
                    id: 1,
                    displayName: '00_Introduction.pdf',
                    locked: false,
                    sizeBytes: 155840),
              ])
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('00_Introduction.pdf'), findsOneWidget);
      expect(find.text('152 KB'), findsOneWidget);
    });

    test('파일 크기를 사람이 읽는 단위로 바꾼다', () {
      expect(formatBytes(500), '500 B');
      expect(formatBytes(155840), '152 KB');
      expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
      expect(formatBytes(null), '');
    });
  });

  group('성적', () {
    testWidgets('점수와 등급을 보여준다', (tester) async {
      await tester.pumpWidget(wrap(
        const GradesTab(courseId: 1),
        [
          courseGradeProvider(1).overrideWith(
              (ref) async => const CanvasGrade(currentScore: 85.5, currentGrade: 'B+'))
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('현재 성적'), findsOneWidget);
      expect(find.textContaining('B+'), findsOneWidget);
    });

    testWidgets('공개된 성적이 없으면 그렇게 말한다', (tester) async {
      await tester.pumpWidget(wrap(
        const GradesTab(courseId: 1),
        [courseGradeProvider(1).overrideWith((ref) async => const CanvasGrade())],
      ));
      await tester.pumpAndSettle();

      expect(find.text('아직 공개된 성적이 없습니다'), findsOneWidget);
    });
  });

  group('사용자 및 그룹', () {
    testWidgets('교수와 수강생을 나눠 보여준다', (tester) async {
      await tester.pumpWidget(wrap(
        const PeopleTab(courseId: 1),
        [
          coursePeopleProvider(1).overrideWith((ref) async => (
                people: const [
                  CanvasPerson(
                      userId: 1, name: '홍교수', enrollmentType: 'TeacherEnrollment'),
                  CanvasPerson(
                      userId: 2, name: '김학생', enrollmentType: 'StudentEnrollment'),
                ],
                groups: const [CanvasGroup(id: 1, name: '1조', membersCount: 2)],
              ))
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('교수 · 조교'), findsOneWidget);
      expect(find.text('홍교수'), findsOneWidget);
      expect(find.text('수강생 1명'), findsOneWidget);
      expect(find.text('1조'), findsOneWidget);
    });
  });

  testWidgets('오류는 사용자 문구로 바꿔 보여준다', (tester) async {
    await tester.pumpWidget(wrap(
      const ModulesTab(courseId: 1),
      [
        courseModulesProvider(1)
            .overrideWith((ref) async => throw const NetworkFailure())
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('네트워크에 연결할 수 없습니다'), findsOneWidget);
    expect(find.textContaining('NetworkFailure'), findsNothing);
  });
}
