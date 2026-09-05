import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/db/app_database.dart';
import '../../../providers.dart';

final termAnnouncementsProvider =
    StreamProvider.family<List<AnnouncementRow>, int>(
  (ref, termId) => ref.watch(announcementsRepositoryProvider).watch(termId),
);
