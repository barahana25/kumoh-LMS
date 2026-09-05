import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/storage/db/app_database.dart';
import '../../assignments/data/calendar_api.dart' show courseIdFromContextCode;
import '../../auth/data/auth_api.dart' show throwAsFailure;
import '../../reference/data/reference_api.dart' show parseServerDate;

class AnnouncementsApi {
  AnnouncementsApi(this._dio);
  final Dio _dio;

  Future<List<AnnouncementsCompanion>> fetchAnnouncements(int termId) async {
    try {
      final res = await _dio.get<Object?>(
        '/dashboard/total/announcement',
        queryParameters: {'termId': termId},
      );
      return unwrapEnvelope<List<AnnouncementsCompanion>>(res.data, (d) {
        final map = (d as Map?) ?? const {};
        final list = (map['announcements'] as List?) ?? const [];
        return list
            .cast<Map<String, dynamic>>()
            .map((a) => _toCompanion(a, termId))
            .toList();
      });
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }
}

AnnouncementsCompanion _toCompanion(Map<String, dynamic> a, int termId) {
  // 서버가 camelCase와 snake_case를 섞어 쓰는 경우가 있어 둘 다 본다.
  Object? pick(String camel, String snake) => a[camel] ?? a[snake];

  return AnnouncementsCompanion.insert(
    id: (pick('id', 'id') ?? '').toString(),
    termId: termId,
    courseId: Value(courseIdFromContextCode(
      (pick('contextCode', 'context_code') as String?),
    )),
    contextName: Value((pick('contextName', 'context_name') as String?) ?? ''),
    title: (pick('title', 'title') as String?) ?? '',
    message: Value((pick('message', 'message') as String?) ?? ''),
    authorName: Value((pick('userName', 'user_name') as String?) ?? ''),
    postedAt: Value(parseServerDate(pick('postedAt', 'posted_at'))),
    htmlUrl: Value((pick('htmlUrl', 'html_url') as String?) ?? ''),
  );
}
