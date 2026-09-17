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

/// "다시 연결"을 눌러도 항상 실패하는(LINUS 세션이 끊긴 상황을 흉내내는)
/// 토큰 서비스. ensure()는 실제 서비스처럼 null을 돌려줄 뿐 던지지 않는다.
class _FailingConnectCanvasTokenService extends CanvasTokenService {
  _FailingConnectCanvasTokenService()
      : super(
          api: CanvasTokenApi(Dio(), CookieJar()),
          store: InMemoryCanvasTokenStore(),
          ensureSession: () async {},
          platformLabel: 'test',
        );

  @override
  Future<String?> ensure() async => null;
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
    expect(find.textContaining('연결에 실패했습니다'), findsNothing,
        reason: '연결이 성공하면 실패 안내가 뜨면 안 된다');
  });

  testWidgets('다시 연결이 실패하면(예: LINUS 세션 끊김) 안내 메시지를 보여준다',
      (tester) async {
    final store = InMemoryCanvasTokenStore();
    await _pump(tester, store, service: _FailingConnectCanvasTokenService());

    expect(find.text('다시 연결'), findsOneWidget);

    await tester.tap(find.text('다시 연결'));
    await tester.pumpAndSettle();

    // 실패해도 연결 상태는 바뀌지 않는다 — 여전히 쿠키 방식이다.
    expect(find.text('쿠키 방식으로 연결됨'), findsOneWidget);
    expect(find.text('다시 연결'), findsOneWidget);
    expect(find.textContaining('연결에 실패했습니다'), findsOneWidget);
  });

  testWidgets('로그인 직후 자동 발급이 실패해도 화면에는 아무 안내도 뜨지 않는다',
      (tester) async {
    // 이 위젯은 자동 발급(로그인 경로의 ensure()/issueFresh())을 직접
    // 호출하지 않는다 — 저장소를 읽기만 한다. 그 자동 시도가 실패해
    // 저장소에 토큰이 없는 채로 화면에 온 상황을 그대로 재현한다: 버튼을
    // 누르지 않아도 실패 안내가 나타나면 안 된다.
    await _pump(tester, InMemoryCanvasTokenStore());

    expect(find.text('쿠키 방식으로 연결됨'), findsOneWidget);
    expect(find.textContaining('연결에 실패했습니다'), findsNothing);
  });

  testWidgets('자세히를 누르면 토큰 권한을 설명하는 대화상자가 뜬다', (tester) async {
    await _pump(tester, InMemoryCanvasTokenStore());

    await tester.tap(find.text('자세히'));
    await tester.pumpAndSettle();

    expect(find.text('Canvas 토큰이 하는 일'), findsOneWidget);
    expect(find.textContaining('범위 제한이 없습니다'), findsOneWidget);

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();

    expect(find.text('Canvas 토큰이 하는 일'), findsNothing);
  });

  testWidgets('동작이 진행 중이면 버튼이 비활성화된다', (tester) async {
    final store = InMemoryCanvasTokenStore();
    final gate = Completer<void>();
    await _pump(tester, store,
        service: _FakeCanvasTokenService(store, gate: gate));

    await tester.tap(find.text('다시 연결'));
    await tester.pump();

    final button = tester.widget<TextButton>(find.descendant(
        of: find.byType(ListTile), matching: find.byType(TextButton)));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('토큰으로 연결됨'), findsOneWidget);
  });
}
