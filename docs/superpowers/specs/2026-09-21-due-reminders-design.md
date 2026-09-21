# 미제출 과제 마감 알림 설계

작성일: 2026-09-21
범위: Android. 새 소식 알림([docs/notifications.md](../../notifications.md))의 매시 예약 위에 얹는다.

## 배경

지금 알림은 새로 올라온 공지·파일·과제·토론만 알린다. 문서에도 "마감 임박 알림은 포함하지 않는다"고 적혀 있다. 과제 화면에는 이미 `D-3`, `D-1`, `D-DAY` 배지가 있지만 앱을 열어야 보인다.

백그라운드 작업은 매시 01분(새벽 1~7시 휴식)에 강좌마다 `/courses/{id}/assignments`를 받고 있다. 여기에 `include[]=submission`을 붙이면 요청을 늘리지 않고 학생 본인의 제출 상태가 같이 온다. 제출 판정 함수 `isSubmitted()`도 이미 있다.

LINUS는 계정당 가장 최근 로그인 하나만 유효하다. 백그라운드가 로그인할 때마다 학교 홈페이지와 다른 기기 세션이 끊긴다. 마감 알림 때문에 매시 로그인이 늘어나면 안 된다.

## 결정 요약

| 항목 | 결정 |
|---|---|
| 알림 시점 | 화면 배지와 같은 구간. 구간에 들어선 뒤 08:01~23:01 사이 첫 회차에 보낸다 |
| 구간 | D-3 = 남은 72~96시간, D-1 = 24~48시간, D-day = 24시간 미만 |
| 켜고 끄기 | 설정에 "과제 마감 알림" 토글을 따로 둔다. 새 소식과 독립 |
| 로그인 | 매시 작업에서 한 번만 로그인하고 새 소식·마감이 같은 세션을 쓴다 |
| 중복 | 과제·구간·마감 시각 조합마다 한 번 |
| 공지 탭 내역 | 넣지 않는다 |
| 알림 채널 | `lms_due` "과제 마감"을 새로 만든다 |

## 동작

### 대상 과제

현재 학기 수강 강좌의 과제 가운데 아래를 모두 만족하는 것.

- `due_at`이 있다.
- 공개됐다(`published != false`).
- 잠기지 않았다(`locked_for_user != true`). 잠긴 과제는 학생이 낼 수 없다.
- 아직 내지 않았다(`!isSubmitted(submission)`). 교수가 점수만 넣은 경우는 미제출로 본다(기존 규칙).
- 온라인으로 낼 수 있다. `submission_types`가 `none`, `on_paper`, `not_graded`뿐인 과제는 제외한다. 이런 과제는 앱에서 영원히 미제출이라 매번 재촉하게 된다.

### 구간

남은 시간 `r = due_at - now`로 정한다. 화면 배지(`dueRelative`)와 같은 계산이다.

| 알림 | 조건 | 화면 배지 |
|---|---|---|
| D-3 | 72시간 ≤ r < 96시간 | `D-3` |
| D-1 | 24시간 ≤ r < 48시간 | `D-1` |
| D-day | 0 < r < 24시간 | `D-DAY` |
| 없음 | 그 밖(D-2, D-4 이상, 마감 지남) | |

마감 알림은 **08:01~23:01 회차에서만** 보낸다. 새 소식은 00:01 회차도 쓰지만, 마감은 대부분 23:59라 구간 경계가 자정 직전에 몰린다. 00:01에 보내면 과제마다 알림 세 개가 전부 한밤중에 울린다.

그래도 놓치는 알림은 없다. 23:01 회차 다음은 08:01 회차라 쉬는 틈이 9시간이고, 구간 폭은 24시간이다. 어느 구간이든 08:01~23:01 회차가 적어도 하나 들어 있다.

예: 마감 9/25(금) 23:59

| 알림 | 구간 | 보내는 회차 |
|---|---|---|
| D-3 | 9/21 23:59 ~ 9/22 23:59 | 9/22 08:01 |
| D-1 | 9/23 23:59 ~ 9/24 23:59 | 9/24 08:01 |
| D-day | 9/24 23:59 ~ 9/25 23:59 | 9/25 08:01 |

예: 마감 9/25(금) 10:00

| 알림 | 구간 | 보내는 회차 |
|---|---|---|
| D-3 | 9/21 10:00 ~ 9/22 10:00 | 9/21 10:01 |
| D-1 | 9/23 10:00 ~ 9/24 10:00 | 9/23 10:01 |
| D-day | 9/24 10:00 ~ 9/25 10:00 | 9/24 10:01 |

### 규칙

- 매 회차 대상 과제의 현재 구간을 계산하고, 보낸 적 없는 `(강좌, 과제, 구간, 마감 시각)`이면 알린다.
- 제출하면 다음 회차부터 대상에서 빠지므로 이후 구간은 가지 않는다.
- 처음 켰을 때 이미 D-1 구간이면 D-1만 간다. 지나간 구간은 다시 현재 구간이 되지 않으므로 따로 처리할 필요가 없다.
- 교수가 마감을 바꾸면 키의 마감 시각이 달라져 새 마감 기준으로 다시 알린다.
- 조회 시각 규칙(매시 01분, 새벽 1~7시 휴식, 앱 타이머)은 새 소식과 같다. 단, 00:01 회차에서는 보내지 않는다.

### 알림 모양

- 제목: `[마감 D-1] 알고리즘및실습` — 강의명 끝의 분반 번호(`-01`)는 뗀다(기존 `PendingNotice.heading`과 같은 규칙).
- 본문: `실습 과제 #4 제출 · 9월 23일 (수) 10:40까지`
- 누르면 해당 강좌의 과제 탭으로 간다(기존 과제 알림과 같은 경로).
- Android 채널 `lms_due` "과제 마감". OS 설정에서 새 소식과 따로 끌 수 있다.

## 구조

| 파일 | 역할 |
|---|---|
| `lib/core/time/due_days.dart` (신규) | `dueDays(dueAt, now)` → 남은 일수(24시간 미만이면 0, 지났으면 null). 화면 배지와 알림이 같이 쓴다 |
| `lib/features/notifications/data/due_reminder_models.dart` (신규) | `DueStage` 구간 판정, 대상 선별, 기록 키, 알림 ID·문구. 모두 순수 함수 |
| `lib/features/notifications/data/due_reminder.dart` (신규) | 러너 `DueReminder` |
| `lib/features/notifications/data/due_reminder_store.dart` (신규) | 설정 행, 보낸 기록, 실행 잠금 |
| `lib/features/notifications/data/shared_lms_session.dart` (신규) | 한 번만 로그인하는 감싸개. 새 소식·마감 러너가 같은 인스턴스를 받는다 |
| `lib/features/notifications/data/lms_notification_source.dart` | `dueAssignments(courseId)` 추가. `/assignments?include[]=submission`을 받아 `DueAssignment`로 만든다 |
| `lib/features/notifications/notification_runtime.dart` | `hasBackgroundWork`·`checkAll`에 마감 알림 추가, 채널 `lms_due`, 알림 탭 경로 |
| `lib/features/notifications/presentation/notification_settings_section.dart` | "과제 마감 알림" 토글과 상태 줄 |
| `lib/features/notifications/presentation/notification_setup.dart` | `enableDueReminders()` — 켜는 절차(자격증명 확인 → 권한 → 저장 → 예약) |
| `lib/features/assignments/presentation/widgets/event_tile.dart` | `dueRelative()`가 `dueDays()`를 쓰게 바꾼다. 표시 결과는 같다 |
| `lib/features/auth/presentation/auth_controller.dart` | 로그인·로그아웃 때 마감 알림을 먼저 끈다. 그래야 `NotificationRuntime.stop()`이 남은 예약을 취소한다 |
| `lib/core/storage/db/tables.dart`, `app_database.dart` | DB v9 |

### DB v9

- `due_reminder_settings`: `id`, `owner`, `generation`, `enabled`, `status`, `last_attempt`, `last_success`, `lease`, `lease_until`. `last_attempt`로 같은 회차에 두 번 돌지 않게 막는다. 15분 복구 작업과 앱 타이머가 같은 회차에 여러 번 부르므로, 이게 없으면 부를 때마다 로그인이 늘어난다.
- `due_reminder_sent`: `key`(기본키, `강좌:과제:구간:마감시각`), `sent_at`

로그아웃 때 `db.wipe()`가 모든 테이블을 비우므로 따로 지울 코드는 없다. v8→v9 마이그레이션 단계를 반드시 추가한다.

### 한 번만 로그인하기

`SharedLmsSession`은 `LmsNotificationSource` 하나를 감싼다.

- `authenticate()`, `courses()`: 첫 호출의 `Future`를 기억해 두고 이후에는 같은 결과(실패 포함)를 돌려준다.
- `close()`: 아무것도 하지 않는다. 실제 종료는 `checkAll`이 끝날 때 한 번 한다.
- `items()`, `dueAssignments()`는 그대로 넘긴다.

과제 목록 응답도 나눠 쓴다. `LmsNotificationSource`가 강좌별 `/assignments?include[]=submission` 응답을 한 실행 동안 기억해 두고, 새 과제 감지(`items(assignment)`)와 마감 알림(`dueAssignments()`)이 같은 응답을 쓴다. 둘 다 켜 두어도 과제 목록 요청은 늘지 않는다.

`NotificationPoller`는 지금처럼 `sourceFactory()`로 소스를 받고 `authenticate()`·`close()`를 부른다. 공유 감싸개를 넘기고, 부르는 쪽이 미리 잡은 잠금을 `reserved`로 받는다.

`checkAll`의 흐름(`runSharedAlerts`):

```
try {
  알림 기능 준비(sink.initialize) — 새 소식이나 마감 중 하나라도 켜져 있으면 잠금을 잡기 전에 한 번
  새 소식 잠금 = 새 소식 켜짐 ? notices.acquire(now) : null
  마감 잠금   = 마감 켜짐 && 발송 회차 ? due.acquire(now, 회차) : null
  if (둘 다 null) 끝 — 소스를 열지 않고 로그인하지 않는다
  공유 세션 = SharedLmsSession(...)
  try {
    새 소식 잠금 → poller.run(reserved: 새 소식 잠금, sourceFactory: () => 공유 세션)
    마감 잠금   → dueReminder.run(reserved: 마감 잠금, source: 공유 세션)
  } finally {
    공유 세션.dispose()
  }
} finally {
  자동 다운로드(지금과 같음, 별도 로그인)
}
```

두 잠금을 네트워크 전에 잡는 이유: 잠금을 러너마다 따로 잡으면, 한 작업이 새 소식을 확인하는 동안 같은 회차의 복구 작업이 새 소식 잠금은 못 잡고 마감 잠금만 잡아 제 세션으로 한 번 더 로그인한다. 네트워크 전에 한꺼번에 잡아도 이 문제가 완전히 없어지지는 않는다. 두 작업이 수 밀리초 안에 동시에 시작해 한쪽이 새 소식 잠금을, 다른 쪽이 마감 잠금을 먼저 잡으면 그 회차에 한 번 더 로그인한다. 드물고 그 회차에 최대 한 번으로 그친다.

설정 화면의 "지금 확인"은 지금처럼 새 소식만 따로 돈다. 마감 알림에는 수동 버튼을 두지 않는다.

### 러너 `DueReminder.run()`

1. 휴식 시간이거나 00:01 회차면 끝.
2. 자체 잠금(`lease`)을 잡는다. 이미 돌고 있으면 끝.

   `runSharedAlerts`가 미리 잡은 잠금을 `reserved`로 넘기면 1-2단계는 건너뛰고 바로 3단계부터 시작한다.
3. 알림 권한이 없으면 상태만 남기고 끝.
4. `authenticate()` → 계정이 설정의 `owner`와 다르면 멈추고 다시 켜라고 안내.
5. `courses()`로 현재 강좌를 받는다.
6. 강좌마다 `dueAssignments()` → 대상 선별 → 현재 구간 → 보낸 적 없는 키면 알림을 띄우고 기록한다.
7. 상태 문구와 마지막 성공 시각을 남긴다.

알림 ID는 키의 고정 해시를 쓰되 기존 새 소식 알림 ID(보낸 기록의 자동 증가 번호)와 겹치지 않는 범위에 둔다. 띄운 뒤 기록 저장이 실패하면 다음 회차에 같은 ID로 다시 띄워 덮어쓴다. 알림이 두 개 쌓이지 않는다.

## 오류 처리

| 상황 | 처리 |
|---|---|
| 자동 로그인 자격증명이 없거나 로그인 거부 | 토글을 끄고 "자동 로그인을 켜고 다시 로그인해 주세요" |
| 계정이 바뀜 | 멈추고 "계정이 변경되었습니다. 마감 알림을 다시 켜 주세요" |
| 한 강좌 조회 실패 | 그 강좌만 건너뛰고 다음 회차에 다시 본다 |
| 학교 서버 연결 실패 | 상태만 남기고 다음 회차에 다시 본다 |
| 중복 실행 | 잠금으로 막는다 |
| 새 소식 poller가 로그인에서 실패 | 공유 세션의 같은 실패를 마감 러너도 받는다. 같은 규칙으로 처리한다 |

오류 문구에 자격증명, 서버 응답 본문, 네이티브 메시지를 넣지 않는다(기존 규칙).

## 테스트

- `dueDays` / `DueStage`: 96시간, 72시간, 48시간, 24시간, 0, 지난 마감 경계.
- `dueRelative`가 바뀐 뒤에도 기존 배지 테스트가 그대로 통과한다.
- 대상 선별: 미제출만, 점수만 있는 제출은 미제출, `none`/`on_paper`/`not_graded` 제외, 잠김·비공개 제외, 마감 없음 제외.
- 러너: 구간 진입 시 알림, 00:01 회차 건너뜀, 같은 구간 재실행 시 중복 없음, 제출 후 다음 구간 없음, 처음 켜면 현재 구간만, 마감 변경 시 재알림, 휴식 시간 건너뜀, 인증 실패 시 해제, 계정 변경 시 멈춤, 한 강좌 실패가 다른 강좌를 막지 않음.
- 공유 세션: 새 소식과 마감이 둘 다 켜져 있어도 `authenticate()`가 한 번만 로그인한다. 하나만 켜져 있어도 동작한다.
- DB v8→v9 마이그레이션.
- 설정 토글 위젯: 지원 안 하는 기기에서 숨김, 켜기(자격증명 없음), 끄기, 상태 줄. 권한 요청과 켜기 성공 경로는 알림 플러그인이 필요해 실기기에서 확인한다.

## 문서

`docs/notifications.md`의 "마감 임박 알림은 포함하지 않는다"를 고치고 마감 알림 절을 추가한다.

## 범위 밖

- 로그인 직후 첫 실행 안내 화면(`background_setup_screen.dart`)에 마감 토글을 넣는 것.
- 알림 시각이나 구간(D-7 등)을 사용자가 고르는 것.
- 자동 다운로드까지 로그인을 공유하는 것. 다운로드는 지금처럼 따로 로그인한다.
- 마감 알림 "지금 확인" 버튼.
- iOS.
