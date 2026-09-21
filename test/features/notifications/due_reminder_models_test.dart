import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/notifications/data/due_reminder_models.dart';

void main() {
  final now = DateTime.utc(2026, 9, 21, 1, 1); // KST 10:01

  test('구간은 화면 배지와 같다', () {
    DueStage? at(Duration d) => dueStageFor(now.add(d), now);
    expect(at(const Duration(hours: 96)), isNull, reason: 'D-4');
    expect(at(const Duration(hours: 95)), DueStage.threeDays);
    expect(at(const Duration(hours: 72)), DueStage.threeDays);
    expect(at(const Duration(hours: 60)), isNull, reason: 'D-2');
    expect(at(const Duration(hours: 47)), DueStage.oneDay);
    expect(at(const Duration(hours: 24)), DueStage.oneDay);
    expect(at(const Duration(hours: 23)), DueStage.today);
    expect(at(const Duration(minutes: 1)), DueStage.today);
    expect(dueStageFor(now.subtract(const Duration(minutes: 1)), now), isNull);
  });

  group('대상 선별', () {
    Map<String, dynamic> row(Map<String, dynamic> extra) => {
          'id': 7,
          'name': '실습 과제',
          'due_at': '2026-09-23T01:40:00Z',
          'published': true,
          'submission_types': ['online_upload'],
          ...extra,
        };

    test('미제출 온라인 과제만 남긴다', () {
      final result = parseDueAssignments([
        row({}),
        row({'id': 8, 'submission': {'workflow_state': 'submitted', 'submitted_at': '2026-09-20T00:00:00Z'}}),
        row({'id': 9, 'submission': {'workflow_state': 'graded', 'submitted_at': null}}),
        row({'id': 10, 'due_at': null}),
        row({'id': 11, 'published': false}),
        row({'id': 12, 'locked_for_user': true}),
        row({'id': 13, 'submission_types': ['none']}),
        row({'id': 14, 'submission_types': ['on_paper', 'not_graded']}),
        row({'id': 15, 'submission_types': ['on_paper', 'online_text_entry']}),
        row({'id': 16, 'submission': {'workflow_state': 'unsubmitted', 'excused': true}}),
        row({'id': 17, 'name': 123}),
        row({'id': 18, 'submission_types': 'online_upload'}),
      ]);
      expect(result.map((a) => a.id), ['7', '9', '15', '17', '18'],
          reason: '점수만 있고 제출 시각이 없으면 미제출, 온라인 방식이 하나라도 있으면 대상');
      expect(result.first.name, '실습 과제');
      expect(result.first.dueAt, DateTime.utc(2026, 9, 23, 1, 40));
      expect(result.first.dueAt.isUtc, isTrue);
      expect(result.firstWhere((a) => a.id == '17').name, '과제',
          reason: '이름이 문자열이 아니어도 TypeError로 실행 전체가 멈추지 않는다');
    });
  });

  test('키에 마감 시각이 들어가 마감이 바뀌면 다른 키가 된다', () {
    final a = DueAssignment(id: '7', name: '과제', dueAt: DateTime.utc(2026, 9, 23, 1, 40));
    final moved = DueAssignment(id: '7', name: '과제', dueAt: DateTime.utc(2026, 9, 24, 1, 40));
    expect(dueReminderKey(3, a, DueStage.oneDay), '3:7:oneDay:2026-09-23T01:40:00.000Z');
    expect(dueReminderKey(3, a, DueStage.oneDay), isNot(dueReminderKey(3, moved, DueStage.oneDay)));
  });

  test('알림 ID는 키마다 고정이고 새 소식 ID와 겹치지 않는 범위다', () {
    const key = '3:7:oneDay:2026-09-23T01:40:00.000Z';
    final id = dueNotificationId(key);
    expect(id, dueNotificationId(key));
    expect(id, greaterThanOrEqualTo(0x40000000));
    expect(id, lessThanOrEqualTo(0x7FFFFFFF));
    expect(dueNotificationId('3:7:today:2026-09-23T01:40:00.000Z'), isNot(id));
  });

  test('문구는 한국 시간으로 적고 강의명의 분반 번호를 뺀다', () {
    final notice = DueNotice(
      id: 1,
      owner: 'student',
      courseId: 3,
      courseName: '알고리즘및실습-01',
      assignment: DueAssignment(
          id: '7', name: '실습 과제 #4 제출', dueAt: DateTime.utc(2026, 9, 23, 1, 40)),
      stage: DueStage.oneDay,
    );
    expect(notice.heading, '[마감 D-1] 알고리즘및실습');
    expect(notice.body, '실습 과제 #4 제출 · 9월 23일 (수) 10:40까지');
    expect(formatDueKst(DateTime.utc(2026, 9, 25, 14, 59)), '9월 25일 (금) 23:59');
  });
}
