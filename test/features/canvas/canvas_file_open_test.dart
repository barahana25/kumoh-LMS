import 'dart:io';
import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_download.dart';
import 'package:kumoh_lms/features/canvas/presentation/canvas_file_open.dart';
import 'package:kumoh_lms/providers.dart';

final _temp = <File>[];

/// 실제 네트워크 대신 대본대로 동작한다.
class _FakeDownloader implements CanvasDownloader {
  _FakeDownloader({this.error, this.delay = Duration.zero});

  final Object? error;
  final Duration delay;

  @override
  Future<File> download({
    required String url,
    required String displayName,
    Directory? directory,
    CancelToken? cancelToken,
    void Function(int received, int total)? onProgress,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (error != null) throw error!;
    final f = File('${Directory.systemTemp.path}/$displayName')
      ..writeAsStringSync('x');
    _temp.add(f);
    return f;
  }
}

void main() {
  tearDown(() {
    for (final f in _temp) {
      if (f.existsSync()) f.deleteSync();
    }
    _temp.clear();
  });

  /// 이 앱은 go_router 셸 때문에 네비게이터가 중첩돼 있다.
  /// showDialog는 기본으로 루트에 올리므로, 닫을 때 가장 가까운 네비게이터를
  /// 팝하면 다이얼로그가 아니라 엉뚱한 화면이 사라진다.
  Widget nestedApp(CanvasDownloader downloader) => ProviderScope(
        overrides: [canvasDownloaderProvider.overrideWithValue(downloader)],
        child: MaterialApp(
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => Consumer(
                builder: (context, ref, __) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => openCanvasFile(
                        context,
                        ref,
                        url: 'https://canvas.kumoh.ac.kr/files/1/download',
                        displayName: 'note.pdf',
                      ),
                      child: const Text('열기'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  /// 무한 스피너 때문에 pumpAndSettle은 끝나지 않는다. 프레임을 정해진
  /// 횟수만큼 흘려보내며 비동기 작업이 끝날 시간을 준다.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('받는 동안에는 진행 표시가 보인다', (tester) async {
    await tester.pumpWidget(nestedApp(
      _FakeDownloader(delay: const Duration(milliseconds: 400)),
    ));
    await tester.tap(find.text('열기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('받는 중'), findsOneWidget);

    await settle(tester);
  });

  testWidgets('다 받고 나면 진행 표시가 사라진다', (tester) async {
    // 중첩 네비게이터에서 잘못된 쪽을 팝하면 이 문구가 화면에 남는다.
    await tester.pumpWidget(nestedApp(_FakeDownloader()));
    await tester.tap(find.text('열기'));
    await settle(tester);

    expect(find.textContaining('받는 중'), findsNothing,
        reason: '앱으로 돌아왔을 때 "받는 중" 문구가 남아 있으면 안 된다');
    expect(find.text('열기'), findsOneWidget,
        reason: '다이얼로그 대신 화면이 사라지면 안 된다');
  });

  testWidgets('실패해도 진행 표시가 사라지고 이유를 알린다', (tester) async {
    await tester.pumpWidget(nestedApp(
      _FakeDownloader(error: const NetworkFailure()),
    ));
    await tester.tap(find.text('열기'));
    await settle(tester);

    expect(find.textContaining('받는 중'), findsNothing);
    expect(find.textContaining('네트워크에 연결할 수 없습니다'), findsOneWidget);
    expect(find.text('열기'), findsOneWidget);
  });
}
