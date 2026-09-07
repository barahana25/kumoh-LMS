enum NoticeKind {
  announcement('공지', 'announcements'),
  file('파일', 'files'),
  assignment('과제', 'assignments');

  const NoticeKind(this.label, this.tab);
  final String label;
  final String tab;
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
}

abstract interface class NoticeSink {
  Future<bool> permitted();
  Future<void> show(PendingNotice notice);
  Future<void> cancel(int id);
}
