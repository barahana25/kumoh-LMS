import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_api.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_download.dart';

/// 홉을 대본대로 재현한다. 리다이렉트는 `location` 응답으로, 끝은 실제
/// 바이트 응답으로 표현한다. 요청마다 호스트와 Authorization 헤더를 남긴다.
class _RedirectScript implements HttpClientAdapter {
  _RedirectScript(this._routes);
  final Map<String, ({int status, String? location, String? body})> _routes;
  final List<({String host, String? auth})> seen = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add((
      host: options.uri.host,
      auth: options.headers['Authorization'] as String?,
    ));
    final hop = _routes[options.uri.toString()];
    if (hop == null) {
      return ResponseBody.fromString('경로 없음', 404);
    }
    if (hop.location != null) {
      return ResponseBody.fromString('', hop.status, headers: {
        'location': [hop.location!],
      });
    }
    return ResponseBody.fromString(hop.body ?? '', hop.status, headers: {
      'content-type': ['application/pdf'],
      'content-disposition': ['attachment; filename="lecture.pdf"'],
    });
  }

  @override
  void close({bool force = false}) {}
}

CanvasDownloader _downloaderFor(_RedirectScript script, {String? token = '7~abc'}) {
  final dio = Dio(BaseOptions(validateStatus: (s) => s != null && s < 500))
    ..httpClientAdapter = script;
  dio.interceptors.insert(
    0,
    canvasSessionInterceptor(
      dio: dio,
      accessToken: () async => token,
      reissueToken: () async => null,
      reBridge: () async {},
    ),
  );
  return CanvasDownloader(dio, crossHostDio: Dio()..httpClientAdapter = script);
}

void main() {
  group('다운로드 URL 판별', () {
    test('Canvas 파일 다운로드 주소를 알아본다', () {
      expect(
        isCanvasFileUrl(
            'https://canvas.kumoh.ac.kr/files/275034/download?download_frd=1'),
        isTrue,
      );
      expect(isCanvasFileUrl('https://canvas.kumoh.ac.kr/files/275034'), isTrue);
      expect(
        isCanvasFileUrl('https://canvas.kumoh.ac.kr/courses/1/files/9/download'),
        isTrue,
      );
    });

    test('일반 페이지는 다운로드가 아니다', () {
      // 이것까지 가로채면 강좌 페이지가 WebView 대신 다운로드로 새어나간다.
      expect(
        isCanvasFileUrl('https://canvas.kumoh.ac.kr/courses/4831/assignments/7931'),
        isFalse,
      );
      expect(isCanvasFileUrl('https://canvas.kumoh.ac.kr/courses/4831'), isFalse);
    });

    test('Canvas 밖 주소는 다루지 않는다', () {
      expect(isCanvasFileUrl('https://example.com/files/1/download'), isFalse);
      expect(isCanvasFileUrl('not a url'), isFalse);
    });
  });

  group('실제 파일 받기', () {
    test('미리보기 페이지 주소를 내려받기 주소로 바꾼다', () {
      // 미리보기 페이지를 받으면 HTML이 저장돼 Acrobat이 "지원하지 않는 형식"을 띄운다.
      expect(canvasFileDownloadUrl('https://canvas.kumoh.ac.kr/courses/5342/files/77'),
          'https://canvas.kumoh.ac.kr/files/77/download?download_frd=1');
      expect(canvasFileDownloadUrl('https://canvas.kumoh.ac.kr/files/77'),
          'https://canvas.kumoh.ac.kr/files/77/download?download_frd=1');
      const direct = 'https://canvas.kumoh.ac.kr/files/77/download?download_frd=1&verifier=x';
      expect(canvasFileDownloadUrl(direct), direct);
    });

    test('서버가 알려준 이름과 형식으로 확장자를 붙인다', () {
      expect(
          resolveDownloadName(
              displayName: 'download',
              disposition: "attachment; filename=\"a.pdf\"; filename*=UTF-8''%EA%B0%95%EC%9D%98.pdf"),
          '강의.pdf');
      expect(
          resolveDownloadName(
              displayName: 'download', disposition: 'attachment; filename="1주차.pptx"'),
          '1주차.pptx');
      expect(
          resolveDownloadName(
              displayName: '1주차 자료', contentType: 'application/pdf; charset=binary'),
          '1주차 자료.pdf');
      expect(
          resolveDownloadName(displayName: '과제.hwp', disposition: 'attachment; filename="download"'),
          '과제.hwp',
          reason: '확장자 없는 서버 이름보다 확장자 있는 표시 이름이 낫다');
    });
  });

  group('저장할 파일 이름', () {
    test('표시 이름을 그대로 쓴다', () {
      expect(safeFileName('00_Introduction2026.pdf'), '00_Introduction2026.pdf');
    });

    test('경로 구분자와 위험한 문자를 없앤다', () {
      // 파일 이름이 그대로 경로가 되면 앱 밖에 쓰려는 시도가 될 수 있다.
      expect(safeFileName('../../etc/passwd'), 'etc_passwd');
      expect(safeFileName(r'보고서:최종<v2>.pdf'), '보고서_최종_v2_.pdf');
    });

    test('빈 이름이면 기본값을 준다', () {
      expect(safeFileName(''), 'download');
      expect(safeFileName('   '), 'download');
    });

    test('너무 긴 이름은 확장자를 지키며 줄인다', () {
      final long = '${'가' * 300}.pdf';
      final result = safeFileName(long);
      expect(result.length, lessThanOrEqualTo(120));
      expect(result.endsWith('.pdf'), isTrue,
          reason: '확장자가 없으면 기기 뷰어가 무엇으로 열지 모른다');
    });
  });

  group('리다이렉트를 따라가는 실제 다운로드', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('canvas_dl_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    const start = 'https://canvas.kumoh.ac.kr/files/9/download?download_frd=1';

    test('Canvas 밖 호스트로 리다이렉트되면 Authorization 없이 받되 내용은 그대로 온다', () async {
      // Canvas 파일은 자주 별도 파일 서버로 302된다. 거기까지 Bearer가
      // 따라가면 만료 없는 토큰이 제3자 로그에 남는다.
      final script = _RedirectScript({
        start: (status: 302, location: 'https://files.example.edu/blob/abc123', body: null),
        'https://files.example.edu/blob/abc123':
            (status: 200, location: null, body: 'PDF-BYTES'),
      });

      final file = await _downloaderFor(script).download(
        url: start,
        displayName: 'note',
        directory: tmp,
      );

      expect(file.readAsStringSync(), 'PDF-BYTES', reason: '호스트가 바뀌어도 파일은 받아야 한다');
      expect(script.seen, [
        (host: 'canvas.kumoh.ac.kr', auth: 'Bearer 7~abc'),
        (host: 'files.example.edu', auth: null),
      ]);
    });

    test('같은 Canvas 호스트 안에서의 리다이렉트는 Authorization을 계속 지닌다', () async {
      final script = _RedirectScript({
        start: (
          status: 302,
          location: 'https://canvas.kumoh.ac.kr/files/9/redirected',
          body: null,
        ),
        'https://canvas.kumoh.ac.kr/files/9/redirected':
            (status: 200, location: null, body: 'PDF-BYTES'),
      });

      final file = await _downloaderFor(script).download(
        url: start,
        displayName: 'note',
        directory: tmp,
      );

      expect(file.readAsStringSync(), 'PDF-BYTES');
      expect(
        script.seen.every((s) => s.host == 'canvas.kumoh.ac.kr' && s.auth == 'Bearer 7~abc'),
        isTrue,
        reason: 'Canvas 안에서의 리다이렉트까지 토큰을 떼면 멀쩡한 요청도 막힌다',
      );
    });

    test('리다이렉트가 끝나지 않으면 홉 한도에서 멈춘다', () async {
      // 두 주소가 서로를 계속 가리키는 순환 리다이렉트.
      final script = _RedirectScript({
        start: (status: 302, location: 'https://canvas.kumoh.ac.kr/files/9/b', body: null),
        'https://canvas.kumoh.ac.kr/files/9/b': (status: 302, location: start, body: null),
      });

      await expectLater(
        _downloaderFor(script).download(url: start, displayName: 'note', directory: tmp),
        throwsA(anything),
      );
      expect(script.seen.length, 6, reason: '홉 한도(5) + 첫 요청 = 6번에서 멈춰야 한다');
    });
  });
}
