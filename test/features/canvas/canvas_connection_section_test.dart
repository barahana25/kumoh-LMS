import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_store.dart';
import 'package:kumoh_lms/features/canvas/presentation/canvas_connection_section.dart';
import 'package:kumoh_lms/providers.dart';

Future<void> _pump(WidgetTester tester, CanvasTokenStore store) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [canvasTokenStoreProvider.overrideWithValue(store)],
    child: const MaterialApp(
      home: Scaffold(body: CanvasConnectionSection()),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('토큰이 있으면 토큰으로 연결됨을 보여준다', (tester) async {
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~abc', id: 1, purpose: '금오LMS 앱 · Android · a3f9'));

    await _pump(tester, store);

    expect(find.text('토큰으로 연결됨'), findsOneWidget);
    expect(find.text('금오LMS 앱 · Android · a3f9'), findsOneWidget);
    expect(find.text('연결 해제'), findsOneWidget);
  });

  testWidgets('토큰이 없으면 쿠키 방식과 다시 연결 버튼을 보여준다', (tester) async {
    await _pump(tester, InMemoryCanvasTokenStore());

    expect(find.text('쿠키 방식으로 연결됨'), findsOneWidget);
    expect(find.text('다시 연결'), findsOneWidget);
  });

  testWidgets('화면에 토큰 값은 절대 나오지 않는다', (tester) async {
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~secret', id: 1, purpose: '금오LMS 앱 · Android · a3f9'));

    await _pump(tester, store);

    expect(find.textContaining('7~secret'), findsNothing);
  });
}
