import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/canvas/presentation/canvas_web_target.dart';

void main() {
  group('relayState 만들기', () {
    test('Canvas 절대 URL에서 경로만 뽑는다', () {
      // SSO는 경로만 받는다. 절대 URL을 그대로 넘기면 엉뚱한 곳으로 간다.
      expect(
        canvasRelayState(
            'https://canvas.kumoh.ac.kr/courses/4831/assignments/7931'),
        '/courses/4831/assignments/7931',
      );
    });

    test('쿼리와 프래그먼트도 유지한다', () {
      expect(
        canvasRelayState('https://canvas.kumoh.ac.kr/courses/4831/files?page=2'),
        '/courses/4831/files?page=2',
      );
    });

    test('이미 경로면 그대로 쓴다', () {
      expect(canvasRelayState('/courses/4831'), '/courses/4831');
    });

    test('Canvas 밖 주소는 받지 않는다', () {
      // 외부 링크를 SSO에 태우면 학교 세션이 남의 사이트로 흘러갈 수 있다.
      expect(canvasRelayState('https://example.com/evil'), isNull);
      expect(canvasRelayState('http://canvas.kumoh.ac.kr.evil.com/x'), isNull);
    });

    test('빈 값과 잘못된 주소는 null', () {
      expect(canvasRelayState(''), isNull);
      expect(canvasRelayState('not a url'), isNull);
    });

    test('Canvas 호스트면 http여도 경로를 뽑는다', () {
      expect(canvasRelayState('http://canvas.kumoh.ac.kr/courses/1'),
          '/courses/1');
    });
  });
}
