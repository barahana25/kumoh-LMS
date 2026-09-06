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

/// Canvas REST API. LINUS와 달리 `{code,message,data}` 봉투가 아니라
/// JSON 배열/객체를 그대로 돌려준다.
class CanvasApi {
  CanvasApi(this._dio);
  final Dio _dio;

  List<Map<String, dynamic>> _asList(Object? body) {
    if (body is! List) throw const ParseFailure();
    return body.cast<Map<String, dynamic>>();
  }

  /// 이 강좌가 실제로 노출하는 탭. 강좌마다 구성이 다르므로 하드코딩하지 않는다.
  Future<List<CourseTab>> fetchTabs(int courseId) async {
    try {
      final res = await _dio.get<Object?>('/courses/$courseId/tabs');
      final tabs = _asList(res.data)
          .where((t) => t['hidden'] != true)
          .map((t) => CourseTab(
                id: t['id'] as String? ?? '',
                label: t['label'] as String? ?? '',
                position: (t['position'] as num?)?.toInt() ?? 0,
                externalUrl:
                    (t['type'] == 'external') ? t['url'] as String? : null,
              ))
          .where((t) => t.id.isNotEmpty && !t.isExternal)
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      return tabs;
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }

  /// 이 강좌의 과제. 아직 게시되지 않은 초안은 제외한다.
  Future<List<CanvasAssignment>> fetchAssignments(int courseId) async {
    try {
      final res = await _dio.get<Object?>(
        '/courses/$courseId/assignments',
        queryParameters: {'per_page': 50, 'order_by': 'due_at'},
      );
      return _asList(res.data)
          .where((a) => a['published'] != false)
          .map((a) => CanvasAssignment(
                id: (a['id'] as num?)?.toInt() ?? 0,
                name: a['name'] as String? ?? '',
                dueAt: _canvasDate(a['due_at']),
                pointsPossible: a['points_possible'] as num?,
                htmlUrl: a['html_url'] as String? ?? '',
              ))
          .toList();
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }

  /// 내 제출 상태를 과제 id로 찾을 수 있게 묶어 돌려준다.
  Future<Map<int, CanvasSubmission>> fetchSubmissions(int courseId) async {
    try {
      final res = await _dio.get<Object?>(
        '/courses/$courseId/students/submissions',
        queryParameters: {'per_page': 50, 'student_ids[]': 'self'},
      );
      return {
        for (final s in _asList(res.data))
          (s['assignment_id'] as num?)?.toInt() ?? 0: CanvasSubmission(
            assignmentId: (s['assignment_id'] as num?)?.toInt() ?? 0,
            submitted: s['workflow_state'] != 'unsubmitted' &&
                s['submitted_at'] != null,
            missing: s['missing'] == true,
            late: s['late'] == true,
            score: s['score'] as num?,
            submittedAt: _canvasDate(s['submitted_at']),
          ),
      };
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }

  /// 강의 계획. 비어 있으면 null.
  Future<String?> fetchSyllabus(int courseId) async {
    try {
      final res = await _dio.get<Object?>(
        '/courses/$courseId',
        queryParameters: {'include[]': 'syllabus_body'},
      );
      final body = res.data;
      if (body is! Map) throw const ParseFailure();
      final syllabus = body['syllabus_body'] as String?;
      return (syllabus == null || syllabus.trim().isEmpty) ? null : syllabus;
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }

  Future<List<CanvasModule>> fetchModules(int courseId) async {
    try {
      final res = await _dio.get<Object?>(
        '/courses/$courseId/modules',
        queryParameters: {'per_page': 50},
      );
      return _asList(res.data)
          .map((m) => CanvasModule(
                id: (m['id'] as num?)?.toInt() ?? 0,
                name: m['name'] as String? ?? '',
                position: (m['position'] as num?)?.toInt() ?? 0,
                itemsCount: (m['items_count'] as num?)?.toInt() ?? 0,
                state: m['state'] as String? ?? '',
              ))
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }

  Future<List<CanvasFile>> fetchFiles(int courseId) async {
    try {
      final res = await _dio.get<Object?>(
        '/courses/$courseId/files',
        queryParameters: {
          'per_page': 50,
          'sort': 'created_at',
          'order': 'desc',
        },
      );
      return _asList(res.data)
          .map((f) => CanvasFile(
                id: (f['id'] as num?)?.toInt() ?? 0,
                displayName: f['display_name'] as String? ?? '',
                locked: f['locked_for_user'] == true,
                contentType: f['content-type'] as String? ?? '',
                sizeBytes: (f['size'] as num?)?.toInt(),
                url: f['url'] as String? ?? '',
              ))
          .toList();
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }

  Future<List<CanvasPerson>> fetchPeople(int courseId) async {
    try {
      final res = await _dio.get<Object?>(
        '/courses/$courseId/enrollments',
        queryParameters: {'per_page': 100},
      );
      return _asList(res.data).map((e) {
        final user = (e['user'] as Map?) ?? const {};
        return CanvasPerson(
          userId: (user['id'] as num?)?.toInt() ?? 0,
          name: user['name'] as String? ?? '',
          enrollmentType: e['type'] as String? ?? '',
        );
      }).toList();
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }

  Future<List<CanvasGroup>> fetchGroups(int courseId) async {
    try {
      final res = await _dio.get<Object?>(
        '/courses/$courseId/groups',
        queryParameters: {'per_page': 50},
      );
      return _asList(res.data)
          .map((g) => CanvasGroup(
                id: (g['id'] as num?)?.toInt() ?? 0,
                name: g['name'] as String? ?? '',
                membersCount: (g['members_count'] as num?)?.toInt() ?? 0,
              ))
          .toList();
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }

  /// 이 강좌에서의 내 성적. 수강 정보가 없으면 null.
  Future<CanvasGrade?> fetchMyGrade(int courseId) async {
    try {
      final res = await _dio.get<Object?>(
        '/users/self/enrollments',
        queryParameters: {'per_page': 100, 'state[]': 'active'},
      );
      for (final e in _asList(res.data)) {
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
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }

  Future<List<CanvasDiscussion>> fetchDiscussions(int courseId) async {
    try {
      final res = await _dio.get<Object?>(
        '/courses/$courseId/discussion_topics',
        queryParameters: {'per_page': 50},
      );
      return _asList(res.data)
          .map((d) => CanvasDiscussion(
                id: (d['id'] as num?)?.toInt() ?? 0,
                title: d['title'] as String? ?? '',
                replyCount:
                    (d['discussion_subentry_count'] as num?)?.toInt() ?? 0,
                postedAt: _canvasDate(d['posted_at']),
                htmlUrl: d['html_url'] as String? ?? '',
              ))
          .toList();
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }
}
