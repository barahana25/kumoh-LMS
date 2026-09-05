# Claude 작업 인수인계

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
