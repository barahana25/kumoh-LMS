import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/config/env.dart';
import '../../../core/error/failure.dart';
import '../../auth/data/auth_api.dart' show throwAsFailure;

final _filePattern = RegExp(r'(^|/)files/\d+');
final _windowsUnsafe = RegExp('[<>:"|?*]');
final _controlChars = RegExp(r'[\x00-\x1f]');

/// Canvas 파일 주소인가?
///
/// WebView는 PDF를 그리지 못하고 다운로드 이벤트도 알려주지 않아, 그냥 두면
/// 빈 화면만 남는다. 그래서 파일 주소는 미리 가려내 직접 내려받는다.
bool isCanvasFileUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || !uri.hasAuthority) return false;
  if (uri.host != Uri.parse(Env.canvasHost).host) return false;
  return _filePattern.hasMatch(uri.path);
}

/// 저장에 쓸 안전한 파일 이름.
///
/// 서버가 준 이름을 그대로 경로에 쓰면 앱 밖에 쓰려는 시도가 될 수 있다.
String safeFileName(String displayName) {
  // 경로 조각을 먼저 버린다. 슬래시를 치환한 뒤에는 '..'가 이름 안에 남는다.
  var name = displayName.trim().replaceAll(r'\', '/');
  name = name
      .split('/')
      .where((s) => s.isNotEmpty && s != '.' && s != '..')
      .join('_');
  name = name.replaceAll(_windowsUnsafe, '_').replaceAll(_controlChars, '_');
  name = name.replaceAll(RegExp(r'^\.+'), '');
  name = name.replaceAll(RegExp('_+'), '_');
  name = name.replaceAll(RegExp(r'^_+|_+$'), '');
  if (name.isEmpty) return 'download';

  const maxLen = 120;
  if (name.length <= maxLen) return name;
  // 확장자가 없으면 기기 뷰어가 무엇으로 열지 모른다.
  final ext = p.extension(name);
  final stem = p.basenameWithoutExtension(name);
  return stem.substring(0, maxLen - ext.length) + ext;
}

/// 세션이 붙은 dio로 파일을 내려받아 앱 저장소에 둔다.
///
/// Canvas 파일은 로그인 상태에서만 받을 수 있어 외부 브라우저나 기기의
/// 다운로드 관리자에 넘길 수 없다.
class CanvasDownloader {
  CanvasDownloader(this._dio);
  final Dio _dio;

  Future<File> download({
    required String url,
    required String displayName,
    Directory? directory,
    CancelToken? cancelToken,
    void Function(int received, int total)? onProgress,
  }) async {
    try {
      final dir = directory ?? await getApplicationDocumentsDirectory();
      final target = File(directory == null
          ? p.join(dir.path, 'files', safeFileName(displayName))
          : p.join(dir.path, safeFileName(displayName)));
      await target.parent.create(recursive: true);

      await _dio.downloadUri(
        Uri.parse(url),
        target.path,
        cancelToken: cancelToken,
        onReceiveProgress: onProgress,
        options: Options(followRedirects: true, maxRedirects: 5),
      );

      if (!target.existsSync() || target.lengthSync() == 0) {
        throw const ServerFailure(code: 'EMPTY', message: '파일을 받지 못했습니다.');
      }
      return target;
    } on DioException catch (e) {
      throwAsFailure(e);
    } on FileSystemException {
      throw const ServerFailure(code: 'IO', message: '기기에 파일을 저장하지 못했습니다.');
    }
  }
}
