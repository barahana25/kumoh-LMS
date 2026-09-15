import 'package:web/web.dart' as web;

/// 홈 화면에 추가해 실행하면 standalone 모드다. 브라우저 탭이면 설치 안내를 띄운다.
bool get runsInBrowserTab =>
    !web.window.matchMedia('(display-mode: standalone)').matches;
