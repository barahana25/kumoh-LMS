import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/storage/db/app_database.dart';
import '../../../providers.dart';

final termsProvider = StreamProvider<List<TermRow>>((ref) =>
    ref.watch(referenceRepositoryProvider).watchTerms());

/// 화면이 실제로 쓸 학기 id.
/// 사용자가 고른 값이 있으면 그것, 없으면 오늘이 속한 학기를 자동 선택한다.
final activeTermIdProvider = FutureProvider<int?>((ref) async {
  final selected = ref.watch(selectedTermIdProvider);
  if (selected != null) return selected;

  final repo = ref.watch(referenceRepositoryProvider);

  var disposed = false;
  ref.onDispose(() => disposed = true);

  // 캐시된 학기가 있으면 네트워크를 기다리지 않는다. 이걸 await 하면
  // 강좌·과제·공지 세 화면이 전부, 이미 디스크에 있는 데이터를 두고도
  // 연결이 끝날 때까지(최대 20초) 스피너만 돈다.
  final cached = await repo.currentTermId();
  if (cached != null) {
    unawaited(() async {
      try {
        await repo.refreshTerms();
        final fresh = await repo.currentTermId();
        // 새 학기가 시작돼 값이 바뀐 경우에만 다시 계산한다(무한 루프 방지).
        if (!disposed && fresh != null && fresh != cached) ref.invalidateSelf();
      } on Object {
        // 배경 갱신 실패는 캐시 표시를 막지 않는다.
      }
    }());
    return cached;
  }

  // 캐시가 아예 없는 최초 실행에서만 네트워크를 기다린다.
  try {
    await repo.refreshTerms();
  } on Failure {
    // 오프라인이면 학기를 못 정한다. 화면은 빈 상태를 보여준다.
  }
  return repo.currentTermId();
});

/// 마지막 새로고침 실패 메시지. 캐시는 그대로 두고 배너로만 알린다.
final refreshErrorProvider = StateProvider<String?>((ref) => null);
