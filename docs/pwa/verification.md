# PWA 실기기 확인 목록

운영자가 NAS 배포(relay/README.md)와 Pages 배포(Task 11) 뒤 iPhone에서 확인한다. 결과는 각 줄 끝에 날짜와 함께 적는다.

## 준비

- [ ] `https://barahana.synology.me:8443/healthz` → `ok`
- [ ] 저장소 Packages에서 배포한 relay 이미지 digest와 compose.yaml의 digest가 같다
- [ ] DSM 리버스 프록시가 X-Forwarded-For 끝에 실제 접속 주소를 붙이는지 확인(relay 로그가 아니라 임시 디버그로 확인 후 되돌림)

## iPhone Safari (iOS 16.4 이상)

- [ ] `https://barahana25.github.io/kumoh-LMS/` 접속 시 로그인 화면에 홈 화면 추가 안내가 보인다
- [ ] 공유 → 홈 화면에 추가 → 아이콘과 이름 "금오 LMS" 확인
- [ ] 홈 화면 아이콘으로 실행하면 주소창 없이 열리고 설치 안내가 보이지 않는다
- [ ] 로그인 화면에 자동 로그인 스위치가 없다
- [ ] 로그인 → 강의 목록, 과제 캘린더, 공지 목록 표시
- [ ] 강좌 상세 9개 탭 이동
- [ ] 강의자료 PDF가 새 창에서 열린다
- [ ] HTML·SVG 첨부파일은 창에서 열리지 않고 다운로드된다(홈 화면 앱에서 다운로드가 막히면 기록)
- [ ] 공지를 누르면 새 창에서 로그인된 Canvas 원문이 열린다 (팝업이 막히면 현재 창에서 열린다)
- [ ] 앱을 닫았다 다시 열면 로그인이 유지된다(토큰 유효 기간 안)
- [ ] 설정 화면에 알림·백그라운드·폴더 다운로드 항목이 없다
- [ ] 비행기 모드에서 다시 열면 캐시된 목록과 연결 실패 배너가 보인다

## 블라인드 확인 (PC Chrome)

- [ ] 개발자 도구 → Network → WS → 중계 서버 연결의 Messages가 바이너리이며 `lms.kumoh.ac.kr`, `canvas.kumoh.ac.kr` 호스트 이름 외에 읽을 수 있는 HTTP 헤더·JSON이 보이지 않는다
- [ ] NAS Container Manager 로그에 비밀번호·토큰·강의 이름이 없다

## 중계 서버 차단

- [ ] 다른 사이트 Origin으로 WebSocket 연결 시 403 (`relay/test/relay.test.mjs`와 같은 요청을 curl로: `curl -i -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Origin: https://evil.example" -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" https://barahana.synology.me:8443/`)
