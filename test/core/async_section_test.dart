import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/core/ui/async_section.dart';
import 'package:kumoh_lms/features/reference/presentation/term_providers.dart';

void main() {
  /// RefreshBanner를 띄우고, runRefresh에 넘길 WidgetRef를 꺼내온다.
  Future<WidgetRef> pumpBanner(WidgetTester tester) async {
    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const Scaffold(body: RefreshBanner());
            },
          ),
        ),
      ),
    );
    return captured;
  }

  testWidgets('실패가 없으면 배너는 아무 자리도 차지하지 않는다', (tester) async {
    await pumpBanner(tester);
    expect(find.byType(Material), findsWidgets);
    expect(find.textContaining('저장된 데이터'), findsNothing);
  });

  testWidgets('Failure의 한국어 메시지를 배너에 그대로 쓴다', (tester) async {
    final ref = await pumpBanner(tester);

    await runRefresh(ref, () async => throw const NetworkFailure());
    await tester.pump();

    expect(find.textContaining('네트워크에 연결할 수 없습니다'), findsOneWidget);
    expect(find.textContaining('저장된 데이터를 표시합니다'), findsOneWidget);
    // 클래스 이름이 한국어 UI에 새면 안 된다.
    expect(find.textContaining('NetworkFailure'), findsNothing);
  });

  testWidgets('성공하면 이전 실패 배너가 사라진다', (tester) async {
    final ref = await pumpBanner(tester);

    await runRefresh(ref, () async => throw const NetworkFailure());
    await tester.pump();
    expect(find.textContaining('저장된 데이터를 표시합니다'), findsOneWidget);

    await runRefresh(ref, () async {});
    await tester.pump();
    expect(find.textContaining('저장된 데이터를 표시합니다'), findsNothing);
  });

  testWidgets('프로그래밍 오류(Error)는 삼키지 않고 그대로 던진다', (tester) async {
    final ref = await pumpBanner(tester);

    await expectLater(
      runRefresh(ref, () async => throw StateError('프로그래밍 버그')),
      throwsA(isA<StateError>()),
    );
    // 버그가 "새로고침 실패"로 위장되면 안 된다.
    await tester.pump();
    expect(find.textContaining('저장된 데이터를 표시합니다'), findsNothing);
    expect(ref.read(refreshErrorProvider), isNull);
  });
}
