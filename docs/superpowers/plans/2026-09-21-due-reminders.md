# 미제출 과제 마감 알림 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 제출하지 않은 과제를 마감 D-3·D-1·D-DAY 구간에 한 번씩 기기 알림으로 알린다.

**Architecture:** 자동 다운로드처럼 자체 설정·잠금·기록을 가진 러너(`DueReminder`)를 매시 예약(`NotificationRuntime.checkAll`)에 얹는다. 새 소식 poller와 마감 러너는 `SharedLmsSession` 하나를 받아 LINUS 로그인과 과제 목록 응답을 나눠 쓴다. 구간 계산은 화면 배지와 같은 `dueDays()` 하나로 통일한다.

**Tech Stack:** Flutter, Riverpod 2, Drift(SQLCipher), Dio, flutter_local_notifications, Workmanager, http_mock_adapter(테스트)

**설계 문서:** [docs/superpowers/specs/2026-09-21-due-reminders-design.md](../specs/2026-09-21-due-reminders-design.md)

## Global Constraints

- 구간: D-3 = 남은 72~96시간, D-1 = 24~48시간, D-DAY = 24시간 미만. 화면 배지(`dueRelative`)와 같은 계산.
- 마감 알림은 **08:01~23:01 회차에서만** 보낸다. 00:01 회차와 새벽 1~7시에는 보내지 않는다.
- 과제·구간·마감 시각 조합마다 한 번. 키 형식 `강좌:과제:구간:마감시각(UTC ISO-8601)`.
- 대상: `due_at` 있음, `published != false`, `locked_for_user != true`, `!isSubmitted(submission)`, `submission_types`가 `none`·`on_paper`·`not_graded`뿐이 아님.
- 매시 작업에서 LINUS 로그인은 한 번만. 마감 러너는 잠금을 잡은 **뒤에만** 로그인을 부른다(15분 복구 작업마다 로그인이 늘면 안 된다).
- 알림 제목 `[마감 D-1] 알고리즘및실습`(분반 번호 제거), 본문 `과제명 · 9월 23일 (수) 10:40까지`(한국 시간). 누르면 강좌 과제 탭.
- Android 알림 채널 `lms_due` "과제 마감". 마감 알림은 Android에서만 돈다(`NotificationRuntime.dueSupported`).
- 오류 문구에 자격증명·서버 응답 본문·네이티브 메시지를 넣지 않는다.
- 코드 주석·문구는 기존처럼 한국어 평서체.
- Windows에서 `flutter test`는 프로젝트 루트의 `sqlite3.dll`이 필요하다(이미 있음).

## File Structure

| 파일 | 상태 | 책임 |
|---|---|---|
| `lib/core/time/due_days.dart` | 신규 | 남은 일수 계산 한 곳 |
| `lib/features/assignments/presentation/widgets/event_tile.dart` | 수정 | `dueRelative()`가 `dueDays()` 사용 |
| `lib/features/notifications/data/due_reminder_models.dart` | 신규 | 구간·대상 선별·키·알림 ID·문구·인터페이스(순수) |
| `lib/core/storage/db/tables.dart` | 수정 | `DueReminderSettings`, `DueReminderSent` |
| `lib/core/storage/db/app_database.dart` | 수정 | 테이블 등록, v9 마이그레이션 |
| `lib/features/notifications/data/due_reminder_store.dart` | 신규 | 설정·잠금·보낸 기록 |
| `lib/features/notifications/data/due_reminder.dart` | 신규 | 러너 |
| `lib/features/notifications/data/shared_lms_session.dart` | 신규 | `LmsSource` 인터페이스, 로그인·강좌 목록 공유 감싸개 |
| `lib/features/notifications/data/lms_notification_source.dart` | 수정 | `dueAssignments()`, 과제 응답 재사용 |
| `lib/features/notifications/notification_runtime.dart` | 수정 | `showDue`, `checkAll`, `remindDue`, `stopDue`, `dueSupported` |
| `lib/features/auth/presentation/auth_controller.dart` | 수정 | 로그인·로그아웃 때 마감 알림 끄기 |
| `lib/features/notifications/presentation/notification_setup.dart` | 수정 | `enableDueReminders()` |
| `lib/features/notifications/presentation/due_reminder_tile.dart` | 신규 | 설정 토글과 상태 |
| `lib/features/notifications/presentation/notification_settings_section.dart` | 수정 | 토글 배치 |
| `docs/notifications.md` | 수정 | 마감 알림 절 |

---

### Task 1: 남은 일수 계산을 한 곳으로

**Files:**
- Create: `lib/core/time/due_days.dart`
- Modify: `lib/features/assignments/presentation/widgets/event_tile.dart:17-25`
- Test: `test/core/time/due_days_test.dart`

**Interfaces:**
- Produces: `int? dueDays(DateTime dueAt, DateTime now)` — 지났으면 `null`, 24시간 미만이면 `0`, 그 외 `diff.inDays`.

- [ ] **Step 1: 실패하는 테스트 작성**

`test/core/time/due_days_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/time/due_days.dart';
import 'package:kumoh_lms/features/assignments/presentation/widgets/event_tile.dart';

void main() {
  final now = DateTime.utc(2026, 9, 21, 1, 1); // KST 10:01
  DateTime after(Duration d) => now.add(d);

  test('24시간 미만이면 0, 지났으면 null', () {
    expect(dueDays(after(const Duration(minutes: 1)), now), 0);
    expect(dueDays(after(const Duration(hours: 23, minutes: 59)), now), 0);
    expect(dueDays(now.subtract(const Duration(seconds: 1)), now), isNull);
  });

  test('24시간부터는 남은 시간을 일 단위로 내린다', () {
    expect(dueDays(after(const Duration(hours: 24)), now), 1);
    expect(dueDays(after(const Duration(hours: 47, minutes: 59)), now), 1);
    expect(dueDays(after(const Duration(hours: 48)), now), 2);
    expect(dueDays(after(const Duration(hours: 72)), now), 3);
    expect(dueDays(after(const Duration(hours: 95, minutes: 59)), now), 3);
    expect(dueDays(after(const Duration(hours: 96)), now), 4);
  });

  test('화면 배지는 같은 계산을 쓴다', () {
    expect(dueRelative(null, now: now), '');
    expect(dueRelative(now.subtract(const Duration(minutes: 1)), now: now), '마감됨');
    expect(dueRelative(after(const Duration(hours: 5)), now: now), 'D-DAY');
    expect(dueRelative(after(const Duration(hours: 30)), now: now), 'D-1');
    expect(dueRelative(after(const Duration(hours: 80)), now: now), 'D-3');
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/core/time/due_days_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:kumoh_lms/core/time/due_days.dart'`

- [ ] **Step 3: 구현**

`lib/core/time/due_days.dart`:

```dart
/// 마감까지 남은 날 수. 화면 배지와 마감 알림이 같은 기준을 쓰도록 한 곳에 둔다.
///
/// 24시간 미만이면 0(D-DAY), 그 이상이면 남은 시간을 일 단위로 내린 값,
/// 이미 지났으면 null이다. 시간대와 무관하게 두 시각의 차이만 본다.
int? dueDays(DateTime dueAt, DateTime now) {
  final diff = dueAt.difference(now);
  if (diff.isNegative) return null;
  if (diff.inHours < 24) return 0;
  return diff.inDays;
}
```

`lib/features/assignments/presentation/widgets/event_tile.dart` — import 추가(기존 `app_database.dart` import 아래):

```dart
import '../../../../core/time/due_days.dart';
```

`dueRelative`를 다음으로 바꾼다:

```dart
/// 마감까지 남은 시간을 사람이 읽는 문구로.
String dueRelative(DateTime? at, {DateTime? now}) {
  if (at == null) return '';
  final days = dueDays(at, now ?? DateTime.now());
  if (days == null) return '마감됨';
  if (days == 0) return 'D-DAY';
  return 'D-$days';
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/core/time/due_days_test.dart test/features/assignments/`
Expected: 전부 PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/time/due_days.dart lib/features/assignments/presentation/widgets/event_tile.dart test/core/time/due_days_test.dart
git commit -m "refactor: 마감까지 남은 일수 계산을 한 곳으로 모은다"
```

---

### Task 2: 마감 알림 모델과 대상 선별

**Files:**
- Create: `lib/features/notifications/data/due_reminder_models.dart`
- Test: `test/features/notifications/due_reminder_models_test.dart`

**Interfaces:**
- Consumes: `dueDays()` (Task 1), `isSubmitted(Object?)` (`lib/features/canvas/data/canvas_api.dart`), `WatchedCourse` (`notification_models.dart`)
- Produces:
  - `enum DueStage { threeDays('D-3'), oneDay('D-1'), today('D-DAY') }` with `String label`
  - `DueStage? dueStageFor(DateTime dueAt, DateTime now)`
  - `class DueAssignment { String id; String name; DateTime dueAt /* UTC */ }`
  - `List<DueAssignment> parseDueAssignments(List<Map<String, dynamic>> rows)`
  - `String dueReminderKey(int courseId, DueAssignment a, DueStage stage)`
  - `int dueNotificationId(String key)` — 결과는 `0x40000000 | (0..0x3FFFFFFF)`
  - `String formatDueKst(DateTime dueAt)`
  - `class DueNotice { int id; String owner; int courseId; String courseName; DueAssignment assignment; DueStage stage; String get heading; String get body; }`
  - `abstract interface class DueSource { authenticate(); courses(); dueAssignments(int); close(); }`
  - `abstract interface class DueSink { Future<bool> permitted(); Future<void> showDue(DueNotice); }`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/features/notifications/due_reminder_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/notifications/data/due_reminder_models.dart';

void main() {
  final now = DateTime.utc(2026, 9, 21, 1, 1); // KST 10:01

  test('구간은 화면 배지와 같다', () {
    DueStage? at(Duration d) => dueStageFor(now.add(d), now);
    expect(at(const Duration(hours: 96)), isNull, reason: 'D-4');
    expect(at(const Duration(hours: 95)), DueStage.threeDays);
    expect(at(const Duration(hours: 72)), DueStage.threeDays);
    expect(at(const Duration(hours: 60)), isNull, reason: 'D-2');
    expect(at(const Duration(hours: 47)), DueStage.oneDay);
    expect(at(const Duration(hours: 24)), DueStage.oneDay);
    expect(at(const Duration(hours: 23)), DueStage.today);
    expect(at(const Duration(minutes: 1)), DueStage.today);
    expect(dueStageFor(now.subtract(const Duration(minutes: 1)), now), isNull);
  });

  group('대상 선별', () {
    Map<String, dynamic> row(Map<String, dynamic> extra) => {
          'id': 7,
          'name': '실습 과제',
          'due_at': '2026-09-23T01:40:00Z',
          'published': true,
          'submission_types': ['online_upload'],
          ...extra,
        };

    test('미제출 온라인 과제만 남긴다', () {
      final result = parseDueAssignments([
        row({}),
        row({'id': 8, 'submission': {'workflow_state': 'submitted', 'submitted_at': '2026-09-20T00:00:00Z'}}),
        row({'id': 9, 'submission': {'workflow_state': 'graded', 'submitted_at': null}}),
        row({'id': 10, 'due_at': null}),
        row({'id': 11, 'published': false}),
        row({'id': 12, 'locked_for_user': true}),
        row({'id': 13, 'submission_types': ['none']}),
        row({'id': 14, 'submission_types': ['on_paper', 'not_graded']}),
        row({'id': 15, 'submission_types': ['on_paper', 'online_text_entry']}),
      ]);
      expect(result.map((a) => a.id), ['7', '9', '15'],
          reason: '점수만 있고 제출 시각이 없으면 미제출, 온라인 방식이 하나라도 있으면 대상');
      expect(result.first.name, '실습 과제');
      expect(result.first.dueAt, DateTime.utc(2026, 9, 23, 1, 40));
      expect(result.first.dueAt.isUtc, isTrue);
    });
  });

  test('키에 마감 시각이 들어가 마감이 바뀌면 다른 키가 된다', () {
    final a = DueAssignment(id: '7', name: '과제', dueAt: DateTime.utc(2026, 9, 23, 1, 40));
    final moved = DueAssignment(id: '7', name: '과제', dueAt: DateTime.utc(2026, 9, 24, 1, 40));
    expect(dueReminderKey(3, a, DueStage.oneDay), '3:7:oneDay:2026-09-23T01:40:00.000Z');
    expect(dueReminderKey(3, a, DueStage.oneDay), isNot(dueReminderKey(3, moved, DueStage.oneDay)));
  });

  test('알림 ID는 키마다 고정이고 새 소식 ID와 겹치지 않는 범위다', () {
    const key = '3:7:oneDay:2026-09-23T01:40:00.000Z';
    final id = dueNotificationId(key);
    expect(id, dueNotificationId(key));
    expect(id, greaterThanOrEqualTo(0x40000000));
    expect(id, lessThanOrEqualTo(0x7FFFFFFF));
    expect(dueNotificationId('3:7:today:2026-09-23T01:40:00.000Z'), isNot(id));
  });

  test('문구는 한국 시간으로 적고 강의명의 분반 번호를 뗀다', () {
    final notice = DueNotice(
      id: 1,
      owner: 'student',
      courseId: 3,
      courseName: '알고리즘및실습-01',
      assignment: DueAssignment(
          id: '7', name: '실습 과제 #4 제출', dueAt: DateTime.utc(2026, 9, 23, 1, 40)),
      stage: DueStage.oneDay,
    );
    expect(notice.heading, '[마감 D-1] 알고리즘및실습');
    expect(notice.body, '실습 과제 #4 제출 · 9월 23일 (수) 10:40까지');
    expect(formatDueKst(DateTime.utc(2026, 9, 25, 14, 59)), '9월 25일 (금) 23:59');
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/notifications/due_reminder_models_test.dart`
Expected: FAIL — `due_reminder_models.dart` 없음

- [ ] **Step 3: 구현**

`lib/features/notifications/data/due_reminder_models.dart`:

```dart
import '../../../core/time/due_days.dart';
import '../../canvas/data/canvas_api.dart' show isSubmitted;
import 'notification_models.dart';

/// 마감 알림을 보내는 구간. 화면 배지와 같은 이름을 쓴다.
enum DueStage {
  threeDays('D-3'),
  oneDay('D-1'),
  today('D-DAY');

  const DueStage(this.label);
  final String label;
}

/// [dueAt]까지 남은 시간이 알림 구간에 있으면 그 구간, 아니면 null.
DueStage? dueStageFor(DateTime dueAt, DateTime now) =>
    switch (dueDays(dueAt, now)) {
      3 => DueStage.threeDays,
      1 => DueStage.oneDay,
      0 => DueStage.today,
      _ => null,
    };

/// 마감 알림 대상이 될 수 있는 미제출 과제.
class DueAssignment {
  const DueAssignment(
      {required this.id, required this.name, required this.dueAt});
  final String id;
  final String name;

  /// UTC.
  final DateTime dueAt;
}

/// 앱에서 낼 수 없는 제출 방식. 이것뿐인 과제는 언제나 미제출로 보인다.
const _offlineSubmissionTypes = {'none', 'on_paper', 'not_graded'};

/// `/assignments?include[]=submission` 응답에서 마감 알림 대상만 고른다.
List<DueAssignment> parseDueAssignments(List<Map<String, dynamic>> rows) {
  final result = <DueAssignment>[];
  for (final row in rows) {
    if (row['published'] == false || row['locked_for_user'] == true) continue;
    final due = DateTime.tryParse('${row['due_at']}');
    if (due == null) continue;
    final types = (row['submission_types'] as List?)
            ?.map((e) => '$e')
            .toSet() ??
        const <String>{};
    if (types.isNotEmpty && types.every(_offlineSubmissionTypes.contains)) {
      continue;
    }
    if (isSubmitted(row['submission'])) continue;
    final id = row['id'];
    if (id == null || '$id'.isEmpty) continue;
    result.add(DueAssignment(
        id: '$id',
        name: row['name'] as String? ?? '과제',
        dueAt: due.toUtc()));
  }
  return result;
}

/// 한 과제·구간·마감 시각에 한 번만 보내기 위한 기록 키.
/// 마감이 바뀌면 키가 달라져 새 마감 기준으로 다시 알린다.
String dueReminderKey(int courseId, DueAssignment a, DueStage stage) =>
    '$courseId:${a.id}:${stage.name}:${a.dueAt.toUtc().toIso8601String()}';

/// 키마다 고정된 알림 ID. 같은 키로 다시 띄우면 알림을 덮어쓴다.
///
/// 새 소식 알림 ID(보낸 기록의 자동 증가 번호)와 겹치지 않게 0x40000000 위에
/// 둔다. 웹에서도 2^53을 넘지 않도록 30비트 안에서 섞는다.
int dueNotificationId(String key) {
  var hash = 0;
  for (final unit in key.codeUnits) {
    hash = (hash * 31 + unit) & 0x3FFFFFFF;
  }
  return 0x40000000 | hash;
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// '9월 23일 (수) 10:40'. 백그라운드 isolate에는 ko_KR 날짜 기호가 없어
/// intl을 쓰지 않고 한국 시간으로 직접 적는다.
String formatDueKst(DateTime dueAt) {
  final kst = dueAt.toUtc().add(const Duration(hours: 9));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${kst.month}월 ${kst.day}일 (${_weekdays[kst.weekday - 1]}) '
      '${two(kst.hour)}:${two(kst.minute)}';
}

/// 기기에 띄울 마감 알림 하나.
class DueNotice {
  const DueNotice(
      {required this.id,
      required this.owner,
      required this.courseId,
      required this.courseName,
      required this.assignment,
      required this.stage});
  final int id;
  final String owner;
  final int courseId;
  final String courseName;
  final DueAssignment assignment;
  final DueStage stage;

  /// '[마감 D-1] 알고리즘및실습'. 강의명 끝의 분반 번호는 뗀다.
  String get heading =>
      '[마감 ${stage.label}] ${courseName.replaceAll(RegExp(r'-\d+$'), '')}';

  /// '실습 과제 #4 제출 · 9월 23일 (수) 10:40까지'
  String get body => '${assignment.name} · ${formatDueKst(assignment.dueAt)}까지';
}

abstract interface class DueSource {
  Future<String> authenticate();
  Future<List<WatchedCourse>> courses();
  Future<List<DueAssignment>> dueAssignments(int courseId);
  void close();
}

abstract interface class DueSink {
  Future<bool> permitted();
  Future<void> showDue(DueNotice notice);
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/notifications/due_reminder_models_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/data/due_reminder_models.dart test/features/notifications/due_reminder_models_test.dart
git commit -m "feat: 마감 알림 구간과 대상 과제를 가린다"
```

---

### Task 3: DB v9와 마감 알림 저장소

**Files:**
- Modify: `lib/core/storage/db/tables.dart` (끝에 추가)
- Modify: `lib/core/storage/db/app_database.dart` (tables 목록, `schemaVersion`, `onUpgrade`)
- Regenerate: `lib/core/storage/db/app_database.g.dart`
- Create: `lib/features/notifications/data/due_reminder_store.dart`
- Modify: `test/core/app_database_test.dart` (v8→v9 테스트, schemaVersion 9)
- Test: `test/features/notifications/due_reminder_store_test.dart`

**Interfaces:**
- Produces (Drift 생성): 테이블 접근자 `db.dueReminderSettings`, `db.dueReminderSent`; 데이터 클래스 `DueReminderSetting`, `DueReminderSentRow`; 컴패니언 `DueReminderSettingsCompanion`, `DueReminderSentCompanion`
- Produces (`DueReminderStore`):
  - `Future<DueReminderSetting?> settings()`
  - `Future<void> enable(String owner)`
  - `Future<void> disable()`
  - `Future<DueReminderSetting?> acquire(DateTime now, DateTime slot)` — 같은 회차에 한 번
  - `Future<bool> current(DueReminderSetting run)`
  - `Future<bool> sent(String key)`
  - `Future<void> markSent(String key, DateTime at)`
  - `Future<void> pause(DueReminderSetting run, String status)`
  - `Future<void> finish(DueReminderSetting run, DateTime now, String status, {bool success = false})`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/core/app_database_test.dart` — `group('스키마 마이그레이션', ...)` 안의 `'v7 -> v8 ...'` 테스트 다음에 추가:

```dart
    test('v8 -> v9 업그레이드가 마감 알림 테이블을 만든다', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      await db.customStatement('DROP TABLE due_reminder_settings');
      await db.customStatement('DROP TABLE due_reminder_sent');

      await db.migration.onUpgrade(Migrator(db), 8, 9);

      await db.into(db.dueReminderSent).insert(DueReminderSentCompanion.insert(
          key: '1:2:oneDay:2026-09-23T01:40:00.000Z',
          sentAt: DateTime.now().toUtc()));
      expect(await db.select(db.dueReminderSent).get(), hasLength(1));
      expect(await db.select(db.dueReminderSettings).get(), isEmpty);
    });
```

같은 파일의 `'현재 schemaVersion과 마이그레이션 단계가 어긋나지 않는다'` 테스트에서 `expect(db.schemaVersion, 8,`를 `expect(db.schemaVersion, 9,`로 바꾼다.

`test/features/notifications/due_reminder_store_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/notifications/data/due_reminder_store.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late DueReminderStore store;
  final slot = DateTime.utc(2026, 9, 21, 1, 1); // KST 10:01
  final now = slot.add(const Duration(seconds: 5));

  setUp(() {
    db = createTestDatabase();
    store = DueReminderStore(db);
  });
  tearDown(() => db.close());

  test('켜고 끈다', () async {
    expect(await store.settings(), isNull);
    await store.enable('student');
    final on = (await store.settings())!;
    expect(on.enabled, isTrue);
    expect(on.owner, 'student');
    await store.disable();
    final off = (await store.settings())!;
    expect(off.enabled, isFalse);
    expect(off.generation, isNot(on.generation));
  });

  test('꺼져 있으면 잠금을 잡지 않는다', () async {
    expect(await store.acquire(now, slot), isNull);
    await store.enable('student');
    await store.disable();
    expect(await store.acquire(now, slot), isNull);
  });

  test('같은 회차에는 한 번만 잡고 다음 회차에는 다시 잡는다', () async {
    await store.enable('student');
    final run = (await store.acquire(now, slot))!;
    expect(await store.current(run), isTrue);
    expect(await store.acquire(now, slot), isNull, reason: '실행 중');
    await store.finish(run, now, '완료', success: true);
    expect(await store.acquire(now.add(const Duration(minutes: 15)), slot), isNull,
        reason: '이번 회차는 이미 돌았다');
    final nextSlot = slot.add(const Duration(hours: 1));
    expect(await store.acquire(nextSlot.add(const Duration(seconds: 5)), nextSlot),
        isNotNull);
    final saved = (await store.settings())!;
    expect(saved.status, '완료');
    expect(saved.lastSuccess, now.millisecondsSinceEpoch);
  });

  test('끄면 진행 중인 실행은 더 이상 유효하지 않다', () async {
    await store.enable('student');
    final run = (await store.acquire(now, slot))!;
    await store.disable();
    expect(await store.current(run), isFalse);
  });

  test('보낸 키를 기록한다', () async {
    const key = '1:7:oneDay:2026-09-23T01:40:00.000Z';
    expect(await store.sent(key), isFalse);
    await store.markSent(key, now);
    await store.markSent(key, now); // 다시 써도 오류가 나지 않는다
    expect(await store.sent(key), isTrue);
  });

  test('멈추면 꺼지고 상태를 남긴다', () async {
    await store.enable('student');
    final run = (await store.acquire(now, slot))!;
    await store.pause(run, '자동 로그인을 켜고 다시 로그인해 주세요.');
    final saved = (await store.settings())!;
    expect(saved.enabled, isFalse);
    expect(saved.status, '자동 로그인을 켜고 다시 로그인해 주세요.');
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/notifications/due_reminder_store_test.dart test/core/app_database_test.dart`
Expected: FAIL — `dueReminderSettings`/`DueReminderStore` 없음

- [ ] **Step 3: 테이블 추가**

`lib/core/storage/db/tables.dart` 끝에 추가:

```dart
/// 과제 마감 알림 설정과 실행 잠금. 새 소식 알림과 따로 켜고 끈다.
class DueReminderSettings extends Table {
  IntColumn get id => integer()();
  TextColumn get owner => text()();
  TextColumn get generation => text()();
  BoolColumn get enabled => boolean()();
  TextColumn get status =>
      text().withDefault(const Constant('아직 확인하지 않았습니다.'))();
  IntColumn get lastAttempt => integer().nullable()();
  IntColumn get lastSuccess => integer().nullable()();
  TextColumn get lease => text().nullable()();
  IntColumn get leaseUntil => integer().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 보낸 마감 알림. 키는 `강좌:과제:구간:마감시각`.
@DataClassName('DueReminderSentRow')
class DueReminderSent extends Table {
  TextColumn get key => text()();
  DateTimeColumn get sentAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {key};
}
```

`lib/core/storage/db/app_database.dart`:
- `@DriftDatabase(tables: [...])` 목록 끝(`ReadNotices` 뒤)에 `DueReminderSettings, DueReminderSent` 추가.
- `int get schemaVersion => 8;` → `int get schemaVersion => 9;`
- `onUpgrade` 맨 위(`// v8: 과제 제출 여부` 앞)에 추가:

```dart
          // v9: 과제 마감 알림
          if (from < 9 && to >= 9) {
            await m.createTable(dueReminderSettings);
            await m.createTable(dueReminderSent);
          }
```

- [ ] **Step 4: 코드 생성**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `Succeeded` 로 끝나고 `app_database.g.dart`에 `$DueReminderSettingsTable`, `$DueReminderSentTable`이 생긴다.

- [ ] **Step 5: 저장소 구현**

`lib/features/notifications/data/due_reminder_store.dart`:

```dart
import 'dart:math';
import 'package:drift/drift.dart';
import '../../../core/storage/db/app_database.dart';

// 1 << 32는 웹에서 0이 되어 nextInt가 RangeError를 던진다. 리터럴을 쓴다.
String _nonce() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0xFFFFFFFF)}';

/// 과제 마감 알림의 설정·실행 잠금·보낸 기록.
/// 백그라운드 isolate와 설정 화면이 함께 읽고 쓴다.
class DueReminderStore {
  DueReminderStore(this.db);
  final AppDatabase db;

  Future<DueReminderSetting?> settings() =>
      (db.select(db.dueReminderSettings)..where((t) => t.id.equals(1)))
          .getSingleOrNull();

  Future<void> enable(String owner) async {
    await db.into(db.dueReminderSettings).insertOnConflictUpdate(
          DueReminderSettingsCompanion.insert(
            id: const Value(1),
            owner: owner,
            generation: _nonce(),
            enabled: true,
            status: const Value('다음 확인부터 마감이 가까운 미제출 과제를 알려드립니다.'),
            lastAttempt: const Value(null),
            lastSuccess: const Value(null),
            lease: const Value(null),
            leaseUntil: const Value(null),
          ),
        );
  }

  Future<void> disable() async {
    await (db.update(db.dueReminderSettings)..where((t) => t.id.equals(1)))
        .write(DueReminderSettingsCompanion(
      enabled: const Value(false),
      generation: Value(_nonce()),
      lease: const Value(null),
      leaseUntil: const Value(null),
      status: const Value('마감 알림이 꺼져 있습니다.'),
    ));
  }

  /// [slot] 회차에 한 번만 실행 잠금을 잡는다. 이미 돌았거나 돌고 있으면 null.
  ///
  /// 15분 복구 작업과 앱 타이머가 같은 회차에 여러 번 부른다. 잠금 없이
  /// 로그인까지 가면 매번 LINUS 로그인이 늘어 다른 기기 세션이 끊긴다.
  Future<DueReminderSetting?> acquire(DateTime now, DateTime slot) async {
    final lease = _nonce();
    final ms = now.millisecondsSinceEpoch;
    final count = await db.customUpdate('''UPDATE due_reminder_settings
      SET lease = ?, lease_until = ?, last_attempt = ?
      WHERE id = 1 AND enabled = 1 AND (lease_until IS NULL OR lease_until < ?)
      AND (last_attempt IS NULL OR last_attempt < ?)''', variables: [
      Variable(lease),
      Variable(ms + const Duration(minutes: 10).inMilliseconds),
      Variable(ms),
      Variable(ms),
      Variable(slot.millisecondsSinceEpoch),
    ], updates: {
      db.dueReminderSettings
    });
    if (count != 1) return null;
    final run = await settings();
    return run?.lease == lease && run?.enabled == true ? run : null;
  }

  Future<bool> current(DueReminderSetting run) async {
    final state = await settings();
    return state?.enabled == true &&
        state?.generation == run.generation &&
        state?.lease == run.lease;
  }

  Future<bool> sent(String key) async =>
      await (db.select(db.dueReminderSent)..where((t) => t.key.equals(key)))
          .getSingleOrNull() !=
      null;

  Future<void> markSent(String key, DateTime at) =>
      db.into(db.dueReminderSent).insertOnConflictUpdate(
          DueReminderSentCompanion.insert(key: key, sentAt: at.toUtc()));

  Future<void> pause(DueReminderSetting run, String status) async {
    await (db.update(db.dueReminderSettings)
          ..where((t) =>
              t.generation.equals(run.generation) & t.lease.equals(run.lease!)))
        .write(DueReminderSettingsCompanion(
            enabled: const Value(false), status: Value(status)));
  }

  Future<void> finish(DueReminderSetting run, DateTime now, String status,
      {bool success = false}) async {
    await (db.update(db.dueReminderSettings)
          ..where((t) =>
              t.generation.equals(run.generation) & t.lease.equals(run.lease!)))
        .write(DueReminderSettingsCompanion(
            lease: const Value(null),
            leaseUntil: const Value(null),
            status: Value(status),
            lastSuccess: success
                ? Value(now.millisecondsSinceEpoch)
                : const Value.absent()));
  }
}
```

- [ ] **Step 6: 통과 확인**

Run: `flutter test test/features/notifications/due_reminder_store_test.dart test/core/app_database_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/core/storage/db/tables.dart lib/core/storage/db/app_database.dart lib/core/storage/db/app_database.g.dart lib/features/notifications/data/due_reminder_store.dart test/core/app_database_test.dart test/features/notifications/due_reminder_store_test.dart
git commit -m "feat: 마감 알림 설정과 보낸 기록을 저장한다 (DB v9)"
```

---

### Task 4: 마감 알림 러너

**Files:**
- Create: `lib/features/notifications/data/due_reminder.dart`
- Test: `test/features/notifications/due_reminder_test.dart`

**Interfaces:**
- Consumes: Task 2의 `DueSource`, `DueSink`, `DueNotice`, `dueStageFor`, `dueReminderKey`, `dueNotificationId`; Task 3의 `DueReminderStore`; `NotificationSchedule.slot()`, `NotificationSchedule.zone`
- Produces:
  - `class DueReminder({required DueReminderStore store, required DueSource source, required DueSink sink, DateTime Function()? clock, Duration budget = const Duration(minutes: 2)})`
  - `static DateTime? DueReminder.sendSlot(DateTime now)` — 00:01·새벽이면 null
  - `Future<String> run()` — 상태 문구를 돌려준다. **source를 닫지 않는다**(호출한 쪽이 수명 관리).

- [ ] **Step 1: 실패하는 테스트 작성**

`test/features/notifications/due_reminder_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/notifications/data/due_reminder.dart';
import 'package:kumoh_lms/features/notifications/data/due_reminder_models.dart';
import 'package:kumoh_lms/features/notifications/data/due_reminder_store.dart';
import 'package:kumoh_lms/features/notifications/data/notification_models.dart';
import '../../helpers/test_db.dart';

class FakeDueSource implements DueSource {
  String owner = 'student';
  int logins = 0;
  Failure? authFailure;
  List<WatchedCourse> watched = [const WatchedCourse(1, '알고리즘및실습-01')];
  final values = <int, List<DueAssignment>>{};
  final failures = <int>{};

  @override
  Future<String> authenticate() async {
    logins++;
    if (authFailure != null) throw authFailure!;
    return owner;
  }

  @override
  Future<List<WatchedCourse>> courses() async => watched;

  @override
  Future<List<DueAssignment>> dueAssignments(int courseId) async {
    if (failures.contains(courseId)) throw const NetworkFailure();
    return values[courseId] ?? const [];
  }

  @override
  void close() {}
}

class FakeDueSink implements DueSink {
  bool allowed = true;
  final shown = <DueNotice>[];
  @override
  Future<bool> permitted() async => allowed;
  @override
  Future<void> showDue(DueNotice notice) async => shown.add(notice);
}

void main() {
  late AppDatabase db;
  late DueReminderStore store;
  late FakeDueSource source;
  late FakeDueSink sink;
  late DateTime now;

  DueReminder reminder() => DueReminder(
      store: store, source: source, sink: sink, clock: () => now);
  DueAssignment due(String id, Duration left) =>
      DueAssignment(id: id, name: '과제 $id', dueAt: now.add(left));
  Future<String> tick([Duration by = const Duration(hours: 1)]) {
    now = now.add(by);
    return reminder().run();
  }

  setUp(() async {
    db = createTestDatabase();
    store = DueReminderStore(db);
    source = FakeDueSource();
    sink = FakeDueSink();
    now = DateTime.utc(2026, 9, 21, 1, 1); // KST 10:01
    await store.enable('student');
  });
  tearDown(() => db.close());

  test('구간에 든 미제출 과제만 한 번씩 알린다', () async {
    source.values[1] = [
      due('a', const Duration(hours: 80)), // D-3
      due('b', const Duration(hours: 30)), // D-1
      due('c', const Duration(hours: 5)), // D-DAY
      due('d', const Duration(hours: 60)), // D-2
      due('e', const Duration(hours: 120)), // D-5
    ];
    final status = await reminder().run();
    expect(sink.shown.map((n) => n.stage),
        [DueStage.threeDays, DueStage.oneDay, DueStage.today]);
    expect(sink.shown[1].heading, '[마감 D-1] 알고리즘및실습');
    expect(status, '1개 강좌 확인 · 마감 알림 3개');
    await tick();
    expect(sink.shown, hasLength(3), reason: '같은 구간은 다시 보내지 않는다');
  });

  test('00:01 회차와 새벽에는 확인하지 않는다', () async {
    source.values[1] = [due('a', const Duration(hours: 5))];
    now = DateTime.utc(2026, 9, 21, 15, 1); // KST 9/22 00:01
    await reminder().run();
    now = DateTime.utc(2026, 9, 21, 18, 1); // KST 03:01
    await reminder().run();
    expect(sink.shown, isEmpty);
    expect(source.logins, 0, reason: '확인하지 않는 회차에는 로그인도 하지 않는다');
    expect((await store.settings())!.lastAttempt, isNull);
  });

  test('같은 회차에 여러 번 불려도 로그인은 한 번이다', () async {
    source.values[1] = [due('a', const Duration(hours: 5))];
    await reminder().run();
    now = now.add(const Duration(minutes: 15));
    await reminder().run();
    expect(source.logins, 1);
    expect(sink.shown, hasLength(1));
  });

  test('미제출로 남아 있으면 다음 구간에 다시 알린다', () async {
    source.values[1] = [
      DueAssignment(id: 'a', name: '과제 a', dueAt: now.add(const Duration(hours: 80)))
    ];
    await reminder().run();
    await tick(const Duration(hours: 56)); // 남은 24시간 → D-1
    expect(sink.shown.map((n) => n.stage), [DueStage.threeDays, DueStage.oneDay]);
  });

  test('제출해서 목록에서 빠지면 다음 구간은 보내지 않는다', () async {
    source.values[1] = [due('a', const Duration(hours: 80))];
    await reminder().run();
    source.values[1] = [];
    await tick(const Duration(hours: 56));
    expect(sink.shown, hasLength(1));
  });

  test('처음 켰을 때 이미 D-1이면 D-1만 보낸다', () async {
    source.values[1] = [due('a', const Duration(hours: 30))];
    await reminder().run();
    expect(sink.shown.single.stage, DueStage.oneDay);
  });

  test('마감이 바뀌면 새 마감 기준으로 다시 알린다', () async {
    final first = now.add(const Duration(hours: 30));
    source.values[1] = [DueAssignment(id: 'a', name: '과제 a', dueAt: first)];
    await reminder().run();
    source.values[1] = [
      DueAssignment(id: 'a', name: '과제 a', dueAt: first.add(const Duration(hours: 2)))
    ];
    await tick();
    expect(sink.shown.map((n) => n.stage), [DueStage.oneDay, DueStage.oneDay]);
    expect(sink.shown[0].id, isNot(sink.shown[1].id));
  });

  test('인증이 거부되면 마감 알림을 끈다', () async {
    source.authFailure = const AuthFailure();
    final status = await reminder().run();
    expect(status, '자동 로그인을 켜고 다시 로그인해 주세요.');
    expect((await store.settings())!.enabled, isFalse);
  });

  test('계정이 바뀌면 멈춘다', () async {
    source.owner = 'someone-else';
    final status = await reminder().run();
    expect(status, '계정이 변경되었습니다. 마감 알림을 다시 켜 주세요.');
    expect((await store.settings())!.enabled, isFalse);
  });

  test('한 강좌가 실패해도 다른 강좌는 알린다', () async {
    source.watched = const [WatchedCourse(1, '운영체제-01'), WatchedCourse(2, '네트워크-02')];
    source.failures.add(1);
    source.values[2] = [due('b', const Duration(hours: 5))];
    final status = await reminder().run();
    expect(sink.shown.single.courseId, 2);
    expect(status, '1개 강좌 확인 · 1개 강좌는 다음 주기에 재시도합니다.');
    expect((await store.settings())!.enabled, isTrue);
  });

  test('알림 권한이 없으면 보내지 않고 켜 둔다', () async {
    sink.allowed = false;
    source.values[1] = [due('a', const Duration(hours: 5))];
    final status = await reminder().run();
    expect(status, '기기 설정에서 알림 권한을 허용해 주세요.');
    expect(sink.shown, isEmpty);
    expect(source.logins, 0);
    expect((await store.settings())!.enabled, isTrue);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/notifications/due_reminder_test.dart`
Expected: FAIL — `due_reminder.dart` 없음

- [ ] **Step 3: 구현**

`lib/features/notifications/data/due_reminder.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:sqlite3/common.dart' show SqliteException;
import '../../../core/error/failure.dart';
import 'due_reminder_models.dart';
import 'due_reminder_store.dart';
import 'notification_schedule.dart';

/// 제출하지 않은 과제를 D-3·D-1·D-DAY 구간마다 한 번씩 알린다.
///
/// [source]의 수명은 부르는 쪽이 관리한다. 새 소식 알림과 로그인을 나눠
/// 쓰기 때문에 여기서 닫지 않는다.
class DueReminder {
  DueReminder(
      {required this.store,
      required this.source,
      required this.sink,
      DateTime Function()? clock,
      this.budget = const Duration(minutes: 2)})
      : clock = clock ?? DateTime.now;
  final DueReminderStore store;
  final DueSource source;
  final DueSink sink;
  final DateTime Function() clock;
  final Duration budget;

  /// 마감 알림을 보내는 회차. 새 소식과 같은 매시 01분이되 00:01은 뺀다.
  /// 23:59 마감이 흔해 구간 경계가 자정 직전에 몰리기 때문이다. 23:01 다음
  /// 회차는 08:01이라 쉬는 틈이 9시간이고 구간은 24시간이므로 놓치지 않는다.
  static DateTime? sendSlot(DateTime now) {
    final slot = NotificationSchedule.slot(now);
    if (slot == null) return null;
    final kstHour = slot.toUtc().add(NotificationSchedule.zone).hour;
    return kstHour == 0 ? null : slot;
  }

  Future<String> run() async {
    final slot = sendSlot(clock());
    if (slot == null) return '마감 알림은 08:01~23:01에 확인합니다.';
    final run = await store.acquire(clock(), slot);
    if (run == null) return '이번 회차는 이미 확인했거나 확인 중입니다.';
    var status = '확인하지 못했습니다. 다음 주기에 다시 시도합니다.';
    var success = false;
    var stage = '알림 권한 확인';
    final timer = Stopwatch()..start();
    try {
      if (!await sink.permitted()) {
        status = '기기 설정에서 알림 권한을 허용해 주세요.';
        return status;
      }
      stage = '자동 로그인';
      final owner = await source.authenticate();
      if (owner.toUpperCase().trim() != run.owner.toUpperCase().trim()) {
        status = '계정이 변경되었습니다. 마감 알림을 다시 켜 주세요.';
        await store.pause(run, status);
        return status;
      }
      stage = '강의 목록 조회';
      final courses = await source.courses();
      var sent = 0;
      var failed = 0;
      for (final course in courses) {
        if (!await store.current(run)) {
          status = '마감 알림 확인이 취소되었습니다.';
          return status;
        }
        if (timer.elapsed > budget) {
          status = '일부 강좌만 확인했습니다. 남은 강좌는 다음 주기에 확인합니다.';
          return status;
        }
        try {
          stage = '${course.name} 과제 조회';
          final assignments = await source.dueAssignments(course.id);
          for (final assignment in assignments) {
            final due = dueStageFor(assignment.dueAt, clock());
            if (due == null) continue;
            final key = dueReminderKey(course.id, assignment, due);
            if (await store.sent(key)) continue;
            stage = '기기 알림 표시';
            await sink.showDue(DueNotice(
                id: dueNotificationId(key),
                owner: run.owner,
                courseId: course.id,
                courseName: course.name,
                assignment: assignment,
                stage: due));
            stage = '알림 기록 저장';
            await store.markSent(key, clock());
            sent++;
          }
        } on Failure {
          // 한 강좌의 권한 오류·일시적 실패가 다른 강좌를 막지 않는다.
          failed++;
        }
      }
      success = failed == 0;
      status = failed == 0
          ? '${courses.length}개 강좌 확인 · 마감 알림 $sent개'
          : '${courses.length - failed}개 강좌 확인 · $failed개 강좌는 다음 주기에 재시도합니다.';
      return status;
    } on AuthFailure {
      status = '자동 로그인을 켜고 다시 로그인해 주세요.';
      await store.pause(run, status);
      return status;
    } on Failure {
      status = '학교 서버에 연결하지 못했습니다. 다음 주기에 재시도합니다.';
      return status;
    } on PlatformException catch (e) {
      // 제한된 식별자만 남긴다. 네이티브 원문 메시지는 넣지 않는다.
      final code = RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(e.code)
          ? e.code
          : 'platform_error';
      status = '$stage 실패 ($code). 다음 주기에 다시 시도합니다.';
      return status;
    } on SqliteException catch (e) {
      status = '$stage 실패 (저장소 ${e.resultCode}). 앱을 다시 열어 주세요.';
      return status;
    } on Exception {
      status = '$stage 중 오류가 발생했습니다. 다음 주기에 다시 시도합니다.';
      return status;
    } finally {
      await store.finish(run, clock(), status, success: success);
    }
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/notifications/due_reminder_test.dart`
Expected: PASS (11 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/data/due_reminder.dart test/features/notifications/due_reminder_test.dart
git commit -m "feat: 미제출 과제를 D-3·D-1·D-DAY에 알리는 러너를 추가한다"
```

---

### Task 5: 로그인과 과제 목록을 나눠 쓰는 세션

**Files:**
- Create: `lib/features/notifications/data/shared_lms_session.dart`
- Modify: `lib/features/notifications/data/lms_notification_source.dart` (클래스 선언, `items()`, 새 메서드)
- Test: `test/features/notifications/shared_lms_session_test.dart`

**Interfaces:**
- Consumes: `NotificationSource`, `WatchedCourse`, `WatchedItem`, `NoticeKind` (`notification_models.dart`); `DueSource`, `DueAssignment`, `parseDueAssignments` (Task 2)
- Produces:
  - `abstract interface class LmsSource implements NotificationSource, DueSource {}`
  - `class SharedLmsSession implements LmsSource { SharedLmsSession(LmsSource inner); void dispose(); }` — `authenticate()`·`courses()`는 첫 결과를 재사용, `close()`는 아무것도 안 함
  - `LmsNotificationSource implements LmsSource`, 새 메서드 `Future<List<DueAssignment>> dueAssignments(int courseId)`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/features/notifications/shared_lms_session_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/config/env.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/features/notifications/data/due_reminder_models.dart';
import 'package:kumoh_lms/features/notifications/data/lms_notification_source.dart';
import 'package:kumoh_lms/features/notifications/data/notification_models.dart';
import 'package:kumoh_lms/features/notifications/data/shared_lms_session.dart';

class CountingSource implements LmsSource {
  int logins = 0;
  int courseCalls = 0;
  bool closed = false;
  Failure? authFailure;

  @override
  Future<String> authenticate() async {
    logins++;
    if (authFailure != null) throw authFailure!;
    return 'student';
  }

  @override
  Future<List<WatchedCourse>> courses() async {
    courseCalls++;
    return const [WatchedCourse(1, '강좌')];
  }

  @override
  Future<List<WatchedItem>> items(int courseId, NoticeKind kind) async => const [];

  @override
  Future<List<DueAssignment>> dueAssignments(int courseId) async => const [];

  @override
  void close() => closed = true;
}

void main() {
  test('로그인과 강좌 목록은 한 번만 받는다', () async {
    final inner = CountingSource();
    final shared = SharedLmsSession(inner);
    expect(await shared.authenticate(), 'student');
    expect(await shared.authenticate(), 'student');
    await shared.courses();
    await shared.courses();
    expect(inner.logins, 1);
    expect(inner.courseCalls, 1);
  });

  test('로그인 실패도 한 번만 시도하고 같은 실패를 돌려준다', () async {
    final inner = CountingSource()..authFailure = const AuthFailure();
    final shared = SharedLmsSession(inner);
    await expectLater(shared.authenticate(), throwsA(isA<AuthFailure>()));
    await expectLater(shared.authenticate(), throwsA(isA<AuthFailure>()));
    expect(inner.logins, 1);
  });

  test('러너가 부르는 close는 무시하고 dispose에서 한 번 닫는다', () {
    final inner = CountingSource();
    final shared = SharedLmsSession(inner);
    shared.close();
    expect(inner.closed, isFalse);
    shared.dispose();
    expect(inner.closed, isTrue);
  });

  group('LmsNotificationSource 과제 목록', () {
    late Dio dio;
    late DioAdapter adapter;
    late int hits;
    late LmsNotificationSource source;

    setUp(() {
      dio = Dio();
      adapter = DioAdapter(dio: dio);
      hits = 0;
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        hits++;
        handler.next(options);
      }));
      source = LmsNotificationSource(InMemoryTokenStore(), canvasDio: dio);
      final url = Uri.parse('${Env.canvasApiBaseUrl}/courses/1/assignments')
          .replace(queryParameters: {'per_page': '100', 'include[]': 'submission'})
          .toString();
      adapter.onGet(
          url,
          (server) => server.reply(200, [
                {
                  'id': 7,
                  'name': '실습 과제',
                  'due_at': '2026-09-23T01:40:00Z',
                  'submission_types': ['online_upload'],
                  'submission': {'workflow_state': 'unsubmitted', 'submitted_at': null},
                },
              ]));
    });
    tearDown(() => dio.close(force: true));

    test('제출 상태를 함께 받아 마감 대상을 고른다', () async {
      final result = await source.dueAssignments(1);
      expect(result.single.id, '7');
      expect(result.single.name, '실습 과제');
    });

    test('새 과제 감지와 마감 알림이 같은 응답을 쓴다', () async {
      final items = await source.items(1, NoticeKind.assignment);
      final due = await source.dueAssignments(1);
      expect(items.single.id, '7');
      expect(due.single.id, '7');
      expect(hits, 1, reason: '한 실행 안에서 강좌마다 한 번만 요청한다');
    });
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/notifications/shared_lms_session_test.dart`
Expected: FAIL — `shared_lms_session.dart` 없음

- [ ] **Step 3: 공유 세션 구현**

`lib/features/notifications/data/shared_lms_session.dart`:

```dart
import 'due_reminder_models.dart';
import 'notification_models.dart';

/// 새 소식 알림과 마감 알림이 함께 쓰는 학교 서버 소스.
abstract interface class LmsSource implements NotificationSource, DueSource {}

/// 매시 작업에서 한 번만 로그인하게 하는 감싸개.
///
/// LINUS는 계정당 가장 최근 로그인 하나만 유효해서, 백그라운드가 로그인할
/// 때마다 학교 홈페이지와 다른 기기 세션이 끊긴다. 새 소식 poller와 마감
/// 러너가 같은 인스턴스를 받아 로그인과 강좌 목록을 나눠 쓴다.
class SharedLmsSession implements LmsSource {
  SharedLmsSession(this._inner);
  final LmsSource _inner;
  Future<String>? _login;
  Future<List<WatchedCourse>>? _courses;

  /// 첫 호출 결과(실패 포함)를 그대로 돌려준다. 로그인은 처음 필요할 때 한다.
  @override
  Future<String> authenticate() => _login ??= _inner.authenticate();

  @override
  Future<List<WatchedCourse>> courses() => _courses ??= _inner.courses();

  @override
  Future<List<WatchedItem>> items(int courseId, NoticeKind kind) =>
      _inner.items(courseId, kind);

  @override
  Future<List<DueAssignment>> dueAssignments(int courseId) =>
      _inner.dueAssignments(courseId);

  /// 러너가 끝날 때 부르는 close는 무시한다. 다른 러너가 아직 쓴다.
  @override
  void close() {}

  /// 작업이 모두 끝나면 부른다.
  void dispose() => _inner.close();
}
```

- [ ] **Step 4: 소스 수정**

`lib/features/notifications/data/lms_notification_source.dart`:

import 두 줄 추가(`import 'notification_models.dart';` 아래):

```dart
import 'due_reminder_models.dart';
import 'shared_lms_session.dart';
```

클래스 선언 `class LmsNotificationSource implements NotificationSource {`를 다음으로 바꾼다:

```dart
class LmsNotificationSource implements LmsSource {
```

`String? _deadCanvasToken;` 선언 바로 아래에 추가:

```dart

  /// 과제 목록은 새 과제 감지와 마감 알림이 같은 응답을 쓴다. 제출 상태를
  /// 함께 받아 두고, 한 실행 안에서는 강좌마다 한 번만 요청한다.
  final _assignmentRows = <int, Future<List<Map<String, dynamic>>>>{};

  Future<List<Map<String, dynamic>>> _assignments(int courseId) =>
      _assignmentRows[courseId] ??= fetchNotificationPages(
          _canvas, '/courses/$courseId/assignments',
          query: const {'include[]': 'submission'});

  @override
  Future<List<DueAssignment>> dueAssignments(int courseId) async =>
      parseDueAssignments(await _assignments(courseId));
```

`items()` 안의 `final json = await fetchNotificationPages(` … `});` 부분(현재 159-163행)을 다음으로 바꾼다:

```dart
    final json = kind == NoticeKind.assignment
        ? await _assignments(courseId)
        : await fetchNotificationPages(
            _canvas, '/courses/$courseId/$endpoint', query: {
            if (kind == NoticeKind.announcement) 'only_announcements': true,
            if (kind == NoticeKind.discussion) 'only_announcements': false,
          });
```

(`endpoint` switch는 그대로 둔다. assignment 분기에서는 쓰이지 않을 뿐이다.)

- [ ] **Step 5: 통과 확인**

Run: `flutter test test/features/notifications/`
Expected: 새 테스트와 기존 알림 테스트 모두 PASS

- [ ] **Step 6: Commit**

```bash
git add lib/features/notifications/data/shared_lms_session.dart lib/features/notifications/data/lms_notification_source.dart test/features/notifications/shared_lms_session_test.dart
git commit -m "feat: 새 소식과 마감 알림이 로그인과 과제 목록을 나눠 쓴다"
```

---

### Task 6: 매시 작업에 마감 알림 연결

**Files:**
- Modify: `lib/features/notifications/notification_runtime.dart`
- Modify: `lib/features/auth/presentation/auth_controller.dart:198-199, 269-270`
- Test: `test/features/notifications/due_runtime_test.dart`

**Interfaces:**
- Consumes: Task 2 `DueSink`, `DueNotice`, `DueSource`; Task 3 `DueReminderStore`; Task 4 `DueReminder`; Task 5 `SharedLmsSession`
- Produces:
  - `LocalNoticeSink implements NoticeSink, DueSink` + `Future<void> showDue(DueNotice)`
  - `static bool get NotificationRuntime.dueSupported` (= `isAndroidApp`)
  - `static Future<String> NotificationRuntime.poll(AppDatabase db, TokenStore secure, {bool force = false, NotificationSource? source})`
  - `static Future<String> NotificationRuntime.remindDue(AppDatabase db, DueSource source)`
  - `static Future<void> NotificationRuntime.stopDue(AppDatabase db)`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/features/notifications/due_runtime_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/notifications/data/due_reminder_store.dart';
import 'package:kumoh_lms/features/notifications/notification_runtime.dart';
import '../../helpers/test_db.dart';

void main() {
  test('마감 알림만 끈다', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    await DueReminderStore(db).enable('student');
    await NotificationRuntime.stopDue(db);
    expect((await DueReminderStore(db).settings())!.enabled, isFalse);
  });

  test('마감 알림을 누르면 강좌 과제 탭으로 간다', () {
    final destination = NotificationDestination.parse(jsonEncode({
      'owner': 'student',
      'courseId': 3,
      'courseName': '알고리즘및실습-01',
      'tab': 'assignments',
    }))!;
    final route = Uri.parse(destination.route);
    expect(route.path, '/courses/3');
    expect(route.queryParameters['tab'], 'assignments');
    expect(route.queryParameters['name'], '알고리즘및실습-01');
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/notifications/due_runtime_test.dart`
Expected: FAIL — `stopDue` 없음

- [ ] **Step 3: 런타임 수정**

`lib/features/notifications/notification_runtime.dart`

import 추가(`import 'data/notification_schedule.dart';` 아래):

```dart
import 'data/due_reminder.dart';
import 'data/due_reminder_models.dart';
import 'data/due_reminder_store.dart';
import 'data/shared_lms_session.dart';
```

`class LocalNoticeSink implements NoticeSink {`를 `class LocalNoticeSink implements NoticeSink, DueSink {`로 바꾸고, 클래스 안 `cancel` 메서드 앞에 추가:

```dart
  @override
  Future<void> showDue(DueNotice notice) async {
    if (!await permitted()) {
      throw Exception('Notification permission unavailable');
    }
    await plugin.show(
        id: notice.id,
        title: notice.heading,
        body: notice.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('lms_due', '과제 마감',
              channelDescription: '제출하지 않은 과제의 마감 3일 전·1일 전·당일 알림',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              visibility: NotificationVisibility.private),
          iOS:
              DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        payload: jsonEncode({
          'owner': notice.owner,
          'courseId': notice.courseId,
          'courseName': notice.courseName,
          'tab': NoticeKind.assignment.tab
        }));
  }
```

`class NotificationRuntime {` 안, `static bool get supported ...` 아래에 추가:

```dart
  /// 마감 알림은 Android에서만 돈다.
  static bool get dueSupported => isAndroidApp;
```

`hasBackgroundWork`를 다음으로 바꾼다:

```dart
  static Future<bool> hasBackgroundWork(AppDatabase db) async =>
      (await NotificationStore(db).settings())?.enabled == true ||
      (dueSupported &&
          (await DueReminderStore(db).settings())?.enabled == true) ||
      (isAndroidApp &&
          (await DownloadStore(db).settings())?.enabled == true);
```

`checkAll`과 `poll`을 다음으로 바꾸고, 그 아래에 `remindDue`, `stopDue`, `_lmsSource`를 추가한다:

```dart
  static LmsNotificationSource _lmsSource(TokenStore secure) =>
      LmsNotificationSource(secure, canvasTokenStore: SecureCanvasTokenStore());

  static Future<void> checkAll(AppDatabase db, TokenStore secure) async {
    final notices = (await NotificationStore(db).settings())?.enabled == true;
    final due = dueSupported &&
        (await DueReminderStore(db).settings())?.enabled == true;
    // LINUS는 최근 로그인 하나만 유효해서 로그인할 때마다 다른 기기 세션이
    // 끊긴다. 새 소식과 마감 알림이 한 세션을 쓰고, 로그인은 처음 필요할 때 한다.
    final shared =
        notices || due ? SharedLmsSession(_lmsSource(secure)) : null;
    try {
      try {
        if (notices) await poll(db, secure, source: shared);
      } finally {
        if (due) await remindDue(db, shared!);
      }
    } finally {
      shared?.dispose();
      if (isAndroidApp &&
          (await DownloadStore(db).settings())?.enabled == true) {
        await download(db, secure);
      }
    }
  }

  static Future<String> poll(AppDatabase db, TokenStore secure,
      {bool force = false, NotificationSource? source}) async {
    if (!supported) return '알림은 Android와 iOS에서 사용할 수 있습니다.';
    // A failed WorkManager initialization must not prevent manual checks.
    await sink.initialize(
        onTap: (payload) =>
            destination.value = NotificationDestination.parse(payload));
    return NotificationPoller(
      store: NotificationStore(db),
      sink: sink,
      sourceFactory: () => source ?? _lmsSource(secure),
      budget: isIOSApp
          ? const Duration(seconds: 20)
          : const Duration(minutes: 4),
    ).run(force: force);
  }

  static Future<String> remindDue(AppDatabase db, DueSource source) async {
    await sink.initialize(
        onTap: (payload) =>
            destination.value = NotificationDestination.parse(payload));
    return DueReminder(store: DueReminderStore(db), source: source, sink: sink)
        .run();
  }

  /// 마감 알림만 끈다. 새 소식이나 자동 다운로드가 켜져 있으면 예약은 둔다.
  /// 이미 뜬 알림은 지우지 않는다. 새 소식 알림까지 함께 지워지기 때문이다.
  static Future<void> stopDue(AppDatabase db) async {
    await DueReminderStore(db).disable();
    if (!await hasBackgroundWork(db)) await cancelScheduled();
  }
```

- [ ] **Step 4: 로그인·로그아웃에서 끄기**

`lib/features/auth/presentation/auth_controller.dart` — import 추가(`import '../../downloads/download_store.dart';` 아래):

```dart
import '../../notifications/data/due_reminder_store.dart';
```

`login()` 안(198행 근처):

```dart
      await DownloadStore(ref.read(appDatabaseProvider)).setEnabled(false);
      await NotificationRuntime.stop(ref.read(appDatabaseProvider));
```

를 다음으로 바꾼다(마감 알림을 먼저 꺼야 `stop()`이 남은 예약을 취소한다):

```dart
      await DownloadStore(ref.read(appDatabaseProvider)).setEnabled(false);
      await DueReminderStore(ref.read(appDatabaseProvider)).disable();
      await NotificationRuntime.stop(ref.read(appDatabaseProvider));
```

`logout()` 안(269행 근처):

```dart
        await DownloadStore(db).setEnabled(false);
        await NotificationRuntime.stop(db);
```

를 다음으로 바꾼다:

```dart
        await DownloadStore(db).setEnabled(false);
        await DueReminderStore(db).disable();
        await NotificationRuntime.stop(db);
```

- [ ] **Step 5: 통과 확인**

Run: `flutter test test/features/notifications/ test/features/auth/`
Expected: PASS

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/notifications/notification_runtime.dart lib/features/auth/presentation/auth_controller.dart test/features/notifications/due_runtime_test.dart
git commit -m "feat: 매시 작업에 마감 알림을 연결하고 로그인을 한 번으로 줄인다"
```

---

### Task 7: 설정 화면 토글

**Files:**
- Modify: `lib/features/notifications/presentation/notification_setup.dart` (`enableDueReminders` 추가)
- Create: `lib/features/notifications/presentation/due_reminder_tile.dart`
- Modify: `lib/features/notifications/presentation/notification_settings_section.dart` (import, 토글 배치)
- Test: `test/features/notifications/due_reminder_tile_test.dart`

**Interfaces:**
- Consumes: Task 3 `DueReminderStore`, `DueReminderSetting`; Task 6 `NotificationRuntime.stopDue`, `NotificationRuntime.dueSupported`; 기존 `hasMatchingCredentials`, `notificationSetupMessage`, `SettingsStatusCard`
- Produces:
  - `Future<String?> enableDueReminders(WidgetRef ref, {required bool Function() stillValid})`
  - `final dueRemindersSupportedProvider = Provider<bool>`
  - `final dueReminderSettingsProvider = StreamProvider<DueReminderSetting?>`
  - `class DueReminderTile extends ConsumerStatefulWidget` — 스위치 키 `Key('due_reminders')`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/features/notifications/due_reminder_tile_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/auth/data/auth_dto.dart';
import 'package:kumoh_lms/features/auth/presentation/auth_controller.dart';
import 'package:kumoh_lms/features/notifications/data/due_reminder_store.dart';
import 'package:kumoh_lms/features/notifications/presentation/due_reminder_tile.dart';
import 'package:kumoh_lms/providers.dart';
import '../../helpers/test_db.dart';

class _SignedIn extends AuthController {
  @override
  Future<AuthState> build() async => const AuthAuthenticated(
      profile: UserProfile(loginId: '20250000', name: '홍길동', role: 'student'));
}

void main() {
  late AppDatabase db;
  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Widget wrap({bool supported = true}) => ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          authControllerProvider.overrideWith(_SignedIn.new),
          dueRemindersSupportedProvider.overrideWithValue(supported),
        ],
        child: const MaterialApp(home: Scaffold(body: DueReminderTile())),
      );

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  SwitchListTile toggle(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.byKey(const Key('due_reminders')));

  /// 스위치를 누르고, 그 뒤의 실제 DB 작업이 끝날 때까지 기다린다.
  Future<void> tapToggle(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('due_reminders')));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
  }

  testWidgets('지원하지 않는 기기에서는 보이지 않는다', (tester) async {
    await tester.pumpWidget(wrap(supported: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('due_reminders')), findsNothing);
    await unmount(tester);
  });

  testWidgets('꺼져 있으면 상태 카드 없이 스위치만 보인다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(toggle(tester).value, isFalse);
    expect(find.text('과제 마감 알림'), findsOneWidget);
    expect(find.text('다음 확인부터 마감이 가까운 미제출 과제를 알려드립니다.'), findsNothing);
    await unmount(tester);
  });

  testWidgets('켜져 있으면 스위치와 상태를 보여준다', (tester) async {
    await tester.runAsync(() => DueReminderStore(db).enable('20250000'));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(toggle(tester).value, isTrue);
    expect(find.text('다음 확인부터 마감이 가까운 미제출 과제를 알려드립니다.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('자동 로그인 정보가 없으면 켜지 않고 안내한다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tapToggle(tester);
    expect(find.text('자동 로그인을 켜고 다시 로그인한 후 마감 알림을 켜 주세요.'), findsOneWidget);
    final saved = await tester.runAsync(() => DueReminderStore(db).settings());
    expect(saved?.enabled ?? false, isFalse);
    await unmount(tester);
  });

  testWidgets('끄면 저장소에서 꺼진다', (tester) async {
    await tester.runAsync(() => DueReminderStore(db).enable('20250000'));
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tapToggle(tester);
    final saved = await tester.runAsync(() => DueReminderStore(db).settings());
    expect(saved!.enabled, isFalse);
    expect(toggle(tester).value, isFalse);
    await unmount(tester);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/notifications/due_reminder_tile_test.dart`
Expected: FAIL — `due_reminder_tile.dart` 없음

- [ ] **Step 3: 켜는 절차 추가**

`lib/features/notifications/presentation/notification_setup.dart` — import 추가(`import '../data/notification_store.dart';` 아래):

```dart
import '../data/due_reminder_store.dart';
```

`enableNotifications` 함수 바로 아래에 추가:

```dart
/// 과제 마감 알림을 켠다. 켰으면 null, 못 켰으면 사용자에게 보여줄 안내를 돌려준다.
///
/// 새 소식 알림과 조건이 같다. 백그라운드가 저장된 자격증명으로 로그인하므로
/// 자동 로그인이 켜져 있어야 하고 알림 권한이 있어야 한다. 켜기만 하고 그
/// 자리에서 서버를 조회하지 않는다.
Future<String?> enableDueReminders(WidgetRef ref,
    {required bool Function() stillValid}) async {
  final db = ref.read(appDatabaseProvider);
  final tokens = ref.read(tokenStoreProvider);
  final auth = ref.read(authControllerProvider).valueOrNull;
  var stage = '자동 로그인 정보 확인';
  try {
    if (!await hasMatchingCredentials(auth, tokens)) {
      return '자동 로그인을 켜고 다시 로그인한 후 마감 알림을 켜 주세요.';
    }
    stage = '알림 기능 준비';
    await NotificationRuntime.initialize();
    stage = '알림 권한 요청';
    if (!await NotificationRuntime.sink.requestPermission()) {
      return '기기 설정에서 금오 LMS의 알림을 허용해 주세요.';
    }
    if (!stillValid() || ref.read(authControllerProvider).valueOrNull != auth) {
      return null;
    }
    stage = '마감 알림 설정 저장';
    final login = (auth! as AuthAuthenticated).profile.loginId;
    await DueReminderStore(db).enable(login);
    try {
      stage = '자동 확인 예약';
      await NotificationRuntime.schedule();
    } on Exception {
      await DueReminderStore(db).disable();
      rethrow;
    }
    return null;
  } on Exception catch (e) {
    return notificationSetupMessage(stage, e);
  }
}
```

- [ ] **Step 4: 토글 위젯 구현**

`lib/features/notifications/presentation/due_reminder_tile.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/storage/db/app_database.dart';
import '../../../core/ui/settings_widgets.dart';
import '../../../providers.dart';
import '../notification_runtime.dart';
import 'notification_settings_section.dart' show notificationSetupMessage;
import 'notification_setup.dart';

/// 마감 알림 토글을 보여줄 기기인가. 테스트에서 덮어쓴다.
final dueRemindersSupportedProvider =
    Provider<bool>((ref) => NotificationRuntime.dueSupported);

final dueReminderSettingsProvider =
    StreamProvider<DueReminderSetting?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.dueReminderSettings)..where((t) => t.id.equals(1)))
      .watchSingleOrNull();
});

/// 설정 화면의 "과제 마감 알림" 토글과 최근 확인 상태.
class DueReminderTile extends ConsumerStatefulWidget {
  const DueReminderTile({super.key});
  @override
  ConsumerState<DueReminderTile> createState() => _DueReminderTileState();
}

class _DueReminderTileState extends ConsumerState<DueReminderTile> {
  bool _busy = false;
  String? _message;

  Future<void> _change(bool enable) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (enable) {
        _message = await enableDueReminders(ref, stillValid: () => mounted);
      } else {
        await NotificationRuntime.stopDue(ref.read(appDatabaseProvider));
      }
    } on Exception catch (e) {
      _message = notificationSetupMessage('마감 알림 끄기', e);
    } finally {
      if (mounted) {
        ref.invalidate(dueReminderSettingsProvider);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(dueRemindersSupportedProvider)) {
      return const SizedBox.shrink();
    }
    final settings = ref.watch(dueReminderSettingsProvider);
    final config = settings.valueOrNull;
    String time(int? ms) => ms == null
        ? '아직 없음'
        : DateFormat('M/d HH:mm')
            .format(DateTime.fromMillisecondsSinceEpoch(ms));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SwitchListTile(
        key: const Key('due_reminders'),
        secondary: const Icon(Icons.alarm_outlined),
        title: const Text('과제 마감 알림'),
        subtitle: const Text('제출 안 한 과제를 마감 3일 전·1일 전·당일에 알려드려요'),
        value: config?.enabled ?? false,
        onChanged: _busy || settings.isLoading || settings.hasError
            ? null
            : _change,
      ),
      if (config?.enabled == true || _message != null || _busy)
        SettingsStatusCard(
          busy: _busy,
          active: config?.enabled == true,
          message: _busy
              ? '마감 알림 설정을 바꾸고 있습니다…'
              : _message ?? config!.status,
          detail: config?.lastAttempt == null
              ? null
              : '최근 완료 ${time(config!.lastSuccess)} · 시도 ${time(config.lastAttempt)}',
        ),
    ]);
  }
}
```

- [ ] **Step 5: 설정 화면에 배치**

`lib/features/notifications/presentation/notification_settings_section.dart` — import 추가(`import 'notification_setup.dart';` 아래):

```dart
import 'due_reminder_tile.dart';
```

`build()`의 `Column` children에서 `SettingsStatusCard(...)` 블록이 끝난 바로 뒤, `if (BackgroundSettings.supported)` 앞에 추가:

```dart
      const DueReminderTile(),
```

- [ ] **Step 6: 통과 확인**

Run: `flutter test test/features/notifications/due_reminder_tile_test.dart test/features/notifications/background_setup_screen_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/features/notifications/presentation/notification_setup.dart lib/features/notifications/presentation/due_reminder_tile.dart lib/features/notifications/presentation/notification_settings_section.dart test/features/notifications/due_reminder_tile_test.dart
git commit -m "feat: 설정에 과제 마감 알림 토글을 추가한다"
```

---

### Task 8: 문서와 전체 확인

**Files:**
- Modify: `docs/notifications.md`

- [ ] **Step 1: 문서 고치기**

`docs/notifications.md`의 다음 문장:

```
- 새 ID만 감지한다. 동일 ID의 본문 수정, 삭제, 마감 임박 알림은 포함하지 않는다. 파일 본문은 다운로드하지 않는다.
```

을 다음으로 바꾼다:

```
- 새 ID만 감지한다. 동일 ID의 본문 수정·삭제는 알리지 않는다. 마감이 가까운 미제출 과제는 아래 "과제 마감 알림"에서 따로 알린다. 파일 본문은 다운로드하지 않는다.
```

파일 끝에 추가:

```markdown
## 과제 마감 알림 (DB v9)

설정 → **과제 마감 알림**을 켜면 제출하지 않은 과제를 마감 3일 전·1일 전·당일에 한 번씩 알린다. 새 소식 알림과 따로 켜고 끈다. 켜는 조건(자동 로그인, 알림 권한)은 같다. Android에서만 동작한다.

- 구간은 과제 화면 배지와 같다. D-3은 남은 72~96시간, D-1은 24~48시간, D-DAY는 24시간 미만이다.
- 08:01~23:01 회차에서만 보낸다. 마감이 23:59인 과제가 많아 00:01에 보내면 한밤중에 울린다. 23:01 다음 회차가 08:01이고 구간 폭이 24시간이라 놓치는 구간은 없다.
- 과제·구간·마감 시각마다 한 번 보낸다. 제출하면 이후 구간은 보내지 않는다. 교수가 마감을 바꾸면 새 마감으로 다시 알린다. 처음 켰을 때 이미 D-1이면 D-1만 보낸다.
- 대상은 공개되고 잠기지 않은, 마감이 있는 미제출 과제다. 제출 방식이 "없음"·"지필"·"채점 안 함"뿐인 과제는 뺀다.
- 알림을 누르면 해당 강좌의 과제 탭이 열린다. Android 알림 채널은 "과제 마감"(`lms_due`)이다.
- 매시 작업에서 LINUS 로그인은 한 번만 한다. 새 소식과 마감 알림이 같은 세션과 같은 과제 목록 응답(`include[]=submission`)을 쓴다. LINUS는 계정당 가장 최근 로그인 하나만 유효해 로그인이 늘면 다른 기기 세션이 더 자주 끊기기 때문이다.
- 로그아웃하면 설정과 보낸 기록이 지워진다.

| 파일 | 역할 |
| --- | --- |
| `data/due_reminder_models.dart` | 구간 판정, 대상 선별, 기록 키, 알림 ID·문구 |
| `data/due_reminder_store.dart` | 설정, 회차 잠금, 보낸 기록 |
| `data/due_reminder.dart` | 러너 |
| `data/shared_lms_session.dart` | 로그인·강좌 목록 공유 |
| `presentation/due_reminder_tile.dart` | 설정 토글 |
```

- [ ] **Step 2: 전체 확인**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: 전부 PASS (기존 테스트 수 + 이번에 추가한 테스트)

Run: `flutter build apk --debug`
Expected: `√ Built build\app\outputs\flutter-apk\app-debug.apk`

- [ ] **Step 3: Commit**

```bash
git add docs/notifications.md
git commit -m "docs: 과제 마감 알림을 문서에 적는다"
```

- [ ] **Step 4: 실기기 확인 목록(자동화하지 않음, 사용자에게 보고)**

실제 학교 계정이 필요해 테스트로 대신할 수 없는 항목:

1. 설정에서 "과제 마감 알림"을 켜면 권한 요청 후 켜진다.
2. 마감 96시간 안쪽의 미제출 과제가 있으면 다음 08:01~23:01 회차에 `[마감 D-n] 강의명` 알림이 온다.
3. 알림을 누르면 해당 강좌 과제 탭이 열린다.
4. 새 소식 알림과 마감 알림을 둘 다 켜도 학교 홈페이지 로그인이 전보다 더 자주 끊기지 않는다.
5. Android 설정 → 앱 → 알림에 "과제 마감" 채널이 따로 보인다.
