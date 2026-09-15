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

/// 파일 미리보기 페이지 주소(/courses/1/files/9)를 실제 내려받기 주소로 바꾼다.
///
/// 미리보기 주소를 그대로 받으면 PDF가 아니라 HTML 페이지가 저장되고,
/// 기기 뷰어가 "지원하지 않는 형식"이라며 열지 못한다.
String canvasFileDownloadUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null) return rawUrl;
  final segments = uri.pathSegments;
  final at = segments.indexOf('files');
  if (at < 0 || at + 1 >= segments.length) return rawUrl;
  final id = segments[at + 1];
  if (int.tryParse(id) == null) return rawUrl;
  if (at + 2 < segments.length && segments[at + 2] == 'download') return rawUrl;
  return '${Env.canvasHost}/files/$id/download?download_frd=1';
}

/// Content-Disposition에서 파일 이름을 꺼낸다. filename*(UTF-8)을 먼저 본다.
String? fileNameFromDisposition(String? header) {
  if (header == null || header.isEmpty) return null;
  final star = RegExp(r"filename\*\s*=\s*([^']*)'[^']*'([^;]+)",
          caseSensitive: false)
      .firstMatch(header);
  if (star != null) {
    try {
      return Uri.decodeComponent(star.group(2)!.trim().replaceAll('"', ''));
    } on ArgumentError {
      // 잘못 인코딩된 이름은 아래 filename으로 대신한다.
    }
  }
  final plain = RegExp(r'filename\s*=\s*"([^"]*)"|filename\s*=\s*([^;]+)',
          caseSensitive: false)
      .firstMatch(header);
  final name = (plain?.group(1) ?? plain?.group(2))?.trim();
  return name == null || name.isEmpty ? null : name;
}

const _extensionByMime = {
  'application/pdf': '.pdf',
  'application/zip': '.zip',
  'application/x-hwp': '.hwp',
  'application/haansofthwp': '.hwp',
  'application/vnd.hancom.hwp': '.hwp',
  'application/vnd.hancom.hwpx': '.hwpx',
  'application/msword': '.doc',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
      '.docx',
  'application/vnd.ms-powerpoint': '.ppt',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation':
      '.pptx',
  'application/vnd.ms-excel': '.xls',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': '.xlsx',
  'text/plain': '.txt',
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'video/mp4': '.mp4',
};

/// 저장할 이름을 정한다. 서버가 알려준 이름을 우선하고, 확장자가 없으면
/// Content-Type으로 붙인다. 확장자가 없으면 기기 뷰어가 형식을 모른다.
String resolveDownloadName({
  required String displayName,
  String? disposition,
  String? contentType,
}) {
  var name = fileNameFromDisposition(disposition) ?? displayName;
  if (p.extension(name).isEmpty && p.extension(displayName).isNotEmpty) {
    name = displayName;
  }
  if (p.extension(name).isEmpty) {
    final mime = contentType?.split(';').first.trim().toLowerCase();
    final ext = _extensionByMime[mime];
    if (ext != null) name = '$name$ext';
  }
  return safeFileName(name);
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
      final folder = directory == null ? p.join(dir.path, 'files') : dir.path;
      final partial = File(p.join(folder, '${safeFileName(displayName)}.part'));
      await partial.parent.create(recursive: true);

      final response = await _dio.downloadUri(
        Uri.parse(canvasFileDownloadUrl(url)),
        partial.path,
        cancelToken: cancelToken,
        onReceiveProgress: onProgress,
        options: Options(followRedirects: true, maxRedirects: 5),
      );

      if (!partial.existsSync() || partial.lengthSync() == 0) {
        throw const ServerFailure(code: 'EMPTY', message: '파일을 받지 못했습니다.');
      }
      final contentType = response.headers.value('content-type');
      final name = resolveDownloadName(
        displayName: displayName,
        disposition: response.headers.value('content-disposition'),
        contentType: contentType,
      );
      // 세션이 끊기면 파일 대신 로그인 페이지(HTML)가 온다. 그대로 넘기면
      // 뷰어가 "지원하지 않는 형식"을 띄우므로 여기서 실패로 알린다.
      final ext = p.extension(name).toLowerCase();
      if ((contentType ?? '').toLowerCase().startsWith('text/html') &&
          ext != '.html' &&
          ext != '.htm') {
        await partial.delete();
        throw const ServerFailure(
            code: 'NOT_FILE', message: '파일을 받지 못했습니다. 잠시 후 다시 시도해 주세요.');
      }
      final target = File(p.join(folder, name));
      if (target.existsSync()) await target.delete();
      return await partial.rename(target.path);
    } on DioException catch (e) {
      throwAsFailure(e);
    } on FileSystemException {
      throw const ServerFailure(code: 'IO', message: '기기에 파일을 저장하지 못했습니다.');
    }
  }
}
