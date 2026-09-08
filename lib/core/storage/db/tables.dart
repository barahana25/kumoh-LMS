import 'package:drift/drift.dart';

class DownloadSettings extends Table {
  IntColumn get id => integer()();
  TextColumn get owner => text()();
  TextColumn get treeUri => text()();
  TextColumn get folderName => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();
  TextColumn get generation => text()();
  TextColumn get lease => text().nullable()();
  IntColumn get leaseUntil => integer().nullable()();
  IntColumn get lastAttempt => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('저장 폴더를 선택해 주세요.'))();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DownloadedFiles extends Table {
  TextColumn get owner => text()();
  TextColumn get treeUri => text()();
  IntColumn get courseId => integer()();
  TextColumn get fileId => text()();
  TextColumn get documentUri => text()();
  @override
  Set<Column<Object>> get primaryKey => {owner, treeUri, courseId, fileId};
}

/// 백그라운드 isolate와 UI가 함께 읽는 알림 설정과 실행 잠금.
class NotificationSettings extends Table {
  IntColumn get id => integer()();
  TextColumn get owner => text()();
  TextColumn get generation => text()();
  BoolColumn get enabled => boolean()();
  IntColumn get lastAttempt => integer().nullable()();
  IntColumn get lastSuccess => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('아직 확인하지 않았습니다.'))();
  TextColumn get lease => text().nullable()();
  IntColumn get cursor => integer().withDefault(const Constant(0))();
  IntColumn get leaseUntil => integer().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class NotificationBaselines extends Table {
  TextColumn get scope => text()();
  @override
  Set<Column<Object>> get primaryKey => {scope};
}

class NotificationSeenItems extends Table {
  TextColumn get scope => text()();
  TextColumn get itemId => text()();
  @override
  Set<Column<Object>> get primaryKey => {scope, itemId};
}

/// OS 알림을 보낸 뒤에만 지운다. 재시도해도 같은 id로 알림을 대체한다.
class NotificationOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get generation => text()();
  TextColumn get owner => text()();
  IntColumn get courseId => integer()();
  TextColumn get courseName => text()();
  TextColumn get kind => text()();
  TextColumn get title => text()();
  TextColumn get itemId => text().withDefault(const Constant(''))();
  DateTimeColumn get detectedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get delivered => boolean().withDefault(const Constant(false))();
}

/// 학기. id는 서버(LINUS)의 termId를 그대로 쓴다.
@DataClassName('TermRow')
class Terms extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  DateTimeColumn get startAt => dateTime().nullable()();
  DateTimeColumn get endAt => dateTime().nullable()();
  TextColumn get workflowState => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 수강 강좌. teachers 배열은 표시용 문자열로 평탄화해 저장한다.
@DataClassName('CourseRow')
class Courses extends Table {
  IntColumn get id => integer()();
  IntColumn get termId => integer()();
  TextColumn get name => text()();
  TextColumn get courseCode => text()();
  TextColumn get institution => text().withDefault(const Constant(''))();
  TextColumn get teacherNames => text().withDefault(const Constant(''))();
  IntColumn get totalStudents => integer().withDefault(const Constant(0))();
  TextColumn get workflowState => text().withDefault(const Constant(''))();
  TextColumn get courseFormat => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 캘린더 이벤트(과제 마감 포함). id는 'assignment_7931' 형태의 문자열이다.
@DataClassName('CalendarEventRow')
class CalendarEvents extends Table {
  TextColumn get id => text()();
  IntColumn get termId => integer()();
  IntColumn get courseId => integer().nullable()();
  TextColumn get contextName => text().withDefault(const Constant(''))();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  DateTimeColumn get startAt => dateTime().nullable()();
  DateTimeColumn get endAt => dateTime().nullable()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get htmlUrl => text().withDefault(const Constant(''))();
  TextColumn get workflowState => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 공지사항.
@DataClassName('AnnouncementRow')
class Announcements extends Table {
  TextColumn get id => text()();
  IntColumn get termId => integer()();
  IntColumn get courseId => integer().nullable()();
  TextColumn get contextName => text().withDefault(const Constant(''))();
  TextColumn get title => text()();
  TextColumn get message => text().withDefault(const Constant(''))();
  TextColumn get authorName => text().withDefault(const Constant(''))();
  DateTimeColumn get postedAt => dateTime().nullable()();
  TextColumn get htmlUrl => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 컬렉션 단위 마지막 조회 시각. TTL 판정에 쓴다.
class CacheMetaEntries extends Table {
  TextColumn get key => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// 강좌 상세 탭 캐시. 원본 JSON을 그대로 보관한다.
/// 탭마다 테이블을 두면 문서 없는 API의 응답이 바뀔 때마다 마이그레이션이
/// 필요하지만, 이 데이터는 테이블 간 조회가 없어 그럴 이유가 없다.
class CanvasCacheEntries extends Table {
  TextColumn get key => text()();
  TextColumn get payload => text()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
