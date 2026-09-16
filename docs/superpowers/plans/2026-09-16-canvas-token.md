# Canvas 액세스 토큰 자동 발급 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 로그인 직후 Canvas 개인 액세스 토큰을 자동 발급해 저장하고, Canvas 조회를 세션 쿠키 대신 그 토큰으로 한다.

**Architecture:** 발급은 기존 SAML 다리(`CanvasSession`)로 얻은 Canvas 세션에서 한 번만 일어난다. `CanvasTokenApi`(HTTP) → `CanvasTokenStore`(보관) → `CanvasTokenService`(상태 기계) 세 층으로 나누고, `canvasSessionInterceptor`가 토큰이 있으면 `Authorization: Bearer`를 붙이고 다리를 건너뛴다. 발급이 실패하면 지금의 쿠키 경로로 조용히 폴백한다.

**Tech Stack:** Flutter, dio, cookie_jar, flutter_secure_storage, riverpod, flutter_test

설계 문서: [docs/superpowers/specs/2026-09-16-canvas-token-design.md](../specs/2026-09-16-canvas-token-design.md)

## Global Constraints

- 범위는 **안드로이드**. 웹앱 저장·알림 서버·LINUS 탈출은 이 계획 밖이다.
- 토큰 값은 로그·`debugPrint`·오류 메시지에 절대 남기지 않는다.
- 발급 실패는 사용자에게 오류로 보이지 않는다. 쿠키 경로로 폴백한다.
- Canvas 토큰 이름(`purpose`)은 `금오LMS 앱 · <플랫폼> · <임의 4자>` 형식이고 기기마다 고정이다.
- 재시도는 요청당 한 번만 한다(`kCanvasRetryFlag`와 같은 방식).
- 커밋 메시지는 한국어 한 줄 요약 + 본문, 끝에 `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.
- 모든 작업은 worktree `C:\Users\barah\Desktop\canvas\.claude\worktrees\pwa-relay`, 브랜치 `feat/canvas-token`에서 한다.
- 각 Task 끝에서 `flutter analyze`가 깨끗해야 한다.

## File Structure

| 파일 | 책임 |
|---|---|
| `lib/features/canvas/data/canvas_token_api.dart` (신규) | Canvas 토큰 생성·목록·삭제 HTTP. CSRF 헤더 처리 |
| `lib/features/canvas/data/canvas_token_store.dart` (신규) | 토큰 값·id·기기 이름 보관. 보안 저장소/메모리 두 구현 |
| `lib/features/canvas/data/canvas_token_service.dart` (신규) | 상태 기계. 발급·재발급·해지, single-flight |
| `lib/features/canvas/data/canvas_api.dart` (수정) | `canvasSessionInterceptor`에 토큰 경로 추가 |
| `lib/providers.dart` (수정) | 위 셋을 배선하고 `canvasDioProvider`에 연결 |
| `lib/features/auth/presentation/auth_controller.dart` (수정) | 로그인 후 발급 시작, 로그아웃 때 해지 |
| `lib/features/canvas/presentation/canvas_connection_section.dart` (신규) | 설정 화면의 "Canvas 연결" 영역 |
| `lib/features/settings/presentation/settings_screen.dart` (수정) | 위 영역 삽입 |
| `lib/features/notifications/data/lms_notification_source.dart` (수정) | 백그라운드 조회도 토큰을 쓰게 한다 |
| `docs/canvas-token.md` (신규) | 권한 범위·저장 위치·해지 방법 안내 |

---

### Task 1: CanvasTokenApi

**Files:**
- Create: `lib/features/canvas/data/canvas_token_api.dart`
- Test: `test/features/canvas/canvas_token_api_test.dart`

**Interfaces:**
- Consumes: `Env.canvasHost`, `Env.canvasApiBaseUrl` (`lib/core/config/env.dart`), `buildCanvasDio(CookieJar)` (`lib/features/canvas/data/canvas_client.dart`)
- Produces:
  - `class IssuedCanvasToken { final int id; final String token; final String purpose; }`
  - `class CanvasTokenSummary { final int id; final String purpose; }`
  - `class CanvasTokenUnavailable implements Exception`
  - `class CanvasTokenApi { CanvasTokenApi(Dio dio, CookieJar jar); Future<IssuedCanvasToken> create(String purpose); Future<List<CanvasTokenSummary>> list(); Future<void> delete(int id); }`

Canvas는 세션 쿠키로 인증하는 쓰기 요청에 `X-CSRF-Token` 헤더를 요구한다. 값은 쿠키 `_csrf_token`을 URL 디코딩한 것이다. 2026-09-16 실계정 확인: 이 헤더 없이 POST하면 422, 있으면 200.

- [ ] **Step 1: Write the failing test**

`test/features/canvas/canvas_token_api_test.dart`:

```dart
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_client.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_api.dart';

/// Canvas 토큰 엔드포인트만 흉내내는 어댑터.
class _TokenScript implements HttpClientAdapter {
  _TokenScript({this.csrfOnWarmup});

  /// 준비 요청(GET /)에서 내려줄 CSRF 쿠키 값. null이면 안 준다.
  final String? csrfOnWarmup;
  final List<String> calls = [];
  final List<String?> csrfHeaders = [];
  String? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.uri.path}');
    csrfHeaders.add(options.headers['X-CSRF-Token'] as String?);

    if (options.method == 'GET' && options.uri.path == '/') {
      return ResponseBody.fromString('', 200, headers: {
        if (csrfOnWarmup != null)
          'set-cookie': ['_csrf_token=$csrfOnWarmup; path=/'],
      });
    }
    if (options.method == 'POST' && options.uri.path == '/api/v1/users/self/tokens') {
      lastBody = options.data?.toString();
      return ResponseBody.fromString(
        '{"id":44,"visible_token":"7~abc","purpose":"금오LMS 앱 · Android · a3f9"}',
        200,
        headers: {
          'content-type': ['application/json'],
        },
      );
    }
    if (options.method == 'GET' && options.uri.path == '/api/v1/users/self/tokens') {
      return ResponseBody.fromString(
        '[{"id":41,"purpose":"금오LMS 앱 · Android · a3f9"},'
        '{"id":42,"purpose":"내가 만든 토큰"}]',
        200,
        headers: {
          'content-type': ['application/json'],
        },
      );
    }
    if (options.method == 'DELETE') {
      return ResponseBody.fromString('{"id":41}', 200, headers: {
        'content-type': ['application/json'],
      });
    }
    return ResponseBody.fromString('', 404);
  }

  @override
  void close({bool force = false}) {}
}

Future<CookieJar> _jarWithCsrf(String value) async {
  final jar = DefaultCookieJar();
  await jar.saveFromResponse(
    Uri.parse('https://canvas.kumoh.ac.kr/'),
    [Cookie('_csrf_token', value)..path = '/'],
  );
  return jar;
}

void main() {
  test('토큰을 만들 때 CSRF 헤더를 디코딩해 붙이고 purpose를 보낸다', () async {
    // Canvas 쿠키는 URL 인코딩된 채로 저장된다. 헤더에는 디코딩해 넣어야 한다.
    final jar = await _jarWithCsrf('ab%2Bcd%3D');
    final script = _TokenScript();
    final api = CanvasTokenApi(buildCanvasDio(jar, adapter: script), jar);

    final issued = await api.create('금오LMS 앱 · Android · a3f9');

    expect(issued.id, 44);
    expect(issued.token, '7~abc');
    expect(script.csrfHeaders.last, 'ab+cd=');
    expect(script.lastBody, contains('금오LMS 앱'));
  });

  test('CSRF 쿠키가 없으면 준비 요청을 한 번 보내고 이어서 만든다', () async {
    final jar = DefaultCookieJar();
    final script = _TokenScript(csrfOnWarmup: 'warm');
    final api = CanvasTokenApi(buildCanvasDio(jar, adapter: script), jar);

    final issued = await api.create('금오LMS 앱 · Android · a3f9');

    expect(issued.id, 44);
    expect(script.calls.first, 'GET /');
    expect(script.csrfHeaders.last, 'warm');
  });

  test('준비 요청에도 CSRF가 없으면 CanvasTokenUnavailable을 던진다', () async {
    final jar = DefaultCookieJar();
    final script = _TokenScript();
    final api = CanvasTokenApi(buildCanvasDio(jar, adapter: script), jar);

    expect(() => api.create('금오LMS 앱 · Android · a3f9'),
        throwsA(isA<CanvasTokenUnavailable>()));
  });

  test('목록은 id와 purpose만 뽑는다', () async {
    final jar = await _jarWithCsrf('x');
    final api = CanvasTokenApi(
        buildCanvasDio(jar, adapter: _TokenScript()), jar);

    final tokens = await api.list();

    expect(tokens.map((t) => t.id), [41, 42]);
    expect(tokens.first.purpose, '금오LMS 앱 · Android · a3f9');
  });

  test('삭제는 id 경로로 요청하고 CSRF를 붙인다', () async {
    final jar = await _jarWithCsrf('x');
    final script = _TokenScript();
    final api = CanvasTokenApi(buildCanvasDio(jar, adapter: script), jar);

    await api.delete(41);

    expect(script.calls.last, 'DELETE /api/v1/users/self/tokens/41');
    expect(script.csrfHeaders.last, 'x');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/canvas/canvas_token_api_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:kumoh_lms/features/canvas/data/canvas_token_api.dart'`

- [ ] **Step 3: Write minimal implementation**

`lib/features/canvas/data/canvas_token_api.dart`:

```dart
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import '../../../core/config/env.dart';

/// 방금 만든 토큰. `token`은 생성 응답에만 들어 있고 다시 볼 수 없다.
class IssuedCanvasToken {
  const IssuedCanvasToken({
    required this.id,
    required this.token,
    required this.purpose,
  });

  final int id;
  final String token;
  final String purpose;
}

/// 목록에서 보이는 토큰. 값은 포함되지 않는다.
class CanvasTokenSummary {
  const CanvasTokenSummary({required this.id, required this.purpose});

  final int id;
  final String purpose;
}

/// CSRF 쿠키를 얻지 못해 토큰을 다룰 수 없는 상태.
class CanvasTokenUnavailable implements Exception {
  const CanvasTokenUnavailable();
}

/// Canvas 개인 액세스 토큰 엔드포인트.
///
/// 세션 쿠키로 인증하는 쓰기 요청이라 Canvas가 `X-CSRF-Token`을 요구한다.
/// 값은 쿠키 `_csrf_token`을 URL 디코딩한 것이다.
class CanvasTokenApi {
  CanvasTokenApi(this._dio, this._jar);

  final Dio _dio;
  final CookieJar _jar;

  static final Uri _tokensUri = Uri.parse('${Env.canvasApiBaseUrl}/users/self/tokens');

  Future<String?> _readCsrf() async {
    final cookies = await _jar.loadForRequest(Uri.parse('${Env.canvasHost}/'));
    for (final cookie in cookies) {
      if (cookie.name == '_csrf_token' && cookie.value.isNotEmpty) {
        return Uri.decodeComponent(cookie.value);
      }
    }
    return null;
  }

  /// 브릿지 직후에는 쿠키 자에 CSRF가 없을 수 있다. 한 번만 받아온다.
  Future<String> _csrf() async {
    final existing = await _readCsrf();
    if (existing != null) return existing;
    await _dio.getUri<void>(
      Uri.parse('${Env.canvasHost}/'),
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    final warmed = await _readCsrf();
    if (warmed == null) throw const CanvasTokenUnavailable();
    return warmed;
  }

  Future<IssuedCanvasToken> create(String purpose) async {
    final csrf = await _csrf();
    final res = await _dio.postUri<Map<String, dynamic>>(
      _tokensUri,
      data: {'token[purpose]': purpose},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'X-CSRF-Token': csrf},
      ),
    );
    final body = res.data ?? const <String, dynamic>{};
    final id = body['id'];
    final token = body['visible_token'];
    if (id is! int || token is! String || token.isEmpty) {
      throw const CanvasTokenUnavailable();
    }
    return IssuedCanvasToken(id: id, token: token, purpose: purpose);
  }

  Future<List<CanvasTokenSummary>> list() async {
    final csrf = await _csrf();
    final res = await _dio.getUri<List<dynamic>>(
      _tokensUri.replace(queryParameters: {'per_page': '100'}),
      options: Options(headers: {'X-CSRF-Token': csrf}),
    );
    final result = <CanvasTokenSummary>[];
    for (final item in res.data ?? const <dynamic>[]) {
      if (item is! Map) continue;
      final id = item['id'];
      if (id is! int) continue;
      result.add(CanvasTokenSummary(
        id: id,
        purpose: item['purpose'] as String? ?? '',
      ));
    }
    return result;
  }

  Future<void> delete(int id) async {
    final csrf = await _csrf();
    await _dio.deleteUri<void>(
      Uri.parse('${Env.canvasApiBaseUrl}/users/self/tokens/$id'),
      options: Options(headers: {'X-CSRF-Token': csrf}),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/canvas/canvas_token_api_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/canvas/data/canvas_token_api.dart test/features/canvas/canvas_token_api_test.dart
git commit -m "feat: Canvas 개인 액세스 토큰 API

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: CanvasTokenStore

**Files:**
- Create: `lib/features/canvas/data/canvas_token_store.dart`
- Test: `test/features/canvas/canvas_token_store_test.dart`

**Interfaces:**
- Consumes: 없음 (`flutter_secure_storage`만 쓴다)
- Produces:
  - `class StoredCanvasToken { final String token; final int id; final String purpose; }`
  - `abstract interface class CanvasTokenStore { Future<StoredCanvasToken?> read(); Future<void> save(StoredCanvasToken value); Future<void> clear(); Future<String> ensurePurpose(String platformLabel); }`
  - `class SecureCanvasTokenStore implements CanvasTokenStore { SecureCanvasTokenStore([FlutterSecureStorage? storage]); }`
  - `class InMemoryCanvasTokenStore implements CanvasTokenStore`
  - `String buildCanvasTokenPurpose({required String platformLabel, required String suffix})`

`ensurePurpose`는 기기마다 한 번만 이름을 만들고 이후 같은 값을 돌려준다. 토큰을 지워도 이름은 남긴다. 같은 기기가 재발급할 때 Canvas에 남은 옛 토큰을 찾아 지우기 위해서다.

- [ ] **Step 1: Write the failing test**

`test/features/canvas/canvas_token_store_test.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InMemoryCanvasTokenStore', () {
    test('저장한 토큰을 그대로 읽고 지운다', () async {
      final store = InMemoryCanvasTokenStore();
      expect(await store.read(), isNull);

      await store.save(const StoredCanvasToken(
          token: '7~abc', id: 44, purpose: '금오LMS 앱 · Android · a3f9'));
      final read = await store.read();
      expect(read!.token, '7~abc');
      expect(read.id, 44);
      expect(read.purpose, '금오LMS 앱 · Android · a3f9');

      await store.clear();
      expect(await store.read(), isNull);
    });

    test('ensurePurpose는 처음에 만들고 이후 같은 값을 돌려준다', () async {
      final store = InMemoryCanvasTokenStore();
      final first = await store.ensurePurpose('Android');
      final second = await store.ensurePurpose('Android');

      expect(first, startsWith('금오LMS 앱 · Android · '));
      expect(second, first);
    });

    test('토큰을 지워도 기기 이름은 남는다', () async {
      final store = InMemoryCanvasTokenStore();
      final purpose = await store.ensurePurpose('Android');
      await store.save(StoredCanvasToken(token: 't', id: 1, purpose: purpose));
      await store.clear();

      expect(await store.ensurePurpose('Android'), purpose);
    });
  });

  group('SecureCanvasTokenStore', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('보안 저장소에 왕복 저장한다', () async {
      final store = SecureCanvasTokenStore();
      await store.save(const StoredCanvasToken(
          token: '7~abc', id: 44, purpose: '금오LMS 앱 · Android · a3f9'));

      final read = await store.read();
      expect(read!.token, '7~abc');
      expect(read.id, 44);
    });

    test('일부만 남아 있으면 없는 것으로 본다', () async {
      FlutterSecureStorage.setMockInitialValues({'canvas_pat_token': '7~abc'});
      expect(await SecureCanvasTokenStore().read(), isNull);
    });
  });

  test('buildCanvasTokenPurpose는 사람이 알아볼 형식을 만든다', () {
    expect(
      buildCanvasTokenPurpose(platformLabel: 'Android', suffix: 'a3f9'),
      '금오LMS 앱 · Android · a3f9',
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/canvas/canvas_token_store_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../canvas_token_store.dart'`

- [ ] **Step 3: Write minimal implementation**

`lib/features/canvas/data/canvas_token_store.dart`:

```dart
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 기기에 보관 중인 Canvas 토큰 한 개.
class StoredCanvasToken {
  const StoredCanvasToken({
    required this.token,
    required this.id,
    required this.purpose,
  });

  final String token;
  final int id;
  final String purpose;
}

/// Canvas 설정 화면에서 사용자가 알아볼 수 있는 이름을 만든다.
String buildCanvasTokenPurpose({
  required String platformLabel,
  required String suffix,
}) =>
    '금오LMS 앱 · $platformLabel · $suffix';

String _randomSuffix() {
  const alphabet = '0123456789abcdef';
  final rng = Random.secure();
  return List.generate(4, (_) => alphabet[rng.nextInt(alphabet.length)]).join();
}

abstract interface class CanvasTokenStore {
  Future<StoredCanvasToken?> read();
  Future<void> save(StoredCanvasToken value);

  /// 토큰만 지운다. 기기 이름은 남긴다.
  Future<void> clear();

  /// 이 기기의 토큰 이름. 없으면 만들어 저장한다.
  Future<String> ensurePurpose(String platformLabel);
}

const _kToken = 'canvas_pat_token';
const _kId = 'canvas_pat_id';
const _kPurpose = 'canvas_pat_purpose';

/// 기기 Keychain(iOS) / EncryptedSharedPreferences(Android) 기반 구현.
class SecureCanvasTokenStore implements CanvasTokenStore {
  SecureCanvasTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions:
                  IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<StoredCanvasToken?> read() async {
    final token = await _storage.read(key: _kToken);
    final id = int.tryParse(await _storage.read(key: _kId) ?? '');
    final purpose = await _storage.read(key: _kPurpose);
    if (token == null || token.isEmpty || id == null || purpose == null) {
      return null;
    }
    return StoredCanvasToken(token: token, id: id, purpose: purpose);
  }

  @override
  Future<void> save(StoredCanvasToken value) async {
    await _storage.write(key: _kToken, value: value.token);
    await _storage.write(key: _kId, value: value.id.toString());
    await _storage.write(key: _kPurpose, value: value.purpose);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kId);
  }

  @override
  Future<String> ensurePurpose(String platformLabel) async {
    final existing = await _storage.read(key: _kPurpose);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = buildCanvasTokenPurpose(
      platformLabel: platformLabel,
      suffix: _randomSuffix(),
    );
    await _storage.write(key: _kPurpose, value: created);
    return created;
  }
}

/// 테스트용 구현.
class InMemoryCanvasTokenStore implements CanvasTokenStore {
  StoredCanvasToken? _value;
  String? _purpose;

  @override
  Future<StoredCanvasToken?> read() async => _value;

  @override
  Future<void> save(StoredCanvasToken value) async {
    _value = value;
    _purpose = value.purpose;
  }

  @override
  Future<void> clear() async => _value = null;

  @override
  Future<String> ensurePurpose(String platformLabel) async =>
      _purpose ??= buildCanvasTokenPurpose(
        platformLabel: platformLabel,
        suffix: _randomSuffix(),
      );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/canvas/canvas_token_store_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/canvas/data/canvas_token_store.dart test/features/canvas/canvas_token_store_test.dart
git commit -m "feat: Canvas 토큰 보관소

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: CanvasTokenService

**Files:**
- Create: `lib/features/canvas/data/canvas_token_service.dart`
- Test: `test/features/canvas/canvas_token_service_test.dart`

**Interfaces:**
- Consumes: Task 1의 `CanvasTokenApi`·`IssuedCanvasToken`·`CanvasTokenSummary`, Task 2의 `CanvasTokenStore`·`StoredCanvasToken`
- Produces:
  - `class CanvasTokenService { CanvasTokenService({required CanvasTokenApi api, required CanvasTokenStore store, required Future<void> Function() ensureSession, required String platformLabel}); Future<String?> current(); Future<String?> ensure(); Future<String?> reissueAfterInvalid(); Future<void> revoke(); }`

규칙 네 가지:
1. 이미 있으면 그대로 쓴다. 발급은 하지 않는다.
2. 발급 전에 같은 이름의 남은 토큰을 지운다. 값은 다시 볼 수 없어 재사용할 수 없다.
3. 어떤 실패든 `null`을 돌려주고 아무것도 저장하지 않는다. 예외를 밖으로 던지지 않는다.
4. 동시에 여러 번 불러도 발급은 한 번만 한다(single-flight).

- [ ] **Step 1: Write the failing test**

`test/features/canvas/canvas_token_service_test.dart`:

```dart
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_client.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_api.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_service.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_store.dart';

/// 토큰 API를 대본대로 흉내낸다. 실제 HTTP는 Task 1에서 검증했다.
class _FakeTokenApi implements CanvasTokenApi {
  _FakeTokenApi({this.existing = const [], this.failCreate = false});

  List<CanvasTokenSummary> existing;
  bool failCreate;
  int createCount = 0;
  final List<int> deleted = [];
  bool failDelete = false;

  @override
  Future<IssuedCanvasToken> create(String purpose) async {
    createCount++;
    if (failCreate) throw const CanvasTokenUnavailable();
    return IssuedCanvasToken(id: 44, token: '7~new', purpose: purpose);
  }

  @override
  Future<List<CanvasTokenSummary>> list() async => existing;

  @override
  Future<void> delete(int id) async {
    if (failDelete) throw const CanvasTokenUnavailable();
    deleted.add(id);
  }
}

CanvasTokenService _service(
  _FakeTokenApi api,
  CanvasTokenStore store, {
  Future<void> Function()? ensureSession,
}) =>
    CanvasTokenService(
      api: api,
      store: store,
      ensureSession: ensureSession ?? () async {},
      platformLabel: 'Android',
    );

void main() {
  test('토큰이 없으면 발급해 저장한다', () async {
    final api = _FakeTokenApi();
    final store = InMemoryCanvasTokenStore();

    expect(await _service(api, store).ensure(), '7~new');
    expect((await store.read())!.id, 44);
  });

  test('이미 있으면 발급하지 않는다', () async {
    final api = _FakeTokenApi();
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~old', id: 1, purpose: '금오LMS 앱 · Android · a3f9'));

    expect(await _service(api, store).ensure(), '7~old');
    expect(api.createCount, 0);
  });

  test('같은 이름의 남은 토큰을 지우고 새로 만든다', () async {
    final store = InMemoryCanvasTokenStore();
    final purpose = await store.ensurePurpose('Android');
    final api = _FakeTokenApi(existing: [
      CanvasTokenSummary(id: 41, purpose: purpose),
      const CanvasTokenSummary(id: 42, purpose: '내가 만든 토큰'),
    ]);

    await _service(api, store).ensure();

    expect(api.deleted, [41]);
  });

  test('발급이 실패하면 null을 돌려주고 저장하지 않는다', () async {
    final api = _FakeTokenApi(failCreate: true);
    final store = InMemoryCanvasTokenStore();

    expect(await _service(api, store).ensure(), isNull);
    expect(await store.read(), isNull);
  });

  test('세션 준비가 실패해도 예외를 밖으로 던지지 않는다', () async {
    final api = _FakeTokenApi();
    final store = InMemoryCanvasTokenStore();
    final service = _service(api, store,
        ensureSession: () async => throw StateError('브릿지 실패'));

    expect(await service.ensure(), isNull);
    expect(api.createCount, 0);
  });

  test('동시에 불러도 발급은 한 번만 한다', () async {
    final api = _FakeTokenApi();
    final service = _service(api, InMemoryCanvasTokenStore());

    final results = await Future.wait([service.ensure(), service.ensure()]);

    expect(results, ['7~new', '7~new']);
    expect(api.createCount, 1);
  });

  test('reissueAfterInvalid는 저장된 토큰을 버리고 새로 발급한다', () async {
    final api = _FakeTokenApi();
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~old', id: 1, purpose: '금오LMS 앱 · Android · a3f9'));

    expect(await _service(api, store).reissueAfterInvalid(), '7~new');
    expect(api.createCount, 1);
  });

  test('revoke는 Canvas에서 지우고 로컬도 비운다', () async {
    final api = _FakeTokenApi();
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~old', id: 7, purpose: '금오LMS 앱 · Android · a3f9'));

    await _service(api, store).revoke();

    expect(api.deleted, [7]);
    expect(await store.read(), isNull);
  });

  test('Canvas 삭제가 실패해도 로컬은 비운다', () async {
    final api = _FakeTokenApi()..failDelete = true;
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~old', id: 7, purpose: '금오LMS 앱 · Android · a3f9'));

    await _service(api, store).revoke();

    expect(await store.read(), isNull);
  });

  test('current는 저장된 값만 본다. 발급하지 않는다', () async {
    final api = _FakeTokenApi();
    final service = _service(api, InMemoryCanvasTokenStore());

    expect(await service.current(), isNull);
    expect(api.createCount, 0);
  });

  test('CanvasTokenApi는 실제 Dio로도 만들 수 있다', () {
    // 가짜가 실제 타입에서 벗어나지 않았는지 확인한다.
    final jar = DefaultCookieJar();
    expect(CanvasTokenApi(buildCanvasDio(jar), jar), isA<CanvasTokenApi>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/canvas/canvas_token_service_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../canvas_token_service.dart'`

- [ ] **Step 3: Write minimal implementation**

`lib/features/canvas/data/canvas_token_service.dart`:

```dart
import 'canvas_token_api.dart';
import 'canvas_token_store.dart';

/// Canvas 개인 액세스 토큰의 수명을 관리한다.
///
/// 발급은 SAML 다리로 얻은 Canvas 세션이 필요하므로 [ensureSession]을 받는다.
/// 실패는 밖으로 던지지 않는다. 토큰이 없으면 호출자가 쿠키 경로로 폴백한다.
class CanvasTokenService {
  CanvasTokenService({
    required CanvasTokenApi api,
    required CanvasTokenStore store,
    required Future<void> Function() ensureSession,
    required String platformLabel,
  })  : _api = api,
        _store = store,
        _ensureSession = ensureSession,
        _platformLabel = platformLabel;

  final CanvasTokenApi _api;
  final CanvasTokenStore _store;
  final Future<void> Function() _ensureSession;
  final String _platformLabel;

  Future<String?>? _issuing;

  /// 저장된 토큰. 없으면 null. 발급하지 않는다.
  Future<String?> current() async => (await _store.read())?.token;

  /// 없으면 발급한다. 동시 호출은 한 번의 발급을 공유한다.
  Future<String?> ensure() async {
    final existing = await current();
    if (existing != null) return existing;
    return _issuing ??= _issue().whenComplete(() => _issuing = null);
  }

  /// 401을 만난 뒤 쓴다. 저장된 토큰을 버리고 한 번 다시 발급한다.
  Future<String?> reissueAfterInvalid() async {
    await _store.clear();
    return ensure();
  }

  /// Canvas에서 이 기기 토큰을 지우고 로컬도 비운다.
  Future<void> revoke() async {
    final stored = await _store.read();
    try {
      if (stored != null) {
        await _ensureSession();
        await _api.delete(stored.id);
      }
    } on Object {
      // 지우지 못해도 로컬은 비운다. 사용자는 Canvas 설정에서 직접 지울 수 있다.
    } finally {
      await _store.clear();
    }
  }

  Future<String?> _issue() async {
    try {
      await _ensureSession();
      final purpose = await _store.ensurePurpose(_platformLabel);
      await _deleteStale(purpose);
      final issued = await _api.create(purpose);
      await _store.save(StoredCanvasToken(
        token: issued.token,
        id: issued.id,
        purpose: issued.purpose,
      ));
      return issued.token;
    } on Object {
      return null;
    }
  }

  /// 같은 이름의 토큰이 남아 있으면 지운다. 값을 다시 볼 수 없어 쓸 수 없고,
  /// 그대로 두면 재설치할 때마다 계정에 쌓인다.
  Future<void> _deleteStale(String purpose) async {
    try {
      for (final token in await _api.list()) {
        if (token.purpose == purpose) await _api.delete(token.id);
      }
    } on Object {
      // 목록을 못 봐도 발급은 계속한다.
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/canvas/canvas_token_service_test.dart`
Expected: PASS (11 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/canvas/data/canvas_token_service.dart test/features/canvas/canvas_token_service_test.dart
git commit -m "feat: Canvas 토큰 발급·재발급·해지 상태 기계

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 4: 인터셉터에 토큰 경로 추가

**Files:**
- Modify: `lib/features/canvas/data/canvas_api.dart:243-300` (`canvasSessionInterceptor`)
- Test: `test/features/canvas/canvas_token_interceptor_test.dart`

**Interfaces:**
- Consumes: 기존 `kCanvasRetryFlag`
- Produces: 이름 있는 매개변수 두 개가 추가된 같은 함수
  ```dart
  Interceptor canvasSessionInterceptor({
    required Dio dio,
    required Future<void> Function() reBridge,
    Future<void> Function()? ensureSession,
    Future<String?> Function()? accessToken,
    Future<String?> Function()? reissueToken,
  })
  ```

동작 규칙:
- `accessToken()`이 값을 주면 `Authorization: Bearer <값>`을 붙이고 `ensureSession`을 **부르지 않는다**.
- Bearer로 보낸 요청이 401이면 `reissueToken()`을 한 번 부른다. 새 토큰이 오면 헤더를 갈아 끼우고 재시도한다.
- 재발급이 `null`이면 `Authorization`을 떼고 `reBridge()` 후 재시도한다(쿠키 폴백).
- 토큰이 없던 요청의 401은 지금과 같이 `reBridge()` 후 재시도한다.
- 재시도는 요청당 한 번(`kCanvasRetryFlag`).

- [ ] **Step 1: Write the failing test**

`test/features/canvas/canvas_token_interceptor_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_api.dart';

/// 첫 요청은 [firstStatus], 재시도부터는 200을 준다.
class _Script implements HttpClientAdapter {
  _Script({this.firstStatus = 200, this.alwaysUnauthorized = false});

  final int firstStatus;
  final bool alwaysUnauthorized;
  final List<String?> authHeaders = [];
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    authHeaders.add(options.headers['Authorization'] as String?);
    final status = alwaysUnauthorized
        ? 401
        : (calls == 1 ? firstStatus : 200);
    return ResponseBody.fromString('{}', status, headers: {
      'content-type': ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(
  _Script script, {
  Future<void> Function()? ensureSession,
  Future<String?> Function()? accessToken,
  Future<String?> Function()? reissueToken,
  required Future<void> Function() reBridge,
}) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://canvas.kumoh.ac.kr/api/v1',
    validateStatus: (s) => s != null && s < 500,
  ))..httpClientAdapter = script;
  dio.interceptors.insert(
    0,
    canvasSessionInterceptor(
      dio: dio,
      ensureSession: ensureSession,
      reBridge: reBridge,
      accessToken: accessToken,
      reissueToken: reissueToken,
    ),
  );
  return dio;
}

void main() {
  test('토큰이 있으면 Bearer를 붙이고 다리를 건너지 않는다', () async {
    var ensured = false;
    final script = _Script();
    final dio = _dio(
      script,
      ensureSession: () async => ensured = true,
      accessToken: () async => '7~abc',
      reBridge: () async {},
    );

    await dio.get<dynamic>('/users/self');

    expect(script.authHeaders.single, 'Bearer 7~abc');
    expect(ensured, isFalse);
  });

  test('토큰이 없으면 지금처럼 다리를 건넌다', () async {
    var ensured = false;
    final script = _Script();
    final dio = _dio(
      script,
      ensureSession: () async => ensured = true,
      accessToken: () async => null,
      reBridge: () async {},
    );

    await dio.get<dynamic>('/users/self');

    expect(script.authHeaders.single, isNull);
    expect(ensured, isTrue);
  });

  test('Bearer 요청이 401이면 재발급한 토큰으로 한 번 재시도한다', () async {
    final script = _Script(firstStatus: 401);
    var reBridged = false;
    final dio = _dio(
      script,
      accessToken: () async => '7~old',
      reissueToken: () async => '7~new',
      reBridge: () async => reBridged = true,
    );

    final res = await dio.get<dynamic>('/users/self');

    expect(res.statusCode, 200);
    expect(script.authHeaders, ['Bearer 7~old', 'Bearer 7~new']);
    expect(reBridged, isFalse);
  });

  test('재발급이 안 되면 Authorization을 떼고 쿠키로 폴백한다', () async {
    final script = _Script(firstStatus: 401);
    var reBridged = false;
    final dio = _dio(
      script,
      accessToken: () async => '7~old',
      reissueToken: () async => null,
      reBridge: () async => reBridged = true,
    );

    final res = await dio.get<dynamic>('/users/self');

    expect(res.statusCode, 200);
    expect(script.authHeaders, ['Bearer 7~old', isNull]);
    expect(reBridged, isTrue);
  });

  test('재시도는 한 번뿐이다', () async {
    final script = _Script(alwaysUnauthorized: true);
    final dio = _dio(
      script,
      accessToken: () async => '7~old',
      reissueToken: () async => '7~new',
      reBridge: () async {},
    );

    final res = await dio.get<dynamic>('/users/self');

    expect(res.statusCode, 401);
    expect(script.calls, 2);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/canvas/canvas_token_interceptor_test.dart`
Expected: FAIL — `No named parameter with the name 'accessToken'`

- [ ] **Step 3: Write minimal implementation**

`lib/features/canvas/data/canvas_api.dart`의 `canvasSessionInterceptor`를 아래로 교체한다(243-300행).

```dart
/// Canvas 인증이 끊겼을 때 복구하고 원요청을 재시도한다.
///
/// 토큰이 있으면 Bearer로 보내고 다리를 건너지 않는다. 401이면 토큰을 한 번
/// 다시 발급하고, 그것도 안 되면 쿠키 세션으로 폴백한다. [reBridge]는
/// single-flight이므로 동시에 만료를 만난 요청들이 다리를 여러 번 건너지 않는다.
Interceptor canvasSessionInterceptor({
  required Dio dio,
  required Future<void> Function() reBridge,
  Future<void> Function()? ensureSession,
  Future<String?> Function()? accessToken,
  Future<String?> Function()? reissueToken,
}) {
  Future<void> recover(
    RequestOptions options,
    void Function(Response<dynamic>) resolve,
    void Function(DioException) reject,
  ) async {
    options.extra[kCanvasRetryFlag] = true;
    try {
      final usedToken = options.headers.containsKey('Authorization');
      final renewed = usedToken ? await reissueToken?.call() : null;
      if (renewed != null) {
        options.headers['Authorization'] = 'Bearer $renewed';
      } else {
        // 쿠키 폴백. Canvas는 Bearer가 붙어 있으면 세션 쿠키를 보지 않는다.
        options.headers.remove('Authorization');
        await reBridge();
      }
      resolve(await dio.fetch<dynamic>(options));
    } on Object catch (e) {
      reject(DioException(
        requestOptions: options,
        error: e is Failure ? e : const AuthFailure(),
      ));
    }
  }

  bool shouldHandle(RequestOptions o, int? status) =>
      status == 401 && o.extra[kCanvasRetryFlag] != true;

  return InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await accessToken?.call();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
        return;
      }
      // 첫 요청 전에 다리를 건너 둔다. 401을 기다리면 사용자가 매번
      // 실패 왕복을 한 번씩 겪는다.
      if (ensureSession != null) {
        try {
          await ensureSession();
        } on Object catch (e) {
          handler.reject(
            DioException(requestOptions: options, error: e),
            true,
          );
          return;
        }
      }
      handler.next(options);
    },
    onResponse: (response, handler) async {
      if (!shouldHandle(response.requestOptions, response.statusCode)) {
        handler.next(response);
        return;
      }
      await recover(response.requestOptions, handler.resolve, handler.reject);
    },
    onError: (err, handler) async {
      if (!shouldHandle(err.requestOptions, err.response?.statusCode)) {
        handler.next(err);
        return;
      }
      await recover(err.requestOptions, handler.resolve, handler.reject);
    },
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/canvas/`
Expected: PASS — 새 테스트 5개와 기존 canvas 테스트 전부 통과

- [ ] **Step 5: Commit**

```bash
git add lib/features/canvas/data/canvas_api.dart test/features/canvas/canvas_token_interceptor_test.dart
git commit -m "feat: Canvas 요청에 토큰을 쓰고 401이면 재발급한다

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 5: providers 배선과 로그인·로그아웃 연결

**Files:**
- Modify: `lib/providers.dart:132-164`
- Modify: `lib/features/auth/presentation/auth_controller.dart:128-161`(로그인), `:184-210`(로그아웃)
- Test: `test/features/canvas/canvas_token_wiring_test.dart`

**Interfaces:**
- Consumes: Task 1~3의 `CanvasTokenApi`, `SecureCanvasTokenStore`, `CanvasTokenService`; Task 4의 `accessToken`·`reissueToken` 매개변수
- Produces:
  - `final canvasTokenStoreProvider = Provider<CanvasTokenStore>(...)`
  - `final canvasTokenApiProvider = Provider<CanvasTokenApi>(...)`
  - `final canvasTokenServiceProvider = Provider<CanvasTokenService>(...)`

- [ ] **Step 1: Write the failing test**

`test/features/canvas/canvas_token_wiring_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_service.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_store.dart';
import 'package:kumoh_lms/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('토큰 서비스와 보관소가 배선돼 있다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(canvasTokenStoreProvider), isA<CanvasTokenStore>());
    expect(container.read(canvasTokenServiceProvider), isA<CanvasTokenService>());
  });

  test('토큰 보관소는 앱 전체가 같은 인스턴스를 쓴다', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      identical(container.read(canvasTokenStoreProvider),
          container.read(canvasTokenStoreProvider)),
      isTrue,
    );
  });

  test('Canvas dio는 토큰이 있으면 Bearer를 붙인다', () async {
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~abc', id: 1, purpose: '금오LMS 앱 · Android · a3f9'));
    final container = ProviderContainer(overrides: [
      canvasTokenStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);

    final dio = container.read(canvasDioProvider);
    // 인터셉터가 요청 직전에 토큰을 읽는다. 어댑터를 바꿔 헤더만 확인한다.
    String? seen;
    dio.httpClientAdapter = _HeaderProbe((value) => seen = value);
    await dio.get<dynamic>('/users/self');

    expect(seen, 'Bearer 7~abc');
  });
}
```

이 테스트가 쓰는 `_HeaderProbe`를 같은 파일 위쪽에 둔다:

```dart
import 'package:dio/dio.dart';

class _HeaderProbe implements HttpClientAdapter {
  _HeaderProbe(this.onHeader);
  final void Function(String?) onHeader;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onHeader(options.headers['Authorization'] as String?);
    return ResponseBody.fromString('{}', 200, headers: {
      'content-type': ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/canvas/canvas_token_wiring_test.dart`
Expected: FAIL — `Undefined name 'canvasTokenStoreProvider'`

- [ ] **Step 3: Write the providers**

`lib/providers.dart`의 import 목록에 추가:

```dart
import 'features/canvas/data/canvas_token_api.dart';
import 'features/canvas/data/canvas_token_service.dart';
import 'features/canvas/data/canvas_token_store.dart';
```

`canvasSessionProvider` 바로 아래에 추가:

```dart
final canvasTokenStoreProvider =
    Provider<CanvasTokenStore>((ref) => SecureCanvasTokenStore());

/// 발급은 세션 인터셉터가 없는 브릿지 dio로 한다. 인터셉터가 붙은 dio를 쓰면
/// 발급 요청이 다시 발급을 부르는 고리가 생긴다.
final canvasTokenApiProvider = Provider<CanvasTokenApi>((ref) => CanvasTokenApi(
      ref.watch(canvasBridgeDioProvider),
      ref.watch(canvasCookieJarProvider),
    ));

final canvasTokenServiceProvider = Provider<CanvasTokenService>((ref) {
  final session = ref.watch(canvasSessionProvider);
  return CanvasTokenService(
    api: ref.watch(canvasTokenApiProvider),
    store: ref.watch(canvasTokenStoreProvider),
    ensureSession: session.ensure,
    platformLabel: defaultTargetPlatform.name,
  );
});
```

`defaultTargetPlatform`을 쓰려면 파일 맨 위에 `import 'package:flutter/foundation.dart';`가 필요하다. 이미 있으면 그대로 둔다.

`canvasDioProvider`의 인터셉터 등록을 아래로 바꾼다:

```dart
  final tokens = ref.watch(canvasTokenServiceProvider);
  dio.interceptors.insert(
      0,
      canvasSessionInterceptor(
    dio: dio,
    ensureSession: session.ensure,
    accessToken: tokens.current,
    reissueToken: tokens.reissueAfterInvalid,
    reBridge: () async {
      session.invalidate();
      await session.ensure();
    },
  ));
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/canvas/canvas_token_wiring_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: 로그인 뒤 발급을 시작한다**

`lib/features/auth/presentation/auth_controller.dart`의 `login()`에서 `_performLogin` 결과를 받은 뒤, `return authenticated;` 바로 앞에 넣는다:

```dart
      // 화면을 막지 않는다. 실패하면 쿠키 경로로 조용히 동작한다.
      unawaited(ref.read(canvasTokenServiceProvider).ensure());
```

`unawaited`를 쓰려면 파일 맨 위에 `import 'dart:async';`가 필요하다. `canvasTokenServiceProvider`는 이미 import된 `../../../providers.dart`에서 오므로 다른 import는 더하지 않는다(쓰지 않는 import는 analyze 경고가 된다).

- [ ] **Step 6: 로그아웃에서 토큰을 해지한다**

같은 파일 `logout()`의 `try {` 다음 첫 줄에 넣는다. LINUS 로그아웃보다 **먼저** 해야 한다. 다리를 건너려면 아직 유효한 LINUS 토큰이 필요하기 때문이다.

```dart
        // 다리를 건널 수 있는 동안 Canvas 토큰을 지운다. 실패해도 진행한다.
        await ref
            .read(canvasTokenServiceProvider)
            .revoke()
            .timeout(const Duration(seconds: 5), onTimeout: () {});
```

- [ ] **Step 7: 로그아웃 테스트를 추가한다**

`test/features/canvas/canvas_token_wiring_test.dart` 맨 아래에 추가:

```dart
  test('로그아웃하면 저장된 Canvas 토큰이 사라진다', () async {
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~abc', id: 1, purpose: '금오LMS 앱 · Android · a3f9'));
    final container = ProviderContainer(overrides: [
      canvasTokenStoreProvider.overrideWithValue(store),
    ]);
    addTearDown(container.dispose);

    await container.read(canvasTokenServiceProvider).revoke();

    expect(await store.read(), isNull);
  });
```

- [ ] **Step 8: 전체 테스트와 분석**

Run: `flutter test && flutter analyze`
Expected: 모든 테스트 통과, analyze 경고 0

- [ ] **Step 9: Commit**

```bash
git add lib/providers.dart lib/features/auth/presentation/auth_controller.dart test/features/canvas/canvas_token_wiring_test.dart
git commit -m "feat: 로그인 시 Canvas 토큰을 발급하고 로그아웃 시 해지한다

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 6: 설정 화면 "Canvas 연결"과 안내 문서

**Files:**
- Create: `lib/features/canvas/presentation/canvas_connection_section.dart`
- Create: `docs/canvas-token.md`
- Modify: `lib/features/settings/presentation/settings_screen.dart:29-32`
- Test: `test/features/canvas/canvas_connection_section_test.dart`

**Interfaces:**
- Consumes: `canvasTokenStoreProvider`, `canvasTokenServiceProvider` (Task 5)
- Produces:
  - `final canvasConnectionProvider = FutureProvider<StoredCanvasToken?>(...)`
  - `class CanvasConnectionSection extends ConsumerWidget`

- [ ] **Step 1: Write the failing test**

`test/features/canvas/canvas_connection_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_store.dart';
import 'package:kumoh_lms/features/canvas/presentation/canvas_connection_section.dart';
import 'package:kumoh_lms/providers.dart';

Future<void> _pump(WidgetTester tester, CanvasTokenStore store) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [canvasTokenStoreProvider.overrideWithValue(store)],
    child: const MaterialApp(
      home: Scaffold(body: CanvasConnectionSection()),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('토큰이 있으면 토큰으로 연결됨을 보여준다', (tester) async {
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~abc', id: 1, purpose: '금오LMS 앱 · Android · a3f9'));

    await _pump(tester, store);

    expect(find.text('토큰으로 연결됨'), findsOneWidget);
    expect(find.text('금오LMS 앱 · Android · a3f9'), findsOneWidget);
    expect(find.text('연결 해제'), findsOneWidget);
  });

  testWidgets('토큰이 없으면 쿠키 방식과 다시 연결 버튼을 보여준다', (tester) async {
    await _pump(tester, InMemoryCanvasTokenStore());

    expect(find.text('쿠키 방식으로 연결됨'), findsOneWidget);
    expect(find.text('다시 연결'), findsOneWidget);
  });

  testWidgets('화면에 토큰 값은 절대 나오지 않는다', (tester) async {
    final store = InMemoryCanvasTokenStore();
    await store.save(const StoredCanvasToken(
        token: '7~secret', id: 1, purpose: '금오LMS 앱 · Android · a3f9'));

    await _pump(tester, store);

    expect(find.textContaining('7~secret'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/canvas/canvas_connection_section_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../canvas_connection_section.dart'`

- [ ] **Step 3: Write minimal implementation**

`lib/features/canvas/presentation/canvas_connection_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers.dart';
import '../data/canvas_token_store.dart';

/// 지금 저장된 Canvas 토큰. 연결 상태 표시에만 쓴다.
final canvasConnectionProvider = FutureProvider<StoredCanvasToken?>(
  (ref) => ref.watch(canvasTokenStoreProvider).read(),
);

/// 설정 화면의 "Canvas 연결" 영역.
class CanvasConnectionSection extends ConsumerWidget {
  const CanvasConnectionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(canvasConnectionProvider);
    final stored = connection.valueOrNull;
    final connected = stored != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.link),
          title: Text(connected ? '토큰으로 연결됨' : '쿠키 방식으로 연결됨'),
          subtitle: Text(
            connected
                ? stored.purpose
                : '토큰 없이도 동작합니다. Canvas 설정에서 발급이 막혀 있을 수 있어요.',
          ),
          trailing: TextButton(
            onPressed: () async {
              final service = ref.read(canvasTokenServiceProvider);
              if (connected) {
                await service.revoke();
              } else {
                await service.ensure();
              }
              ref.invalidate(canvasConnectionProvider);
            },
            child: Text(connected ? '연결 해제' : '다시 연결'),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            '앱은 Canvas 조회에만 이 토큰을 씁니다. Canvas 설정(프로필 → 설정)에서 '
            '직접 지울 수 있고, 지우면 다음 조회에서 새로 만듭니다.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/canvas/canvas_connection_section_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: 설정 화면에 넣는다**

`lib/features/settings/presentation/settings_screen.dart`에서 `const DownloadSettingsSection(),` 다음 줄에 추가하고, 파일 위에 import를 더한다.

```dart
import '../../canvas/presentation/canvas_connection_section.dart';
```

```dart
          const Divider(),
          const CanvasConnectionSection(),
```

- [ ] **Step 6: 안내 문서를 쓴다**

`docs/canvas-token.md`:

```markdown
# Canvas 액세스 토큰

앱은 로그인한 뒤 Canvas 개인 액세스 토큰을 하나 만들어 기기에 보관합니다.
공지·과제·강의자료를 읽을 때 이 토큰을 씁니다.

## 왜 만드나요

학교 LINUS 로그인은 계정당 한 곳에서만 유지됩니다. PC에서 학교 홈페이지에
로그인하면 앱 세션이 끊깁니다. Canvas 토큰은 로그인과 무관해서 이 문제를
받지 않습니다.

## 권한 범위

Canvas가 만들어 주는 토큰에는 범위 제한이 없습니다. **Canvas 계정으로 할 수
있는 모든 일**이 가능한 권한입니다. 앱은 조회에만 쓰지만, 권한 자체는 그렇습니다.

## 어디에 보관하나요

기기 보안 저장소(Android EncryptedSharedPreferences)에만 둡니다. 서버로
보내지 않고, 로그에도 남기지 않습니다.

## 어떻게 지우나요

- 앱: 설정 → Canvas 연결 → 연결 해제
- 앱에서 로그아웃하면 자동으로 지워집니다
- Canvas 직접: `https://canvas.kumoh.ac.kr/profile/settings` → 승인된 통합 →
  `금오LMS 앱 · …` 항목 삭제

Canvas에서 직접 지우면 앱은 다음 조회에서 새 토큰을 만듭니다. 새로 만들지
못해도 앱은 예전 방식(세션 쿠키)으로 계속 동작합니다.
```

- [ ] **Step 7: 전체 테스트와 분석**

Run: `flutter test && flutter analyze`
Expected: 모든 테스트 통과, analyze 경고 0

- [ ] **Step 8: Commit**

```bash
git add lib/features/canvas/presentation/canvas_connection_section.dart lib/features/settings/presentation/settings_screen.dart docs/canvas-token.md test/features/canvas/canvas_connection_section_test.dart
git commit -m "feat: 설정에 Canvas 연결 상태와 해제를 넣는다

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 7: 백그라운드 알림 조회도 토큰을 쓴다

**Files:**
- Modify: `lib/features/notifications/data/lms_notification_source.dart:59-74`
- Test: `test/features/notifications/lms_notification_token_test.dart`

**Interfaces:**
- Consumes: Task 2의 `CanvasTokenStore`·`SecureCanvasTokenStore`, Task 4의 `accessToken` 매개변수
- Produces: `LmsNotificationSource`에 이름 있는 매개변수 `canvasTokenStore` 추가

백그라운드 작업은 자기만의 dio와 쿠키 자를 만든다. 여기에도 토큰을 물려 주면, 알림 조회가 SAML 다리를 매번 건너지 않는다. LINUS 로그인 자체는 이 작업 범위가 아니다(강좌·학기 목록이 아직 LINUS API를 쓴다).

- [ ] **Step 1: Write the failing test**

`test/features/notifications/lms_notification_token_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/canvas/data/canvas_token_store.dart';
import 'package:kumoh_lms/features/notifications/data/lms_notification_source.dart';
import 'package:kumoh_lms/core/network/token_store.dart';

void main() {
  test('Canvas 토큰 보관소를 받아 둔다', () async {
    final canvasTokens = InMemoryCanvasTokenStore();
    await canvasTokens.save(const StoredCanvasToken(
        token: '7~abc', id: 1, purpose: '금오LMS 앱 · Android · a3f9'));

    final source = LmsNotificationSource(
      InMemoryTokenStore(),
      canvasTokenStore: canvasTokens,
    );

    expect(await source.canvasAccessToken(), '7~abc');
  });

  test('보관소를 넘기지 않으면 토큰 없이 동작한다', () async {
    final source = LmsNotificationSource(InMemoryTokenStore());
    expect(await source.canvasAccessToken(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notifications/lms_notification_token_test.dart`
Expected: FAIL — `No named parameter with the name 'canvasTokenStore'`

- [ ] **Step 3: Write minimal implementation**

`lib/features/notifications/data/lms_notification_source.dart`:

생성자와 필드를 바꾼다.

```dart
  LmsNotificationSource(this.secureStore,
      {Dio? linusDio,
      Dio? bridgeDio,
      Dio? canvasDio,
      CanvasTokenStore? canvasTokenStore})
      : _canvasTokenStore = canvasTokenStore {
    _linus = linusDio ?? buildAuthDio();
    // CookieJar()는 웹에서 저장하지 않는 WebCookieJar가 된다.
    final jar = DefaultCookieJar();
    cookieJar = jar;
    _bridge = bridgeDio ?? buildCanvasDio(jar);
    _canvas = canvasDio ?? buildCanvasDio(jar);
    _canvas.options.baseUrl = Env.canvasApiBaseUrl;
  }
  final TokenStore secureStore;
  final CanvasTokenStore? _canvasTokenStore;

  /// 화면 쪽에서 발급해 둔 Canvas 토큰. 없으면 null이고 다리로 폴백한다.
  Future<String?> canvasAccessToken() async =>
      (await _canvasTokenStore?.read())?.token;
```

파일 위에 import를 더한다.

```dart
import '../../canvas/data/canvas_token_store.dart';
```

`authenticate()` 안의 인터셉터 등록에 토큰을 물린다.

```dart
    _canvas.interceptors.insert(
        0,
        canvasSessionInterceptor(
            dio: _canvas,
            ensureSession: session.ensure,
            accessToken: canvasAccessToken,
            reBridge: () async {
              session.invalidate();
              await session.ensure();
            }));
```

`reissueToken`은 넘기지 않는다. 백그라운드에서 토큰을 새로 만들면 화면 쪽 토큰과 어긋난다. 401이면 쿠키 경로로 폴백한다.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notifications/`
Expected: PASS — 새 테스트 2개와 기존 알림 테스트 전부 통과

- [ ] **Step 5: 실제 배선에 보관소를 넘긴다**

`LmsNotificationSource(...)`를 만드는 곳을 찾아 `canvasTokenStore: SecureCanvasTokenStore()`를 넘긴다.

Run: `grep -rn "LmsNotificationSource(" lib/`

각 호출부에 인자를 더하고, 해당 파일에 `import '../../canvas/data/canvas_token_store.dart';`(상대 경로는 파일 위치에 맞춘다)를 더한다.

- [ ] **Step 6: 전체 테스트와 분석**

Run: `flutter test && flutter analyze`
Expected: 모든 테스트 통과, analyze 경고 0

- [ ] **Step 7: Commit**

```bash
git add lib/features/notifications/data/lms_notification_source.dart test/features/notifications/lms_notification_token_test.dart
git commit -m "feat: 알림 조회도 Canvas 토큰을 쓴다

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 8: 실기기 확인

**Files:**
- Modify: `docs/pwa/verification.md` (안드로이드 확인 항목 추가)

코드 변경이 없는 마지막 관문이다. 실제 안드로이드 기기에서 아래를 순서대로 확인하고 결과를 적는다.

- [ ] **Step 1: 앱을 실기기에 올린다**

Run: `flutter run -d <안드로이드 기기 id>`

- [ ] **Step 2: 로그인하고 토큰이 생기는지 본다**

앱에서 로그인한 뒤 브라우저로 `https://canvas.kumoh.ac.kr/profile/settings`를 열어 "승인된 통합"에 `금오LMS 앱 · android · ****`가 있는지 확인한다.
Expected: 항목이 하나 보인다. 설정 화면에는 `토큰으로 연결됨`이 뜬다.

- [ ] **Step 3: 앱을 껐다 켜도 새로 만들지 않는지 본다**

앱을 완전히 종료하고 다시 연 뒤 강좌 목록과 공지를 연다. Canvas 설정을 새로고침한다.
Expected: 토큰 항목이 여전히 하나다(두 개로 늘지 않는다).

- [ ] **Step 4: Canvas에서 토큰을 지우면 복구되는지 본다**

Canvas 설정에서 그 토큰을 삭제하고, 앱에서 강좌 공지를 새로고침한다.
Expected: 화면이 정상으로 뜨고, Canvas 설정을 새로고침하면 새 토큰이 하나 있다.

- [ ] **Step 5: 연결 해제가 동작하는지 본다**

설정 → Canvas 연결 → 연결 해제.
Expected: `쿠키 방식으로 연결됨`으로 바뀌고, Canvas 설정에서 항목이 사라진다. 강좌 공지는 여전히 열린다.

- [ ] **Step 6: 발급이 실패해도 앱이 동작하는지 본다**

연결을 해제한 상태에서 비행기 모드를 켜고 `다시 연결`을 누른다. 그다음 비행기 모드를 끄고 강좌를 연다.
Expected: 오류 화면이 뜨지 않는다. 강좌 내용이 쿠키 경로로 열린다.

- [ ] **Step 7: 로그아웃이 토큰을 지우는지 본다**

다시 연결한 뒤 로그아웃한다.
Expected: Canvas 설정에서 항목이 사라진다.

- [ ] **Step 8: 확인 문서를 갱신하고 커밋한다**

`docs/pwa/verification.md` 맨 아래에 위 7가지를 체크리스트로 옮겨 적는다.

```bash
git add docs/pwa/verification.md
git commit -m "docs: Canvas 토큰 실기기 확인 항목

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## 범위 밖 (다음 계획)

1. **웹앱 적용** — 기기별 토큰을 브라우저 저장소에 둔다. 저장소가 기기 보안 저장소보다 약하다는 안내가 필요하다.
2. **LINUS 의존 제거** — 강좌·학기·공지함·캘린더를 Canvas API로 옮긴다. 끝나면 로그인 이후 LINUS를 쓰지 않아 세션 충돌이 사라지고, 알림 백그라운드의 매시 자동 로그인도 없앨 수 있다.
3. **알림 서버** — 동의한 사용자의 Canvas 토큰으로 서버가 폴링해 iOS Web Push를 보낸다.
