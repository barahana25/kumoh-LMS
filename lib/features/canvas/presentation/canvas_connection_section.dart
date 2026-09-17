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
    // 사용자가 직접 누른 시도만 실패를 알린다. 로그인 뒤 조용히 시도하는
    // 자동 발급(ensure()/issueFresh())은 이 위젯을 거치지 않으므로 여기서
    // 실패를 알려도 그 경로에는 영향이 없다.
    var connectFailed = false;
    if (connected) {
      await service.revoke();
    } else {
      connectFailed = await service.ensure() == null;
    }
    // SAML 다리를 넘는 동안 사용자가 설정 화면을 떠나면 이 위젯과 ref가
    // 이미 폐기됐을 수 있다. await 뒤에 ref나 setState를 건드리기 전에
    // 반드시 mounted를 확인한다.
    if (!mounted) return;
    ref.invalidate(canvasConnectionProvider);
    setState(() => _busy = false);
    if (connectFailed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          '연결에 실패했습니다. 토큰이 없어도 앱은 그대로 동작합니다. '
          '다시 로그인한 뒤 다시 시도해 주세요.',
        ),
      ));
    }
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
            '· 새로 로그인하면 이 기기가 전에 만들어 둔 토큰을 새 토큰을 '
            '받기 전에 먼저 지웁니다(실패해도 새 토큰은 그대로 만들어집니다)\n'
            '· Canvas 직접: 프로필 → 설정 → 승인된 통합에서 \'금오LMS 앱 · …\' '
            '항목 삭제\n\n'
            '앱은 Canvas 계정의 토큰 목록을 확인할 방법이 없어, 이 기기가 '
            '방금까지 쓰던 토큰만 정확히 지목해 지웁니다. 계정에 다른 토큰이 '
            '더 있는지는 훑어보지 않습니다.\n\n'
            '앱을 지울 때는 먼저 로그아웃하세요\n'
            '로그아웃하지 않고 앱을 지우거나 앱 데이터를 삭제하면 그 토큰은 '
            'Canvas에 그대로 남습니다. 앱이 더는 그 토큰을 알지 못하므로 위 '
            '방법으로 직접 지워 주세요. 이름 끝 네 자리가 기기마다 달라서 어느 '
            '기기 것인지 구분할 수 있습니다. 같은 이유로, 이 정리 기능이 '
            '생기기 전에 만들어졌던 토큰도 앱이 기억하지 못해 자동으로 '
            '지워지지 않습니다 — 이런 토큰도 Canvas에서 직접 지워야 합니다.',
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
