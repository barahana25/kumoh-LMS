import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/storage/db/app_database.dart';
import '../../auth/data/auth_api.dart' show throwAsFailure;
import '../../reference/data/reference_api.dart' show parseServerDate;

/// 'course_4831' → 4831. 강좌가 아닌 컨텍스트는 null.
int? courseIdFromContextCode(String? code) {
  if (code == null || !code.startsWith('course_')) return null;
  return int.tryParse(code.substring('course_'.length));
}

/// 서버가 기대하는 날짜 형식은 yyyy-MM-dd.
String formatDateParam(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class CalendarApi {
  CalendarApi(this._dio);
  final Dio _dio;

  /// 캘린더는 강좌(context_code) 단위로만 조회할 수 있다.
  Future<List<CalendarEventsCompanion>> fetchEvents({
    required int termId,
    required int courseId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final res = await _dio.get<Object?>(
        '/calendar-events',
        queryParameters: {
          'start_date': formatDateParam(from),
          'end_date': formatDateParam(to),
          'context_code': 'course_$courseId',
        },
      );
      return unwrapEnvelope<List<CalendarEventsCompanion>>(res.data, (d) {
        final map = (d as Map?) ?? const {};
        final list = (map['calendarEvents'] as List?) ?? const [];
        return list
            .cast<Map<String, dynamic>>()
            .map((e) => _toCompanion(e, termId, courseId))
            .toList();
      });
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }
}

CalendarEventsCompanion _toCompanion(
  Map<String, dynamic> e,
  int termId,
  int fallbackCourseId,
) {
  return CalendarEventsCompanion.insert(
    id: e['id'] as String? ?? '',
    termId: termId,
    courseId: Value(
      courseIdFromContextCode(e['context_code'] as String?) ?? fallbackCourseId,
    ),
    contextName: Value(e['context_name'] as String? ?? ''),
    title: e['title'] as String? ?? '',
    description: Value(e['description'] as String? ?? ''),
    startAt: Value(parseServerDate(e['start_at'])),
    endAt: Value(parseServerDate(e['end_at'])),
    allDay: Value(e['all_day'] as bool? ?? false),
    htmlUrl: Value(e['html_url'] as String? ?? ''),
    workflowState: Value(e['workflow_state'] as String? ?? ''),
  );
}
