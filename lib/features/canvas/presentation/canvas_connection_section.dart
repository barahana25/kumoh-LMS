import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers.dart';
import '../data/canvas_token_store.dart';

/// 지금 저장된 Canvas 토큰. 연결 상태 표시에만 쓴다.
final canvasConnectionProvider = FutureProvider<StoredCanvasToken?>(
  (ref) => ref.watch(canvasTokenStoreProvider).read(),
);

/// 설정 화면의 "Canvas 연결" 영역.
class CanvasConnectionSection extends ConsumerWidget {
  const CanvasConnectionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            connected
                ? stored.purpose
                : '토큰 없이도 동작합니다. Canvas 설정에서 발급이 막혀 있을 수 있어요.',
          ),
          trailing: TextButton(
            onPressed: () async {
              final service = ref.read(canvasTokenServiceProvider);
              if (connected) {
                await service.revoke();
              } else {
                await service.ensure();
              }
              ref.invalidate(canvasConnectionProvider);
            },
            child: Text(connected ? '연결 해제' : '다시 연결'),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            '앱은 Canvas 조회에만 이 토큰을 씁니다. Canvas 설정(프로필 → 설정)에서 '
            '직접 지울 수 있고, 지우면 다음 조회에서 새로 만듭니다.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
