import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/ui/empty_state.dart';
import '../../../providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/canvas_download.dart';
import 'canvas_file_open.dart';
import 'canvas_web_target.dart';

/// Canvas 페이지를 로그인된 상태로 연다.
///
/// 외부 브라우저로는 할 수 없다. IdP는 `.kumoh.ac.kr`에 심긴 `_linus_saml_login`
/// 쿠키로 사용자를 식별하는데, 외부 브라우저에는 그 쿠키를 넣을 방법이 없어
/// 매번 로그인 화면이 뜬다. 앱 안의 WebView에는 쿠키를 직접 주입할 수 있으므로,
/// SSO를 태워 사용자가 누른 그 페이지에 바로 도착시킨다.
class CanvasWebScreen extends ConsumerStatefulWidget {
  const CanvasWebScreen({required this.title, required this.url, super.key});

  final String title;
  final String url;

  @override
  ConsumerState<CanvasWebScreen> createState() => _CanvasWebScreenState();
}

class _CanvasWebScreenState extends ConsumerState<CanvasWebScreen> {
  WebViewController? _controller;
  Object? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      final relayState = canvasRelayState(widget.url);
      if (relayState == null) {
        throw const ServerFailure(
          code: 'BAD_URL',
          message: '이 링크는 앱에서 열 수 없습니다.',
        );
      }

      final auth = ref.read(authControllerProvider).valueOrNull;
      final loginId =
          auth is AuthAuthenticated ? auth.profile.loginId : null;
      if (loginId == null || loginId.isEmpty) {
        throw const AuthFailure('로그인 정보가 없어 열 수 없습니다.');
      }

      // IdP는 이 쿠키로 사용자를 식별한다. 없으면 A001로 거부한다.
      final cookies = WebViewCookieManager();
      for (final c in [
        WebViewCookie(
            name: '_linus_saml_login',
            value: loginId,
            domain: '.kumoh.ac.kr',
            path: '/'),
        WebViewCookie(
            name: '_linus_saml_domain',
            value: relayState,
            domain: '.kumoh.ac.kr',
            path: '/'),
      ]) {
        await cookies.setCookie(c);
      }

      final ssoUrl =
          await ref.read(samlBridgeApiProvider).fetchSsoUrl(relayState);
      if (ssoUrl.isEmpty) {
        throw const AuthFailure('Canvas 연결 주소를 받지 못했습니다.');
      }

      final controller = WebViewController()
        // IdP가 돌려주는 폼은 자바스크립트로 자동 제출된다.
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onNavigationRequest: (request) {
            // WebView는 PDF를 그리지 못하고 다운로드도 처리하지 않는다.
            // 그대로 두면 빈 화면만 남으므로 우리가 받아서 기기 뷰어로 넘긴다.
            if (isCanvasFileUrl(request.url)) {
              openCanvasFile(
                context,
                ref,
                url: request.url,
                displayName: Uri.parse(request.url).pathSegments.last,
              );
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (e) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = ServerFailure(
                  code: '${e.errorCode}',
                  message: '페이지를 열지 못했습니다.',
                );
              });
            }
          },
        ))
        ..loadRequest(Uri.parse(ssoUrl));

      if (mounted) setState(() => _controller = controller);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _error != null
          ? EmptyState(
              icon: Icons.error_outline,
              title: '페이지를 열지 못했습니다',
              description: userMessage(_error!),
            )
          : Stack(
              children: [
                if (controller != null)
                  WebViewWidget(controller: controller),
                if (_loading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }
}
