# 작업 인수인계 — 2026-09-06 업데이트

## 릴리스 빌드에서 알림을 켤 수 없던 문제 (2026-09-09)

- 증상: 알림 토글을 누르면 "알림 설정을 완료하지 못했습니다"가 뜨고 스위치가 도로 꺼졌다.
- 원인: 릴리스 빌드의 리소스 축소가 ic_stat_lms를 제거했다. 이 드로어블은 Dart의 AndroidInitializationSettings에서 이름 문자열로만 참조해 축소기가 미사용으로 판단한다. 제거되면 알림 초기화가 PlatformException(invalid_icon)으로 실패하고, 이 실패는 설정 저장 이전이라 스위치가 꺼진 채로 되돌아간다.
- debug 빌드에는 리소스가 남아 있어 개발 중 재현되지 않았다. 2026-09-07 조사에서 원인을 좁히지 못한 이유다.
- 수정: android/app/src/main/res/raw/keep.xml로 ic_stat_lms를 보존한다. 이름 문자열로 참조하는 다른 리소스는 없다. launch_logo·launch_background·ic_launcher는 XML 정적 참조라 대상이 아니다.
- 검증: 수정 전 릴리스 APK 리소스 테이블에 ic_stat_lms 0건이고 에뮬레이터 릴리스 빌드에서 initialize가 invalid_icon으로 실패했다. 수정 후 1건이며 initialize가 통과한다. debug 빌드는 수정 전에도 통과해 릴리스 전용임을 확인했다. 진단 스크립트는 .superpowers/schedule_smoke.dart이며 로그인 없이 초기화·권한·예약 단계만 실행한다.
- 함께 보완: 알림 설정 실패 시 실패한 단계를 표시한다. poller와 같은 규칙으로 PlatformException은 제한된 코드, SqliteException은 숫자 코드만 남기고 자격증명·네이티브 원문·서버 응답은 노출하지 않는다. notificationSetupMessage 회귀 테스트 5개를 추가했다.
- 전체 287개 테스트 통과, 정적 분석 통과. 실제 사용자 기기 확인은 하지 않았다.

## 강의자료 자동 다운로드 (2026-09-08)

- Android 설정에서 저장 폴더 선택·생성 및 자동 다운로드/지금 다운로드를 추가했다. 예: Download/2학년 2학기/강의명 (강의 ID)/파일명__파일ID.pdf. 처음 켜면 현재 자료도 받는다.
- 알림과 독립적인 설정/DB 잠금으로 기존 정시 WorkManager 및 앱 타이머를 공유한다. 알림을 꺼도 다운로드가 켜져 있으면 예약 유지. 로그아웃/계정 교체는 다운로드를 먼저 끈다.
- 로컬 Flutter 플러그인 packages/lms_folder_storage를 새로 추가해 SAF 트리 선택, 지속 URI 권한, 강의 폴더 생성 및 파일 복사를 담당한다. 백그라운드 Flutter 엔진에도 자동 등록된다. 광범위 저장소 권한은 추가하지 않았다.
- DB v5로 다운로드 설정과 완료 URI를 추가했다. 경로 안전화, 동명 파일 덮어쓰기 방지, 임시 저장 후 최종 이름 변경, 중복 방지, 실패 재시도, 삭제 파일 재수신, 권한 상실 시 중지를 구현했다.
- 전체 282개 테스트 통과, 정적 분석 통과, Android Java 컴파일 통과. 실제 학교 서버 PDF 다운로드 및 헤더 검증 성공. APK와 기기 폴더 선택/밤샘 실행 검증은 하지 않았다. iOS 폴더 저장은 이번 범위 밖이다. 자세한 사용법과 제한은 docs/downloads.md 참조.

## 통합 알림 내역·분류 및 투명 상단 로고 (2026-09-07)

- 상단 로고를 사용자가 제공한 img_ci03_pc (1)-Photoroom.png의 복사본 assets/branding/kumoh-header-transparent.png로 교체했다.
- 공지사항 탭에 전체/공지사항/파일/토론/과제 필터를 추가했다. 기존 공지 목록과 알림 기록을 시간순으로 합치고 동일 강좌/공지 ID는 중복 표시하지 않는다. 알림 항목을 누르면 해당 원문을 내부 웹뷰로 연다.
- DB v4: notification_outbox에 item_id, detected_at, delivered를 추가했다. 전송 후 삭제 대신 완료 표시하여 내역을 유지한다. 같은 계정의 알림 껐다 켜기에는 기록을 유지하고 로그아웃 wipe 때 지운다. 기존 v3 대기 내역은 유지하며 이미 삭제된 과거 전송 내역은 복원할 수 없다. 앱 내 시간은 새 소식 감지 시각이다.
- 토론 새 게시글을 네 번째 크롤링/시스템 알림 대상으로 추가했다. 공지 중복, 숨김·잠금·미공개 및 예약 공개 전 게시글을 제외한다. 댓글은 대상이 아니다. 첫 토론 조회는 기준만 저장한다.
- 전체 273개 테스트 통과. 실제 학교 서버의 6개 강의 × 4종 목록 조회 성공(현재 토론 0건). 필터 UI, v3→v4 이관, 내역 보존, 로그아웃 삭제, 토론 파싱을 검증했다. APK 빌드는 하지 않았다.

## 상단 로고·로딩 글꼴 변경 (2026-09-07)

- 강의 화면 상단 로고를 assets/branding/img_ci03_pc.jpg로 교체했다. 원본 주변 여백은 UI에서 잘라 가로 로고가 보이게 한다.
- 시작 이미지 assets/branding/kumoh-lms-startup-ochungi.png는 기존 원형 학교 로고를 유지하고 아래 학교명 및 LMS를 지정된 GriunXHangeul_OCHUNGI.KIM-Rg.ttf로 직접 렌더링했다. Flutter 및 Android/iOS 시작 이미지에 연결했다. 런처 아이콘은 유지한다.
- 관련 정적 분석 통과. APK 빌드는 하지 않았다.

## 아이콘 색상·글꼴 변경 (2026-09-07)

- 현재 런처 원본은 assets/branding/lms_app_icon_ochungi.png이다. 물방울은 밝은 하늘색, LMS는 프로젝트의 GriunXHangeul_OCHUNGI.KIM-Rg.ttf를 직접 로드하여 대문자로 렌더링했다. Android/iOS 아이콘 리소스를 재생성했고 기존 JPG 및 중간 단색 버전은 보존했다. 시작 화면의 학교 로고는 유지했다. APK는 빌드하지 않았다.

## 수동 확인 오류·포그라운드 확인 보완 (2026-09-07)

- 실제 운영 LmsNotificationSource 기본 생성자로 학교 서버를 읽기 전용 검증했다. 로그인, 6개 강의 × 공지/파일/과제 18개 목록 모두 성공했다. 사용자 휴대폰의 일반 Exception 오류는 아직 재현하지 못했다. 진단 스크립트는 .superpowers/verify_notifications_test.dart이며 env 값이나 서버 원문 오류를 출력하지 않는다.
- 포그라운드 확인에서 WorkManager 초기화/예약 실패가 조회를 막던 결합을 제거했다. OS 예약 실패 후에도 독립적으로 poll을 호출한다. poll은 알림 표시 플러그인만 별도로 초기화한다.
- 설정 상태를 단발 FutureProvider에서 DB StreamProvider로 바꿔 같은 앱 인스턴스의 자동 확인 결과를 즉시 반영한다. 최근 시도 및 완료 시각을 초 단위로 표시한다.
- poller의 일반 실패는 단계, PlatformException은 제한된 코드, SQLite 오류는 숫자 코드만 표시한다. 자격증명·원문 네이티브 메시지·응답은 저장하지 않는다.
- 정적 분석 통과, 기존 관련 31개 테스트 통과 후 신규 2개 회귀 테스트 추가 및 해당 묶음 16개 통과. APK 빌드/사용자 기기 검증은 하지 않았다. 수동 실패의 확정 진단은 수정 버전에서 표시되는 단계/코드가 필요하다.

## 최근 앱 종료 후 알림 예약 보완 (2026-09-07)

- 사용자가 최근 앱에서 밀어서 종료 후 08:01/09:01 확인 누락을 보고했다. 사용자 기기의 작업 기록은 확보하지 못해 원인은 미확정이다.
- 매시 1분 단발 예약과 별도로 고유한 15분 주기 WorkManager 복구 작업을 추가했다. 누락 회차 조회 및 다음 예약을 복구하며 기존 DB 회차 잠금으로 시간당 한 번, 01:00~07:59 크롤링 없음은 유지한다. 알림 해제 시 복구 작업도 취소한다.
- 설정에 Android 앱 정보로 이동하는 백그라운드 실행 설정을 추가했다. 배터리 최적화 제외 상태를 조회하고, 배터리 제한 없음 및 절전 앱 제외를 안내한다. 이 상태는 제조사별 모든 제한을 판별하는 값은 아니다.
- 알림 및 앱 흐름 30개 테스트 통과 후 복구 중복 방지 회귀 테스트를 추가했고 시간표 테스트 8개가 통과했다. 알림 코드 정적 분석 통과. APK 빌드, 변경된 Kotlin 컴파일 및 실기기 밤샘 실행은 미검증이다.
- 복구 작업도 Doze 제한을 받는다. 정각 실행 보장이나 사용자 강제 중지 우회 기능은 아니다.

## 시작 이미지 변경 (2026-09-07)

- 런처 아이콘은 유지하고 시작 화면은 `assets/branding/kumoh-lms-logo-v4.png` 전체를 흰 배경 중앙에 240×240으로 표시한다.
- Android 12 이상은 시스템 아이콘 슬롯을 투명하게 처리하고 Flutter 시작 화면에서 마스크 없이 이미지를 표시한다. 이전 Android 및 iOS에도 별도 시작 이미지를 연결했다.
- Flutter 초기화와 세션 복원 동안 같은 시작 화면을 사용한다. 정적 분석 및 기존 앱 흐름 테스트 3개 통과, 네이티브 XML 파싱 확인. APK 빌드 및 기기 화면 확인은 하지 않았다.
- 직전 강의 목록 변경: ONLINE 등 분류 제거, 강좌 코드의 `LA0424-02` 형태만 표시, 탭과 화면 제목을 `강의`로 변경. APK에는 아직 반영되지 않았다.


## 알림 시간표 변경 (2026-09-07)

- 한국 시간 기준 `00:01, 08:01~23:01`에 자동 크롤링한다. 01:00~07:59는 쉬고 08:01에 재개한다. 수동 `지금 확인`과 활성화 직후 첫 기준 조회는 즉시 실행한다.
- Android는 다음 회차 시각을 계산해 WorkManager 단발 작업을 연결한다. 앱 내 타이머도 동일한 시각에 맞춘다. iOS는 BGAppRefresh와 실행 시각 검사를 사용하며 OS에 따른 지연 가능성은 유지된다.
- DB 중복 검사를 지난 실행 이후 1시간에서 현재 정시 회차 기준으로 바꿨다. 늦은 실행 때문에 다음 정시를 건너뛰지 않는다. 실행 중 휴식 시간이 되면 후속 목록 요청·알림 전송을 멈춘다.
- 관련 회귀 테스트 7개 추가, 전체 **266개 통과**. 자세한 설명은 `docs/notifications.md` 참고.

## 공지·과제 누락 수정 (2026-09-06)

- 실제 학교 서버에서 정치학입문-01(5342)의 `레포트 안내` 공지와 `레포트 제출` 과제를 확인했다. 과제의 `due_at`은 null이고 기존 LINUS 캘린더 응답은 0건이었다.
- 전체 과제는 Canvas 과제 원본을 함께 조회한다. 기한 없는 과제는 목록과 캘린더 아래 `기한 없는 과제` 영역에 표시하며 임의의 날짜를 넣지 않는다. 날짜가 있는 과제는 마감일에 표시한다.
- 전체 공지도 강좌별 Canvas 공지를 조회하여 강좌명을 채우고, 클릭하면 SSO가 연결된 내부 웹뷰로 연다.
- 강좌 공지 탭을 구현하고 모든 강좌에 `홈 - 공지 - 강의실 - 과제 - 강의자료실 - 토론 - 성적 - 사용자 및 그룹 - 강의 계획` 순서를 고정했다.
- 과제·공지 목록은 페이지 끝까지 조회한다. 일부 강좌 조회 실패 시 해당 강좌의 캐시를 보존하고 오류 배너를 표시한다.
- `test/features/canvas/lms_regressions_test.dart`에 8개 회귀 테스트를 추가했다. 전체 **259개 테스트 통과**.
- 정적 분석과 Android APK 생성·에뮬레이터 업데이트 설치를 확인했다. Flutter 최소 요구 조건에 맞게 `android/settings.gradle.kts`의 Kotlin 플러그인을 2.2.20으로 명시했다.
- 선택한 금오공대 로고 + 학교명/LMS 아이콘은 Android/iOS 런처에 적용되어 있다. 재생성 설정은 `flutter_launcher_icons.yaml`이다.

## 앞선 알림 구현

기본 앱과 강좌 상세는 Claude가 완료했다. 이번 작업 시작 커밋은 `a7dfe9d`이며, 현재 미커밋 변경은 **1시간 주기 새 공지·파일·과제 알림**이다. 아래 9월 5일 기록의 Task 15~17 미완료 상태는 과거 기록이다.

- 설정 → `LMS 새 소식 알림`에서 활성화한다. 저장된 자동 로그인 자격증명이 필요하다. `지금 확인`도 제공한다.
- 첫 조회는 기준만 저장하고 이후 새 ID만 기기 알림으로 표시한다. 현재 학기 수강 강좌를 감시한다.
- 별도 세션으로 Canvas 목록의 페이지를 끝까지 읽으며 화면 캐시·저장 토큰을 덮어쓰지 않는다.
- DB v3에 설정·기준·확인 ID·미전송 알림 테이블을 추가했다. 중복 실행, 로그아웃 후 응답, 실패 재시도를 처리한다.
- 전체 테스트 **251개 통과**. 새 알림 테스트는 **20개**다. Android 에뮬레이터에서 합성 데이터로 최초 0개 → 새 항목 3개 → 반복 0개와 실제 OS 알림 표시·작업 등록을 확인했다.
- iOS 설정은 구현했지만 Windows에서 iOS 빌드·실행은 검증하지 않았다. 실제 학교 서버의 새 게시물 발생과 장시간 절전 검증은 별도로 필요하다.
- 사용 방법, 구조, OS 실행 제약은 [notifications.md](notifications.md)를 읽는다.
- 정적 분석과 최종 Android 디버그 APK 빌드가 통과했다. 에뮬레이터에서 WorkManager의 백그라운드 실행 성공도 확인했다. 알림을 끈 상태에서는 앱 재개 시 남은 정기 작업을 취소한다.
- 최종 빌드는 `flutter build apk --debug --no-pub`로 `lib/main.dart`를 사용한다. `.superpowers/`의 합성 데이터 진입점은 배포에 사용하지 않는다.
- Android SDK의 cmdline-tools와 NDK 환경은 정리되어 Android 빌드가 가능하다. Flutter 경로와 자격증명 보호 규칙은 아래와 동일하다.

---

# 이전 기록: Claude 작업 인수인계 (2026-09-05)

확인일: 2026-09-05 (Asia/Seoul). 이번 작업은 기존 구현과 기록을 확인하고 다음 개발을 준비하는 범위다. 앱 소스와 기존 테스트는 수정하지 않았다.

## 현재 위치

- 프로젝트: 금오공과대학교 Canvas/LINUS LMS 조회용 Flutter 모바일 앱.
- 브랜치: `feat/v1-client`
- 마지막 커밋: `cf80061` — 오프라인에서 캐시된 학기를 쓰고, 새로고침 오류 처리를 정돈.
- 전체 17개 Task 중 1~14는 구현 및 커밋됨. Task 15(강좌 목록 화면)는 파일 작성 후 미커밋 상태다.
- Claude 대화 마지막에는 Task 15 착수 후 세션 사용량 제한 메시지가 남아 있다. Task 15 완료 보고서는 없다.
- `lib/main.dart`와 `test/widget_test.dart`는 아직 Flutter 기본 카운터 예제다. 개별 기능이 구현되어 있어도 앱에서 연결되어 보이는 상태는 아니다.

## 참고 문서

- [설계](superpowers/specs/2026-09-05-kumoh-canvas-client-design.md)
- [구현 계획](superpowers/plans/2026-09-05-kumoh-canvas-client-v1.md): Task 15는 4378행, Task 16은 4687행, Task 17은 5130행부터 시작한다.
- 로컬 상세 진행 기록: `.superpowers/sdd/progress.md`
- 로컬 Task 15 지시서: `.superpowers/sdd/task-15-brief.md`
- Claude 기록: `C:\Users\barah\.claude\projects\c--Users-barah-Desktop-canvas\80f62260-b6bd-4c04-ab29-8d34267a8049.jsonl`

`.superpowers/`와 Claude 기록은 Git에 포함되지 않는다. 과거 보고서에는 이후 수정으로 낡은 설명이 있으므로 최종 코드와 커밋을 대조한다. 진행 기록의 과거 Task 8 중단 문구 이후에도 Task 14까지 진행된 이력이 있다.

## 구현된 내용

| 범위 | 상태 |
| --- | --- |
| 오류 모델, API 응답 파서, 토큰 저장소 | 구현됨 |
| 로그인 API, HTTP 204/401 토큰 회전 및 재시도 | 구현 및 회귀 테스트 있음 |
| Drift DB, SQLCipher 개방 코드, DAO, TTL 캐시 | 구현됨; 실기기 암호화 검증은 별도 필요 |
| 학기·강좌·과제·공지 데이터 계층 | 구현됨 |
| Riverpod 의존성 연결, AuthController | 구현됨 |
| KIT 테마, 하단 탭 셸, 로그인 화면 | 구현됨; 최종 앱 연결 전 |
| 학기 선택 provider, 빈 화면, 새로고침 실패 배너 | 구현됨 |
| 강좌 카드와 목록 화면 | 미커밋 초안, 테스트 실패 확인 |
| 과제 캘린더/목록, 공지·설정 화면, 라우터 | 미구현 |

구조는 `UI/Riverpod → Repository → dio + Drift 캐시`다. 수동 DTO와 일반 Riverpod provider를 사용하며 코드 생성은 Drift만 사용한다. API와 인증 동작은 기존 구현을 재사용한다.

## 인수 시 존재한 미커밋 파일

아래 파일은 이번 인수인계 이전부터 존재했으며 그대로 보존했다.

- `lib/features/courses/presentation/courses_providers.dart`
- `lib/features/courses/presentation/course_list_screen.dart`
- `lib/features/courses/presentation/widgets/course_card.dart`
- `test/features/courses/course_list_screen_test.dart`
- `test/_diag_course_list_test.dart` — 진단용 별도 테스트. 완료 판정 전에 정식 테스트와 역할을 정리할 것.

## 이번 검증

- `flutter analyze --no-pub`: **통과**, `No issues found!`.
- `flutter test --no-pub --timeout 30s --reporter expanded`: **실패 확인**. 정식/진단용 강좌 화면의 캐시 표시 테스트 모두 `A Timer is still pending even after the widget tree was disposed.`를 출력했다.
- 해당 스택은 Drift의 `StreamQueryStore.markAsClosed`와 Riverpod provider dispose를 거친다. 위젯 제거, 스트림 취소, DB 종료 순서와 fake async 타이머 처리를 먼저 확인할 것. 원인 수정은 아직 하지 않았다.
- 실행은 92개 통과·2개 실패 출력 뒤 추가 진행 없이 대기하여 중단했다. 전체 완료 집계는 얻지 못했다. `--timeout 30s`만으로 이 대기가 종료되지 않았다.
- Claude의 마지막 커밋 직전 기록에는 92개 테스트 통과가 남아 있다. 이는 Task 15 미커밋 파일을 포함한 현재 전체 테스트 통과를 뜻하지 않는다.
- 학교 서버 로그인, 실기기 실행, Android 빌드는 이번 인수인계에서 수행하지 않았다.

## 다음 작업 순서

1. **Task 15를 마무리한다.** 먼저 실패하는 강좌 화면 테스트의 생명주기 정리를 수정한다. 정식 테스트는 학기만 override하고 실제 courses repository/token store 경로는 남겨 두므로, 네트워크 및 보안 저장소도 테스트 대역으로 격리할 필요가 있다. 진단용 테스트는 이미 일부 대역을 사용하지만 동일한 타이머 실패가 있다.
2. **강좌 화면 동작을 검증한다.** 코드 검토상 학기 변경 시 `_CourseList`가 같은 State를 재사용하면 `initState` 새로고침이 재실행되지 않을 수 있다. 짧거나 빈 목록에서도 당겨서 새로고침이 가능한지, 비동기 새로고침 중 화면을 닫았을 때 dispose된 ref를 쓰지 않는지도 확인한다. 이 항목들은 이번에 실행으로 재현한 버그가 아닌 검토 대상이다.
3. **Task 16:** 과제 provider, 캘린더/목록 화면, 이벤트 타일과 관련 테스트를 구현한다.
4. **Task 17:** 공지·설정 화면, 학기 선택/로그아웃, 인증 라우터, `lib/app.dart`, `lib/main.dart` 연결을 구현한다. 기존 카운터 테스트도 새 앱에 맞게 교체한다.
5. **최종 검증:** 정적 분석과 전체 테스트 후 Android 환경을 정리하고 로그인·세션 복원·캐시·로그아웃을 실기기에서 확인한다. 특히 현재 `_restoreSession()`은 재발급 실패 시 토큰을 지우므로, 계획의 '오프라인으로 앱 재시작 후 캐시 표시' 요구가 실제 인증 라우터와 함께 충족되는지 확인해야 한다.

## 이어받을 때 유지할 수정 사항

- `activeTermIdProvider`는 학기 갱신이 `Failure`로 실패해도 캐시 학기를 사용한다.
- `runRefresh`는 `Failure.message`를 표시하고 일반 `Exception`은 안내 문구로 처리하지만 프로그래밍 오류인 `Error`는 다시 던진다.
- 서버의 시간대 없는 날짜는 KST로 해석한다. Drift는 UTC 보존을 위해 `storeDateTimeAsText: true`를 사용한다.
- `http_mock_adapter` 등록 콜백은 요청 횟수 카운터가 아니다. 요청 횟수는 Dio 인터셉터에서 센다. 실패 테스트의 캐시에 TTL 메타가 있으면 네트워크 요청이 생략될 수 있다.
- 자동 로그인은 기본 OFF이며, ON일 때만 자격증명을 Secure Storage에 보관한다.

## Windows 실행 환경

Flutter SDK는 `C:\src\flutter`, Dart는 이번 확인 기준 3.13.2다. 현재 PowerShell PATH에서는 `flutter`가 바로 검색되지 않아 절대 경로를 사용했다. Windows 호스트 테스트는 프로젝트 루트의 무시된 `sqlite3.dll`과 `test/helpers/test_db.dart`를 사용한다.

```powershell
& 'C:\src\flutter\bin\flutter.bat' analyze --no-pub
& 'C:\src\flutter\bin\flutter.bat' test --no-pub test/features/courses/course_list_screen_test.dart --timeout 30s --reporter expanded
& 'C:\src\flutter\bin\flutter.bat' test --no-pub --timeout 30s --reporter expanded
```

Android SDK는 `C:\Users\barah\AppData\Local\Android\Sdk`다. 현재 디렉터리 목록에 `cmdline-tools`가 없다. 과거 기록에는 라이선스 미승인도 적혀 있으나 이번에 승인 상태를 재확인하지는 않았다. 실기기 검증 전에 `flutter doctor -v`로 확인한다.

재개 요청 예시: "docs/HANDOFF.md를 읽고 Task 15의 강좌 화면 테스트 실패부터 수정한 다음, 기존 계획의 Task 16~17을 이어서 구현해줘."
