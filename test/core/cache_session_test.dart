import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:kumoh_lms/core/storage/db/app_database.dart';
import 'package:kumoh_lms/providers.dart';

import '../fixtures/fixtures.dart';
import '../helpers/test_db.dart';

void main() {
  for (final feature in ['terms', 'courses', 'assignments', 'announcements']) {
    test('$feature: 이전 세션의 늦은 응답은 새 세션 캐시에 기록되지 않는다', () async {
      final db = createTestDatabase();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      final adapter = DioAdapter(dio: dio);
      adapter.onGet('/terms', (s) => s.reply(200, termsJson));
      adapter.onGet('/courses', (s) => s.reply(200, coursesJson));
      adapter.onGet('/calendar-events', (s) => s.reply(200, {
        'code': '200', 'data': {'calendarEvents': [
          {'id': 'assignment_1', 'title': '이전 계정 과제', 'context_code': 'course_1'},
        ]},
      }));
      adapter.onGet('/dashboard/total/announcement', (s) => s.reply(200, {
        'code': '200', 'data': {'announcements': [
          {'id': '1', 'title': '이전 계정 공지'},
        ]},
      }));
      final sent = Completer<void>();
      adapter.onGet('/courses/1/discussion_topics', (s) => s.reply(200, [
        {'id': 1, 'title': '이전 계정 공지'},
      ]));
      final release = Completer<void>();
      dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) async {
        sent.complete();
        await release.future;
        h.next(o);
      }));
      final container = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        dioProvider.overrideWithValue(dio),
        canvasDioProvider.overrideWithValue(dio),
      ]);
      addTearDown(() async {
        container.dispose();
        dio.close(force: true);
        await db.close();
      });
      await db.coursesDao.upsertAll([CoursesCompanion.insert(
        id: const Value(1), termId: 8, name: '이전 계정 강좌', courseCode: 'TEST',
      )]);
      final pending = switch (feature) {
        'terms' => container.read(referenceRepositoryProvider).refreshTerms(force: true),
        'courses' => container.read(coursesRepositoryProvider).refresh(8, force: true),
        'assignments' => container.read(assignmentsRepositoryProvider).refresh(8, force: true),
        _ => container.read(announcementsRepositoryProvider).refresh(8, force: true),
      };
      await sent.future;
      final session = container.read(cacheSessionProvider);
      session.end();
      await db.wipe();
      session.start();
      release.complete();
      await pending;
      expect(await db.select(db.terms).get(), isEmpty);
      expect(await db.select(db.courses).get(), isEmpty);
      expect(await db.select(db.calendarEvents).get(), isEmpty);
      expect(await db.select(db.announcements).get(), isEmpty);
      expect(await db.select(db.cacheMetaEntries).get(), isEmpty);
    });
  }
}
