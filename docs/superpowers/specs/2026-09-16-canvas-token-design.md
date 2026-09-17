# Canvas 액세스 토큰 자동 발급 설계

작성일: 2026-09-16
범위: **안드로이드 먼저.** 웹앱(PWA) 적용은 "다음 단계"에 적었다.
선행 문서: [2026-09-05-kumoh-canvas-client-design.md](2026-09-05-kumoh-canvas-client-design.md)

## 배경

앱은 Canvas 데이터를 SAML 다리로 얻은 세션 쿠키(`_normandy_session`)로 조회한다. 이 다리는 학교가 IdP를 손댈 때마다 깨졌고(2026-09-08 A001 중단), 쿠키를 얻으려면 유효한 LINUS accessToken이 있어야 한다.

LINUS 토큰에는 더 큰 제약이 있다. **계정당 가장 최근에 발급된 refreshToken 하나만 유효하다**(2026-09-15~16 실계정 확인). 학교 홈페이지나 다른 기기에서 로그인하면 앱 세션이 끊긴다. 안드로이드 앱의 매시 자동 로그인은 반대로 다른 기기를 끊는다.

Canvas 개인 액세스 토큰은 이 둘과 무관하다. 만료가 없고, 로그인해도 죽지 않는다. 2026-09-16 실계정 실험에서 앱이 가진 SAML 경로만으로 발급까지 되는 것을 확인했다.

| 단계 | 결과 |
|---|---|
| LINUS 로그인 → SSO 주소 → SAML 폼 → ACS POST | Canvas 세션 획득 |
| 세션으로 `GET /api/v1/users/self` | HTTP 200 |
| `POST /api/v1/users/self/tokens` (`X-CSRF-Token` 필요) | HTTP 200, 토큰 64자, 만료 없음, 범위 `[]` |
| 발급 토큰으로 `GET /api/v1/courses` | HTTP 200 |
| `DELETE /api/v1/users/self/tokens/{id}` | HTTP 200 |

## 결정 요약

| 항목 | 결정 |
|---|---|
| 발급 시점 | 로그인 성공 직후, 백그라운드로 자동. 사용자에게 묻지 않는다 |
| 실패 시 | 조용히 기존 쿠키 방식으로 동작. 설정 화면에만 표시 |
| 토큰 이름 | 기기마다 다르게. `금오LMS 앱 · <플랫폼> · <임의 4자>` |
| 보관 | 기존 보안 저장소(`SecureTokenStore`와 같은 저장소) |
| 해지 | 로그아웃과 설정의 "연결 해제"에서 Canvas에서 삭제 |
| 범위 | 안드로이드. 웹앱은 다음 단계 |

## 무엇이 바뀌고 무엇이 남나

| 경로 | 지금 | 토큰 도입 후 |
|---|---|---|
| Canvas 조회(공지·과제·토론·자료·모듈) | SAML 쿠키 세션 | **토큰** |
| 파일 다운로드 | 쿠키 | **토큰** |
| 과제 제출·Panopto 등 화면 열기 | SAML 다리 | **그대로**(브라우저가 쿠키를 써야 한다) |
| LINUS 조회(강좌·학기·공지함·캘린더) | LINUS API | **그대로**(LINUS 탈출은 다음 조각) |
| 토큰 발급 | — | SAML 다리를 한 번 사용 |

조회가 쿠키에서 벗어나는 것이 이 조각의 목표다. LINUS 세션 충돌은 다음 조각에서 없앤다.

## 구성 요소

네 개로 나눈다. 각각 따로 테스트한다.

### `CanvasTokenApi` (`lib/features/canvas/data/canvas_token_api.dart`)

Canvas 세션으로 토큰을 만들고 지운다. CSRF 처리가 이 파일의 책임이다.

- `Future<IssuedCanvasToken> create(String purpose)` — `POST /api/v1/users/self/tokens`, 본문 `token[purpose]`. 응답에서 `id`와 `visible_token`을 읽는다.
- `Future<List<CanvasTokenSummary>> list()` — `GET /api/v1/users/self/tokens`. `id`와 `purpose`만 쓴다.
- `Future<void> delete(int id)` — `DELETE /api/v1/users/self/tokens/{id}`.
- 모든 쓰기 요청에 `X-CSRF-Token`을 붙인다. 값은 쿠키 자의 `_csrf_token`을 URL 디코딩한 것이다. 쿠키가 없으면 `CanvasTokenUnavailable`을 던진다.

`visible_token`은 생성 응답에만 들어 있다. 목록에서는 다시 볼 수 없다.

### `CanvasTokenStore` (`lib/features/canvas/data/canvas_token_store.dart`)

`token`(문자열), `id`(정수), `purpose`(문자열)를 저장·삭제한다. 저장소는 `SecureTokenStore`가 쓰는 `FlutterSecureStorage`를 그대로 쓴다. 키 앞머리는 `canvas_pat_`.

### `CanvasTokenService` (`lib/features/canvas/data/canvas_token_service.dart`)

상태 기계 하나다. 다른 코드가 보는 표면은 두 개뿐이다.

- `Future<String?> current()` — 저장된 토큰. 없으면 `null`.
- `Future<String?> ensure()` — 없으면 발급을 시도하고 결과를 돌려준다. 실패하면 `null`.
- `Future<void> revoke()` — Canvas에서 삭제하고 로컬도 지운다. 삭제 실패해도 로컬은 지운다.
- `Future<String?> reissueAfterInvalid()` — 저장된 토큰을 버리고 한 번만 다시 발급한다.

발급 절차: SAML 다리로 Canvas 세션 확보 → 같은 `purpose`의 남은 토큰이 있으면 삭제 → `create()` → 저장.

### `canvas_client` 변경

요청을 보내기 전에 `CanvasTokenService.current()`를 확인한다.

- 토큰이 있으면 `Authorization: Bearer <토큰>`을 붙이고 **SAML 다리를 건너뛴다**.
- 없으면 지금 경로 그대로다.

## 발급 흐름

1. 로그인 성공. 화면은 기다리지 않는다. 발급은 백그라운드에서 시작한다
2. `CanvasTokenService.ensure()`
3. SAML 다리 → Canvas 세션 → `_csrf_token`
4. 같은 `purpose`의 토큰이 Canvas에 남아 있으면 삭제한다. 값을 다시 볼 수 없으므로 재사용할 수 없다(재설치·기기 분실 뒤에 쓰레기 토큰이 쌓이는 것을 막는다)
5. `create(purpose)` → `{id, visible_token}` 저장
6. 어느 단계에서든 실패하면 아무것도 저장하지 않고 끝낸다. 사용자에게 오류를 보여주지 않는다

`purpose`는 기기마다 고정이다. 최초 1회 만들어 저장한다: `금오LMS 앱 · Android · <임의 4자>`. 임의 4자는 `Random.secure()`로 만든다.

## 무효 감지와 해지

| 상황 | 동작 |
|---|---|
| Canvas 조회가 401 | 저장된 토큰을 버리고 `reissueAfterInvalid()`를 **요청당 한 번만** 시도. 성공하면 원요청 재시도 |
| 재발급도 실패 | 쿠키 방식으로 폴백. 다음 로그인 때 다시 시도 |
| 앱 로그아웃 | `revoke()`. Canvas 삭제에 실패해도 로컬은 지운다 |
| 설정의 "연결 해제" | `revoke()`. "다시 연결" 버튼으로 `ensure()` |
| 사용자가 Canvas 설정에서 직접 삭제 | 다음 조회가 401 → 자동 재발급 |

재시도 루프는 요청 `extra`에 표시를 남겨 막는다. `AuthInterceptor`가 재발급 루프를 막는 방식과 같다.

## 설정 화면

`설정 → Canvas 연결`

- 상태: `토큰으로 연결됨 (2026-09-16 발급)` 또는 `쿠키 방식으로 연결됨`
- 버튼: `연결 해제`, `다시 연결`
- 안내 한 줄과 `docs/canvas-token.md` 링크

## 보안과 투명성

- 토큰의 범위는 `[]`, 곧 **Canvas 계정 전체 권한**이다. 조회뿐 아니라 과제 제출·수정도 가능한 권한이다. 앱은 조회에만 쓰지만, 설정 화면과 문서에 이 사실을 그대로 적는다
- 토큰 값은 로그·오류 보고·분석에 남기지 않는다. 기존 마스킹 규칙을 따른다
- 토큰 이름에 기기 표시를 넣어, 사용자가 Canvas 설정(`/profile/settings`)에서 구분해 지울 수 있게 한다
- `docs/canvas-token.md`: 무엇을 만드는지, 권한 범위, 저장 위치, 해지 방법, 자동 발급이 실패해도 앱이 동작한다는 점

## 테스트

- **`CanvasTokenApi`**: 가짜 Canvas 서버로 생성(`X-CSRF-Token` 부착 확인), `_csrf_token` 쿠키가 없을 때 예외, 목록, 삭제, 403 처리
- **`CanvasTokenService`**: 없음→발급, 이미 있음→그대로, 같은 이름 토큰 삭제 후 발급, 발급 실패→`null`, 401→한 번만 재발급, `revoke()`가 삭제 실패에도 로컬을 지우는지
- **`canvas_client`**: 토큰이 있으면 `Bearer`를 붙이고 SAML 다리를 부르지 않는지, 없으면 기존 경로 그대로인지, 401 재시도가 한 번인지
- **설정 위젯**: 두 상태 표시, 해제·재연결 버튼 동작
- **실기기(안드로이드)**: 로그인 후 Canvas 설정에 토큰이 생긴다 / 앱을 껐다 켜도 재발급 없이 조회된다 / Canvas에서 지우면 다음 조회에서 자동 복구된다 / 로그아웃하면 Canvas에서 사라진다 / 발급을 막은 상태(비행기 모드로 발급 단계만 실패)에서도 앱이 동작한다

## 다음 단계 (이 문서 범위 밖)

1. **웹앱 적용** — 기기별 별도 토큰을 브라우저 저장소에 둔다. 브라우저 저장소는 기기 보안 저장소보다 약하므로 안내가 필요하다
2. **LINUS 의존 제거** — 강좌·학기·공지함·캘린더를 Canvas API로 옮기면 로그인 이후 LINUS를 쓰지 않게 되어 세션 충돌이 사라진다
3. **알림 서버** — 동의한 사용자의 토큰으로 서버가 폴링해 iOS Web Push를 보낸다. 비밀번호를 보관하지 않는다
