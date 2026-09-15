# PWA 선택 동의 알림 서버 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 알림을 켠 PWA 사용자만 NAS의 `notifier` 컨테이너가 토큰으로 학교 LMS를 매시 조회해 새 글을 Web Push로 알린다.

**Architecture:** `notifier/`는 `relay/`와 분리된 Node 24 서비스다(`node:sqlite`, `web-push`, `tough-cookie`). 조회 규칙은 안드로이드 `LmsNotificationSource`를 JS로 옮기고, 두 쪽이 `test/fixtures/notifications/rules.json`을 함께 검증한다. Flutter 웹은 설정 화면에 웹 전용 알림 영역, 서비스 워커 `web/push_sw.js`, notifier API 클라이언트를 추가한다.

**Tech Stack:** Node 24 (`node:test`, `node:sqlite`, `node:crypto`), `web-push@3.6.7`, `tough-cookie@5.1.2`, Flutter 3.47.2, `dio`, `flutter_riverpod`, `package:web`.

## Global Constraints

- 설계 문서: `docs/superpowers/specs/2026-09-15-pwa-opt-in-notifier-design.md`
- 작업 위치: worktree `C:\Users\barah\Desktop\canvas\.claude\worktrees\pwa-relay`, 브랜치 `feat/pwa-notifier`. 메인 저장소 폴더로 이동하지 않는다.
- `relay/` 코드는 수정하지 않는다.
- 서버는 비밀번호를 받지 않는다. 토큰·학번·계정 키·글 제목·IP·푸시 주소를 로그에 남기지 않는다. 오류 로그는 `error.name`만 쓴다.
- 서버는 학교에 `/logout`을 보내지 않는다.
- LINUS 재발급은 `Authorization: Bearer <accessToken>`과 `X-Refresh-Token: <refreshToken>`을 함께 보낸다(2026-09-15 실험).
- 새 글 확인: 08:01~00:01 KST 매시(01~07시 제외), 계정별 분(1~30). 토큰 회전: 50분마다 24시간.
- 한 번에 새 글이 5건을 넘으면 "새 소식 N건" 한 건으로 묶는다.
- CORS/Origin 허용: `https://barahana25.github.io`만.
- 푸시 구독 endpoint 허용 호스트: `web.push.apple.com`, `*.push.apple.com`, `fcm.googleapis.com`, `updates.push.services.mozilla.com`, `*.notify.windows.com`.
- 공개 저장소다. `env`, `python/`, `sqlite3.dll`, 비밀 파일(`notifier/secrets*.json`)을 커밋하지 않는다.
- 커밋 메시지는 한국어, 끝에 `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- Flutter 명령: `C:\src\flutter\bin\flutter.bat`. Node 명령은 `notifier/`에서 `npm test`.

---

### Task 1: 앱 재발급 요청에 accessToken 함께 보내기

**Files:**
- Modify: `lib/features/auth/data/auth_api.dart:64-79`
- Modify: `lib/providers.dart` (`dioProvider`의 `reissue:` 인자)
- Test: `test/features/auth/auth_api_reissue_test.dart`

**Interfaces:**
- Produces: `Future<AuthTokens> AuthApi.reissue(String refreshToken, {String? accessToken})` — `accessToken`이 있으면 `Authorization: Bearer` 헤더를 붙인다. Task 9가 사용한다.

**실행 전 확인(결정 게이트):** 스크래치 폴더의 `expired_access.log`에서 만료된 accessToken 실험 결과를 본다.
- `만료 Bearer+refresh HTTP 200`이면 아래 코드를 그대로 쓴다.
- `만료 Bearer+refresh`가 실패하고 `refresh만`이 200이면, Step 3의 헤더를 "accessToken이 만료 전일 때만" 붙이도록 바꾸지 말고 **이 태스크를 멈추고 사용자에게 보고한다**(서버 설계의 회전 방식도 다시 봐야 한다).

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/features/auth/data/auth_api.dart';

import '../../fixtures/fixtures.dart';

/// LINUS /reissue는 refreshToken만 보내면 401 T003으로 거부한다.
/// accessToken(Bearer)을 함께 보내야 새 토큰을 준다(2026-09-15 실계정 실험).
void main() {
  test('재발급 요청에 Bearer accessToken과 X-Refresh-Token을 함께 보낸다', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://lms.example.test/api/v1'));
    final adapter = DioAdapter(dio: dio);
    Map<String, dynamic>? sent;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      sent = o.headers;
      h.next(o);
    }));
    adapter.onPost('/reissue', (s) => s.reply(200, loginSuccessJson));

    await AuthApi(dio).reissue('refresh-1', accessToken: 'access-1');

    expect(sent!['Authorization'], 'Bearer access-1');
    expect(sent!['X-Refresh-Token'], 'refresh-1');
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `C:\src\flutter\bin\flutter.bat test test/features/auth/auth_api_reissue_test.dart`
Expected: FAIL (`No named parameter with the name 'accessToken'`)

- [ ] **Step 3: 구현**

`lib/features/auth/data/auth_api.dart`의 `reissue`를 바꾼다.

```dart
  /// refreshToken은 X-Refresh-Token 헤더로, accessToken은 Bearer로 함께 보낸다.
  /// refreshToken만 보내면 서버가 401 T003으로 거부한다.
  Future<AuthTokens> reissue(String refreshToken, {String? accessToken}) async {
    try {
      final res = await _dio.post<Object?>(
        '/reissue',
        options: Options(headers: {
          'X-Refresh-Token': refreshToken,
          if (accessToken != null && accessToken.isNotEmpty)
            'Authorization': 'Bearer $accessToken',
        }),
      );
      return unwrapEnvelope<AuthTokens>(
        res.data,
          (d) => AuthTokens.fromJson(d! as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }
```

`lib/providers.dart`의 `dioProvider`에서 `reissue: authApi.reissue,`를 바꾼다.

```dart
    reissue: (refresh) async => authApi.reissue(refresh,
        accessToken: await store.readAccessToken()),
```

- [ ] **Step 4: 통과 확인**

Run: `C:\src\flutter\bin\flutter.bat test test/features/auth/auth_api_reissue_test.dart test/core`
Expected: PASS

Run: `C:\src\flutter\bin\flutter.bat analyze`
Expected: `No issues found!`

- [ ] **Step 5: 커밋**

```bash
git add lib/features/auth/data/auth_api.dart lib/providers.dart test/features/auth/auth_api_reissue_test.dart
git commit -m "fix: 토큰 재발급에 accessToken을 함께 보낸다

LINUS /reissue는 refreshToken만 보내면 401 T003으로 거부한다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: 조회 규칙 공유 예시와 Node 규칙 모듈

**Files:**
- Create: `test/fixtures/notifications/rules.json`
- Create: `test/features/notifications/notification_rules_fixture_test.dart`
- Create: `notifier/package.json`, `notifier/.gitignore`, `notifier/.dockerignore`
- Create: `notifier/src/errors.mjs`, `notifier/src/rules.mjs`
- Test: `notifier/test/rules.test.mjs`

**Interfaces:**
- Produces (`notifier/src/errors.mjs`): `class AuthRevokedError extends Error`, `class SchoolError extends Error { status?: number }`
- Produces (`notifier/src/rules.mjs`):
  - `KINDS: ["announcement","file","assignment","discussion"]`
  - `KIND_INFO[kind] = { label, tab, badge, endpoint, query }`
  - `parseWatchedItems(rows, kind, now = new Date()) -> {id: string, title: string}[]` (ID 없으면 `SchoolError`)
  - `INSTRUCTOR_TYPES`, `parseInstructorIds(rows) -> Set<number>`, `isInstructorPost(row, ids, teacherNames = "") -> boolean`
  - `parseServerDate(raw) -> Date|null`, `pickTerm(terms, now) -> term|null`
  - `heading(kind, courseName) -> string`

- [ ] **Step 1: 공유 예시 파일 작성** — `test/fixtures/notifications/rules.json`

```json
{
  "watchedItems": [
    {
      "name": "토론 목록에서 공지와 숨김 글을 뺀다",
      "kind": "discussion",
      "rows": [
        {"id": 1, "title": "새 토론", "is_announcement": false},
        {"id": 2, "title": "공지", "is_announcement": true},
        {"id": 3, "title": "숨김", "hidden": true}
      ],
      "expectedIds": ["1"],
      "expectedTitles": ["새 토론"]
    },
    {
      "name": "잠김·숨김·미게시 파일을 뺀다",
      "kind": "file",
      "rows": [
        {"id": 1, "display_name": "보이는 파일"},
        {"id": 2, "locked_for_user": true},
        {"id": 3, "hidden_for_user": true},
        {"id": 4, "published": false},
        {"id": 5, "filename": "a.pdf"}
      ],
      "expectedIds": ["1", "5"],
      "expectedTitles": ["보이는 파일", "a.pdf"]
    },
    {
      "name": "예약 게시 전 공지는 빼고 제목이 없으면 종류와 번호를 쓴다",
      "kind": "announcement",
      "rows": [
        {"id": 10, "title": "예약 공지", "delayed_post_at": "2999-01-01T00:00:00Z"},
        {"id": 11, "title": "지난 공지", "delayed_post_at": "2000-01-01T00:00:00Z"},
        {"id": 12, "title": null}
      ],
      "expectedIds": ["11", "12"],
      "expectedTitles": ["지난 공지", "공지 #12"]
    },
    {
      "name": "과제는 name을 제목으로 쓴다",
      "kind": "assignment",
      "rows": [{"id": 5, "name": "과제1"}],
      "expectedIds": ["5"],
      "expectedTitles": ["과제1"]
    }
  ],
  "watchedItemErrors": [
    {"name": "ID 없는 목록은 거부한다", "kind": "assignment", "rows": [{"name": "ID 없음"}]}
  ],
  "instructorIds": [
    {
      "rows": [
        {"type": "TeacherEnrollment", "user_id": 1},
        {"type": "TaEnrollment", "user": {"id": 2}},
        {"type": "StudentEnrollment", "user_id": 3}
      ],
      "expected": [1, 2]
    }
  ],
  "instructorPosts": [
    {"row": {"author": {"id": 1}}, "ids": [1], "teacherNames": "", "expected": true},
    {"row": {"author": {"id": 3}}, "ids": [1], "teacherNames": "", "expected": false},
    {"row": {"author": {"id": 9, "display_name": "김교수"}}, "ids": [], "teacherNames": "김교수, 이조교", "expected": true},
    {"row": {"author": {"id": 9, "display_name": "김교"}}, "ids": [], "teacherNames": "김교수", "expected": false}
  ]
}
```

- [ ] **Step 2: Dart 쪽 예시 테스트 작성** — `test/features/notifications/notification_rules_fixture_test.dart`

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_api.dart';
import 'package:kumoh_lms/features/notifications/data/lms_notification_source.dart';
import 'package:kumoh_lms/features/notifications/data/notification_models.dart';

/// notifier/test/rules.test.mjs와 같은 파일을 쓴다. 한쪽 규칙만 바뀌면 둘 중 하나가 실패한다.
void main() {
  final fixture = jsonDecode(
          File('test/fixtures/notifications/rules.json').readAsStringSync())
      as Map<String, dynamic>;

  for (final c in (fixture['watchedItems'] as List).cast<Map<String, dynamic>>()) {
    test('공유 규칙: ${c['name']}', () {
      final items = parseWatchedItems(
          (c['rows'] as List).cast<Map<String, dynamic>>(),
          NoticeKind.values.byName(c['kind'] as String));
      expect(items.map((i) => i.id).toList(), c['expectedIds']);
      expect(items.map((i) => i.title).toList(), c['expectedTitles']);
    });
  }

  for (final c
      in (fixture['watchedItemErrors'] as List).cast<Map<String, dynamic>>()) {
    test('공유 규칙: ${c['name']}', () {
      expect(
          () => parseWatchedItems(
              (c['rows'] as List).cast<Map<String, dynamic>>(),
              NoticeKind.values.byName(c['kind'] as String)),
          throwsA(isA<ParseFailure>()));
    });
  }

  test('공유 규칙: 강의자 ID와 강의자 글 판별', () {
    for (final c in (fixture['instructorIds'] as List).cast<Map<String, dynamic>>()) {
      expect(parseInstructorIds(c['rows']), (c['expected'] as List).toSet());
    }
    for (final c
        in (fixture['instructorPosts'] as List).cast<Map<String, dynamic>>()) {
      expect(
          isInstructorPost(c['row'] as Map<String, dynamic>,
              (c['ids'] as List).cast<int>().toSet(),
              teacherNames: c['teacherNames'] as String),
          c['expected']);
    }
  });
}
```

- [ ] **Step 3: Dart 테스트 통과 확인** (기존 규칙을 기록한 예시라 바로 통과해야 한다)

Run: `C:\src\flutter\bin\flutter.bat test test/features/notifications/notification_rules_fixture_test.dart`
Expected: PASS. 실패하면 예시 값이 아니라 기존 Dart 동작을 기준으로 예시를 고친다.

- [ ] **Step 4: Node 패키지 뼈대**

`notifier/package.json`:

```json
{
  "name": "kumoh-lms-notifier",
  "private": true,
  "type": "module",
  "engines": { "node": ">=24" },
  "scripts": {
    "start": "node src/main.mjs",
    "test": "node --test"
  },
  "dependencies": {
    "tough-cookie": "5.1.2",
    "web-push": "3.6.7"
  }
}
```

`notifier/.gitignore`:

```
node_modules/
secrets*.json
*.sqlite
```

`notifier/.dockerignore`:

```
node_modules
test
secrets*.json
*.sqlite
```

Run (notifier/): `npm install`
Expected: `package-lock.json` 생성

- [ ] **Step 5: Node 실패 테스트 작성** — `notifier/test/rules.test.mjs`

```js
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { SchoolError } from "../src/errors.mjs";
import {
  heading,
  isInstructorPost,
  parseInstructorIds,
  parseServerDate,
  parseWatchedItems,
  pickTerm,
} from "../src/rules.mjs";

// Flutter 테스트(test/features/notifications/notification_rules_fixture_test.dart)와 같은 파일이다.
const fixture = JSON.parse(
  readFileSync(new URL("../../test/fixtures/notifications/rules.json", import.meta.url), "utf8"),
);

for (const c of fixture.watchedItems) {
  test(`공유 규칙: ${c.name}`, () => {
    const items = parseWatchedItems(c.rows, c.kind);
    assert.deepEqual(items.map((i) => i.id), c.expectedIds);
    assert.deepEqual(items.map((i) => i.title), c.expectedTitles);
  });
}

for (const c of fixture.watchedItemErrors) {
  test(`공유 규칙: ${c.name}`, () => {
    assert.throws(() => parseWatchedItems(c.rows, c.kind), SchoolError);
  });
}

test("공유 규칙: 강의자 ID와 강의자 글 판별", () => {
  for (const c of fixture.instructorIds) {
    assert.deepEqual([...parseInstructorIds(c.rows)].sort(), c.expected);
  }
  for (const c of fixture.instructorPosts) {
    assert.equal(isInstructorPost(c.row, new Set(c.ids), c.teacherNames), c.expected);
  }
});

test("시간대가 없는 서버 날짜는 한국 시간으로 읽는다", () => {
  assert.equal(parseServerDate("2026-09-01T00:00:00").toISOString(), "2026-08-31T15:00:00.000Z");
  assert.equal(parseServerDate("2026-09-01T00:00:00Z").toISOString(), "2026-09-01T00:00:00.000Z");
  assert.equal(parseServerDate(""), null);
  assert.equal(parseServerDate(null), null);
});

test("현재 날짜가 들어 있는 학기를 고르고, 없으면 ID가 가장 큰 학기를 고른다", () => {
  const terms = [
    { id: 1, startAt: "2026-03-01T00:00:00", endAt: "2026-06-30T00:00:00" },
    { id: 3, startAt: "2027-03-01T00:00:00", endAt: "2027-06-30T00:00:00" },
    { id: 2, startAt: "2026-09-01T00:00:00", endAt: "2026-12-31T00:00:00" },
  ];
  assert.equal(pickTerm(terms, new Date("2026-09-15T00:00:00Z")).id, 2);
  assert.equal(pickTerm(terms, new Date("2028-01-01T00:00:00Z")).id, 3);
  assert.equal(pickTerm([], new Date()), null);
});

test("알림 제목은 분류를 붙이고 강좌명의 분반 번호를 뗀다", () => {
  assert.equal(heading("file", "운영체제-01"), "[새 파일] 운영체제");
  assert.equal(heading("announcement", "자료구조"), "[공지] 자료구조");
});
```

Run (notifier/): `npm test`
Expected: FAIL (`Cannot find module '../src/errors.mjs'`)

- [ ] **Step 6: 구현** — `notifier/src/errors.mjs`

```js
// 학교 서버가 이 계정의 세션을 끊었다(로그아웃, 토큰 무효). 등록을 지워야 한다.
export class AuthRevokedError extends Error {
  constructor(message) {
    super(message);
    this.name = "AuthRevokedError";
  }
}

// 일시적인 학교 서버 오류나 예상 밖 응답. 다음 회차에 다시 시도한다.
export class SchoolError extends Error {
  constructor(message, status) {
    super(message);
    this.name = "SchoolError";
    this.status = status;
  }
}
```

`notifier/src/rules.mjs`:

```js
import { SchoolError } from "./errors.mjs";

// 안드로이드 lib/features/notifications/data/notification_models.dart의 NoticeKind와 같은 순서·값.
export const KINDS = ["announcement", "file", "assignment", "discussion"];

export const KIND_INFO = {
  announcement: {
    label: "공지", tab: "announcements", badge: "공지",
    endpoint: "discussion_topics", query: { only_announcements: "true" },
  },
  file: { label: "파일", tab: "files", badge: "새 파일", endpoint: "files", query: {} },
  assignment: { label: "과제", tab: "assignments", badge: "과제", endpoint: "assignments", query: {} },
  discussion: {
    label: "토론", tab: "discussions", badge: "토론",
    endpoint: "discussion_topics", query: { only_announcements: "false" },
  },
};

// lms_notification_source.dart의 parseWatchedItems와 같은 규칙.
export function parseWatchedItems(rows, kind, now = new Date()) {
  const result = [];
  for (const row of rows) {
    if (kind === "discussion" && row.is_announcement === true) continue;
    if (
      row.published === false ||
      row.locked_for_user === true ||
      row.hidden_for_user === true ||
      row.hidden === true
    ) {
      continue;
    }
    if (kind === "announcement" || kind === "discussion") {
      const delayed = Date.parse(String(row.delayed_post_at));
      if (!Number.isNaN(delayed) && delayed > now.getTime()) continue;
    }
    if (row.id === undefined || row.id === null || `${row.id}` === "") {
      throw new SchoolError("항목 ID가 없는 목록");
    }
    const title = {
      announcement: row.title,
      file: row.display_name ?? row.filename,
      assignment: row.name,
      discussion: row.title,
    }[kind];
    result.push({
      id: `${row.id}`,
      title: typeof title === "string" && title !== "" ? title : `${KIND_INFO[kind].label} #${row.id}`,
    });
  }
  return result;
}

export const INSTRUCTOR_TYPES = ["TeacherEnrollment", "TaEnrollment"];

export function parseInstructorIds(rows) {
  const ids = new Set();
  for (const e of rows) {
    if (!INSTRUCTOR_TYPES.includes(e.type)) continue;
    const id = e.user_id ?? e.user?.id;
    if (typeof id === "number") ids.add(Math.trunc(id));
  }
  return ids;
}

export function isInstructorPost(row, ids, teacherNames = "") {
  const author = row.author;
  const id = (author && typeof author === "object" ? author.id : undefined) ?? row.user_id;
  if (typeof id === "number" && ids.has(Math.trunc(id))) return true;
  const name = author && typeof author === "object" ? author.display_name : row.user_name;
  if (typeof name !== "string" || name.trim() === "") return false;
  return teacherNames.split(",").map((n) => n.trim()).includes(name.trim());
}

// reference_api.dart의 parseServerDate: 시간대가 없으면 한국 시간이다.
export function parseServerDate(raw) {
  if (typeof raw !== "string" || raw === "") return null;
  const hasZone = raw.endsWith("Z") || /[+-]\d{2}:?\d{2}$/.test(raw);
  const ms = Date.parse(hasZone ? raw : `${raw}+09:00`);
  return Number.isNaN(ms) ? null : new Date(ms);
}

// lms_notification_source.dart의 courses(): 현재 학기, 없으면 ID가 가장 큰 학기.
export function pickTerm(terms, now) {
  if (terms.length === 0) return null;
  const sorted = [...terms].sort((a, b) => b.id - a.id);
  const current = sorted.find((t) => {
    const start = parseServerDate(t.startAt);
    const end = parseServerDate(t.endAt);
    return start && end && now >= start && now <= end;
  });
  return current ?? sorted[0];
}

// notification_models.dart의 PendingNotice.heading.
export function heading(kind, courseName) {
  return `[${KIND_INFO[kind].badge}] ${courseName.replace(/-\d+$/, "")}`;
}
```

- [ ] **Step 7: 통과 확인**

Run (notifier/): `npm test`
Expected: PASS (모든 테스트)

- [ ] **Step 8: 커밋**

```bash
git add test/fixtures/notifications/rules.json test/features/notifications/notification_rules_fixture_test.dart notifier/package.json notifier/package-lock.json notifier/.gitignore notifier/.dockerignore notifier/src/errors.mjs notifier/src/rules.mjs notifier/test/rules.test.mjs
git commit -m "feat: 알림 서버 조회 규칙과 안드로이드 공유 예시

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---
### Task 3: 암호화와 저장소

**Files:**
- Create: `notifier/src/crypto.mjs`, `notifier/src/store.mjs`
- Test: `notifier/test/crypto.test.mjs`, `notifier/test/store.test.mjs`

**Interfaces:**
- Produces (`crypto.mjs`):
  - `createSealer(key: Buffer(32)) -> { seal(value) -> string, open(text) -> value }` (AES-256-GCM, 변조 시 throw)
  - `accountKeyFor(hmacKey: Buffer, loginId: string) -> string` (hex)
  - `newDeviceId() -> string` (32 hex), `newDeleteSecret() -> string` (base64url 43자)
  - `hashSecret(secret) -> string` (hex), `secretMatches(secret, hash) -> boolean`
  - `slotMinuteFor(accountKey) -> 1..30`
- Produces (`store.mjs`): `openStore({ path, sealer }) -> Store`
  - `saveAccount({accountKey, tokens, now})`
  - `getAccount(accountKey) -> Account|null`, `listAccounts() -> Account[]`, `countAccounts() -> number`
  - `Account = {accountKey, tokens: {accessToken, refreshToken}, slotMinute, lastCheckSlot: number|null, lastRotatedAt: number, lastSuccessAt: number|null, lastFailure: string|null}`
  - `updateTokens(accountKey, tokens, now)`
  - `markChecked(accountKey, {slot, now, failure})` (`failure`가 null이면 성공)
  - `addDevice({id, accountKey, deleteSecretHash, subscription, now})`
  - `getDevice(id) -> {id, accountKey, deleteSecretHash} | null`
  - `listDevices(accountKey) -> {id, subscription}[]`
  - `deleteDevice(id)` (계정의 마지막 기기면 계정도 지운다)
  - `deleteAccount(accountKey)`
  - `recordItems(accountKey, courseId, kind, itemIds: string[]) -> string[]` (기준점이 이미 있을 때만 새 ID를 돌려준다)
  - `rawRowsForTest()`, `close()`

- [ ] **Step 1: 실패 테스트** — `notifier/test/crypto.test.mjs`

```js
import test from "node:test";
import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import {
  accountKeyFor,
  createSealer,
  hashSecret,
  newDeleteSecret,
  newDeviceId,
  secretMatches,
  slotMinuteFor,
} from "../src/crypto.mjs";

test("봉인한 값을 그대로 연다", () => {
  const sealer = createSealer(randomBytes(32));
  const value = { accessToken: "a.b.c", refreshToken: "d.e.f" };
  const sealed = sealer.seal(value);
  assert.ok(!sealed.includes("a.b.c"));
  assert.deepEqual(sealer.open(sealed), value);
});

test("변조했거나 다른 키로 봉인한 값은 열지 않는다", () => {
  const sealer = createSealer(randomBytes(32));
  const sealed = Buffer.from(sealer.seal({ x: 1 }), "base64");
  sealed[sealed.length - 1] ^= 1;
  assert.throws(() => sealer.open(sealed.toString("base64")));
  assert.throws(() => createSealer(randomBytes(32)).open(sealer.seal({ x: 1 })));
});

test("32바이트가 아닌 키는 거부한다", () => {
  assert.throws(() => createSealer(randomBytes(16)));
});

test("계정 키는 학번 대소문자·공백과 무관하고 학번을 드러내지 않는다", () => {
  const key = randomBytes(32);
  assert.equal(accountKeyFor(key, " s20250001 "), accountKeyFor(key, "S20250001"));
  assert.ok(!accountKeyFor(key, "S20250001").includes("20250001"));
  assert.notEqual(accountKeyFor(randomBytes(32), "S20250001"), accountKeyFor(key, "S20250001"));
});

test("삭제 비밀 값은 해시로만 비교한다", () => {
  const secret = newDeleteSecret();
  assert.equal(secret.length, 43);
  assert.equal(newDeviceId().length, 32);
  assert.ok(secretMatches(secret, hashSecret(secret)));
  assert.ok(!secretMatches(newDeleteSecret(), hashSecret(secret)));
});

test("조회 분은 1~30 사이에 퍼진다", () => {
  const seen = new Set();
  for (let i = 0; i < 300; i++) {
    const m = slotMinuteFor(accountKeyFor(randomBytes(32), `S${i}`));
    assert.ok(m >= 1 && m <= 30);
    seen.add(m);
  }
  assert.ok(seen.size >= 25);
});
```

Run (notifier/): `npm test`
Expected: FAIL (`Cannot find module '../src/crypto.mjs'`)

- [ ] **Step 2: 구현** — `notifier/src/crypto.mjs`

```js
import {
  createCipheriv,
  createDecipheriv,
  createHash,
  createHmac,
  randomBytes,
  timingSafeEqual,
} from "node:crypto";

// 토큰과 푸시 구독을 디스크에 암호화해 둔다. 키가 같은 NAS에 있으므로
// 운영자로부터가 아니라 디스크·백업 유출로부터 보호하는 장치다.
export function createSealer(key) {
  if (!Buffer.isBuffer(key) || key.length !== 32) {
    throw new Error("토큰 암호화 키는 32바이트여야 합니다.");
  }
  return {
    seal(value) {
      const iv = randomBytes(12);
      const cipher = createCipheriv("aes-256-gcm", key, iv);
      const data = Buffer.concat([cipher.update(JSON.stringify(value), "utf8"), cipher.final()]);
      return Buffer.concat([iv, cipher.getAuthTag(), data]).toString("base64");
    },
    open(text) {
      const buf = Buffer.from(text, "base64");
      const decipher = createDecipheriv("aes-256-gcm", key, buf.subarray(0, 12));
      decipher.setAuthTag(buf.subarray(12, 28));
      const data = Buffer.concat([decipher.update(buf.subarray(28)), decipher.final()]);
      return JSON.parse(data.toString("utf8"));
    },
  };
}

// 학번 원문 대신 저장하는 계정 구분값.
export function accountKeyFor(hmacKey, loginId) {
  return createHmac("sha256", hmacKey).update(loginId.trim().toUpperCase()).digest("hex");
}

export const newDeviceId = () => randomBytes(16).toString("hex");
export const newDeleteSecret = () => randomBytes(32).toString("base64url");
export const hashSecret = (secret) => createHash("sha256").update(secret).digest("hex");

export function secretMatches(secret, hash) {
  if (typeof secret !== "string" || typeof hash !== "string") return false;
  const a = Buffer.from(hashSecret(secret), "hex");
  const b = Buffer.from(hash, "hex");
  return a.length === b.length && timingSafeEqual(a, b);
}

// 학교 서버에 한꺼번에 몰리지 않도록 계정마다 매시 1~30분 중 하나에 조회한다.
export function slotMinuteFor(accountKey) {
  return 1 + (Number.parseInt(accountKey.slice(0, 8), 16) % 30);
}
```

Run (notifier/): `npm test`
Expected: crypto 테스트 PASS

- [ ] **Step 3: 저장소 실패 테스트** — `notifier/test/store.test.mjs`

```js
import test from "node:test";
import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { createSealer } from "../src/crypto.mjs";
import { openStore } from "../src/store.mjs";

const tokens = { accessToken: "access", refreshToken: "refresh" };
const subscription = { endpoint: "https://web.push.apple.com/abc", keys: { p256dh: "p", auth: "a" } };

function newStore() {
  return openStore({ path: ":memory:", sealer: createSealer(randomBytes(32)) });
}

test("계정과 기기를 저장하고 토큰·구독은 암호화해 둔다", () => {
  const store = newStore();
  store.saveAccount({ accountKey: "aa11", tokens, now: 1000 });
  store.addDevice({ id: "d1", accountKey: "aa11", deleteSecretHash: "h", subscription, now: 1000 });

  const account = store.getAccount("aa11");
  assert.deepEqual(account.tokens, tokens);
  assert.equal(account.lastRotatedAt, 1000);
  assert.ok(account.slotMinute >= 1 && account.slotMinute <= 30);
  assert.deepEqual(store.listDevices("aa11"), [{ id: "d1", subscription }]);
  assert.deepEqual(store.getDevice("d1"), { id: "d1", accountKey: "aa11", deleteSecretHash: "h" });

  const raw = JSON.stringify(store.rawRowsForTest());
  assert.ok(!raw.includes("access"));
  assert.ok(!raw.includes("web.push.apple.com"));
  store.close();
});

test("같은 계정을 다시 저장하면 토큰만 바꾸고 기록은 유지한다", () => {
  const store = newStore();
  store.saveAccount({ accountKey: "aa11", tokens, now: 1000 });
  store.markChecked("aa11", { slot: 5, now: 2000, failure: null });
  store.saveAccount({ accountKey: "aa11", tokens: { accessToken: "a2", refreshToken: "r2" }, now: 3000 });
  const account = store.getAccount("aa11");
  assert.equal(account.tokens.accessToken, "a2");
  assert.equal(account.lastSuccessAt, 2000);
  assert.equal(store.countAccounts(), 1);
  store.close();
});

test("마지막 기기를 지우면 계정과 본 글 기록도 지운다", () => {
  const store = newStore();
  store.saveAccount({ accountKey: "aa11", tokens, now: 1 });
  store.addDevice({ id: "d1", accountKey: "aa11", deleteSecretHash: "h", subscription, now: 1 });
  store.addDevice({ id: "d2", accountKey: "aa11", deleteSecretHash: "h", subscription, now: 1 });
  store.recordItems("aa11", 7, "file", ["1"]);

  store.deleteDevice("d1");
  assert.ok(store.getAccount("aa11"));
  store.deleteDevice("d2");
  assert.equal(store.getAccount("aa11"), null);
  store.saveAccount({ accountKey: "aa11", tokens, now: 2 });
  assert.deepEqual(store.recordItems("aa11", 7, "file", ["1"]), []);
  store.close();
});

test("처음 본 강좌·종류는 기준점만 저장하고 이후 새 ID만 돌려준다", () => {
  const store = newStore();
  store.saveAccount({ accountKey: "aa11", tokens, now: 1 });
  assert.deepEqual(store.recordItems("aa11", 7, "file", ["1", "2"]), []);
  assert.deepEqual(store.recordItems("aa11", 7, "file", ["1", "2", "3"]), ["3"]);
  assert.deepEqual(store.recordItems("aa11", 7, "file", ["3"]), []);
  assert.deepEqual(store.recordItems("aa11", 7, "assignment", ["3"]), []);
  store.close();
});

test("확인 결과와 회전 시각을 기록한다", () => {
  const store = newStore();
  store.saveAccount({ accountKey: "aa11", tokens, now: 1 });
  store.markChecked("aa11", { slot: 100, now: 200, failure: null });
  store.markChecked("aa11", { slot: 101, now: 300, failure: "학교 서버에 연결하지 못했어요" });
  const account = store.getAccount("aa11");
  assert.equal(account.lastCheckSlot, 101);
  assert.equal(account.lastSuccessAt, 200);
  assert.equal(account.lastFailure, "학교 서버에 연결하지 못했어요");
  store.updateTokens("aa11", { accessToken: "n", refreshToken: "m" }, 400);
  assert.equal(store.getAccount("aa11").lastRotatedAt, 400);
  store.close();
});
```

Run (notifier/): `npm test`
Expected: FAIL (`Cannot find module '../src/store.mjs'`)

- [ ] **Step 4: 구현** — `notifier/src/store.mjs`

```js
import { DatabaseSync } from "node:sqlite";
import { slotMinuteFor } from "./crypto.mjs";

const SCHEMA = `
CREATE TABLE IF NOT EXISTS accounts (
  account_key TEXT PRIMARY KEY,
  tokens TEXT NOT NULL,
  slot_minute INTEGER NOT NULL,
  last_check_slot INTEGER,
  last_rotated_at INTEGER NOT NULL,
  last_success_at INTEGER,
  last_failure TEXT,
  created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS devices (
  id TEXT PRIMARY KEY,
  account_key TEXT NOT NULL,
  delete_secret_hash TEXT NOT NULL,
  subscription TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS seen_items (
  account_key TEXT NOT NULL,
  course_id INTEGER NOT NULL,
  kind TEXT NOT NULL,
  item_id TEXT NOT NULL,
  PRIMARY KEY (account_key, course_id, kind, item_id)
);
CREATE TABLE IF NOT EXISTS baselines (
  account_key TEXT NOT NULL,
  course_id INTEGER NOT NULL,
  kind TEXT NOT NULL,
  PRIMARY KEY (account_key, course_id, kind)
);
`;

// 글 제목·강좌명·학번은 저장하지 않는다. 토큰과 푸시 구독은 sealer로 암호화한다.
export function openStore({ path, sealer }) {
  const db = new DatabaseSync(path);
  db.exec(SCHEMA);

  const toAccount = (row) =>
    row
      ? {
          accountKey: row.account_key,
          tokens: sealer.open(row.tokens),
          slotMinute: row.slot_minute,
          lastCheckSlot: row.last_check_slot ?? null,
          lastRotatedAt: row.last_rotated_at,
          lastSuccessAt: row.last_success_at ?? null,
          lastFailure: row.last_failure ?? null,
        }
      : null;

  function transaction(fn) {
    db.exec("BEGIN");
    try {
      const result = fn();
      db.exec("COMMIT");
      return result;
    } catch (e) {
      db.exec("ROLLBACK");
      throw e;
    }
  }

  function deleteAccount(accountKey) {
    transaction(() => {
      for (const table of ["devices", "seen_items", "baselines", "accounts"]) {
        db.prepare(`DELETE FROM ${table} WHERE account_key = ?`).run(accountKey);
      }
    });
  }

  return {
    saveAccount({ accountKey, tokens, now }) {
      db.prepare(
        `INSERT INTO accounts (account_key, tokens, slot_minute, last_rotated_at, created_at)
         VALUES (?, ?, ?, ?, ?)
         ON CONFLICT(account_key) DO UPDATE SET tokens = excluded.tokens,
           last_rotated_at = excluded.last_rotated_at`,
      ).run(accountKey, sealer.seal(tokens), slotMinuteFor(accountKey), now, now);
    },
    getAccount(accountKey) {
      return toAccount(db.prepare("SELECT * FROM accounts WHERE account_key = ?").get(accountKey));
    },
    listAccounts() {
      return db.prepare("SELECT * FROM accounts ORDER BY created_at").all().map(toAccount);
    },
    countAccounts() {
      return db.prepare("SELECT COUNT(*) AS n FROM accounts").get().n;
    },
    updateTokens(accountKey, tokens, now) {
      db.prepare("UPDATE accounts SET tokens = ?, last_rotated_at = ? WHERE account_key = ?")
        .run(sealer.seal(tokens), now, accountKey);
    },
    markChecked(accountKey, { slot, now, failure }) {
      if (failure === null) {
        db.prepare(
          "UPDATE accounts SET last_check_slot = ?, last_success_at = ?, last_failure = NULL WHERE account_key = ?",
        ).run(slot, now, accountKey);
      } else {
        db.prepare("UPDATE accounts SET last_check_slot = ?, last_failure = ? WHERE account_key = ?")
          .run(slot, failure, accountKey);
      }
    },
    addDevice({ id, accountKey, deleteSecretHash, subscription, now }) {
      db.prepare(
        "INSERT INTO devices (id, account_key, delete_secret_hash, subscription, created_at) VALUES (?, ?, ?, ?, ?)",
      ).run(id, accountKey, deleteSecretHash, sealer.seal(subscription), now);
    },
    getDevice(id) {
      const row = db.prepare("SELECT id, account_key, delete_secret_hash FROM devices WHERE id = ?").get(id);
      return row ? { id: row.id, accountKey: row.account_key, deleteSecretHash: row.delete_secret_hash } : null;
    },
    listDevices(accountKey) {
      return db
        .prepare("SELECT id, subscription FROM devices WHERE account_key = ? ORDER BY created_at")
        .all(accountKey)
        .map((row) => ({ id: row.id, subscription: sealer.open(row.subscription) }));
    },
    deleteDevice(id) {
      const device = db.prepare("SELECT account_key FROM devices WHERE id = ?").get(id);
      if (!device) return;
      db.prepare("DELETE FROM devices WHERE id = ?").run(id);
      const left = db.prepare("SELECT COUNT(*) AS n FROM devices WHERE account_key = ?").get(device.account_key).n;
      if (left === 0) deleteAccount(device.account_key);
    },
    deleteAccount,
    recordItems(accountKey, courseId, kind, itemIds) {
      return transaction(() => {
        const hadBaseline = !!db
          .prepare("SELECT 1 FROM baselines WHERE account_key = ? AND course_id = ? AND kind = ?")
          .get(accountKey, courseId, kind);
        const insert = db.prepare(
          "INSERT OR IGNORE INTO seen_items (account_key, course_id, kind, item_id) VALUES (?, ?, ?, ?)",
        );
        const fresh = [];
        for (const id of itemIds) {
          if (insert.run(accountKey, courseId, kind, id).changes > 0 && hadBaseline) fresh.push(id);
        }
        db.prepare("INSERT OR IGNORE INTO baselines (account_key, course_id, kind) VALUES (?, ?, ?)")
          .run(accountKey, courseId, kind);
        return fresh;
      });
    },
    rawRowsForTest() {
      return {
        accounts: db.prepare("SELECT * FROM accounts").all(),
        devices: db.prepare("SELECT * FROM devices").all(),
      };
    },
    close() {
      db.close();
    },
  };
}
```

- [ ] **Step 5: 통과 확인**

Run (notifier/): `npm test`
Expected: PASS (`node:sqlite`의 ExperimentalWarning 출력은 정상)

- [ ] **Step 6: 커밋**

```bash
git add notifier/src/crypto.mjs notifier/src/store.mjs notifier/test/crypto.test.mjs notifier/test/store.test.mjs
git commit -m "feat: 알림 서버 암호화 보관소

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: 조회·회전 일정

**Files:**
- Create: `notifier/src/schedule.mjs`
- Test: `notifier/test/schedule.test.mjs`

**Interfaces:**
- Consumes: Task 3 `Account`
- Produces:
  - `checkSlot(nowMs) -> number|null` (KST 정시 시작 시각 ms, 01~07시는 null)
  - `isCheckDue(account, nowMs) -> boolean`
  - `ROTATE_EVERY_MS = 50 * 60 * 1000`, `isRotationDue(account, nowMs) -> boolean`

- [ ] **Step 1: 실패 테스트** — `notifier/test/schedule.test.mjs`

```js
import test from "node:test";
import assert from "node:assert/strict";
import { checkSlot, isCheckDue, isRotationDue, ROTATE_EVERY_MS } from "../src/schedule.mjs";

// 2026-09-15 한국 시간 h:m을 UTC ms로.
const kst = (h, m) => Date.UTC(2026, 8, 15, h, m) - 9 * 3600 * 1000;
const account = (over = {}) => ({ slotMinute: 10, lastCheckSlot: null, lastRotatedAt: kst(8, 0), ...over });

test("01~07시에는 확인 회차가 없고 00시와 08~23시에는 있다", () => {
  for (const h of [1, 4, 7]) assert.equal(checkSlot(kst(h, 30)), null);
  for (const h of [0, 8, 13, 23]) assert.equal(checkSlot(kst(h, 30)), kst(h, 0));
});

test("계정의 분이 지나야 확인하고 같은 회차에는 다시 확인하지 않는다", () => {
  assert.equal(isCheckDue(account(), kst(9, 9)), false);
  assert.equal(isCheckDue(account(), kst(9, 10)), true);
  assert.equal(isCheckDue(account(), kst(9, 59)), true);
  assert.equal(isCheckDue(account({ lastCheckSlot: kst(9, 0) }), kst(9, 40)), false);
  assert.equal(isCheckDue(account({ lastCheckSlot: kst(9, 0) }), kst(10, 10)), true);
  assert.equal(isCheckDue(account(), kst(3, 30)), false);
  assert.equal(isCheckDue(account(), kst(0, 30)), true);
});

test("마지막 회전에서 50분이 지나면 회전한다", () => {
  assert.equal(ROTATE_EVERY_MS, 50 * 60 * 1000);
  assert.equal(isRotationDue(account(), kst(8, 49)), false);
  assert.equal(isRotationDue(account(), kst(8, 50)), true);
});
```

Run (notifier/): `npm test`
Expected: FAIL (`Cannot find module '../src/schedule.mjs'`)

- [ ] **Step 2: 구현** — `notifier/src/schedule.mjs`

```js
// 안드로이드 notification_schedule.dart와 같은 휴식 시간(한국 시간 01~07시).
const KST_MS = 9 * 3600 * 1000;
const HOUR_MS = 3600 * 1000;

export const ROTATE_EVERY_MS = 50 * 60 * 1000;

export function checkSlot(nowMs) {
  const kstHour = new Date(nowMs + KST_MS).getUTCHours();
  if (kstHour >= 1 && kstHour <= 7) return null;
  return Math.floor((nowMs + KST_MS) / HOUR_MS) * HOUR_MS - KST_MS;
}

export function isCheckDue(account, nowMs) {
  const slot = checkSlot(nowMs);
  if (slot === null || account.lastCheckSlot === slot) return false;
  const minute = new Date(nowMs + KST_MS).getUTCMinutes();
  return minute >= account.slotMinute;
}

// accessToken(60분)이 만료되기 전에 회전한다. 밤에도 멈추지 않는다.
export function isRotationDue(account, nowMs) {
  return nowMs - account.lastRotatedAt >= ROTATE_EVERY_MS;
}
```

- [ ] **Step 3: 통과 확인**

Run (notifier/): `npm test`
Expected: PASS

- [ ] **Step 4: 커밋**

```bash
git add notifier/src/schedule.mjs notifier/test/schedule.test.mjs
git commit -m "feat: 알림 서버 조회·회전 일정

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: 학교 서버 클라이언트 (LINUS, Canvas)

**Files:**
- Create: `notifier/src/linus.mjs`, `notifier/src/canvas.mjs`
- Test: `notifier/test/linus.test.mjs`, `notifier/test/canvas.test.mjs`, `notifier/test/fake_fetch.mjs`

**Interfaces:**
- Consumes: Task 2 `AuthRevokedError`, `SchoolError`, `KIND_INFO`, `parseWatchedItems`, `parseInstructorIds`, `isInstructorPost`, `INSTRUCTOR_TYPES`
- Produces (`linus.mjs`): `createLinusClient({ fetch, baseUrl? }) -> Linus`
  - `reissue(tokens) -> tokens`, `profile(tokens) -> {loginId}`, `terms(tokens) -> {id,startAt,endAt}[]`,
    `courses(tokens, termId) -> {id:number, name:string}[]`, `ssoUrl(tokens, relayState) -> string`
  - 401·204 응답 또는 `T`로 시작하는 봉투 코드는 `AuthRevokedError`, 그 밖의 실패는 `SchoolError`
- Produces (`canvas.mjs`): `createCanvasClient({ linus, fetch, canvasHost? }) -> Canvas`
  - `listItems(tokens, courseId, kind, now) -> {id,title}[]`
  - `parseSamlForm(html) -> {action, samlResponse, relayState} | null` (named export)
- Produces (`test/fake_fetch.mjs`): `fakeFetch(routes) -> fetch` — `routes`는 `[{ match(url, init) -> boolean, reply(url, init) -> Response }]`, 호출 기록은 `fetch.calls`

- [ ] **Step 1: 테스트 도우미** — `notifier/test/fake_fetch.mjs`

```js
// 네트워크 없이 학교 서버 응답을 흉내 낸다. 매칭되는 경로가 없으면 테스트를 실패시킨다.
export function fakeFetch(routes) {
  const calls = [];
  const fn = async (input, init = {}) => {
    const url = new URL(typeof input === "string" ? input : input.href);
    calls.push({ url, init });
    const route = routes.find((r) => r.match(url, init));
    if (!route) throw new Error(`예상하지 못한 요청: ${init.method ?? "GET"} ${url.href}`);
    return route.reply(url, init);
  };
  fn.calls = calls;
  return fn;
}

export const json = (body, init = {}) =>
  new Response(JSON.stringify(body), {
    status: 200,
    ...init,
    headers: { "content-type": "application/json", ...(init.headers ?? {}) },
  });
```

- [ ] **Step 2: LINUS 실패 테스트** — `notifier/test/linus.test.mjs`

```js
import test from "node:test";
import assert from "node:assert/strict";
import { AuthRevokedError, SchoolError } from "../src/errors.mjs";
import { createLinusClient } from "../src/linus.mjs";
import { fakeFetch, json } from "./fake_fetch.mjs";

const BASE = "https://lms.example.test/api/v1";
const tokens = { accessToken: "acc", refreshToken: "ref" };
const path = (p) => (url) => url.pathname === `/api/v1${p}`;

test("재발급은 Bearer와 X-Refresh-Token을 함께 보내고 새 토큰을 돌려준다", async () => {
  const fetch = fakeFetch([
    { match: path("/reissue"), reply: () => json({ code: "200", data: { accessToken: "a2", refreshToken: "r2" } }) },
  ]);
  const linus = createLinusClient({ fetch, baseUrl: BASE });
  assert.deepEqual(await linus.reissue(tokens), { accessToken: "a2", refreshToken: "r2" });
  const headers = fetch.calls[0].init.headers;
  assert.equal(headers.Authorization, "Bearer acc");
  assert.equal(headers["X-Refresh-Token"], "ref");
  assert.equal(headers.Origin, "https://lms.kumoh.ac.kr");
  assert.equal(fetch.calls[0].init.method, "POST");
});

test("세션이 끊긴 응답은 AuthRevokedError로 알린다", async () => {
  for (const reply of [
    () => json({ code: "T001", message: "expired" }, { status: 401 }),
    () => new Response(null, { status: 204 }),
    () => json({ code: "T003", message: "invalid token" }),
  ]) {
    const linus = createLinusClient({ fetch: fakeFetch([{ match: path("/reissue"), reply }]), baseUrl: BASE });
    await assert.rejects(linus.reissue(tokens), AuthRevokedError);
  }
});

test("학교 서버 장애는 SchoolError로 알린다", async () => {
  const linus = createLinusClient({
    fetch: fakeFetch([{ match: path("/terms"), reply: () => new Response("down", { status: 503 }) }]),
    baseUrl: BASE,
  });
  await assert.rejects(linus.terms(tokens), SchoolError);
});

test("프로필·학기·강좌·SSO 주소를 읽는다", async () => {
  const fetch = fakeFetch([
    { match: path("/user/profile"), reply: () => json({ code: "200", data: { loginId: "S20250001", name: "홍길동" } }) },
    { match: path("/terms"), reply: () => json({ code: "200", data: [{ id: 5, startAt: "2026-09-01T00:00:00", endAt: "2026-12-31T00:00:00" }] }) },
    { match: path("/courses"), reply: () => json({ code: "200", data: { courses: [{ id: 12, name: "운영체제-01" }] } }) },
    { match: path("/saml/redirect.do"), reply: () => new Response(" https://canvas.example.test/login/saml?x=1 \n") },
  ]);
  const linus = createLinusClient({ fetch, baseUrl: BASE });
  assert.deepEqual(await linus.profile(tokens), { loginId: "S20250001" });
  assert.equal((await linus.terms(tokens))[0].id, 5);
  assert.deepEqual(await linus.courses(tokens, 5), [{ id: 12, name: "운영체제-01" }]);
  assert.equal(await linus.ssoUrl(tokens, "/courses"), "https://canvas.example.test/login/saml?x=1");

  const courseCall = fetch.calls.find((c) => c.url.pathname.endsWith("/courses"));
  assert.equal(courseCall.url.searchParams.get("termId"), "5");
  assert.equal(courseCall.url.searchParams.get("isMyCourse"), "true");
  assert.equal(fetch.calls.at(-1).url.searchParams.get("relayState"), "/courses");
});
```

Run (notifier/): `npm test`
Expected: FAIL (`Cannot find module '../src/linus.mjs'`)

- [ ] **Step 3: LINUS 구현** — `notifier/src/linus.mjs`

```js
import { AuthRevokedError, SchoolError } from "./errors.mjs";

// 앱의 dio_client.dart와 같은 헤더. 내부 API가 Origin/Referer를 검사한다.
const WEB_HEADERS = { Origin: "https://lms.kumoh.ac.kr", Referer: "https://lms.kumoh.ac.kr/" };
const ACCOUNT_ID = "1";

export function createLinusClient({ fetch = globalThis.fetch, baseUrl = "https://lms.kumoh.ac.kr:82/api/v1" }) {
  async function call(method, path, tokens, query = {}) {
    const url = new URL(`${baseUrl}${path}`);
    for (const [k, v] of Object.entries(query)) url.searchParams.set(k, v);
    const res = await fetch(url.href, {
      method,
      redirect: "manual",
      signal: AbortSignal.timeout(20_000),
      headers: {
        ...WEB_HEADERS,
        Accept: "application/json",
        Authorization: `Bearer ${tokens.accessToken}`,
        "X-Refresh-Token": tokens.refreshToken,
      },
    });
    // 204는 운영 웹앱이 재발급 신호로 쓰는 응답이다.
    if (res.status === 401 || res.status === 204) throw new AuthRevokedError(`linus ${res.status}`);
    if (res.status >= 400) throw new SchoolError(`linus ${res.status}`, res.status);
    return res;
  }

  async function data(res) {
    const body = await res.json().catch(() => null);
    const code = body?.code === undefined ? undefined : String(body.code);
    if (code === undefined) throw new SchoolError("linus envelope");
    if (/^T\d+$/.test(code)) throw new AuthRevokedError(`linus ${code}`);
    if (code !== "200") throw new SchoolError(`linus ${code}`);
    return body.data;
  }

  return {
    async reissue(tokens) {
      const d = await data(await call("POST", "/reissue", tokens));
      if (typeof d?.accessToken !== "string" || typeof d?.refreshToken !== "string") {
        throw new SchoolError("reissue data");
      }
      return { accessToken: d.accessToken, refreshToken: d.refreshToken };
    },
    async profile(tokens) {
      const d = await data(await call("GET", "/user/profile", tokens));
      if (typeof d?.loginId !== "string" || d.loginId === "") throw new SchoolError("profile data");
      return { loginId: d.loginId };
    },
    async terms(tokens) {
      const d = await data(await call("GET", "/terms", tokens, { accountId: ACCOUNT_ID }));
      return Array.isArray(d) ? d.filter((t) => typeof t?.id === "number") : [];
    },
    async courses(tokens, termId) {
      const d = await data(
        await call("GET", "/courses", tokens, { isMyCourse: "true", accountId: ACCOUNT_ID, termId: String(termId) }),
      );
      const list = Array.isArray(d?.courses) ? d.courses : [];
      return list
        .filter((c) => typeof c?.id === "number")
        .map((c) => ({ id: c.id, name: typeof c.name === "string" ? c.name : "" }));
    },
    // 봉투가 아니라 URL 문자열을 그대로 준다(saml_bridge_api.dart).
    async ssoUrl(tokens, relayState) {
      const res = await call("GET", "/saml/redirect.do", tokens, { relayState });
      const text = (await res.text()).trim();
      if (!text.startsWith("https://")) throw new SchoolError("sso url");
      return text;
    },
  };
}
```

Run (notifier/): `npm test`
Expected: linus 테스트 PASS

- [ ] **Step 4: Canvas 실패 테스트** — `notifier/test/canvas.test.mjs`

```js
import test from "node:test";
import assert from "node:assert/strict";
import { SchoolError } from "../src/errors.mjs";
import { createCanvasClient, parseSamlForm } from "../src/canvas.mjs";
import { fakeFetch, json } from "./fake_fetch.mjs";

const CANVAS = "https://canvas.kumoh.ac.kr";
const SSO = "https://canvas.kumoh.ac.kr/login/saml";
const IDP = "https://lms.kumoh.ac.kr/api/v1/saml/login.do";
const tokens = { accessToken: "acc.token", refreshToken: "ref" };
const now = new Date("2026-09-15T00:00:00Z");
const FORM = `<form method="post" action="${CANVAS}/login/saml"><input type="hidden" name="SAMLResponse" value="QkxPQg=="><input type="hidden" name="RelayState" value="/courses"></form>`;

function linusStub() {
  return { ssoUrl: async () => SSO };
}

// canvas SSO → IdP(쿠키 확인) → 폼 → ACS POST → 세션 쿠키 → API
function bridgeRoutes(extra) {
  return [
    {
      match: (u, i) => u.href === SSO && (i.method ?? "GET") === "GET",
      reply: () => new Response(null, { status: 302, headers: { location: IDP } }),
    },
    {
      match: (u) => u.href === IDP,
      reply: (u, i) =>
        (i.headers.Cookie ?? "").includes("_linus_saml_login=acc.token")
          ? new Response(FORM, { headers: { "content-type": "text/html" } })
          : new Response("A001", { status: 200 }),
    },
    {
      match: (u, i) => u.href === `${CANVAS}/login/saml` && i.method === "POST",
      reply: () =>
        new Response(null, {
          status: 302,
          headers: { location: `${CANVAS}/courses`, "set-cookie": "_normandy_session=S1; Path=/; Secure; HttpOnly" },
        }),
    },
    ...extra,
  ];
}

const api = (p) => (u) => u.pathname === `/api/v1${p}`;
const withSession = (reply) => (u, i) =>
  (i.headers.Cookie ?? "").includes("_normandy_session=S1") ? reply(u, i) : new Response("{}", { status: 401 });

test("SAML 폼의 action과 값을 읽는다", () => {
  assert.deepEqual(parseSamlForm(FORM), {
    action: `${CANVAS}/login/saml`,
    samlResponse: "QkxPQg==",
    relayState: "/courses",
  });
  assert.equal(parseSamlForm("A001"), null);
});

test("SSO를 건너 세션 쿠키로 공지 목록을 받는다", async () => {
  const fetch = fakeFetch(
    bridgeRoutes([
      {
        match: api("/courses/12/discussion_topics"),
        reply: withSession((u) => {
          assert.equal(u.searchParams.get("only_announcements"), "true");
          assert.equal(u.searchParams.get("per_page"), "100");
          return json([{ id: 1, title: "시험 공지" }]);
        }),
      },
    ]),
  );
  const canvas = createCanvasClient({ linus: linusStub(), fetch, canvasHost: CANVAS });
  assert.deepEqual(await canvas.listItems(tokens, 12, "announcement", now), [{ id: "1", title: "시험 공지" }]);
});

test("다음 페이지를 따라가고 다른 경로로 향하는 다음 페이지는 거부한다", async () => {
  const pages = fakeFetch(
    bridgeRoutes([
      {
        match: (u) => u.pathname === "/api/v1/courses/12/files" && u.searchParams.get("page") !== "2",
        reply: withSession(() =>
          json([{ id: 100, display_name: "파일1" }], {
            headers: { link: `<${CANVAS}/api/v1/courses/12/files?page=2>; rel="next"` },
          }),
        ),
      },
      {
        match: (u) => u.pathname === "/api/v1/courses/12/files" && u.searchParams.get("page") === "2",
        reply: withSession(() => json([{ id: 5, display_name: "파일2" }])),
      },
    ]),
  );
  const canvas = createCanvasClient({ linus: linusStub(), fetch: pages, canvasHost: CANVAS });
  assert.deepEqual((await canvas.listItems(tokens, 12, "file", now)).map((i) => i.id), ["100", "5"]);

  const evil = fakeFetch(
    bridgeRoutes([
      {
        match: api("/courses/12/files"),
        reply: withSession(() => json([], { headers: { link: `<https://other.test/api/v1/courses/12/files>; rel="next"` } })),
      },
    ]),
  );
  const canvas2 = createCanvasClient({ linus: linusStub(), fetch: evil, canvasHost: CANVAS });
  await assert.rejects(canvas2.listItems(tokens, 12, "file", now), SchoolError);
});

test("토론은 강의자 글만 남기고 수강 목록을 못 보면 토론을 비운다", async () => {
  const topics = json([
    { id: 1, title: "교수 토론", author: { id: 7 } },
    { id: 2, title: "학생 토론", author: { id: 8 } },
  ]);
  const fetch = fakeFetch(
    bridgeRoutes([
      { match: api("/courses/12/discussion_topics"), reply: withSession(() => topics.clone()) },
      {
        match: api("/courses/12/enrollments"),
        reply: withSession((u) =>
          json(u.searchParams.get("type[]") === "TeacherEnrollment" ? [{ type: "TeacherEnrollment", user_id: 7 }] : []),
        ),
      },
    ]),
  );
  const canvas = createCanvasClient({ linus: linusStub(), fetch, canvasHost: CANVAS });
  assert.deepEqual((await canvas.listItems(tokens, 12, "discussion", now)).map((i) => i.id), ["1"]);

  const hidden = fakeFetch(
    bridgeRoutes([
      { match: api("/courses/12/discussion_topics"), reply: withSession(() => topics.clone()) },
      { match: api("/courses/12/enrollments"), reply: withSession(() => json({}, { status: 403 })) },
    ]),
  );
  const canvas2 = createCanvasClient({ linus: linusStub(), fetch: hidden, canvasHost: CANVAS });
  assert.deepEqual(await canvas2.listItems(tokens, 12, "discussion", now), []);
});

test("Canvas가 401을 주면 SSO를 한 번 다시 건넌다", async () => {
  let first = true;
  const fetch = fakeFetch(
    bridgeRoutes([
      {
        match: api("/courses/12/assignments"),
        reply: withSession(() => {
          if (first) {
            first = false;
            return new Response("{}", { status: 401 });
          }
          return json([{ id: 3, name: "과제" }]);
        }),
      },
    ]),
  );
  const canvas = createCanvasClient({ linus: linusStub(), fetch, canvasHost: CANVAS });
  assert.deepEqual(await canvas.listItems(tokens, 12, "assignment", now), [{ id: "3", title: "과제" }]);
  assert.equal(fetch.calls.filter((c) => c.url.href === SSO).length, 2);
});

test("SAML 폼이 Canvas가 아닌 곳으로 가면 제출하지 않는다", async () => {
  const fetch = fakeFetch([
    { match: (u) => u.href === SSO, reply: () => new Response(null, { status: 302, headers: { location: IDP } }) },
    {
      match: (u) => u.href === IDP,
      reply: () => new Response(FORM.replace(`${CANVAS}/login/saml`, "https://evil.test/acs")),
    },
  ]);
  const canvas = createCanvasClient({ linus: linusStub(), fetch, canvasHost: CANVAS });
  await assert.rejects(canvas.listItems(tokens, 12, "file", now), SchoolError);
  assert.ok(!fetch.calls.some((c) => c.url.host === "evil.test"));
});
```

Run (notifier/): `npm test`
Expected: FAIL (`Cannot find module '../src/canvas.mjs'`)

- [ ] **Step 5: Canvas 구현** — `notifier/src/canvas.mjs`

```js
import { CookieJar } from "tough-cookie";
import { SchoolError } from "./errors.mjs";
import { INSTRUCTOR_TYPES, KIND_INFO, isInstructorPost, parseInstructorIds, parseWatchedItems } from "./rules.mjs";

const FORM_ACTION = /<form[^>]*action="([^"]+)"/i;
const hidden = (name) => new RegExp(`<input[^>]*name="${name}"[^>]*value="([^"]*)"`, "i");
const NEXT_LINK = /<([^>]+)>\s*;\s*rel="?next"?/i;
const MAX_PAGES = 100;

// canvas_session.dart의 parseSamlForm과 같은 규칙.
export function parseSamlForm(html) {
  const action = FORM_ACTION.exec(html)?.[1];
  const samlResponse = hidden("SAMLResponse").exec(html)?.[1];
  if (!action || !samlResponse) return null;
  return { action, samlResponse, relayState: hidden("RelayState").exec(html)?.[1] ?? "/" };
}

// 계정 하나의 확인 한 회차 동안만 쓰는 Canvas 세션. 쿠키는 메모리에만 있다.
export function createCanvasClient({ linus, fetch = globalThis.fetch, canvasHost = "https://canvas.kumoh.ac.kr" }) {
  const jar = new CookieJar();
  const canvas = new URL(canvasHost);
  let bridged = false;

  async function send(url, init = {}) {
    const cookie = await jar.getCookieString(url);
    const res = await fetch(url, {
      ...init,
      redirect: "manual",
      signal: AbortSignal.timeout(20_000),
      headers: { ...(init.headers ?? {}), ...(cookie ? { Cookie: cookie } : {}) },
    });
    for (const value of res.headers.getSetCookie()) {
      await jar.setCookie(value, url, { ignoreError: true });
    }
    return res;
  }

  async function bridge(tokens) {
    const ssoUrl = await linus.ssoUrl(tokens, "/courses");
    // IdP는 이 쿠키의 서명된 accessToken으로 사용자를 확인한다(canvas_session.dart).
    const idpOrigin = "https://lms.kumoh.ac.kr/";
    await jar.setCookie(`_linus_saml_login=${tokens.accessToken}; Domain=kumoh.ac.kr; Path=/`, idpOrigin);
    await jar.setCookie("_linus_saml_domain=/courses; Domain=kumoh.ac.kr; Path=/", idpOrigin);

    let url = ssoUrl;
    let html = null;
    for (let hop = 0; hop < 10 && html === null; hop++) {
      const res = await send(url, { headers: { Accept: "text/html" } });
      const location = res.headers.get("location");
      if (res.status >= 300 && res.status < 400 && location) {
        await res.body?.cancel();
        url = new URL(location, url).href;
      } else if (res.status >= 400) {
        throw new SchoolError(`idp ${res.status}`, res.status);
      } else {
        html = await res.text();
      }
    }
    if (html === null) throw new SchoolError("idp redirects");
    const form = parseSamlForm(html);
    // 폼이 없으면(A001 등) 학교 쪽 일시 문제일 수 있다. 등록 삭제는 LINUS 재발급 실패만 기준으로 한다.
    if (!form) throw new SchoolError("saml form");
    const action = new URL(form.action);
    if (action.protocol !== "https:" || action.host !== canvas.host) throw new SchoolError("saml action");

    const res = await send(action.href, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ SAMLResponse: form.samlResponse, RelayState: form.relayState }).toString(),
    });
    await res.body?.cancel();
    if (res.status >= 400) throw new SchoolError(`acs ${res.status}`, res.status);
    bridged = true;
  }

  async function getPage(url, tokens, retried = false) {
    if (!bridged) await bridge(tokens);
    const res = await send(url, { headers: { Accept: "application/json" } });
    if (res.status === 401 && !retried) {
      await res.body?.cancel();
      bridged = false;
      return getPage(url, tokens, true);
    }
    if (res.status >= 400) {
      await res.body?.cancel();
      throw new SchoolError(`canvas ${res.status}`, res.status);
    }
    return res;
  }

  // lms_notification_source.dart의 fetchNotificationPages와 같은 검증.
  async function allPages(path, query, tokens) {
    const first = new URL(`${canvasHost}/api/v1${path}`);
    let next = new URL(first);
    next.searchParams.set("per_page", "100");
    for (const [k, v] of Object.entries(query)) next.searchParams.set(k, v);
    const visited = new Set();
    const rows = [];
    for (let page = 0; page < MAX_PAGES; page++) {
      if (
        next.protocol !== first.protocol ||
        next.host !== first.host ||
        next.pathname !== first.pathname ||
        next.username !== "" ||
        next.password !== "" ||
        visited.has(next.href)
      ) {
        throw new SchoolError("next page url");
      }
      visited.add(next.href);
      const res = await getPage(next.href, tokens);
      const body = await res.json().catch(() => null);
      if (!Array.isArray(body) || body.some((e) => e === null || typeof e !== "object" || Array.isArray(e))) {
        throw new SchoolError("list body");
      }
      rows.push(...body);
      const following = NEXT_LINK.exec(res.headers.get("link") ?? "")?.[1];
      if (!following) return rows;
      next = new URL(following, next);
    }
    throw new SchoolError("too many pages");
  }

  return {
    async listItems(tokens, courseId, kind, now) {
      const info = KIND_INFO[kind];
      const rows = await allPages(`/courses/${courseId}/${info.endpoint}`, info.query, tokens);
      if (kind !== "discussion") return parseWatchedItems(rows, kind, now);
      // 다른 학생의 토론 글은 알리지 않는다. 수강 목록을 못 보면 토론 알림을 보내지 않는다.
      const instructors = new Set();
      for (const type of INSTRUCTOR_TYPES) {
        try {
          const enrollments = await allPages(`/courses/${courseId}/enrollments`, { "type[]": type }, tokens);
          for (const id of parseInstructorIds(enrollments)) instructors.add(id);
        } catch (e) {
          if (!(e instanceof SchoolError && [401, 403, 404].includes(e.status))) throw e;
        }
      }
      return parseWatchedItems(rows.filter((r) => isInstructorPost(r, instructors)), kind, now);
    },
  };
}
```

- [ ] **Step 6: 통과 확인**

Run (notifier/): `npm test`
Expected: PASS

- [ ] **Step 7: 커밋**

```bash
git add notifier/src/linus.mjs notifier/src/canvas.mjs notifier/test/fake_fetch.mjs notifier/test/linus.test.mjs notifier/test/canvas.test.mjs
git commit -m "feat: 알림 서버의 LINUS·Canvas 조회 클라이언트

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: 푸시 발송과 확인·회전 작업

**Files:**
- Create: `notifier/src/push.mjs`, `notifier/src/jobs.mjs`
- Test: `notifier/test/push.test.mjs`, `notifier/test/jobs.test.mjs`

**Interfaces:**
- Consumes: Task 2 `KINDS`, `KIND_INFO`, `heading`, `pickTerm`, `AuthRevokedError`, `SchoolError`; Task 3 `Store`; Task 4 `checkSlot`, `isCheckDue`, `isRotationDue`; Task 5 `Linus`, `Canvas`
- Produces (`push.mjs`):
  - `STOPPED_PAYLOAD = {title, body, url: "/kumoh-LMS/#/settings"}`
  - `noticePayloads(notices) -> {title, body, url}[]` (`notices = {courseId, courseName, kind, title}[]`, 5건 초과면 1건으로 묶음)
  - `createPusher({ store, send }) -> { sendNotices(accountKey, notices) -> number, sendStopped(accountKey) -> number }` — `send(subscription, payloadString)`는 실패 시 `statusCode`가 있는 오류를 던진다
- Produces (`jobs.mjs`):
  - `rotateAccount({store, linus, pusher, account, now}) -> tokens|null` (null이면 등록 삭제됨)
  - `checkAccount({store, linus, createCanvas, pusher, account, now}) -> {revoked: boolean, notices: number, failures: number}`
  - `runTick({store, linus, createCanvas, pusher, now, concurrency = 4, inFlight = new Set()}) -> {checked, rotated, notices, failures, revoked}`

- [ ] **Step 1: 푸시 실패 테스트** — `notifier/test/push.test.mjs`

```js
import test from "node:test";
import assert from "node:assert/strict";
import { createPusher, noticePayloads, STOPPED_PAYLOAD } from "../src/push.mjs";

const notice = (i, over = {}) => ({ courseId: 12, courseName: "운영체제-01", kind: "file", title: `자료${i}`, ...over });

test("새 글 한 건은 분류·강좌명·제목과 강좌 탭 경로로 만든다", () => {
  assert.deepEqual(noticePayloads([notice(1)]), [
    { title: "[새 파일] 운영체제", body: "자료1", url: "/kumoh-LMS/#/courses/12?tab=files" },
  ]);
  assert.deepEqual(noticePayloads([]), []);
});

test("5건을 넘으면 한 건으로 묶는다", () => {
  assert.equal(noticePayloads([1, 2, 3, 4, 5].map((i) => notice(i))).length, 5);
  assert.deepEqual(noticePayloads([1, 2, 3, 4, 5, 6].map((i) => notice(i))), [
    { title: "금오 LMS 새 소식", body: "새 소식 6건이 올라왔어요.", url: "/kumoh-LMS/#/announcements" },
  ]);
});

test("계정의 모든 기기로 보내고 만료된 구독(404·410)은 지운다", async () => {
  const deleted = [];
  const store = {
    listDevices: () => [
      { id: "ok", subscription: { endpoint: "https://web.push.apple.com/ok" } },
      { id: "gone", subscription: { endpoint: "https://web.push.apple.com/gone" } },
    ],
    deleteDevice: (id) => deleted.push(id),
  };
  const sent = [];
  const send = async (sub, payload) => {
    if (sub.endpoint.endsWith("gone")) throw Object.assign(new Error("gone"), { statusCode: 410 });
    sent.push(JSON.parse(payload));
  };
  const pusher = createPusher({ store, send });
  assert.equal(await pusher.sendNotices("k", [notice(1), notice(2)]), 2);
  assert.equal(sent.length, 2);
  assert.deepEqual(deleted, ["gone"]);

  sent.length = 0;
  await pusher.sendStopped("k");
  assert.deepEqual(sent, [STOPPED_PAYLOAD]);
});

test("일시적인 푸시 실패는 기기를 지우지 않는다", async () => {
  const deleted = [];
  const store = { listDevices: () => [{ id: "d", subscription: {} }], deleteDevice: (id) => deleted.push(id) };
  const send = async () => {
    throw Object.assign(new Error("busy"), { statusCode: 503 });
  };
  assert.equal(await createPusher({ store, send }).sendNotices("k", [notice(1)]), 0);
  assert.deepEqual(deleted, []);
});
```

Run (notifier/): `npm test`
Expected: FAIL (`Cannot find module '../src/push.mjs'`)

- [ ] **Step 2: 푸시 구현** — `notifier/src/push.mjs`

```js
import { KIND_INFO, heading } from "./rules.mjs";

const BUNDLE_OVER = 5;

export const STOPPED_PAYLOAD = {
  title: "알림이 멈췄어요",
  body: "로그아웃되어 새 소식을 확인할 수 없어요. 앱에서 알림을 다시 켜 주세요.",
  url: "/kumoh-LMS/#/settings",
};

// 제목은 푸시 본문에만 담고 저장하지 않는다.
export function noticePayloads(notices) {
  if (notices.length > BUNDLE_OVER) {
    return [{ title: "금오 LMS 새 소식", body: `새 소식 ${notices.length}건이 올라왔어요.`, url: "/kumoh-LMS/#/announcements" }];
  }
  return notices.map((n) => ({
    title: heading(n.kind, n.courseName),
    body: n.title,
    url: `/kumoh-LMS/#/courses/${n.courseId}?tab=${KIND_INFO[n.kind].tab}`,
  }));
}

export function createPusher({ store, send }) {
  async function toAccount(accountKey, payloads) {
    let sent = 0;
    for (const device of store.listDevices(accountKey)) {
      for (const payload of payloads) {
        try {
          await send(device.subscription, JSON.stringify(payload));
          sent++;
        } catch (e) {
          // 404·410은 앱 삭제·구독 해지다. 그 기기는 더 보내지 않는다.
          if (e?.statusCode === 404 || e?.statusCode === 410) {
            store.deleteDevice(device.id);
            break;
          }
        }
      }
    }
    return sent;
  }
  return {
    sendNotices: (accountKey, notices) => toAccount(accountKey, noticePayloads(notices)),
    sendStopped: (accountKey) => toAccount(accountKey, [STOPPED_PAYLOAD]),
  };
}
```

Run (notifier/): `npm test`
Expected: push 테스트 PASS

- [ ] **Step 3: 작업 실패 테스트** — `notifier/test/jobs.test.mjs`

```js
import test from "node:test";
import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { createSealer } from "../src/crypto.mjs";
import { AuthRevokedError, SchoolError } from "../src/errors.mjs";
import { checkAccount, rotateAccount, runTick } from "../src/jobs.mjs";
import { openStore } from "../src/store.mjs";

const kst = (h, m) => Date.UTC(2026, 8, 15, h, m) - 9 * 3600 * 1000;
const tokens = { accessToken: "a1", refreshToken: "r1" };

function setup() {
  const store = openStore({ path: ":memory:", sealer: createSealer(randomBytes(32)) });
  store.saveAccount({ accountKey: "00000000aa", tokens, now: kst(0, 0) }); // slotMinute = 1
  store.addDevice({ id: "d1", accountKey: "00000000aa", deleteSecretHash: "h", subscription: {}, now: 0 });
  const pushed = [];
  const pusher = {
    sendNotices: async (k, notices) => pushed.push(...notices),
    sendStopped: async (k) => pushed.push("stopped"),
  };
  const linus = {
    rotations: 0,
    reissue: async () => ({ accessToken: `a${++linus.rotations + 1}`, refreshToken: "r" }),
    terms: async () => [{ id: 5, startAt: "2026-09-01T00:00:00", endAt: "2026-12-31T00:00:00" }],
    courses: async () => [{ id: 12, name: "운영체제-01" }],
  };
  let items = { file: [{ id: "1", title: "자료1" }] };
  const createCanvas = () => ({ listItems: async (t, c, kind) => items[kind] ?? [] });
  return { store, pusher, pushed, linus, createCanvas, setItems: (v) => (items = v) };
}

test("첫 확인은 기준점만 저장하고 다음 확인에서 새 글을 푸시한다", async () => {
  const s = setup();
  const account = () => s.store.getAccount("00000000aa");
  let r = await checkAccount({ ...s, account: account(), now: kst(9, 1) });
  assert.deepEqual(r, { revoked: false, notices: 0, failures: 0 });
  assert.equal(s.pushed.length, 0);
  assert.equal(account().lastSuccessAt, kst(9, 1));

  s.setItems({ file: [{ id: "1", title: "자료1" }, { id: "2", title: "자료2" }] });
  r = await checkAccount({ ...s, account: account(), now: kst(10, 1) });
  assert.equal(r.notices, 1);
  assert.deepEqual(s.pushed, [{ courseId: 12, courseName: "운영체제-01", kind: "file", title: "자료2" }]);
});

test("한 목록이 실패해도 나머지를 확인하고 실패를 기록한다", async () => {
  const s = setup();
  s.createCanvas = () => ({
    listItems: async (t, c, kind) => {
      if (kind === "assignment") throw new SchoolError("canvas 500", 500);
      return [];
    },
  });
  const r = await checkAccount({ ...s, account: s.store.getAccount("00000000aa"), now: kst(9, 1) });
  assert.equal(r.failures, 1);
  assert.equal(s.store.getAccount("00000000aa").lastFailure, "목록 1개를 확인하지 못했어요");
});

test("회전이 거부되면 멈춤 푸시를 보내고 등록을 지운다", async () => {
  const s = setup();
  s.linus.reissue = async () => {
    throw new AuthRevokedError("linus T001");
  };
  assert.equal(await rotateAccount({ ...s, account: s.store.getAccount("00000000aa"), now: kst(9, 50) }), null);
  assert.deepEqual(s.pushed, ["stopped"]);
  assert.equal(s.store.getAccount("00000000aa"), null);
});

test("확인 중 세션이 끊기면 한 번 회전하고 다시 확인한다", async () => {
  const s = setup();
  let calls = 0;
  s.linus.terms = async (t) => {
    calls++;
    if (t.accessToken === "a1") throw new AuthRevokedError("linus 204");
    return [{ id: 5, startAt: "2026-09-01T00:00:00", endAt: "2026-12-31T00:00:00" }];
  };
  const r = await checkAccount({ ...s, account: s.store.getAccount("00000000aa"), now: kst(9, 1) });
  assert.equal(r.revoked, false);
  assert.equal(calls, 2);
  assert.equal(s.store.getAccount("00000000aa").tokens.accessToken, "a2");
});

test("학교 서버 장애는 등록을 지우지 않고 실패만 기록한다", async () => {
  const s = setup();
  s.linus.terms = async () => {
    throw new SchoolError("linus 503", 503);
  };
  const r = await checkAccount({ ...s, account: s.store.getAccount("00000000aa"), now: kst(9, 1) });
  assert.equal(r.failures, 1);
  assert.equal(s.store.getAccount("00000000aa").lastFailure, "학교 서버에 연결하지 못했어요");
});

test("틱은 휴식 시간에는 확인하지 않고 회전만 한다", async () => {
  const s = setup();
  const night = await runTick({ ...s, now: kst(3, 30) });
  assert.equal(night.checked, 0);
  assert.equal(night.rotated, 1);

  const morning = await runTick({ ...s, now: kst(8, 5) });
  assert.equal(morning.checked, 1);
  const again = await runTick({ ...s, now: kst(8, 6) });
  assert.equal(again.checked, 0);
});
```

Run (notifier/): `npm test`
Expected: FAIL (`Cannot find module '../src/jobs.mjs'`)

- [ ] **Step 4: 작업 구현** — `notifier/src/jobs.mjs`

```js
import { AuthRevokedError } from "./errors.mjs";
import { KINDS, pickTerm } from "./rules.mjs";
import { checkSlot, isCheckDue, isRotationDue } from "./schedule.mjs";

const SCHOOL_DOWN = "학교 서버에 연결하지 못했어요";

async function revoke({ store, pusher, account }) {
  await pusher.sendStopped(account.accountKey);
  store.deleteAccount(account.accountKey);
}

export async function rotateAccount({ store, linus, pusher, account, now }) {
  try {
    const tokens = await linus.reissue(account.tokens);
    store.updateTokens(account.accountKey, tokens, now);
    return tokens;
  } catch (e) {
    if (!(e instanceof AuthRevokedError)) throw e;
    await revoke({ store, pusher, account });
    return null;
  }
}

async function collect({ store, linus, createCanvas, account, tokens, now }) {
  const term = pickTerm(await linus.terms(tokens), new Date(now));
  if (!term) return { notices: [], failures: 1 };
  const courses = await linus.courses(tokens, term.id);
  const canvas = createCanvas();
  const notices = [];
  let failures = 0;
  for (const course of courses) {
    for (const kind of KINDS) {
      try {
        const items = await canvas.listItems(tokens, course.id, kind, new Date(now));
        const fresh = new Set(store.recordItems(account.accountKey, course.id, kind, items.map((i) => i.id)));
        for (const item of items) {
          if (fresh.has(item.id)) notices.push({ courseId: course.id, courseName: course.name, kind, title: item.title });
        }
      } catch (e) {
        if (e instanceof AuthRevokedError) throw e;
        failures++;
      }
    }
  }
  return { notices, failures };
}

export async function checkAccount({ store, linus, createCanvas, pusher, account, now }) {
  const slot = checkSlot(now);
  let tokens = account.tokens;
  try {
    let result;
    try {
      result = await collect({ store, linus, createCanvas, account, tokens, now });
    } catch (e) {
      if (!(e instanceof AuthRevokedError)) throw e;
      tokens = await rotateAccount({ store, linus, pusher, account, now });
      if (!tokens) return { revoked: true, notices: 0, failures: 0 };
      result = await collect({ store, linus, createCanvas, account: { ...account, tokens }, tokens, now });
    }
    await pusher.sendNotices(account.accountKey, result.notices);
    store.markChecked(account.accountKey, {
      slot,
      now,
      failure: result.failures ? `목록 ${result.failures}개를 확인하지 못했어요` : null,
    });
    return { revoked: false, notices: result.notices.length, failures: result.failures };
  } catch (e) {
    if (e instanceof AuthRevokedError) {
      await revoke({ store, pusher, account });
      return { revoked: true, notices: 0, failures: 0 };
    }
    store.markChecked(account.accountKey, { slot, now, failure: SCHOOL_DOWN });
    return { revoked: false, notices: 0, failures: 1 };
  }
}

// 매분 부른다. 확인할 계정은 확인만, 아니면 회전 시각이 된 계정만 회전한다.
export async function runTick({ store, linus, createCanvas, pusher, now, concurrency = 4, inFlight = new Set() }) {
  const jobs = [];
  for (const account of store.listAccounts()) {
    if (inFlight.has(account.accountKey)) continue;
    if (isCheckDue(account, now)) jobs.push({ type: "check", account });
    else if (isRotationDue(account, now)) jobs.push({ type: "rotate", account });
  }
  const stats = { checked: 0, rotated: 0, notices: 0, failures: 0, revoked: 0 };
  let next = 0;
  async function worker() {
    while (next < jobs.length) {
      const job = jobs[next++];
      inFlight.add(job.account.accountKey);
      try {
        if (job.type === "rotate") {
          const tokens = await rotateAccount({ store, linus, pusher, account: job.account, now });
          if (tokens) stats.rotated++;
          else stats.revoked++;
        } else {
          let account = job.account;
          if (isRotationDue(account, now)) {
            const tokens = await rotateAccount({ store, linus, pusher, account, now });
            if (!tokens) {
              stats.revoked++;
              continue;
            }
            account = { ...account, tokens };
          }
          const r = await checkAccount({ store, linus, createCanvas, pusher, account, now });
          stats.checked++;
          stats.notices += r.notices;
          stats.failures += r.failures;
          if (r.revoked) stats.revoked++;
        }
      } catch {
        stats.failures++;
      } finally {
        inFlight.delete(job.account.accountKey);
      }
    }
  }
  await Promise.all(Array.from({ length: Math.min(concurrency, jobs.length) }, worker));
  return stats;
}
```

주의: `setup()`의 계정 키 `"00000000aa"`는 `slotMinuteFor`에서 1분이 된다(`0 % 30 + 1`). 테스트의 "학교 서버 장애" 메시지와 구현의 `SCHOOL_DOWN`, "목록 N개" 메시지가 같아야 한다.

- [ ] **Step 5: 통과 확인**

Run (notifier/): `npm test`
Expected: PASS

- [ ] **Step 6: 커밋**

```bash
git add notifier/src/push.mjs notifier/src/jobs.mjs notifier/test/push.test.mjs notifier/test/jobs.test.mjs
git commit -m "feat: 알림 서버 확인·회전 작업과 푸시 발송

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: 등록 API

**Files:**
- Create: `notifier/src/http.mjs`
- Test: `notifier/test/http.test.mjs`

**Interfaces:**
- Consumes: Task 3 `Store`, `accountKeyFor`, `newDeviceId`, `newDeleteSecret`, `hashSecret`, `secretMatches`; Task 5 `Linus.profile`; Task 2 `AuthRevokedError`
- Produces: `createNotifierServer({store, linus, hmacKey, vapidPublicKey, allowedOrigin, maxAccounts, trustForwardedFor, now = Date.now, registerRateMax = 5}) -> http.Server`
  - `GET /healthz` → `200 ok`
  - `GET /vapid-public-key` → `200 {"key": "..."}`
  - `POST /registrations` body `{accessToken, refreshToken, subscription:{endpoint, keys:{p256dh, auth}}}` → `201 {"id","deleteSecret"}` | 400 | 401 | 403 | 413 | 429 | 503
  - `GET /registrations/{id}` + `Authorization: Bearer <deleteSecret>` → `200 {"lastSuccessAt": number|null, "lastFailure": string|null}` | 403 | 404
  - `DELETE /registrations/{id}` + 같은 헤더 → 204 | 403 | 404
  - 모든 응답에 `Access-Control-Allow-Origin: <allowedOrigin>`(요청 Origin이 같을 때만), `OPTIONS` → 204

- [ ] **Step 1: 실패 테스트** — `notifier/test/http.test.mjs`

```js
import test from "node:test";
import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { createSealer } from "../src/crypto.mjs";
import { AuthRevokedError } from "../src/errors.mjs";
import { createNotifierServer } from "../src/http.mjs";
import { openStore } from "../src/store.mjs";

const ORIGIN = "https://barahana25.github.io";
const body = {
  accessToken: "acc",
  refreshToken: "ref",
  subscription: { endpoint: "https://web.push.apple.com/QGf", keys: { p256dh: "BNc", auth: "tBH" } },
};

async function start(over = {}) {
  const store = openStore({ path: ":memory:", sealer: createSealer(randomBytes(32)) });
  const linus = { profile: async () => ({ loginId: "S20250001" }) };
  const server = createNotifierServer({
    store,
    linus,
    hmacKey: randomBytes(32),
    vapidPublicKey: "BPUBLIC",
    allowedOrigin: ORIGIN,
    maxAccounts: 300,
    trustForwardedFor: false,
    ...over,
    ...(over.linus ? {} : { linus }),
  });
  await new Promise((r) => server.listen(0, "127.0.0.1", r));
  const base = `http://127.0.0.1:${server.address().port}`;
  const call = (path, init = {}) =>
    fetch(base + path, { ...init, headers: { Origin: ORIGIN, "Content-Type": "application/json", ...(init.headers ?? {}) } });
  return { store, server, call, close: () => new Promise((r) => server.close(r)) };
}

test("등록하면 기기 ID와 삭제 비밀 값을 주고 학번은 저장하지 않는다", async () => {
  const app = await start();
  const res = await app.call("/registrations", { method: "POST", body: JSON.stringify(body) });
  assert.equal(res.status, 201);
  assert.equal(res.headers.get("access-control-allow-origin"), ORIGIN);
  const { id, deleteSecret } = await res.json();
  assert.equal(id.length, 32);
  assert.equal(app.store.countAccounts(), 1);
  assert.ok(!JSON.stringify(app.store.rawRowsForTest()).includes("20250001"));
  assert.ok(!JSON.stringify(app.store.rawRowsForTest()).includes(deleteSecret));

  const status = await app.call(`/registrations/${id}`, { headers: { Authorization: `Bearer ${deleteSecret}` } });
  assert.equal(status.status, 200);
  assert.deepEqual(await status.json(), { lastSuccessAt: null, lastFailure: null });

  const wrong = await app.call(`/registrations/${id}`, { method: "DELETE", headers: { Authorization: "Bearer nope" } });
  assert.equal(wrong.status, 403);
  const del = await app.call(`/registrations/${id}`, { method: "DELETE", headers: { Authorization: `Bearer ${deleteSecret}` } });
  assert.equal(del.status, 204);
  assert.equal(app.store.countAccounts(), 0);
  assert.equal((await app.call(`/registrations/${id}`, { headers: { Authorization: `Bearer ${deleteSecret}` } })).status, 404);
  await app.close();
});

test("허용하지 않은 Origin은 403이다", async () => {
  const app = await start();
  const res = await app.call("/registrations", { method: "POST", body: JSON.stringify(body), headers: { Origin: "https://evil.test" } });
  assert.equal(res.status, 403);
  await app.close();
});

test("잘못된 구독 주소나 형식은 400이다", async () => {
  const app = await start({ registerRateMax: 100 });
  for (const bad of [
    { ...body, subscription: { ...body.subscription, endpoint: "https://169.254.169.254/latest" } },
    { ...body, subscription: { ...body.subscription, endpoint: "http://web.push.apple.com/x" } },
    { ...body, accessToken: "" },
    { ...body, subscription: { endpoint: body.subscription.endpoint } },
  ]) {
    const res = await app.call("/registrations", { method: "POST", body: JSON.stringify(bad) });
    assert.equal(res.status, 400, JSON.stringify(bad));
  }
  assert.equal((await app.call("/registrations", { method: "POST", body: "{" })).status, 400);
  assert.equal((await app.call("/registrations", { method: "POST", body: "x".repeat(20_000) })).status, 413);
  await app.close();
});

test("학교 서버가 토큰을 거부하면 401이고 저장하지 않는다", async () => {
  const app = await start({
    linus: {
      profile: async () => {
        throw new AuthRevokedError("linus 401");
      },
    },
  });
  const res = await app.call("/registrations", { method: "POST", body: JSON.stringify(body) });
  assert.equal(res.status, 401);
  assert.equal(app.store.countAccounts(), 0);
  await app.close();
});

test("인원이 가득 차면 새 계정은 503이다", async () => {
  const app = await start({ maxAccounts: 1 });
  app.store.saveAccount({ accountKey: "other", tokens: { accessToken: "x", refreshToken: "y" }, now: 1 });
  const res = await app.call("/registrations", { method: "POST", body: JSON.stringify(body) });
  assert.equal(res.status, 503);
  await app.close();
});

test("같은 주소의 등록 요청은 10분에 5번까지다", async () => {
  const app = await start();
  const statuses = [];
  for (let i = 0; i < 6; i++) {
    statuses.push((await app.call("/registrations", { method: "POST", body: "{" })).status);
  }
  assert.deepEqual(statuses, [400, 400, 400, 400, 400, 429]);
  await app.close();
});

test("상태 확인과 공개키", async () => {
  const app = await start();
  assert.equal(await (await app.call("/healthz")).text(), "ok");
  assert.deepEqual(await (await app.call("/vapid-public-key")).json(), { key: "BPUBLIC" });
  const pre = await app.call("/registrations", { method: "OPTIONS" });
  assert.equal(pre.status, 204);
  assert.match(pre.headers.get("access-control-allow-methods"), /DELETE/);
  await app.close();
});
```

Run (notifier/): `npm test`
Expected: FAIL (`Cannot find module '../src/http.mjs'`)

- [ ] **Step 2: 구현** — `notifier/src/http.mjs`

```js
import http from "node:http";
import { AuthRevokedError } from "./errors.mjs";
import { accountKeyFor, hashSecret, newDeleteSecret, newDeviceId, secretMatches } from "./crypto.mjs";

const MAX_BODY = 16 * 1024;
const RATE_WINDOW_MS = 10 * 60 * 1000;
const RATE_MAX = 5;
// 서버가 이 주소로 POST하므로 알려진 푸시 서비스만 허용한다(SSRF 방지).
const PUSH_HOSTS = [/^web\.push\.apple\.com$/, /\.push\.apple\.com$/, /^fcm\.googleapis\.com$/,
  /^updates\.push\.services\.mozilla\.com$/, /\.notify\.windows\.com$/];
const DEVICE_PATH = /^\/registrations\/([0-9a-f]{32})$/;

function validSubscription(s) {
  if (!s || typeof s !== "object" || typeof s.endpoint !== "string") return false;
  if (typeof s.keys?.p256dh !== "string" || typeof s.keys?.auth !== "string") return false;
  let url;
  try {
    url = new URL(s.endpoint);
  } catch {
    return false;
  }
  return url.protocol === "https:" && PUSH_HOSTS.some((re) => re.test(url.hostname));
}

const validToken = (t) => typeof t === "string" && t.length > 0 && t.length < 4096;

export function createNotifierServer({
  store, linus, hmacKey, vapidPublicKey, allowedOrigin, maxAccounts, trustForwardedFor, now = Date.now,
  registerRateMax = RATE_MAX,
}) {
  // 주소는 메모리의 요청 수 집계에만 쓰고 저장·로그하지 않는다.
  const hits = new Map();

  function clientAddress(req) {
    if (trustForwardedFor) {
      const last = String(req.headers["x-forwarded-for"] ?? "").split(",").map((s) => s.trim()).filter(Boolean).at(-1);
      if (last) return last;
    }
    return req.socket.remoteAddress ?? "unknown";
  }

  function limited(req) {
    const t = now();
    const key = clientAddress(req);
    const recent = (hits.get(key) ?? []).filter((x) => t - x < RATE_WINDOW_MS);
    recent.push(t);
    hits.set(key, recent);
    return recent.length > registerRateMax;
  }

  function send(res, status, payload, origin) {
    const headers = { "Cache-Control": "no-store", Vary: "Origin" };
    if (origin === allowedOrigin) {
      headers["Access-Control-Allow-Origin"] = allowedOrigin;
      headers["Access-Control-Allow-Methods"] = "GET, POST, DELETE, OPTIONS";
      headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type";
      headers["Access-Control-Max-Age"] = "600";
    }
    if (payload === undefined) {
      res.writeHead(status, headers).end();
    } else if (typeof payload === "string") {
      res.writeHead(status, { ...headers, "Content-Type": "text/plain; charset=utf-8" }).end(payload);
    } else {
      res.writeHead(status, { ...headers, "Content-Type": "application/json" }).end(JSON.stringify(payload));
    }
  }

  function readBody(req) {
    return new Promise((resolve, reject) => {
      const chunks = [];
      let size = 0;
      // 너무 큰 본문도 끝까지 읽고 버린다. 중간에 끊으면 413 응답을 보내지 못한다.
      req.on("data", (c) => {
        size += c.length;
        if (size <= MAX_BODY) chunks.push(c);
      });
      req.on("end", () => {
        if (size > MAX_BODY) reject(Object.assign(new Error("too large"), { status: 413 }));
        else resolve(Buffer.concat(chunks).toString("utf8"));
      });
      req.on("error", reject);
    });
  }

  function authorizedDevice(req, id) {
    const device = store.getDevice(id);
    if (!device) return { status: 404 };
    const secret = /^Bearer (.+)$/.exec(req.headers.authorization ?? "")?.[1];
    if (!secretMatches(secret, device.deleteSecretHash)) return { status: 403 };
    return { device };
  }

  async function register(req, res, origin) {
    if (limited(req)) return send(res, 429, { error: "잠시 후 다시 시도해 주세요." }, origin);
    let parsed;
    try {
      parsed = JSON.parse(await readBody(req));
    } catch (e) {
      return send(res, e.status === 413 ? 413 : 400, { error: "요청 형식이 올바르지 않아요." }, origin);
    }
    const { accessToken, refreshToken, subscription } = parsed ?? {};
    if (!validToken(accessToken) || !validToken(refreshToken) || !validSubscription(subscription)) {
      return send(res, 400, { error: "요청 형식이 올바르지 않아요." }, origin);
    }
    const tokens = { accessToken, refreshToken };
    let loginId;
    try {
      ({ loginId } = await linus.profile(tokens));
    } catch (e) {
      if (e instanceof AuthRevokedError) return send(res, 401, { error: "로그인이 만료됐어요. 다시 로그인해 주세요." }, origin);
      return send(res, 502, { error: "학교 서버에 연결하지 못했어요." }, origin);
    }
    const accountKey = accountKeyFor(hmacKey, loginId);
    if (!store.getAccount(accountKey) && store.countAccounts() >= maxAccounts) {
      return send(res, 503, { error: "지금은 알림 등록 인원이 가득 찼어요." }, origin);
    }
    store.saveAccount({ accountKey, tokens, now: now() });
    const id = newDeviceId();
    const deleteSecret = newDeleteSecret();
    store.addDevice({ id, accountKey, deleteSecretHash: hashSecret(deleteSecret), subscription, now: now() });
    return send(res, 201, { id, deleteSecret }, origin);
  }

  return http.createServer(async (req, res) => {
    const origin = req.headers.origin;
    const url = new URL(req.url, "http://localhost");
    try {
      if (req.method === "GET" && url.pathname === "/healthz") return send(res, 200, "ok", origin);
      if (req.method === "GET" && url.pathname === "/vapid-public-key") {
        return send(res, 200, { key: vapidPublicKey }, origin);
      }
      const deviceMatch = DEVICE_PATH.exec(url.pathname);
      if (url.pathname !== "/registrations" && !deviceMatch) return send(res, 404, { error: "not found" }, origin);
      if (origin !== allowedOrigin) return send(res, 403, { error: "허용되지 않은 출처예요." }, origin);
      if (req.method === "OPTIONS") return send(res, 204, undefined, origin);
      if (req.method === "POST" && url.pathname === "/registrations") return await register(req, res, origin);
      if (deviceMatch && (req.method === "GET" || req.method === "DELETE")) {
        const { device, status } = authorizedDevice(req, deviceMatch[1]);
        if (!device) return send(res, status, { error: status === 404 ? "등록이 없어요." : "권한이 없어요." }, origin);
        if (req.method === "DELETE") {
          store.deleteDevice(device.id);
          return send(res, 204, undefined, origin);
        }
        const account = store.getAccount(device.accountKey);
        return send(res, 200, { lastSuccessAt: account?.lastSuccessAt ?? null, lastFailure: account?.lastFailure ?? null }, origin);
      }
      return send(res, 405, { error: "method not allowed" }, origin);
    } catch (e) {
      console.error(`request failed: ${e?.name ?? "Error"}`);
      if (!res.headersSent) send(res, 500, { error: "서버 오류" }, origin);
    }
  });
}
```

주의: `start({ linus })`로 넘긴 `linus`가 기본 `linus`를 덮어쓰도록 테스트가 작성돼 있다. 413 테스트는 본문 16KB 초과다.

- [ ] **Step 3: 통과 확인**

Run (notifier/): `npm test`
Expected: PASS

- [ ] **Step 4: 커밋**

```bash
git add notifier/src/http.mjs notifier/test/http.test.mjs
git commit -m "feat: 알림 서버 등록 API

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: 서버 실행, 배포 파일, 개인정보 문서

**Files:**
- Create: `notifier/src/config.mjs`, `notifier/src/main.mjs`
- Create: `notifier/Dockerfile`, `notifier/compose.yaml`, `notifier/README.md`, `notifier/tool/make_secrets.mjs`
- Create: `.github/workflows/notifier-image.yml`
- Create: `docs/pwa/notifier-privacy.md`
- Test: `notifier/test/config.test.mjs`

**Interfaces:**
- Consumes: Task 3~7 전부
- Produces (`config.mjs`): `loadConfig(env, readFile) -> {port, dbPath, allowedOrigin, maxAccounts, trustForwardedFor, tokenKey: Buffer, hmacKey: Buffer, vapidPublicKey, vapidPrivateKey, vapidSubject}`
- 비밀 파일 형식(`NOTIFIER_SECRETS` 경로의 JSON): `{"tokenKey": base64(32B), "hmacKey": base64(32B), "vapidPublicKey": "...", "vapidPrivateKey": "...", "vapidSubject": "mailto:..."}`

- [ ] **Step 1: 실패 테스트** — `notifier/test/config.test.mjs`

```js
import test from "node:test";
import assert from "node:assert/strict";
import { randomBytes } from "node:crypto";
import { loadConfig } from "../src/config.mjs";

const secrets = {
  tokenKey: randomBytes(32).toString("base64"),
  hmacKey: randomBytes(32).toString("base64"),
  vapidPublicKey: "BPUB",
  vapidPrivateKey: "PRIV",
  vapidSubject: "mailto:admin@example.com",
};

test("환경 변수와 비밀 파일을 읽는다", () => {
  const config = loadConfig(
    { NOTIFIER_SECRETS: "/run/secrets/n.json", NOTIFIER_ALLOWED_ORIGIN: "https://barahana25.github.io" },
    () => JSON.stringify(secrets),
  );
  assert.equal(config.port, 8080);
  assert.equal(config.dbPath, "/data/notifier.sqlite");
  assert.equal(config.maxAccounts, 300);
  assert.equal(config.trustForwardedFor, false);
  assert.equal(config.tokenKey.length, 32);
  assert.equal(config.vapidSubject, "mailto:admin@example.com");
});

test("키 길이가 틀리거나 Origin이 없으면 시작하지 않는다", () => {
  const read = () => JSON.stringify({ ...secrets, tokenKey: randomBytes(16).toString("base64") });
  assert.throws(() => loadConfig({ NOTIFIER_SECRETS: "x", NOTIFIER_ALLOWED_ORIGIN: "https://a.b" }, read));
  assert.throws(() => loadConfig({ NOTIFIER_SECRETS: "x" }, () => JSON.stringify(secrets)));
});
```

Run (notifier/): `npm test`
Expected: FAIL (`Cannot find module '../src/config.mjs'`)

- [ ] **Step 2: 구현** — `notifier/src/config.mjs`

```js
function key32(value, name) {
  const buf = Buffer.from(String(value ?? ""), "base64");
  if (buf.length !== 32) throw new Error(`${name}는 base64로 인코딩한 32바이트여야 합니다.`);
  return buf;
}

export function loadConfig(env, readFile) {
  const allowedOrigin = env.NOTIFIER_ALLOWED_ORIGIN;
  if (!allowedOrigin) throw new Error("NOTIFIER_ALLOWED_ORIGIN이 비어 있습니다.");
  if (!env.NOTIFIER_SECRETS) throw new Error("NOTIFIER_SECRETS(비밀 파일 경로)가 비어 있습니다.");
  const secrets = JSON.parse(readFile(env.NOTIFIER_SECRETS));
  for (const name of ["vapidPublicKey", "vapidPrivateKey", "vapidSubject"]) {
    if (typeof secrets[name] !== "string" || secrets[name] === "") throw new Error(`비밀 파일에 ${name}가 없습니다.`);
  }
  const maxAccounts = Number.parseInt(env.NOTIFIER_MAX_ACCOUNTS ?? "300", 10);
  return {
    port: Number(env.PORT ?? 8080),
    dbPath: env.NOTIFIER_DB ?? "/data/notifier.sqlite",
    allowedOrigin,
    maxAccounts: Number.isFinite(maxAccounts) && maxAccounts > 0 ? maxAccounts : 300,
    trustForwardedFor: ["1", "true"].includes(String(env.NOTIFIER_TRUST_FORWARDED_FOR ?? "").toLowerCase()),
    tokenKey: key32(secrets.tokenKey, "tokenKey"),
    hmacKey: key32(secrets.hmacKey, "hmacKey"),
    vapidPublicKey: secrets.vapidPublicKey,
    vapidPrivateKey: secrets.vapidPrivateKey,
    vapidSubject: secrets.vapidSubject,
  };
}
```

`notifier/src/main.mjs`:

```js
import { readFileSync } from "node:fs";
import webpush from "web-push";
import { createCanvasClient } from "./canvas.mjs";
import { loadConfig } from "./config.mjs";
import { createSealer } from "./crypto.mjs";
import { createNotifierServer } from "./http.mjs";
import { runTick } from "./jobs.mjs";
import { createLinusClient } from "./linus.mjs";
import { createPusher } from "./push.mjs";
import { openStore } from "./store.mjs";

const config = loadConfig(process.env, (path) => readFileSync(path, "utf8"));
const store = openStore({ path: config.dbPath, sealer: createSealer(config.tokenKey) });
const linus = createLinusClient({});
webpush.setVapidDetails(config.vapidSubject, config.vapidPublicKey, config.vapidPrivateKey);
const pusher = createPusher({
  store,
  send: (subscription, payload) => webpush.sendNotification(subscription, payload, { TTL: 6 * 3600 }),
});

createNotifierServer({
  store,
  linus,
  hmacKey: config.hmacKey,
  vapidPublicKey: config.vapidPublicKey,
  allowedOrigin: config.allowedOrigin,
  maxAccounts: config.maxAccounts,
  trustForwardedFor: config.trustForwardedFor,
}).listen(config.port, "0.0.0.0", () => {
  console.log(`notifier listening on :${config.port}, maxAccounts=${config.maxAccounts}`);
});

// 로그는 집계만 남긴다. 토큰·학번·계정 키·제목·주소는 남기지 않는다.
const inFlight = new Set();
let running = false;
setInterval(async () => {
  if (running) return;
  running = true;
  try {
    const stats = await runTick({
      store, linus, pusher, inFlight, now: Date.now(),
      createCanvas: () => createCanvasClient({ linus }),
    });
    if (stats.checked || stats.rotated || stats.revoked) {
      console.log(
        `tick accounts=${store.countAccounts()} checked=${stats.checked} rotated=${stats.rotated} ` +
          `new=${stats.notices} failures=${stats.failures} revoked=${stats.revoked}`,
      );
    }
  } catch (e) {
    console.error(`tick failed: ${e?.name ?? "Error"}`);
  } finally {
    running = false;
  }
}, 60_000);
```

`notifier/tool/make_secrets.mjs`:

```js
// NAS에서 한 번 실행해 비밀 파일을 만든다: node tool/make_secrets.mjs mailto:you@example.com > secrets.json
import { randomBytes } from "node:crypto";
import webpush from "web-push";

const subject = process.argv[2];
if (!subject?.startsWith("mailto:")) {
  console.error("사용법: node tool/make_secrets.mjs mailto:you@example.com > secrets.json");
  process.exit(1);
}
const vapid = webpush.generateVAPIDKeys();
console.log(
  JSON.stringify(
    {
      tokenKey: randomBytes(32).toString("base64"),
      hmacKey: randomBytes(32).toString("base64"),
      vapidPublicKey: vapid.publicKey,
      vapidPrivateKey: vapid.privateKey,
      vapidSubject: subject,
    },
    null,
    2,
  ),
);
```

- [ ] **Step 3: 통과 확인**

Run (notifier/): `npm test`
Expected: PASS

- [ ] **Step 4: 배포 파일**

`notifier/Dockerfile`:

```dockerfile
FROM node:24-bookworm-slim
WORKDIR /app
ENV NODE_ENV=production
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY src ./src
COPY tool ./tool
USER node
EXPOSE 8080
HEALTHCHECK --interval=60s CMD node -e "fetch('http://127.0.0.1:8080/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "src/main.mjs"]
```

`notifier/compose.yaml`:

```yaml
# Synology Container Manager > 프로젝트에 이 파일을 넣는다. image는 README대로 digest로 바꾼다.
services:
  notifier:
    image: ghcr.io/barahana25/kumoh-lms-notifier:main
    restart: unless-stopped
    environment:
      NOTIFIER_ALLOWED_ORIGIN: https://barahana25.github.io
      NOTIFIER_SECRETS: /run/secrets/notifier.json
      NOTIFIER_DB: /data/notifier.sqlite
      NOTIFIER_MAX_ACCOUNTS: "300"
      # 포트가 127.0.0.1에만 열려 있어 접속자가 DSM 리버스 프록시뿐이다. 외부에 직접 열면 지운다.
      NOTIFIER_TRUST_FORWARDED_FOR: "1"
      PORT: "8080"
    ports:
      - "127.0.0.1:18081:8080"
    volumes:
      - ./data:/data
      - ./secrets.json:/run/secrets/notifier.json:ro
    read_only: true
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
```

`.github/workflows/notifier-image.yml`:

```yaml
name: notifier-image

on:
  push:
    branches: [main]
    paths:
      - "notifier/**"
      - "test/fixtures/notifications/**"
      - ".github/workflows/notifier-image.yml"
  pull_request:
    branches: [main]
    paths:
      - "notifier/**"
      - "test/fixtures/notifications/**"
      - ".github/workflows/notifier-image.yml"
  workflow_dispatch:

permissions:
  contents: read
  packages: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 24

      - name: 테스트
        working-directory: notifier
        run: npm ci && npm test

      - uses: docker/login-action@v3
        if: github.event_name != 'pull_request'
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/build-push-action@v6
        with:
          context: notifier
          platforms: linux/amd64
          push: ${{ github.event_name != 'pull_request' }}
          tags: |
            ghcr.io/barahana25/kumoh-lms-notifier:main
            ghcr.io/barahana25/kumoh-lms-notifier:${{ github.sha }}
```

- [ ] **Step 5: 문서** — `notifier/README.md` (아래 `~~~` 사이 내용)

~~~markdown
# 금오 LMS PWA 알림 서버

알림을 켠 웹앱 사용자만 등록한다. 등록한 사용자의 로그인 토큰으로 학교 LMS를 매시 확인하고 새 글을 Web Push로 알린다. 중계 서버(`relay/`)와 다른 컨테이너이며, 중계 서버는 계속 자격 증명을 다루지 않는다. 무엇을 보관하는지는 [docs/pwa/notifier-privacy.md](../docs/pwa/notifier-privacy.md)에 있다.

## 로컬 개발

```bash
npm install
npm test
```

## Synology NAS 배포

1. **비밀 파일**: 프로젝트 폴더에서 한 번만 만든다. 이 파일을 잃으면 모든 등록이 무효가 되고, 유출되면 저장된 토큰을 열 수 있다.
   `docker run --rm ghcr.io/barahana25/kumoh-lms-notifier:main node tool/make_secrets.mjs mailto:운영자메일 > secrets.json`
   권한은 `chmod 600 secrets.json`. 저장소에 올리지 않는다.
2. **데이터 폴더**: 프로젝트 폴더에 `data/`를 만든다. 백업하면 암호화된 토큰이 함께 백업된다. 백업을 보관하지 않는 편이 낫다.
3. **컨테이너**: Container Manager → 프로젝트 → 생성. `compose.yaml`의 `image`를 배포할 커밋의 digest(`ghcr.io/barahana25/kumoh-lms-notifier@sha256:...`)로 바꾼다.
4. **리버스 프록시**: 제어판 → 로그인 포털 → 고급 → 리버스 프록시 → 생성
   - 소스: HTTPS, `barahana.synology.me`, 포트 8444
   - 대상: HTTP, `localhost`, 포트 18081
   - 인증서: 제어판 → 보안 → 인증서 → 설정에서 `barahana.synology.me:8444`에 Let's Encrypt 인증서 지정
5. **공유기**: TCP 8444 → NAS
6. **확인**: `curl.exe https://barahana.synology.me:8444/healthz`가 인증서 오류 없이 `ok`
7. GitHub 저장소 → Settings → Secrets and variables → Actions → Variables에 `NOTIFIER_URL` = `https://barahana.synology.me:8444` (끝에 `/` 없음)

## 로그

회차별 집계만 남긴다(`tick accounts=12 checked=3 rotated=9 new=2 failures=0 revoked=0`). 토큰, 학번, 계정 키, 글 제목, 접속 주소, 푸시 주소는 남기지 않는다.
~~~

`docs/pwa/notifier-privacy.md`:

```markdown
# 새 소식 알림(서버 확인) 개인정보 안내

iPhone 웹앱은 앱이 닫혀 있을 때 스스로 새 글을 확인할 수 없다. 이 기능을 켜면 운영자 NAS의 알림 서버가 대신 확인한다. 켜지 않으면 아래 내용은 해당하지 않는다.

## 서버가 보관하는 것

- 로그인 토큰(accessToken, refreshToken): 암호화해 보관한다. 50분마다 새 토큰으로 바꾼다.
- 푸시 받을 기기 주소: 암호화해 보관한다.
- 계정 구분값: 학번에서 계산한 값(HMAC)이다. 학번 자체는 저장하지 않는다.
- 이미 본 글의 번호: 강좌 번호, 글 종류, 글 번호(숫자)만.
- 마지막 확인 시각과 실패 여부.

## 보관하지 않는 것

- 비밀번호. 서버로 보내지 않는다.
- 글 제목, 강좌명, 본문. 알림을 보낼 때만 잠깐 쓰고 저장하지 않는다.
- 접속 IP. 요청 수 제한에 메모리로만 쓴다.

## 운영자가 볼 수 있는 것

- 토큰의 유효 기간 안에서는 학교 LMS에서 본인이 볼 수 있는 모든 것을 조회할 수 있다. 암호화 키가 같은 NAS에 있어서 암호화는 운영자로부터 보호하지 않는다. 디스크나 백업 파일만 유출됐을 때를 막는다.
- 알림을 보내는 순간의 글 제목.
- 서버 코드는 공개 저장소의 `notifier/`에 있고, 배포 이미지는 GitHub Actions가 그 코드로 만든다.

## 끄기와 삭제

- 앱 설정에서 끄면 기기 정보를 바로 지운다. 그 계정에 남은 기기가 없으면 토큰과 본 글 기록도 지운다.
- 앱이나 LMS 웹에서 로그아웃하면 학교 서버가 모든 세션을 끊는다. 서버는 이를 감지하면 "알림이 멈췄어요" 알림을 한 번 보내고 기록을 지운다.
- 알림 서버는 학교 서버에 로그아웃 요청을 보내지 않는다.

## 확인 시간

한국 시간 08:01~00:01 사이 매시 한 번 확인한다. 01~07시에는 확인하지 않고 토큰만 바꾼다.
```

- [ ] **Step 6: 이미지 빌드 확인** (Docker가 있으면)

Run (notifier/): `docker build -t kumoh-lms-notifier:test .`
Expected: 성공. Docker가 없으면 이 단계는 CI(`notifier-image.yml`)에 맡기고 보고서에 적는다.

- [ ] **Step 7: 커밋**

```bash
git add notifier/src/config.mjs notifier/src/main.mjs notifier/tool/make_secrets.mjs notifier/test/config.test.mjs notifier/Dockerfile notifier/compose.yaml notifier/README.md .github/workflows/notifier-image.yml docs/pwa/notifier-privacy.md
git commit -m "feat: 알림 서버 실행·배포 파일과 개인정보 안내

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 9: 웹앱 푸시 연결과 알림 서버 클라이언트

**Files:**
- Create: `web/push_bridge.js`, `web/push_sw.js`
- Modify: `web/index.html` (libcurl 내보내기 줄 다음에 `<script src="push_bridge.js"></script>`)
- Modify: `lib/core/config/env.dart` (`notifierUrl`)
- Create: `lib/features/notifications/web_push/web_push_port.dart`, `web_push_port_stub.dart`, `web_push_port_web.dart`, `web_push.dart`
- Create: `lib/features/notifications/data/notifier_api.dart`
- Create: `lib/features/notifications/web_notification_controller.dart`
- Modify: `test/core/web_index_html_test.dart`
- Test: `test/features/notifications/notifier_api_test.dart`, `test/features/notifications/web_notification_controller_test.dart`

**Interfaces:**
- Consumes: Task 1 `AuthApi.reissue(refresh, {accessToken})`; Task 7 API 응답 형식; 기존 `tokenStoreProvider`, `authApiProvider`
- Produces:
  - `Env.notifierUrl` (`String.fromEnvironment('NOTIFIER_URL')`, 기본 빈 문자열)
  - `abstract interface class WebPushPort { bool get standalone; bool get supported; Future<Map<String, Object?>> subscribe(String vapidPublicKey); Future<void> unsubscribe(); String? read(String key); void write(String key, String? value); }`
  - `class PushPermissionDenied implements Exception`
  - `WebPushPort createWebPushPort()` (`web_push.dart`에서 조건부 export)
  - `class NotifierFailure implements Exception { final String message; }`
  - `class NotifierRegistration { id, deleteSecret; toJson(); fromJson() }`, `class NotifierStatus { DateTime? lastSuccessAt; String? lastFailure; }`
  - `class NotifierApi { vapidPublicKey(); register({tokens, subscription}); status(reg) -> NotifierStatus?; delete(reg) }`
  - `webPushPortProvider`, `notifierApiProvider`, `webNotificationControllerProvider` (`AsyncNotifier<WebNotificationState>`: `enable()`, `disable()`)
  - `class WebNotificationState { bool registered; DateTime? lastSuccessAt; String? lastFailure; }`

- [ ] **Step 1: 서비스 워커와 브리지** — `web/push_sw.js`

```js
// 알림 서버의 Web Push를 받아 표시한다. 앱 내부 경로(/kumoh-LMS/)만 연다.
self.addEventListener("push", (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (_) {
    data = {};
  }
  const title = typeof data.title === "string" ? data.title : "금오 LMS";
  const body = typeof data.body === "string" ? data.body : "새 소식이 있어요.";
  const url = typeof data.url === "string" && data.url.startsWith("/kumoh-LMS/") ? data.url : "/kumoh-LMS/";
  event.waitUntil(self.registration.showNotification(title, { body, data: { url }, icon: "icons/Icon-192.png" }));
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const path = event.notification.data?.url;
  const url = new URL(typeof path === "string" && path.startsWith("/kumoh-LMS/") ? path : "/kumoh-LMS/", self.location.origin);
  event.waitUntil(self.clients.openWindow(url.href));
});
```

`web/push_bridge.js`:

```js
// Flutter(web_push_port_web.dart)가 부르는 푸시 구독 함수. package:web의 API 차이를 피하려고 JS로 둔다.
(function () {
  function toBytes(base64url) {
    const pad = "=".repeat((4 - (base64url.length % 4)) % 4);
    const raw = atob((base64url + pad).replace(/-/g, "+").replace(/_/g, "/"));
    return Uint8Array.from(raw, (c) => c.charCodeAt(0));
  }

  window.kumohPush = {
    standalone() {
      return window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone === true;
    },
    supported() {
      return "serviceWorker" in navigator && "PushManager" in window && "Notification" in window;
    },
    // iOS는 사용자 탭 안에서 권한을 요청해야 하므로 권한 요청을 가장 먼저 한다.
    async subscribe(vapidPublicKey) {
      const permission = await Notification.requestPermission();
      if (permission !== "granted") throw new Error("permission-denied");
      const registration = await navigator.serviceWorker.register("push_sw.js", { scope: "./" });
      await navigator.serviceWorker.ready;
      const old = await registration.pushManager.getSubscription();
      if (old) await old.unsubscribe();
      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: toBytes(vapidPublicKey),
      });
      return JSON.stringify(subscription.toJSON());
    },
    async unsubscribe() {
      const registration = await navigator.serviceWorker.getRegistration("./");
      const subscription = registration ? await registration.pushManager.getSubscription() : null;
      if (subscription) await subscription.unsubscribe();
    },
  };
})();
```

`web/index.html`에서 `<script>window.libcurl = libcurl;</script>` 다음 줄에 추가:

```html
  <!-- 새 소식 알림(서버 확인)의 푸시 구독. 파일은 web/push_bridge.js -->
  <script src="push_bridge.js"></script>
```

`test/core/web_index_html_test.dart`의 `main()` 안에 테스트를 추가:

```dart
  test('index.html이 Flutter 시작 전에 푸시 브리지를 불러온다', () {
    final html = File('web/index.html').readAsStringSync();
    final bridge = html.indexOf('<script src="push_bridge.js"></script>');
    final bootstrap = html.indexOf('<script src="flutter_bootstrap.js"');
    expect(bridge, isNonNegative);
    expect(bootstrap, greaterThan(bridge));
  });
```

Run: `C:\src\flutter\bin\flutter.bat test test/core/web_index_html_test.dart`
Expected: PASS

- [ ] **Step 2: 설정값과 푸시 포트**

`lib/core/config/env.dart`의 `relayUrl` 아래에 추가:

```dart
  /// 새 소식 알림(서버 확인) 서버. 끝에 `/`가 없다. 비어 있으면 웹 알림 영역을 숨긴다.
  /// 배포 빌드는 `--dart-define=NOTIFIER_URL=https://...`로 넣는다.
  static const String notifierUrl = String.fromEnvironment('NOTIFIER_URL');
```

`lib/features/notifications/web_push/web_push_port.dart`:

```dart
/// 웹 푸시 구독과 등록 정보 보관. 웹이 아니면 [supported]가 false다.
abstract interface class WebPushPort {
  /// 홈 화면에 추가한 앱으로 실행 중인가. iOS는 이때만 푸시를 허용한다.
  bool get standalone;
  bool get supported;

  /// 알림 권한을 요청하고 구독한다. 반환값은 PushSubscription.toJSON().
  Future<Map<String, Object?>> subscribe(String vapidPublicKey);
  Future<void> unsubscribe();
  String? read(String key);
  void write(String key, String? value);
}

class PushPermissionDenied implements Exception {
  const PushPermissionDenied();
}
```

`lib/features/notifications/web_push/web_push_port_stub.dart`:

```dart
import 'web_push_port.dart';

WebPushPort createWebPushPort() => const _UnsupportedWebPushPort();

class _UnsupportedWebPushPort implements WebPushPort {
  const _UnsupportedWebPushPort();

  @override
  bool get standalone => false;

  @override
  bool get supported => false;

  @override
  Future<Map<String, Object?>> subscribe(String vapidPublicKey) =>
      throw UnsupportedError('웹에서만 푸시를 구독할 수 있습니다.');

  @override
  Future<void> unsubscribe() async {}

  @override
  String? read(String key) => null;

  @override
  void write(String key, String? value) {}
}
```

`lib/features/notifications/web_push/web_push_port_web.dart`:

```dart
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'web_push_port.dart';

@JS('kumohPush')
external _KumohPush? get _kumohPush;

extension type _KumohPush._(JSObject _) implements JSObject {
  external bool standalone();
  external bool supported();
  external JSPromise<JSString> subscribe(String vapidPublicKey);
  external JSPromise<JSAny?> unsubscribe();
}

WebPushPort createWebPushPort() => _BrowserWebPushPort();

/// web/push_bridge.js의 window.kumohPush를 쓴다.
class _BrowserWebPushPort implements WebPushPort {
  @override
  bool get standalone => _kumohPush?.standalone() ?? false;

  @override
  bool get supported => _kumohPush?.supported() ?? false;

  @override
  Future<Map<String, Object?>> subscribe(String vapidPublicKey) async {
    final bridge = _kumohPush;
    if (bridge == null) throw UnsupportedError('push_bridge.js를 불러오지 못했습니다.');
    try {
      final json = (await bridge.subscribe(vapidPublicKey).toDart).toDart;
      return (jsonDecode(json) as Map).cast<String, Object?>();
    } on Object catch (e) {
      if ('$e'.contains('permission-denied')) throw const PushPermissionDenied();
      rethrow;
    }
  }

  @override
  Future<void> unsubscribe() async {
    await _kumohPush?.unsubscribe().toDart;
  }

  @override
  String? read(String key) => web.window.localStorage.getItem(key);

  @override
  void write(String key, String? value) {
    if (value == null) {
      web.window.localStorage.removeItem(key);
    } else {
      web.window.localStorage.setItem(key, value);
    }
  }
}
```

`lib/features/notifications/web_push/web_push.dart`:

```dart
export 'web_push_port.dart';
export 'web_push_port_stub.dart'
    if (dart.library.js_interop) 'web_push_port_web.dart';
```

Run: `C:\src\flutter\bin\flutter.bat analyze lib/features/notifications/web_push lib/core/config`
Expected: `No issues found!`

- [ ] **Step 3: 알림 서버 클라이언트 실패 테스트** — `test/features/notifications/notifier_api_test.dart`

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/features/auth/data/auth_dto.dart';
import 'package:kumoh_lms/features/notifications/data/notifier_api.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  const reg = NotifierRegistration(id: 'abc', deleteSecret: 'secret');

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://notifier.test'));
    adapter = DioAdapter(dio: dio);
  });

  test('등록은 새 토큰과 구독을 보내고 기기 ID와 삭제 비밀 값을 받는다', () async {
    const tokens = AuthTokens(accessToken: 'a2', refreshToken: 'r2');
    final sub = {
      'endpoint': 'https://web.push.apple.com/x',
      'keys': {'p256dh': 'p', 'auth': 'a'}
    };
    adapter.onPost('/registrations',
        (s) => s.reply(201, {'id': 'abc', 'deleteSecret': 'secret'}),
        data: {'accessToken': 'a2', 'refreshToken': 'r2', 'subscription': sub});
    final result =
        await NotifierApi(dio).register(tokens: tokens, subscription: sub);
    expect(result.id, 'abc');
    expect(NotifierRegistration.fromJson(result.toJson()).deleteSecret, 'secret');
  });

  test('서버 오류 문구를 NotifierFailure로 전한다', () async {
    adapter.onPost('/registrations',
        (s) => s.reply(503, {'error': '지금은 알림 등록 인원이 가득 찼어요.'}),
        data: Matchers.any);
    await expectLater(
        NotifierApi(dio).register(
            tokens: const AuthTokens(accessToken: 'a', refreshToken: 'r'),
            subscription: const {}),
        throwsA(isA<NotifierFailure>().having(
            (e) => e.message, 'message', '지금은 알림 등록 인원이 가득 찼어요.')));
  });

  test('상태는 삭제 비밀 값으로 읽고 없으면 null이다', () async {
    adapter.onGet('/registrations/abc',
        (s) => s.reply(200, {'lastSuccessAt': 1757900000000, 'lastFailure': null}),
        headers: {'Authorization': 'Bearer secret'});
    final status = await NotifierApi(dio).status(reg);
    expect(status!.lastSuccessAt,
        DateTime.fromMillisecondsSinceEpoch(1757900000000));

    adapter.onGet('/registrations/abc', (s) => s.reply(404, {'error': '등록이 없어요.'}),
        headers: {'Authorization': 'Bearer secret'});
    expect(await NotifierApi(dio).status(reg), isNull);
  });

  test('삭제는 이미 없는 등록이어도 성공으로 본다', () async {
    adapter.onDelete('/registrations/abc', (s) => s.reply(404, {}),
        headers: {'Authorization': 'Bearer secret'});
    await NotifierApi(dio).delete(reg);
  });
}
```

Run: `C:\src\flutter\bin\flutter.bat test test/features/notifications/notifier_api_test.dart`
Expected: FAIL (`notifier_api.dart` 없음)

- [ ] **Step 4: 구현** — `lib/features/notifications/data/notifier_api.dart`

```dart
import 'package:dio/dio.dart';

import '../../../core/config/env.dart';
import '../../auth/data/auth_dto.dart';

class NotifierFailure implements Exception {
  const NotifierFailure(this.message);
  final String message;

  @override
  String toString() => 'NotifierFailure: $message';
}

class NotifierRegistration {
  const NotifierRegistration({required this.id, required this.deleteSecret});
  final String id;
  final String deleteSecret;

  Map<String, String> toJson() => {'id': id, 'deleteSecret': deleteSecret};

  static NotifierRegistration? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final secret = json['deleteSecret'];
    if (id is! String || secret is! String) return null;
    return NotifierRegistration(id: id, deleteSecret: secret);
  }
}

class NotifierStatus {
  const NotifierStatus({this.lastSuccessAt, this.lastFailure});
  final DateTime? lastSuccessAt;
  final String? lastFailure;
}

Dio buildNotifierDio() => Dio(BaseOptions(
      baseUrl: Env.notifierUrl,
      connectTimeout: Env.connectTimeout,
      receiveTimeout: Env.receiveTimeout,
      contentType: Headers.jsonContentType,
      validateStatus: (s) => s != null && s < 600,
    ));

/// NAS의 알림 서버. 학교 서버가 아니라서 libcurl 터널이 아니라 브라우저 요청을 쓴다.
class NotifierApi {
  NotifierApi(this._dio);
  final Dio _dio;

  static const _unreachable = NotifierFailure('알림 서버에 연결하지 못했어요.');

  Future<Response<Object?>> _send(Future<Response<Object?>> Function() request) async {
    try {
      return await request();
    } on DioException {
      throw _unreachable;
    }
  }

  Never _fail(Response<Object?> res) {
    final body = res.data;
    final message = body is Map ? body['error'] : null;
    throw NotifierFailure(message is String ? message : '알림 서버가 요청을 처리하지 못했어요.');
  }

  Options _auth(NotifierRegistration reg) =>
      Options(headers: {'Authorization': 'Bearer ${reg.deleteSecret}'});

  Future<String> vapidPublicKey() async {
    final res = await _send(() => _dio.get<Object?>('/vapid-public-key'));
    final key = res.data is Map ? (res.data as Map)['key'] : null;
    if (res.statusCode != 200 || key is! String) _fail(res);
    return key;
  }

  Future<NotifierRegistration> register({
    required AuthTokens tokens,
    required Map<String, Object?> subscription,
  }) async {
    final res = await _send(() => _dio.post<Object?>('/registrations', data: {
          'accessToken': tokens.accessToken,
          'refreshToken': tokens.refreshToken,
          'subscription': subscription,
        }));
    final reg = NotifierRegistration.fromJson(res.data);
    if (res.statusCode != 201 || reg == null) _fail(res);
    return reg;
  }

  Future<NotifierStatus?> status(NotifierRegistration reg) async {
    final res = await _send(
        () => _dio.get<Object?>('/registrations/${reg.id}', options: _auth(reg)));
    if (res.statusCode == 404 || res.statusCode == 403) return null;
    final body = res.data;
    if (res.statusCode != 200 || body is! Map) _fail(res);
    final success = body['lastSuccessAt'];
    final failure = body['lastFailure'];
    return NotifierStatus(
      lastSuccessAt: success is num
          ? DateTime.fromMillisecondsSinceEpoch(success.toInt())
          : null,
      lastFailure: failure is String ? failure : null,
    );
  }

  Future<void> delete(NotifierRegistration reg) async {
    final res = await _send(
        () => _dio.delete<Object?>('/registrations/${reg.id}', options: _auth(reg)));
    if (res.statusCode == 204 || res.statusCode == 404 || res.statusCode == 403) return;
    _fail(res);
  }
}
```

Run: `C:\src\flutter\bin\flutter.bat test test/features/notifications/notifier_api_test.dart`
Expected: PASS

- [ ] **Step 5: 컨트롤러 실패 테스트** — `test/features/notifications/web_notification_controller_test.dart`

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/features/auth/data/auth_api.dart';
import 'package:kumoh_lms/features/notifications/data/notifier_api.dart';
import 'package:kumoh_lms/features/notifications/web_notification_controller.dart';
import 'package:kumoh_lms/features/notifications/web_push/web_push.dart';
import 'package:kumoh_lms/providers.dart';

class FakePort implements WebPushPort {
  final values = <String, String>{};
  var unsubscribed = false;

  @override
  bool get standalone => true;

  @override
  bool get supported => true;

  @override
  Future<Map<String, Object?>> subscribe(String vapidPublicKey) async => {
        'endpoint': 'https://web.push.apple.com/x',
        'keys': {'p256dh': 'p', 'auth': vapidPublicKey},
      };

  @override
  Future<void> unsubscribe() async => unsubscribed = true;

  @override
  String? read(String key) => values[key];

  @override
  void write(String key, String? value) =>
      value == null ? values.remove(key) : values[key] = value;
}

void main() {
  test('켜면 현재 세션을 재발급한 새 토큰으로 등록하고, 끄면 서버와 기기에서 지운다', () async {
    final store = InMemoryTokenStore();
    await store.saveTokens(accessToken: 'a1', refreshToken: 'r1');

    final authDio = Dio(BaseOptions(baseUrl: 'https://lms.test/api/v1'));
    DioAdapter(dio: authDio).onPost('/reissue',
        (s) => s.reply(200, {
              'code': '200',
              'data': {'accessToken': 'a2', 'refreshToken': 'r2'}
            }),
        headers: {'Authorization': 'Bearer a1', 'X-Refresh-Token': 'r1'});

    final notifierDio = Dio(BaseOptions(
        baseUrl: 'https://notifier.test', validateStatus: (s) => s != null));
    final notifier = DioAdapter(dio: notifierDio);
    notifier.onGet('/vapid-public-key', (s) => s.reply(200, {'key': 'VAPID'}));
    notifier.onPost('/registrations',
        (s) => s.reply(201, {'id': 'abc', 'deleteSecret': 'secret'}),
        data: {
          'accessToken': 'a2',
          'refreshToken': 'r2',
          'subscription': {
            'endpoint': 'https://web.push.apple.com/x',
            'keys': {'p256dh': 'p', 'auth': 'VAPID'},
          },
        });
    notifier.onDelete('/registrations/abc', (s) => s.reply(204, null),
        headers: {'Authorization': 'Bearer secret'});

    final port = FakePort();
    final container = ProviderContainer(overrides: [
      tokenStoreProvider.overrideWithValue(store),
      authApiProvider.overrideWithValue(AuthApi(authDio, tokenStore: store)),
      notifierApiProvider.overrideWithValue(NotifierApi(notifierDio)),
      webPushPortProvider.overrideWithValue(port),
    ]);
    addTearDown(container.dispose);

    expect((await container.read(webNotificationControllerProvider.future)).registered,
        isFalse);

    await container.read(webNotificationControllerProvider.notifier).enable();
    expect(container.read(webNotificationControllerProvider).value!.registered, isTrue);
    expect(port.values.values.single, contains('secret'));
    // 앱 세션의 토큰은 그대로 둔다(재발급해도 이전 토큰이 유효하다).
    expect(await store.readAccessToken(), 'a1');

    await container.read(webNotificationControllerProvider.notifier).disable();
    expect(container.read(webNotificationControllerProvider).value!.registered, isFalse);
    expect(port.values, isEmpty);
    expect(port.unsubscribed, isTrue);
  });
}
```

Run: `C:\src\flutter\bin\flutter.bat test test/features/notifications/web_notification_controller_test.dart`
Expected: FAIL (`web_notification_controller.dart` 없음)

- [ ] **Step 6: 구현** — `lib/features/notifications/web_notification_controller.dart`

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import 'data/notifier_api.dart';
import 'web_push/web_push.dart';

final webPushPortProvider = Provider<WebPushPort>((ref) => createWebPushPort());

final notifierApiProvider =
    Provider<NotifierApi>((ref) => NotifierApi(buildNotifierDio()));

final webNotificationControllerProvider =
    AsyncNotifierProvider<WebNotificationController, WebNotificationState>(
        WebNotificationController.new);

class WebNotificationState {
  const WebNotificationState(
      {required this.registered, this.lastSuccessAt, this.lastFailure});
  final bool registered;
  final DateTime? lastSuccessAt;
  final String? lastFailure;
}

/// 새 소식 알림(서버 확인). 등록 정보는 기기 localStorage에만 둔다.
class WebNotificationController extends AsyncNotifier<WebNotificationState> {
  static const storageKey = 'kumoh_notifier_registration';
  static const _off = WebNotificationState(registered: false);

  // iOS는 사용자 탭 직후에만 알림 권한 요청을 허용한다. 켜기 전에 미리 받아 둔다.
  String? _vapidKey;

  NotifierRegistration? _saved(WebPushPort port) {
    final raw = port.read(storageKey);
    if (raw == null) return null;
    try {
      return NotifierRegistration.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<WebNotificationState> build() async {
    final port = ref.watch(webPushPortProvider);
    final api = ref.watch(notifierApiProvider);
    if (port.supported) {
      unawaited(api
          .vapidPublicKey()
          .then<void>((key) => _vapidKey = key)
          .catchError((Object _) {}));
    }
    final reg = _saved(port);
    if (reg == null) return _off;
    try {
      final status = await api.status(reg);
      if (status == null) {
        port.write(storageKey, null);
        return _off;
      }
      return WebNotificationState(
          registered: true,
          lastSuccessAt: status.lastSuccessAt,
          lastFailure: status.lastFailure);
    } on NotifierFailure catch (e) {
      return WebNotificationState(registered: true, lastFailure: e.message);
    }
  }

  Future<void> enable() async {
    final port = ref.read(webPushPortProvider);
    final api = ref.read(notifierApiProvider);
    final store = ref.read(tokenStoreProvider);
    final key = _vapidKey ?? await api.vapidPublicKey();
    final subscription = await port.subscribe(key);
    final refresh = await store.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      throw const NotifierFailure('다시 로그인한 뒤 알림을 켜 주세요.');
    }
    // 서버 전용 토큰. 재발급해도 앱의 현재 토큰은 계속 유효하므로 앱 쪽은 바꾸지 않는다.
    final tokens = await ref
        .read(authApiProvider)
        .reissue(refresh, accessToken: await store.readAccessToken());
    final reg = await api.register(tokens: tokens, subscription: subscription);
    port.write(storageKey, jsonEncode(reg.toJson()));
    state = const AsyncData(WebNotificationState(registered: true));
  }

  Future<void> disable() async {
    final port = ref.read(webPushPortProvider);
    final reg = _saved(port);
    if (reg != null) await ref.read(notifierApiProvider).delete(reg);
    try {
      await port.unsubscribe();
    } on Object {
      // 서버 기록은 이미 지웠다. 브라우저 구독 해지는 실패해도 푸시가 오지 않는다.
    }
    port.write(storageKey, null);
    state = const AsyncData(_off);
  }
}
```

- [ ] **Step 7: 통과 확인**

Run: `C:\src\flutter\bin\flutter.bat test test/features/notifications test/core`
Expected: PASS

Run: `C:\src\flutter\bin\flutter.bat analyze`
Expected: `No issues found!`

- [ ] **Step 8: 커밋**

```bash
git add web/push_bridge.js web/push_sw.js web/index.html lib/core/config/env.dart lib/features/notifications/web_push lib/features/notifications/data/notifier_api.dart lib/features/notifications/web_notification_controller.dart test/core/web_index_html_test.dart test/features/notifications/notifier_api_test.dart test/features/notifications/web_notification_controller_test.dart
git commit -m "feat: 웹앱 푸시 구독과 알림 서버 등록

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 10: 설정 화면, 로그아웃 경고, 배포 설정

**Files:**
- Create: `lib/features/notifications/presentation/web_notification_section.dart`
- Modify: `lib/features/settings/presentation/settings_screen.dart`
- Modify: `.github/workflows/pwa.yml`
- Modify: `docs/pwa/verification.md`
- Test: `test/features/notifications/web_notification_section_test.dart`

**Interfaces:**
- Consumes: Task 9 `webPushPortProvider`, `webNotificationControllerProvider`, `WebNotificationController.enable/disable`, `PushPermissionDenied`, `NotifierFailure`; 기존 `SettingsStatusCard`, `openLink`
- Produces: `WebNotificationSection({bool visible = kIsWeb && Env.notifierUrl != ''})`, 상수 `notifierPrivacyUrl`

- [ ] **Step 1: 실패 테스트** — `test/features/notifications/web_notification_section_test.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/notifications/presentation/web_notification_section.dart';
import 'package:kumoh_lms/features/notifications/web_notification_controller.dart';
import 'package:kumoh_lms/features/notifications/web_push/web_push.dart';

class _Port implements WebPushPort {
  _Port({required this.standalone});
  @override
  final bool standalone;
  @override
  bool get supported => true;
  @override
  Future<Map<String, Object?>> subscribe(String vapidPublicKey) async => {};
  @override
  Future<void> unsubscribe() async {}
  @override
  String? read(String key) => null;
  @override
  void write(String key, String? value) {}
}

class _Controller extends WebNotificationController {
  _Controller(this.initial);
  final WebNotificationState initial;
  var enabled = false;

  @override
  Future<WebNotificationState> build() async => initial;

  @override
  Future<void> enable() async {
    enabled = true;
    state = const AsyncData(WebNotificationState(registered: true));
  }
}

Widget _app(WebPushPort port, _Controller controller) => ProviderScope(
      overrides: [
        webPushPortProvider.overrideWithValue(port),
        webNotificationControllerProvider.overrideWith(() => controller),
      ],
      child: const MaterialApp(
          home: Scaffold(body: WebNotificationSection(visible: true))),
    );

void main() {
  testWidgets('홈 화면에 추가하지 않았으면 스위치 대신 안내를 보여준다', (tester) async {
    await tester.pumpWidget(_app(_Port(standalone: false),
        _Controller(const WebNotificationState(registered: false))));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
    expect(find.textContaining('홈 화면에 추가'), findsOneWidget);
  });

  testWidgets('켜기 전에 서버가 보관하는 정보에 동의를 받는다', (tester) async {
    final controller = _Controller(const WebNotificationState(registered: false));
    await tester.pumpWidget(_app(_Port(standalone: true), controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('web_notifications')));
    await tester.pumpAndSettle();
    expect(find.textContaining('비밀번호는 보내지 않아요'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(controller.enabled, isFalse);

    await tester.tap(find.byKey(const Key('web_notifications')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('동의하고 켜기'));
    await tester.pumpAndSettle();
    expect(controller.enabled, isTrue);
  });

  testWidgets('켜져 있으면 마지막 확인 상태를 보여준다', (tester) async {
    await tester.pumpWidget(_app(
        _Port(standalone: true),
        _Controller(const WebNotificationState(
            registered: true, lastFailure: '학교 서버에 연결하지 못했어요'))));
    await tester.pumpAndSettle();
    expect(find.text('학교 서버에 연결하지 못했어요'), findsOneWidget);
  });

  testWidgets('웹이 아니거나 서버 주소가 없으면 아무것도 그리지 않는다', (tester) async {
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: Scaffold(body: WebNotificationSection(visible: false)))));
    expect(find.byType(ListTile), findsNothing);
  });
}
```

Run: `C:\src\flutter\bin\flutter.bat test test/features/notifications/web_notification_section_test.dart`
Expected: FAIL (`web_notification_section.dart` 없음)

- [ ] **Step 2: 구현** — `lib/features/notifications/presentation/web_notification_section.dart`

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/config/env.dart';
import '../../../core/ui/open_link.dart';
import '../../../core/ui/settings_widgets.dart';
import '../data/notifier_api.dart';
import '../web_notification_controller.dart';
import '../web_push/web_push.dart';

const notifierPrivacyUrl =
    'https://github.com/barahana25/kumoh-LMS/blob/main/docs/pwa/notifier-privacy.md';

/// docs/pwa/notifier-privacy.md의 요약. 문서를 바꾸면 여기도 같이 바꾼다.
const _consentPoints = [
  '비밀번호는 보내지 않아요. 로그인 토큰만 알림 서버에 암호화해 보관해요.',
  '글 제목·강좌명은 저장하지 않고, 이미 본 글의 번호만 저장해요.',
  '운영자는 토큰으로 내 LMS를 조회할 수 있어요. 암호화 키도 같은 서버에 있어요.',
  '한국 시간 08:01~00:01에 매시 확인해요.',
  '끄면 서버 기록을 바로 지워요. 로그아웃하면 알림이 멈춰요.',
];

class WebNotificationSection extends ConsumerStatefulWidget {
  const WebNotificationSection(
      {super.key, this.visible = kIsWeb && Env.notifierUrl != ''});
  final bool visible;

  @override
  ConsumerState<WebNotificationSection> createState() =>
      _WebNotificationSectionState();
}

class _WebNotificationSectionState extends ConsumerState<WebNotificationSection> {
  bool _busy = false;

  Future<bool> _consent() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('새 소식 알림을 켤까요?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('앱이 닫혀 있어도 알림을 받으려면 운영자 서버가 대신 확인해요.'),
            const SizedBox(height: 12),
            for (final point in _consentPoints)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $point'),
              ),
            TextButton(
              onPressed: () => openLink(dialogContext, notifierPrivacyUrl),
              child: const Text('자세한 안내 보기'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('동의하고 켜기')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _change(bool on) async {
    if (on && !await _consent()) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final controller = ref.read(webNotificationControllerProvider.notifier);
      on ? await controller.enable() : await controller.disable();
    } on PushPermissionDenied {
      messenger.showSnackBar(const SnackBar(
          content: Text('알림 권한을 허용해야 켤 수 있어요. 설정 → 알림에서 허용해 주세요.')));
    } on NotifierFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on Object {
      messenger.showSnackBar(SnackBar(
          content: Text(on ? '알림을 켜지 못했어요. 다시 시도해 주세요.' : '알림을 끄지 못했어요. 다시 시도해 주세요.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final port = ref.watch(webPushPortProvider);
    if (!port.standalone || !port.supported) {
      return const ListTile(
        leading: Icon(Icons.notifications_off_outlined),
        title: Text('새 소식 알림'),
        subtitle: Text('Safari 공유 버튼 → 홈 화면에 추가한 앱에서 켤 수 있어요.'),
      );
    }
    final state = ref.watch(webNotificationControllerProvider);
    final value = state.valueOrNull;
    final registered = value?.registered ?? false;
    final lastSuccess = value?.lastSuccessAt;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SwitchListTile(
        key: const Key('web_notifications'),
        secondary: const Icon(Icons.notifications_outlined),
        title: const Text('새 소식 알림 (서버 확인)'),
        subtitle: const Text('공지·파일·과제·토론이 올라오면 알려드려요'),
        value: registered,
        onChanged: _busy || state.isLoading ? null : _change,
      ),
      if (registered)
        SettingsStatusCard(
          busy: _busy,
          active: value?.lastFailure == null,
          message: value?.lastFailure ??
              (lastSuccess == null
                  ? '첫 확인을 기다리고 있어요'
                  : '마지막 확인 ${DateFormat('M/d HH:mm').format(lastSuccess.toLocal())}'),
          actionLabel: '보관 정보',
          onAction: () => openLink(context, notifierPrivacyUrl),
        ),
    ]);
  }
}
```

- [ ] **Step 3: 통과 확인**

Run: `C:\src\flutter\bin\flutter.bat test test/features/notifications/web_notification_section_test.dart`
Expected: PASS

- [ ] **Step 4: 설정 화면과 로그아웃**

`lib/features/settings/presentation/settings_screen.dart` 맨 위 import에 추가:

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../notifications/presentation/web_notification_section.dart';
import '../../notifications/web_notification_controller.dart';
```

`const NotificationSettingsSection(),` 줄을 바꾼다:

```dart
          if (kIsWeb)
            const WebNotificationSection()
          else
            const NotificationSettingsSection(),
```

로그아웃 `onTap`의 `showDialog` 앞에 서버 알림 여부를 읽고, 대화상자 문구와 확인 뒤 동작을 바꾼다.

```dart
            onTap: () async {
              final serverNotifications = ref
                      .read(webNotificationControllerProvider)
                      .valueOrNull
                      ?.registered ==
                  true;
              final ok = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('로그아웃'),
                  content: Text(serverNotifications
                      ? '로그아웃하면 새 소식 알림도 꺼져요. 저장된 데이터를 모두 지우고 로그아웃할까요?'
                      : '저장된 데이터를 모두 지우고 로그아웃할까요?'),
```

(`actions`는 그대로 둔다.) 확인 뒤 `logout()`을 부르기 전에 추가:

```dart
                if (serverNotifications) {
                  try {
                    await ref.read(webNotificationControllerProvider.notifier).disable();
                  } on Object {
                    // 서버 기록 삭제에 실패해도 로그아웃하면 학교 서버가 세션을 끊어 알림이 멈춘다.
                  }
                }
```

Run: `C:\src\flutter\bin\flutter.bat test`
Expected: 전체 PASS. 안드로이드 설정 화면 테스트가 있으면 `kIsWeb`이 false라 기존 `NotificationSettingsSection`이 그대로 보여야 한다.

Run: `C:\src\flutter\bin\flutter.bat analyze`
Expected: `No issues found!`

- [ ] **Step 5: 배포 설정** — `.github/workflows/pwa.yml`

"중계 서버 주소 확인" 단계 다음에 추가:

```yaml
      # 알림 서버 주소는 선택이다. 없으면 설정 화면의 웹 알림 영역을 숨긴 채 빌드한다.
      - name: 알림 서버 주소 확인
        env:
          EVENT_NAME: ${{ github.event_name }}
          NOTIFIER_URL: ${{ vars.NOTIFIER_URL }}
        run: |
          if [ "$EVENT_NAME" = "pull_request" ] || [ -z "$NOTIFIER_URL" ]; then
            echo "BUILD_NOTIFIER_URL=" >> "$GITHUB_ENV"
            exit 0
          fi
          case "$NOTIFIER_URL" in
            */) echo "vars.NOTIFIER_URL은 끝에 /가 없어야 합니다." >&2; exit 1 ;;
            https://?*) echo "BUILD_NOTIFIER_URL=$NOTIFIER_URL" >> "$GITHUB_ENV" ;;
            *) echo "vars.NOTIFIER_URL은 https://로 시작해야 합니다." >&2; exit 1 ;;
          esac
```

"웹 빌드" 단계의 명령 끝에 한 줄 추가:

```yaml
          --dart-define=NOTIFIER_URL="$BUILD_NOTIFIER_URL"
```

- [ ] **Step 6: 실기기 확인 목록** — `docs/pwa/verification.md` 끝에 추가

```markdown
## 새 소식 알림 (서버 확인)

- [ ] `https://barahana.synology.me:8444/healthz` → `ok` (인증서 오류 없음)
- [ ] Safari 탭에서 설정을 열면 스위치 대신 "홈 화면에 추가한 앱에서 켤 수 있어요" 안내가 보인다
- [ ] 홈 화면 앱에서 스위치 → 동의 화면 → "동의하고 켜기" → iOS 알림 권한 요청이 뜬다(뜨지 않으면 탭과 권한 요청 사이 대기가 원인인지 기록)
- [ ] 켠 뒤 설정에 "첫 확인을 기다리고 있어요", 다음 정시 확인 뒤 "마지막 확인 HH:mm"
- [ ] 테스트 강좌에 새 글이 올라온 다음 회차에 "[공지] 강좌명" 푸시가 오고, 누르면 그 강좌의 해당 탭이 열린다
- [ ] 끄면 NAS 로그의 `accounts=` 수가 줄고 이후 푸시가 오지 않는다
- [ ] 알림을 켠 상태로 LMS 웹에서 로그아웃하면 50분 안에 "알림이 멈췄어요" 푸시가 오고 설정 스위치가 꺼진다
- [ ] NAS Container Manager 로그에 토큰·학번·글 제목·IP가 없다
```

- [ ] **Step 7: 웹 빌드 확인**

Run (PowerShell): `C:\src\flutter\bin\flutter.bat build web --release --no-web-resources-cdn --base-href /kumoh-LMS/ --dart-define=RELAY_URL=wss://barahana.synology.me:8443/ --dart-define=NOTIFIER_URL=https://barahana.synology.me:8444`
Expected: `√ Built build\web`, `build/web/push_sw.js`와 `build/web/push_bridge.js` 존재

- [ ] **Step 8: 커밋**

```bash
git add lib/features/notifications/presentation/web_notification_section.dart lib/features/settings/presentation/settings_screen.dart .github/workflows/pwa.yml docs/pwa/verification.md test/features/notifications/web_notification_section_test.dart
git commit -m "feat: 웹 설정 화면에 새 소식 알림(서버 확인) 추가

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```
