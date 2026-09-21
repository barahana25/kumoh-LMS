import 'due_reminder_models.dart';
import 'notification_models.dart';

/// 새 소식 알림과 마감 알림이 함께 쓰는 학교 서버 소스.
abstract interface class LmsSource implements NotificationSource, DueSource {}

/// 매시 작업에서 한 번만 로그인하게 하는 감싸개.
///
/// LINUS는 계정당 가장 최근 로그인 하나만 유효해서, 백그라운드가 로그인할
/// 때마다 학교 홈페이지와 다른 기기 세션이 끊긴다. 새 소식 poller와 마감
/// 러너가 같은 인스턴스를 받아 로그인과 강좌 목록을 나눠 쓴다.
class SharedLmsSession implements LmsSource {
  SharedLmsSession(this._inner);
  final LmsSource _inner;
  Future<String>? _login;
  Future<List<WatchedCourse>>? _courses;

  /// 첫 호출 결과(실패 포함)를 그대로 돌려준다. 로그인은 처음 필요할 때 한다.
  @override
  Future<String> authenticate() => _login ??= _inner.authenticate();

  @override
  Future<List<WatchedCourse>> courses() => _courses ??= _inner.courses();

  @override
  Future<List<WatchedItem>> items(int courseId, NoticeKind kind) =>
      _inner.items(courseId, kind);

  @override
  Future<List<DueAssignment>> dueAssignments(int courseId) =>
      _inner.dueAssignments(courseId);

  /// 러너가 끝날 때 부르는 close는 무시한다. 다른 러너가 아직 쓴다.
  @override
  void close() {}

  /// 작업이 모두 끝나면 부른다.
  void dispose() => _inner.close();
}
