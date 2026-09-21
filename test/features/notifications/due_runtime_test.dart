import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumoh_lms/features/notifications/data/due_reminder_store.dart';
import 'package:kumoh_lms/features/notifications/notification_runtime.dart';
import '../../helpers/test_db.dart';

void main() {
  test('마감 알림만 끈다', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    await DueReminderStore(db).enable('student');
    await NotificationRuntime.stopDue(db);
    expect((await DueReminderStore(db).settings())!.enabled, isFalse);
  });

  test('마감 알림을 누르면 강좌 과제 탭으로 간다', () {
    final destination = NotificationDestination.parse(jsonEncode({
      'owner': 'student',
      'courseId': 3,
      'courseName': '알고리즘및실습-01',
      'tab': 'assignments',
    }))!;
    final route = Uri.parse(destination.route);
    expect(route.path, '/courses/3');
    expect(route.queryParameters['tab'], 'assignments');
    expect(route.queryParameters['name'], '알고리즘및실습-01');
  });
}
