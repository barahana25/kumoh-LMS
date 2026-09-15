# 금오 LMS PWA 중계 서버

PWA가 학교 서버에 접속할 수 있게 TCP 바이트만 전달한다. 학교 서버와의 TLS는 사용자 브라우저 안의 libcurl.js가 맺으므로 이 서버와 운영자는 요청·응답 내용(비밀번호, 토큰, 쿠키, 강의 데이터)을 볼 수 없다.

## 허용 범위

- 대상: `lms.kumoh.ac.kr`, `canvas.kumoh.ac.kr`의 82, 443 포트만 ([src/policy.mjs](src/policy.mjs))
- 사설 IP, 루프백, IP 직접 지정, UDP 금지
- WebSocket `Origin`이 `RELAY_ALLOWED_ORIGINS`에 없으면 403
- 동시 WebSocket 연결 수 제한 ([src/limits.mjs](src/limits.mjs)). 넘으면 `429 Too Many Requests`
  - `RELAY_MAX_CONNECTIONS_PER_CLIENT`: 클라이언트 주소 하나당 최대 연결 수 (기본 32)
    - 학교 Wi‑Fi나 통신사 NAT 뒤에서는 여러 사용자가 공인 IP 하나를 함께 쓴다. 값을 낮추면 남용은 더 막지만 같은 NAT 뒤의 정상 사용자가 429를 받을 수 있어 넉넉히 둔다
  - `RELAY_MAX_CONNECTIONS`: 전체 최대 연결 수 (기본 200)
  - `RELAY_TRUST_FORWARDED_FOR`: `1` 또는 `true`면 모든 연결에서 `X-Forwarded-For`의 마지막 주소를 클라이언트 주소로 쓴다(헤더가 없거나 비면 TCP 상대 주소). 기본은 꺼짐
  - 클라이언트 주소는 기본적으로 루프백(같은 호스트의 리버스 프록시)에서 온 연결이면 `X-Forwarded-For`의 마지막 주소, 아니면 TCP 상대 주소다. 앞쪽 항목은 클라이언트가 속일 수 있어 쓰지 않는다. 마지막 항목은 DSM 리버스 프록시가 실제 접속 주소를 붙인 값이어야 하므로, 프록시가 이 헤더를 붙이는지 배포 때 확인한다. 주소는 메모리의 연결 수 집계에만 쓰고 연결이 닫히면 지우며, 로그에 남기지 않는다
  - **주의**: `RELAY_TRUST_FORWARDED_FOR`는 포트가 `127.0.0.1`에만 열려 있어 접속자가 같은 호스트의 리버스 프록시뿐일 때만 켠다. 포트를 외부에 직접 열었다면 누구나 헤더를 바꿔 제한을 피할 수 있으므로 절대 켜지 않는다
- 로그: 연결·스트림 시각, 대상 호스트:포트만 남는다. wisp-js가 남기는 접속자 IP는 [src/log_redaction.mjs](src/log_redaction.mjs)가 콘솔 출력 단계에서 가린다

## 로컬 개발

```bash
npm install
npm test
RELAY_ALLOWED_ORIGINS=http://localhost:8000 PORT=8080 npm start
```

Flutter 쪽: `flutter run -d chrome --web-port 8000 --dart-define=RELAY_URL=ws://127.0.0.1:8080/`

## Synology NAS 배포

1. **DDNS**: 제어판 → 외부 액세스 → DDNS → 추가. 서비스 공급자 Synology, 호스트 이름 `barahana.synology.me`
   - 이 NAS의 443 포트를 다른 서비스(Web Station, 다른 리버스 프록시 규칙)가 같은 호스트 이름으로 이미 쓰고 있다면 규칙이 겹친다. 그때는 5의 소스 포트를 다른 번호(예: 8443)로 정하고 `RELAY_URL`에 포트를 넣는다(`wss://barahana.synology.me:8443/`)
2. **인증서**: 제어판 → 보안 → 인증서 → 추가 → Let's Encrypt에서 인증서 받기. 도메인은 1의 호스트 이름
3. **컨테이너**: Container Manager → 프로젝트 → 생성. 경로에 `compose.yaml`을 두고 실행
   - `compose.yaml`은 `RELAY_TRUST_FORWARDED_FOR: "1"`을 켠다. Docker 브리지 뒤에서는 리버스 프록시가 게이트웨이 주소(예: `172.17.0.1`)로 보여, 끄면 모든 사용자가 한 주소로 묶여 연결 제한(기본 32)을 함께 쓰기 때문이다. `ports`를 `127.0.0.1:18080:8080`에서 바꿔 포트를 외부에 직접 열 경우 반드시 이 값을 지운다
4. **이미지 고정**: GitHub 저장소 → Packages → `kumoh-lms-relay`에서 배포할 커밋의 `sha256:...` digest를 확인하고 `compose.yaml`의 `image`를 `ghcr.io/barahana25/kumoh-lms-relay@sha256:<digest>`로 바꾼 뒤 프로젝트를 다시 빌드한다
   - GHCR 패키지는 처음에 비공개다. GitHub → Packages → `kumoh-lms-relay` → Package settings에서 공개로 바꾸거나, NAS에서 `docker login ghcr.io`(read:packages 권한 토큰)로 로그인해야 이미지를 받을 수 있다
5. **리버스 프록시**: 제어판 → 로그인 포털 → 고급 → 리버스 프록시 → 생성
   - 소스: HTTPS, 호스트 이름 `barahana.synology.me`, 포트 443
   - 대상: HTTP, `localhost`, 포트 18080 (`compose.yaml`의 `ports` 왼쪽 번호. NAS의 8080은 다른 서비스가 쓰고 있어 18080을 쓴다)
   - 사용자 지정 머리글 → 생성 → **WebSocket** (Upgrade, Connection 헤더 자동 추가)
   - 인증서: 제어판 → 보안 → 인증서 → 설정에서 이 호스트에 2의 인증서 지정
   - 고급 설정의 프록시 시간 제한(WebSocket 유휴 시간)은 600초 정도로 둔다. 너무 길면(예: 3600초) 백그라운드로 멈춘 iOS PWA의 연결이 한 시간씩 연결 수 한도를 차지한다
   - 연결 수 제한은 `X-Forwarded-For`의 마지막 주소로 센다. DSM 리버스 프록시가 이 헤더 끝에 실제 접속 주소를 붙여야 한다
6. **공유기**: TCP 443 → NAS만 포워딩한다. DSM 관리 포트 5000/5001은 외부에 열지 않는다
7. **확인**: `https://barahana.synology.me/healthz`가 `ok`
8. GitHub 저장소 → Settings → Secrets and variables → Actions → Variables에 `RELAY_URL` = `wss://barahana.synology.me/` 등록 (끝의 `/` 필수)
