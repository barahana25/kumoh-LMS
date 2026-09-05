import '../error/failure.dart';
import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.description,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.outline),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 화면에 띄울 오류 문구. Failure는 자체 한국어 메시지를 갖고 있고,
/// 그 밖의 예외는 클래스 이름이 그대로 새어 나가지 않도록 일반 문구로 바꾼다.
/// (학생에게 "SqliteException(26): file is not a database"를 보여줄 수는 없다.)
String userMessage(Object error) =>
    error is Failure ? error.message : '알 수 없는 오류가 발생했습니다.';
