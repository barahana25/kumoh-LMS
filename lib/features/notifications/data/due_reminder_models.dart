import '../../../core/time/due_days.dart';
import '../../canvas/data/canvas_api.dart' show isSubmitted;
import 'notification_models.dart';

/// 마감 알림을 보내는 구간. 화면 배지와 같은 이름을 쓴다.
enum DueStage {
  threeDays('D-3'),
  oneDay('D-1'),
  today('D-DAY');

  const DueStage(this.label);
  final String label;
}

/// [dueAt]까지 남은 시간이 알림 구간에 있으면 그 구간, 아니면 null.
DueStage? dueStageFor(DateTime dueAt, DateTime now) =>
    switch (dueDays(dueAt, now)) {
      3 => DueStage.threeDays,
      1 => DueStage.oneDay,
      0 => DueStage.today,
      _ => null,
    };

/// 마감 알림 대상이 될 수 있는 미제출 과제.
class DueAssignment {
  const DueAssignment(
      {required this.id, required this.name, required this.dueAt});
  final String id;
  final String name;

  /// UTC.
  final DateTime dueAt;
}

/// 앱에서 낼 수 없는 제출 방식. 이것뿐인 과제는 언제나 미제출로 보인다.
const _offlineSubmissionTypes = {'none', 'on_paper', 'not_graded'};

/// `/assignments?include[]=submission` 응답에서 마감 알림 대상만 고른다.
List<DueAssignment> parseDueAssignments(List<Map<String, dynamic>> rows) {
  final result = <DueAssignment>[];
  for (final row in rows) {
    if (row['published'] == false || row['locked_for_user'] == true) continue;
    final due = DateTime.tryParse('${row['due_at']}');
    if (due == null) continue;
    final types = (row['submission_types'] as List?)
            ?.map((e) => '$e')
            .toSet() ??
        const <String>{};
    if (types.isNotEmpty && types.every(_offlineSubmissionTypes.contains)) {
      continue;
    }
    if (isSubmitted(row['submission'])) continue;
    final id = row['id'];
    if (id == null || '$id'.isEmpty) continue;
    result.add(DueAssignment(
        id: '$id',
        name: row['name'] as String? ?? '과제',
        dueAt: due.toUtc()));
  }
  return result;
}

/// 한 과제·구간·마감 시각에 한 번만 보내기 위한 기록 키.
/// 마감이 바뀌면 키가 달라져 새 마감 기준으로 다시 알린다.
String dueReminderKey(int courseId, DueAssignment a, DueStage stage) =>
    '$courseId:${a.id}:${stage.name}:${a.dueAt.toUtc().toIso8601String()}';

/// 키마다 고정된 알림 ID. 같은 키로 다시 띄우면 알림을 덮어쓴다.
///
/// 새 소식 알림 ID(보낸 기록의 자동 증가 번호)와 겹치지 않게 0x40000000 위에
/// 둔다. 웹에서도 2^53을 넘지 않도록 30비트 안에서 섞는다.
int dueNotificationId(String key) {
  var hash = 0;
  for (final unit in key.codeUnits) {
    hash = (hash * 31 + unit) & 0x3FFFFFFF;
  }
  return 0x40000000 | hash;
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// '9월 23일 (수) 10:40'. 백그라운드 isolate에는 ko_KR 날짜 기호가 없어
/// intl을 쓰지 않고 한국 시간으로 직접 적는다.
String formatDueKst(DateTime dueAt) {
  final kst = dueAt.toUtc().add(const Duration(hours: 9));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${kst.month}월 ${kst.day}일 (${_weekdays[kst.weekday - 1]}) '
      '${two(kst.hour)}:${two(kst.minute)}';
}

/// 기기에 띄울 마감 알림 하나.
class DueNotice {
  const DueNotice(
      {required this.id,
      required this.owner,
      required this.courseId,
      required this.courseName,
      required this.assignment,
      required this.stage});
  final int id;
  final String owner;
  final int courseId;
  final String courseName;
  final DueAssignment assignment;
  final DueStage stage;

  /// '[마감 D-1] 알고리즘및실습'. 강의명 끝의 분반 번호는 뗀다.
  String get heading =>
      '[마감 ${stage.label}] ${courseName.replaceAll(RegExp(r'-\d+$'), '')}';

  /// '실습 과제 #4 제출 · 9월 23일 (수) 10:40까지'
  String get body => '${assignment.name} · ${formatDueKst(assignment.dueAt)}까지';
}

abstract interface class DueSource {
  Future<String> authenticate();
  Future<List<WatchedCourse>> courses();
  Future<List<DueAssignment>> dueAssignments(int courseId);
  void close();
}

abstract interface class DueSink {
  Future<bool> permitted();
  Future<void> showDue(DueNotice notice);
}
