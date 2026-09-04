# 금오공과대학교 Canvas LMS 모바일 클라이언트 — 설계 문서

- 작성일: 2026-09-05
- 상태: 승인됨 (브레인스토밍 완료 → 구현 계획 단계로 이동)
- 대상: 개인용 학생 클라이언트 (본인 계정, 본인 데이터, 클라이언트-온리)

---

## 1. 배경 & 정찰 결과 (실제 계정으로 검증)

두 도메인의 실제 구조를 로그인해 확인했다.

- **`canvas.kumoh.ac.kr`** — 진짜 Instructure Canvas LMS(오픈소스 빌드). 표준 `/api/v1/*` REST가 있으나 Bearer 토큰 필요(`www-authenticate: Bearer realm="canvas-lms"`).
- **`lms.kumoh.ac.kr`** — 학교가 Canvas 위에 올린 자체 Next.js 포털("LINUS"). 자체 백엔드 API가 **`https://lms.kumoh.ac.kr:82/api/v1/*`**(Spring 계열)로 떠 있고, Canvas 데이터를 JSON으로 가공·집계해 내려준다.

### 인증 흐름 (확정)
- `POST https://lms.kumoh.ac.kr:82/api/v1/login`  body `{ "userId": "<학번 대문자>", "password": "<비번>" }`
  → `200 { code:"200", data:{ accessToken, refreshToken } }`
- `accessToken`: JWT(HS512), 만료 **1시간**. payload에 `loginId(학번)`, `name`, `role`, `division`, `subDivision` 등.
- `refreshToken`: JWT, 만료 **약 2시간**.
- 갱신: `POST /reissue` — **`X-Refresh-Token: <refreshToken>` 헤더 필수**(쿠키/바디/Bearer 모두 실패 확인). 성공 시 `{accessToken, refreshToken}` **둘 다 새로 회전**되어 내려옴. 검증 완료.
- 모든 요청 헤더 규약(웹앱 request 인터셉터와 동일): `Authorization: Bearer <accessToken>` + `X-Refresh-Token: <refreshToken>` 동시 부착.
- **재발급 트리거 = HTTP 204**(웹앱 response 인터셉터가 `204 === status`로 판정). 방어적으로 401도 함께 처리.
- 갱신 중 동시요청은 큐잉, `_retry` 플래그로 무한루프 방지, `/reissue` 자체는 트리거 제외.

### 에러 응답이 두 가지 형태다 (검증됨)
1. **앱 봉투**: `{code, message, data}` — 애플리케이션 레벨 (`U004`, `A001` 등)
2. **원시 Spring**: `{timestamp, status, error, path}` — 필터 레벨. Authorization 헤더 없음 → **401**, 형식이 깨진 토큰 → **500**.

파서는 **두 형태를 모두** 처리해야 한다.
- 깊은 콘텐츠(과제 제출·Panopto)는 `.kumoh.ac.kr` 도메인에 `_linus_saml_login`(=loginId)/`_linus_saml_domain` 쿠키를 심고 `GET /saml/redirect.do?relayState=<path>` 가 돌려주는 Canvas SSO URL을 웹뷰로 여는 브릿지 구조. **v1 범위 밖**(심만 남김).

### 검증된 조회 엔드포인트 (모두 200 OK, Bearer 필요)
| 용도 | 엔드포인트 |
|---|---|
| 내 프로필 | `GET /user/profile` → `{canvasId,name,loginId,division,subDivision,role,locale,...}` |
| 기관 정보 | `GET /accounts` → `{id:1, name:"KIT", scaleGpa:4.5, themeColor:"#00A9CE", ...}` |
| 학기 목록 | `GET /terms?accountId=1` → `[{id,name,startAt,endAt,workflowState}]` (2026-2학기 = id 8) |
| 수강 강좌 | `GET /courses?isMyCourse=true&accountId=1&termId=8` → `{courses:[{id,name,courseCode,teachers[],enrollments[],workflowState,courseFormat,...}]}` |
| 단일 강좌 | `GET /course?courseId=<id>` |
| 과제 마감(캘린더) | `GET /calendar-events?start_date=&end_date=&context_code=course_<id>` → `{calendarEvents:[{id,title,start_at,end_at,description(HTML),context_code,context_name,html_url,all_day,workflow_state}]}` |
| 과제 집계 | `GET /student/dashboard/total/assignment?termId=8` |
| 공지 집계 | `GET /dashboard/total/announcement?termId=8` → `{announcements:[...]}` |
| 학사일정 | `GET /academic-calendar?accountId=1&termId=8` |
| 쪽지(향후) | `GET /inbox?`, `/inbox/unread-count`, `/inbox/detail?inboxId=` |

> **정직한 한계:** `lms.kumoh.ac.kr:82` API는 공식 문서 없는 학교 내부 API다. 본인 계정으로 본인 데이터를 개인 클라이언트에서 조회하는 정당한 사용이지만, 스펙이 예고 없이 바뀔 수 있다. → 설계는 **API 계층을 repository 뒤로 격리**해 교체 비용을 최소화한다.

### 확정된 세 갈래 결정
1. **인증 = LINUS JWT (학번/비번)** — 웹앱과 동일. 별도 Canvas 토큰/SSO 웹뷰 불필요.
2. **v1 범위 = 핵심 4기능, 조회 전용** — 로그인 / 강좌 목록 / 과제 마감(캘린더+리스트) / 공지사항. 쓰기 동작(제출·출석·쪽지)과 성적·출석·동영상 등은 v1 밖(같은 폴더 틀로 이후 확장).
3. **스택 = Flutter.**

---

## 2. 기술 스택 (확정)

- **Flutter 3.x / Dart 3.x**
- HTTP: **dio** (+ Interceptor로 JWT 부착/재발급/재시도 큐 — 웹앱 axios 로직 1:1 이식)
- 상태/DI: **flutter_riverpod + riverpod_generator**
- 모델: **freezed + json_serializable** (불변 DTO, JSON 직렬화)
- 로컬 캐시: **Drift (SQLite)** — 타입세이프 SQL, `watch()` 반응형 스트림, 관계형(학기→강좌→과제/이벤트)에 적합
- 캐시 암호화: **SQLCipher** (`sqlcipher_flutter_libs`), 키는 Secure Storage 보관 — **채택**
- Secure Storage: **flutter_secure_storage** (Keychain/Keystore) — 토큰 전용, 비번 미저장
- 라우팅: **go_router** (선언형 + 인증 리다이렉트 가드)
- 캘린더 UI: **table_calendar**
- i18n: **intl** (ko 기본)
- 웹뷰(향후 SAML): **webview_flutter** (v1 미사용, 심만 유지)

**스택 근거 요약**
- CORS: 내부 API가 `Access-Control-Allow-Origin: https://lms.kumoh.ac.kr`로 제한 → **웹 빌드 불가**, 네이티브(모바일)는 CORS 무관 → 모바일 타깃과 일치.
- dio 인터셉터가 관측된 `204/401 → /reissue → 재시도 + 큐잉` 패턴에 가장 잘 맞음.
- 데이터가 관계형·쿼리 중심("이번 주 마감 전체")이라 KV(Hive)보다 Drift(SQL+반응형)가 적합.

---

## 3. 아키텍처 — feature-first 레이어드

```
UI(위젯) → Riverpod Provider → Repository ──┬─→ Remote(dio API client)  ← lms:82/api/v1
                                            └─→ Local(Drift DAO)        ← SQLite(암호화) 캐시
```

- **data**: DTO(API JSON 미러) · Remote(도메인별 dio 클라이언트) · Local(Drift DAO) · **Repository**(remote+cache 조율, 오프라인-퍼스트). Repository가 내부 API 격리·교체 지점.
- **presentation**: Riverpod Notifier/Provider + 화면/위젯.
- 도메인 엔티티는 DTO→UI모델 매핑을 repository에서 처리하는 선까지만(과설계 회피).

---

## 4. 폴더 구조

```
lib/
  main.dart
  app.dart                         # MaterialApp.router, KIT 테마, ProviderScope
  core/
    config/env.dart                # lms:82 base, canvas host, accountId(기본 1), TTL 상수
    config/theme.dart              # KIT 테마(#00A9CE), 라이트/다크
    network/dio_client.dart        # dio 팩토리(Origin/Referer 헤더 포함)
    network/auth_interceptor.dart  # Bearer 부착 + 204/401→reissue→재시도 큐
    network/api_envelope.dart      # {code,message,data} 언랩 + code=="200" 판정
    storage/secure_store.dart      # 토큰 전용 (비번 미저장), DB 암호화 키 보관
    storage/db/app_database.dart   # Drift DB (SQLCipher)
    storage/db/tables.dart         # 테이블 정의(fetched_at 포함)
    storage/db/daos/*.dart         # courses/events/announcements DAO
    router/app_router.dart         # go_router + 인증 리다이렉트 가드
    error/failure.dart             # Network/Auth/Server(code)/Parse/CacheMiss
    utils/{date_x,logger}.dart
  features/
    auth/          data/{auth_api, auth_repository, dto/}           presentation/{auth_controller, login_screen}
    courses/       data/{courses_api, courses_repository, dto/}     presentation/{providers, course_list_screen, widgets/}
    assignments/   data/{calendar_api, assignments_repository, dto/} presentation/{providers, calendar_screen, list_screen, widgets/}
    announcements/ data/{announcements_api, announcements_repository, dto/} presentation/{providers, announcements_screen}
    shell/         home_shell.dart # 하단 탭: 강좌 / 과제 / 공지 / 설정
test/
  fixtures/                        # 정찰 때 캡처한 실제 JSON 샘플
  features/…                       # repository/interceptor/provider 테스트
```

세로 슬라이스(각 기능이 자기 data+presentation 소유) → 성적·출석·쪽지는 폴더 하나씩 추가로 확장.

---

## 5. 상태 관리 설계 (Riverpod)

**Provider 계층**
1. 인프라(싱글턴): `secureStoreProvider`, `appDatabaseProvider`, `dioProvider`(authInterceptor 포함)
2. 리포지토리: `authRepositoryProvider`, `coursesRepositoryProvider`, `assignmentsRepositoryProvider`, `announcementsRepositoryProvider`
3. **AuthController** (`AsyncNotifier<AuthState>`): `unauthenticated / authenticating / authenticated(profile) / error`.
   - 앱 시작: Secure Storage의 refreshToken으로 `/reissue` 시도 → 성공 시 세션 복원, 실패 시 unauthenticated.
   - `login(id,pw)` → repo 호출 → 토큰 저장 → 프로필 로드.
   - `logout()` → 토큰·DB 클리어.
   - `go_router`가 이 상태를 watch해 로그인 가드.
4. 읽기 모델(기능별):
   - `selectedTermProvider` = `StateProvider<int>` (기본 = 활성 학기, 2026-2 = id 8; 실제로는 terms에서 workflowState/기간으로 현재 학기 자동 선택)
   - `termsProvider` = 캐시-퍼스트 FutureProvider
   - `coursesProvider` = **StreamProvider**(Drift `watch(termId)`) + `refresh()` 액션
   - `dueSoonProvider` = N일 내 마감 과제 전체(강좌 교차)
   - `calendarEventsProvider.family(month)` = 월별 이벤트
   - `announcementsProvider.family(termId)`

**오프라인-퍼스트 패턴 (모든 repository 공통)**
```dart
Stream<List<Course>> watch(int termId) => dao.watch(termId);         // 캐시 즉시·반응형
Future<void> refresh(int termId, {bool force = false}) async {
  if (!force && _isFresh(termId)) return;                            // TTL 내 → 네트워크 스킵
  final dto = await api.getCourses(accountId: 1, termId: termId);    // GET /courses?...
  await dao.upsertAll(dto, fetchedAt: DateTime.now());               // → watch 스트림 자동 재방출
}
```
- UI는 **항상 캐시를 읽고**, 네트워크는 TTL과 당겨서 새로고침(pull-to-refresh)으로만 호출.
- **TTL**: 강좌 6h / 과제·캘린더 30m / 공지 30m / 학기·기관 24h.
- → "학교 서버 부하 방지 캐싱 기본 탑재" 요구 충족.

---

## 6. 인증 토큰 수명주기

- 로그인 → accessToken(1h) + refreshToken(~2h) → **둘 다 Secure Storage**, **비번 미저장**.
- `auth_interceptor.dart`:
  - onRequest: `Authorization: Bearer <access>` + **`X-Refresh-Token: <refresh>`** + `Origin: https://lms.kumoh.ac.kr` 부착.
  - onResponse/onError: **204(주 신호)/401(방어)** → `POST /reissue`(**`X-Refresh-Token` 헤더**) → accessToken·refreshToken **둘 다 회전·저장** → 원요청 재시도. 갱신 진행 중 동시요청은 큐에 모아 갱신 후 일괄 재개(`_retry` 가드로 무한루프 방지, `/reissue` 자체는 재발급 대상 제외).
  - 재발급 실패 → 세션 클리어 → AuthController → 로그인 화면.
- refreshToken(~2h) 만료 시 재로그인 필요.
- **자동 로그인 토글** = 포함하되 **기본 OFF**. ON일 때만 자격증명을 Secure Storage(Keychain)에 저장하고 refresh 만료 시 조용히 재로그인. 보안 트레이드오프를 설정 화면에 명시.

---

## 7. 에러 처리 & 보안

- API 봉투 `{code,message,data}`: `code=="200"`만 성공. 그 외 `ServerFailure(code,message)`로 매핑(예: `U004`, `A001`).
- 새로고침 실패 시 **캐시 유지 표시** + 비침습 스낵바("오프라인 데이터 표시 중"). 캐시 없을 때만 전체 화면 에러.
- **SQLCipher로 Drift 캐시 암호화**(키는 Secure Storage) → 강의명·과제 제목 등 학사 데이터까지 at-rest 보호.
- 트래픽은 `lms.kumoh.ac.kr:82` · `canvas.kumoh.ac.kr`로만. 외부 서버 전송·텔레메트리·서드파티 SDK 없음.
- 인증서 피닝: 학교 인증서 회전 시 앱이 깨질 위험 → **기본 OFF·문서화**만.

---

## 8. 테스트 전략

- 리포지토리: `http_mock_adapter`(dio) + 인메모리 Drift(`NativeDatabase.memory()`)로 오프라인-퍼스트·TTL 스킵·봉투 에러 매핑 검증.
- **인터셉터 TDD 최우선**: 204/401→reissue→재시도 성공, `/reissue` 제외, 동시요청 큐잉, 재발급 실패→세션 클리어. (가장 위험한 로직)
- Provider 테스트: `ProviderContainer` override.
- 위젯/골든(선택): course_card, 캘린더, due badge.
- 픽스처: 정찰 때 캡처한 실제 JSON(courses/calendar-events/terms/profile 샘플)을 `test/fixtures/`에 그대로 사용.

---

## 9. v1 범위 밖 (명시적 비목표)

- 쓰기 동작: 과제 제출, 출석 체크인, 쪽지 발송.
- 성적/출석/동영상강의(Panopto)/토론/퀴즈 조회.
- SAML 웹뷰 브릿지(딥 콘텐츠) — 아키텍처 심(seam)만 유지.
- 푸시 알림, 위젯, 웹 빌드.
- 다국어(ko 외).

이들은 모두 동일한 feature 폴더 패턴으로 이후 버전에서 추가.

---

## 10. 보안 주의사항 (레포 위생)

- 사용자 자격증명이 든 로컬 `env` 파일은 **절대 커밋 금지** → `.gitignore`에 등록됨.
- 정찰 중 획득한 live JWT/쿠키는 디스크에서 삭제 완료. 커밋되는 JSON 픽스처에는 토큰이 포함되지 않도록 확인.
