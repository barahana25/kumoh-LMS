# PWA 선택 동의 알림 서버 설계 (3단계)

작성일: 2026-09-15
상태: **폐기 (2026-09-15).** 후속 실험에서 학교 서버가 계정당 가장 최근에 발급된 refreshToken 하나만 인정한다는 것이 확인됐다. 서버가 세션을 유지하면 사용자의 기기 세션과 서로 끊으므로 이 설계는 성립하지 않는다. 비밀번호 보관도 서버 로그인마다 기기 세션을 끊어 같은 문제가 있다. 방향은 "재발급 버그 수정 → 앱을 열 때 새 소식 표시"로 바뀌었다. 아래 내용은 기록으로 남긴다.

## 폐기 사유가 된 실험 (2026-09-15 17:30)

| 실험 (로그인 간격 2초) | 결과 |
|---|---|
| P 로그인 → Q 로그인 → P 재발급 | 401 `T001` |
| Q 재발급 | 200 |
| Q 재발급(Q2) → Q2 재발급(Q3) → 처음 Q로 재발급 | 401 `T001` |
| 50분 뒤 회전(그 사이 다른 로그인 있음) | 401 `T001` |

아래 "토큰 실험 결과"의 "로그인 두 번은 서로 영향이 없다", "재발급 후 이전 토큰도 쓸 수 있다"는 두 요청이 같은 초에 발급돼 구분되지 않은 결과로, 틀렸다.
선행 문서: [2026-09-14-pwa-blind-relay-design.md](2026-09-14-pwa-blind-relay-design.md)

## 배경

iOS 웹앱은 백그라운드에서 실행할 수 없고, 푸시로 깨운 뒤 기기에서 조회하는 방식도 막혀 있다(Safari는 푸시마다 알림 표시를 강제한다). Canvas Student 공식 앱은 금오공대를 지원하지 않는다(Instructure 학교 검색 0건, 학교가 직접 설치한 Canvas). 그래서 **알림을 켠 사용자에 한해** NAS의 알림 서버가 학교 서버를 대신 조회하고 Web Push로 알린다.

이 기능은 블라인드 중계의 약속("운영자는 내용을 볼 수 없다")을 켠 사람에 대해서만 깨뜨린다. 그래서 동의, 최소 보관, 분리된 컨테이너, 공개 코드를 전제로 한다.

## 결정 요약

| 항목 | 결정 |
|---|---|
| 대상 | 누구나(공개 웹앱). 켠 사람만 서버에 등록 |
| 서버가 받는 자격 | **토큰만**(accessToken·refreshToken). 비밀번호는 서버로 보내지 않는다 |
| 알림 범위·일정 | 안드로이드와 같다. 공지·과제·토론·강의자료, 08:01~00:01 KST 매시 |
| 푸시 내용 | 강좌명 + 글 제목. 서버는 제목을 저장하지 않는다 |
| 구현 | 별도 Node 컨테이너 `notifier/`. 중계 서버(`relay/`)는 바꾸지 않는다 |

## 토큰 실험 결과 (2026-09-15, 실계정)

| 확인 | 결과 |
|---|---|
| 수명 | accessToken 60분, refreshToken 120분 |
| 재발급 요청 | `X-Refresh-Token`만 보내면 401 `T003`. **`Authorization: Bearer <accessToken>`을 함께 보내야** 200 |
| 로그인 두 번 | 두 세션은 서로 영향이 없다 |
| 재발급 후 이전 토큰 | 계속 쓸 수 있다(서버가 회전을 추적하지 않는다) |
| 한 세션에서 `/logout` | **같은 계정의 모든 세션**이 재발급 불가(`T001`). 이미 발급된 accessToken은 만료 전까지 동작 |
| 로그아웃 뒤 새 로그인 | 정상 |

설계에 반영한 결론:
- 앱이 현재 세션을 한 번 재발급해 얻은 토큰 쌍을 서버에 넘기면, 비밀번호 재입력 없이 서버 전용 세션이 생긴다.
- 서버는 accessToken 만료 전에 회전해야 한다(50분 간격).
- 사용자가 어느 기기에서든 로그아웃하면 서버 세션도 끊긴다. 서버는 이를 감지해 알리고 기록을 지운다.
- 서버는 알림 해제 때 학교에 `/logout`을 보내면 안 된다.

### 미확정 (배경 실험 진행 중)

1. 50분 간격 회전이 로그인 후 7시간 넘게 이어지는지(절대 한도 여부). 한도가 있으면 "알림이 멈췄어요" 흐름이 그 주기로 발생하므로 동의 화면에 주기를 적는다.
2. accessToken이 만료된 뒤에도 재발급되는지(75분 간격 실험). 안 되면 서버 다운 시 복구 여유가 60분으로 줄어든다.
3. 앱의 `AuthApi.reissue`는 `X-Refresh-Token`만 보낸다. accessToken 만료 뒤에도 이 방식이 거부되면 앱·PWA 모두 1시간마다 세션이 풀리는 별도 버그이며, 알림과 별개로 고친다.

## 구조

```
[iPhone 웹앱] ══ 블라인드 터널 ══▶ relay (변경 없음) ══▶ 학교 서버
      │
      └── HTTPS (켜기·끄기·상태) ──▶ notifier ── 매시 조회 ──▶ 학교 서버
                                        └── Web Push ──▶ Apple 푸시 서버 ──▶ iPhone
```

- `notifier`는 `relay`와 다른 컨테이너·다른 포트다. 중계 이미지는 계속 자격 증명을 다루지 않는다.
- notifier는 학교 서버에 NAS에서 직접 접속한다(중계를 거치지 않는다).

## 알림 켜기·끄기 흐름

### 켜기 (홈 화면에 추가한 웹앱에서만)

1. 설정 → "새 소식 알림 (서버 확인)" 스위치를 켜면 동의 화면을 연다. 내용은 `docs/pwa/notifier-privacy.md`와 같다.
2. 동의하면 `Notification.requestPermission()` → `PushManager.subscribe({userVisibleOnly: true, applicationServerKey: <VAPID 공개키>})`.
3. 앱이 터널로 `/reissue`를 불러 새 토큰 쌍을 받는다(현재 앱 세션은 그대로 유지된다).
4. `POST {NOTIFIER_URL}/registrations` 본문 `{accessToken, refreshToken, subscription}`.
5. 서버는 토큰으로 `/user/profile`을 불러 유효성을 확인하고, 응답 `{id, deleteSecret}`를 준다. 앱은 둘을 localStorage에 둔다.
6. 서버는 첫 조회에서 현재 글을 기준점으로만 저장하고 알리지 않는다.

### 끄기

- 앱이 `DELETE {NOTIFIER_URL}/registrations/{id}` + `Authorization: Bearer <deleteSecret>`. 서버는 그 기기를 즉시 지우고, 계정에 남은 기기가 없으면 토큰·본 글 기록까지 지운다. 학교 서버에는 아무 요청도 보내지 않는다.
- 앱은 `PushSubscription.unsubscribe()`도 호출하고 localStorage의 등록 정보를 지운다.

### 상태 조회

- `GET {NOTIFIER_URL}/registrations/{id}` + 같은 삭제용 비밀 값 → `{lastSuccessAt, lastFailure}`. 설정 화면에 "마지막 확인 13:01" 또는 "확인 실패"로 보여 준다.

### 웹앱 로그아웃

- 알림이 켜져 있으면 "로그아웃하면 알림도 멈춰요" 확인을 받는다. 로그아웃하면 끄기 요청을 먼저 보내고 학교 로그아웃을 진행한다.

## 서버 보관

SQLite 파일 하나(`/data/notifier.sqlite`, 컨테이너 볼륨).

| 테이블 | 열 | 보관 방식 |
|---|---|---|
| `accounts` | `account_key` | `HMAC-SHA256(HMAC_KEY, loginId)`. 학번 원문은 저장하지 않는다 |
| | `tokens` | `{accessToken, refreshToken}` JSON을 AES-256-GCM 암호화 |
| | `slot_minute` | 1~30. `account_key`에서 결정적으로 계산 |
| | `last_success_at`, `last_failure` | 상태 표시용 |
| `devices` | `id` | 무작위 128비트 |
| | `account_key` | 위 계정 |
| | `delete_secret_hash` | SHA-256 |
| | `subscription` | 푸시 구독 JSON을 AES-256-GCM 암호화 |
| `seen_items` | `account_key, course_id, kind, item_id` | 숫자 ID만 |
| `baselines` | `account_key, course_id, kind` | 기준점 저장 여부 |

- 글 제목·강좌명·본문은 저장하지 않는다. 조회 중 메모리에서만 쓰고 푸시 본문에 넣는다.
- 암호화 키(`TOKEN_KEY`), HMAC 키(`HMAC_KEY`), VAPID 키 쌍은 NAS의 비밀 파일로 주입한다. 저장소에 올리지 않는다.
- 키가 같은 NAS에 있으므로 암호화는 운영자로부터 보호하지 않는다. 디스크·백업만 유출된 경우를 막는다. 동의 화면에 그대로 적는다.

## 조회와 회전

| 작업 | 주기 | 내용 |
|---|---|---|
| 토큰 회전 | 50분마다, 24시간 | `/reissue`(Bearer + X-Refresh-Token) → 새 쌍 저장 |
| 새 글 확인 | 08:01~00:01 KST 매시, 계정별 `slot_minute`에 | 학기 → 강좌 → 종류별 목록 → 기준점 비교 → 새 글 푸시 |

- 동시 조회 계정 수 상한 4.
- 조회 로직은 안드로이드 `LmsNotificationSource`와 같은 규칙을 JS로 옮긴다.
  - 현재 학기 선택(시작·종료 사이, 없으면 가장 최근), 강좌 목록(LINUS)
  - Canvas 연결: `redirect.do` → `_linus_saml_login` 쿠키(accessToken) → IdP 폼 → ACS POST → `_normandy_session`
  - 종류별 목록: 공지(`discussion_topics?only_announcements=true`), 토론(`only_announcements=false`, 강의자 글만), 과제(`assignments`), 자료(`files`)
  - 페이지 넘김: `Link rel=next`는 같은 scheme·host·port·path만, 방문 중복 금지, 최대 100쪽
  - 제외: 미게시, `locked_for_user`, `hidden_for_user`, 토론 목록의 공지
- 한 계정 안에서 처음 보는 강좌·종류는 기준점만 저장한다.
- 한 번에 푸시할 새 글이 5건을 넘으면 "새 소식 N건" 한 건으로 묶는다.

## 실패 처리

| 상황 | 동작 |
|---|---|
| `/reissue`가 401(`T001` 등) | 계정의 모든 기기에 "알림이 멈췄어요. 앱에서 다시 켜 주세요" 푸시 1회 → 계정 기록 삭제 |
| 조회 중 401/204가 계속됨 | 회전 1회 후 재시도, 그래도 실패면 위와 같다 |
| 학교 서버 5xx·네트워크 오류·파싱 실패 | `last_failure` 기록, 다음 회차 재시도 |
| 푸시 404·410 | 해당 기기 삭제. 기기가 0이면 계정 삭제 |
| 서버 중단으로 refresh 만료 | `/reissue` 401과 같다 |

## 남용 방지와 로그

- 계정 수 상한 `NOTIFIER_MAX_ACCOUNTS`(기본 300). 넘으면 등록 503과 "지금은 알림 등록 인원이 가득 찼어요".
- 등록 요청은 IP당 10분에 5회. IP는 메모리 집계에만 쓰고 저장·로그하지 않는다.
- CORS·Origin은 `https://barahana25.github.io`만 허용.
- 로그는 회차별 집계만: `accounts=12 new=3 failures=1 pushes=3`. 토큰·학번·계정 키·제목·IP·푸시 주소를 남기지 않는다(relay의 `log_redaction.mjs` 재사용).

## 웹앱

- `web/push_sw.js`: `push` 이벤트에서 알림 표시, `notificationclick`에서 푸시에 담긴 앱 내부 경로를 연다. 새 글 한 건은 안드로이드 알림과 같은 `/kumoh-LMS/#/courses/{id}?tab={announcements|files|assignments|discussions}`, 묶음 알림은 `/kumoh-LMS/#/announcements`, "멈췄어요"는 `/kumoh-LMS/#/settings`. `/kumoh-LMS/`로 시작하지 않는 경로는 무시한다. 스코프 `/kumoh-LMS/`.
- 설정 화면: 웹에서만 "새 소식 알림 (서버 확인)" 영역. 스위치, 동의 화면, 상태, 끄기. 기존 `settings_widgets` 스타일.
- 홈 화면에 추가하지 않은 Safari(`display-mode: standalone` 아님) 또는 `PushManager` 없음: 스위치 대신 "홈 화면에 추가한 뒤 켤 수 있어요" 안내.
- `NOTIFIER_URL`은 `--dart-define`으로 넣는다(`RELAY_URL`과 같은 방식, `pwa.yml`에 `vars.NOTIFIER_URL` 검사 추가). 비어 있으면 영역을 숨긴다.
- VAPID 공개키는 `GET {NOTIFIER_URL}/vapid-public-key`로 받는다.

## 배포

- `notifier/`: `package.json`, `src/`, `test/`, `Dockerfile`(node:24-bookworm-slim), `compose.yaml`(`127.0.0.1:18081:8080`, 볼륨 `/data`, 비밀 파일 마운트, `read_only`, `cap_drop: ALL`).
- `.github/workflows/notifier-image.yml`: 테스트 후 GHCR `kumoh-lms-notifier` 이미지. compose는 digest로 고정.
- DSM 리버스 프록시: `https://barahana.synology.me:8444` → `http://localhost:18081`, Let's Encrypt 인증서 지정, 공유기 TCP 8444 포워딩.
- `notifier/README.md`: 비밀 파일 만들기(VAPID 키 생성 명령 포함), 배포, 백업 시 주의.

## 투명성

- `docs/pwa/notifier-privacy.md`: 보관 항목, 보관하지 않는 항목, 암호화 키의 한계, 운영자가 볼 수 있는 것(토큰으로 가능한 모든 조회, 푸시 시점의 제목), 삭제 방식, 로그아웃 시 동작. 동의 화면 문구의 원본이며 앱에서 링크한다.
- 서버 코드 공개, 이미지 digest 고정, 로그 정책 문서화.

## 테스트

- **규칙 일치**: 안드로이드 테스트의 목록 예시를 `test/fixtures/notifications/*.json`으로 옮기고, Dart 테스트와 `notifier/test`가 같은 파일로 같은 결과(`WatchedItem` ID 목록)를 확인한다.
- **Node 단위**(`node:test`): 암호화 왕복·변조 거부, `slot_minute` 분포, 일정(가짜 시계: 00:01 뒤 08:01, 회전 50분), 기준점, 5건 초과 묶음, 실패 표(가짜 학교 서버의 `T001`·5xx·페이지 주소 조작, 가짜 푸시의 410), 로그에 비밀 값이 없는지.
- **HTTP**: 등록 검증(잘못된 구독·토큰 거부), 삭제 비밀 불일치 403, Origin 거부, 인원 상한 503, 요청 제한 429.
- **Flutter 위젯**: 웹 조건에서 영역 표시/숨김, 홈 화면 미추가 안내, 동의 화면, 로그아웃 경고.
- **실기기**: `docs/pwa/verification.md`에 켜기, 새 글 푸시, 탭하면 공지 탭, 끄기 후 푸시 없음, 다른 기기 로그아웃 뒤 "멈췄어요" 푸시 항목 추가.

## 범위 밖

알림 종류별 선택, 조용한 시간 설정, 안드로이드 PWA 최적화, 토큰 외 자격 증명 보관.
