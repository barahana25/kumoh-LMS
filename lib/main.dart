import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/ui/startup_screen.dart';
import 'features/notifications/notification_runtime.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: _StartupApp()));
}

Future<void> _initialize() async {
  await initializeDateFormatting('ko_KR');
  try {
    await NotificationRuntime.initialize();
  } on Exception {
    // 알림 초기화 문제로 앱 로그인 화면까지 막지 않는다. 설정에서 재시도한다.
  }
}

class _StartupApp extends StatefulWidget {
  const _StartupApp();

  @override
  State<_StartupApp> createState() => _StartupAppState();
}

class _StartupAppState extends State<_StartupApp> {
  late final Future<void> _ready = _initialize();

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done) {
        return const KumohLmsApp();
      }
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: StartupScreen(),
      );
    },
  );
}
