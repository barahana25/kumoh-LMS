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
