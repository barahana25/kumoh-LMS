import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/storage/db/app_database.dart';
import '../../auth/data/auth_api.dart' show throwAsFailure;

/// `/accounts` 응답. 기관 표시명·테마색·GPA 만점을 담는다.
class AccountInfo {
  const AccountInfo({
    required this.id,
    required this.name,
    required this.universityName,
    required this.scaleGpa,
    required this.themeColor,
  });

  final int id;
  final String name;
  final String universityName;
  final double scaleGpa;
  final String themeColor;

  factory AccountInfo.fromJson(Map<String, dynamic> json) => AccountInfo(
        id: (json['id'] as num?)?.toInt() ?? 1,
        name: json['name'] as String? ?? '',
        universityName: json['universityName'] as String? ?? '',
        scaleGpa: (json['scaleGpa'] as num?)?.toDouble() ?? 4.5,
        themeColor: json['themeColor'] as String? ?? '#00A9CE',
      );
}

/// 서버는 두 가지 형태로 시각을 준다.
///  - 오프셋이 있는 값(...Z, +09:00): 그대로 UTC로 변환한다.
///  - 오프셋이 없는 값('2026-09-01T00:01:00'): KST(UTC+9) 벽시계 시각이다.
///    기기 로컬 타임존으로 해석하면 안 된다.
DateTime? parseServerDate(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  final hasZone = raw.endsWith('Z') ||
      RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(raw);
  if (hasZone) return parsed.toUtc();
  return DateTime.utc(parsed.year, parsed.month, parsed.day, parsed.hour,
          parsed.minute, parsed.second, parsed.millisecond)
      .subtract(const Duration(hours: 9));
}

class ReferenceApi {
  ReferenceApi(this._dio);
  final Dio _dio;

  Future<AccountInfo> fetchAccount() async {
    try {
      final res = await _dio.get<Object?>('/accounts');
      return unwrapEnvelope<AccountInfo>(
        res.data,
        (d) => AccountInfo.fromJson(d! as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }

  Future<List<TermsCompanion>> fetchTerms(int accountId) async {
    try {
      final res = await _dio.get<Object?>(
        '/terms',
        queryParameters: {'accountId': accountId},
      );
      return unwrapEnvelope<List<TermsCompanion>>(res.data, (d) {
        final list = (d as List?) ?? const [];
        return list
            .cast<Map<String, dynamic>>()
            .map((t) => TermsCompanion.insert(
                  id: Value((t['id'] as num).toInt()),
                  name: t['name'] as String? ?? '',
                  startAt: Value(parseServerDate(t['startAt'])),
                  endAt: Value(parseServerDate(t['endAt'])),
                  workflowState: Value(t['workflowState'] as String? ?? ''),
                ))
            .toList();
      });
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }
}
