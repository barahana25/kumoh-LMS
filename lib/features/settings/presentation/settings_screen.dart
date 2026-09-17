import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notifications/presentation/notification_settings_section.dart';
import '../../downloads/download_settings_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;
    final profile = auth is AuthAuthenticated ? auth.profile : null;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          if (profile != null)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(profile.name),
              subtitle: Text('${profile.loginId}\n${profile.affiliation}'),
              isThreeLine: true,
            ),
          const Divider(),
          const NotificationSettingsSection(),
          const Divider(),
          const DownloadSettingsSection(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('로그아웃', style: TextStyle(color: Colors.red)),
            subtitle: const Text('저장된 토큰·자격증명·캐시를 모두 삭제합니다.'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('로그아웃'),
                  content: const Text('저장된 데이터를 모두 지우고 로그아웃할까요?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('취소'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('로그아웃'),
                    ),
                  ],
                ),
              );
              if (context.mounted && (ok ?? false)) {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref.read(authControllerProvider.notifier).logout();
                } on Exception {
                  messenger.showSnackBar(const SnackBar(
                    content: Text('저장된 데이터 정리에 실패했습니다. 앱을 다시 열어 확인해 주세요.'),
                  ));
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
