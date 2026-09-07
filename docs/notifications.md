# LMS 새 소식 알림

## 사용 방법

1. 자동 로그인을 켜고 로그인한다.
2. 설정 → **LMS 새 소식 알림**을 켜고 알림 권한을 허용한다.
3. 첫 확인은 강좌별 공지·파일·과제를 기준으로 저장한다. 이후 새 항목만 알린다.
4. **지금 확인**으로 즉시 조회하고 최근 시도와 처리 결과를 확인할 수 있다.

알림을 누르면 공지 목록 또는 해당 강좌의 파일·과제 탭으로 이동한다. 로그아웃하면 정기 작업·표시된 알림·기록을 정리한다. 다시 켜거나 새 강좌를 수강하면 기존 항목을 기준으로 시작한다.

## 범위와 실행 주기

- 한국 시간(KST) 기준 **00:01, 08:01~23:01**에 현재 학기 수강 강좌를 자동 확인한다. **01:00~07:59는 휴식하고 08:01에 재개**한다. `지금 확인` 및 활성화 직후 최초 기준 조회는 사용자가 요청한 동작이므로 휴식 시간에도 실행된다. 화면에서 선택한 과거 학기와는 독립적이다. 현재 기간에 해당하는 학기가 없으면 최신 학기를 사용한다.
- 새 ID만 감지한다. 동일 ID의 본문 수정, 삭제, 마감 임박 알림은 포함하지 않는다. 파일 본문은 다운로드하지 않는다.
- 숨김·잠금·미공개 항목과 공개 시각 전 공지는 제외한다.
- Android WorkManager의 단발 작업으로 다음 회차를 예약하고, 실행 시 다음 회차를 미리 등록한다. 이전 버전의 시간 간격 기준 정기 작업은 해제한다. iOS는 BGAppRefreshTask를 사용한다. 절전·네트워크·OS 정책으로 실제 확인이 늦어질 수 있어 예약한 분에 정확한 실행을 보장하지 않는다. 강제 종료 후에는 앱을 다시 열어야 할 수 있다. [Workmanager 공식 안내](https://docs.page/fluttercommunity/flutter_workmanager/quickstart)
- 지연된 작업은 현재 회차에서 한 번만 처리한다. 예를 들어 12:05에 실행됐어도 13:01 회차는 정상적으로 실행할 수 있다. 휴식 시간이나 매시 00분에 도착한 작업은 네트워크 조회 없이 건너뛴다. 앱을 켠 상태의 타이머도 같은 예약 계산을 사용한다.

## 구조

`lib/features/notifications/`에 데이터 수집, 기록, 비교, OS 알림, 설정 화면을 분리했다.

| 파일 | 역할 |
| --- | --- |
| `data/lms_notification_source.dart` | 독립 로그인 세션과 현재 강좌·Canvas 목록 조회 |
| `data/notification_store.dart` | 기준, 확인 ID, 미전송 알림, 실행 잠금 |
| `data/notification_poller.dart` | 새 항목 비교, 부분 실패, 재시도, 이어서 실행 |
| `notification_runtime.dart` | 백그라운드 진입점, 주기 등록, OS 알림과 탭 정보 |
| `presentation/notification_settings_section.dart` | 설정·수동 확인 |

학생 세션으로 `discussion_topics?only_announcements=true`, `files`, `assignments`를 조회한다. 관리자 webhook이나 외부 알림 서버는 사용하지 않는다. `per_page=100`과 `Link`를 따라 최대 100페이지까지 조회하며 다른 호스트·강좌로 향하는 링크는 거부한다. 중간 실패와 페이지 제한 초과 시 해당 목록의 기준을 갱신하지 않는다. [공지 API](https://canvas.instructure.com/doc/api/discussion_topics.html), [페이지 처리](https://canvas.instructure.com/doc/api/file.pagination.html)

화면 TTL 캐시를 사용하지 않으며 백그라운드 토큰과 쿠키는 메모리에만 둔다. 화면의 저장 토큰을 교체하지 않는다. 자동 로그인 자격증명이 없거나 인증에 실패하면 알림을 해제하고 재로그인을 안내한다. 서버의 일시적 실패는 다음 주기에 재시도한다.

DB v3에 `notification_settings`, `notification_baselines`, `notification_seen_items`, `notification_outbox`를 추가했다. 원자적 잠금과 설정 세대를 검사해 중복 실행과 로그아웃 후 늦은 응답을 처리한다. OS 알림 실패 시 같은 알림 ID로 재시도한다. Android는 약 4분, iOS는 약 20초의 작업 예산을 두고 완료한 목록 위치를 기록한다. 개별 네트워크 요청이나 OS의 강제 종료로 이 예산 내 완료가 보장되는 것은 아니다.

## 검증

알림 관련 27개 테스트를 포함해 전체 266개가 통과했다. 초기 기준, 세 종류의 새 항목, 낮은 ID, 중복 실행, 권한 거부, 계정 변경·로그아웃, 인증 실패, 전송 재시도, 작업 이어가기, DB 마이그레이션, 페이지 처리, 토큰 보존, 탭 경로를 검증한다. 예약 시각·자정 경계·새벽 휴식·08:01 재개·늦은 실행·수동 확인도 테스트한다.

Android 에뮬레이터에서 합성 데이터로 실제 세 종류의 알림 표시와 중복 방지, OS 작업 등록을 확인했다. 실제 학교 서버의 새 게시물 발생, 장시간 절전, iOS 빌드·실행은 아직 검증하지 않았다.

```powershell
& 'C:\src\flutter\bin\flutter.bat' analyze --no-pub
& 'C:\src\flutter\bin\flutter.bat' test --no-pub --reporter expanded
& 'C:\src\flutter\bin\flutter.bat' build apk --debug --no-pub
```

## 앱을 닫은 뒤의 실행

Android에는 매시 1분 단발 예약 외에 15분 주기의 독립 복구 작업도 등록한다. 복구 작업이 실행되면 다음 예약을 보충하고 현재 회차가 미처리일 때만 조회한다. 같은 회차에 반복 로그인하지 않으며 새벽 휴식 시간에는 크롤링하지 않는다. 알림 해제 시 두 종류의 예약을 모두 취소한다.

설정 → 백그라운드 실행 설정에서 앱 정보를 열고 배터리를 제한 없음으로 변경한다. 제조사 설정의 절전·초절전 앱에서도 제외한다. 최근 앱에서 밀어서 닫는 것과 설정의 강제 중지는 다르다. Doze에 의한 지연은 복구 작업에도 적용되므로 정각 실행은 보장하지 않는다. 휴대폰 전원이 꺼져 있거나 앱을 강제 중지한 상태에서는 기기 내 크롤링을 계속할 수 없다.

참고: https://developer.android.com/training/monitoring-device-state/doze-standby