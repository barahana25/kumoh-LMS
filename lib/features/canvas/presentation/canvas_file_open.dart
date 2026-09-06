import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/ui/empty_state.dart';
import '../../../providers.dart';

/// 파일을 내려받아 기기 뷰어로 넘긴다.
///
/// WebView에 맡기면 PDF는 빈 화면이 되고 다운로드도 일어나지 않는다.
/// Canvas 파일은 로그인 상태에서만 받을 수 있어 외부 다운로드 관리자에도
/// 넘길 수 없으므로, 세션이 붙은 dio로 우리가 직접 받는다.
Future<void> openCanvasFile(
  BuildContext context,
  WidgetRef ref, {
  required String url,
  required String displayName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final progress = ValueNotifier<double?>(null);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DownloadDialog(name: displayName, progress: progress),
  );

  try {
    final file = await ref.read(canvasDownloaderProvider).download(
          url: url,
          displayName: displayName,
          onProgress: (received, total) {
            progress.value = total > 0 ? received / total : null;
          },
        );

    if (context.mounted) Navigator.of(context).pop();

    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      // 기기에 뷰어가 없을 수 있다. 파일은 이미 저장돼 있으니 그렇게 알린다.
      messenger.showSnackBar(
        SnackBar(content: Text('$displayName 을(를) 열 앱이 없습니다. 기기에 저장했습니다.')),
      );
    }
  } on Object catch (e) {
    if (context.mounted) Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(userMessage(e))));
  } finally {
    progress.dispose();
  }
}

class _DownloadDialog extends StatelessWidget {
  const _DownloadDialog({required this.name, required this.progress});

  final String name;
  final ValueNotifier<double?> progress;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        children: [
          ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (_, value, __) => SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3, value: value),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text('$name 받는 중…',
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
