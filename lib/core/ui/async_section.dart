import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/failure.dart';

import '../../features/reference/presentation/term_providers.dart';

/// 새로고침이 실패했을 때 캐시 위에 얇게 뜨는 안내줄.
/// 화면 전체를 에러로 덮지 않는 것이 이 앱의 원칙이다.
class RefreshBanner extends ConsumerWidget {
  const RefreshBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(refreshErrorProvider);
    if (message == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.cloud_off, size: 18, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 12, color: scheme.onErrorContainer),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 16, color: scheme.onErrorContainer),
              onPressed: () =>
                  ref.read(refreshErrorProvider.notifier).state = null,
            ),
          ],
        ),
      ),
    );
  }
}

/// 리포지토리 새로고침을 감싸 실패를 배너 메시지로 바꾼다.
/// 예외를 삼키므로 캐시 화면은 그대로 유지된다.
Future<void> runRefresh(WidgetRef ref, Future<void> Function() action) async {
  if (!ref.context.mounted) return;
  try {
    await action();
    if (!ref.context.mounted) return;
    ref.read(refreshErrorProvider.notifier).state = null;
  } on Failure catch (e) {
    if (!ref.context.mounted) return;
    // Failure는 사용자에게 보여줄 한국어 메시지를 이미 갖고 있다.
    ref.read(refreshErrorProvider.notifier).state =
        '${e.message} 저장된 데이터를 표시합니다.';
  } on Exception {
    if (!ref.context.mounted) return;
    ref.read(refreshErrorProvider.notifier).state =
        '새로고침에 실패했습니다. 저장된 데이터를 표시합니다.';
  }
  // Error(TypeError, StateError 등)는 프로그래밍 버그이므로 삼키지 않고 그대로 던진다.
}
