import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/storage/db/app_database.dart';
import '../../providers.dart';
import '../auth/presentation/auth_controller.dart';
import '../notifications/notification_runtime.dart';
import 'download_store.dart';
import 'folder_storage.dart';

final downloadSettingsProvider =
    StreamProvider.autoDispose<DownloadSetting?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.downloadSettings)..where((t) => t.id.equals(1)))
      .watchSingleOrNull();
});

class DownloadSettingsSection extends ConsumerStatefulWidget {
  const DownloadSettingsSection({super.key});
  @override
  ConsumerState<DownloadSettingsSection> createState() =>
      _DownloadSettingsSectionState();
}

class _DownloadSettingsSectionState
    extends ConsumerState<DownloadSettingsSection> with WidgetsBindingObserver {
  bool busy = false;
  String? message;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(downloadSettingsProvider);
    }
  }

  Future<void> perform(Future<void> Function() task) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await task();
    } on Exception {
      message = '완료하지 못했습니다. 폴더 접근 권한과 연결을 확인해 주세요.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> choose() => perform(() async {
        final auth = ref.read(authControllerProvider).valueOrNull;
        if (auth is! AuthAuthenticated) {
          message = '온라인으로 로그인한 뒤 폴더를 선택해 주세요.';
          return;
        }
        final folder = await AndroidFolderStorage.pick();
        if (folder == null ||
            !mounted ||
            ref.read(authControllerProvider).valueOrNull != auth) {
          return;
        }
        await AndroidFolderStorage().validate(folder.uri);
        if (!mounted || ref.read(authControllerProvider).valueOrNull != auth) {
          return;
        }
        await DownloadStore(ref.read(appDatabaseProvider))
            .configure(auth.profile.loginId, folder.uri, folder.name);
      });
  Future<void> enable(bool value) => perform(() async {
        final db = ref.read(appDatabaseProvider);
        final store = DownloadStore(db);
        final setting = await store.settings();
        if (setting == null) {
          message = '먼저 저장 폴더를 선택해 주세요.';
          return;
        }
        if (value) {
          final tokens = ref.read(tokenStoreProvider);
          final credentials = await tokens.readCredentials();
          final auth = ref.read(authControllerProvider).valueOrNull;
          if (auth is! AuthAuthenticated ||
              credentials == null ||
              auth.profile.loginId != setting.owner ||
              credentials.userId.toUpperCase().trim() !=
                  setting.owner.toUpperCase().trim()) {
            message = '자동 로그인을 켜고 로그인한 뒤 사용해 주세요.';
            return;
          }
          await AndroidFolderStorage().validate(setting.treeUri);
          if (!mounted || ref.read(authControllerProvider).valueOrNull != auth) {
            return;
          }
          await store.setEnabled(true);
          try {
            await NotificationRuntime.schedule();
          } on Exception {
            await store.setEnabled(false);
            message = '자동 실행을 예약하지 못했습니다. 다시 켜 주세요.';
            return;
          }
          message = await NotificationRuntime.download(db, tokens, force: true);
        } else {
          await store.setEnabled(false);
          if (!await NotificationRuntime.hasBackgroundWork(db)) {
            await NotificationRuntime.cancelScheduled();
          }
        }
      });
  @override
  Widget build(BuildContext context) {
    if (!AndroidFolderStorage.supported) return const SizedBox.shrink();
    final async = ref.watch(downloadSettingsProvider);
    final setting = async.valueOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SwitchListTile(
        title: const Text('강의자료 자동 다운로드'),
        subtitle: const Text('새 자료를 선택한 폴더 안에 강의별로 저장'),
        secondary: const Icon(Icons.download_outlined),
        value: setting?.enabled ?? false,
        onChanged: busy || async.isLoading || async.hasError ? null : enable,
      ),
      ListTile(
        title: const Text('저장 폴더 선택·만들기'),
        subtitle: Text(setting?.folderName ?? '예: 다운로드 / 2학년 2학기'),
        leading: const Icon(Icons.create_new_folder_outlined),
        trailing: const Icon(Icons.chevron_right),
        onTap: busy ? null : choose,
      ),
      const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '폴더 선택창에서 다운로드로 이동한 뒤 새 폴더(예: 2학년 2학기)를 만들고 선택하세요. '
            'Android에서는 다운로드 최상위 폴더 대신 그 안의 폴더를 선택해야 합니다.\n'
            '선택한 폴더 / 강의명 (강의 ID) / 파일명__파일ID 형식으로 저장합니다. '
            '처음 켜면 현재 자료도 다운로드하며 이후 저장한 파일은 건너뜁니다. '
            '매시 1분 확인과 새벽 휴식 시간을 따르며 알림을 꺼도 동작합니다. '
            '모바일 데이터가 사용될 수 있습니다. 로그아웃해도 저장한 파일은 남습니다.',
            style: TextStyle(fontSize: 12),
          )),
      if (setting != null || message != null || async.hasError)
        ListTile(
          title: Text(busy
              ? '폴더와 파일을 처리하고 있습니다…'
              : message ?? setting?.status ?? '설정을 불러오지 못했습니다.'),
          subtitle: setting?.lastAttempt == null
              ? null
              : Text(
                  '최근 확인: ${DateFormat('M/d HH:mm').format(DateTime.fromMillisecondsSinceEpoch(setting!.lastAttempt!))}'),
          trailing: setting?.enabled == true
              ? TextButton(
                  onPressed: busy
                      ? null
                      : () => perform(() async {
                            message = await NotificationRuntime.download(
                                ref.read(appDatabaseProvider),
                                ref.read(tokenStoreProvider),
                                force: true);
                          }),
                  child: const Text('지금 다운로드'),
                )
              : null,
        ),
    ]);
  }
}
