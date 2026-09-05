import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:sqlite3/open.dart';

bool _configured = false;

/// Windows에서 flutter test는 호스트 VM으로 돌기 때문에
/// 프로젝트 루트의 sqlite3.dll을 직접 지정해야 한다.
void _configureSqlite() {
  if (_configured) return;
  _configured = true;
  if (Platform.isWindows) {
    open.overrideFor(OperatingSystem.windows, () {
      final dll = File('sqlite3.dll').absolute;
      return DynamicLibrary.open(dll.path);
    });
  }
}

AppDatabase createTestDatabase() {
  _configureSqlite();
  return AppDatabase.forTesting(NativeDatabase.memory());
}
