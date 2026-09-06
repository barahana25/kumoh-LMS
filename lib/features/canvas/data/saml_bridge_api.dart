import 'package:dio/dio.dart';

import '../../auth/data/auth_api.dart' show throwAsFailure;

/// LINUS가 Canvas SSO 진입 URL을 만들어 준다.
///
/// 봉투(`{code,message,data}`)가 아니라 URL 문자열을 그대로 돌려주는
/// 몇 안 되는 엔드포인트다.
class SamlBridgeApi {
  SamlBridgeApi(this._dio);
  final Dio _dio;

  Future<String> fetchSsoUrl(String relayState) async {
    try {
      final res = await _dio.get<String>(
        '/saml/redirect.do',
        queryParameters: {'relayState': relayState},
        options: Options(responseType: ResponseType.plain),
      );
      return (res.data ?? '').trim();
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }
}
