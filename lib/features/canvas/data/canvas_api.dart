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

/// Canvas 세션이 끊겼을 때 다시 다리를 건너고 원요청을 재시도한다.
///
/// Canvas는 세션이 만료되면 401을 준다. [reBridge]는 single-flight이므로
/// 동시에 만료를 만난 요청들이 다리를 여러 번 건너지 않는다.
Interceptor canvasSessionInterceptor({
  required Dio dio,
  required Future<void> Function() reBridge,
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
}
