import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/db/app_database.dart';
import '../../../providers.dart';

/// 한 학기의 모든 캘린더 이벤트(과제 마감 포함).
final termEventsProvider = StreamProvider.family<List<CalendarEventRow>, int>(
  (ref, termId) => ref.watch(assignmentsRepositoryProvider).watchTerm(termId),
);
