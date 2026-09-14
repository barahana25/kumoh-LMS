enum NoticeKind {
  announcement('공지', 'announcements', '공지'),
  file('파일', 'files', '새 파일'),
  assignment('과제', 'assignments', '과제'),
  discussion('토론', 'discussions', '토론');

  const NoticeKind(this.label, this.tab, this.badge);
  final String label;
  final String tab;

  /// 기기 알림 제목 앞에 붙는 분류 표시. ex) [새 파일] 강의명
  final String badge;
}

class WatchedCourse {
  const WatchedCourse(this.id, this.name);
  final int id;
  final String name;
}

class WatchedItem {
  const WatchedItem(this.id, this.title);
  final String id;
  final String title;
}

abstract interface class NotificationSource {
  Future<String> authenticate();
  Future<List<WatchedCourse>> courses();
  Future<List<WatchedItem>> items(int courseId, NoticeKind kind);
  void close();
}

class PendingNotice {
  const PendingNotice(
      {required this.id,
      required this.owner,
      required this.courseId,
      required this.courseName,
      required this.kind,
      required this.title});
  final int id;
  final String owner;
  final int courseId;
  final String courseName;
  final NoticeKind kind;
  final String title;

  /// 기기 알림 제목. 분류를 앞에 붙이고 강의명의 분반 번호는 뗀다.
  String get heading =>
      '[${kind.badge}] ${courseName.replaceAll(RegExp(r'-\d+$'), '')}';
}

abstract interface class NoticeSink {
  Future<bool> permitted();
  Future<void> show(PendingNotice notice);
  Future<void> cancel(int id);
}
