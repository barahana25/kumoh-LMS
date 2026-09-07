import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/error/failure.dart';
import 'package:kumoh_lms/core/network/token_store.dart';
import 'package:kumoh_lms/features/notifications/data/lms_notification_source.dart';
import 'package:kumoh_lms/features/notifications/data/notification_models.dart';
import 'package:kumoh_lms/features/notifications/notification_runtime.dart';
import '../../fixtures/fixtures.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://canvas.example.test/api/v1'));
    adapter = DioAdapter(dio: dio);
  });
  tearDown(() => dio.close(force: true));

  test('Link의 다음 페이지를 따라가며 오래된 ID의 새 항목까지 수집한다', () async {
    adapter.onGet(
        'https://canvas.example.test/api/v1/courses/1/files?per_page=100',
        (s) => s.reply(200, [
              {'id': 100, 'display_name': '파일1'}
            ], headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
              'link': [
                '<https://canvas.example.test/api/v1/courses/1/files?page=2>; rel="next"'
              ],
            }));
    adapter.onGet(
        'https://canvas.example.test/api/v1/courses/1/files?page=2',
        (s) => s.reply(200, [
              {'id': 5, 'display_name': '파일2'}
            ]));
    final result = await fetchNotificationPages(dio, '/courses/1/files');
    expect(result.map((e) => e['id']), [100, 5]);
  });

  test('나중 페이지가 실패하면 불완전한 목록을 성공으로 반환하지 않는다', () async {
    final requested = <String>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (r, h) {
      requested.add(r.path);
      h.next(r);
    }));
    adapter.onGet(
        'https://canvas.example.test/api/v1/courses/1/files?per_page=100',
        (s) => s.reply(200, [
              {'id': 1}
            ], headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
              'link': ['<?page=2>; rel="next"']
            }));
    adapter.onGet('https://canvas.example.test/api/v1/courses/1/files?page=2',
        (s) => s.reply(500, {}));
    await expectLater(fetchNotificationPages(dio, '/courses/1/files'),
        throwsA(isA<Failure>()));
    expect(requested.length, 2);
    expect(requested.last, endsWith('?page=2'));
  });

  test('다른 호스트나 다른 강좌로 향하는 다음 페이지는 거부한다', () async {
    for (final url in [
      'https://other.test/api/v1/courses/1/files',
      'https://canvas.example.test/api/v1/courses/2/files'
    ]) {
      adapter.onGet(
          'https://canvas.example.test/api/v1/courses/1/files?per_page=100',
          (s) => s.reply(200, [], headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
                'link': ['<$url>; rel="next"']
              }));
      await expectLater(fetchNotificationPages(dio, '/courses/1/files'),
          throwsA(isA<ParseFailure>()));
    }
  });

  test('잠금·숨김·미공개 항목은 새 소식 대상에서 제외한다', () {
    final result = parseWatchedItems([
      {'id': 1, 'display_name': '보이는 파일'},
      {'id': 2, 'locked_for_user': true},
      {'id': 3, 'hidden_for_user': true},
      {'id': 4, 'published': false},
    ], NoticeKind.file);
    expect(result.map((i) => i.id), ['1']);
    expect(
        () => parseWatchedItems([
              {'name': 'ID 없음'}
            ], NoticeKind.assignment),
        throwsA(isA<ParseFailure>()));
  });

  test('백그라운드 인증은 화면에서 사용하는 토큰과 비밀번호를 변경하지 않는다', () async {
    final store = InMemoryTokenStore();
    await store.saveTokens(
        accessToken: 'foreground-access', refreshToken: 'foreground-refresh');
    await store.saveCredentials(userId: '20250000', password: 'pw');
    adapter.onPost('/login', (s) => s.reply(200, loginSuccessJson),
        data: {'userId': '20250000', 'password': 'pw'});
    adapter.onGet('/user/profile', (s) => s.reply(200, userProfileJson));
    final source = LmsNotificationSource(store, linusDio: dio);
    addTearDown(source.close);
    expect(await source.authenticate(), '20250000');
    expect(await store.readAccessToken(), 'foreground-access');
    expect(await store.readRefreshToken(), 'foreground-refresh');
    expect((await store.readCredentials())!.password, 'pw');
  });

  test('알림 탭 주소는 내부 경로만 만들며 비정상 payload는 무시한다', () {
    final target = NotificationDestination.parse(
        '{"owner":"student","courseId":12,"courseName":"강좌","tab":"files"}');
    expect(Uri.parse(target!.route).path, '/courses/12');
    expect(Uri.parse(target.route).queryParameters['tab'], 'files');
    expect(
        NotificationDestination.parse(
            '{"owner":"student","courseId":12,"tab":"https://other.test"}'),
        isNull);
    expect(NotificationDestination.parse('not-json'), isNull);
  });
}
