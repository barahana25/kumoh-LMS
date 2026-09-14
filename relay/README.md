# 금오 LMS PWA 중계 서버

PWA가 학교 서버에 접속할 수 있게 TCP 바이트만 전달한다. 학교 서버와의 TLS는 사용자 브라우저 안의 libcurl.js가 맺으므로 이 서버와 운영자는 요청·응답 내용(비밀번호, 토큰, 쿠키, 강의 데이터)을 볼 수 없다.

## 허용 범위

- 대상: `lms.kumoh.ac.kr`, `canvas.kumoh.ac.kr`의 82, 443 포트만 ([src/policy.mjs](src/policy.mjs))
- 사설 IP, 루프백, IP 직접 지정, UDP 금지
- WebSocket `Origin`이 `RELAY_ALLOWED_ORIGINS`에 없으면 403
- 동시 WebSocket 연결 수 제한 ([src/limits.mjs](src/limits.mjs)). 넘으면 `429 Too Many Requests`
  - `RELAY_MAX_CONNECTIONS_PER_CLIENT`: 클라이언트 주소 하나당 최대 연결 수 (기본 4)
  - `RELAY_MAX_CONNECTIONS`: 전체 최대 연결 수 (기본 200)
  - 클라이언트 주소는 루프백(같은 호스트의 리버스 프록시)에서 온 연결이면 `X-Forwarded-For`의 첫 주소, 아니면 TCP 상대 주소다. 주소는 메모리의 연결 수 집계에만 쓰고 연결이 닫히면 지우며, 로그에 남기지 않는다
- 로그: 연결·스트림 시각, 대상 호스트:포트만 남는다. wisp-js가 남기는 접속자 IP는 [src/log_redaction.mjs](src/log_redaction.mjs)가 콘솔 출력 단계에서 가린다

## 로컬 개발

```bash
npm install
npm test
RELAY_ALLOWED_ORIGINS=http://localhost:8000 PORT=8080 npm start
```

Flutter 쪽: `flutter run -d chrome --web-port 8000 --dart-define=RELAY_URL=ws://127.0.0.1:8080/`

## Synology NAS 배포

1. **DDNS**: 제어판 → 외부 액세스 → DDNS → 추가. 서비스 공급자 Synology, 호스트 이름 예: `kumoh-relay.synology.me`
2. **인증서**: 제어판 → 보안 → 인증서 → 추가 → Let's Encrypt에서 인증서 받기. 도메인은 1의 호스트 이름
3. **컨테이너**: Container Manager → 프로젝트 → 생성. 경로에 `compose.yaml`을 두고 실행
4. **이미지 고정**: GitHub 저장소 → Packages → `kumoh-lms-relay`에서 배포할 커밋의 `sha256:...` digest를 확인하고 `compose.yaml`의 `image`를 `ghcr.io/barahana25/kumoh-lms-relay@sha256:<digest>`로 바꾼 뒤 프로젝트를 다시 빌드한다
   - GHCR 패키지는 처음에 비공개다. GitHub → Packages → `kumoh-lms-relay` → Package settings에서 공개로 바꾸거나, NAS에서 `docker login ghcr.io`(read:packages 권한 토큰)로 로그인해야 이미지를 받을 수 있다
5. **리버스 프록시**: 제어판 → 로그인 포털 → 고급 → 리버스 프록시 → 생성
   - 소스: HTTPS, 호스트 이름 `kumoh-relay.synology.me`, 포트 443
   - 대상: HTTP, `localhost`, 포트 8080
   - 사용자 지정 머리글 → 생성 → **WebSocket** (Upgrade, Connection 헤더 자동 추가)
   - 인증서: 제어판 → 보안 → 인증서 → 설정에서 이 호스트에 2의 인증서 지정
   - 오래 열어 둔 세션이 끊기면 고급 설정의 프록시 시간 제한(WebSocket 유휴 시간)을 3600초 정도로 늘린다
6. **공유기**: TCP 443 → NAS만 포워딩한다. DSM 관리 포트 5000/5001은 외부에 열지 않는다
7. **확인**: `https://kumoh-relay.synology.me/healthz`가 `ok`
8. GitHub 저장소 → Settings → Secrets and variables → Actions → Variables에 `RELAY_URL` = `wss://kumoh-relay.synology.me/` 등록 (끝의 `/` 필수)
