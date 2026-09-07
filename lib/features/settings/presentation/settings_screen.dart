import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../reference/presentation/term_providers.dart';
import '../../notifications/presentation/notification_settings_section.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;
    final profile = auth is AuthAuthenticated ? auth.profile : null;
    final termsAsync = ref.watch(termsProvider);
    final selectedTermId = ref.watch(selectedTermIdProvider);

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
          termsAsync.maybeWhen(
            data: (terms) => ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('학기'),
              subtitle: Text(
                terms
                        .where((t) => t.id == selectedTermId)
                        .map((t) => t.name)
                        .firstOrNull ??
                    '현재 학기 자동 선택',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked = await showModalBottomSheet<({int? id})>(
                  context: context,
                  builder: (_) => SafeArea(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        ListTile(
                          title: const Text('현재 학기 자동 선택'),
                          onTap: () => Navigator.pop(context, (id: null)),
                        ),
                        for (final t in terms)
                          ListTile(
                            title: Text(t.name),
                            selected: t.id == selectedTermId,
                            onTap: () => Navigator.pop(context, (id: t.id)),
                          ),
                      ],
                    ),
                  ),
                );
                if (context.mounted && picked != null) {
                  ref.read(selectedTermIdProvider.notifier).state = picked.id;
                  ref.read(refreshErrorProvider.notifier).state = null;
                }
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('보안'),
            subtitle: const Text(
              '토큰은 기기 보안 저장소에, 학습 데이터는 암호화된 캐시에 저장합니다. '
              '로그인과 데이터 조회 시 학교 서버에 연결합니다. '
              '자동 로그인을 켠 경우에만 비밀번호를 기기에 저장합니다.',
            ),
          ),
          const Divider(),
          const NotificationSettingsSection(),
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
