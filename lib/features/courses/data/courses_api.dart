import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/storage/db/app_database.dart';
import '../../auth/data/auth_api.dart' show throwAsFailure;

class CoursesApi {
  CoursesApi(this._dio);
  final Dio _dio;

  Future<List<CoursesCompanion>> fetchCourses({
    required int accountId,
    required int termId,
  }) async {
    try {
      final res = await _dio.get<Object?>(
        '/courses',
        queryParameters: {
          'isMyCourse': 'true',
          'accountId': accountId,
          'termId': termId,
        },
      );
      return unwrapEnvelope<List<CoursesCompanion>>(res.data, (d) {
        final map = (d as Map?) ?? const {};
        final list = (map['courses'] as List?) ?? const [];
        return list
            .cast<Map<String, dynamic>>()
            .map((c) => _toCompanion(c, termId))
            .toList();
      });
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }
}

CoursesCompanion _toCompanion(Map<String, dynamic> c, int fallbackTermId) {
  final teachers = (c['teachers'] as List?) ?? const [];
  final names = teachers
      .cast<Map<String, dynamic>>()
      .map((t) => t['displayName'] as String? ?? '')
      .where((s) => s.isNotEmpty)
      .join(', ');

  return CoursesCompanion.insert(
    id: Value((c['id'] as num).toInt()),
    termId: (c['enrollmentTermId'] as num?)?.toInt() ?? fallbackTermId,
    name: c['name'] as String? ?? '',
    courseCode: c['courseCode'] as String? ?? '',
    institution: Value(c['institution'] as String? ?? ''),
    teacherNames: Value(names),
    totalStudents: Value((c['totalStudents'] as num?)?.toInt() ?? 0),
    workflowState: Value(c['workflowState'] as String? ?? ''),
    courseFormat: Value(c['courseFormat'] as String? ?? ''),
  );
}
