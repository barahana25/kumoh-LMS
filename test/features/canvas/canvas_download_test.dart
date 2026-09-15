import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_download.dart';

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
}
