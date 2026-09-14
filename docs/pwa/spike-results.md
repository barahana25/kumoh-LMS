# PWA 스파이크 결과

확인일: 2026-09-14, 데스크톱 Chrome, libcurl.js 0.7.4, wisp-js 0.5.0 (tool/spike, 127.0.0.1 로컬 중계)

## 판정

- 터널 브리지: 성공
- 브라우저 SAML POST: 성공
- 파일 다운로드 리다이렉트 호스트: 없음 (`/files/:id/download`가 바로 200)

## 관찰

- Set-Cookie 읽기: 읽힘 (`raw_headers`에 `_csrf_token`, `log_session_id`, `_normandy_session`, `_legacy_normandy_session` 모두 노출)
- redirect: manual: 3xx가 그대로 보임 (hop 0: canvas 302 → lms.kumoh.ac.kr:82, hop 1: 200 SAML 폼)
- Origin 헤더 지정 로그인: status 200, code 200, accessToken(JWT 404자)
- ACS POST: 302, `_normandy_session` 발급
- Canvas profile / courses / files status: 200 / 200 / 200
- 브라우저 SAML POST: 새 창에 로그인된 Canvas 강좌 목록 표시. 터널 세션에서 시작한 SAML 요청의 응답을 브라우저가 제출해도 Canvas가 받는다(InResponseTo를 세션과 대조하지 않거나 통과)
- 주의: 데스크톱 Chrome에 기존 canvas.kumoh.ac.kr 로그인 세션이 남아 있었다면 B 결과가 그 세션 때문일 수 있다. iPhone 확인 목록(docs/pwa/verification.md)에서 새로 설치한 PWA로 다시 확인한다

## 로그 (토큰 앞 4자만)

```
[1] LINUS 로그인 (Origin 헤더 지정)
    status 200, code 200
    accessToken eyJh…(404자)
[2] SSO 진입 URL
    host canvas.kumoh.ac.kr
[3] 리다이렉트 수동 추적 (redirect: manual이 먹는지 확인)
    Set-Cookie 읽힘: _csrf_token=waTS…(96자) (canvas.kumoh.ac.kr)
    hop 0: 302 canvas.kumoh.ac.kr -> lms.kumoh.ac.kr:82
    hop 1: 200 lms.kumoh.ac.kr:82
    폼 action canvas.kumoh.ac.kr, SAMLResponse PD94…(6452자)
[4] ACS POST (터널)
    Set-Cookie 읽힘: _csrf_token=55cH…(96자) (canvas.kumoh.ac.kr)
    Set-Cookie 읽힘: log_session_id=9689…(32자) (canvas.kumoh.ac.kr)
    Set-Cookie 읽힘: _legacy_normandy_session=tn1K…(421자) (canvas.kumoh.ac.kr)
    Set-Cookie 읽힘: _normandy_session=tn1K…(421자) (canvas.kumoh.ac.kr)
    status 302, _normandy_session 있음
    Set-Cookie 읽힘: _csrf_token=7ya2…(100자) (canvas.kumoh.ac.kr)
    Set-Cookie 읽힘: log_session_id=8867…(32자) (canvas.kumoh.ac.kr)
    Set-Cookie 읽힘: _legacy_normandy_session=GTce…(442자) (canvas.kumoh.ac.kr)
    Set-Cookie 읽힘: _normandy_session=GTce…(442자) (canvas.kumoh.ac.kr)
[5] Canvas profile status 200
    Set-Cookie 읽힘: _csrf_token=Z14m…(96자) (canvas.kumoh.ac.kr)
    Set-Cookie 읽힘: log_session_id=8867…(32자) (canvas.kumoh.ac.kr)
[6] courses status 200, 1건
    Set-Cookie 읽힘: _csrf_token=q044…(94자) (canvas.kumoh.ac.kr)
    Set-Cookie 읽힘: log_session_id=8867…(32자) (canvas.kumoh.ac.kr)
[7] files status 200, 1건
    Set-Cookie 읽힘: _csrf_token=1kwX…(94자) (canvas.kumoh.ac.kr)
    Set-Cookie 읽힘: log_session_id=8867…(32자) (canvas.kumoh.ac.kr)
    download status 200 -> (리다이렉트 없음)
```

B: 새 창에 로그인된 Canvas 강좌 목록 보임.
