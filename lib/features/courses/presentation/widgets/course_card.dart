import 'package:flutter/material.dart';

import '../../../../core/storage/db/app_database.dart';

class CourseCard extends StatelessWidget {
  const CourseCard({required this.course, super.key});

  final CourseRow course;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitleParts = [
      if (course.teacherNames.isNotEmpty) course.teacherNames,
      if (course.institution.isNotEmpty) course.institution,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              course.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (subtitleParts.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subtitleParts.join(' · '),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.outline),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Chip(text: course.courseCode),
                if (course.courseFormat.isNotEmpty) ...[
                  _Chip(text: course.courseFormat),
                ],
                Text(
                  '${course.totalStudents}명',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
