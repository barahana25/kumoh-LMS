import 'package:flutter/material.dart';

import '../../../../core/ui/empty_state.dart';
import '../../data/canvas_api.dart';
import 'assignments_tab.dart';
import 'content_tabs.dart';
import 'home_tab.dart';

/// 탭 id에 맞는 내용을 그린다.
///
/// 아직 네이티브로 만들지 않은 탭은 "준비 중"으로 정직하게 표시한다.
/// 빈 화면을 보여주면 학생이 "내용이 없다"고 오해한다.
class CourseTabView extends StatelessWidget {
  const CourseTabView({required this.courseId, required this.tab, super.key});

  final int courseId;
  final CourseTab tab;

  @override
  Widget build(BuildContext context) {
    switch (tab.id) {
      case 'home':
        return HomeTab(courseId: courseId);
      case 'assignments':
        return AssignmentsTab(courseId: courseId);
      case 'syllabus':
        return SyllabusTab(courseId: courseId);
      case 'modules':
        return ModulesTab(courseId: courseId);
      case 'files':
        return FilesTab(courseId: courseId);
      case 'grades':
        return GradesTab(courseId: courseId);
      case 'discussions':
        return DiscussionsTab(courseId: courseId);
      case 'people':
        return PeopleTab(courseId: courseId);
      default:
        return EmptyState(
          icon: Icons.construction_outlined,
          title: '${tab.label} 준비 중',
          description: '이 메뉴는 아직 앱에서 지원하지 않습니다.',
        );
    }
  }
}
