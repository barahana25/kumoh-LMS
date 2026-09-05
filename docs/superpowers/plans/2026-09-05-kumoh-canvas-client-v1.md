# 금오공대 Canvas LMS 클라이언트 v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 금오공대 학생이 학번/비번으로 로그인해 수강 강좌·과제 마감일(캘린더+리스트)·공지사항을 오프라인 캐시 기반으로 조회하는 Flutter 모바일 앱 v1을 만든다.

**Architecture:** 백엔드 서버 없는 클라이언트-온리. UI(Riverpod) → Repository → {dio 원격 API `lms.kumoh.ac.kr:82/api/v1`, Drift 암호화 SQLite 캐시}. Repository가 문서 없는 내부 API를 격리하는 교체 지점이자 오프라인-퍼스트 지점이다. 화면은 항상 캐시를 읽고, 네트워크는 TTL과 당겨서 새로고침으로만 호출한다.

**Tech Stack:** Flutter 3.x / Dart 3.x, dio, flutter_riverpod(코드젠 없이), freezed + json_serializable, drift + sqlcipher_flutter_libs, flutter_secure_storage, go_router, table_calendar, intl.

---

## Global Constraints

이 절의 값은 **모든 태스크에 암묵적으로 포함**된다. 그대로 복사해 쓸 것.

- **API base URL**: `https://lms.kumoh.ac.kr:82/api/v1`
- **Canvas host**: `https://canvas.kumoh.ac.kr`
- **필수 요청 헤더**: `Origin: https://lms.kumoh.ac.kr`, `Authorization: Bearer <accessToken>`, `X-Refresh-Token: <refreshToken>`
- **로그인**: `POST /login`, body `{"userId": "<학번 대문자>", "password": "<비번>"}`
- **재발급**: `POST /reissue`, **`X-Refresh-Token` 헤더 필수**. 응답에서 accessToken·refreshToken **둘 다 회전**되므로 둘 다 저장할 것. (쿠키/바디/Bearer 방식은 실패 확인됨)
- **재발급 트리거**: **HTTP 204** (주 신호, 운영 웹앱과 동일). 방어적으로 **401**도 함께 처리. `/reissue` 자체는 트리거에서 제외.
- **응답 봉투**: `{"code":"200","message":"Success","data":{...}}`. `code == "200"` 만 성공.
- **에러 바디는 두 형태**: ① 봉투 `{code,message,data}` ② 원시 Spring `{timestamp,status,error,path}`. 파서는 둘 다 처리.
- **accountId 기본값**: `1` (KIT). **테마색**: `#00A9CE`. **GPA 만점**: `4.5`.
- **토큰 수명**: accessToken 1시간, refreshToken 약 2시간.
- **보안**: 비밀번호는 기본적으로 저장하지 않는다. 자동 로그인 토글이 ON일 때만 Secure Storage에 저장. 토큰과 DB 암호화 키는 Secure Storage에만. 외부 서버 전송·텔레메트리·서드파티 SDK 금지.
- **DB 암호화**: Drift + SQLCipher, 키는 Secure Storage 보관.
- **언어**: UI 문자열은 한국어. 날짜 로케일 `ko_KR`.
- **코드젠 최소화 결정 (스펙 대비 조정)**: 스펙은 `riverpod_generator` + `freezed` + `json_serializable`을 언급했으나, 이 계획은 **drift 코드젠 하나만** 쓴다.
  - Riverpod → 평범한 provider (코드젠 없음). 아키텍처는 그대로.
  - DTO → **손으로 쓴 불변 클래스 + `fromJson`** (freezed/json_serializable 없음).
  - 이유 ①: 대상 API가 문서 없는 내부 API라 필드가 예고 없이 바뀐다. 생성된 엄격한 파서보다 **널 안전 기본값을 가진 관대한 수동 파서**가 실제로 덜 깨진다. (예: `colorCode: null`, `courseProgress: {error: {...}}` 같은 실제 응답)
  - 이유 ②: 코드젠 시스템이 하나면 구현자가 마주칠 빌드 실패 지점이 줄어든다.
  - 모델은 여전히 불변(`final` 필드 + `const` 생성자)이다.
- **커밋**: 각 태스크 끝에서 커밋. 커밋 메시지 끝에 다음 줄을 붙인다:
  `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`
- **DateTime은 UTC로 저장·비교한다**: `AppDatabase`가 `storeDateTimeAsText: true`를 쓴다.
  drift 기본 정수 저장은 읽을 때 `isUtc`를 잃고, `DateTime.==`는 `isUtc`까지 비교하므로
  UTC로 쓴 값이 왕복 후 달라진다. 리포지토리에서 `.toUtc()`로 덧칠하지 말 것.
- **`unwrapEnvelope` 호출 시 타입 인자를 명시할 것**: `unwrapEnvelope<Course>(...)` 처럼.
  async 함수의 `return` 문맥에서 `T`가 `FutureOr<...>`로 추론되어
  `unawaited_return_in_try_block` 경고가 뜬다. 타입 인자를 못 박으면 사라진다.
  (억제 주석 `// ignore:` 로 덮지 말 것 — Task 4에서 실제로 겪은 문제다.)
- **자격증명 파일 `env`는 절대 커밋 금지** (`.gitignore`에 이미 등록됨).

---

## File Structure

| 파일 | 책임 |
|---|---|
| `lib/core/config/env.dart` | base URL, 호스트, accountId, TTL 상수 |
| `lib/core/config/theme.dart` | KIT 테마(#00A9CE) 라이트/다크 |
| `lib/core/error/failure.dart` | 타입드 실패 sealed class |
| `lib/core/network/api_envelope.dart` | 봉투 언랩 + 두 에러 형태 파싱 |
| `lib/core/network/token_store.dart` | 토큰/DB키/자격증명 저장 인터페이스 + Secure Storage 구현 |
| `lib/core/network/auth_interceptor.dart` | Bearer·X-Refresh-Token 부착, 204/401→reissue→재시도 큐 |
| `lib/core/network/dio_client.dart` | dio 인스턴스 팩토리 |
| `lib/core/storage/db/tables.dart` | Drift 테이블 정의(fetched_at 포함) |
| `lib/core/storage/db/app_database.dart` | Drift DB + DAO + SQLCipher 개방 |
| `lib/core/storage/cache_policy.dart` | TTL 신선도 판정 |
| `lib/core/router/app_router.dart` | go_router + 인증 가드 |
| `lib/features/auth/data/auth_api.dart` | `/login` `/reissue` `/logout` `/user/profile` |
| `lib/features/auth/data/auth_repository.dart` | 로그인·세션복원·로그아웃 |
| `lib/features/auth/presentation/auth_controller.dart` | `AsyncNotifier<AuthState>` |
| `lib/features/auth/presentation/login_screen.dart` | 로그인 화면 |
| `lib/features/reference/…` | `/accounts` `/terms` (기관·학기) |
| `lib/features/courses/…` | 강좌 목록 |
| `lib/features/assignments/…` | `/calendar-events` 과제 마감 |
| `lib/features/announcements/…` | 공지 |
| `lib/features/shell/home_shell.dart` | 하단 탭 |
| `lib/providers.dart` | 인프라·리포지토리 provider 모음 |

---

## Task 1: 툴체인 설치 + 프로젝트 스캐폴드

**Files:**
- Create: `pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, `test/smoke_test.dart`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: 없음 (최초 태스크)
- Produces: 빌드·테스트 가능한 Flutter 프로젝트. 이후 모든 태스크가 `flutter test`로 검증된다.

- [ ] **Step 1: Flutter SDK 설치 확인**

이 PC에는 Flutter SDK가 없다(Android SDK android-36, build-tools 36.x, JDK 21은 있음). PowerShell에서:

```powershell
winget install --id=Google.Flutter -e --accept-package-agreements --accept-source-agreements
```

winget 패키지가 없으면 수동 설치:
```powershell
New-Item -ItemType Directory -Force C:\src
Invoke-WebRequest -Uri "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.35.5-stable.zip" -OutFile "$env:TEMP\flutter.zip"
Expand-Archive "$env:TEMP\flutter.zip" -DestinationPath C:\src -Force
[Environment]::SetEnvironmentVariable("Path", "$([Environment]::GetEnvironmentVariable('Path','User'));C:\src\flutter\bin", "User")
```

새 터미널을 열고 확인:
```bash
flutter --version
```
Expected: `Flutter 3.3x.x` 버전 출력.

- [ ] **Step 2: Android 툴체인 점검**

Run:
```bash
flutter doctor -v
flutter doctor --android-licenses
```
Expected: `[√] Flutter`, `[√] Android toolchain` 두 줄이 통과. (Chrome/Visual Studio 항목은 실패해도 무방 — 모바일만 타깃)

- [ ] **Step 3: 프로젝트 생성**

프로젝트 디렉터리가 이미 git 저장소이고 `docs/`, `.gitignore`, `env`가 있다. 그 위에 생성한다.

Run:
```bash
cd /c/Users/barah/Desktop/canvas
flutter create --project-name kumoh_lms --org ac.kumoh --platforms=android,ios .
```
Expected: `Wrote N files.` 그리고 `lib/main.dart`, `pubspec.yaml`, `android/`, `ios/` 생성.

- [ ] **Step 4: pubspec.yaml 의존성 작성**

`pubspec.yaml`의 `dependencies` / `dev_dependencies` 블록을 통째로 아래로 교체한다.

```yaml
name: kumoh_lms
description: 금오공과대학교 Canvas LMS 모바일 클라이언트
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: ^3.5.0

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  dio: ^5.7.0
  flutter_riverpod: ^2.6.1
  drift: ^2.20.3
  sqlcipher_flutter_libs: ^0.6.4
  sqlite3: ^2.4.6
  flutter_secure_storage: ^9.2.2
  go_router: ^14.6.2
  table_calendar: ^3.1.2
  intl: ^0.19.0
  path_provider: ^2.1.5
  path: ^1.9.0
  flutter_widget_from_html_core: ^0.15.2
  url_launcher: ^6.3.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.4.13
  drift_dev: ^2.20.3
  http_mock_adapter: ^0.6.1

flutter:
  uses-material-design: true
```

> `sqlite3_flutter_libs`는 **넣지 않는다** — `sqlcipher_flutter_libs`와 심볼이 충돌한다.

Run:
```bash
flutter pub get
```
Expected: `Got dependencies!`

- [ ] **Step 5: analysis_options.yaml 작성**

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
  errors:
    invalid_annotation_target: ignore

linter:
  rules:
    prefer_single_quotes: true
    always_declare_return_types: true
```

- [ ] **Step 6: 스모크 테스트 작성 (실패 확인용)**

`test/smoke_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/config/env.dart';

void main() {
  test('Env는 LINUS API base URL을 노출한다', () {
    expect(Env.apiBaseUrl, 'https://lms.kumoh.ac.kr:82/api/v1');
    expect(Env.canvasHost, 'https://canvas.kumoh.ac.kr');
    expect(Env.defaultAccountId, 1);
  });
}
```

- [ ] **Step 7: 테스트 실행 → 실패 확인**

Run: `flutter test test/smoke_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:kumoh_lms/core/config/env.dart'`

- [ ] **Step 8: env.dart 구현**

`lib/core/config/env.dart`:
```dart
/// 앱 전역 상수. 백엔드 서버가 없으므로 모든 엔드포인트는 여기에 고정된다.
class Env {
  const Env._();

  static const String apiBaseUrl = 'https://lms.kumoh.ac.kr:82/api/v1';
  static const String canvasHost = 'https://canvas.kumoh.ac.kr';

  /// 내부 API가 CORS/Referer 검사를 하므로 웹앱과 동일한 Origin을 보낸다.
  static const String webOrigin = 'https://lms.kumoh.ac.kr';

  /// KIT 기관 계정 id.
  static const int defaultAccountId = 1;

  /// 캐시 TTL — 학교 서버 부하를 줄이기 위해 이 시간 안에는 네트워크를 치지 않는다.
  static const Duration coursesTtl = Duration(hours: 6);
  static const Duration calendarTtl = Duration(minutes: 30);
  static const Duration announcementsTtl = Duration(minutes: 30);
  static const Duration referenceTtl = Duration(hours: 24);

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
```

- [ ] **Step 9: 테스트 실행 → 통과 확인**

Run: `flutter test test/smoke_test.dart`
Expected: `All tests passed!`

- [ ] **Step 10: .gitignore에 Flutter 항목 확인 후 커밋**

`.gitignore`에 아래 줄이 모두 있는지 확인하고 없으면 추가한다 (`env` 줄은 이미 있음 — 지우지 말 것):
```
.dart_tool/
build/
.flutter-plugins
.flutter-plugins-dependencies
```

Run:
```bash
git add -A
git status --short   # env 가 목록에 없어야 한다
git commit -m "feat: Flutter 프로젝트 스캐폴드 및 의존성 설정

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```
Expected: `env`가 커밋 목록에 **없어야** 한다.

---

## Task 2: 에러 타입 + 응답 봉투 파서

**Files:**
- Create: `lib/core/error/failure.dart`, `lib/core/network/api_envelope.dart`
- Test: `test/core/api_envelope_test.dart`

**Interfaces:**
- Consumes: 없음 (순수 Dart)
- Produces:
  - `sealed class Failure` + `NetworkFailure`, `AuthFailure`, `ServerFailure({required String code, required String message})`, `ParseFailure`, `CacheMissFailure`
  - `T unwrapEnvelope<T>(Object? body, T Function(Object? data) parse)` — 성공 시 `data`를 `parse`에 넘긴 결과 반환, 실패 시 `Failure` throw
  - `Failure failureFromResponse(int? statusCode, Object? body)` — 두 에러 형태를 모두 `Failure`로 변환

- [ ] **Step 1: 실패 테스트 작성**

`test/core/api_envelope_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/core/network/api_envelope.dart';

void main() {
  group('unwrapEnvelope', () {
    test('code가 200이면 data를 파싱해 반환한다', () {
      final body = {
        'code': '200',
        'message': 'Success',
        'data': {'id': 1, 'name': 'KIT'},
      };
      final result = unwrapEnvelope(body, (d) => (d! as Map)['name'] as String);
      expect(result, 'KIT');
    });

    test('code가 200이 아니면 ServerFailure를 던진다', () {
      final body = {
        'code': 'U004',
        'message': "No static resource api/v1/user.",
        'data': null,
      };
      expect(
        () => unwrapEnvelope(body, (d) => d),
        throwsA(isA<ServerFailure>()
            .having((f) => f.code, 'code', 'U004')
            .having((f) => f.message, 'message', contains('No static resource'))),
      );
    });

    test('봉투가 아닌 바디는 ParseFailure를 던진다', () {
      expect(() => unwrapEnvelope('보통 문자열', (d) => d), throwsA(isA<ParseFailure>()));
    });

    test('data가 null이어도 parse에 null을 넘긴다', () {
      final body = {'code': '200', 'message': 'Success', 'data': null};
      expect(unwrapEnvelope(body, (d) => d), isNull);
    });
  });

  group('failureFromResponse', () {
    test('401은 AuthFailure로 매핑한다', () {
      final f = failureFromResponse(401, {
        'timestamp': '2026-09-04T15:25:53.939+00:00',
        'status': 401,
        'error': 'Unauthorized',
        'path': '/api/v1/user/profile',
      });
      expect(f, isA<AuthFailure>());
    });

    test('원시 Spring 에러 바디를 ServerFailure로 매핑한다', () {
      final f = failureFromResponse(500, {
        'timestamp': '2026-09-04T15:25:53.810+00:00',
        'status': 500,
        'error': 'Internal Server Error',
        'path': '/api/v1/user/profile',
      });
      expect(f, isA<ServerFailure>());
      expect((f as ServerFailure).code, '500');
      expect(f.message, contains('Internal Server Error'));
    });

    test('앱 봉투 에러 바디를 code와 함께 ServerFailure로 매핑한다', () {
      final f = failureFromResponse(500, {
        'code': 'A001',
        'message': 'SSO 연동 ID가 존재하지 않습니다.',
        'data': null,
      });
      expect(f, isA<ServerFailure>());
      expect((f as ServerFailure).code, 'A001');
      expect(f.message, 'SSO 연동 ID가 존재하지 않습니다.');
    });

    test('바디가 없으면 ServerFailure에 상태코드만 담는다', () {
      final f = failureFromResponse(503, null);
      expect(f, isA<ServerFailure>());
      expect((f as ServerFailure).code, '503');
    });
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/core/api_envelope_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:kumoh_lms/core/error/failure.dart'`

- [ ] **Step 3: failure.dart 구현**

`lib/core/error/failure.dart`:
```dart
/// 앱 전역에서 쓰는 타입드 실패. UI는 이 타입만 보고 분기한다.
sealed class Failure implements Exception {
  const Failure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// 네트워크에 닿지 못함 (타임아웃, DNS, 연결 끊김).
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = '네트워크에 연결할 수 없습니다.']);
}

/// 세션이 유효하지 않음 → 재로그인 필요.
class AuthFailure extends Failure {
  const AuthFailure([super.message = '세션이 만료되었습니다. 다시 로그인해 주세요.']);
}

/// 서버가 응답했지만 실패. code는 앱 봉투의 code 또는 HTTP 상태코드 문자열.
class ServerFailure extends Failure {
  const ServerFailure({required this.code, required String message}) : super(message);
  final String code;
}

/// 응답 형태가 예상과 다름.
class ParseFailure extends Failure {
  const ParseFailure([super.message = '서버 응답을 해석할 수 없습니다.']);
}

/// 캐시에 데이터가 없고 네트워크도 실패.
class CacheMissFailure extends Failure {
  const CacheMissFailure([super.message = '표시할 데이터가 없습니다.']);
}
```

- [ ] **Step 4: api_envelope.dart 구현**

`lib/core/network/api_envelope.dart`:
```dart
import '../error/failure.dart';

/// LINUS API 성공 응답은 {code, message, data} 봉투다.
/// code == '200' 일 때만 성공이며, data를 [parse]에 넘긴 결과를 돌려준다.
T unwrapEnvelope<T>(Object? body, T Function(Object? data) parse) {
  if (body is! Map) {
    throw const ParseFailure();
  }
  final code = body['code']?.toString();
  if (code == null) {
    throw const ParseFailure();
  }
  if (code != '200') {
    throw ServerFailure(
      code: code,
      message: body['message']?.toString() ?? '알 수 없는 오류가 발생했습니다.',
    );
  }
  return parse(body['data']);
}

/// 에러 응답은 두 형태로 온다.
///   1) 앱 봉투     : {code, message, data}
///   2) 원시 Spring : {timestamp, status, error, path}
/// 둘 다 [Failure]로 정규화한다.
Failure failureFromResponse(int? statusCode, Object? body) {
  if (statusCode == 401) {
    return const AuthFailure();
  }

  if (body is Map) {
    // 앱 봉투 형태
    final code = body['code']?.toString();
    if (code != null) {
      return ServerFailure(
        code: code,
        message: body['message']?.toString() ?? '알 수 없는 오류가 발생했습니다.',
      );
    }
    // 원시 Spring 형태
    final error = body['error']?.toString();
    if (error != null) {
      return ServerFailure(
        code: (body['status'] ?? statusCode ?? 0).toString(),
        message: error,
      );
    }
  }

  return ServerFailure(
    code: (statusCode ?? 0).toString(),
    message: '서버 오류가 발생했습니다. (${statusCode ?? '알 수 없음'})',
  );
}
```

- [ ] **Step 5: 테스트 실행 → 통과 확인**

Run: `flutter test test/core/api_envelope_test.dart`
Expected: `All tests passed!` (9개 테스트)

- [ ] **Step 6: 커밋**

```bash
git add lib/core/error lib/core/network test/core
git commit -m "feat: 타입드 Failure와 API 봉투 파서 추가

두 가지 에러 응답 형태(앱 봉투/원시 Spring)를 모두 정규화한다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 3: 토큰 저장소 (Secure Storage)

**Files:**
- Create: `lib/core/network/token_store.dart`
- Test: `test/core/token_store_test.dart`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `abstract interface class TokenStore` — 메서드: `Future<String?> readAccessToken()`, `Future<String?> readRefreshToken()`, `Future<void> saveTokens({required String accessToken, required String refreshToken})`, `Future<void> clearTokens()`, `Future<String> ensureDbKey()`, `Future<void> saveCredentials({required String userId, required String password})`, `Future<Credentials?> readCredentials()`, `Future<void> clearCredentials()`, `Future<void> clearAll()`
  - `class Credentials { final String userId; final String password; }`
  - `class SecureTokenStore implements TokenStore` — 실기기용 구현
  - `class InMemoryTokenStore implements TokenStore` — 테스트/상위 계층 테스트에서 재사용 (lib에 둬서 위젯 테스트에서도 쓴다)

- [ ] **Step 1: 실패 테스트 작성**

`test/core/token_store_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/network/token_store.dart';

void main() {
  late InMemoryTokenStore store;

  setUp(() => store = InMemoryTokenStore());

  test('초기 상태에서는 토큰이 없다', () async {
    expect(await store.readAccessToken(), isNull);
    expect(await store.readRefreshToken(), isNull);
  });

  test('저장한 토큰을 그대로 읽는다', () async {
    await store.saveTokens(accessToken: 'AAA', refreshToken: 'RRR');
    expect(await store.readAccessToken(), 'AAA');
    expect(await store.readRefreshToken(), 'RRR');
  });

  test('clearTokens는 토큰만 지우고 자격증명은 남긴다', () async {
    await store.saveTokens(accessToken: 'AAA', refreshToken: 'RRR');
    await store.saveCredentials(userId: '20250000', password: 'pw');
    await store.clearTokens();
    expect(await store.readAccessToken(), isNull);
    expect((await store.readCredentials())?.userId, '20250000');
  });

  test('clearAll은 토큰과 자격증명을 모두 지운다', () async {
    await store.saveTokens(accessToken: 'AAA', refreshToken: 'RRR');
    await store.saveCredentials(userId: '20250000', password: 'pw');
    await store.clearAll();
    expect(await store.readAccessToken(), isNull);
    expect(await store.readCredentials(), isNull);
  });

  test('ensureDbKey는 최초에 키를 만들고 이후 같은 키를 돌려준다', () async {
    final first = await store.ensureDbKey();
    final second = await store.ensureDbKey();
    expect(first, isNotEmpty);
    expect(first.length, greaterThanOrEqualTo(32));
    expect(second, first);
  });

  test('자격증명을 저장하지 않으면 null이다', () async {
    expect(await store.readCredentials(), isNull);
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/core/token_store_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:kumoh_lms/core/network/token_store.dart'`

- [ ] **Step 3: token_store.dart 구현**

`lib/core/network/token_store.dart`:
```dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 자동 로그인이 켜졌을 때만 저장되는 학번/비밀번호 한 쌍.
class Credentials {
  const Credentials({required this.userId, required this.password});
  final String userId;
  final String password;
}

/// 토큰·DB 암호화 키·(선택)자격증명 보관소.
/// 구현체는 기기 Keychain/Keystore를 쓰며, 어떤 값도 외부로 전송하지 않는다.
abstract interface class TokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> saveTokens({required String accessToken, required String refreshToken});
  Future<void> clearTokens();

  /// Drift SQLCipher 키. 없으면 만들어 저장하고, 있으면 그대로 돌려준다.
  Future<String> ensureDbKey();

  Future<void> saveCredentials({required String userId, required String password});
  Future<Credentials?> readCredentials();
  Future<void> clearCredentials();

  /// 토큰 + 자격증명 전부 삭제 (로그아웃).
  Future<void> clearAll();
}

const _kAccess = 'access_token';
const _kRefresh = 'refresh_token';
const _kDbKey = 'db_key';
const _kUserId = 'cred_user_id';
const _kPassword = 'cred_password';

String _generateDbKey() {
  final rng = Random.secure();
  final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
  return base64Url.encode(bytes);
}

/// 기기 Keychain(iOS) / EncryptedSharedPreferences(Android) 기반 구현.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccessToken() => _storage.read(key: _kAccess);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _kRefresh);

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _kAccess, value: accessToken);
    await _storage.write(key: _kRefresh, value: refreshToken);
  }

  @override
  Future<void> clearTokens() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }

  @override
  Future<String> ensureDbKey() async {
    final existing = await _storage.read(key: _kDbKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _generateDbKey();
    await _storage.write(key: _kDbKey, value: created);
    return created;
  }

  @override
  Future<void> saveCredentials({required String userId, required String password}) async {
    await _storage.write(key: _kUserId, value: userId);
    await _storage.write(key: _kPassword, value: password);
  }

  @override
  Future<Credentials?> readCredentials() async {
    final id = await _storage.read(key: _kUserId);
    final pw = await _storage.read(key: _kPassword);
    if (id == null || pw == null) return null;
    return Credentials(userId: id, password: pw);
  }

  @override
  Future<void> clearCredentials() async {
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kPassword);
  }

  @override
  Future<void> clearAll() async {
    await clearTokens();
    await clearCredentials();
  }
}

/// 테스트와 위젯 프리뷰에서 쓰는 메모리 구현. DB 키는 유지한다.
class InMemoryTokenStore implements TokenStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> readAccessToken() async => _values[_kAccess];

  @override
  Future<String?> readRefreshToken() async => _values[_kRefresh];

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    _values[_kAccess] = accessToken;
    _values[_kRefresh] = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    _values.remove(_kAccess);
    _values.remove(_kRefresh);
  }

  @override
  Future<String> ensureDbKey() async => _values[_kDbKey] ??= _generateDbKey();

  @override
  Future<void> saveCredentials({required String userId, required String password}) async {
    _values[_kUserId] = userId;
    _values[_kPassword] = password;
  }

  @override
  Future<Credentials?> readCredentials() async {
    final id = _values[_kUserId];
    final pw = _values[_kPassword];
    if (id == null || pw == null) return null;
    return Credentials(userId: id, password: pw);
  }

  @override
  Future<void> clearCredentials() async {
    _values.remove(_kUserId);
    _values.remove(_kPassword);
  }

  @override
  Future<void> clearAll() async {
    await clearTokens();
    await clearCredentials();
  }
}
```

- [ ] **Step 4: 테스트 실행 → 통과 확인**

Run: `flutter test test/core/token_store_test.dart`
Expected: `All tests passed!` (6개 테스트)

- [ ] **Step 5: 커밋**

```bash
git add lib/core/network/token_store.dart test/core/token_store_test.dart
git commit -m "feat: Secure Storage 기반 토큰 저장소 추가

토큰/DB키/선택적 자격증명을 Keychain·Keystore에만 보관한다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 4: 인증 DTO + AuthApi

**Files:**
- Create: `lib/features/auth/data/auth_dto.dart`, `lib/features/auth/data/auth_api.dart`
- Create: `test/fixtures/fixtures.dart`
- Test: `test/features/auth/auth_api_test.dart`

**Interfaces:**
- Consumes: `unwrapEnvelope`, `failureFromResponse` (Task 2), `Env` (Task 1)
- Produces:
  - `class AuthTokens { final String accessToken; final String refreshToken; factory AuthTokens.fromJson(Map<String,dynamic>) }`
  - `class UserProfile { final int? canvasId; final String name; final String loginId; final String division; final String subDivision; final String role; final String? profileUrl; factory UserProfile.fromJson(Map<String,dynamic>) }`
  - `class AuthApi { AuthApi(Dio dio); Future<AuthTokens> login({required String userId, required String password}); Future<AuthTokens> reissue(String refreshToken); Future<UserProfile> fetchProfile(); Future<void> logout(); }`

- [ ] **Step 1: 픽스처 헬퍼 작성**

`test/fixtures/fixtures.dart` — 실제 서버 응답에서 뽑은 형태(값은 익명화):
```dart
/// 실제 lms.kumoh.ac.kr:82 응답에서 뽑은 형태. 토큰 값은 익명화했다.
const loginSuccessJson = {
  'code': '200',
  'message': 'Success',
  'data': {
    'accessToken': 'header.accessPayload.sig',
    'refreshToken': 'header.refreshPayload.sig',
  },
};

const userProfileJson = {
  'code': '200',
  'message': 'Success',
  'data': {
    'id': null,
    'canvasId': 59580,
    'name': '홍길동',
    'birth': '20000110',
    'mobile': '',
    'email': 'student@example.com',
    'loginId': '20250000',
    'division': '컴퓨터공학부',
    'subDivision': '인공지능공학전공',
    'agreementFlag': false,
    'createdAt': '2026-09-04 23:58:42',
    'profileUrl': 'https://canvas.kumoh.ac.kr/images/messages/avatar-50.png',
    'role': 'STUDENT',
    'locale': 'ko',
  },
};

const accountsJson = {
  'code': '200',
  'message': 'Success',
  'data': {
    'id': 1,
    'parentAccountId': null,
    'name': 'KIT',
    'workflowState': 'active',
    'universityName': '국립금오공과',
    'logoUrl': '',
    'scaleGpa': 4.5,
    'themeColor': '#00A9CE',
    'canvasType': 'OPEN_SOURCE',
    'ssoType': null,
  },
};

const termsJson = {
  'code': '200',
  'message': 'Success',
  'data': [
    {
      'id': 8,
      'name': '2026-2학기',
      'startAt': '2026-09-01T00:01:00',
      'endAt': '2026-12-22T00:00:59',
      'workflowState': 'active',
    },
    {
      'id': 6,
      'name': '2026-1학기',
      'startAt': '2026-03-03T00:01:00',
      'endAt': '2026-06-25T00:00:00',
      'workflowState': 'active',
    },
  ],
};

const coursesJson = {
  'code': '200',
  'message': 'Success',
  'data': {
    'courses': [
      {
        'no': null,
        'id': 4831,
        'name': '리눅스시스템프로그래밍-01',
        'startAt': null,
        'endAt': null,
        'courseCode': '리눅스시스템프로그래밍-GA2015-01',
        'totalStudents': 28,
        'sisCourseId': '2026-2-12211-GA2015-01',
        'teachers': [
          {
            'id': 83520,
            'loginId': 'F00357',
            'displayName': '[컴퓨터공학부] 윤현주',
            'avatarImageUrl': 'https://canvas.kumoh.ac.kr/images/messages/avatar-50.png',
          }
        ],
        'enrollments': [
          {'type': 'student', 'role': 'StudentEnrollment', 'enrollment_state': 'active'}
        ],
        'colorCode': null,
        'publicDescription': null,
        'institution': '인공지능공학전공',
        'courseProgress': {
          'error': {'message': 'no progress available because this course is not module based'}
        },
        'enrollmentTermId': 8,
        'imageDownloadUrl': null,
        'workflowState': 'available',
        'courseFormat': 'ONLINE',
      },
      {
        'id': 5682,
        'name': '모두를위한아두이노-02',
        'courseCode': '모두를위한아두이노-LA0424-02',
        'totalStudents': 40,
        'teachers': [
          {'id': 83648, 'loginId': 'F00489', 'displayName': '[산업.빅데이터공학부] 신승혁', 'avatarImageUrl': null}
        ],
        'enrollments': [
          {'type': 'student', 'role': 'StudentEnrollment', 'enrollment_state': 'active'}
        ],
        'colorCode': null,
        'institution': '교양학부',
        'enrollmentTermId': 8,
        'workflowState': 'available',
        'courseFormat': 'ONLINE',
      },
    ],
  },
};

const calendarEventsJson = {
  'code': '200',
  'message': 'Success',
  'data': {
    'calendarEvents': [
      {
        'id': 'assignment_7931',
        'title': '[토의 과제] 리눅스 상식',
        'start_at': '2026-09-02T14:59:00Z',
        'end_at': '2026-09-02T14:59:00Z',
        'workflow_state': 'published',
        'description': '<p>1. 리눅스 상식을 다룬 질문들에 대해 토의하고 답을 합의한다.</p>',
        'context_code': 'course_4831',
        'context_name': '리눅스시스템프로그래밍-01',
        'hidden': null,
        'html_url': 'https://canvas.kumoh.ac.kr/courses/4831/assignments/7931',
        'all_day': true,
      },
    ],
  },
};

const announcementsJson = {
  'code': '200',
  'message': 'Success',
  'data': {
    'announcements': [
      {
        'id': 991,
        'title': '2주차 실습 안내',
        'message': '<p>실습실은 D동 401호입니다.</p>',
        'postedAt': '2026-09-03T01:00:00Z',
        'contextCode': 'course_4831',
        'contextName': '리눅스시스템프로그래밍-01',
        'htmlUrl': 'https://canvas.kumoh.ac.kr/courses/4831/discussion_topics/991',
        'userName': '윤현주',
      },
    ],
  },
};

const emptyAnnouncementsJson = {
  'code': '200',
  'message': 'Success',
  'data': {'announcements': <Map<String, dynamic>>[]},
};

const springAuthErrorJson = {
  'timestamp': '2026-09-04T15:25:53.939+00:00',
  'status': 401,
  'error': 'Unauthorized',
  'path': '/api/v1/user/profile',
};
```

- [ ] **Step 2: 실패 테스트 작성**

`test/features/auth/auth_api_test.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/config/env.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/features/auth/data/auth_api.dart';

import '../../fixtures/fixtures.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late AuthApi api;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: Env.apiBaseUrl));
    adapter = DioAdapter(dio: dio);
    api = AuthApi(dio);
  });

  test('login은 학번을 대문자로 보내고 토큰을 파싱한다', () async {
    adapter.onPost(
      '/login',
      (server) => server.reply(200, loginSuccessJson),
      data: {'userId': '20250000', 'password': 'pw'},
    );

    final tokens = await api.login(userId: '20250000', password: 'pw');

    expect(tokens.accessToken, 'header.accessPayload.sig');
    expect(tokens.refreshToken, 'header.refreshPayload.sig');
  });

  test('login이 봉투 에러를 주면 ServerFailure를 던진다', () async {
    adapter.onPost(
      '/login',
      (server) => server.reply(200, {
        'code': 'U001',
        'message': '아이디 또는 비밀번호가 올바르지 않습니다.',
        'data': null,
      }),
      data: {'userId': '20250000', 'password': 'wrong'},
    );

    expect(
      () => api.login(userId: '20250000', password: 'wrong'),
      throwsA(isA<ServerFailure>().having((f) => f.code, 'code', 'U001')),
    );
  });

  test('reissue는 X-Refresh-Token 헤더로 보내고 회전된 토큰 두 개를 돌려준다', () async {
    adapter.onPost(
      '/reissue',
      (server) => server.reply(200, {
        'code': '200',
        'message': 'Success',
        'data': {'accessToken': 'newAccess', 'refreshToken': 'newRefresh'},
      }),
      headers: {'X-Refresh-Token': 'oldRefresh'},
    );

    final tokens = await api.reissue('oldRefresh');

    expect(tokens.accessToken, 'newAccess');
    expect(tokens.refreshToken, 'newRefresh');
  });

  test('fetchProfile은 사용자 프로필을 파싱한다', () async {
    adapter.onGet('/user/profile', (server) => server.reply(200, userProfileJson));

    final profile = await api.fetchProfile();

    expect(profile.loginId, '20250000');
    expect(profile.name, '홍길동');
    expect(profile.canvasId, 59580);
    expect(profile.division, '컴퓨터공학부');
    expect(profile.role, 'STUDENT');
  });

  test('401 원시 Spring 에러는 AuthFailure로 변환된다', () async {
    adapter.onGet('/user/profile', (server) => server.reply(401, springAuthErrorJson));

    expect(() => api.fetchProfile(), throwsA(isA<AuthFailure>()));
  });

  test('연결 실패는 NetworkFailure로 변환된다', () async {
    adapter.onGet(
      '/user/profile',
      (server) => server.throws(
        0,
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/user/profile'),
          reason: 'no route',
        ),
      ),
    );

    expect(() => api.fetchProfile(), throwsA(isA<NetworkFailure>()));
  });
}
```

- [ ] **Step 3: 테스트 실행 → 실패 확인**

Run: `flutter test test/features/auth/auth_api_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:kumoh_lms/features/auth/data/auth_api.dart'`

- [ ] **Step 4: auth_dto.dart 구현**

`lib/features/auth/data/auth_dto.dart`:
```dart
/// 로그인/재발급 응답의 토큰 쌍. 재발급 시 둘 다 회전되므로 항상 함께 저장한다.
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['accessToken'] as String? ?? '',
        refreshToken: json['refreshToken'] as String? ?? '',
      );

  bool get isValid => accessToken.isNotEmpty && refreshToken.isNotEmpty;
}

/// `/user/profile` 응답. 널 허용 필드가 많아 방어적으로 파싱한다.
class UserProfile {
  const UserProfile({
    required this.loginId,
    required this.name,
    required this.role,
    this.canvasId,
    this.division = '',
    this.subDivision = '',
    this.profileUrl,
    this.email = '',
  });

  final String loginId;
  final String name;
  final String role;
  final int? canvasId;
  final String division;
  final String subDivision;
  final String? profileUrl;
  final String email;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        loginId: json['loginId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        role: json['role'] as String? ?? 'STUDENT',
        canvasId: (json['canvasId'] as num?)?.toInt(),
        division: json['division'] as String? ?? '',
        subDivision: json['subDivision'] as String? ?? '',
        profileUrl: json['profileUrl'] as String?,
        email: json['email'] as String? ?? '',
      );

  /// "컴퓨터공학부 · 인공지능공학전공" 형태. 빈 값은 알아서 빠진다.
  String get affiliation =>
      [division, subDivision].where((s) => s.isNotEmpty).join(' · ');
}
```

- [ ] **Step 5: auth_api.dart 구현**

`lib/features/auth/data/auth_api.dart`:
```dart
import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../../core/network/api_envelope.dart';
import 'auth_dto.dart';

/// DioException을 앱의 Failure 타입으로 정규화한다.
/// 모든 API 클래스가 이 함수를 통해 예외를 던진다.
Never throwAsFailure(DioException e) {
  // 인터셉터가 이미 판정한 Failure(예: 세션 만료 AuthFailure)는 그대로 통과시킨다.
  // 이게 없으면 AuthInterceptor가 실어 보낸 AuthFailure가 NetworkFailure로 뒤바뀐다.
  final carried = e.error;
  if (carried is Failure) throw carried;

  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      throw const NetworkFailure();
    case DioExceptionType.badCertificate:
      throw const NetworkFailure('보안 연결에 실패했습니다.');
    case DioExceptionType.cancel:
      throw const NetworkFailure('요청이 취소되었습니다.');
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      final res = e.response;
      if (res == null) throw const NetworkFailure();
      throw failureFromResponse(res.statusCode, res.data);
  }
}

class AuthApi {
  AuthApi(this._dio);
  final Dio _dio;

  /// 학번은 서버가 대문자를 기대한다(웹앱도 대문자로 변환해 보낸다).
  Future<AuthTokens> login({required String userId, required String password}) async {
    try {
      final res = await _dio.post<Object?>(
        '/login',
        data: {'userId': userId.toUpperCase().trim(), 'password': password},
      );
      return unwrapEnvelope(
        res.data,
        (d) => AuthTokens.fromJson(d! as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }

  /// refreshToken은 반드시 X-Refresh-Token 헤더로 보낸다.
  /// (쿠키·바디·Bearer 방식은 서버가 거부한다.)
  Future<AuthTokens> reissue(String refreshToken) async {
    try {
      final res = await _dio.post<Object?>(
        '/reissue',
        options: Options(headers: {'X-Refresh-Token': refreshToken}),
      );
      return unwrapEnvelope(
        res.data,
        (d) => AuthTokens.fromJson(d! as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }

  Future<UserProfile> fetchProfile() async {
    try {
      final res = await _dio.get<Object?>('/user/profile');
      return unwrapEnvelope(
        res.data,
        (d) => UserProfile.fromJson(d! as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }

  /// 서버 세션 정리. 실패해도 로컬 로그아웃은 진행해야 하므로 예외를 삼킨다.
  Future<void> logout() async {
    try {
      await _dio.post<Object?>('/logout');
    } on DioException {
      return;
    }
  }
}
```

- [ ] **Step 6: 테스트 실행 → 통과 확인**

Run: `flutter test test/features/auth/auth_api_test.dart`
Expected: `All tests passed!` (6개 테스트)

- [ ] **Step 7: 커밋**

```bash
git add lib/features/auth test/features/auth test/fixtures
git commit -m "feat: 인증 DTO와 AuthApi 추가

reissue는 X-Refresh-Token 헤더를 쓰고 회전된 토큰 두 개를 모두 반환한다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 5: AuthInterceptor (최고 위험 — 가장 먼저 TDD)

운영 웹앱의 인터셉터를 그대로 옮긴다. 핵심 규칙 네 가지:
1. 요청마다 `Authorization: Bearer <access>` + `X-Refresh-Token: <refresh>` 부착
2. 응답이 **204**(주 신호) 또는 **401**(방어)이면 재발급 시도
3. `/reissue` 요청 자체와 이미 재시도한 요청(`_retry`)은 트리거에서 제외
4. 재발급이 진행 중이면 뒤따르는 요청은 **큐에 모아** 갱신 후 일괄 재개. 재발급 실패 시 큐 전체를 거절하고 세션을 비운다

**Files:**
- Create: `lib/core/network/auth_interceptor.dart`
- Test: `test/core/auth_interceptor_test.dart`

**Interfaces:**
- Consumes: `TokenStore` (Task 3), `AuthApi.reissue` (Task 4), `AuthFailure` (Task 2)
- Produces:
  - `class AuthInterceptor extends Interceptor` — 생성자 `AuthInterceptor({required TokenStore tokenStore, required Future<AuthTokens> Function(String refreshToken) reissue, required Future<void> Function() onSessionExpired, required Dio retryClient})`
  - 상수 `const kRetryFlag = 'auth_retry'` — `RequestOptions.extra`에 쓰는 재시도 플래그 키

- [ ] **Step 1: 실패 테스트 작성**

`test/core/auth_interceptor_test.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/core/network/auth_interceptor.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/features/auth/data/auth_dto.dart';

/// 응답을 대본대로 돌려주는 최소 어댑터.
/// 경로별로 응답 큐를 넣어두면 호출 순서대로 하나씩 꺼내 준다.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.script);

  final Map<String, List<int>> script;
  final List<RequestOptions> received = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    received.add(options);
    final queue = script[options.path];
    if (queue == null || queue.isEmpty) {
      return ResponseBody.fromString('{"code":"200","message":"Success","data":{}}', 200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          });
    }
    final status = queue.removeAt(0);
    if (status == 204) {
      return ResponseBody.fromString('', 204);
    }
    return ResponseBody.fromString('{"code":"200","message":"Success","data":{"ok":true}}', status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late InMemoryTokenStore store;
  late Dio dio;
  late _ScriptedAdapter adapter;
  late int reissueCalls;
  late int sessionExpiredCalls;

  /// [script] 는 경로별 응답 상태코드 큐.
  Future<void> setUpDio({
    required Map<String, List<int>> script,
    required Future<AuthTokens> Function(String refresh) reissue,
  }) async {
    store = InMemoryTokenStore();
    await store.saveTokens(accessToken: 'oldAccess', refreshToken: 'oldRefresh');
    reissueCalls = 0;
    sessionExpiredCalls = 0;

    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    adapter = _ScriptedAdapter(script);
    dio.httpClientAdapter = adapter;

    dio.interceptors.add(AuthInterceptor(
      tokenStore: store,
      reissue: (refresh) async {
        reissueCalls++;
        return reissue(refresh);
      },
      onSessionExpired: () async {
        sessionExpiredCalls++;
      },
      retryClient: dio,
    ));
  }

  test('요청에 Authorization과 X-Refresh-Token을 모두 붙인다', () async {
    await setUpDio(
      script: {'/courses': [200]},
      reissue: (_) async => const AuthTokens(accessToken: 'a', refreshToken: 'r'),
    );

    await dio.get<Object?>('/courses');

    final sent = adapter.received.single;
    expect(sent.headers['Authorization'], 'Bearer oldAccess');
    expect(sent.headers['X-Refresh-Token'], 'oldRefresh');
  });

  test('204를 받으면 재발급 후 새 토큰으로 원요청을 재시도한다', () async {
    await setUpDio(
      script: {'/courses': [204, 200]},
      reissue: (_) async => const AuthTokens(accessToken: 'newAccess', refreshToken: 'newRefresh'),
    );

    final res = await dio.get<Object?>('/courses');

    expect(res.statusCode, 200);
    expect(reissueCalls, 1);
    // 첫 요청 + 재시도 = 2회
    expect(adapter.received.length, 2);
    expect(adapter.received.last.headers['Authorization'], 'Bearer newAccess');
    // 회전된 토큰이 저장됐다
    expect(await store.readAccessToken(), 'newAccess');
    expect(await store.readRefreshToken(), 'newRefresh');
  });

  test('401도 재발급 트리거로 동작한다', () async {
    await setUpDio(
      script: {'/courses': [401, 200]},
      reissue: (_) async => const AuthTokens(accessToken: 'newAccess', refreshToken: 'newRefresh'),
    );

    final res = await dio.get<Object?>('/courses');

    expect(res.statusCode, 200);
    expect(reissueCalls, 1);
  });

  test('재발급이 실패하면 세션을 비우고 AuthFailure를 던진다', () async {
    await setUpDio(
      script: {'/courses': [204]},
      reissue: (_) async => throw const ServerFailure(code: 'U004', message: 'bad refresh'),
    );

    await expectLater(
      dio.get<Object?>('/courses'),
      throwsA(isA<AuthFailure>()),
    );
    expect(sessionExpiredCalls, 1);
    expect(await store.readAccessToken(), isNull);
  });

  test('재시도한 요청이 또 204면 재발급을 반복하지 않는다', () async {
    await setUpDio(
      script: {'/courses': [204, 204]},
      reissue: (_) async => const AuthTokens(accessToken: 'newAccess', refreshToken: 'newRefresh'),
    );

    await expectLater(dio.get<Object?>('/courses'), throwsA(isA<AuthFailure>()));
    expect(reissueCalls, 1, reason: '_retry 플래그가 두 번째 재발급을 막아야 한다');
  });

  test('refreshToken이 없으면 재발급을 시도하지 않고 곧장 세션 만료 처리한다', () async {
    await setUpDio(
      script: {'/courses': [204]},
      reissue: (_) async => const AuthTokens(accessToken: 'a', refreshToken: 'r'),
    );
    await store.clearTokens();

    await expectLater(dio.get<Object?>('/courses'), throwsA(isA<AuthFailure>()));
    expect(reissueCalls, 0);
    expect(sessionExpiredCalls, 1);
  });

  test('동시에 204를 받은 요청들이 재발급을 한 번만 호출한다', () async {
    await setUpDio(
      script: {
        '/courses': [204, 200],
        '/terms': [204, 200],
        '/user/profile': [204, 200],
      },
      reissue: (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return const AuthTokens(accessToken: 'newAccess', refreshToken: 'newRefresh');
      },
    );

    final results = await Future.wait([
      dio.get<Object?>('/courses'),
      dio.get<Object?>('/terms'),
      dio.get<Object?>('/user/profile'),
    ]);

    expect(results.every((r) => r.statusCode == 200), isTrue);
    expect(reissueCalls, 1, reason: '동시 요청은 한 번의 재발급을 공유해야 한다');
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/core/auth_interceptor_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:kumoh_lms/core/network/auth_interceptor.dart'`

> **구현 후 정정 (실제 코드가 정본):** 아래 코드는 초안이며 리뷰에서 결함 4개가 나와 수정됐다.
> 실제 동작하는 판본은 `lib/core/network/auth_interceptor.dart`를 볼 것.
> ① `_refreshing = true`를 `await readRefreshToken()` **이전에** 세워야 한다(경쟁 조건).
> ② 재발급 실패와 재시도(replay) 실패를 분리한다. 재시도가 비인증 오류(500/timeout)면
>    세션을 지우지 말고 원인을 그대로 전달한다.
> ③ 단, 재시도가 또 204/401이면 새 토큰이 거부된 것이므로 세션을 종료한다.
> ④ 플래그 구간 전체를 `try/finally`로 감싸 TokenStore I/O 예외에도 `_refreshing`이
>    반드시 해제되게 한다(안 그러면 인터셉터가 영구 정지한다).

- [ ] **Step 3: auth_interceptor.dart 구현**

`lib/core/network/auth_interceptor.dart`:
```dart
import 'dart:async';

import 'package:dio/dio.dart';

import '../error/failure.dart';
import '../../features/auth/data/auth_dto.dart';
import 'token_store.dart';

/// RequestOptions.extra 에 저장하는 재시도 표시. 무한 재발급 루프를 막는다.
const String kRetryFlag = 'auth_retry';

/// 재발급 신호. 운영 웹앱은 204만 보지만 401도 방어적으로 함께 처리한다.
bool _needsReissue(int? statusCode) => statusCode == 204 || statusCode == 401;

/// 토큰 부착 + 만료 시 자동 재발급 + 원요청 재시도.
///
/// 동시에 여러 요청이 만료를 만나면 첫 요청만 재발급을 수행하고
/// 나머지는 [_waiters] 에 모였다가 새 토큰으로 한꺼번에 재개된다.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStore tokenStore,
    required Future<AuthTokens> Function(String refreshToken) reissue,
    required Future<void> Function() onSessionExpired,
    required Dio retryClient,
  })  : _tokenStore = tokenStore,
        _reissue = reissue,
        _onSessionExpired = onSessionExpired,
        _retryClient = retryClient;

  final TokenStore _tokenStore;
  final Future<AuthTokens> Function(String refreshToken) _reissue;
  final Future<void> Function() _onSessionExpired;
  final Dio _retryClient;

  bool _refreshing = false;
  final List<Completer<String>> _waiters = [];

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final access = await _tokenStore.readAccessToken();
    final refresh = await _tokenStore.readRefreshToken();
    if (access != null && access.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    if (refresh != null && refresh.isNotEmpty) {
      options.headers['X-Refresh-Token'] = refresh;
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    if (!_shouldHandle(response.requestOptions, response.statusCode)) {
      handler.next(response);
      return;
    }
    await _recover(response.requestOptions, handler.resolve, handler.reject);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldHandle(err.requestOptions, err.response?.statusCode)) {
      handler.next(err);
      return;
    }
    await _recover(err.requestOptions, handler.resolve, handler.reject);
  }

  bool _shouldHandle(RequestOptions options, int? statusCode) {
    if (!_needsReissueFor(statusCode)) return false;
    if (options.path.contains('/reissue')) return false;
    if (options.extra[kRetryFlag] == true) return false;
    return true;
  }

  bool _needsReissueFor(int? statusCode) => _needsReissue(statusCode);

  /// 재발급 → 원요청 재시도. 실패하면 세션을 비우고 AuthFailure로 거절한다.
  Future<void> _recover(
    RequestOptions options,
    void Function(Response<dynamic>) resolve,
    void Function(DioException) reject,
  ) async {
    options.extra[kRetryFlag] = true;

    // 이미 다른 요청이 재발급 중이면 새 토큰을 기다렸다가 재개한다.
    if (_refreshing) {
      final waiter = Completer<String>();
      _waiters.add(waiter);
      try {
        final token = await waiter.future;
        resolve(await _replay(options, token));
      } on Object {
        reject(_authError(options));
      }
      return;
    }

    final refresh = await _tokenStore.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      await _failSession();
      reject(_authError(options));
      return;
    }

    _refreshing = true;
    try {
      final tokens = await _reissue(refresh);
      if (!tokens.isValid) {
        throw const AuthFailure();
      }
      await _tokenStore.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      _refreshing = false;
      for (final w in _waiters) {
        w.complete(tokens.accessToken);
      }
      _waiters.clear();

      resolve(await _replay(options, tokens.accessToken));
    } on Object catch (e) {
      _refreshing = false;
      for (final w in _waiters) {
        w.completeError(e);
      }
      _waiters.clear();
      await _failSession();
      reject(_authError(options));
    }
  }

  Future<Response<dynamic>> _replay(RequestOptions options, String accessToken) {
    options.headers['Authorization'] = 'Bearer $accessToken';
    return _retryClient.fetch<dynamic>(options);
  }

  Future<void> _failSession() async {
    await _tokenStore.clearTokens();
    await _onSessionExpired();
  }

  DioException _authError(RequestOptions options) => DioException(
        requestOptions: options,
        type: DioExceptionType.unknown,
        error: const AuthFailure(),
      );
}
```

- [ ] **Step 4: 테스트 실행 → 통과 확인**

Run: `flutter test test/core/auth_interceptor_test.dart`
Expected: `All tests passed!` (7개 테스트)

> 테스트에서 `throwsA(isA<AuthFailure>())`가 통과하려면 DioException의 `error`가 그대로 표면화돼야 한다. 실패하면 Step 5의 `dio_client.dart`에 있는 **에러 언랩 인터셉터**가 필요하다는 뜻이다 — Step 5에서 추가한다.

- [ ] **Step 5: dio_client.dart 구현 (에러 언랩 포함)**

`lib/core/network/dio_client.dart`:
```dart
import 'package:dio/dio.dart';

import '../config/env.dart';
import '../error/failure.dart';
import 'auth_interceptor.dart';
import 'token_store.dart';
import '../../features/auth/data/auth_dto.dart';

/// DioException 안에 감싸인 Failure를 그대로 던져 주는 마지막 인터셉터.
/// 이게 없으면 호출부가 DioException을 받게 되어 UI 분기가 지저분해진다.
class _UnwrapFailureInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final inner = err.error;
    if (inner is Failure) {
      handler.reject(DioException(
        requestOptions: err.requestOptions,
        type: err.type,
        error: inner,
      ));
      return;
    }
    handler.next(err);
  }
}

/// 앱이 쓰는 dio 인스턴스를 만든다.
/// [reissue] 와 [onSessionExpired] 는 순환 의존을 피하려고 콜백으로 받는다.
Dio buildDio({
  required TokenStore tokenStore,
  required Future<AuthTokens> Function(String refreshToken) reissue,
  required Future<void> Function() onSessionExpired,
}) {
  final dio = Dio(BaseOptions(
    baseUrl: Env.apiBaseUrl,
    connectTimeout: Env.connectTimeout,
    receiveTimeout: Env.receiveTimeout,
    headers: {
      'Content-Type': 'application/json',
      'Origin': Env.webOrigin,
      'Referer': '${Env.webOrigin}/',
    },
    // 204/401을 예외가 아닌 응답으로 받아 인터셉터에서 처리한다.
    validateStatus: (status) => status != null && status < 500,
  ));

  dio.interceptors.add(AuthInterceptor(
    tokenStore: tokenStore,
    reissue: reissue,
    onSessionExpired: onSessionExpired,
    retryClient: dio,
  ));
  dio.interceptors.add(_UnwrapFailureInterceptor());

  return dio;
}

/// 로그인·재발급 전용 dio. 인터셉터가 없어 재발급 재귀가 생기지 않는다.
Dio buildAuthDio() => Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: Env.connectTimeout,
      receiveTimeout: Env.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Origin': Env.webOrigin,
        'Referer': '${Env.webOrigin}/',
      },
    ));
```

- [ ] **Step 6: 전체 테스트 실행 → 통과 확인**

Run: `flutter test`
Expected: `All tests passed!` — Task 1~5의 모든 테스트(총 28개)가 통과.

- [ ] **Step 7: 커밋**

```bash
git add lib/core/network test/core/auth_interceptor_test.dart
git commit -m "feat: 204/401 자동 재발급 AuthInterceptor 추가

동시 요청은 단일 재발급을 공유하고, _retry 플래그로 무한 루프를 막는다.
재발급 실패 시 세션을 비우고 AuthFailure로 통일해 던진다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 6: Drift 암호화 DB + 테이블 + DAO

> **설계 결정 (DRY):** Drift가 생성하는 row 클래스를 **그대로 UI 모델로 쓴다.** 별도 도메인 엔티티 계층을 두지 않는다. 흐름은 `API JSON → Drift Companion → (DB) → Drift Row → UI` 다. 매핑 계층이 하나 줄어 코드와 테스트가 함께 줄어든다.
>
> **TTL 설계:** 행마다 시각을 두지 않고 `CacheMeta(key, fetchedAt)` 한 테이블로 컬렉션 단위 신선도를 관리한다. 키 예: `terms`, `courses:8`, `calendar:8`, `announcements:8`.

**Files:**
- Create: `lib/core/storage/db/tables.dart`, `lib/core/storage/db/app_database.dart`, `lib/core/storage/cache_policy.dart`
- Create: `test/helpers/test_db.dart`
- Test: `test/core/app_database_test.dart`
- Modify: `.gitignore` (sqlite3.dll 추가)

**Interfaces:**
- Consumes: `TokenStore.ensureDbKey()` (Task 3), `Env` TTL 상수 (Task 1)
- Produces:
  - Drift row 클래스: `TermRow`, `CourseRow`, `CalendarEventRow`, `AnnouncementRow`
  - Companion 클래스: `TermsCompanion`, `CoursesCompanion`, `CalendarEventsCompanion`, `AnnouncementsCompanion`
  - `class AppDatabase` — drift가 생성하는 DAO 접근자 `termsDao`, `coursesDao`, `calendarEventsDao`, `announcementsDao`, `cacheMetaDao`, 그리고 직접 작성한 `Future<void> wipe()`
    > 주의: drift는 DAO 접근자를 **DAO 클래스 이름**에서 만든다(`TermsDao` → `termsDao`). `db.terms`는 DAO가 아니라 **테이블** 접근자이므로 호출하면 컴파일되지 않는다.
  - `AppDatabase.encrypted(Future<String> Function() keyProvider)` / `AppDatabase.forTesting(QueryExecutor)`
  - DAO 메서드 (아래 구현 참조)
  - `class CachePolicy { static bool isFresh(DateTime? fetchedAt, Duration ttl); }`

- [ ] **Step 1: Windows 테스트용 sqlite3.dll 준비**

`flutter test`는 호스트 VM에서 돌기 때문에 Windows에서 `NativeDatabase.memory()`를 쓰려면 sqlite3 네이티브 라이브러리가 필요하다. 프로젝트 루트에 받아 둔다.

PowerShell에서:
```powershell
Invoke-WebRequest -Uri "https://www.sqlite.org/2024/sqlite-dll-win-x64-3460100.zip" -OutFile "$env:TEMP\sqlite3.zip"
Expand-Archive "$env:TEMP\sqlite3.zip" -DestinationPath "$env:TEMP\sqlite3" -Force
Copy-Item "$env:TEMP\sqlite3\sqlite3.dll" -Destination "C:\Users\barah\Desktop\canvas\sqlite3.dll" -Force
```

확인:
```bash
ls -l sqlite3.dll
```
Expected: 파일이 존재하고 크기가 1MB 이상.

`.gitignore`에 추가 (바이너리는 커밋하지 않는다):
```
sqlite3.dll
```

- [ ] **Step 2: 실패 테스트 작성**

`test/core/app_database_test.dart`:
```dart
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/storage/cache_policy.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';

import '../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  TermsCompanion term(int id, String name) => TermsCompanion.insert(
        id: Value(id),
        name: name,
        startAt: Value(DateTime.utc(2026, 9, 1)),
        endAt: Value(DateTime.utc(2026, 12, 22)),
        workflowState: const Value('active'),
      );

  CoursesCompanion course(int id, int termId, String name) => CoursesCompanion.insert(
        id: Value(id),
        termId: termId,
        name: name,
        courseCode: '$name-CODE',
        institution: const Value('컴퓨터공학부'),
        teacherNames: const Value('윤현주'),
        workflowState: const Value('available'),
      );

  CalendarEventsCompanion event(String id, int courseId, DateTime dueAt) =>
      CalendarEventsCompanion.insert(
        id: Value(id),
        courseId: Value(courseId),
        termId: 8,
        title: '과제 $id',
        contextName: const Value('리눅스시스템프로그래밍-01'),
        startAt: Value(dueAt),
        endAt: Value(dueAt),
        htmlUrl: const Value('https://canvas.kumoh.ac.kr/x'),
      );

  test('학기를 upsert하고 최신순으로 읽는다', () async {
    await db.termsDao.upsertAll([term(6, '2026-1학기'), term(8, '2026-2학기')]);
    final rows = await db.termsDao.watchAll().first;
    expect(rows.map((t) => t.id), [8, 6], reason: 'id 내림차순 = 최신 학기 우선');
  });

  test('강좌는 학기별로 조회된다', () async {
    await db.coursesDao.upsertAll([
      course(4831, 8, '리눅스시스템프로그래밍-01'),
      course(5682, 8, '모두를위한아두이노-02'),
      course(1111, 6, '지난학기강좌'),
    ]);
    final rows = await db.coursesDao.watchByTerm(8).first;
    expect(rows.length, 2);
    expect(rows.every((c) => c.termId == 8), isTrue);
  });

  test('같은 id를 다시 upsert하면 덮어쓴다', () async {
    await db.coursesDao.upsertAll([course(4831, 8, '옛이름')]);
    await db.coursesDao.upsertAll([course(4831, 8, '새이름')]);
    final rows = await db.coursesDao.watchByTerm(8).first;
    expect(rows.single.name, '새이름');
  });

  test('replaceForTerm은 해당 학기의 사라진 강좌를 제거한다', () async {
    await db.coursesDao.replaceForTerm(8, [course(4831, 8, 'A'), course(5682, 8, 'B')]);
    await db.coursesDao.replaceForTerm(8, [course(4831, 8, 'A')]);
    final rows = await db.coursesDao.watchByTerm(8).first;
    expect(rows.map((c) => c.id), [4831]);
  });

  test('마감 임박 이벤트를 기간으로 조회한다', () async {
    final now = DateTime.utc(2026, 9, 5, 12);
    await db.calendarEventsDao.upsertAll([
      event('assignment_1', 4831, now.add(const Duration(days: 1))),
      event('assignment_2', 4831, now.add(const Duration(days: 30))),
      event('assignment_3', 4831, now.subtract(const Duration(days: 2))),
    ]);

    final upcoming = await db.calendarEventsDao
        .watchBetween(from: now, to: now.add(const Duration(days: 7)))
        .first;

    expect(upcoming.map((e) => e.id), ['assignment_1']);
  });

  test('CacheMeta로 신선도를 판정한다', () async {
    expect(await db.cacheMetaDao.fetchedAt('courses:8'), isNull);

    await db.cacheMetaDao.touch('courses:8');
    final at = await db.cacheMetaDao.fetchedAt('courses:8');

    expect(at, isNotNull);
    expect(CachePolicy.isFresh(at, const Duration(hours: 6)), isTrue);
    expect(CachePolicy.isFresh(at, Duration.zero), isFalse);
    expect(CachePolicy.isFresh(null, const Duration(hours: 6)), isFalse);
  });

  test('wipe는 모든 캐시를 비운다', () async {
    await db.termsDao.upsertAll([term(8, '2026-2학기')]);
    await db.coursesDao.upsertAll([course(4831, 8, 'A')]);
    await db.cacheMetaDao.touch('courses:8');

    await db.wipe();

    expect(await db.termsDao.watchAll().first, isEmpty);
    expect(await db.coursesDao.watchByTerm(8).first, isEmpty);
    expect(await db.cacheMetaDao.fetchedAt('courses:8'), isNull);
  });
}
```

- [ ] **Step 3: 테스트 실행 → 실패 확인**

Run: `flutter test test/core/app_database_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:kumoh_lms/core/storage/db/app_database.dart'`

- [ ] **Step 4: cache_policy.dart 구현**

`lib/core/storage/cache_policy.dart`:
```dart
/// 컬렉션 단위 캐시 신선도 판정. 이 창 안에서는 네트워크를 치지 않는다.
class CachePolicy {
  const CachePolicy._();

  static bool isFresh(DateTime? fetchedAt, Duration ttl) {
    if (fetchedAt == null) return false;
    return DateTime.now().toUtc().difference(fetchedAt.toUtc()) < ttl;
  }
}
```

- [ ] **Step 5: tables.dart 구현**

`lib/core/storage/db/tables.dart`:
```dart
import 'package:drift/drift.dart';

/// 학기. id는 서버(LINUS)의 termId를 그대로 쓴다.
class Terms extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  DateTimeColumn get startAt => dateTime().nullable()();
  DateTimeColumn get endAt => dateTime().nullable()();
  TextColumn get workflowState => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 수강 강좌. teachers 배열은 표시용 문자열로 평탄화해 저장한다.
class Courses extends Table {
  IntColumn get id => integer()();
  IntColumn get termId => integer()();
  TextColumn get name => text()();
  TextColumn get courseCode => text()();
  TextColumn get institution => text().withDefault(const Constant(''))();
  TextColumn get teacherNames => text().withDefault(const Constant(''))();
  IntColumn get totalStudents => integer().withDefault(const Constant(0))();
  TextColumn get workflowState => text().withDefault(const Constant(''))();
  TextColumn get courseFormat => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 캘린더 이벤트(과제 마감 포함). id는 'assignment_7931' 형태의 문자열이다.
class CalendarEvents extends Table {
  TextColumn get id => text()();
  IntColumn get termId => integer()();
  IntColumn get courseId => integer().nullable()();
  TextColumn get contextName => text().withDefault(const Constant(''))();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get startAt => dateTime().nullable()();
  DateTimeColumn get endAt => dateTime().nullable()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get htmlUrl => text().withDefault(const Constant(''))();
  TextColumn get workflowState => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 공지사항.
class Announcements extends Table {
  TextColumn get id => text()();
  IntColumn get termId => integer()();
  IntColumn get courseId => integer().nullable()();
  TextColumn get contextName => text().withDefault(const Constant(''))();
  TextColumn get title => text()();
  TextColumn get message => text().withDefault(const Constant(''))();
  TextColumn get authorName => text().withDefault(const Constant(''))();
  DateTimeColumn get postedAt => dateTime().nullable()();
  TextColumn get htmlUrl => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 컬렉션 단위 마지막 조회 시각. TTL 판정에 쓴다.
class CacheMetaEntries extends Table {
  TextColumn get key => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
```

- [ ] **Step 6: app_database.dart 구현**

`lib/core/storage/db/app_database.dart`:
```dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Terms, Courses, CalendarEvents, Announcements, CacheMetaEntries],
  daos: [TermsDao, CoursesDao, CalendarEventsDao, AnnouncementsDao, CacheMetaDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// 실기기용. SQLCipher로 암호화된 파일 DB를 연다.
  factory AppDatabase.encrypted(Future<String> Function() keyProvider) =>
      AppDatabase(_openEncrypted(keyProvider));

  /// 테스트용. 보통 NativeDatabase.memory()를 넘긴다.
  factory AppDatabase.forTesting(QueryExecutor executor) => AppDatabase(executor);

  /// drift 기본값은 DateTime을 정수 타임스탬프로 저장해 읽을 때 isUtc를 잃는다.
  /// DateTime.==는 isUtc까지 비교하므로 UTC로 쓴 값이 왕복 후 달라진다.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  @override
  int get schemaVersion => 1;

  /// 로그아웃 시 캐시 전체 삭제.
  Future<void> wipe() async {
    await transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }
}

LazyDatabase _openEncrypted(Future<String> Function() keyProvider) {
  return LazyDatabase(() async {
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    open.overrideForAll(openCipherOnAndroid);

    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'kumoh_lms.sqlite'));
    final key = await keyProvider();
    final escaped = key.replaceAll("'", "''");

    return NativeDatabase.createInBackground(
      file,
      setup: (db) => db.execute("PRAGMA key = '$escaped';"),
    );
  });
}

@DriftAccessor(tables: [Terms])
class TermsDao extends DatabaseAccessor<AppDatabase> with _$TermsDaoMixin {
  TermsDao(super.db);

  /// id 내림차순 = 최신 학기 우선.
  Stream<List<TermRow>> watchAll() =>
      (select(terms)..orderBy([(t) => OrderingTerm.desc(t.id)])).watch();

  Future<void> upsertAll(List<TermsCompanion> rows) async {
    await batch((b) => b.insertAllOnConflictUpdate(terms, rows));
  }
}

@DriftAccessor(tables: [Courses])
class CoursesDao extends DatabaseAccessor<AppDatabase> with _$CoursesDaoMixin {
  CoursesDao(super.db);

  Stream<List<CourseRow>> watchByTerm(int termId) =>
      (select(courses)
            ..where((c) => c.termId.equals(termId))
            ..orderBy([(c) => OrderingTerm.asc(c.name)]))
          .watch();

  Future<void> upsertAll(List<CoursesCompanion> rows) async {
    await batch((b) => b.insertAllOnConflictUpdate(courses, rows));
  }

  /// 서버에서 사라진 강좌(수강 취소 등)를 캐시에서도 없애기 위해
  /// 해당 학기를 통째로 교체한다.
  Future<void> replaceForTerm(int termId, List<CoursesCompanion> rows) async {
    await transaction(() async {
      await (delete(courses)..where((c) => c.termId.equals(termId))).go();
      await batch((b) => b.insertAllOnConflictUpdate(courses, rows));
    });
  }
}

@DriftAccessor(tables: [CalendarEvents])
class CalendarEventsDao extends DatabaseAccessor<AppDatabase>
    with _$CalendarEventsDaoMixin {
  CalendarEventsDao(super.db);

  Stream<List<CalendarEventRow>> watchByTerm(int termId) =>
      (select(calendarEvents)
            ..where((e) => e.termId.equals(termId))
            ..orderBy([(e) => OrderingTerm.asc(e.startAt)]))
          .watch();

  /// [from] 이상 [to] 미만인 이벤트. 마감 임박 목록과 월별 캘린더에 함께 쓴다.
  Stream<List<CalendarEventRow>> watchBetween({
    required DateTime from,
    required DateTime to,
  }) =>
      (select(calendarEvents)
            ..where((e) =>
                e.startAt.isBiggerOrEqualValue(from) & e.startAt.isSmallerThanValue(to))
            ..orderBy([(e) => OrderingTerm.asc(e.startAt)]))
          .watch();

  Future<void> upsertAll(List<CalendarEventsCompanion> rows) async {
    await batch((b) => b.insertAllOnConflictUpdate(calendarEvents, rows));
  }

  Future<void> replaceForTerm(int termId, List<CalendarEventsCompanion> rows) async {
    await transaction(() async {
      await (delete(calendarEvents)..where((e) => e.termId.equals(termId))).go();
      await batch((b) => b.insertAllOnConflictUpdate(calendarEvents, rows));
    });
  }
}

@DriftAccessor(tables: [Announcements])
class AnnouncementsDao extends DatabaseAccessor<AppDatabase>
    with _$AnnouncementsDaoMixin {
  AnnouncementsDao(super.db);

  Stream<List<AnnouncementRow>> watchByTerm(int termId) =>
      (select(announcements)
            ..where((a) => a.termId.equals(termId))
            ..orderBy([(a) => OrderingTerm.desc(a.postedAt)]))
          .watch();

  Future<void> replaceForTerm(int termId, List<AnnouncementsCompanion> rows) async {
    await transaction(() async {
      await (delete(announcements)..where((a) => a.termId.equals(termId))).go();
      await batch((b) => b.insertAllOnConflictUpdate(announcements, rows));
    });
  }
}

@DriftAccessor(tables: [CacheMetaEntries])
class CacheMetaDao extends DatabaseAccessor<AppDatabase> with _$CacheMetaDaoMixin {
  CacheMetaDao(super.db);

  Future<DateTime?> fetchedAt(String key) async {
    final row = await (select(cacheMetaEntries)..where((e) => e.key.equals(key)))
        .getSingleOrNull();
    return row?.fetchedAt;
  }

  Future<void> touch(String key) async {
    await into(cacheMetaEntries).insertOnConflictUpdate(
      CacheMetaEntriesCompanion.insert(
        key: key,
        fetchedAt: DateTime.now().toUtc(),
      ),
    );
  }
}
```

- [ ] **Step 7: Drift 코드젠 실행**

Run:
```bash
dart run build_runner build --delete-conflicting-outputs
```
Expected: `Succeeded after ...` 그리고 `lib/core/storage/db/app_database.g.dart` 생성.

> 생성된 row 클래스 이름이 `Term`/`Course`가 아니라 `TermRow`/`CourseRow`가 되도록, 테이블 클래스 이름은 복수형(`Terms`, `Courses`)이고 drift가 단수형 + `Row` 접미사를 붙이지 않는다면 `@DataClassName('TermRow')` 를 각 테이블 클래스 위에 붙인다. 생성 결과를 확인하고 이름이 다르면 `tables.dart`의 각 테이블에 다음을 추가한 뒤 코드젠을 다시 돌린다:
> ```dart
> @DataClassName('TermRow')
> class Terms extends Table { ... }
> ```
> (`CourseRow`, `CalendarEventRow`, `AnnouncementRow`도 동일)

- [ ] **Step 8: 테스트 헬퍼 작성**

`test/helpers/test_db.dart`:
```dart
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
```

- [ ] **Step 9: 테스트 실행 → 통과 확인**

Run: `flutter test test/core/app_database_test.dart`
Expected: `All tests passed!` (7개 테스트)

- [ ] **Step 10: 커밋**

```bash
git add lib/core/storage test/core/app_database_test.dart test/helpers .gitignore
git commit -m "feat: SQLCipher 암호화 Drift 캐시와 DAO 추가

Drift row 클래스를 UI 모델로 직접 사용하고, CacheMeta로 컬렉션 TTL을 관리한다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 7: 기준 데이터 리포지토리 (기관 + 학기)

**Files:**
- Create: `lib/features/reference/data/reference_api.dart`, `lib/features/reference/data/reference_repository.dart`
- Test: `test/features/reference/reference_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`(Task 6), `unwrapEnvelope`/`throwAsFailure`(Task 2·4), `Env`, `CachePolicy`
- Produces:
  - `class AccountInfo { final int id; final String name; final String universityName; final double scaleGpa; final String themeColor; factory AccountInfo.fromJson(...) }`
  - `class ReferenceApi { ReferenceApi(Dio); Future<AccountInfo> fetchAccount(); Future<List<TermsCompanion>> fetchTerms(int accountId); }`
  - `class ReferenceRepository { Stream<List<TermRow>> watchTerms(); Future<void> refreshTerms({bool force = false}); Future<int?> currentTermId(); }`

- [ ] **Step 1: 실패 테스트 작성**

`test/features/reference/reference_repository_test.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/reference/data/reference_api.dart';
import 'package:kumoh_lms/features/reference/data/reference_repository.dart';

import '../../fixtures/fixtures.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late Dio dio;
  late DioAdapter adapter;
  late ReferenceRepository repo;

  setUp(() {
    db = createTestDatabase();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    adapter = DioAdapter(dio: dio);
    repo = ReferenceRepository(api: ReferenceApi(dio), db: db);
  });
  tearDown(() => db.close());

  test('refreshTerms는 학기를 받아 캐시에 저장한다', () async {
    adapter.onGet('/terms', (s) => s.reply(200, termsJson),
        queryParameters: {'accountId': 1});

    await repo.refreshTerms();

    final rows = await repo.watchTerms().first;
    expect(rows.map((t) => t.id), [8, 6]);
    expect(rows.first.name, '2026-2학기');
  });

  test('TTL 안에서는 두 번째 호출이 네트워크를 치지 않는다', () async {
    var calls = 0;
    // http_mock_adapter의 onGet 콜백은 등록 시점에 1회만 실행되고 실제 요청
    // 횟수와 무관하다. 진짜 네트워크 호출 수는 Dio 인터셉터로 센다.
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls++;
      handler.next(options);
    }));
    adapter.onGet('/terms', (s) => s.reply(200, termsJson), queryParameters: {'accountId': 1});

    await repo.refreshTerms();
    await repo.refreshTerms();

    expect(calls, 1);
  });

  test('force가 true면 TTL을 무시하고 다시 받아온다', () async {
    var calls = 0;
    // http_mock_adapter의 onGet 콜백은 등록 시점에 1회만 실행되고 실제 요청
    // 횟수와 무관하다. 진짜 네트워크 호출 수는 Dio 인터셉터로 센다.
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls++;
      handler.next(options);
    }));
    adapter.onGet('/terms', (s) => s.reply(200, termsJson), queryParameters: {'accountId': 1});

    await repo.refreshTerms();
    await repo.refreshTerms(force: true);

    expect(calls, 2);
  });

  test('currentTermId는 오늘 날짜를 포함하는 학기를 고른다', () async {
    adapter.onGet('/terms', (s) => s.reply(200, termsJson),
        queryParameters: {'accountId': 1});
    await repo.refreshTerms();

    // 픽스처의 2026-2학기는 2026-09-01 ~ 2026-12-22
    final id = await repo.currentTermId(now: DateTime.utc(2026, 9, 5));
    expect(id, 8);
  });

  test('현재 날짜에 맞는 학기가 없으면 가장 최근 학기를 고른다', () async {
    adapter.onGet('/terms', (s) => s.reply(200, termsJson),
        queryParameters: {'accountId': 1});
    await repo.refreshTerms();

    final id = await repo.currentTermId(now: DateTime.utc(2030, 1, 1));
    expect(id, 8, reason: 'id가 가장 큰 학기로 폴백');
  });

  test('캐시가 비어 있으면 currentTermId는 null이다', () async {
    expect(await repo.currentTermId(), isNull);
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/features/reference/reference_repository_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../reference_api.dart'`

- [ ] **Step 3: reference_api.dart 구현**

`lib/features/reference/data/reference_api.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/storage/db/app_database.dart';
import '../../auth/data/auth_api.dart' show throwAsFailure;

/// `/accounts` 응답. 기관 표시명·테마색·GPA 만점을 담는다.
class AccountInfo {
  const AccountInfo({
    required this.id,
    required this.name,
    required this.universityName,
    required this.scaleGpa,
    required this.themeColor,
  });

  final int id;
  final String name;
  final String universityName;
  final double scaleGpa;
  final String themeColor;

  factory AccountInfo.fromJson(Map<String, dynamic> json) => AccountInfo(
        id: (json['id'] as num?)?.toInt() ?? 1,
        name: json['name'] as String? ?? '',
        universityName: json['universityName'] as String? ?? '',
        scaleGpa: (json['scaleGpa'] as num?)?.toDouble() ?? 4.5,
        themeColor: json['themeColor'] as String? ?? '#00A9CE',
      );
}

/// 서버는 두 가지 형태로 시각을 준다.
///  - 오프셋이 있는 값('...Z', '+09:00'): 그대로 UTC로 변환한다.
///  - 오프셋이 없는 값('2026-09-01T00:01:00'): KST(UTC+9) 벽시계 시각이다.
///    DateTime.tryParse는 이를 기기 로컬 시간대로 읽으므로 KST가 아닌
///    기기에서 어긋난다. 그래서 명시적으로 KST로 못박는다.
DateTime? parseServerDate(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  final hasZone =
      raw.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(raw);
  if (hasZone) return parsed.toUtc();
  return DateTime.utc(parsed.year, parsed.month, parsed.day, parsed.hour,
          parsed.minute, parsed.second, parsed.millisecond)
      .subtract(const Duration(hours: 9));
}

class ReferenceApi {
  ReferenceApi(this._dio);
  final Dio _dio;

  Future<AccountInfo> fetchAccount() async {
    try {
      final res = await _dio.get<Object?>('/accounts');
      return unwrapEnvelope(
        res.data,
        (d) => AccountInfo.fromJson(d! as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }

  Future<List<TermsCompanion>> fetchTerms(int accountId) async {
    try {
      final res = await _dio.get<Object?>(
        '/terms',
        queryParameters: {'accountId': accountId},
      );
      return unwrapEnvelope(res.data, (d) {
        final list = (d as List?) ?? const [];
        return list
            .cast<Map<String, dynamic>>()
            .map((t) => TermsCompanion.insert(
                  id: Value((t['id'] as num).toInt()),
                  name: t['name'] as String? ?? '',
                  startAt: Value(parseServerDate(t['startAt'])),
                  endAt: Value(parseServerDate(t['endAt'])),
                  workflowState: Value(t['workflowState'] as String? ?? ''),
                ))
            .toList();
      });
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }
}
```

- [ ] **Step 4: reference_repository.dart 구현**

`lib/features/reference/data/reference_repository.dart`:
```dart
import '../../../core/config/env.dart';
import '../../../core/storage/cache_policy.dart';
import '../../../core/storage/db/app_database.dart';
import 'reference_api.dart';

const String _termsCacheKey = 'terms';

/// 기관·학기처럼 거의 변하지 않는 기준 데이터.
/// 화면은 항상 캐시를 읽고, 네트워크는 TTL을 넘겼을 때만 친다.
class ReferenceRepository {
  ReferenceRepository({required ReferenceApi api, required AppDatabase db})
      : _api = api,
        _db = db;

  final ReferenceApi _api;
  final AppDatabase _db;

  Stream<List<TermRow>> watchTerms() => _db.termsDao.watchAll();

  Future<void> refreshTerms({bool force = false}) async {
    if (!force) {
      final at = await _db.cacheMetaDao.fetchedAt(_termsCacheKey);
      if (CachePolicy.isFresh(at, Env.referenceTtl)) return;
    }
    final rows = await _api.fetchTerms(Env.defaultAccountId);
    await _db.termsDao.upsertAll(rows);
    await _db.cacheMetaDao.touch(_termsCacheKey);
  }

  /// 오늘이 포함된 학기를 고르고, 없으면 가장 최근(id 최대) 학기로 폴백한다.
  Future<int?> currentTermId({DateTime? now}) async {
    final rows = await _db.termsDao.watchAll().first;
    if (rows.isEmpty) return null;

    final today = (now ?? DateTime.now()).toUtc();
    for (final t in rows) {
      final start = t.startAt;
      final end = t.endAt;
      if (start != null && end != null &&
          !today.isBefore(start) && !today.isAfter(end)) {
        return t.id;
      }
    }
    return rows.first.id; // watchAll은 id 내림차순
  }
}
```

- [ ] **Step 5: 테스트 실행 → 통과 확인**

Run: `flutter test test/features/reference/reference_repository_test.dart`
Expected: `All tests passed!` (6개 테스트)

- [ ] **Step 6: 커밋**

```bash
git add lib/features/reference test/features/reference
git commit -m "feat: 기관·학기 기준 데이터 리포지토리 추가

TTL 기반 캐시로 학기 목록을 관리하고 현재 학기를 자동 판별한다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 8: 강좌 리포지토리 (오프라인-퍼스트)

**Files:**
- Create: `lib/features/courses/data/courses_api.dart`, `lib/features/courses/data/courses_repository.dart`
- Test: `test/features/courses/courses_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `parseServerDate`(Task 7), `throwAsFailure`, `Env`, `CachePolicy`
- Produces:
  - `class CoursesApi { CoursesApi(Dio); Future<List<CoursesCompanion>> fetchCourses({required int accountId, required int termId}); }`
  - `class CoursesRepository { Stream<List<CourseRow>> watch(int termId); Future<void> refresh(int termId, {bool force = false}); }`

- [ ] **Step 1: 실패 테스트 작성**

`test/features/courses/courses_repository_test.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/courses/data/courses_api.dart';
import 'package:kumoh_lms/features/courses/data/courses_repository.dart';

import '../../fixtures/fixtures.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late Dio dio;
  late DioAdapter adapter;
  late CoursesRepository repo;

  const query = {'isMyCourse': 'true', 'accountId': 1, 'termId': 8};

  setUp(() {
    db = createTestDatabase();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    adapter = DioAdapter(dio: dio);
    repo = CoursesRepository(api: CoursesApi(dio), db: db);
  });
  tearDown(() => db.close());

  test('강좌를 받아 캐시에 저장하고 스트림으로 내보낸다', () async {
    adapter.onGet('/courses', (s) => s.reply(200, coursesJson),
        queryParameters: query);

    await repo.refresh(8);
    final rows = await repo.watch(8).first;

    expect(rows.length, 2);
    final linux = rows.firstWhere((c) => c.id == 4831);
    expect(linux.name, '리눅스시스템프로그래밍-01');
    expect(linux.courseCode, '리눅스시스템프로그래밍-GA2015-01');
    expect(linux.institution, '인공지능공학전공');
    expect(linux.totalStudents, 28);
    expect(linux.termId, 8);
  });

  test('교수 이름 배열을 표시용 문자열로 평탄화한다', () async {
    adapter.onGet('/courses', (s) => s.reply(200, coursesJson),
        queryParameters: query);

    await repo.refresh(8);
    final rows = await repo.watch(8).first;

    expect(rows.firstWhere((c) => c.id == 4831).teacherNames, '[컴퓨터공학부] 윤현주');
  });

  test('TTL 안에서는 네트워크를 다시 치지 않는다', () async {
    var calls = 0;
    // http_mock_adapter의 onGet 콜백은 등록 시점에 1회만 실행되고 실제 요청
    // 횟수와 무관하다. 진짜 네트워크 호출 수는 Dio 인터셉터로 센다.
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls++;
      handler.next(options);
    }));
    adapter.onGet('/courses', (s) => s.reply(200, coursesJson), queryParameters: query);

    await repo.refresh(8);
    await repo.refresh(8);

    expect(calls, 1);
  });

  test('수강 취소된 강좌는 새로고침 후 캐시에서 사라진다', () async {
    adapter.onGet('/courses', (s) => s.reply(200, coursesJson),
        queryParameters: query);
    await repo.refresh(8);
    expect((await repo.watch(8).first).length, 2);

    // 두 번째 응답에는 강좌가 하나만 남아 있다.
    // 공유 const 픽스처를 변형하지 않도록 별도 리터럴로 만든다.
    const shrunk = {
      'code': '200',
      'message': 'Success',
      'data': {
        'courses': [
          {
            'id': 4831,
            'name': '리눅스시스템프로그래밍-01',
            'courseCode': '리눅스시스템프로그래밍-GA2015-01',
            'totalStudents': 28,
            'teachers': <Map<String, dynamic>>[],
            'institution': '인공지능공학전공',
            'enrollmentTermId': 8,
            'workflowState': 'available',
            'courseFormat': 'ONLINE',
          },
        ],
      },
    };

    adapter.onGet('/courses', (s) => s.reply(200, shrunk), queryParameters: query);
    await repo.refresh(8, force: true);

    final rows = await repo.watch(8).first;
    expect(rows.length, 1);
    expect(rows.single.id, 4831);
  });

  test('네트워크가 실패해도 기존 캐시는 남는다', () async {
    adapter.onGet('/courses', (s) => s.reply(200, coursesJson),
        queryParameters: query);
    await repo.refresh(8);

    adapter.onGet('/courses', (s) => s.reply(401, springAuthErrorJson),
        queryParameters: query);

    await expectLater(repo.refresh(8, force: true), throwsA(isA<AuthFailure>()));
    expect((await repo.watch(8).first).length, 2, reason: '캐시는 유지돼야 한다');
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/features/courses/courses_repository_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../courses_api.dart'`

- [ ] **Step 3: courses_api.dart 구현**

`lib/features/courses/data/courses_api.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/storage/db/app_database.dart';
import '../../auth/data/auth_api.dart' show throwAsFailure;

class CoursesApi {
  CoursesApi(this._dio);
  final Dio _dio;

  Future<List<CoursesCompanion>> fetchCourses({
    required int accountId,
    required int termId,
  }) async {
    try {
      final res = await _dio.get<Object?>(
        '/courses',
        queryParameters: {
          'isMyCourse': 'true',
          'accountId': accountId,
          'termId': termId,
        },
      );
      return unwrapEnvelope(res.data, (d) {
        final map = (d as Map?) ?? const {};
        final list = (map['courses'] as List?) ?? const [];
        return list
            .cast<Map<String, dynamic>>()
            .map((c) => _toCompanion(c, termId))
            .toList();
      });
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }
}

CoursesCompanion _toCompanion(Map<String, dynamic> c, int fallbackTermId) {
  final teachers = (c['teachers'] as List?) ?? const [];
  final names = teachers
      .cast<Map<String, dynamic>>()
      .map((t) => t['displayName'] as String? ?? '')
      .where((s) => s.isNotEmpty)
      .join(', ');

  return CoursesCompanion.insert(
    id: Value((c['id'] as num).toInt()),
    termId: (c['enrollmentTermId'] as num?)?.toInt() ?? fallbackTermId,
    name: c['name'] as String? ?? '',
    courseCode: c['courseCode'] as String? ?? '',
    institution: Value(c['institution'] as String? ?? ''),
    teacherNames: Value(names),
    totalStudents: Value((c['totalStudents'] as num?)?.toInt() ?? 0),
    workflowState: Value(c['workflowState'] as String? ?? ''),
    courseFormat: Value(c['courseFormat'] as String? ?? ''),
  );
}
```

- [ ] **Step 4: courses_repository.dart 구현**

`lib/features/courses/data/courses_repository.dart`:
```dart
import '../../../core/config/env.dart';
import '../../../core/storage/cache_policy.dart';
import '../../../core/storage/db/app_database.dart';
import 'courses_api.dart';

/// 오프라인-퍼스트 강좌 저장소.
/// [watch]는 즉시 캐시를 흘려보내고, [refresh]는 TTL을 넘겼을 때만 네트워크를 친다.
class CoursesRepository {
  CoursesRepository({required CoursesApi api, required AppDatabase db})
      : _api = api,
        _db = db;

  final CoursesApi _api;
  final AppDatabase _db;

  String _cacheKey(int termId) => 'courses:$termId';

  Stream<List<CourseRow>> watch(int termId) => _db.coursesDao.watchByTerm(termId);

  Future<void> refresh(int termId, {bool force = false}) async {
    if (!force) {
      final at = await _db.cacheMetaDao.fetchedAt(_cacheKey(termId));
      if (CachePolicy.isFresh(at, Env.coursesTtl)) return;
    }
    // 실패하면 예외가 그대로 올라가고 캐시는 손대지 않는다.
    final rows = await _api.fetchCourses(
      accountId: Env.defaultAccountId,
      termId: termId,
    );
    await _db.coursesDao.replaceForTerm(termId, rows);
    await _db.cacheMetaDao.touch(_cacheKey(termId));
  }
}
```

- [ ] **Step 5: 테스트 실행 → 통과 확인**

Run: `flutter test test/features/courses/courses_repository_test.dart`
Expected: `All tests passed!` (5개 테스트)

- [ ] **Step 6: 커밋**

```bash
git add lib/features/courses test/features/courses
git commit -m "feat: 오프라인-퍼스트 강좌 리포지토리 추가

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 9: 과제 마감(캘린더 이벤트) 리포지토리

`/calendar-events`는 강좌(context_code) 하나씩 조회해야 하므로, 캐시된 강좌 목록을 돌며 모아서 한 학기 분량을 채운다.

**Files:**
- Create: `lib/features/assignments/data/calendar_api.dart`, `lib/features/assignments/data/assignments_repository.dart`
- Test: `test/features/assignments/assignments_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `CoursesRepository`(Task 8), `parseServerDate`(Task 7), `Env`, `CachePolicy`
- Produces:
  - `class CalendarApi { CalendarApi(Dio); Future<List<CalendarEventsCompanion>> fetchEvents({required int termId, required int courseId, required DateTime from, required DateTime to}); }`
  - `class AssignmentsRepository { Stream<List<CalendarEventRow>> watchTerm(int termId); Stream<List<CalendarEventRow>> watchBetween({required DateTime from, required DateTime to}); Future<void> refresh(int termId, {bool force = false}); }`

- [ ] **Step 1: 실패 테스트 작성**

`test/features/assignments/assignments_repository_test.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/assignments/data/assignments_repository.dart';
import 'package:kumoh_lms/features/assignments/data/calendar_api.dart';

import '../../fixtures/fixtures.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late Dio dio;
  late DioAdapter adapter;
  late AssignmentsRepository repo;

  setUp(() async {
    db = createTestDatabase();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    adapter = DioAdapter(dio: dio);
    repo = AssignmentsRepository(api: CalendarApi(dio), db: db);

    // 캘린더는 캐시된 강좌를 기준으로 조회하므로 강좌를 먼저 심는다.
    await db.coursesDao.upsertAll([
      CoursesCompanion.insert(
        id: const Value(4831),
        termId: 8,
        name: '리눅스시스템프로그래밍-01',
        courseCode: 'GA2015-01',
      ),
    ]);
  });
  tearDown(() => db.close());

  test('강좌별 캘린더 이벤트를 받아 캐시에 저장한다', () async {
    adapter.onGet('/calendar-events', (s) => s.reply(200, calendarEventsJson),
        queryParameters: {
          'start_date': '2026-09-01',
          'end_date': '2026-12-31',
          'context_code': 'course_4831',
        });

    await repo.refresh(8,
        from: DateTime.utc(2026, 9, 1), to: DateTime.utc(2026, 12, 31));

    final rows = await repo.watchTerm(8).first;
    expect(rows.length, 1);
    expect(rows.single.id, 'assignment_7931');
    expect(rows.single.title, '[토의 과제] 리눅스 상식');
    expect(rows.single.courseId, 4831);
    expect(rows.single.contextName, '리눅스시스템프로그래밍-01');
    expect(rows.single.htmlUrl,
        'https://canvas.kumoh.ac.kr/courses/4831/assignments/7931');
    expect(rows.single.startAt, DateTime.utc(2026, 9, 2, 14, 59));
  });

  test('context_code에서 courseId를 뽑아낸다', () {
    expect(courseIdFromContextCode('course_4831'), 4831);
    expect(courseIdFromContextCode('user_59580'), isNull);
    expect(courseIdFromContextCode(null), isNull);
  });

  test('watchBetween은 기간 안의 이벤트만 돌려준다', () async {
    adapter.onGet('/calendar-events', (s) => s.reply(200, calendarEventsJson),
        queryParameters: {
          'start_date': '2026-09-01',
          'end_date': '2026-12-31',
          'context_code': 'course_4831',
        });
    await repo.refresh(8,
        from: DateTime.utc(2026, 9, 1), to: DateTime.utc(2026, 12, 31));

    final inRange = await repo
        .watchBetween(from: DateTime.utc(2026, 9, 1), to: DateTime.utc(2026, 9, 3))
        .first;
    final outOfRange = await repo
        .watchBetween(from: DateTime.utc(2026, 10, 1), to: DateTime.utc(2026, 10, 5))
        .first;

    expect(inRange.length, 1);
    expect(outOfRange, isEmpty);
  });

  test('TTL 안에서는 네트워크를 다시 치지 않는다', () async {
    var calls = 0;
    // http_mock_adapter의 onGet 콜백은 등록 시점에 1회만 실행되고 실제 요청
    // 횟수와 무관하다. 진짜 네트워크 호출 수는 Dio 인터셉터로 센다.
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls++;
      handler.next(options);
    }));
    adapter.onGet('/calendar-events', (s) => s.reply(200, calendarEventsJson), queryParameters: {
      'start_date': '2026-09-01',
      'end_date': '2026-12-31',
      'context_code': 'course_4831',
    });

    await repo.refresh(8,
        from: DateTime.utc(2026, 9, 1), to: DateTime.utc(2026, 12, 31));
    await repo.refresh(8,
        from: DateTime.utc(2026, 9, 1), to: DateTime.utc(2026, 12, 31));

    expect(calls, 1);
  });

  test('캐시된 강좌가 없으면 네트워크를 치지 않는다', () async {
    await db.wipe();
    var calls = 0;
    // http_mock_adapter의 onGet 콜백은 등록 시점에 1회만 실행되고 실제 요청
    // 횟수와 무관하다. 진짜 네트워크 호출 수는 Dio 인터셉터로 센다.
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls++;
      handler.next(options);
    }));
    adapter.onGet('/calendar-events', (s) => s.reply(200, calendarEventsJson));

    await repo.refresh(8,
        from: DateTime.utc(2026, 9, 1), to: DateTime.utc(2026, 12, 31));

    expect(calls, 0);
    expect(await repo.watchTerm(8).first, isEmpty);
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/features/assignments/assignments_repository_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../calendar_api.dart'`

- [ ] **Step 3: calendar_api.dart 구현**

`lib/features/assignments/data/calendar_api.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/storage/db/app_database.dart';
import '../../auth/data/auth_api.dart' show throwAsFailure;
import '../../reference/data/reference_api.dart' show parseServerDate;

/// 'course_4831' → 4831. 강좌가 아닌 컨텍스트는 null.
int? courseIdFromContextCode(String? code) {
  if (code == null || !code.startsWith('course_')) return null;
  return int.tryParse(code.substring('course_'.length));
}

/// 서버가 기대하는 날짜 형식은 yyyy-MM-dd.
String formatDateParam(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class CalendarApi {
  CalendarApi(this._dio);
  final Dio _dio;

  /// 캘린더는 강좌(context_code) 단위로만 조회할 수 있다.
  Future<List<CalendarEventsCompanion>> fetchEvents({
    required int termId,
    required int courseId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final res = await _dio.get<Object?>(
        '/calendar-events',
        queryParameters: {
          'start_date': formatDateParam(from),
          'end_date': formatDateParam(to),
          'context_code': 'course_$courseId',
        },
      );
      return unwrapEnvelope(res.data, (d) {
        final map = (d as Map?) ?? const {};
        final list = (map['calendarEvents'] as List?) ?? const [];
        return list
            .cast<Map<String, dynamic>>()
            .map((e) => _toCompanion(e, termId, courseId))
            .toList();
      });
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }
}

CalendarEventsCompanion _toCompanion(
  Map<String, dynamic> e,
  int termId,
  int fallbackCourseId,
) {
  return CalendarEventsCompanion.insert(
    id: e['id'] as String? ?? '',
    termId: termId,
    courseId: Value(
      courseIdFromContextCode(e['context_code'] as String?) ?? fallbackCourseId,
    ),
    contextName: Value(e['context_name'] as String? ?? ''),
    title: e['title'] as String? ?? '',
    description: Value(e['description'] as String? ?? ''),
    startAt: Value(parseServerDate(e['start_at'])),
    endAt: Value(parseServerDate(e['end_at'])),
    allDay: Value(e['all_day'] as bool? ?? false),
    htmlUrl: Value(e['html_url'] as String? ?? ''),
    workflowState: Value(e['workflow_state'] as String? ?? ''),
  );
}
```

- [ ] **Step 4: assignments_repository.dart 구현**

`lib/features/assignments/data/assignments_repository.dart`:
```dart
import '../../../core/config/env.dart';
import '../../../core/storage/cache_policy.dart';
import '../../../core/storage/db/app_database.dart';
import 'calendar_api.dart';

export 'calendar_api.dart' show courseIdFromContextCode;

/// 과제 마감을 포함한 캘린더 이벤트 저장소.
/// 서버가 강좌 단위 조회만 지원하므로 캐시된 강좌를 순회해 한 학기분을 모은다.
class AssignmentsRepository {
  AssignmentsRepository({required CalendarApi api, required AppDatabase db})
      : _api = api,
        _db = db;

  final CalendarApi _api;
  final AppDatabase _db;

  String _cacheKey(int termId) => 'calendar:$termId';

  Stream<List<CalendarEventRow>> watchTerm(int termId) =>
      _db.calendarEventsDao.watchByTerm(termId);

  Stream<List<CalendarEventRow>> watchBetween({
    required DateTime from,
    required DateTime to,
  }) =>
      _db.calendarEventsDao.watchBetween(from: from, to: to);

  Future<void> refresh(
    int termId, {
    bool force = false,
    DateTime? from,
    DateTime? to,
  }) async {
    if (!force) {
      final at = await _db.cacheMetaDao.fetchedAt(_cacheKey(termId));
      if (CachePolicy.isFresh(at, Env.calendarTtl)) return;
    }

    final courses = await _db.coursesDao.watchByTerm(termId).first;
    if (courses.isEmpty) return; // 강좌 캐시가 먼저 채워져야 한다.

    final start = from ?? DateTime.now().toUtc().subtract(const Duration(days: 60));
    final end = to ?? DateTime.now().toUtc().add(const Duration(days: 180));

    final all = <CalendarEventsCompanion>[];
    for (final c in courses) {
      final events = await _api.fetchEvents(
        termId: termId,
        courseId: c.id,
        from: start,
        to: end,
      );
      all.addAll(events);
    }

    await _db.calendarEventsDao.replaceForTerm(termId, all);
    await _db.cacheMetaDao.touch(_cacheKey(termId));
  }
}
```

- [ ] **Step 5: 테스트 실행 → 통과 확인**

Run: `flutter test test/features/assignments/assignments_repository_test.dart`
Expected: `All tests passed!` (5개 테스트)

- [ ] **Step 6: 커밋**

```bash
git add lib/features/assignments test/features/assignments
git commit -m "feat: 과제 마감 캘린더 리포지토리 추가

강좌별 context_code로 조회해 한 학기분 이벤트를 캐시에 모은다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 10: 공지사항 리포지토리

**Files:**
- Create: `lib/features/announcements/data/announcements_api.dart`, `lib/features/announcements/data/announcements_repository.dart`
- Test: `test/features/announcements/announcements_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `parseServerDate`, `courseIdFromContextCode`(Task 9), `Env`, `CachePolicy`
- Produces:
  - `class AnnouncementsApi { AnnouncementsApi(Dio); Future<List<AnnouncementsCompanion>> fetchAnnouncements(int termId); }`
  - `class AnnouncementsRepository { Stream<List<AnnouncementRow>> watch(int termId); Future<void> refresh(int termId, {bool force = false}); }`

- [ ] **Step 1: 실패 테스트 작성**

`test/features/announcements/announcements_repository_test.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/announcements/data/announcements_api.dart';
import 'package:kumoh_lms/features/announcements/data/announcements_repository.dart';

import '../../fixtures/fixtures.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late Dio dio;
  late DioAdapter adapter;
  late AnnouncementsRepository repo;

  setUp(() {
    db = createTestDatabase();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    adapter = DioAdapter(dio: dio);
    repo = AnnouncementsRepository(api: AnnouncementsApi(dio), db: db);
  });
  tearDown(() => db.close());

  test('공지를 받아 캐시에 저장한다', () async {
    adapter.onGet('/dashboard/total/announcement',
        (s) => s.reply(200, announcementsJson),
        queryParameters: {'termId': 8});

    await repo.refresh(8);
    final rows = await repo.watch(8).first;

    expect(rows.length, 1);
    expect(rows.single.title, '2주차 실습 안내');
    expect(rows.single.courseId, 4831);
    expect(rows.single.contextName, '리눅스시스템프로그래밍-01');
    expect(rows.single.authorName, '윤현주');
    expect(rows.single.postedAt, DateTime.utc(2026, 9, 3, 1));
  });

  test('공지가 없으면 빈 목록이다', () async {
    adapter.onGet('/dashboard/total/announcement',
        (s) => s.reply(200, emptyAnnouncementsJson),
        queryParameters: {'termId': 8});

    await repo.refresh(8);

    expect(await repo.watch(8).first, isEmpty);
  });

  test('TTL 안에서는 네트워크를 다시 치지 않는다', () async {
    var calls = 0;
    // http_mock_adapter의 onGet 콜백은 등록 시점에 1회만 실행되고 실제 요청
    // 횟수와 무관하다. 진짜 네트워크 호출 수는 Dio 인터셉터로 센다.
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls++;
      handler.next(options);
    }));
    adapter.onGet('/dashboard/total/announcement', (s) => s.reply(200, announcementsJson), queryParameters: {'termId': 8});

    await repo.refresh(8);
    await repo.refresh(8);

    expect(calls, 1);
  });

  test('force면 다시 받아온다', () async {
    var calls = 0;
    // http_mock_adapter의 onGet 콜백은 등록 시점에 1회만 실행되고 실제 요청
    // 횟수와 무관하다. 진짜 네트워크 호출 수는 Dio 인터셉터로 센다.
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls++;
      handler.next(options);
    }));
    adapter.onGet('/dashboard/total/announcement', (s) => s.reply(200, announcementsJson), queryParameters: {'termId': 8});

    await repo.refresh(8);
    await repo.refresh(8, force: true);

    expect(calls, 2);
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/features/announcements/announcements_repository_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../announcements_api.dart'`

- [ ] **Step 3: announcements_api.dart 구현**

`lib/features/announcements/data/announcements_api.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/storage/db/app_database.dart';
import '../../assignments/data/calendar_api.dart' show courseIdFromContextCode;
import '../../auth/data/auth_api.dart' show throwAsFailure;
import '../../reference/data/reference_api.dart' show parseServerDate;

class AnnouncementsApi {
  AnnouncementsApi(this._dio);
  final Dio _dio;

  Future<List<AnnouncementsCompanion>> fetchAnnouncements(int termId) async {
    try {
      final res = await _dio.get<Object?>(
        '/dashboard/total/announcement',
        queryParameters: {'termId': termId},
      );
      return unwrapEnvelope(res.data, (d) {
        final map = (d as Map?) ?? const {};
        final list = (map['announcements'] as List?) ?? const [];
        return list
            .cast<Map<String, dynamic>>()
            .map((a) => _toCompanion(a, termId))
            .toList();
      });
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }
}

AnnouncementsCompanion _toCompanion(Map<String, dynamic> a, int termId) {
  // 서버가 camelCase와 snake_case를 섞어 쓰는 경우가 있어 둘 다 본다.
  Object? pick(String camel, String snake) => a[camel] ?? a[snake];

  return AnnouncementsCompanion.insert(
    id: (pick('id', 'id') ?? '').toString(),
    termId: termId,
    courseId: Value(courseIdFromContextCode(
      (pick('contextCode', 'context_code') as String?),
    )),
    contextName: Value((pick('contextName', 'context_name') as String?) ?? ''),
    title: (pick('title', 'title') as String?) ?? '',
    message: Value((pick('message', 'message') as String?) ?? ''),
    authorName: Value((pick('userName', 'user_name') as String?) ?? ''),
    postedAt: Value(parseServerDate(pick('postedAt', 'posted_at'))),
    htmlUrl: Value((pick('htmlUrl', 'html_url') as String?) ?? ''),
  );
}
```

- [ ] **Step 4: announcements_repository.dart 구현**

`lib/features/announcements/data/announcements_repository.dart`:
```dart
import '../../../core/config/env.dart';
import '../../../core/storage/cache_policy.dart';
import '../../../core/storage/db/app_database.dart';
import 'announcements_api.dart';

class AnnouncementsRepository {
  AnnouncementsRepository({
    required AnnouncementsApi api,
    required AppDatabase db,
  })  : _api = api,
        _db = db;

  final AnnouncementsApi _api;
  final AppDatabase _db;

  String _cacheKey(int termId) => 'announcements:$termId';

  Stream<List<AnnouncementRow>> watch(int termId) =>
      _db.announcementsDao.watchByTerm(termId);

  Future<void> refresh(int termId, {bool force = false}) async {
    if (!force) {
      final at = await _db.cacheMetaDao.fetchedAt(_cacheKey(termId));
      if (CachePolicy.isFresh(at, Env.announcementsTtl)) return;
    }
    final rows = await _api.fetchAnnouncements(termId);
    await _db.announcementsDao.replaceForTerm(termId, rows);
    await _db.cacheMetaDao.touch(_cacheKey(termId));
  }
}
```

- [ ] **Step 5: 테스트 실행 → 통과 확인**

Run: `flutter test test/features/announcements/announcements_repository_test.dart`
Expected: `All tests passed!` (4개 테스트)

- [ ] **Step 6: 전체 테스트 + 커밋**

Run: `flutter test`
Expected: `All tests passed!` — Task 1~10 전체 통과.

```bash
git add lib/features/announcements test/features/announcements
git commit -m "feat: 공지사항 리포지토리 추가

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 11: Riverpod 배선 + AuthController

**Files:**
- Create: `lib/providers.dart`, `lib/features/auth/presentation/auth_controller.dart`
- Test: `test/features/auth/auth_controller_test.dart`

**Interfaces:**
- Consumes: 지금까지의 모든 리포지토리·API·`TokenStore`·`AppDatabase`
- Produces:
  - `sealed class AuthState` → `AuthUnauthenticated`, `AuthAuthenticated({required UserProfile profile})`
  - `class AuthController extends AsyncNotifier<AuthState>` — `login({required String userId, required String password, required bool rememberMe})`, `logout()`, `handleSessionExpired()`
  - Provider: `tokenStoreProvider`, `appDatabaseProvider`, `authDioProvider`, `authApiProvider`, `dioProvider`, `referenceRepositoryProvider`, `coursesRepositoryProvider`, `assignmentsRepositoryProvider`, `announcementsRepositoryProvider`, `authControllerProvider`, `selectedTermIdProvider`

- [ ] **Step 1: 실패 테스트 작성**

`test/features/auth/auth_controller_test.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/auth/presentation/auth_controller.dart';
import 'package:kumoh_lms/providers.dart';

import '../../fixtures/fixtures.dart';
import '../../helpers/test_db.dart';

void main() {
  late InMemoryTokenStore store;
  late AppDatabase db;
  late Dio authDio;
  late DioAdapter authAdapter;
  late ProviderContainer container;

  ProviderContainer makeContainer() => ProviderContainer(overrides: [
        tokenStoreProvider.overrideWithValue(store),
        appDatabaseProvider.overrideWithValue(db),
        authDioProvider.overrideWithValue(authDio),
      ]);

  setUp(() {
    store = InMemoryTokenStore();
    db = createTestDatabase();
    authDio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    authAdapter = DioAdapter(dio: authDio);
    container = makeContainer();
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  test('토큰이 없으면 초기 상태는 미인증이다', () async {
    final state = await container.read(authControllerProvider.future);
    expect(state, isA<AuthUnauthenticated>());
  });

  test('로그인 성공 시 토큰을 저장하고 인증 상태가 된다', () async {
    authAdapter.onPost('/login', (s) => s.reply(200, loginSuccessJson),
        data: {'userId': '20250000', 'password': 'pw'});
    authAdapter.onGet('/user/profile', (s) => s.reply(200, userProfileJson));

    await container.read(authControllerProvider.future);
    await container.read(authControllerProvider.notifier).login(
          userId: '20250000',
          password: 'pw',
          rememberMe: false,
        );

    final state = container.read(authControllerProvider).value;
    expect(state, isA<AuthAuthenticated>());
    expect((state! as AuthAuthenticated).profile.name, '홍길동');
    expect(await store.readAccessToken(), 'header.accessPayload.sig');
    expect(await store.readRefreshToken(), 'header.refreshPayload.sig');
  });

  test('rememberMe가 false면 자격증명을 저장하지 않는다', () async {
    authAdapter.onPost('/login', (s) => s.reply(200, loginSuccessJson),
        data: {'userId': '20250000', 'password': 'pw'});
    authAdapter.onGet('/user/profile', (s) => s.reply(200, userProfileJson));

    await container.read(authControllerProvider.future);
    await container.read(authControllerProvider.notifier).login(
          userId: '20250000',
          password: 'pw',
          rememberMe: false,
        );

    expect(await store.readCredentials(), isNull);
  });

  test('rememberMe가 true면 자격증명을 저장한다', () async {
    authAdapter.onPost('/login', (s) => s.reply(200, loginSuccessJson),
        data: {'userId': '20250000', 'password': 'pw'});
    authAdapter.onGet('/user/profile', (s) => s.reply(200, userProfileJson));

    await container.read(authControllerProvider.future);
    await container.read(authControllerProvider.notifier).login(
          userId: '20250000',
          password: 'pw',
          rememberMe: true,
        );

    expect((await store.readCredentials())?.userId, '20250000');
  });

  test('로그인 실패는 에러 상태가 되고 토큰을 저장하지 않는다', () async {
    authAdapter.onPost(
      '/login',
      (s) => s.reply(200, {
        'code': 'U001',
        'message': '아이디 또는 비밀번호가 올바르지 않습니다.',
        'data': null,
      }),
      data: {'userId': '20250000', 'password': 'wrong'},
    );

    await container.read(authControllerProvider.future);
    await container.read(authControllerProvider.notifier).login(
          userId: '20250000',
          password: 'wrong',
          rememberMe: false,
        );

    expect(container.read(authControllerProvider).hasError, isTrue);
    expect(await store.readAccessToken(), isNull);
  });

  test('저장된 refreshToken이 있으면 재발급으로 세션을 복원한다', () async {
    await store.saveTokens(accessToken: 'old', refreshToken: 'oldRefresh');
    authAdapter.onPost(
      '/reissue',
      (s) => s.reply(200, {
        'code': '200',
        'message': 'Success',
        'data': {'accessToken': 'newAccess', 'refreshToken': 'newRefresh'},
      }),
      headers: {'X-Refresh-Token': 'oldRefresh'},
    );
    authAdapter.onGet('/user/profile', (s) => s.reply(200, userProfileJson));

    final state = await makeContainer().read(authControllerProvider.future);

    expect(state, isA<AuthAuthenticated>());
    expect(await store.readAccessToken(), 'newAccess');
  });

  test('로그아웃은 토큰·자격증명·캐시를 모두 비운다', () async {
    await store.saveTokens(accessToken: 'a', refreshToken: 'r');
    await store.saveCredentials(userId: '20250000', password: 'pw');
    await db.cacheMetaDao.touch('courses:8');
    authAdapter.onPost('/logout', (s) => s.reply(200, {'code': '200', 'message': 'Success', 'data': null}));

    await container.read(authControllerProvider.notifier).logout();

    expect(await store.readAccessToken(), isNull);
    expect(await store.readCredentials(), isNull);
    expect(await db.cacheMetaDao.fetchedAt('courses:8'), isNull);
    expect(container.read(authControllerProvider).value, isA<AuthUnauthenticated>());
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/features/auth/auth_controller_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:kumoh_lms/providers.dart'`

- [ ] **Step 3: auth_controller.dart 구현**

`lib/features/auth/presentation/auth_controller.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers.dart';
import '../data/auth_dto.dart';

/// 세션 상태. 라우터가 이 값을 보고 로그인 화면 여부를 결정한다.
sealed class AuthState {
  const AuthState();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.profile});
  final UserProfile profile;
}

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() => _restoreSession();

  /// 앱 시작 시 저장된 refreshToken으로 세션을 되살린다.
  /// 실패하면 자동 로그인이 켜져 있을 때만 자격증명으로 재시도한다.
  Future<AuthState> _restoreSession() async {
    final store = ref.read(tokenStoreProvider);
    final authApi = ref.read(authApiProvider);

    final refresh = await store.readRefreshToken();
    if (refresh != null && refresh.isNotEmpty) {
      try {
        final tokens = await authApi.reissue(refresh);
        await store.saveTokens(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
        );
        final profile = await authApi.fetchProfile();
        return AuthAuthenticated(profile: profile);
      } on Object {
        await store.clearTokens();
      }
    }

    return _autoLoginOrUnauthenticated();
  }

  /// 자동 로그인이 켜져 있으면 저장된 자격증명으로 다시 로그인하고,
  /// 아니면 미인증 상태로 떨어진다.
  Future<AuthState> _autoLoginOrUnauthenticated() async {
    final store = ref.read(tokenStoreProvider);
    final creds = await store.readCredentials();
    if (creds == null) return const AuthUnauthenticated();
    try {
      return await _performLogin(
        userId: creds.userId,
        password: creds.password,
        rememberMe: true,
      );
    } on Object {
      await store.clearAll();
      return const AuthUnauthenticated();
    }
  }

  Future<AuthState> _performLogin({
    required String userId,
    required String password,
    required bool rememberMe,
  }) async {
    final store = ref.read(tokenStoreProvider);
    final authApi = ref.read(authApiProvider);

    final tokens = await authApi.login(userId: userId, password: password);
    await store.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );

    if (rememberMe) {
      await store.saveCredentials(userId: userId, password: password);
    } else {
      await store.clearCredentials();
    }

    final profile = await authApi.fetchProfile();
    return AuthAuthenticated(profile: profile);
  }

  Future<void> login({
    required String userId,
    required String password,
    required bool rememberMe,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _performLogin(
        userId: userId,
        password: password,
        rememberMe: rememberMe,
      ),
    );
  }

  Future<void> logout() async {
    final store = ref.read(tokenStoreProvider);
    final db = ref.read(appDatabaseProvider);
    await ref.read(authApiProvider).logout();
    await store.clearAll();
    await db.wipe();
    state = const AsyncData(AuthUnauthenticated());
  }

  /// 인터셉터가 재발급에 실패했을 때 호출된다.
  /// 자동 로그인이 켜져 있으면 조용히 다시 로그인한다.
  Future<void> handleSessionExpired() async {
    final result = await _autoLoginOrUnauthenticated();
    state = AsyncData(result);
  }
}
```

- [ ] **Step 4: providers.dart 구현**

`lib/providers.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/dio_client.dart';
import 'core/network/token_store.dart';
import 'core/storage/db/app_database.dart';
import 'features/announcements/data/announcements_api.dart';
import 'features/announcements/data/announcements_repository.dart';
import 'features/assignments/data/assignments_repository.dart';
import 'features/assignments/data/calendar_api.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/courses/data/courses_api.dart';
import 'features/courses/data/courses_repository.dart';
import 'features/reference/data/reference_api.dart';
import 'features/reference/data/reference_repository.dart';

// ---------- 인프라 ----------

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final store = ref.watch(tokenStoreProvider);
  final db = AppDatabase.encrypted(store.ensureDbKey);
  ref.onDispose(db.close);
  return db;
});

/// 인터셉터가 없는 dio. 로그인·재발급 전용이라 재귀가 생기지 않는다.
final authDioProvider = Provider<Dio>((ref) => buildAuthDio());

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(authDioProvider)));

/// 나머지 모든 API가 쓰는 dio. 토큰 부착과 자동 재발급이 붙어 있다.
final dioProvider = Provider<Dio>((ref) {
  final store = ref.watch(tokenStoreProvider);
  final authApi = ref.watch(authApiProvider);
  return buildDio(
    tokenStore: store,
    reissue: authApi.reissue,
    // ref.read를 콜백 안에서 늦게 부르는 것이 순환 의존을 끊는다.
    onSessionExpired: () =>
        ref.read(authControllerProvider.notifier).handleSessionExpired(),
  );
});

// ---------- 리포지토리 ----------

final referenceRepositoryProvider = Provider<ReferenceRepository>((ref) =>
    ReferenceRepository(
      api: ReferenceApi(ref.watch(dioProvider)),
      db: ref.watch(appDatabaseProvider),
    ));

final coursesRepositoryProvider = Provider<CoursesRepository>((ref) =>
    CoursesRepository(
      api: CoursesApi(ref.watch(dioProvider)),
      db: ref.watch(appDatabaseProvider),
    ));

final assignmentsRepositoryProvider = Provider<AssignmentsRepository>((ref) =>
    AssignmentsRepository(
      api: CalendarApi(ref.watch(dioProvider)),
      db: ref.watch(appDatabaseProvider),
    ));

final announcementsRepositoryProvider = Provider<AnnouncementsRepository>((ref) =>
    AnnouncementsRepository(
      api: AnnouncementsApi(ref.watch(dioProvider)),
      db: ref.watch(appDatabaseProvider),
    ));

// ---------- 상태 ----------

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);

/// 화면에서 고른 학기. null이면 아직 결정 전이다.
final selectedTermIdProvider = StateProvider<int?>((ref) => null);
```

- [ ] **Step 5: 테스트 실행 → 통과 확인**

Run: `flutter test test/features/auth/auth_controller_test.dart`
Expected: `All tests passed!` (7개 테스트)

- [ ] **Step 6: 커밋**

```bash
git add lib/providers.dart lib/features/auth/presentation test/features/auth/auth_controller_test.dart
git commit -m "feat: Riverpod 배선과 AuthController 추가

세션 복원·로그인·로그아웃·만료 처리와 선택적 자동 로그인을 담당한다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 12: 테마 + 앱 셸

> 라우터(`app_router.dart`)와 앱 진입점(`app.dart`, `main.dart`)은 **Task 17**에서 만든다. 라우터가 아직 존재하지 않는 화면들을 import하므로, 여기서 만들면 Task 12~16 내내 `flutter analyze`가 깨진다. 화면이 모두 갖춰진 뒤에 배선한다.

**Files:**
- Create: `lib/core/config/theme.dart`, `lib/features/shell/home_shell.dart`
- Test: `test/core/theme_test.dart`

**Interfaces:**
- Consumes: 없음 (순수 위젯·테마)
- Produces:
  - `ThemeData buildLightTheme()`, `ThemeData buildDarkTheme()`, `const Color kKitBrand`
  - `class HomeShell extends StatelessWidget` — `HomeShell({required this.navigationShell})`, `navigationShell`은 `StatefulNavigationShell`

- [ ] **Step 1: 실패 테스트 작성**

`test/core/theme_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/config/theme.dart';

void main() {
  test('브랜드 색은 금오공대 테마색이다', () {
    expect(kKitBrand, const Color(0xFF00A9CE));
  });

  test('라이트/다크 테마 모두 Material3이며 브랜드 시드를 쓴다', () {
    final light = buildLightTheme();
    final dark = buildDarkTheme();

    expect(light.useMaterial3, isTrue);
    expect(dark.useMaterial3, isTrue);
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/core/theme_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:kumoh_lms/core/config/theme.dart'`

- [ ] **Step 3: theme.dart 구현**

`lib/core/config/theme.dart`:
```dart
import 'package:flutter/material.dart';

/// 학교 포털이 쓰는 테마색 (/accounts 의 themeColor).
const Color kKitBrand = Color(0xFF00A9CE);

ThemeData _base(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: kKitBrand, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      filled: true,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
  );
}

ThemeData buildLightTheme() => _base(Brightness.light);
ThemeData buildDarkTheme() => _base(Brightness.dark);
```

- [ ] **Step 4: 테스트 실행 → 통과 확인**

Run: `flutter test test/core/theme_test.dart`
Expected: `All tests passed!` (2개 테스트)

- [ ] **Step 5: home_shell.dart 구현**

`lib/features/shell/home_shell.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 하단 탭 네비게이션 셸. 각 탭은 자기 네비게이션 스택을 유지한다.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '강좌',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: '과제',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: '공지',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: 커밋**

Run: `flutter test test/core/theme_test.dart`
Expected: `All tests passed!`

Run: `flutter analyze`
Expected: `No issues found!` — 이 태스크가 만든 파일은 아직 배선되지 않은 상태로도 독립적으로 컴파일된다.

```bash
git add lib/core/config/theme.dart lib/features/shell test/core/theme_test.dart
git commit -m "feat: KIT 테마와 하단 탭 셸 추가

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 13: 로그인 화면

**Files:**
- Create: `lib/features/auth/presentation/login_screen.dart`
- Test: `test/features/auth/login_screen_test.dart`

**Interfaces:**
- Consumes: `authControllerProvider`, `kKitBrand`
- Produces: `class LoginScreen extends ConsumerStatefulWidget`

- [ ] **Step 1: 실패 테스트 작성**

`test/features/auth/login_screen_test.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/auth/presentation/auth_controller.dart';
import 'package:kumoh_lms/features/auth/presentation/login_screen.dart';
import 'package:kumoh_lms/providers.dart';

import '../../fixtures/fixtures.dart';
import '../../helpers/test_db.dart';

void main() {
  late InMemoryTokenStore store;
  late AppDatabase db;
  late Dio authDio;
  late DioAdapter authAdapter;

  setUp(() {
    store = InMemoryTokenStore();
    db = createTestDatabase();
    authDio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    authAdapter = DioAdapter(dio: authDio);
  });
  tearDown(() => db.close());

  Widget wrap() => ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(store),
          appDatabaseProvider.overrideWithValue(db),
          authDioProvider.overrideWithValue(authDio),
        ],
        child: const MaterialApp(home: LoginScreen()),
      );

  testWidgets('학번과 비밀번호 입력란, 로그인 버튼이 보인다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('학번'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '로그인'), findsOneWidget);
    expect(find.text('자동 로그인'), findsOneWidget);
  });

  testWidgets('빈 입력으로 제출하면 검증 메시지를 보여준다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();

    expect(find.text('학번을 입력해 주세요.'), findsOneWidget);
    expect(find.text('비밀번호를 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('로그인 실패 시 에러 메시지를 보여준다', (tester) async {
    authAdapter.onPost(
      '/login',
      (s) => s.reply(200, {
        'code': 'U001',
        'message': '아이디 또는 비밀번호가 올바르지 않습니다.',
        'data': null,
      }),
      data: {'userId': '20250000', 'password': 'wrong'},
    );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('login_user_id')), '20250000');
    await tester.enterText(find.byKey(const Key('login_password')), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();

    expect(find.text('아이디 또는 비밀번호가 올바르지 않습니다.'), findsOneWidget);
  });

  testWidgets('로그인 성공 시 토큰이 저장된다', (tester) async {
    authAdapter.onPost('/login', (s) => s.reply(200, loginSuccessJson),
        data: {'userId': '20250000', 'password': 'pw'});
    authAdapter.onGet('/user/profile', (s) => s.reply(200, userProfileJson));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('login_user_id')), '20250000');
    await tester.enterText(find.byKey(const Key('login_password')), 'pw');
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();

    expect(await store.readAccessToken(), 'header.accessPayload.sig');
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/features/auth/login_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../login_screen.dart'`

- [ ] **Step 3: login_screen.dart 구현**

`lib/features/auth/presentation/login_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/theme.dart';
import '../../../core/error/failure.dart';
import '../../../providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(authControllerProvider.notifier).login(
          userId: _userIdController.text,
          password: _passwordController.text,
          rememberMe: _rememberMe,
        );
  }

  String _errorText(Object error) =>
      error is Failure ? error.message : '로그인에 실패했습니다.';

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final busy = auth.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.school, size: 56, color: kKitBrand),
                    const SizedBox(height: 12),
                    Text(
                      '금오 LMS',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '학교 포털 계정으로 로그인하세요',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      key: const Key('login_user_id'),
                      controller: _userIdController,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: '학번'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? '학번을 입력해 주세요.' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('login_password'),
                      controller: _passwordController,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => busy ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? '비밀번호를 입력해 주세요.' : null,
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile.adaptive(
                      value: _rememberMe,
                      onChanged: (v) => setState(() => _rememberMe = v),
                      title: const Text('자동 로그인'),
                      subtitle: const Text('학번과 비밀번호를 기기 보안 저장소에 보관합니다.'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (auth.hasError) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorText(auth.error!),
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('로그인'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '입력한 정보는 학교 서버로만 전송되며, 외부로 나가지 않습니다.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트 실행 → 통과 확인**

Run: `flutter test test/features/auth/login_screen_test.dart`
Expected: `All tests passed!` (4개 테스트)

- [ ] **Step 5: 커밋**

```bash
git add lib/features/auth/presentation/login_screen.dart test/features/auth/login_screen_test.dart
git commit -m "feat: 로그인 화면 추가

학번/비밀번호 검증, 자동 로그인 토글(기본 꺼짐), 실패 메시지 표시.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 14: 공용 UI 조각 + 학기 부트스트랩 provider

강좌·과제·공지 세 화면이 똑같이 필요로 하는 것들을 먼저 만든다: 현재 학기 결정, 새로고침 실패를 캐시 위에 얹어 보여주는 래퍼, 빈 상태 위젯.

**Files:**
- Create: `lib/features/reference/presentation/term_providers.dart`, `lib/core/ui/async_section.dart`, `lib/core/ui/empty_state.dart`
- Test: `test/features/reference/term_providers_test.dart`

**Interfaces:**
- Consumes: `referenceRepositoryProvider`, `selectedTermIdProvider`, `Failure`
- Produces:
  - `final termsProvider = StreamProvider<List<TermRow>>`
  - `final activeTermIdProvider = FutureProvider<int?>` — 선택 학기가 있으면 그것, 없으면 오늘 기준 현재 학기
  - `final refreshErrorProvider = StateProvider<String?>` — 마지막 새로고침 실패 메시지
  - `class EmptyState extends StatelessWidget` — `EmptyState({required IconData icon, required String title, String? description})`
  - `class RefreshBanner extends ConsumerWidget` — 새로고침 실패 시 캐시 위에 얇게 뜨는 안내줄

- [ ] **Step 1: 실패 테스트 작성**

`test/features/reference/term_providers_test.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/reference/data/reference_api.dart';
import 'package:kumoh_lms/features/reference/data/reference_repository.dart';
import 'package:kumoh_lms/features/reference/presentation/term_providers.dart';
import 'package:kumoh_lms/providers.dart';

import '../../fixtures/fixtures.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late Dio dio;
  late DioAdapter adapter;
  late ProviderContainer container;

  setUp(() {
    db = createTestDatabase();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'));
    adapter = DioAdapter(dio: dio);
    container = ProviderContainer(overrides: [
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      appDatabaseProvider.overrideWithValue(db),
      referenceRepositoryProvider.overrideWithValue(
        ReferenceRepository(api: ReferenceApi(dio), db: db),
      ),
    ]);
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  test('termsProvider는 캐시된 학기를 흘려보낸다', () async {
    adapter.onGet('/terms', (s) => s.reply(200, termsJson),
        queryParameters: {'accountId': 1});
    await container.read(referenceRepositoryProvider).refreshTerms();

    final rows = await container.read(termsProvider.future);

    expect(rows.map((t) => t.id), [8, 6]);
  });

  test('activeTermIdProvider는 선택 학기가 없으면 현재 학기를 고른다', () async {
    adapter.onGet('/terms', (s) => s.reply(200, termsJson),
        queryParameters: {'accountId': 1});
    await container.read(referenceRepositoryProvider).refreshTerms();

    final id = await container.read(activeTermIdProvider.future);

    expect(id, 8);
  });

  test('선택 학기가 지정되면 그것을 그대로 쓴다', () async {
    container.read(selectedTermIdProvider.notifier).state = 6;

    final id = await container.read(activeTermIdProvider.future);

    expect(id, 6);
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/features/reference/term_providers_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../term_providers.dart'`

- [ ] **Step 3: term_providers.dart 구현**

`lib/features/reference/presentation/term_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/db/app_database.dart';
import '../../../providers.dart';

final termsProvider = StreamProvider<List<TermRow>>((ref) =>
    ref.watch(referenceRepositoryProvider).watchTerms());

/// 화면이 실제로 쓸 학기 id.
/// 사용자가 고른 값이 있으면 그것, 없으면 오늘이 속한 학기를 자동 선택한다.
final activeTermIdProvider = FutureProvider<int?>((ref) async {
  final selected = ref.watch(selectedTermIdProvider);
  if (selected != null) return selected;

  final repo = ref.watch(referenceRepositoryProvider);
  await repo.refreshTerms();
  return repo.currentTermId();
});

/// 마지막 새로고침 실패 메시지. 캐시는 그대로 두고 배너로만 알린다.
final refreshErrorProvider = StateProvider<String?>((ref) => null);
```

- [ ] **Step 4: 공용 위젯 구현**

`lib/core/ui/empty_state.dart`:
```dart
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
```

`lib/core/ui/async_section.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/reference/presentation/term_providers.dart';

/// 새로고침이 실패했을 때 캐시 위에 얇게 뜨는 안내줄.
/// 화면 전체를 에러로 덮지 않는 것이 이 앱의 원칙이다.
class RefreshBanner extends ConsumerWidget {
  const RefreshBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(refreshErrorProvider);
    if (message == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.cloud_off, size: 18, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 12, color: scheme.onErrorContainer),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 16, color: scheme.onErrorContainer),
              onPressed: () =>
                  ref.read(refreshErrorProvider.notifier).state = null,
            ),
          ],
        ),
      ),
    );
  }
}

/// 리포지토리 새로고침을 감싸 실패를 배너 메시지로 바꾼다.
/// 예외를 삼키므로 캐시 화면은 그대로 유지된다.
Future<void> runRefresh(WidgetRef ref, Future<void> Function() action) async {
  try {
    await action();
    ref.read(refreshErrorProvider.notifier).state = null;
  } on Object catch (e) {
    ref.read(refreshErrorProvider.notifier).state =
        '새로고침에 실패했습니다. 저장된 데이터를 표시합니다. ($e)';
  }
}
```

- [ ] **Step 5: 테스트 실행 → 통과 확인**

Run: `flutter test test/features/reference/term_providers_test.dart`
Expected: `All tests passed!` (3개 테스트)

- [ ] **Step 6: 커밋**

```bash
git add lib/features/reference/presentation lib/core/ui test/features/reference/term_providers_test.dart
git commit -m "feat: 학기 부트스트랩 provider와 공용 UI 조각 추가

새로고침 실패는 화면을 덮지 않고 배너로만 알린다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 15: 강좌 목록 화면

**Files:**
- Create: `lib/features/courses/presentation/courses_providers.dart`, `lib/features/courses/presentation/course_list_screen.dart`, `lib/features/courses/presentation/widgets/course_card.dart`
- Test: `test/features/courses/course_list_screen_test.dart`

**Interfaces:**
- Consumes: `coursesRepositoryProvider`, `activeTermIdProvider`, `termsProvider`, `EmptyState`, `RefreshBanner`, `runRefresh`
- Produces:
  - `final coursesProvider = StreamProvider.family<List<CourseRow>, int>`
  - `class CourseListScreen extends ConsumerWidget`
  - `class CourseCard extends StatelessWidget` — `CourseCard({required this.course})`

- [ ] **Step 1: 실패 테스트 작성**

`test/features/courses/course_list_screen_test.dart`:
```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/courses/presentation/course_list_screen.dart';
import 'package:kumoh_lms/features/reference/presentation/term_providers.dart';
import 'package:kumoh_lms/providers.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Widget wrap() => ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          // 네트워크를 타지 않도록 학기를 고정한다.
          activeTermIdProvider.overrideWith((ref) async => 8),
        ],
        child: const MaterialApp(home: CourseListScreen()),
      );

  testWidgets('캐시된 강좌를 카드로 보여준다', (tester) async {
    await db.coursesDao.upsertAll([
      CoursesCompanion.insert(
        id: const Value(4831),
        termId: 8,
        name: '리눅스시스템프로그래밍-01',
        courseCode: 'GA2015-01',
        institution: const Value('인공지능공학전공'),
        teacherNames: const Value('[컴퓨터공학부] 윤현주'),
        totalStudents: const Value(28),
      ),
    ]);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('리눅스시스템프로그래밍-01'), findsOneWidget);
    expect(find.textContaining('윤현주'), findsOneWidget);
    expect(find.textContaining('인공지능공학전공'), findsOneWidget);
  });

  testWidgets('강좌가 없으면 빈 상태를 보여준다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('수강 중인 강좌가 없습니다'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/features/courses/course_list_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../course_list_screen.dart'`

- [ ] **Step 3: courses_providers.dart 구현**

`lib/features/courses/presentation/courses_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/db/app_database.dart';
import '../../../providers.dart';

/// 학기별 강좌 스트림. Drift가 캐시 변경을 자동으로 흘려보낸다.
final coursesProvider = StreamProvider.family<List<CourseRow>, int>(
  (ref, termId) => ref.watch(coursesRepositoryProvider).watch(termId),
);
```

- [ ] **Step 4: course_card.dart 구현**

`lib/features/courses/presentation/widgets/course_card.dart`:
```dart
import 'package:flutter/material.dart';

import '../../../../core/storage/db/app_database.dart';

class CourseCard extends StatelessWidget {
  const CourseCard({required this.course, super.key});

  final CourseRow course;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitleParts = [
      if (course.teacherNames.isNotEmpty) course.teacherNames,
      if (course.institution.isNotEmpty) course.institution,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              course.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (subtitleParts.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subtitleParts.join(' · '),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.outline),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                _Chip(text: course.courseCode),
                if (course.courseFormat.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _Chip(text: course.courseFormat),
                ],
                const Spacer(),
                Text(
                  '${course.totalStudents}명',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
```

- [ ] **Step 5: course_list_screen.dart 구현**

`lib/features/courses/presentation/course_list_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/async_section.dart';
import '../../../core/ui/empty_state.dart';
import '../../../providers.dart';
import '../../reference/presentation/term_providers.dart';
import 'courses_providers.dart';
import 'widgets/course_card.dart';

class CourseListScreen extends ConsumerWidget {
  const CourseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termAsync = ref.watch(activeTermIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('강좌')),
      body: Column(
        children: [
          const RefreshBanner(),
          Expanded(
            child: termAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                icon: Icons.error_outline,
                title: '학기 정보를 불러오지 못했습니다',
                description: '$e',
              ),
              data: (termId) {
                if (termId == null) {
                  return const EmptyState(
                    icon: Icons.calendar_today_outlined,
                    title: '학기 정보가 없습니다',
                  );
                }
                return _CourseList(termId: termId);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseList extends ConsumerStatefulWidget {
  const _CourseList({required this.termId});
  final int termId;

  @override
  ConsumerState<_CourseList> createState() => _CourseListState();
}

class _CourseListState extends ConsumerState<_CourseList> {
  @override
  void initState() {
    super.initState();
    // 화면 진입 시 한 번 시도. TTL 안이면 리포지토리가 알아서 건너뛴다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh({bool force = false}) => runRefresh(
        ref,
        () => ref
            .read(coursesRepositoryProvider)
            .refresh(widget.termId, force: force),
      );

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider(widget.termId));

    return RefreshIndicator(
      onRefresh: () => _refresh(force: true),
      child: coursesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: '강좌를 불러오지 못했습니다',
          description: '$e',
        ),
        data: (courses) {
          if (courses.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: '수강 중인 강좌가 없습니다',
                  description: '아래로 당겨 새로고침해 보세요.',
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: courses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => CourseCard(course: courses[i]),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 6: 테스트 실행 → 통과 확인**

Run: `flutter test test/features/courses/course_list_screen_test.dart`
Expected: `All tests passed!` (2개 테스트)

- [ ] **Step 7: 커밋**

```bash
git add lib/features/courses/presentation test/features/courses/course_list_screen_test.dart
git commit -m "feat: 강좌 목록 화면 추가

캐시를 즉시 보여주고 당겨서 새로고침으로만 네트워크를 친다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 16: 과제 마감 화면 (캘린더 + 리스트)

**Files:**
- Create: `lib/features/assignments/presentation/assignments_providers.dart`, `lib/features/assignments/presentation/assignments_screen.dart`, `lib/features/assignments/presentation/widgets/event_tile.dart`
- Test: `test/features/assignments/assignments_screen_test.dart`

**Interfaces:**
- Consumes: `assignmentsRepositoryProvider`, `activeTermIdProvider`, `EmptyState`, `RefreshBanner`, `runRefresh`
- Produces:
  - `final termEventsProvider = StreamProvider.family<List<CalendarEventRow>, int>`
  - `class AssignmentsScreen extends ConsumerStatefulWidget` — 상단 탭 두 개(캘린더 / 목록)
  - `class EventTile extends StatelessWidget` — `EventTile({required this.event})`
  - `String formatDue(DateTime? at)` — '9월 2일 (화) 23:59' 형태

- [ ] **Step 1: 실패 테스트 작성**

`test/features/assignments/assignments_screen_test.dart`:
```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/assignments/presentation/assignments_screen.dart';
import 'package:kumoh_lms/features/assignments/presentation/widgets/event_tile.dart';
import 'package:kumoh_lms/features/reference/presentation/term_providers.dart';
import 'package:kumoh_lms/providers.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUpAll(() => initializeDateFormatting('ko_KR'));
  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Widget wrap() => ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeTermIdProvider.overrideWith((ref) async => 8),
        ],
        child: const MaterialApp(home: AssignmentsScreen()),
      );

  Future<void> seedEvent(DateTime dueAt) => db.calendarEventsDao.upsertAll([
        CalendarEventsCompanion.insert(
          id: 'assignment_7931',
          termId: 8,
          courseId: const Value(4831),
          title: '[토의 과제] 리눅스 상식',
          contextName: const Value('리눅스시스템프로그래밍-01'),
          startAt: Value(dueAt),
          endAt: Value(dueAt),
          htmlUrl: const Value('https://canvas.kumoh.ac.kr/courses/4831/assignments/7931'),
        ),
      ]);

  testWidgets('목록 탭에서 과제 제목과 강좌명을 보여준다', (tester) async {
    await seedEvent(DateTime.utc(2026, 9, 20, 14, 59));

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('목록'));
    await tester.pumpAndSettle();

    expect(find.text('[토의 과제] 리눅스 상식'), findsOneWidget);
    expect(find.textContaining('리눅스시스템프로그래밍-01'), findsWidgets);
  });

  testWidgets('과제가 없으면 빈 상태를 보여준다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('목록'));
    await tester.pumpAndSettle();

    expect(find.text('예정된 과제가 없습니다'), findsOneWidget);
  });

  test('formatDue는 한국어 날짜 형식을 만든다', () {
    expect(formatDue(DateTime(2026, 9, 2, 23, 59)), '9월 2일 (수) 23:59');
    expect(formatDue(null), '기한 없음');
  });
}
```

> 요일 표기는 실제 로케일 결과에 맞춘다. 테스트가 실패하면 `flutter test` 출력에 찍힌 실제 문자열로 기대값을 고친다 — 형식 자체(`M월 d일 (E) HH:mm`)가 맞는지만 확인하면 된다.

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/features/assignments/assignments_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../assignments_screen.dart'`

- [ ] **Step 3: assignments_providers.dart 구현**

`lib/features/assignments/presentation/assignments_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/db/app_database.dart';
import '../../../providers.dart';

/// 한 학기의 모든 캘린더 이벤트(과제 마감 포함).
final termEventsProvider = StreamProvider.family<List<CalendarEventRow>, int>(
  (ref, termId) => ref.watch(assignmentsRepositoryProvider).watchTerm(termId),
);
```

- [ ] **Step 4: event_tile.dart 구현**

`lib/features/assignments/presentation/widgets/event_tile.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/storage/db/app_database.dart';

/// '9월 2일 (수) 23:59' 형태. 기한이 없으면 안내 문구.
String formatDue(DateTime? at) {
  if (at == null) return '기한 없음';
  return DateFormat('M월 d일 (E) HH:mm', 'ko_KR').format(at.toLocal());
}

/// 마감까지 남은 시간을 사람이 읽는 문구로.
String dueRelative(DateTime? at, {DateTime? now}) {
  if (at == null) return '';
  final base = now ?? DateTime.now();
  final diff = at.toLocal().difference(base);
  if (diff.isNegative) return '마감됨';
  if (diff.inHours < 24) return 'D-DAY';
  return 'D-${diff.inDays}';
}

class EventTile extends StatelessWidget {
  const EventTile({required this.event, super.key});

  final CalendarEventRow event;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badge = dueRelative(event.startAt);
    final overdue = badge == '마감됨';

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(event.title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${event.contextName}\n${formatDue(event.startAt)}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.outline),
          ),
        ),
        isThreeLine: true,
        trailing: badge.isEmpty
            ? null
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: overdue ? scheme.surfaceContainerHighest : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: overdue ? scheme.outline : scheme.onPrimaryContainer,
                  ),
                ),
              ),
        onTap: event.htmlUrl.isEmpty
            ? null
            : () => launchUrl(
                  Uri.parse(event.htmlUrl),
                  mode: LaunchMode.externalApplication,
                ),
      ),
    );
  }
}
```

- [ ] **Step 5: assignments_screen.dart 구현**

`lib/features/assignments/presentation/assignments_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/storage/db/app_database.dart';
import '../../../core/ui/async_section.dart';
import '../../../core/ui/empty_state.dart';
import '../../../providers.dart';
import '../../reference/presentation/term_providers.dart';
import 'assignments_providers.dart';
import 'widgets/event_tile.dart';

export 'widgets/event_tile.dart' show formatDue;

class AssignmentsScreen extends ConsumerWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termAsync = ref.watch(activeTermIdProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('과제'),
          bottom: const TabBar(
            tabs: [Tab(text: '캘린더'), Tab(text: '목록')],
          ),
        ),
        body: Column(
          children: [
            const RefreshBanner(),
            Expanded(
              child: termAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => EmptyState(
                  icon: Icons.error_outline,
                  title: '학기 정보를 불러오지 못했습니다',
                  description: '$e',
                ),
                data: (termId) => termId == null
                    ? const EmptyState(
                        icon: Icons.calendar_today_outlined,
                        title: '학기 정보가 없습니다',
                      )
                    : _AssignmentsBody(termId: termId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentsBody extends ConsumerStatefulWidget {
  const _AssignmentsBody({required this.termId});
  final int termId;

  @override
  ConsumerState<_AssignmentsBody> createState() => _AssignmentsBodyState();
}

class _AssignmentsBodyState extends ConsumerState<_AssignmentsBody> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh({bool force = false}) => runRefresh(
        ref,
        () async {
          // 캘린더는 강좌 캐시가 있어야 조회할 수 있다.
          await ref.read(coursesRepositoryProvider).refresh(widget.termId);
          await ref
              .read(assignmentsRepositoryProvider)
              .refresh(widget.termId, force: force);
        },
      );

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(termEventsProvider(widget.termId));

    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: '과제를 불러오지 못했습니다',
        description: '$e',
      ),
      data: (events) => TabBarView(
        children: [
          _CalendarTab(
            events: events,
            focusedDay: _focusedDay,
            selectedDay: _selectedDay,
            sameDay: _sameDay,
            onDaySelected: (selected, focused) => setState(() {
              _selectedDay = selected;
              _focusedDay = focused;
            }),
            onRefresh: () => _refresh(force: true),
          ),
          _ListTab(events: events, onRefresh: () => _refresh(force: true)),
        ],
      ),
    );
  }
}

class _CalendarTab extends StatelessWidget {
  const _CalendarTab({
    required this.events,
    required this.focusedDay,
    required this.selectedDay,
    required this.sameDay,
    required this.onDaySelected,
    required this.onRefresh,
  });

  final List<CalendarEventRow> events;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final bool Function(DateTime, DateTime) sameDay;
  final void Function(DateTime, DateTime) onDaySelected;
  final Future<void> Function() onRefresh;

  List<CalendarEventRow> _eventsOn(DateTime day) => events
      .where((e) => e.startAt != null && sameDay(e.startAt!.toLocal(), day))
      .toList();

  @override
  Widget build(BuildContext context) {
    final day = selectedDay ?? focusedDay;
    final dayEvents = _eventsOn(day);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        children: [
          TableCalendar<CalendarEventRow>(
            locale: 'ko_KR',
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: focusedDay,
            selectedDayPredicate: (d) => sameDay(d, day),
            eventLoader: _eventsOn,
            onDaySelected: onDaySelected,
            calendarFormat: CalendarFormat.month,
            availableGestures: AvailableGestures.horizontalSwipe,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
          const Divider(height: 1),
          if (dayEvents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: EmptyState(
                icon: Icons.event_available_outlined,
                title: '이 날짜에는 마감이 없습니다',
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final e in dayEvents) ...[
                    EventTile(event: e),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ListTab extends StatelessWidget {
  const _ListTab({required this.events, required this.onRefresh});

  final List<CalendarEventRow> events;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final upcoming = events
        .where((e) => e.startAt != null && e.startAt!.toLocal().isAfter(now))
        .toList()
      ..sort((a, b) => a.startAt!.compareTo(b.startAt!));

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: upcoming.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: Icons.assignment_outlined,
                  title: '예정된 과제가 없습니다',
                  description: '아래로 당겨 새로고침해 보세요.',
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: upcoming.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => EventTile(event: upcoming[i]),
            ),
    );
  }
}
```

- [ ] **Step 6: 테스트 실행 → 통과 확인**

Run: `flutter test test/features/assignments/assignments_screen_test.dart`
Expected: `All tests passed!` (3개 테스트). `formatDue` 요일 기대값이 다르면 실제 출력에 맞춰 고친다.

- [ ] **Step 7: 커밋**

```bash
git add lib/features/assignments/presentation test/features/assignments/assignments_screen_test.dart
git commit -m "feat: 과제 마감 캘린더/목록 화면 추가

D-DAY 배지와 Canvas 원문 링크 열기를 포함한다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## Task 17: 공지 화면 + 설정 화면 + 최종 통합

마지막 두 화면을 만든 뒤, 지금까지의 모든 화면을 라우터·앱 진입점에 배선한다. 이 태스크가 끝나면 앱 전체가 처음으로 컴파일되고 실행된다.

**Files:**
- Create: `lib/features/announcements/presentation/announcements_providers.dart`, `lib/features/announcements/presentation/announcements_screen.dart`, `lib/features/settings/presentation/settings_screen.dart`, `lib/core/router/app_router.dart`, `lib/app.dart`
- Modify: `lib/main.dart` (전체 교체)
- Test: `test/features/announcements/announcements_screen_test.dart`

**Interfaces:**
- Consumes: `announcementsRepositoryProvider`, `authControllerProvider`, `AuthState`, `activeTermIdProvider`, `termsProvider`, `selectedTermIdProvider`, `HomeShell`(Task 12), `buildLightTheme`/`buildDarkTheme`(Task 12), 그리고 Task 13·15·16의 화면 위젯
- Produces:
  - `final termAnnouncementsProvider = StreamProvider.family<List<AnnouncementRow>, int>`
  - `class AnnouncementsScreen extends ConsumerWidget`
  - `class SettingsScreen extends ConsumerWidget`
  - `final routerProvider = Provider<GoRouter>` — 경로 `/login`, `/courses`, `/assignments`, `/announcements`, `/settings`
  - `class KumohLmsApp extends ConsumerWidget`

- [ ] **Step 1: 실패 테스트 작성**

`test/features/announcements/announcements_screen_test.dart`:
```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/features/announcements/presentation/announcements_screen.dart';
import 'package:kumoh_lms/features/reference/presentation/term_providers.dart';
import 'package:kumoh_lms/providers.dart';

import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUpAll(() => initializeDateFormatting('ko_KR'));
  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  Widget wrap() => ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeTermIdProvider.overrideWith((ref) async => 8),
        ],
        child: const MaterialApp(home: AnnouncementsScreen()),
      );

  testWidgets('공지 제목과 강좌명을 보여준다', (tester) async {
    await db.announcementsDao.replaceForTerm(8, [
      AnnouncementsCompanion.insert(
        id: '991',
        termId: 8,
        courseId: const Value(4831),
        title: '2주차 실습 안내',
        message: const Value('<p>실습실은 D동 401호입니다.</p>'),
        contextName: const Value('리눅스시스템프로그래밍-01'),
        authorName: const Value('윤현주'),
        postedAt: Value(DateTime.utc(2026, 9, 3, 1)),
      ),
    ]);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('2주차 실습 안내'), findsOneWidget);
    expect(find.textContaining('리눅스시스템프로그래밍-01'), findsOneWidget);
  });

  testWidgets('공지가 없으면 빈 상태를 보여준다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('새로운 공지가 없습니다'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `flutter test test/features/announcements/announcements_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../announcements_screen.dart'`

- [ ] **Step 3: announcements_providers.dart 구현**

`lib/features/announcements/presentation/announcements_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/db/app_database.dart';
import '../../../providers.dart';

final termAnnouncementsProvider =
    StreamProvider.family<List<AnnouncementRow>, int>(
  (ref, termId) => ref.watch(announcementsRepositoryProvider).watch(termId),
);
```

- [ ] **Step 4: announcements_screen.dart 구현**

`lib/features/announcements/presentation/announcements_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/storage/db/app_database.dart';
import '../../../core/ui/async_section.dart';
import '../../../core/ui/empty_state.dart';
import '../../../providers.dart';
import '../../reference/presentation/term_providers.dart';
import 'announcements_providers.dart';

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termAsync = ref.watch(activeTermIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('공지사항')),
      body: Column(
        children: [
          const RefreshBanner(),
          Expanded(
            child: termAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                icon: Icons.error_outline,
                title: '학기 정보를 불러오지 못했습니다',
                description: '$e',
              ),
              data: (termId) => termId == null
                  ? const EmptyState(
                      icon: Icons.calendar_today_outlined,
                      title: '학기 정보가 없습니다',
                    )
                  : _AnnouncementList(termId: termId),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementList extends ConsumerStatefulWidget {
  const _AnnouncementList({required this.termId});
  final int termId;

  @override
  ConsumerState<_AnnouncementList> createState() => _AnnouncementListState();
}

class _AnnouncementListState extends ConsumerState<_AnnouncementList> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh({bool force = false}) => runRefresh(
        ref,
        () => ref
            .read(announcementsRepositoryProvider)
            .refresh(widget.termId, force: force),
      );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(termAnnouncementsProvider(widget.termId));

    return RefreshIndicator(
      onRefresh: () => _refresh(force: true),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline,
          title: '공지를 불러오지 못했습니다',
          description: '$e',
        ),
        data: (items) {
          if (items.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: Icons.campaign_outlined,
                  title: '새로운 공지가 없습니다',
                  description: '아래로 당겨 새로고침해 보세요.',
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _AnnouncementCard(item: items[i]),
          );
        },
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item});
  final AnnouncementRow item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final meta = [
      if (item.contextName.isNotEmpty) item.contextName,
      if (item.authorName.isNotEmpty) item.authorName,
      if (item.postedAt != null)
        DateFormat('M월 d일', 'ko_KR').format(item.postedAt!.toLocal()),
    ].join(' · ');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: item.htmlUrl.isEmpty
            ? null
            : () => launchUrl(
                  Uri.parse(item.htmlUrl),
                  mode: LaunchMode.externalApplication,
                ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: Theme.of(context).textTheme.titleMedium),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  meta,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.outline),
                ),
              ],
              if (item.message.isNotEmpty) ...[
                const SizedBox(height: 10),
                HtmlWidget(
                  item.message,
                  textStyle: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: settings_screen.dart 구현**

`lib/features/settings/presentation/settings_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../reference/presentation/term_providers.dart';

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
                final picked = await showModalBottomSheet<int?>(
                  context: context,
                  builder: (_) => SafeArea(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        ListTile(
                          title: const Text('현재 학기 자동 선택'),
                          onTap: () => Navigator.pop(context, null),
                        ),
                        for (final t in terms)
                          ListTile(
                            title: Text(t.name),
                            selected: t.id == selectedTermId,
                            onTap: () => Navigator.pop(context, t.id),
                          ),
                      ],
                    ),
                  ),
                );
                ref.read(selectedTermIdProvider.notifier).state = picked;
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('보안'),
            subtitle: const Text(
              '토큰과 캐시는 기기 보안 저장소에 암호화되어 저장되며, '
              '외부 서버로 전송되지 않습니다.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('로그아웃', style: TextStyle(color: Colors.red)),
            subtitle: const Text('저장된 토큰·자격증명·캐시를 모두 삭제합니다.'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('로그아웃'),
                  content: const Text('저장된 데이터를 모두 지우고 로그아웃할까요?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('로그아웃'),
                    ),
                  ],
                ),
              );
              if (ok ?? false) {
                await ref.read(authControllerProvider.notifier).logout();
              }
            },
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: 테스트 실행 → 통과 확인**

Run: `flutter test test/features/announcements/announcements_screen_test.dart`
Expected: `All tests passed!` (2개 테스트)

- [ ] **Step 7: app_router.dart 구현**

`lib/core/router/app_router.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/announcements/presentation/announcements_screen.dart';
import '../../features/assignments/presentation/assignments_screen.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/courses/presentation/course_list_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shell/home_shell.dart';
import '../../providers.dart';

/// AsyncValue 변화를 Listenable로 바꿔 GoRouter가 재평가하게 만든다.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable(ref);
  ref.onDispose(listenable.dispose);

  final shellKey = GlobalKey<NavigatorState>();

  return GoRouter(
    initialLocation: '/courses',
    refreshListenable: listenable,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      // 세션 복원 중에는 아무 데도 보내지 않는다.
      if (auth.isLoading) return null;

      final loggedIn = auth.value is AuthAuthenticated;
      final onLogin = state.matchedLocation == '/login';

      if (!loggedIn) return onLogin ? null : '/login';
      if (onLogin) return '/courses';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        navigatorKey: shellKey,
        builder: (_, __, shell) => HomeShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/courses', builder: (_, __) => const CourseListScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/assignments', builder: (_, __) => const AssignmentsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/announcements', builder: (_, __) => const AnnouncementsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
          ]),
        ],
      ),
    ],
  );
});
```

- [ ] **Step 8: app.dart 와 main.dart 구현**

`lib/app.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/theme.dart';
import 'core/router/app_router.dart';

class KumohLmsApp extends ConsumerWidget {
  const KumohLmsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: '금오 LMS',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
```

`lib/main.dart` (전체 교체):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');
  runApp(const ProviderScope(child: KumohLmsApp()));
}
```

- [ ] **Step 9: 정적 분석 + 전체 테스트**

Run:
```bash
flutter analyze
flutter test
```
Expected: `No issues found!` 그리고 `All tests passed!` — 전체 테스트가 통과.

> `flutter analyze`가 `firstOrNull` 관련 오류를 내면 `settings_screen.dart` 상단에 `import 'dart:collection';` 대신 `import 'package:collection/collection.dart';` 를 추가하고 `pubspec.yaml` dependencies에 `collection: ^1.19.0` 을 넣은 뒤 `flutter pub get` 을 다시 돌린다.

- [ ] **Step 10: 실기기/에뮬레이터 수동 검증**

Android 에뮬레이터나 실기기를 연결하고:
```bash
flutter devices
flutter run
```

다음을 순서대로 확인한다:
1. 로그인 화면이 뜬다 (자동 로그인 토글은 꺼져 있다)
2. 본인 학번/비밀번호로 로그인하면 강좌 탭으로 이동한다
3. 강좌 탭에 수강 강좌가 보인다
4. 과제 탭의 캘린더에 마감일 점이 찍히고, 목록 탭에 D-DAY 배지가 보인다
5. 공지 탭이 열린다 (학기 초라 비어 있을 수 있다 — 빈 상태 문구가 보이면 정상)
6. 앱을 완전히 종료했다 재실행하면 로그인 없이 세션이 복원된다
7. 비행기 모드로 바꾼 뒤 재실행하면 캐시된 강좌·과제가 그대로 보이고 새로고침 배너가 뜬다
8. 설정 → 로그아웃하면 로그인 화면으로 돌아가고, 재실행해도 로그인 화면이다

- [ ] **Step 11: 커밋**

```bash
git add -A
git status --short   # env 와 sqlite3.dll 이 목록에 없어야 한다
git commit -m "feat: 공지 화면과 설정 화면 추가로 v1 완성

학기 선택, 보안 안내, 캐시 포함 로그아웃을 제공한다.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

## 완료 기준 (v1 Definition of Done)

- [ ] `flutter analyze` 무결점, `flutter test` 전체 통과
- [ ] 학번/비밀번호로 로그인되고, 재실행 시 세션이 복원된다
- [ ] 강좌·과제(캘린더+리스트)·공지 세 화면이 실제 데이터를 보여준다
- [ ] 오프라인에서 캐시가 표시되고, 새로고침 실패가 화면을 덮지 않는다
- [ ] 비밀번호는 자동 로그인을 켠 경우에만 저장된다
- [ ] `env`와 `sqlite3.dll`이 커밋에 포함되지 않는다

