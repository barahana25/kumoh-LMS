import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_api.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_service.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_store.dart';
import 'package:kumoh_lms/features/canvas/presentation/canvas_connection_section.dart';
import 'package:kumoh_lms/providers.dart';

/// 실제 SAML 다리나 Canvas API를 타지 않는 테스트용 토큰 서비스.
/// [gate]가 있으면 완료될 때까지 멈춰서, 진행 중 상태를 관찰할 수 있게 한다.
class _FakeCanvasTokenService extends CanvasTokenService {
  _FakeCanvasTokenService(CanvasTokenStore store, {Completer<void>? gate})
      : _store = store,
        _gate = gate,
        super(
          api: CanvasTokenApi(Dio(), CookieJar()),
          store: store,
          ensureSession: () async {},
          platformLabel: 'test',
        );

  final CanvasTokenStore _store;
  final Completer<void>? _gate;

  @override
  Future<String?> ensure() async {
    if (_gate != null) await _gate.future;
    const issued = StoredCanvasToken(
        token: '7~new', id: 2, purpose: '금오LMS 앱 · test · fake');
    await _store.save(issued);
    return issued.token;
  }

  @override
  Future<void> revoke() async {
    if (_gate != null) await _gate.future;
    await _store.clear();
  }
}

Future<void> _pump(WidgetTester tester, CanvasTokenStore store,
    {CanvasTokenService? service}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      canvasTokenStoreProvider.overrideWithValue(store),
      if (service != null) canvasTokenServiceProvider.overrideWithValue(service),
    ],
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

  testWidgets('다시 연결을 누르면 연결된 상태로 바뀐다', (tester) async {
    final store = InMemoryCanvasTokenStore();
    await _pump(tester, store, service: _FakeCanvasTokenService(store));

    expect(find.text('다시 연결'), findsOneWidget);

    await tester.tap(find.text('다시 연결'));
    await tester.pumpAndSettle();

    expect(find.text('토큰으로 연결됨'), findsOneWidget);
    expect(find.text('연결 해제'), findsOneWidget);
  });

  testWidgets('동작이 진행 중이면 버튼이 비활성화된다', (tester) async {
    final store = InMemoryCanvasTokenStore();
    final gate = Completer<void>();
    await _pump(tester, store,
        service: _FakeCanvasTokenService(store, gate: gate));

    await tester.tap(find.text('다시 연결'));
    await tester.pump();

    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('토큰으로 연결됨'), findsOneWidget);
  });
}
