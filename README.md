# 금오 LMS (kumoh_lms)

금오공과대학교 LINUS/Canvas LMS를 휴대폰에서 조회하는 Flutter 앱이다. 별도 백엔드 서버 없이 앱이 학교 서버에 직접 접속한다.

## 주요 기능

- **강의**: 현재 학기 수강 강좌 목록. 강좌마다 `홈 - 공지 - 강의실 - 과제 - 강의자료실 - 토론 - 성적 - 사용자 및 그룹 - 강의 계획` 탭을 같은 순서로 보여 준다.
- **과제**: 마감일 캘린더와 목록. 기한이 없는 과제는 따로 모아 표시한다.
- **공지사항**: 전체 공지와 알림 내역을 시간순으로 합쳐 보여 주고, 공지사항/파일/토론/과제로 거를 수 있다.
- **인앱 웹뷰**: Canvas 링크를 SSO 로그인된 상태로 앱 안에서 연다. PDF 같은 파일은 받아서 기기 뷰어로 넘긴다.
- **새 소식 알림**: 새 공지·파일·과제·토론 글을 정해진 시각마다 확인해 기기 알림으로 띄운다. 자세한 내용은 [docs/notifications.md](docs/notifications.md)에 있다.
- **강의자료 자동 다운로드 (Android)**: 선택한 폴더에 강의별로 자료를 저장한다. 자세한 내용은 [docs/downloads.md](docs/downloads.md)에 있다.
- **오프라인 캐시**: 암호화된 로컬 DB에 마지막 조회 결과를 보관한다.

## 구조

```
UI (Riverpod) → Repository → dio + Drift(SQLCipher) 캐시
```

| 경로 | 내용 |
| --- | --- |
| `lib/core/` | 설정(`config/env.dart`), 오류 모델, 네트워크(토큰 부착·자동 재발급), 라우터, 저장소, 공통 UI |
| `lib/features/auth/` | 로그인, 세션 복원, 자동 로그인 |
| `lib/features/courses/`, `assignments/`, `announcements/`, `reference/` | LINUS API 기반 강좌·과제·공지·학기 |
| `lib/features/canvas/` | Canvas SAML 브릿지, Canvas REST API, 강좌 상세 탭, 인앱 웹뷰 |
| `lib/features/notifications/`, `downloads/` | 백그라운드 알림과 자료 다운로드 |
| `lib/providers.dart` | 의존성 연결 |
| `packages/lms_folder_storage/` | Android SAF 폴더 선택·저장용 로컬 플러그인 |
| `python/` | 서버 연동 확인용 진단 스크립트 |

### 인증 흐름

1. LINUS `/login`으로 accessToken(JWT, 유효 1시간)과 refreshToken을 받는다. 토큰은 Secure Storage에 둔다.
2. LINUS API가 204/401을 돌려주면 `AuthInterceptor`가 `/reissue`로 재발급하고 원요청을 다시 보낸다.
3. Canvas는 LINUS 토큰을 모르므로 SAML 브릿지를 건넌다.
   1. LINUS `/saml/redirect.do`로 SSO 진입 URL을 받는다. 토큰이 만료됐다면 이때 재발급된다.
   2. **그 다음에** 저장된 accessToken을 읽어 `.kumoh.ac.kr`에 `_linus_saml_login` 쿠키로 심는다.
   3. IdP가 돌려준 SAML 폼을 제출해 Canvas 세션 쿠키(`_normandy_session`)를 얻는다.

   순서가 바뀌면 만료된 토큰이 쿠키에 들어가 IdP가 `S010`(SSO 연동 요청 검증 실패)을 낸다. 쿠키가 없으면 `A001`이다.

## 개발 환경

- Flutter SDK (Dart `^3.5.0`)
- Android SDK. iOS 빌드는 macOS가 필요하다.
- Windows에서 `flutter test`를 돌리려면 프로젝트 루트에 `sqlite3.dll`이 있어야 한다(커밋하지 않는다).

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift 코드 생성
flutter analyze
flutter test
flutter run
```

릴리스 APK:

```sh
flutter build apk --release
```

서명 키(`key.properties`, `*.jks`)는 저장소에 없다.

## 주의

- 로컬 자격증명 파일 `env`(`hakbun=`, `password=`)는 진단 스크립트용이다. 출력하거나 커밋하지 않는다.
- 학교 서버 부하를 줄이려고 강좌·학기 등은 TTL 캐시를 쓴다. 기준값은 `lib/core/config/env.dart`에 있다.
- 작업 이력과 인수인계는 [docs/HANDOFF.md](docs/HANDOFF.md), 설계·계획은 `docs/superpowers/`에 있다.
- 개인정보 처리방침: [privacy.html](privacy.html)
