# 강좌 상세 탭 (Canvas 연동) — 설계 문서

- 작성일: 2026-09-06
- 상태: 정찰 검증 완료, 구현 착수
- 전제: v1(로그인·강좌·과제·공지)은 완료되어 `feat/v1-client`에 커밋됨

---

## 1. 배경

강좌를 눌렀을 때 `canvas.kumoh.ac.kr`가 제공하는 탭(홈·과제·토론·성적·사용자 및 그룹·강의자료실·강의 계획·강의실)을 앱에서 지원한다.

**핵심 제약:** LINUS API(`lms.kumoh.ac.kr:82`)에는 이 탭들에 해당하는 엔드포인트가 **없다.** 캐시된 웹 번들의 엔드포인트를 전수 조사한 결과 강좌 관련은 `GET /course?courseId=` 하나뿐이다. 웹에서도 이 화면들은 Canvas로 직접 넘어가며, LINUS는 SAML 다리 역할만 한다.

→ **Canvas REST API를 직접 호출한다.**

## 2. Canvas 세션 브릿지 (실측 검증 완료)

curl로 끝까지 재현해 Canvas 세션과 API 접근을 확인했다.

1. LINUS 로그인 → `accessToken` / `refreshToken`
2. `GET /user/profile` → `loginId`(학번)
3. **`.kumoh.ac.kr` 도메인에 쿠키 심기**
   - `_linus_saml_login = <loginId>`
   - `_linus_saml_domain = <relayState>`
   이 쿠키가 없으면 IdP가 `A001 SSO 연동 ID가 존재하지 않습니다`로 거부한다.
4. `GET lms:82/api/v1/saml/redirect.do?relayState=/courses` → `https://canvas.kumoh.ac.kr/login/saml?RelayState=...` 문자열 반환
5. 그 URL을 따라가면 IdP가 **자동 제출 HTML 폼**을 돌려준다
   (`action=https://canvas.kumoh.ac.kr/login/saml`, hidden `SAMLResponse`, `RelayState`).
   브라우저는 JS로 제출하지만, 클라이언트는 **폼을 파싱해 직접 POST**해야 한다.
6. `POST https://canvas.kumoh.ac.kr/login/saml` (SAMLResponse + RelayState)
   → `302 → /courses`, 쿠키 `_normandy_session`, `_legacy_normandy_session` 획득
7. 이후 `https://canvas.kumoh.ac.kr/api/v1/*` 를 **세션 쿠키만으로** 호출 가능

검증: `GET /api/v1/users/self` → 200, `GET /api/v1/courses` → 200 (5건).

## 3. 검증된 탭별 엔드포인트

`GET /api/v1/courses/:id/tabs` 가 그 강좌의 실제 탭 목록을 돌려준다. 실측 결과 요청받은 탭과 정확히 일치했다:

| tab id | 라벨 | 데이터 엔드포인트 | 실측 |
|---|---|---|---|
| `home` | 홈 | `/courses/:id` + `modules` | 200 |
| `assignments` | 과제 | `/courses/:id/assignments` | 200 |
| `discussions` | 토론 | `/courses/:id/discussion_topics` | 200 |
| `grades` | 성적 | `/users/self/enrollments` (grades 포함) + `/courses/:id/students/submissions` | 200 |
| `people` | 사용자 및 그룹 | `/courses/:id/enrollments`, `/courses/:id/groups` | 200 |
| `files` | 강의자료실 | `/courses/:id/files`, `/courses/:id/folders` | 200 |
| `syllabus` | 강의 계획 | `/courses/:id?include[]=syllabus_body` | 200 (10,220자) |
| `modules` | 강의실 | `/courses/:id/modules` | 200 |

`/courses/:id/pages` 는 404 — 이 강좌가 위키를 끄고 있어서다. **탭 목록을 하드코딩하지 않고 `/tabs`로 받아 렌더링**하면 강좌마다 다른 구성에 자동으로 맞는다.

> 주의: `/tabs`에는 `context_external_tool_7`(콘텐츠제작) 같은 외부 도구 탭도 섞여 있다. 네이티브로 표현할 수 없으므로 웹뷰로 열거나 숨긴다.

## 4. 아키텍처

기존 v1 구조를 그대로 확장한다: `UI → Riverpod → Repository → {dio, Drift 캐시}`.

**추가되는 것**
- `CanvasSession`: SAML 브릿지를 수행하고 세션 쿠키를 보유. 만료 시 재브릿지.
- `canvasDioProvider`: `canvas.kumoh.ac.kr` 전용 dio. 쿠키 매니저 + 세션 만료 시 재브릿지 인터셉터.
- 탭별 리포지토리 + Drift 테이블(오프라인 캐시, TTL).
- `CourseDetailScreen`: `/tabs`로 받은 탭을 동적 렌더링.

**유지되는 원칙 (v1과 동일)**
- 화면은 항상 캐시를 먼저 읽는다. 실패한 새로고침은 캐시를 지우지 않고 배너로만 알린다.
- TTL로 학교 서버 부하를 억제한다.
- 자격증명·세션은 기기 밖으로 나가지 않는다.
- 사용자에게 raw 예외를 노출하지 않는다(`userMessage`).

## 5. 구현 순서

1. **Canvas 세션 브릿지** — 나머지 전부의 전제. 가장 위험하므로 먼저, 테스트와 함께.
2. **탭 목록 + 강좌 상세 셸** — `/tabs` 기반 동적 탭.
3. 탭별 구현: 과제 → 강의계획 → 강의실(모듈) → 자료실 → 성적 → 토론 → 사용자/그룹 → 홈.

각 단계는 오프라인 캐시·테스트를 포함해 독립적으로 동작해야 한다.

## 6. 비목표

- 쓰기 동작(과제 제출, 토론 작성, 파일 업로드).
- 외부 도구 탭(콘텐츠제작 등)의 네이티브 구현 — 웹뷰로 위임.
- Canvas 알림/실시간 갱신.
