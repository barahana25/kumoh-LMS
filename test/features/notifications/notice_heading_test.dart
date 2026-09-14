import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/notifications/data/notification_models.dart';

PendingNotice notice(NoticeKind kind, String courseName) => PendingNotice(
    id: 1,
    owner: '20240001',
    courseId: 10,
    courseName: courseName,
    kind: kind,
    title: '항목');

void main() {
  test('알림 제목은 분류를 앞에 붙인다', () {
    expect(notice(NoticeKind.announcement, '자료구조').heading, '[공지] 자료구조');
    expect(notice(NoticeKind.file, '자료구조').heading, '[새 파일] 자료구조');
    expect(notice(NoticeKind.assignment, '자료구조').heading, '[과제] 자료구조');
    expect(notice(NoticeKind.discussion, '자료구조').heading, '[토론] 자료구조');
  });

  test('강의명의 분반 번호는 제목에서 뗀다', () {
    expect(notice(NoticeKind.file, '자료구조-01').heading, '[새 파일] 자료구조');
  });
}
