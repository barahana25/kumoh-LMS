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

/// 서버가 주는 'yyyy-MM-ddTHH:mm:ss' 또는 ISO8601을 관대하게 파싱한다.
DateTime? parseServerDate(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toUtc();
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
