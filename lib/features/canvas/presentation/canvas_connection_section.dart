import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers.dart';
import '../data/canvas_token_store.dart';

/// 지금 저장된 Canvas 토큰. 연결 상태 표시에만 쓴다.
final canvasConnectionProvider = FutureProvider<StoredCanvasToken?>(
  (ref) => ref.watch(canvasTokenStoreProvider).read(),
);

/// 설정 화면의 "Canvas 연결" 영역.
class CanvasConnectionSection extends ConsumerStatefulWidget {
  const CanvasConnectionSection({super.key});

  @override
  ConsumerState<CanvasConnectionSection> createState() =>
      _CanvasConnectionSectionState();
}

class _CanvasConnectionSectionState
    extends ConsumerState<CanvasConnectionSection> {
  bool _busy = false;

  Future<void> _toggle(bool connected) async {
    setState(() => _busy = true);
    final service = ref.read(canvasTokenServiceProvider);
    if (connected) {
      await service.revoke();
    } else {
      await service.ensure();
    }
    // SAML 다리를 넘는 동안 사용자가 설정 화면을 떠나면 이 위젯과 ref가
    // 이미 폐기됐을 수 있다. await 뒤에 ref나 setState를 건드리기 전에
    // 반드시 mounted를 확인한다.
    if (!mounted) return;
    ref.invalidate(canvasConnectionProvider);
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(canvasConnectionProvider);
    final stored = connection.valueOrNull;
    final connected = stored != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.link),
          title: Text(connected ? '토큰으로 연결됨' : '쿠키 방식으로 연결됨'),
          subtitle: Text(
            connected ? stored.purpose : '토큰 없이도 동작합니다. 연결은 선택 사항이에요.',
          ),
          trailing: TextButton(
            onPressed: _busy ? null : () => _toggle(connected),
            child: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(connected ? '연결 해제' : '다시 연결'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  '앱은 Canvas 조회에만 이 토큰을 씁니다. Canvas 설정(프로필 → 설정)에서 '
                  '직접 지울 수 있고, 지우면 다음 조회에서 새로 만듭니다.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () => _showTokenInfoDialog(context),
                child: const Text('자세히', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 토큰이 실제로 가진 권한을 설명한다. `docs/canvas-token.md`와 같은
  /// 내용을 오프라인에서, 브라우저 없이 볼 수 있게 대화상자로 보여준다.
  void _showTokenInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Canvas 토큰이 하는 일'),
        content: const SingleChildScrollView(
          child: Text(
            '앱은 로그인한 뒤 Canvas 개인 액세스 토큰을 하나 만들어 기기에 '
            '보관합니다. 공지·과제·강의자료를 읽을 때 이 토큰을 씁니다.\n\n'
            '권한 범위\n'
            'Canvas가 만들어 주는 토큰에는 범위 제한이 없습니다. Canvas 계정으로 '
            '할 수 있는 모든 일이 가능한 권한입니다. 앱은 조회에만 쓰지만, 권한 '
            '자체는 그렇습니다.\n\n'
            '어디에 보관하나요\n'
            '기기 보안 저장소에만 둡니다(Android EncryptedSharedPreferences, '
            'iOS Keychain). 서버로 보내지 않고, 로그에도 남기지 않습니다.\n\n'
            '어떻게 지우나요\n'
            '· 앱: 설정 → Canvas 연결 → 연결 해제\n'
            '· 앱에서 로그아웃하면 자동으로 지워집니다\n'
            '· Canvas 직접: 프로필 → 설정 → 승인된 통합에서 \'금오LMS 앱 · …\' '
            '항목 삭제',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}
