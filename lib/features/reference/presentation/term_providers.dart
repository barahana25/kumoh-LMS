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
  try {
    await repo.refreshTerms();
  } on Failure {
    // 오프라인이어도 캐시된 학기로 화면을 띄운다. 여기서 예외를 흘리면
    // 강좌·과제·공지 세 화면이 전부 에러 화면이 되어, 저장된 데이터를
    // 보여준다는 이 앱의 원칙이 깨진다.
  }
  return repo.currentTermId();
});

/// 마지막 새로고침 실패 메시지. 캐시는 그대로 두고 배너로만 알린다.
final refreshErrorProvider = StateProvider<String?>((ref) => null);
