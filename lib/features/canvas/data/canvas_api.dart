import 'package:dio/dio.dart';

import '../../../core/error/failure.dart';
import '../../auth/data/auth_api.dart' show throwAsFailure;

/// `RequestOptions.extra`에 두는 재시도 표시. 무한 재브릿지를 막는다.
const String kCanvasRetryFlag = 'canvas_retry';

/// 강좌가 실제로 노출하는 탭 하나.
class CourseTab {
  const CourseTab({
    required this.id,
    required this.label,
    required this.position,
    this.externalUrl,
  });

  final String id;
  final String label;
  final int position;

  /// 외부 도구 탭이면 그 URL. 네이티브로 그릴 수 없어 웹뷰로 위임한다.
  final String? externalUrl;

  bool get isExternal => externalUrl != null;
}


/// Canvas 과제 하나.
class CanvasAssignment {
  const CanvasAssignment({
    required this.id,
    required this.name,
    this.dueAt,
    this.pointsPossible,
    this.htmlUrl = '',
  });

  final int id;
  final String name;
  final DateTime? dueAt;
  final num? pointsPossible;
  final String htmlUrl;
}

/// 내 제출 상태.
class CanvasSubmission {
  const CanvasSubmission({
    required this.assignmentId,
    required this.submitted,
    required this.missing,
    required this.late,
    this.score,
    this.submittedAt,
  });

  final int assignmentId;
  final bool submitted;
  final bool missing;
  final bool late;
  final num? score;
  final DateTime? submittedAt;
}

DateTime? _canvasDate(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toUtc();
}


/// 강의실(모듈) 한 주차.
class CanvasModule {
  const CanvasModule({
    required this.id,
    required this.name,
    required this.position,
    required this.itemsCount,
    required this.state,
  });

  final int id;
  final String name;
  final int position;
  final int itemsCount;
  final String state;

  bool get completed => state == 'completed';
  bool get locked => state == 'locked';
}

/// 강의자료실 파일.
class CanvasFile {
  const CanvasFile({
    required this.id,
    required this.displayName,
    required this.locked,
    this.contentType = '',
    this.sizeBytes,
    this.url = '',
  });

  final int id;
  final String displayName;
  final bool locked;
  final String contentType;
  final int? sizeBytes;
  final String url;
}

/// 강좌 구성원.
class CanvasPerson {
  const CanvasPerson({
    required this.userId,
    required this.name,
    required this.enrollmentType,
  });

  final int userId;
  final String name;
  final String enrollmentType;

  bool get isTeacher =>
      enrollmentType == 'TeacherEnrollment' || enrollmentType == 'TaEnrollment';
}

/// 그룹.
class CanvasGroup {
  const CanvasGroup({
    required this.id,
    required this.name,
    required this.membersCount,
  });

  final int id;
  final String name;
  final int membersCount;
}

/// 이 강좌에서의 내 성적.
class CanvasGrade {
  const CanvasGrade({
    this.currentScore,
    this.currentGrade,
    this.finalScore,
    this.finalGrade,
  });

  final num? currentScore;
  final String? currentGrade;
  final num? finalScore;
  final String? finalGrade;

  bool get isEmpty =>
      currentScore == null &&
      currentGrade == null &&
      finalScore == null &&
      finalGrade == null;

  /// 채점된 성적이 실제로 공개됐는가.
  ///
  /// Canvas의 final_score는 아직 채점하지 않은 과제를 0으로 계산한 값이라
  /// 학기 초에는 거의 항상 0이다. 이걸 "최종 성적 0점"으로 보여주면 학생이
  /// F를 받은 것으로 오해한다. 채점 여부는 current 쪽으로만 판단한다.
  bool get hasPublishedGrade => currentScore != null || currentGrade != null;
}

/// 토론 주제.
class CanvasDiscussion {
  const CanvasDiscussion({
    required this.id,
    required this.title,
    required this.replyCount,
    this.postedAt,
    this.htmlUrl = '',
  });

  final int id;
  final String title;
  final int replyCount;
  final DateTime? postedAt;
  final String htmlUrl;
}

/// 모듈(주차) 안의 항목 하나. 파일·과제·페이지·토론 등이 섞여 있다.
class CanvasModuleItem {
  const CanvasModuleItem({
    required this.id,
    required this.title,
    required this.type,
    this.htmlUrl = '',
    this.contentId,
    this.indent = 0,
  });

  final int id;
  final String title;
  final String type;
  final String htmlUrl;
  final int? contentId;
  final int indent;

  bool get isFile => type == 'File' && contentId != null;

  /// 파일은 WebView로 열면 빈 화면이 된다. 내려받아 기기 뷰어로 넘긴다.
  String get downloadUrl =>
      'https://canvas.kumoh.ac.kr/files/$contentId/download?download_frd=1';

  /// SubHeader는 내용이 아니라 목록의 소제목이라 누를 것이 없다.
  bool get isOpenable => isFile || (type != 'SubHeader' && htmlUrl.isNotEmpty);
}

/// Canvas 세션이 끊겼을 때 다시 다리를 건너고 원요청을 재시도한다.
///
/// Canvas는 세션이 만료되면 401을 준다. [reBridge]는 single-flight이므로
/// 동시에 만료를 만난 요청들이 다리를 여러 번 건너지 않는다.
Interceptor canvasSessionInterceptor({
  required Dio dio,
  required Future<void> Function() reBridge,
  Future<void> Function()? ensureSession,
}) {
  Future<void> recover(
    RequestOptions options,
    void Function(Response<dynamic>) resolve,
    void Function(DioException) reject,
  ) async {
    options.extra[kCanvasRetryFlag] = true;
    try {
      await reBridge();
      resolve(await dio.fetch<dynamic>(options));
    } on Object catch (e) {
      reject(DioException(
        requestOptions: options,
        error: e is Failure ? e : const AuthFailure(),
      ));
    }
  }

  bool shouldHandle(RequestOptions o, int? status) =>
      status == 401 && o.extra[kCanvasRetryFlag] != true;

  return InterceptorsWrapper(
    onRequest: (options, handler) async {
      // 첫 요청 전에 다리를 건너 둔다. 401을 기다리면 사용자가 매번
      // 실패 왕복을 한 번씩 겪는다.
      if (ensureSession != null) {
        try {
          await ensureSession();
        } on Object catch (e) {
          handler.reject(
            DioException(requestOptions: options, error: e),
            true,
          );
          return;
        }
      }
      handler.next(options);
    },
    onResponse: (response, handler) async {
      if (!shouldHandle(response.requestOptions, response.statusCode)) {
        handler.next(response);
        return;
      }
      await recover(response.requestOptions, handler.resolve, handler.reject);
    },
    onError: (err, handler) async {
      if (!shouldHandle(err.requestOptions, err.response?.statusCode)) {
        handler.next(err);
        return;
      }
      await recover(err.requestOptions, handler.resolve, handler.reject);
    },
  );
}

/// Canvas REST API의 전송 계층.
///
/// 응답 해석은 아래 순수 함수들이 맡는다. 캐시가 원본 JSON을 보관했다가
/// 나중에 같은 함수로 해석해야 하므로, 받아오는 일과 해석하는 일을 나눈다.
class CanvasApi {
  CanvasApi(this._dio);
  final Dio _dio;

  Future<Object?> getRaw(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get<Object?>(path, queryParameters: query);
      return res.data;
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }

  Future<List<CourseTab>> fetchTabs(int courseId) async =>
      parseTabs(await getRaw('/courses/$courseId/tabs'));

  Future<List<CanvasAssignment>> fetchAssignments(int courseId) async =>
      parseAssignments(await getRaw(
        '/courses/$courseId/assignments',
        query: const {'per_page': 50, 'order_by': 'due_at'},
      ));

  Future<Map<int, CanvasSubmission>> fetchSubmissions(int courseId) async =>
      parseSubmissions(await getRaw(
        '/courses/$courseId/students/submissions',
        query: const {'per_page': 50, 'student_ids[]': 'self'},
      ));

  Future<String?> fetchSyllabus(int courseId) async =>
      parseSyllabus(await getRaw(
        '/courses/$courseId',
        query: const {'include[]': 'syllabus_body'},
      ));

  Future<List<CanvasModule>> fetchModules(int courseId) async =>
      parseModules(await getRaw(
        '/courses/$courseId/modules',
        query: const {'per_page': 50},
      ));

  Future<List<CanvasFile>> fetchFiles(int courseId) async =>
      parseFiles(await getRaw(
        '/courses/$courseId/files',
        query: const {'per_page': 50, 'sort': 'created_at', 'order': 'desc'},
      ));

  Future<List<CanvasPerson>> fetchPeople(int courseId) async =>
      parsePeople(await getRaw(
        '/courses/$courseId/enrollments',
        query: const {'per_page': 100},
      ));

  Future<List<CanvasGroup>> fetchGroups(int courseId) async =>
      parseGroups(await getRaw(
        '/courses/$courseId/groups',
        query: const {'per_page': 50},
      ));

  Future<CanvasGrade?> fetchMyGrade(int courseId) async => parseMyGrade(
        await getRaw(
          '/users/self/enrollments',
          query: const {'per_page': 100, 'state[]': 'active'},
        ),
        courseId,
      );

  Future<List<CanvasModuleItem>> fetchModuleItems(
    int courseId,
    int moduleId,
  ) async =>
      parseModuleItems(await getRaw(
        '/courses/$courseId/modules/$moduleId/items',
        query: const {'per_page': 100},
      ));

  Future<String?> fetchFrontPage(int courseId) async =>
      parseFrontPage(await getRaw('/courses/$courseId/front_page'));

  Future<List<CanvasDiscussion>> fetchDiscussions(int courseId) async =>
      parseDiscussions(await getRaw(
        '/courses/$courseId/discussion_topics',
        query: const {'per_page': 50},
      ));
}

// ---------- 순수 파싱 ----------
//
// 네트워크에서 막 받은 JSON이든, 캐시에서 꺼낸 JSON이든 같은 함수로 해석한다.

List<Map<String, dynamic>> _asList(Object? body) {
  if (body is! List) throw const ParseFailure();
  return body.cast<Map<String, dynamic>>();
}

List<CourseTab> parseTabs(Object? json) => _asList(json)
    .where((t) => t['hidden'] != true)
    .map((t) => CourseTab(
          id: t['id'] as String? ?? '',
          label: t['label'] as String? ?? '',
          position: (t['position'] as num?)?.toInt() ?? 0,
          externalUrl: (t['type'] == 'external') ? t['url'] as String? : null,
        ))
    .where((t) => t.id.isNotEmpty && !t.isExternal)
    .toList()
  ..sort((a, b) => a.position.compareTo(b.position));

List<CanvasAssignment> parseAssignments(Object? json) => _asList(json)
    .where((a) => a['published'] != false)
    .map((a) => CanvasAssignment(
          id: (a['id'] as num?)?.toInt() ?? 0,
          name: a['name'] as String? ?? '',
          dueAt: _canvasDate(a['due_at']),
          pointsPossible: a['points_possible'] as num?,
          htmlUrl: a['html_url'] as String? ?? '',
        ))
    .toList();

Map<int, CanvasSubmission> parseSubmissions(Object? json) => {
      for (final s in _asList(json))
        (s['assignment_id'] as num?)?.toInt() ?? 0: CanvasSubmission(
          assignmentId: (s['assignment_id'] as num?)?.toInt() ?? 0,
          submitted:
              s['workflow_state'] != 'unsubmitted' && s['submitted_at'] != null,
          missing: s['missing'] == true,
          late: s['late'] == true,
          score: s['score'] as num?,
          submittedAt: _canvasDate(s['submitted_at']),
        ),
    };

String? parseSyllabus(Object? json) {
  if (json is! Map) throw const ParseFailure();
  final syllabus = json['syllabus_body'] as String?;
  return (syllabus == null || syllabus.trim().isEmpty) ? null : syllabus;
}

List<CanvasModule> parseModules(Object? json) => _asList(json)
    .map((m) => CanvasModule(
          id: (m['id'] as num?)?.toInt() ?? 0,
          name: m['name'] as String? ?? '',
          position: (m['position'] as num?)?.toInt() ?? 0,
          itemsCount: (m['items_count'] as num?)?.toInt() ?? 0,
          state: m['state'] as String? ?? '',
        ))
    .toList()
  ..sort((a, b) => a.position.compareTo(b.position));

List<CanvasFile> parseFiles(Object? json) => _asList(json)
    .map((f) => CanvasFile(
          id: (f['id'] as num?)?.toInt() ?? 0,
          displayName: f['display_name'] as String? ?? '',
          locked: f['locked_for_user'] == true,
          contentType: f['content-type'] as String? ?? '',
          sizeBytes: (f['size'] as num?)?.toInt(),
          url: f['url'] as String? ?? '',
        ))
    .toList();

List<CanvasPerson> parsePeople(Object? json) => _asList(json).map((e) {
      final user = (e['user'] as Map?) ?? const {};
      return CanvasPerson(
        userId: (user['id'] as num?)?.toInt() ?? 0,
        name: user['name'] as String? ?? '',
        enrollmentType: e['type'] as String? ?? '',
      );
    }).toList();

List<CanvasGroup> parseGroups(Object? json) => _asList(json)
    .map((g) => CanvasGroup(
          id: (g['id'] as num?)?.toInt() ?? 0,
          name: g['name'] as String? ?? '',
          membersCount: (g['members_count'] as num?)?.toInt() ?? 0,
        ))
    .toList();

CanvasGrade? parseMyGrade(Object? json, int courseId) {
  for (final e in _asList(json)) {
    if ((e['course_id'] as num?)?.toInt() != courseId) continue;
    final g = (e['grades'] as Map?) ?? const {};
    return CanvasGrade(
      currentScore: g['current_score'] as num?,
      currentGrade: g['current_grade'] as String?,
      finalScore: g['final_score'] as num?,
      finalGrade: g['final_grade'] as String?,
    );
  }
  return null;
}

List<CanvasDiscussion> parseDiscussions(Object? json) => _asList(json)
    .map((d) => CanvasDiscussion(
          id: (d['id'] as num?)?.toInt() ?? 0,
          title: d['title'] as String? ?? '',
          replyCount: (d['discussion_subentry_count'] as num?)?.toInt() ?? 0,
          postedAt: _canvasDate(d['posted_at']),
          htmlUrl: d['html_url'] as String? ?? '',
        ))
    .toList();

/// 강좌 홈이 무엇을 보여줄지. Canvas 기본값은 feed다.
String parseDefaultView(Object? json) {
  if (json is! Map) throw const ParseFailure();
  final view = json['default_view'] as String?;
  return (view == null || view.isEmpty) ? 'feed' : view;
}

/// 강좌 대문 페이지 본문. 비어 있으면 null.
String? parseFrontPage(Object? json) {
  if (json is! Map) throw const ParseFailure();
  final body = json['body'] as String?;
  return (body == null || body.trim().isEmpty) ? null : body;
}

List<CanvasModuleItem> parseModuleItems(Object? json) => _asList(json)
    .map((i) => CanvasModuleItem(
          id: (i['id'] as num?)?.toInt() ?? 0,
          title: i['title'] as String? ?? '',
          type: i['type'] as String? ?? '',
          htmlUrl: i['html_url'] as String? ?? '',
          contentId: (i['content_id'] as num?)?.toInt(),
          indent: (i['indent'] as num?)?.toInt() ?? 0,
        ))
    .toList();
