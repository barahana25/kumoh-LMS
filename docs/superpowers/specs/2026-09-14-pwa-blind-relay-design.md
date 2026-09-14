# iOS용 PWA와 블라인드 중계 서버 설계

작성일: 2026-09-14
상태: 1단계 설계 확정, 2·3단계는 방향만 확정

## 배경

- iOS 네이티브 배포는 유료 Apple Developer 계정이 필요하다. 무료 사이드로딩(AltStore)은 7일 재서명과 3앱 제한으로 일반 학생 배포에 맞지 않는다.
- PWA에서 학교 서버를 직접 호출할 수 없다. 2026-09-14 확인 결과:
  - `lms.kumoh.ac.kr:82`는 외부 Origin의 CORS preflight를 403으로 거부한다.
  - `canvas.kumoh.ac.kr`는 CORS 허용 헤더를 보내지 않는다.
  - 앱은 `Origin` 헤더 지정, `.kumoh.ac.kr` 쿠키 주입, 리다이렉트 수동 추적에 의존하는데 브라우저는 셋 다 허용하지 않는다.
- 따라서 중계 서버가 필요하다. 서버는 운영자 NAS(로컬)에서 돌리므로 원격 증명이 불가능하다. 운영자를 믿지 않아도 되게 만드는 것이 목표다.

## 결정 요약

| 항목 | 결정 |
|---|---|
| 데이터 경로 | 블라인드 터널: 브라우저 안의 libcurl.js(WASM)가 학교 서버와 TLS를 직접 맺는다. 중계 서버는 암호문 TCP 바이트만 전달한다 |
| 중계 서버 | wisp-js 서버, Synology NAS의 Container Manager(x86)에서 실행 |
| 공개 주소 | Synology DDNS(`*.synology.me`) + Let's Encrypt + DSM 리버스 프록시 |
| PWA 호스팅 | GitHub Pages, 공개 저장소의 GitHub Actions로만 배포 |
| 알림 | 선택 동의한 사용자만 서버에 자격증명을 맡기고 서버가 조회해 웹 푸시한다(3단계) |

iOS PWA는 백그라운드 실행 API(Background Sync, Periodic Sync, Background Fetch)가 없다. 푸시로 깨워 기기에서 조회하는 방식도 Safari가 푸시마다 알림 표시를 강제해서(`userVisibleOnly`) 쓸 수 없다. 그래서 알림만은 서버 조회로 분리한다.

## 단계 분할

1. **블라인드 터널 + PWA 본체** — 이 문서의 상세 범위
2. **투명성 장치** — 공개 CI 이미지 서명(attestation), `/version`과 앱의 커밋 SHA 표시, 로그 정책 문서, 사용자가 개발자 도구로 암호문만 오가는지 확인하는 방법 안내
3. **선택 동의 알림** — 동의 화면, 서버 측 자격증명 보관, 정시 조회, 웹 푸시

각 단계는 별도 스펙·계획·구현 주기를 가진다.

---

## 1단계 상세

### 구조

```
iPhone 홈 화면 PWA (https://barahana25.github.io/kumoh-LMS/)
 │  Flutter web + libcurl.js(WASM): 학교 서버 TLS 종단이 브라우저 안에 있다
 │
 └─ wss://<이름>.synology.me  (DSM 리버스 프록시, Let's Encrypt)
      └─ [Container Manager] wisp-js 서버
           └─ TCP 전달 ─▶ lms.kumoh.ac.kr:82, lms.kumoh.ac.kr:443, canvas.kumoh.ac.kr:443
```

DSM 리버스 프록시는 바깥 WebSocket의 TLS만 종단한다. 안쪽 학교 서버 TLS는 브라우저에서 종단하므로 NAS와 운영자는 암호문만 본다.

### 중계 서버 (`relay/`)

- wisp-js(LGPL-3.0) 서버 모드. 직접 작성하는 코드는 설정과 진입점 수십 줄로 제한한다.
- 설정:
  - `hostname_whitelist`: `^lms\.kumoh\.ac\.kr$`, `^canvas\.kumoh\.ac\.kr$`
  - `port_whitelist`: 82, 443
  - `allow_private_ips: false`, `allow_udp_streams: false` — 집 내부망과 NAS 자신으로의 접근 차단
  - `stream_limit_total`: WebSocket 연결당 동시 스트림 상한
- WebSocket 업그레이드 시 `Origin`이 PWA 주소(`https://barahana25.github.io`)가 아니면 거부한다. 다른 사이트의 무단 사용 방지 목적이며 보안 경계는 아니다.
- 로그: 연결 시각, 대상 호스트:포트, 전송 바이트만. 로그 수준은 설정 파일에 고정한다.
- 산출물: `Dockerfile`, `compose.yaml`, `relay/README.md`(DDNS·인증서·리버스 프록시 WebSocket 헤더·공유기 443 포워딩 안내, DSM 관리 포트 5000/5001 외부 비공개).
- 이미지는 공개 CI에서 빌드해 GHCR에 올리고 NAS는 digest로 고정한다. 서명은 2단계.

### PWA 배포

- Flutter `web` 플랫폼 추가.
- `.github/workflows/pwa.yml`: `main` push 시 `flutter build web --base-href /kumoh-LMS/ --dart-define=RELAY_URL=wss://...` 후 GitHub Pages에 배포. Flutter 3.47.2 고정.
- libcurl.js와 WASM은 `web/`에 포함해 Pages에서 직접 제공한다. CDN을 쓰지 않는다(제공 코드가 저장소와 같다는 대조 가능성 유지).
- `manifest.json`, 아이콘, `apple-touch-icon`, `display: standalone`. Safari에서 처음 열면 "공유 → 홈 화면에 추가" 안내를 보여준다.

### 앱 변경

원칙: 모바일 코드 경로는 바꾸지 않는다. 웹 차이는 조건부 import로 격리한다.

**네트워크 — `LibcurlHttpClientAdapter` (웹 전용)**

- Dio `HttpClientAdapter` 구현. `dart:js_interop`으로 libcurl.js fetch를 호출한다.
- Dio 생성 지점은 `lib/core/network/dio_client.dart`와 `buildCanvasDio` 두 곳이다. 여기서 플랫폼별 어댑터를 붙인다.
- libcurl.js의 쿠키 기능은 끈다. 쿠키는 기존처럼 Dart `CookieJar`가 관리한다.
- 리다이렉트는 따라가지 않는다. `Set-Cookie`, `Location`을 포함한 원본 응답 헤더를 Dio에 그대로 넘긴다. 그래서 `CanvasSession`의 SAML 브리지를 수정 없이 재사용한다.
- `Origin`, `Referer`는 curl이 보내므로 현재 설정 그대로 동작한다.

**저장소**

- DB: 웹은 drift `WasmDatabase`(sqlite3.wasm, OPFS 또는 IndexedDB). 암호화 없음. 캐시 데이터만 들어간다. GitHub Pages는 COOP/COEP 헤더를 줄 수 없으므로 drift가 고르는 대체 저장소를 허용한다.
- 토큰: 웹 `flutter_secure_storage`는 실질적 보호가 없으므로 **웹에서는 비밀번호를 저장하지 않는다**(`saveCredentials` 무동작). refresh token으로 세션을 유지하고 만료되면 재로그인한다.

**웹에서 제외·대체하는 기능**

| 기능 | 웹 동작 |
|---|---|
| 알림, 백그라운드 실행 설정, 폴더 자동 다운로드 | 설정 화면에서 숨김 |
| 파일 열기(`open_filex`) | 터널로 받은 바이트를 Blob URL로 새 탭에 연다 |
| 내장 WebView(`canvas_web_screen`) | 아래 "로그인된 원문 열기" |
| `dart:io` `Platform.is*` | 웹에서 예외가 난다. `kIsWeb`, `defaultTargetPlatform`으로 교체 |

**로그인된 원문 열기 (웹)**

브라우저는 `.kumoh.ac.kr` 쿠키를 만들 수 없다. 대신 SAML HTTP-POST 바인딩의 마지막 단계를 브라우저에 맡긴다.

1. 사용자가 링크를 누르는 즉시(사용자 제스처 안에서) "연결 중" 창을 연다.
2. 터널로 기존 브리지를 진행한다: `_linus_saml_login`=accessToken 쿠키로 IdP에 요청해 SAML 폼(`action`, `SAMLResponse`, `RelayState`)을 받는다.
3. Dio로 POST하지 않고, 1의 창에 자동 제출 폼을 채워 브라우저가 Canvas ACS로 직접 POST한다.
4. Canvas가 브라우저에 `_normandy_session`을 발급하고 RelayState 페이지로 보낸다.

`SAMLResponse`는 1회용이고 짧게 만료되므로 열 때마다 새로 받는다. 스파이크에서 실패하면(아래 위험 1·2) 새 탭으로 원문을 열고 "학교 사이트 로그인이 필요할 수 있다"고 안내하는 방식으로 대체한다.

### 오류 처리

- 중계 서버 연결 불가: 캐시 표시 + "중계 서버에 연결할 수 없습니다" 배너(기존 새로고침 실패 배너 재사용).
- 중계 서버의 연결 거부(허용 목록 밖): 어댑터가 `NetworkFailure`로 변환해 기존 흐름을 따른다.
- 원문 열기 창이 차단되면 "팝업 허용" 안내와 새 탭 대체 경로를 보여준다.

### 위험과 스파이크

구현 첫 작업은 스파이크다. 로컬 wisp-js + `flutter run -d chrome`으로 실제 학교 서버에 읽기 전용으로 확인한다. 1이 실패하면 설계를 재검토한다.

1. libcurl.js 응답에서 `Set-Cookie`를 읽을 수 있는가, 수동 리다이렉트와 `Origin` 지정이 되는가, 로그인 → SAML 브리지 → Canvas API 200까지 가는가.
2. 브라우저가 제출한 SAMLResponse를 Canvas가 받는가. 요청을 터널 세션에서 시작했으므로 `InResponseTo`를 세션과 대조하면 거부될 수 있다.
3. iOS 홈 화면 PWA에서 사용자 제스처로 연 창에 비동기로 폼을 제출할 수 있는가.
4. 모든 사용자 트래픽이 NAS IP 하나에서 나가므로 학교 측이 차단하거나 속도를 제한할 수 있다. 전산원 회신에서 함께 확인한다.
5. iOS는 오래 쓰지 않은 PWA의 저장소를 지울 수 있다. 캐시는 보조 수단으로만 취급한다.

### 검증

- 기존 VM 테스트 전체 통과(모바일 경로 무변경 확인).
- 웹 전용 코드(어댑터, 저장소 선택, 플랫폼 검사)는 `flutter test --platform chrome`.
- 중계 서버: 허용 목록 밖 호스트·포트, 사설 IP, UDP 거부 테스트. 잘못된 Origin 거부 테스트.
- NAS 배포와 iPhone 실기기 확인은 운영자가 체크리스트로 수행한다.

### 1단계 범위 밖

투명성 장치(2단계), 알림(3단계), 서비스 워커 오프라인 캐싱 고도화, Android용 PWA 최적화.
