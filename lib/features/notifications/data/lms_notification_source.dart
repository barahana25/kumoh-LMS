import 'package:cookie_jar/cookie_jar.dart';
import 'dart:io';
import 'dart:async';
import '../../canvas/data/canvas_download.dart';
import 'package:dio/dio.dart';
import '../../../core/config/env.dart';
import '../../../core/error/failure.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/token_store.dart';
import '../../auth/data/auth_api.dart';
import '../../canvas/data/canvas_api.dart';
import '../../canvas/data/canvas_client.dart';
import '../../canvas/data/canvas_session.dart';
import '../../canvas/data/saml_bridge_api.dart';
import '../../courses/data/courses_api.dart';
import '../../reference/data/reference_api.dart';
import 'notification_models.dart';

/// 화면 캐시의 TTL을 사용하지 않는다. 페이지를 끝까지 조회한 경우만 비교한다.
class LmsNotificationSource implements NotificationSource {
  LmsNotificationSource(this.secureStore,
      {Dio? linusDio, Dio? bridgeDio, Dio? canvasDio}) {
    _linus = linusDio ?? buildAuthDio();
    final jar = CookieJar();
    cookieJar = jar;
    _bridge = bridgeDio ?? buildCanvasDio(jar);
    _canvas = canvasDio ?? buildCanvasDio(jar);
    _canvas.options.baseUrl = Env.canvasApiBaseUrl;
  }
  final TokenStore secureStore;
  late final Dio _linus;
  late final Dio _bridge;
  late final Dio _canvas;

  @override
  Future<String> authenticate() async {
    final credentials = await secureStore.readCredentials();
    if (credentials == null) throw const AuthFailure('자동 로그인을 켜고 다시 로그인해 주세요.');
    // UI의 회전 중인 토큰을 읽거나 덮어쓰지 않는 작업 전용 세션이다.
    final memory = InMemoryTokenStore();
    final api = AuthApi(_linus, tokenStore: memory);
    final tokens = await api
        .login(userId: credentials.userId, password: credentials.password)
        .catchError((Object e) {
      if (e is ServerFailure && (int.tryParse(e.code) ?? 0) < 500) {
        throw const AuthFailure();
      }
      throw e;
    });
    if (!tokens.isValid) throw const AuthFailure();
    await memory.saveTokens(
        accessToken: tokens.accessToken, refreshToken: tokens.refreshToken);
    _linus.options.headers.addAll({
      'Authorization': 'Bearer ${tokens.accessToken}',
      'X-Refresh-Token': tokens.refreshToken
    });
    final profile = await api.fetchProfile();
    final session = CanvasSession(
        dio: _bridge,
        jar: cookieJar,
        fetchSsoUrl: SamlBridgeApi(_linus).fetchSsoUrl,
        loginId: () async => profile.loginId);
    _canvas.interceptors.insert(
        0,
        canvasSessionInterceptor(
            dio: _canvas,
            ensureSession: session.ensure,
            reBridge: () async {
              session.invalidate();
              await session.ensure();
            }));
    return profile.loginId;
  }

  late CookieJar cookieJar;

  Future<File> downloadFile(String id, Directory temporaryDirectory,
      {Duration? timeout}) async {
    if (!RegExp(r'^\d+$').hasMatch(id)) throw const ParseFailure();
    final cancel = CancelToken();
    final timer = timeout == null ? null : Timer(timeout, () => cancel.cancel());
    try {
      return await CanvasDownloader(_canvas).download(
      url: '${Env.canvasHost}/files/$id/download?download_frd=1',
      displayName: '$id.bin', directory: temporaryDirectory, cancelToken: cancel,
    );
    } finally {
      timer?.cancel();
    }
  }

  @override
  Future<List<WatchedCourse>> courses() async {
    final terms = await ReferenceApi(_linus).fetchTerms(Env.defaultAccountId);
    if (terms.isEmpty) throw const ParseFailure('학기 정보를 확인하지 못했습니다.');
    terms.sort((a, b) => b.id.value.compareTo(a.id.value));
    final now = DateTime.now().toUtc();
    final term = terms
            .where((t) =>
                t.startAt.value != null &&
                t.endAt.value != null &&
                !now.isBefore(t.startAt.value!) &&
                !now.isAfter(t.endAt.value!))
            .firstOrNull ??
        terms.first;
    final courses = await CoursesApi(_linus)
        .fetchCourses(accountId: Env.defaultAccountId, termId: term.id.value);
    return courses.map((c) => WatchedCourse(c.id.value, c.name.value)).toList();
  }

  @override
  Future<List<WatchedItem>> items(int courseId, NoticeKind kind) async {
    final endpoint = switch (kind) {
      NoticeKind.announcement => 'discussion_topics',
      NoticeKind.file => 'files',
      NoticeKind.assignment => 'assignments',
      NoticeKind.discussion => 'discussion_topics',
    };
    final json = await fetchNotificationPages(
        _canvas, '/courses/$courseId/$endpoint', query: {
      if (kind == NoticeKind.announcement) 'only_announcements': true,
      if (kind == NoticeKind.discussion) 'only_announcements': false,
    });
    return parseWatchedItems(json, kind);
  }

  @override
  void close() {
    _linus.close(force: true);
    _bridge.close(force: true);
    _canvas.close(force: true);
  }
}

Future<List<Map<String, dynamic>>> fetchNotificationPages(Dio dio, String path,
    {Map<String, dynamic> query = const {}}) async {
  final base = Uri.parse(dio.options.baseUrl.endsWith('/')
      ? dio.options.baseUrl
      : '${dio.options.baseUrl}/');
  final first = base.resolve(path.replaceFirst(RegExp(r'^/'), ''));
  var next = first.replace(queryParameters: {
    'per_page': '100',
    for (final e in query.entries) e.key: '${e.value}'
  });
  final visited = <String>{};
  final items = <Map<String, dynamic>>[];
  for (var page = 0; page < 100; page++) {
    if (next.scheme != first.scheme ||
        next.host != first.host ||
        next.port != first.port ||
        next.path != first.path ||
        next.userInfo.isNotEmpty ||
        !visited.add(next.toString())) {
      throw const ParseFailure('목록의 다음 페이지 주소가 올바르지 않습니다.');
    }
    try {
      final response = await dio.getUri<dynamic>(next);
      final body = response.data;
      if (body is! List || body.any((e) => e is! Map<String, dynamic>)) {
        throw const ParseFailure();
      }
      items.addAll(body.cast<Map<String, dynamic>>());
      final link = response.headers.value('link') ?? '';
      final following =
          RegExp(r'<([^>]+)>\s*;\s*rel="?next"?', caseSensitive: false)
              .firstMatch(link)
              ?.group(1);
      if (following == null) return items;
      next = next.resolve(following);
    } on DioException catch (e) {
      throwAsFailure(e);
    }
  }
  throw const ParseFailure('목록이 너무 길어 이번 확인을 완료하지 못했습니다.');
}

List<WatchedItem> parseWatchedItems(
    List<Map<String, dynamic>> rows, NoticeKind kind) {
  final result = <WatchedItem>[];
  for (final row in rows) {
    if (kind == NoticeKind.discussion && row['is_announcement'] == true) continue;
    if (row['published'] == false ||
        row['locked_for_user'] == true ||
        row['hidden_for_user'] == true ||
        row['hidden'] == true) {
      continue;
    }
    if (kind == NoticeKind.announcement || kind == NoticeKind.discussion) {
      final delayed = DateTime.tryParse('${row['delayed_post_at']}');
      if (delayed != null && delayed.isAfter(DateTime.now())) continue;
    }
    final id = row['id'];
    if (id == null || '$id'.isEmpty) {
      throw const ParseFailure('항목 ID가 없는 목록입니다.');
    }
    final title = switch (kind) {
      NoticeKind.announcement => row['title'],
      NoticeKind.file => row['display_name'] ?? row['filename'],
      NoticeKind.assignment => row['name'],
      NoticeKind.discussion => row['title'],
    };
    result.add(WatchedItem('$id',
        title is String && title.isNotEmpty ? title : '${kind.label} #$id'));
  }
  return result;
}
