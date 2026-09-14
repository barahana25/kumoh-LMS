import 'package:flutter/material.dart';

/// iOS는 PWA 설치 버튼이 없어 사용자가 직접 홈 화면에 추가해야 한다.
class InstallHint extends StatelessWidget {
  const InstallHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.ios_share),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Safari 아래쪽 공유 버튼을 누르고 "홈 화면에 추가"를 선택하면 앱처럼 쓸 수 있습니다.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
