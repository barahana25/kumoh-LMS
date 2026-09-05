import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/db/app_database.dart';
import '../../../providers.dart';

/// 학기별 강좌 스트림. Drift가 캐시 변경을 자동으로 흘려보낸다.
final coursesProvider = StreamProvider.family<List<CourseRow>, int>(
  (ref, termId) => ref.watch(coursesRepositoryProvider).watch(termId),
);
