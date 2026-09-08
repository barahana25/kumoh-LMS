// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TermsTable extends Terms with TableInfo<$TermsTable, TermRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TermsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startAtMeta =
      const VerificationMeta('startAt');
  @override
  late final GeneratedColumn<DateTime> startAt = GeneratedColumn<DateTime>(
      'start_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _endAtMeta = const VerificationMeta('endAt');
  @override
  late final GeneratedColumn<DateTime> endAt = GeneratedColumn<DateTime>(
      'end_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _workflowStateMeta =
      const VerificationMeta('workflowState');
  @override
  late final GeneratedColumn<String> workflowState = GeneratedColumn<String>(
      'workflow_state', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, startAt, endAt, workflowState];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'terms';
  @override
  VerificationContext validateIntegrity(Insertable<TermRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('start_at')) {
      context.handle(_startAtMeta,
          startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta));
    }
    if (data.containsKey('end_at')) {
      context.handle(
          _endAtMeta, endAt.isAcceptableOrUnknown(data['end_at']!, _endAtMeta));
    }
    if (data.containsKey('workflow_state')) {
      context.handle(
          _workflowStateMeta,
          workflowState.isAcceptableOrUnknown(
              data['workflow_state']!, _workflowStateMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TermRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TermRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      startAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_at']),
      endAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end_at']),
      workflowState: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workflow_state'])!,
    );
  }

  @override
  $TermsTable createAlias(String alias) {
    return $TermsTable(attachedDatabase, alias);
  }
}

class TermRow extends DataClass implements Insertable<TermRow> {
  final int id;
  final String name;
  final DateTime? startAt;
  final DateTime? endAt;
  final String workflowState;
  const TermRow(
      {required this.id,
      required this.name,
      this.startAt,
      this.endAt,
      required this.workflowState});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || startAt != null) {
      map['start_at'] = Variable<DateTime>(startAt);
    }
    if (!nullToAbsent || endAt != null) {
      map['end_at'] = Variable<DateTime>(endAt);
    }
    map['workflow_state'] = Variable<String>(workflowState);
    return map;
  }

  TermsCompanion toCompanion(bool nullToAbsent) {
    return TermsCompanion(
      id: Value(id),
      name: Value(name),
      startAt: startAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startAt),
      endAt:
          endAt == null && nullToAbsent ? const Value.absent() : Value(endAt),
      workflowState: Value(workflowState),
    );
  }

  factory TermRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TermRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      startAt: serializer.fromJson<DateTime?>(json['startAt']),
      endAt: serializer.fromJson<DateTime?>(json['endAt']),
      workflowState: serializer.fromJson<String>(json['workflowState']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'startAt': serializer.toJson<DateTime?>(startAt),
      'endAt': serializer.toJson<DateTime?>(endAt),
      'workflowState': serializer.toJson<String>(workflowState),
    };
  }

  TermRow copyWith(
          {int? id,
          String? name,
          Value<DateTime?> startAt = const Value.absent(),
          Value<DateTime?> endAt = const Value.absent(),
          String? workflowState}) =>
      TermRow(
        id: id ?? this.id,
        name: name ?? this.name,
        startAt: startAt.present ? startAt.value : this.startAt,
        endAt: endAt.present ? endAt.value : this.endAt,
        workflowState: workflowState ?? this.workflowState,
      );
  TermRow copyWithCompanion(TermsCompanion data) {
    return TermRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      endAt: data.endAt.present ? data.endAt.value : this.endAt,
      workflowState: data.workflowState.present
          ? data.workflowState.value
          : this.workflowState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TermRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('workflowState: $workflowState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, startAt, endAt, workflowState);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TermRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.startAt == this.startAt &&
          other.endAt == this.endAt &&
          other.workflowState == this.workflowState);
}

class TermsCompanion extends UpdateCompanion<TermRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime?> startAt;
  final Value<DateTime?> endAt;
  final Value<String> workflowState;
  const TermsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.workflowState = const Value.absent(),
  });
  TermsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.workflowState = const Value.absent(),
  }) : name = Value(name);
  static Insertable<TermRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? startAt,
    Expression<DateTime>? endAt,
    Expression<String>? workflowState,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      if (workflowState != null) 'workflow_state': workflowState,
    });
  }

  TermsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<DateTime?>? startAt,
      Value<DateTime?>? endAt,
      Value<String>? workflowState}) {
    return TermsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      workflowState: workflowState ?? this.workflowState,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<DateTime>(startAt.value);
    }
    if (endAt.present) {
      map['end_at'] = Variable<DateTime>(endAt.value);
    }
    if (workflowState.present) {
      map['workflow_state'] = Variable<String>(workflowState.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TermsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('workflowState: $workflowState')
          ..write(')'))
        .toString();
  }
}

class $CoursesTable extends Courses with TableInfo<$CoursesTable, CourseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoursesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _termIdMeta = const VerificationMeta('termId');
  @override
  late final GeneratedColumn<int> termId = GeneratedColumn<int>(
      'term_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _courseCodeMeta =
      const VerificationMeta('courseCode');
  @override
  late final GeneratedColumn<String> courseCode = GeneratedColumn<String>(
      'course_code', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _institutionMeta =
      const VerificationMeta('institution');
  @override
  late final GeneratedColumn<String> institution = GeneratedColumn<String>(
      'institution', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _teacherNamesMeta =
      const VerificationMeta('teacherNames');
  @override
  late final GeneratedColumn<String> teacherNames = GeneratedColumn<String>(
      'teacher_names', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _totalStudentsMeta =
      const VerificationMeta('totalStudents');
  @override
  late final GeneratedColumn<int> totalStudents = GeneratedColumn<int>(
      'total_students', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _workflowStateMeta =
      const VerificationMeta('workflowState');
  @override
  late final GeneratedColumn<String> workflowState = GeneratedColumn<String>(
      'workflow_state', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _courseFormatMeta =
      const VerificationMeta('courseFormat');
  @override
  late final GeneratedColumn<String> courseFormat = GeneratedColumn<String>(
      'course_format', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        termId,
        name,
        courseCode,
        institution,
        teacherNames,
        totalStudents,
        workflowState,
        courseFormat
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'courses';
  @override
  VerificationContext validateIntegrity(Insertable<CourseRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('term_id')) {
      context.handle(_termIdMeta,
          termId.isAcceptableOrUnknown(data['term_id']!, _termIdMeta));
    } else if (isInserting) {
      context.missing(_termIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('course_code')) {
      context.handle(
          _courseCodeMeta,
          courseCode.isAcceptableOrUnknown(
              data['course_code']!, _courseCodeMeta));
    } else if (isInserting) {
      context.missing(_courseCodeMeta);
    }
    if (data.containsKey('institution')) {
      context.handle(
          _institutionMeta,
          institution.isAcceptableOrUnknown(
              data['institution']!, _institutionMeta));
    }
    if (data.containsKey('teacher_names')) {
      context.handle(
          _teacherNamesMeta,
          teacherNames.isAcceptableOrUnknown(
              data['teacher_names']!, _teacherNamesMeta));
    }
    if (data.containsKey('total_students')) {
      context.handle(
          _totalStudentsMeta,
          totalStudents.isAcceptableOrUnknown(
              data['total_students']!, _totalStudentsMeta));
    }
    if (data.containsKey('workflow_state')) {
      context.handle(
          _workflowStateMeta,
          workflowState.isAcceptableOrUnknown(
              data['workflow_state']!, _workflowStateMeta));
    }
    if (data.containsKey('course_format')) {
      context.handle(
          _courseFormatMeta,
          courseFormat.isAcceptableOrUnknown(
              data['course_format']!, _courseFormatMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CourseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CourseRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      termId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}term_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      courseCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}course_code'])!,
      institution: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}institution'])!,
      teacherNames: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}teacher_names'])!,
      totalStudents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_students'])!,
      workflowState: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workflow_state'])!,
      courseFormat: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}course_format'])!,
    );
  }

  @override
  $CoursesTable createAlias(String alias) {
    return $CoursesTable(attachedDatabase, alias);
  }
}

class CourseRow extends DataClass implements Insertable<CourseRow> {
  final int id;
  final int termId;
  final String name;
  final String courseCode;
  final String institution;
  final String teacherNames;
  final int totalStudents;
  final String workflowState;
  final String courseFormat;
  const CourseRow(
      {required this.id,
      required this.termId,
      required this.name,
      required this.courseCode,
      required this.institution,
      required this.teacherNames,
      required this.totalStudents,
      required this.workflowState,
      required this.courseFormat});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['term_id'] = Variable<int>(termId);
    map['name'] = Variable<String>(name);
    map['course_code'] = Variable<String>(courseCode);
    map['institution'] = Variable<String>(institution);
    map['teacher_names'] = Variable<String>(teacherNames);
    map['total_students'] = Variable<int>(totalStudents);
    map['workflow_state'] = Variable<String>(workflowState);
    map['course_format'] = Variable<String>(courseFormat);
    return map;
  }

  CoursesCompanion toCompanion(bool nullToAbsent) {
    return CoursesCompanion(
      id: Value(id),
      termId: Value(termId),
      name: Value(name),
      courseCode: Value(courseCode),
      institution: Value(institution),
      teacherNames: Value(teacherNames),
      totalStudents: Value(totalStudents),
      workflowState: Value(workflowState),
      courseFormat: Value(courseFormat),
    );
  }

  factory CourseRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CourseRow(
      id: serializer.fromJson<int>(json['id']),
      termId: serializer.fromJson<int>(json['termId']),
      name: serializer.fromJson<String>(json['name']),
      courseCode: serializer.fromJson<String>(json['courseCode']),
      institution: serializer.fromJson<String>(json['institution']),
      teacherNames: serializer.fromJson<String>(json['teacherNames']),
      totalStudents: serializer.fromJson<int>(json['totalStudents']),
      workflowState: serializer.fromJson<String>(json['workflowState']),
      courseFormat: serializer.fromJson<String>(json['courseFormat']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'termId': serializer.toJson<int>(termId),
      'name': serializer.toJson<String>(name),
      'courseCode': serializer.toJson<String>(courseCode),
      'institution': serializer.toJson<String>(institution),
      'teacherNames': serializer.toJson<String>(teacherNames),
      'totalStudents': serializer.toJson<int>(totalStudents),
      'workflowState': serializer.toJson<String>(workflowState),
      'courseFormat': serializer.toJson<String>(courseFormat),
    };
  }

  CourseRow copyWith(
          {int? id,
          int? termId,
          String? name,
          String? courseCode,
          String? institution,
          String? teacherNames,
          int? totalStudents,
          String? workflowState,
          String? courseFormat}) =>
      CourseRow(
        id: id ?? this.id,
        termId: termId ?? this.termId,
        name: name ?? this.name,
        courseCode: courseCode ?? this.courseCode,
        institution: institution ?? this.institution,
        teacherNames: teacherNames ?? this.teacherNames,
        totalStudents: totalStudents ?? this.totalStudents,
        workflowState: workflowState ?? this.workflowState,
        courseFormat: courseFormat ?? this.courseFormat,
      );
  CourseRow copyWithCompanion(CoursesCompanion data) {
    return CourseRow(
      id: data.id.present ? data.id.value : this.id,
      termId: data.termId.present ? data.termId.value : this.termId,
      name: data.name.present ? data.name.value : this.name,
      courseCode:
          data.courseCode.present ? data.courseCode.value : this.courseCode,
      institution:
          data.institution.present ? data.institution.value : this.institution,
      teacherNames: data.teacherNames.present
          ? data.teacherNames.value
          : this.teacherNames,
      totalStudents: data.totalStudents.present
          ? data.totalStudents.value
          : this.totalStudents,
      workflowState: data.workflowState.present
          ? data.workflowState.value
          : this.workflowState,
      courseFormat: data.courseFormat.present
          ? data.courseFormat.value
          : this.courseFormat,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CourseRow(')
          ..write('id: $id, ')
          ..write('termId: $termId, ')
          ..write('name: $name, ')
          ..write('courseCode: $courseCode, ')
          ..write('institution: $institution, ')
          ..write('teacherNames: $teacherNames, ')
          ..write('totalStudents: $totalStudents, ')
          ..write('workflowState: $workflowState, ')
          ..write('courseFormat: $courseFormat')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, termId, name, courseCode, institution,
      teacherNames, totalStudents, workflowState, courseFormat);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CourseRow &&
          other.id == this.id &&
          other.termId == this.termId &&
          other.name == this.name &&
          other.courseCode == this.courseCode &&
          other.institution == this.institution &&
          other.teacherNames == this.teacherNames &&
          other.totalStudents == this.totalStudents &&
          other.workflowState == this.workflowState &&
          other.courseFormat == this.courseFormat);
}

class CoursesCompanion extends UpdateCompanion<CourseRow> {
  final Value<int> id;
  final Value<int> termId;
  final Value<String> name;
  final Value<String> courseCode;
  final Value<String> institution;
  final Value<String> teacherNames;
  final Value<int> totalStudents;
  final Value<String> workflowState;
  final Value<String> courseFormat;
  const CoursesCompanion({
    this.id = const Value.absent(),
    this.termId = const Value.absent(),
    this.name = const Value.absent(),
    this.courseCode = const Value.absent(),
    this.institution = const Value.absent(),
    this.teacherNames = const Value.absent(),
    this.totalStudents = const Value.absent(),
    this.workflowState = const Value.absent(),
    this.courseFormat = const Value.absent(),
  });
  CoursesCompanion.insert({
    this.id = const Value.absent(),
    required int termId,
    required String name,
    required String courseCode,
    this.institution = const Value.absent(),
    this.teacherNames = const Value.absent(),
    this.totalStudents = const Value.absent(),
    this.workflowState = const Value.absent(),
    this.courseFormat = const Value.absent(),
  })  : termId = Value(termId),
        name = Value(name),
        courseCode = Value(courseCode);
  static Insertable<CourseRow> custom({
    Expression<int>? id,
    Expression<int>? termId,
    Expression<String>? name,
    Expression<String>? courseCode,
    Expression<String>? institution,
    Expression<String>? teacherNames,
    Expression<int>? totalStudents,
    Expression<String>? workflowState,
    Expression<String>? courseFormat,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (termId != null) 'term_id': termId,
      if (name != null) 'name': name,
      if (courseCode != null) 'course_code': courseCode,
      if (institution != null) 'institution': institution,
      if (teacherNames != null) 'teacher_names': teacherNames,
      if (totalStudents != null) 'total_students': totalStudents,
      if (workflowState != null) 'workflow_state': workflowState,
      if (courseFormat != null) 'course_format': courseFormat,
    });
  }

  CoursesCompanion copyWith(
      {Value<int>? id,
      Value<int>? termId,
      Value<String>? name,
      Value<String>? courseCode,
      Value<String>? institution,
      Value<String>? teacherNames,
      Value<int>? totalStudents,
      Value<String>? workflowState,
      Value<String>? courseFormat}) {
    return CoursesCompanion(
      id: id ?? this.id,
      termId: termId ?? this.termId,
      name: name ?? this.name,
      courseCode: courseCode ?? this.courseCode,
      institution: institution ?? this.institution,
      teacherNames: teacherNames ?? this.teacherNames,
      totalStudents: totalStudents ?? this.totalStudents,
      workflowState: workflowState ?? this.workflowState,
      courseFormat: courseFormat ?? this.courseFormat,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (termId.present) {
      map['term_id'] = Variable<int>(termId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (courseCode.present) {
      map['course_code'] = Variable<String>(courseCode.value);
    }
    if (institution.present) {
      map['institution'] = Variable<String>(institution.value);
    }
    if (teacherNames.present) {
      map['teacher_names'] = Variable<String>(teacherNames.value);
    }
    if (totalStudents.present) {
      map['total_students'] = Variable<int>(totalStudents.value);
    }
    if (workflowState.present) {
      map['workflow_state'] = Variable<String>(workflowState.value);
    }
    if (courseFormat.present) {
      map['course_format'] = Variable<String>(courseFormat.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoursesCompanion(')
          ..write('id: $id, ')
          ..write('termId: $termId, ')
          ..write('name: $name, ')
          ..write('courseCode: $courseCode, ')
          ..write('institution: $institution, ')
          ..write('teacherNames: $teacherNames, ')
          ..write('totalStudents: $totalStudents, ')
          ..write('workflowState: $workflowState, ')
          ..write('courseFormat: $courseFormat')
          ..write(')'))
        .toString();
  }
}

class $CalendarEventsTable extends CalendarEvents
    with TableInfo<$CalendarEventsTable, CalendarEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _termIdMeta = const VerificationMeta('termId');
  @override
  late final GeneratedColumn<int> termId = GeneratedColumn<int>(
      'term_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _courseIdMeta =
      const VerificationMeta('courseId');
  @override
  late final GeneratedColumn<int> courseId = GeneratedColumn<int>(
      'course_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _contextNameMeta =
      const VerificationMeta('contextName');
  @override
  late final GeneratedColumn<String> contextName = GeneratedColumn<String>(
      'context_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _startAtMeta =
      const VerificationMeta('startAt');
  @override
  late final GeneratedColumn<DateTime> startAt = GeneratedColumn<DateTime>(
      'start_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _endAtMeta = const VerificationMeta('endAt');
  @override
  late final GeneratedColumn<DateTime> endAt = GeneratedColumn<DateTime>(
      'end_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _allDayMeta = const VerificationMeta('allDay');
  @override
  late final GeneratedColumn<bool> allDay = GeneratedColumn<bool>(
      'all_day', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("all_day" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _htmlUrlMeta =
      const VerificationMeta('htmlUrl');
  @override
  late final GeneratedColumn<String> htmlUrl = GeneratedColumn<String>(
      'html_url', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _workflowStateMeta =
      const VerificationMeta('workflowState');
  @override
  late final GeneratedColumn<String> workflowState = GeneratedColumn<String>(
      'workflow_state', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        termId,
        courseId,
        contextName,
        title,
        description,
        startAt,
        endAt,
        allDay,
        htmlUrl,
        workflowState
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendar_events';
  @override
  VerificationContext validateIntegrity(Insertable<CalendarEventRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('term_id')) {
      context.handle(_termIdMeta,
          termId.isAcceptableOrUnknown(data['term_id']!, _termIdMeta));
    } else if (isInserting) {
      context.missing(_termIdMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(_courseIdMeta,
          courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta));
    }
    if (data.containsKey('context_name')) {
      context.handle(
          _contextNameMeta,
          contextName.isAcceptableOrUnknown(
              data['context_name']!, _contextNameMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('start_at')) {
      context.handle(_startAtMeta,
          startAt.isAcceptableOrUnknown(data['start_at']!, _startAtMeta));
    }
    if (data.containsKey('end_at')) {
      context.handle(
          _endAtMeta, endAt.isAcceptableOrUnknown(data['end_at']!, _endAtMeta));
    }
    if (data.containsKey('all_day')) {
      context.handle(_allDayMeta,
          allDay.isAcceptableOrUnknown(data['all_day']!, _allDayMeta));
    }
    if (data.containsKey('html_url')) {
      context.handle(_htmlUrlMeta,
          htmlUrl.isAcceptableOrUnknown(data['html_url']!, _htmlUrlMeta));
    }
    if (data.containsKey('workflow_state')) {
      context.handle(
          _workflowStateMeta,
          workflowState.isAcceptableOrUnknown(
              data['workflow_state']!, _workflowStateMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CalendarEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarEventRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      termId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}term_id'])!,
      courseId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}course_id']),
      contextName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}context_name'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      startAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_at']),
      endAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end_at']),
      allDay: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}all_day'])!,
      htmlUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}html_url'])!,
      workflowState: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workflow_state'])!,
    );
  }

  @override
  $CalendarEventsTable createAlias(String alias) {
    return $CalendarEventsTable(attachedDatabase, alias);
  }
}

class CalendarEventRow extends DataClass
    implements Insertable<CalendarEventRow> {
  final String id;
  final int termId;
  final int? courseId;
  final String contextName;
  final String title;
  final String description;
  final DateTime? startAt;
  final DateTime? endAt;
  final bool allDay;
  final String htmlUrl;
  final String workflowState;
  const CalendarEventRow(
      {required this.id,
      required this.termId,
      this.courseId,
      required this.contextName,
      required this.title,
      required this.description,
      this.startAt,
      this.endAt,
      required this.allDay,
      required this.htmlUrl,
      required this.workflowState});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['term_id'] = Variable<int>(termId);
    if (!nullToAbsent || courseId != null) {
      map['course_id'] = Variable<int>(courseId);
    }
    map['context_name'] = Variable<String>(contextName);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || startAt != null) {
      map['start_at'] = Variable<DateTime>(startAt);
    }
    if (!nullToAbsent || endAt != null) {
      map['end_at'] = Variable<DateTime>(endAt);
    }
    map['all_day'] = Variable<bool>(allDay);
    map['html_url'] = Variable<String>(htmlUrl);
    map['workflow_state'] = Variable<String>(workflowState);
    return map;
  }

  CalendarEventsCompanion toCompanion(bool nullToAbsent) {
    return CalendarEventsCompanion(
      id: Value(id),
      termId: Value(termId),
      courseId: courseId == null && nullToAbsent
          ? const Value.absent()
          : Value(courseId),
      contextName: Value(contextName),
      title: Value(title),
      description: Value(description),
      startAt: startAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startAt),
      endAt:
          endAt == null && nullToAbsent ? const Value.absent() : Value(endAt),
      allDay: Value(allDay),
      htmlUrl: Value(htmlUrl),
      workflowState: Value(workflowState),
    );
  }

  factory CalendarEventRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarEventRow(
      id: serializer.fromJson<String>(json['id']),
      termId: serializer.fromJson<int>(json['termId']),
      courseId: serializer.fromJson<int?>(json['courseId']),
      contextName: serializer.fromJson<String>(json['contextName']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      startAt: serializer.fromJson<DateTime?>(json['startAt']),
      endAt: serializer.fromJson<DateTime?>(json['endAt']),
      allDay: serializer.fromJson<bool>(json['allDay']),
      htmlUrl: serializer.fromJson<String>(json['htmlUrl']),
      workflowState: serializer.fromJson<String>(json['workflowState']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'termId': serializer.toJson<int>(termId),
      'courseId': serializer.toJson<int?>(courseId),
      'contextName': serializer.toJson<String>(contextName),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'startAt': serializer.toJson<DateTime?>(startAt),
      'endAt': serializer.toJson<DateTime?>(endAt),
      'allDay': serializer.toJson<bool>(allDay),
      'htmlUrl': serializer.toJson<String>(htmlUrl),
      'workflowState': serializer.toJson<String>(workflowState),
    };
  }

  CalendarEventRow copyWith(
          {String? id,
          int? termId,
          Value<int?> courseId = const Value.absent(),
          String? contextName,
          String? title,
          String? description,
          Value<DateTime?> startAt = const Value.absent(),
          Value<DateTime?> endAt = const Value.absent(),
          bool? allDay,
          String? htmlUrl,
          String? workflowState}) =>
      CalendarEventRow(
        id: id ?? this.id,
        termId: termId ?? this.termId,
        courseId: courseId.present ? courseId.value : this.courseId,
        contextName: contextName ?? this.contextName,
        title: title ?? this.title,
        description: description ?? this.description,
        startAt: startAt.present ? startAt.value : this.startAt,
        endAt: endAt.present ? endAt.value : this.endAt,
        allDay: allDay ?? this.allDay,
        htmlUrl: htmlUrl ?? this.htmlUrl,
        workflowState: workflowState ?? this.workflowState,
      );
  CalendarEventRow copyWithCompanion(CalendarEventsCompanion data) {
    return CalendarEventRow(
      id: data.id.present ? data.id.value : this.id,
      termId: data.termId.present ? data.termId.value : this.termId,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      contextName:
          data.contextName.present ? data.contextName.value : this.contextName,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      startAt: data.startAt.present ? data.startAt.value : this.startAt,
      endAt: data.endAt.present ? data.endAt.value : this.endAt,
      allDay: data.allDay.present ? data.allDay.value : this.allDay,
      htmlUrl: data.htmlUrl.present ? data.htmlUrl.value : this.htmlUrl,
      workflowState: data.workflowState.present
          ? data.workflowState.value
          : this.workflowState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarEventRow(')
          ..write('id: $id, ')
          ..write('termId: $termId, ')
          ..write('courseId: $courseId, ')
          ..write('contextName: $contextName, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('allDay: $allDay, ')
          ..write('htmlUrl: $htmlUrl, ')
          ..write('workflowState: $workflowState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, termId, courseId, contextName, title,
      description, startAt, endAt, allDay, htmlUrl, workflowState);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarEventRow &&
          other.id == this.id &&
          other.termId == this.termId &&
          other.courseId == this.courseId &&
          other.contextName == this.contextName &&
          other.title == this.title &&
          other.description == this.description &&
          other.startAt == this.startAt &&
          other.endAt == this.endAt &&
          other.allDay == this.allDay &&
          other.htmlUrl == this.htmlUrl &&
          other.workflowState == this.workflowState);
}

class CalendarEventsCompanion extends UpdateCompanion<CalendarEventRow> {
  final Value<String> id;
  final Value<int> termId;
  final Value<int?> courseId;
  final Value<String> contextName;
  final Value<String> title;
  final Value<String> description;
  final Value<DateTime?> startAt;
  final Value<DateTime?> endAt;
  final Value<bool> allDay;
  final Value<String> htmlUrl;
  final Value<String> workflowState;
  final Value<int> rowid;
  const CalendarEventsCompanion({
    this.id = const Value.absent(),
    this.termId = const Value.absent(),
    this.courseId = const Value.absent(),
    this.contextName = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.allDay = const Value.absent(),
    this.htmlUrl = const Value.absent(),
    this.workflowState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarEventsCompanion.insert({
    required String id,
    required int termId,
    this.courseId = const Value.absent(),
    this.contextName = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    this.startAt = const Value.absent(),
    this.endAt = const Value.absent(),
    this.allDay = const Value.absent(),
    this.htmlUrl = const Value.absent(),
    this.workflowState = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        termId = Value(termId),
        title = Value(title);
  static Insertable<CalendarEventRow> custom({
    Expression<String>? id,
    Expression<int>? termId,
    Expression<int>? courseId,
    Expression<String>? contextName,
    Expression<String>? title,
    Expression<String>? description,
    Expression<DateTime>? startAt,
    Expression<DateTime>? endAt,
    Expression<bool>? allDay,
    Expression<String>? htmlUrl,
    Expression<String>? workflowState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (termId != null) 'term_id': termId,
      if (courseId != null) 'course_id': courseId,
      if (contextName != null) 'context_name': contextName,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (startAt != null) 'start_at': startAt,
      if (endAt != null) 'end_at': endAt,
      if (allDay != null) 'all_day': allDay,
      if (htmlUrl != null) 'html_url': htmlUrl,
      if (workflowState != null) 'workflow_state': workflowState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarEventsCompanion copyWith(
      {Value<String>? id,
      Value<int>? termId,
      Value<int?>? courseId,
      Value<String>? contextName,
      Value<String>? title,
      Value<String>? description,
      Value<DateTime?>? startAt,
      Value<DateTime?>? endAt,
      Value<bool>? allDay,
      Value<String>? htmlUrl,
      Value<String>? workflowState,
      Value<int>? rowid}) {
    return CalendarEventsCompanion(
      id: id ?? this.id,
      termId: termId ?? this.termId,
      courseId: courseId ?? this.courseId,
      contextName: contextName ?? this.contextName,
      title: title ?? this.title,
      description: description ?? this.description,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      allDay: allDay ?? this.allDay,
      htmlUrl: htmlUrl ?? this.htmlUrl,
      workflowState: workflowState ?? this.workflowState,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (termId.present) {
      map['term_id'] = Variable<int>(termId.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<int>(courseId.value);
    }
    if (contextName.present) {
      map['context_name'] = Variable<String>(contextName.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (startAt.present) {
      map['start_at'] = Variable<DateTime>(startAt.value);
    }
    if (endAt.present) {
      map['end_at'] = Variable<DateTime>(endAt.value);
    }
    if (allDay.present) {
      map['all_day'] = Variable<bool>(allDay.value);
    }
    if (htmlUrl.present) {
      map['html_url'] = Variable<String>(htmlUrl.value);
    }
    if (workflowState.present) {
      map['workflow_state'] = Variable<String>(workflowState.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarEventsCompanion(')
          ..write('id: $id, ')
          ..write('termId: $termId, ')
          ..write('courseId: $courseId, ')
          ..write('contextName: $contextName, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('startAt: $startAt, ')
          ..write('endAt: $endAt, ')
          ..write('allDay: $allDay, ')
          ..write('htmlUrl: $htmlUrl, ')
          ..write('workflowState: $workflowState, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnnouncementsTable extends Announcements
    with TableInfo<$AnnouncementsTable, AnnouncementRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnnouncementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _termIdMeta = const VerificationMeta('termId');
  @override
  late final GeneratedColumn<int> termId = GeneratedColumn<int>(
      'term_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _courseIdMeta =
      const VerificationMeta('courseId');
  @override
  late final GeneratedColumn<int> courseId = GeneratedColumn<int>(
      'course_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _contextNameMeta =
      const VerificationMeta('contextName');
  @override
  late final GeneratedColumn<String> contextName = GeneratedColumn<String>(
      'context_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _messageMeta =
      const VerificationMeta('message');
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
      'message', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _authorNameMeta =
      const VerificationMeta('authorName');
  @override
  late final GeneratedColumn<String> authorName = GeneratedColumn<String>(
      'author_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _postedAtMeta =
      const VerificationMeta('postedAt');
  @override
  late final GeneratedColumn<DateTime> postedAt = GeneratedColumn<DateTime>(
      'posted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _htmlUrlMeta =
      const VerificationMeta('htmlUrl');
  @override
  late final GeneratedColumn<String> htmlUrl = GeneratedColumn<String>(
      'html_url', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        termId,
        courseId,
        contextName,
        title,
        message,
        authorName,
        postedAt,
        htmlUrl
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'announcements';
  @override
  VerificationContext validateIntegrity(Insertable<AnnouncementRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('term_id')) {
      context.handle(_termIdMeta,
          termId.isAcceptableOrUnknown(data['term_id']!, _termIdMeta));
    } else if (isInserting) {
      context.missing(_termIdMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(_courseIdMeta,
          courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta));
    }
    if (data.containsKey('context_name')) {
      context.handle(
          _contextNameMeta,
          contextName.isAcceptableOrUnknown(
              data['context_name']!, _contextNameMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('message')) {
      context.handle(_messageMeta,
          message.isAcceptableOrUnknown(data['message']!, _messageMeta));
    }
    if (data.containsKey('author_name')) {
      context.handle(
          _authorNameMeta,
          authorName.isAcceptableOrUnknown(
              data['author_name']!, _authorNameMeta));
    }
    if (data.containsKey('posted_at')) {
      context.handle(_postedAtMeta,
          postedAt.isAcceptableOrUnknown(data['posted_at']!, _postedAtMeta));
    }
    if (data.containsKey('html_url')) {
      context.handle(_htmlUrlMeta,
          htmlUrl.isAcceptableOrUnknown(data['html_url']!, _htmlUrlMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnnouncementRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnnouncementRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      termId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}term_id'])!,
      courseId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}course_id']),
      contextName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}context_name'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      message: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}message'])!,
      authorName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author_name'])!,
      postedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}posted_at']),
      htmlUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}html_url'])!,
    );
  }

  @override
  $AnnouncementsTable createAlias(String alias) {
    return $AnnouncementsTable(attachedDatabase, alias);
  }
}

class AnnouncementRow extends DataClass implements Insertable<AnnouncementRow> {
  final String id;
  final int termId;
  final int? courseId;
  final String contextName;
  final String title;
  final String message;
  final String authorName;
  final DateTime? postedAt;
  final String htmlUrl;
  const AnnouncementRow(
      {required this.id,
      required this.termId,
      this.courseId,
      required this.contextName,
      required this.title,
      required this.message,
      required this.authorName,
      this.postedAt,
      required this.htmlUrl});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['term_id'] = Variable<int>(termId);
    if (!nullToAbsent || courseId != null) {
      map['course_id'] = Variable<int>(courseId);
    }
    map['context_name'] = Variable<String>(contextName);
    map['title'] = Variable<String>(title);
    map['message'] = Variable<String>(message);
    map['author_name'] = Variable<String>(authorName);
    if (!nullToAbsent || postedAt != null) {
      map['posted_at'] = Variable<DateTime>(postedAt);
    }
    map['html_url'] = Variable<String>(htmlUrl);
    return map;
  }

  AnnouncementsCompanion toCompanion(bool nullToAbsent) {
    return AnnouncementsCompanion(
      id: Value(id),
      termId: Value(termId),
      courseId: courseId == null && nullToAbsent
          ? const Value.absent()
          : Value(courseId),
      contextName: Value(contextName),
      title: Value(title),
      message: Value(message),
      authorName: Value(authorName),
      postedAt: postedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(postedAt),
      htmlUrl: Value(htmlUrl),
    );
  }

  factory AnnouncementRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnnouncementRow(
      id: serializer.fromJson<String>(json['id']),
      termId: serializer.fromJson<int>(json['termId']),
      courseId: serializer.fromJson<int?>(json['courseId']),
      contextName: serializer.fromJson<String>(json['contextName']),
      title: serializer.fromJson<String>(json['title']),
      message: serializer.fromJson<String>(json['message']),
      authorName: serializer.fromJson<String>(json['authorName']),
      postedAt: serializer.fromJson<DateTime?>(json['postedAt']),
      htmlUrl: serializer.fromJson<String>(json['htmlUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'termId': serializer.toJson<int>(termId),
      'courseId': serializer.toJson<int?>(courseId),
      'contextName': serializer.toJson<String>(contextName),
      'title': serializer.toJson<String>(title),
      'message': serializer.toJson<String>(message),
      'authorName': serializer.toJson<String>(authorName),
      'postedAt': serializer.toJson<DateTime?>(postedAt),
      'htmlUrl': serializer.toJson<String>(htmlUrl),
    };
  }

  AnnouncementRow copyWith(
          {String? id,
          int? termId,
          Value<int?> courseId = const Value.absent(),
          String? contextName,
          String? title,
          String? message,
          String? authorName,
          Value<DateTime?> postedAt = const Value.absent(),
          String? htmlUrl}) =>
      AnnouncementRow(
        id: id ?? this.id,
        termId: termId ?? this.termId,
        courseId: courseId.present ? courseId.value : this.courseId,
        contextName: contextName ?? this.contextName,
        title: title ?? this.title,
        message: message ?? this.message,
        authorName: authorName ?? this.authorName,
        postedAt: postedAt.present ? postedAt.value : this.postedAt,
        htmlUrl: htmlUrl ?? this.htmlUrl,
      );
  AnnouncementRow copyWithCompanion(AnnouncementsCompanion data) {
    return AnnouncementRow(
      id: data.id.present ? data.id.value : this.id,
      termId: data.termId.present ? data.termId.value : this.termId,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      contextName:
          data.contextName.present ? data.contextName.value : this.contextName,
      title: data.title.present ? data.title.value : this.title,
      message: data.message.present ? data.message.value : this.message,
      authorName:
          data.authorName.present ? data.authorName.value : this.authorName,
      postedAt: data.postedAt.present ? data.postedAt.value : this.postedAt,
      htmlUrl: data.htmlUrl.present ? data.htmlUrl.value : this.htmlUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnnouncementRow(')
          ..write('id: $id, ')
          ..write('termId: $termId, ')
          ..write('courseId: $courseId, ')
          ..write('contextName: $contextName, ')
          ..write('title: $title, ')
          ..write('message: $message, ')
          ..write('authorName: $authorName, ')
          ..write('postedAt: $postedAt, ')
          ..write('htmlUrl: $htmlUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, termId, courseId, contextName, title,
      message, authorName, postedAt, htmlUrl);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnnouncementRow &&
          other.id == this.id &&
          other.termId == this.termId &&
          other.courseId == this.courseId &&
          other.contextName == this.contextName &&
          other.title == this.title &&
          other.message == this.message &&
          other.authorName == this.authorName &&
          other.postedAt == this.postedAt &&
          other.htmlUrl == this.htmlUrl);
}

class AnnouncementsCompanion extends UpdateCompanion<AnnouncementRow> {
  final Value<String> id;
  final Value<int> termId;
  final Value<int?> courseId;
  final Value<String> contextName;
  final Value<String> title;
  final Value<String> message;
  final Value<String> authorName;
  final Value<DateTime?> postedAt;
  final Value<String> htmlUrl;
  final Value<int> rowid;
  const AnnouncementsCompanion({
    this.id = const Value.absent(),
    this.termId = const Value.absent(),
    this.courseId = const Value.absent(),
    this.contextName = const Value.absent(),
    this.title = const Value.absent(),
    this.message = const Value.absent(),
    this.authorName = const Value.absent(),
    this.postedAt = const Value.absent(),
    this.htmlUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnnouncementsCompanion.insert({
    required String id,
    required int termId,
    this.courseId = const Value.absent(),
    this.contextName = const Value.absent(),
    required String title,
    this.message = const Value.absent(),
    this.authorName = const Value.absent(),
    this.postedAt = const Value.absent(),
    this.htmlUrl = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        termId = Value(termId),
        title = Value(title);
  static Insertable<AnnouncementRow> custom({
    Expression<String>? id,
    Expression<int>? termId,
    Expression<int>? courseId,
    Expression<String>? contextName,
    Expression<String>? title,
    Expression<String>? message,
    Expression<String>? authorName,
    Expression<DateTime>? postedAt,
    Expression<String>? htmlUrl,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (termId != null) 'term_id': termId,
      if (courseId != null) 'course_id': courseId,
      if (contextName != null) 'context_name': contextName,
      if (title != null) 'title': title,
      if (message != null) 'message': message,
      if (authorName != null) 'author_name': authorName,
      if (postedAt != null) 'posted_at': postedAt,
      if (htmlUrl != null) 'html_url': htmlUrl,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnnouncementsCompanion copyWith(
      {Value<String>? id,
      Value<int>? termId,
      Value<int?>? courseId,
      Value<String>? contextName,
      Value<String>? title,
      Value<String>? message,
      Value<String>? authorName,
      Value<DateTime?>? postedAt,
      Value<String>? htmlUrl,
      Value<int>? rowid}) {
    return AnnouncementsCompanion(
      id: id ?? this.id,
      termId: termId ?? this.termId,
      courseId: courseId ?? this.courseId,
      contextName: contextName ?? this.contextName,
      title: title ?? this.title,
      message: message ?? this.message,
      authorName: authorName ?? this.authorName,
      postedAt: postedAt ?? this.postedAt,
      htmlUrl: htmlUrl ?? this.htmlUrl,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (termId.present) {
      map['term_id'] = Variable<int>(termId.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<int>(courseId.value);
    }
    if (contextName.present) {
      map['context_name'] = Variable<String>(contextName.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (authorName.present) {
      map['author_name'] = Variable<String>(authorName.value);
    }
    if (postedAt.present) {
      map['posted_at'] = Variable<DateTime>(postedAt.value);
    }
    if (htmlUrl.present) {
      map['html_url'] = Variable<String>(htmlUrl.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnnouncementsCompanion(')
          ..write('id: $id, ')
          ..write('termId: $termId, ')
          ..write('courseId: $courseId, ')
          ..write('contextName: $contextName, ')
          ..write('title: $title, ')
          ..write('message: $message, ')
          ..write('authorName: $authorName, ')
          ..write('postedAt: $postedAt, ')
          ..write('htmlUrl: $htmlUrl, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CacheMetaEntriesTable extends CacheMetaEntries
    with TableInfo<$CacheMetaEntriesTable, CacheMetaEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheMetaEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fetchedAtMeta =
      const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
      'fetched_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_meta_entries';
  @override
  VerificationContext validateIntegrity(Insertable<CacheMetaEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta,
          fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  CacheMetaEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheMetaEntry(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      fetchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fetched_at'])!,
    );
  }

  @override
  $CacheMetaEntriesTable createAlias(String alias) {
    return $CacheMetaEntriesTable(attachedDatabase, alias);
  }
}

class CacheMetaEntry extends DataClass implements Insertable<CacheMetaEntry> {
  final String key;
  final DateTime fetchedAt;
  const CacheMetaEntry({required this.key, required this.fetchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CacheMetaEntriesCompanion toCompanion(bool nullToAbsent) {
    return CacheMetaEntriesCompanion(
      key: Value(key),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CacheMetaEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheMetaEntry(
      key: serializer.fromJson<String>(json['key']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CacheMetaEntry copyWith({String? key, DateTime? fetchedAt}) => CacheMetaEntry(
        key: key ?? this.key,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
  CacheMetaEntry copyWithCompanion(CacheMetaEntriesCompanion data) {
    return CacheMetaEntry(
      key: data.key.present ? data.key.value : this.key,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheMetaEntry(')
          ..write('key: $key, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheMetaEntry &&
          other.key == this.key &&
          other.fetchedAt == this.fetchedAt);
}

class CacheMetaEntriesCompanion extends UpdateCompanion<CacheMetaEntry> {
  final Value<String> key;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const CacheMetaEntriesCompanion({
    this.key = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheMetaEntriesCompanion.insert({
    required String key,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        fetchedAt = Value(fetchedAt);
  static Insertable<CacheMetaEntry> custom({
    Expression<String>? key,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheMetaEntriesCompanion copyWith(
      {Value<String>? key, Value<DateTime>? fetchedAt, Value<int>? rowid}) {
    return CacheMetaEntriesCompanion(
      key: key ?? this.key,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheMetaEntriesCompanion(')
          ..write('key: $key, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CanvasCacheEntriesTable extends CanvasCacheEntries
    with TableInfo<$CanvasCacheEntriesTable, CanvasCacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CanvasCacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fetchedAtMeta =
      const VerificationMeta('fetchedAt');
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
      'fetched_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, payload, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'canvas_cache_entries';
  @override
  VerificationContext validateIntegrity(Insertable<CanvasCacheEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(_fetchedAtMeta,
          fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta));
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  CanvasCacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CanvasCacheEntry(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      fetchedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}fetched_at'])!,
    );
  }

  @override
  $CanvasCacheEntriesTable createAlias(String alias) {
    return $CanvasCacheEntriesTable(attachedDatabase, alias);
  }
}

class CanvasCacheEntry extends DataClass
    implements Insertable<CanvasCacheEntry> {
  final String key;
  final String payload;
  final DateTime fetchedAt;
  const CanvasCacheEntry(
      {required this.key, required this.payload, required this.fetchedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['payload'] = Variable<String>(payload);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CanvasCacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return CanvasCacheEntriesCompanion(
      key: Value(key),
      payload: Value(payload),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CanvasCacheEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CanvasCacheEntry(
      key: serializer.fromJson<String>(json['key']),
      payload: serializer.fromJson<String>(json['payload']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'payload': serializer.toJson<String>(payload),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CanvasCacheEntry copyWith(
          {String? key, String? payload, DateTime? fetchedAt}) =>
      CanvasCacheEntry(
        key: key ?? this.key,
        payload: payload ?? this.payload,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );
  CanvasCacheEntry copyWithCompanion(CanvasCacheEntriesCompanion data) {
    return CanvasCacheEntry(
      key: data.key.present ? data.key.value : this.key,
      payload: data.payload.present ? data.payload.value : this.payload,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CanvasCacheEntry(')
          ..write('key: $key, ')
          ..write('payload: $payload, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, payload, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CanvasCacheEntry &&
          other.key == this.key &&
          other.payload == this.payload &&
          other.fetchedAt == this.fetchedAt);
}

class CanvasCacheEntriesCompanion extends UpdateCompanion<CanvasCacheEntry> {
  final Value<String> key;
  final Value<String> payload;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const CanvasCacheEntriesCompanion({
    this.key = const Value.absent(),
    this.payload = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CanvasCacheEntriesCompanion.insert({
    required String key,
    required String payload,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        payload = Value(payload),
        fetchedAt = Value(fetchedAt);
  static Insertable<CanvasCacheEntry> custom({
    Expression<String>? key,
    Expression<String>? payload,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (payload != null) 'payload': payload,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CanvasCacheEntriesCompanion copyWith(
      {Value<String>? key,
      Value<String>? payload,
      Value<DateTime>? fetchedAt,
      Value<int>? rowid}) {
    return CanvasCacheEntriesCompanion(
      key: key ?? this.key,
      payload: payload ?? this.payload,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CanvasCacheEntriesCompanion(')
          ..write('key: $key, ')
          ..write('payload: $payload, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationSettingsTable extends NotificationSettings
    with TableInfo<$NotificationSettingsTable, NotificationSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
      'owner', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _generationMeta =
      const VerificationMeta('generation');
  @override
  late final GeneratedColumn<String> generation = GeneratedColumn<String>(
      'generation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _enabledMeta =
      const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
      'enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'));
  static const VerificationMeta _lastAttemptMeta =
      const VerificationMeta('lastAttempt');
  @override
  late final GeneratedColumn<int> lastAttempt = GeneratedColumn<int>(
      'last_attempt', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _lastSuccessMeta =
      const VerificationMeta('lastSuccess');
  @override
  late final GeneratedColumn<int> lastSuccess = GeneratedColumn<int>(
      'last_success', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('아직 확인하지 않았습니다.'));
  static const VerificationMeta _leaseMeta = const VerificationMeta('lease');
  @override
  late final GeneratedColumn<String> lease = GeneratedColumn<String>(
      'lease', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<int> cursor = GeneratedColumn<int>(
      'cursor', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _leaseUntilMeta =
      const VerificationMeta('leaseUntil');
  @override
  late final GeneratedColumn<int> leaseUntil = GeneratedColumn<int>(
      'lease_until', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        owner,
        generation,
        enabled,
        lastAttempt,
        lastSuccess,
        status,
        lease,
        cursor,
        leaseUntil
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_settings';
  @override
  VerificationContext validateIntegrity(
      Insertable<NotificationSetting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('owner')) {
      context.handle(
          _ownerMeta, owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta));
    } else if (isInserting) {
      context.missing(_ownerMeta);
    }
    if (data.containsKey('generation')) {
      context.handle(
          _generationMeta,
          generation.isAcceptableOrUnknown(
              data['generation']!, _generationMeta));
    } else if (isInserting) {
      context.missing(_generationMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta,
          enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    } else if (isInserting) {
      context.missing(_enabledMeta);
    }
    if (data.containsKey('last_attempt')) {
      context.handle(
          _lastAttemptMeta,
          lastAttempt.isAcceptableOrUnknown(
              data['last_attempt']!, _lastAttemptMeta));
    }
    if (data.containsKey('last_success')) {
      context.handle(
          _lastSuccessMeta,
          lastSuccess.isAcceptableOrUnknown(
              data['last_success']!, _lastSuccessMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('lease')) {
      context.handle(
          _leaseMeta, lease.isAcceptableOrUnknown(data['lease']!, _leaseMeta));
    }
    if (data.containsKey('cursor')) {
      context.handle(_cursorMeta,
          cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta));
    }
    if (data.containsKey('lease_until')) {
      context.handle(
          _leaseUntilMeta,
          leaseUntil.isAcceptableOrUnknown(
              data['lease_until']!, _leaseUntilMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NotificationSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationSetting(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      owner: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner'])!,
      generation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}generation'])!,
      enabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}enabled'])!,
      lastAttempt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_attempt']),
      lastSuccess: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_success']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      lease: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lease']),
      cursor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cursor'])!,
      leaseUntil: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}lease_until']),
    );
  }

  @override
  $NotificationSettingsTable createAlias(String alias) {
    return $NotificationSettingsTable(attachedDatabase, alias);
  }
}

class NotificationSetting extends DataClass
    implements Insertable<NotificationSetting> {
  final int id;
  final String owner;
  final String generation;
  final bool enabled;
  final int? lastAttempt;
  final int? lastSuccess;
  final String status;
  final String? lease;
  final int cursor;
  final int? leaseUntil;
  const NotificationSetting(
      {required this.id,
      required this.owner,
      required this.generation,
      required this.enabled,
      this.lastAttempt,
      this.lastSuccess,
      required this.status,
      this.lease,
      required this.cursor,
      this.leaseUntil});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['owner'] = Variable<String>(owner);
    map['generation'] = Variable<String>(generation);
    map['enabled'] = Variable<bool>(enabled);
    if (!nullToAbsent || lastAttempt != null) {
      map['last_attempt'] = Variable<int>(lastAttempt);
    }
    if (!nullToAbsent || lastSuccess != null) {
      map['last_success'] = Variable<int>(lastSuccess);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || lease != null) {
      map['lease'] = Variable<String>(lease);
    }
    map['cursor'] = Variable<int>(cursor);
    if (!nullToAbsent || leaseUntil != null) {
      map['lease_until'] = Variable<int>(leaseUntil);
    }
    return map;
  }

  NotificationSettingsCompanion toCompanion(bool nullToAbsent) {
    return NotificationSettingsCompanion(
      id: Value(id),
      owner: Value(owner),
      generation: Value(generation),
      enabled: Value(enabled),
      lastAttempt: lastAttempt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttempt),
      lastSuccess: lastSuccess == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSuccess),
      status: Value(status),
      lease:
          lease == null && nullToAbsent ? const Value.absent() : Value(lease),
      cursor: Value(cursor),
      leaseUntil: leaseUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseUntil),
    );
  }

  factory NotificationSetting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationSetting(
      id: serializer.fromJson<int>(json['id']),
      owner: serializer.fromJson<String>(json['owner']),
      generation: serializer.fromJson<String>(json['generation']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      lastAttempt: serializer.fromJson<int?>(json['lastAttempt']),
      lastSuccess: serializer.fromJson<int?>(json['lastSuccess']),
      status: serializer.fromJson<String>(json['status']),
      lease: serializer.fromJson<String?>(json['lease']),
      cursor: serializer.fromJson<int>(json['cursor']),
      leaseUntil: serializer.fromJson<int?>(json['leaseUntil']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'owner': serializer.toJson<String>(owner),
      'generation': serializer.toJson<String>(generation),
      'enabled': serializer.toJson<bool>(enabled),
      'lastAttempt': serializer.toJson<int?>(lastAttempt),
      'lastSuccess': serializer.toJson<int?>(lastSuccess),
      'status': serializer.toJson<String>(status),
      'lease': serializer.toJson<String?>(lease),
      'cursor': serializer.toJson<int>(cursor),
      'leaseUntil': serializer.toJson<int?>(leaseUntil),
    };
  }

  NotificationSetting copyWith(
          {int? id,
          String? owner,
          String? generation,
          bool? enabled,
          Value<int?> lastAttempt = const Value.absent(),
          Value<int?> lastSuccess = const Value.absent(),
          String? status,
          Value<String?> lease = const Value.absent(),
          int? cursor,
          Value<int?> leaseUntil = const Value.absent()}) =>
      NotificationSetting(
        id: id ?? this.id,
        owner: owner ?? this.owner,
        generation: generation ?? this.generation,
        enabled: enabled ?? this.enabled,
        lastAttempt: lastAttempt.present ? lastAttempt.value : this.lastAttempt,
        lastSuccess: lastSuccess.present ? lastSuccess.value : this.lastSuccess,
        status: status ?? this.status,
        lease: lease.present ? lease.value : this.lease,
        cursor: cursor ?? this.cursor,
        leaseUntil: leaseUntil.present ? leaseUntil.value : this.leaseUntil,
      );
  NotificationSetting copyWithCompanion(NotificationSettingsCompanion data) {
    return NotificationSetting(
      id: data.id.present ? data.id.value : this.id,
      owner: data.owner.present ? data.owner.value : this.owner,
      generation:
          data.generation.present ? data.generation.value : this.generation,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      lastAttempt:
          data.lastAttempt.present ? data.lastAttempt.value : this.lastAttempt,
      lastSuccess:
          data.lastSuccess.present ? data.lastSuccess.value : this.lastSuccess,
      status: data.status.present ? data.status.value : this.status,
      lease: data.lease.present ? data.lease.value : this.lease,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
      leaseUntil:
          data.leaseUntil.present ? data.leaseUntil.value : this.leaseUntil,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationSetting(')
          ..write('id: $id, ')
          ..write('owner: $owner, ')
          ..write('generation: $generation, ')
          ..write('enabled: $enabled, ')
          ..write('lastAttempt: $lastAttempt, ')
          ..write('lastSuccess: $lastSuccess, ')
          ..write('status: $status, ')
          ..write('lease: $lease, ')
          ..write('cursor: $cursor, ')
          ..write('leaseUntil: $leaseUntil')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, owner, generation, enabled, lastAttempt,
      lastSuccess, status, lease, cursor, leaseUntil);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationSetting &&
          other.id == this.id &&
          other.owner == this.owner &&
          other.generation == this.generation &&
          other.enabled == this.enabled &&
          other.lastAttempt == this.lastAttempt &&
          other.lastSuccess == this.lastSuccess &&
          other.status == this.status &&
          other.lease == this.lease &&
          other.cursor == this.cursor &&
          other.leaseUntil == this.leaseUntil);
}

class NotificationSettingsCompanion
    extends UpdateCompanion<NotificationSetting> {
  final Value<int> id;
  final Value<String> owner;
  final Value<String> generation;
  final Value<bool> enabled;
  final Value<int?> lastAttempt;
  final Value<int?> lastSuccess;
  final Value<String> status;
  final Value<String?> lease;
  final Value<int> cursor;
  final Value<int?> leaseUntil;
  const NotificationSettingsCompanion({
    this.id = const Value.absent(),
    this.owner = const Value.absent(),
    this.generation = const Value.absent(),
    this.enabled = const Value.absent(),
    this.lastAttempt = const Value.absent(),
    this.lastSuccess = const Value.absent(),
    this.status = const Value.absent(),
    this.lease = const Value.absent(),
    this.cursor = const Value.absent(),
    this.leaseUntil = const Value.absent(),
  });
  NotificationSettingsCompanion.insert({
    this.id = const Value.absent(),
    required String owner,
    required String generation,
    required bool enabled,
    this.lastAttempt = const Value.absent(),
    this.lastSuccess = const Value.absent(),
    this.status = const Value.absent(),
    this.lease = const Value.absent(),
    this.cursor = const Value.absent(),
    this.leaseUntil = const Value.absent(),
  })  : owner = Value(owner),
        generation = Value(generation),
        enabled = Value(enabled);
  static Insertable<NotificationSetting> custom({
    Expression<int>? id,
    Expression<String>? owner,
    Expression<String>? generation,
    Expression<bool>? enabled,
    Expression<int>? lastAttempt,
    Expression<int>? lastSuccess,
    Expression<String>? status,
    Expression<String>? lease,
    Expression<int>? cursor,
    Expression<int>? leaseUntil,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (owner != null) 'owner': owner,
      if (generation != null) 'generation': generation,
      if (enabled != null) 'enabled': enabled,
      if (lastAttempt != null) 'last_attempt': lastAttempt,
      if (lastSuccess != null) 'last_success': lastSuccess,
      if (status != null) 'status': status,
      if (lease != null) 'lease': lease,
      if (cursor != null) 'cursor': cursor,
      if (leaseUntil != null) 'lease_until': leaseUntil,
    });
  }

  NotificationSettingsCompanion copyWith(
      {Value<int>? id,
      Value<String>? owner,
      Value<String>? generation,
      Value<bool>? enabled,
      Value<int?>? lastAttempt,
      Value<int?>? lastSuccess,
      Value<String>? status,
      Value<String?>? lease,
      Value<int>? cursor,
      Value<int?>? leaseUntil}) {
    return NotificationSettingsCompanion(
      id: id ?? this.id,
      owner: owner ?? this.owner,
      generation: generation ?? this.generation,
      enabled: enabled ?? this.enabled,
      lastAttempt: lastAttempt ?? this.lastAttempt,
      lastSuccess: lastSuccess ?? this.lastSuccess,
      status: status ?? this.status,
      lease: lease ?? this.lease,
      cursor: cursor ?? this.cursor,
      leaseUntil: leaseUntil ?? this.leaseUntil,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (generation.present) {
      map['generation'] = Variable<String>(generation.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (lastAttempt.present) {
      map['last_attempt'] = Variable<int>(lastAttempt.value);
    }
    if (lastSuccess.present) {
      map['last_success'] = Variable<int>(lastSuccess.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (lease.present) {
      map['lease'] = Variable<String>(lease.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<int>(cursor.value);
    }
    if (leaseUntil.present) {
      map['lease_until'] = Variable<int>(leaseUntil.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationSettingsCompanion(')
          ..write('id: $id, ')
          ..write('owner: $owner, ')
          ..write('generation: $generation, ')
          ..write('enabled: $enabled, ')
          ..write('lastAttempt: $lastAttempt, ')
          ..write('lastSuccess: $lastSuccess, ')
          ..write('status: $status, ')
          ..write('lease: $lease, ')
          ..write('cursor: $cursor, ')
          ..write('leaseUntil: $leaseUntil')
          ..write(')'))
        .toString();
  }
}

class $NotificationBaselinesTable extends NotificationBaselines
    with TableInfo<$NotificationBaselinesTable, NotificationBaseline> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationBaselinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
      'scope', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [scope];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_baselines';
  @override
  VerificationContext validateIntegrity(
      Insertable<NotificationBaseline> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
          _scopeMeta, scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta));
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope};
  @override
  NotificationBaseline map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationBaseline(
      scope: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scope'])!,
    );
  }

  @override
  $NotificationBaselinesTable createAlias(String alias) {
    return $NotificationBaselinesTable(attachedDatabase, alias);
  }
}

class NotificationBaseline extends DataClass
    implements Insertable<NotificationBaseline> {
  final String scope;
  const NotificationBaseline({required this.scope});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    return map;
  }

  NotificationBaselinesCompanion toCompanion(bool nullToAbsent) {
    return NotificationBaselinesCompanion(
      scope: Value(scope),
    );
  }

  factory NotificationBaseline.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationBaseline(
      scope: serializer.fromJson<String>(json['scope']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
    };
  }

  NotificationBaseline copyWith({String? scope}) => NotificationBaseline(
        scope: scope ?? this.scope,
      );
  NotificationBaseline copyWithCompanion(NotificationBaselinesCompanion data) {
    return NotificationBaseline(
      scope: data.scope.present ? data.scope.value : this.scope,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationBaseline(')
          ..write('scope: $scope')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => scope.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationBaseline && other.scope == this.scope);
}

class NotificationBaselinesCompanion
    extends UpdateCompanion<NotificationBaseline> {
  final Value<String> scope;
  final Value<int> rowid;
  const NotificationBaselinesCompanion({
    this.scope = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationBaselinesCompanion.insert({
    required String scope,
    this.rowid = const Value.absent(),
  }) : scope = Value(scope);
  static Insertable<NotificationBaseline> custom({
    Expression<String>? scope,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationBaselinesCompanion copyWith(
      {Value<String>? scope, Value<int>? rowid}) {
    return NotificationBaselinesCompanion(
      scope: scope ?? this.scope,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationBaselinesCompanion(')
          ..write('scope: $scope, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationSeenItemsTable extends NotificationSeenItems
    with TableInfo<$NotificationSeenItemsTable, NotificationSeenItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationSeenItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
      'scope', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [scope, itemId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_seen_items';
  @override
  VerificationContext validateIntegrity(
      Insertable<NotificationSeenItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
          _scopeMeta, scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta));
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope, itemId};
  @override
  NotificationSeenItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationSeenItem(
      scope: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}scope'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
    );
  }

  @override
  $NotificationSeenItemsTable createAlias(String alias) {
    return $NotificationSeenItemsTable(attachedDatabase, alias);
  }
}

class NotificationSeenItem extends DataClass
    implements Insertable<NotificationSeenItem> {
  final String scope;
  final String itemId;
  const NotificationSeenItem({required this.scope, required this.itemId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['item_id'] = Variable<String>(itemId);
    return map;
  }

  NotificationSeenItemsCompanion toCompanion(bool nullToAbsent) {
    return NotificationSeenItemsCompanion(
      scope: Value(scope),
      itemId: Value(itemId),
    );
  }

  factory NotificationSeenItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationSeenItem(
      scope: serializer.fromJson<String>(json['scope']),
      itemId: serializer.fromJson<String>(json['itemId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'itemId': serializer.toJson<String>(itemId),
    };
  }

  NotificationSeenItem copyWith({String? scope, String? itemId}) =>
      NotificationSeenItem(
        scope: scope ?? this.scope,
        itemId: itemId ?? this.itemId,
      );
  NotificationSeenItem copyWithCompanion(NotificationSeenItemsCompanion data) {
    return NotificationSeenItem(
      scope: data.scope.present ? data.scope.value : this.scope,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationSeenItem(')
          ..write('scope: $scope, ')
          ..write('itemId: $itemId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(scope, itemId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationSeenItem &&
          other.scope == this.scope &&
          other.itemId == this.itemId);
}

class NotificationSeenItemsCompanion
    extends UpdateCompanion<NotificationSeenItem> {
  final Value<String> scope;
  final Value<String> itemId;
  final Value<int> rowid;
  const NotificationSeenItemsCompanion({
    this.scope = const Value.absent(),
    this.itemId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationSeenItemsCompanion.insert({
    required String scope,
    required String itemId,
    this.rowid = const Value.absent(),
  })  : scope = Value(scope),
        itemId = Value(itemId);
  static Insertable<NotificationSeenItem> custom({
    Expression<String>? scope,
    Expression<String>? itemId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (itemId != null) 'item_id': itemId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationSeenItemsCompanion copyWith(
      {Value<String>? scope, Value<String>? itemId, Value<int>? rowid}) {
    return NotificationSeenItemsCompanion(
      scope: scope ?? this.scope,
      itemId: itemId ?? this.itemId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationSeenItemsCompanion(')
          ..write('scope: $scope, ')
          ..write('itemId: $itemId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationOutboxTable extends NotificationOutbox
    with TableInfo<$NotificationOutboxTable, NotificationOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _generationMeta =
      const VerificationMeta('generation');
  @override
  late final GeneratedColumn<String> generation = GeneratedColumn<String>(
      'generation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
      'owner', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _courseIdMeta =
      const VerificationMeta('courseId');
  @override
  late final GeneratedColumn<int> courseId = GeneratedColumn<int>(
      'course_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _courseNameMeta =
      const VerificationMeta('courseName');
  @override
  late final GeneratedColumn<String> courseName = GeneratedColumn<String>(
      'course_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _detectedAtMeta =
      const VerificationMeta('detectedAt');
  @override
  late final GeneratedColumn<DateTime> detectedAt = GeneratedColumn<DateTime>(
      'detected_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _deliveredMeta =
      const VerificationMeta('delivered');
  @override
  late final GeneratedColumn<bool> delivered = GeneratedColumn<bool>(
      'delivered', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("delivered" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        generation,
        owner,
        courseId,
        courseName,
        kind,
        title,
        itemId,
        detectedAt,
        delivered
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_outbox';
  @override
  VerificationContext validateIntegrity(
      Insertable<NotificationOutboxData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('generation')) {
      context.handle(
          _generationMeta,
          generation.isAcceptableOrUnknown(
              data['generation']!, _generationMeta));
    } else if (isInserting) {
      context.missing(_generationMeta);
    }
    if (data.containsKey('owner')) {
      context.handle(
          _ownerMeta, owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta));
    } else if (isInserting) {
      context.missing(_ownerMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(_courseIdMeta,
          courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta));
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('course_name')) {
      context.handle(
          _courseNameMeta,
          courseName.isAcceptableOrUnknown(
              data['course_name']!, _courseNameMeta));
    } else if (isInserting) {
      context.missing(_courseNameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    }
    if (data.containsKey('detected_at')) {
      context.handle(
          _detectedAtMeta,
          detectedAt.isAcceptableOrUnknown(
              data['detected_at']!, _detectedAtMeta));
    }
    if (data.containsKey('delivered')) {
      context.handle(_deliveredMeta,
          delivered.isAcceptableOrUnknown(data['delivered']!, _deliveredMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NotificationOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationOutboxData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      generation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}generation'])!,
      owner: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner'])!,
      courseId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}course_id'])!,
      courseName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}course_name'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      detectedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}detected_at'])!,
      delivered: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}delivered'])!,
    );
  }

  @override
  $NotificationOutboxTable createAlias(String alias) {
    return $NotificationOutboxTable(attachedDatabase, alias);
  }
}

class NotificationOutboxData extends DataClass
    implements Insertable<NotificationOutboxData> {
  final int id;
  final String generation;
  final String owner;
  final int courseId;
  final String courseName;
  final String kind;
  final String title;
  final String itemId;
  final DateTime detectedAt;
  final bool delivered;
  const NotificationOutboxData(
      {required this.id,
      required this.generation,
      required this.owner,
      required this.courseId,
      required this.courseName,
      required this.kind,
      required this.title,
      required this.itemId,
      required this.detectedAt,
      required this.delivered});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['generation'] = Variable<String>(generation);
    map['owner'] = Variable<String>(owner);
    map['course_id'] = Variable<int>(courseId);
    map['course_name'] = Variable<String>(courseName);
    map['kind'] = Variable<String>(kind);
    map['title'] = Variable<String>(title);
    map['item_id'] = Variable<String>(itemId);
    map['detected_at'] = Variable<DateTime>(detectedAt);
    map['delivered'] = Variable<bool>(delivered);
    return map;
  }

  NotificationOutboxCompanion toCompanion(bool nullToAbsent) {
    return NotificationOutboxCompanion(
      id: Value(id),
      generation: Value(generation),
      owner: Value(owner),
      courseId: Value(courseId),
      courseName: Value(courseName),
      kind: Value(kind),
      title: Value(title),
      itemId: Value(itemId),
      detectedAt: Value(detectedAt),
      delivered: Value(delivered),
    );
  }

  factory NotificationOutboxData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationOutboxData(
      id: serializer.fromJson<int>(json['id']),
      generation: serializer.fromJson<String>(json['generation']),
      owner: serializer.fromJson<String>(json['owner']),
      courseId: serializer.fromJson<int>(json['courseId']),
      courseName: serializer.fromJson<String>(json['courseName']),
      kind: serializer.fromJson<String>(json['kind']),
      title: serializer.fromJson<String>(json['title']),
      itemId: serializer.fromJson<String>(json['itemId']),
      detectedAt: serializer.fromJson<DateTime>(json['detectedAt']),
      delivered: serializer.fromJson<bool>(json['delivered']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'generation': serializer.toJson<String>(generation),
      'owner': serializer.toJson<String>(owner),
      'courseId': serializer.toJson<int>(courseId),
      'courseName': serializer.toJson<String>(courseName),
      'kind': serializer.toJson<String>(kind),
      'title': serializer.toJson<String>(title),
      'itemId': serializer.toJson<String>(itemId),
      'detectedAt': serializer.toJson<DateTime>(detectedAt),
      'delivered': serializer.toJson<bool>(delivered),
    };
  }

  NotificationOutboxData copyWith(
          {int? id,
          String? generation,
          String? owner,
          int? courseId,
          String? courseName,
          String? kind,
          String? title,
          String? itemId,
          DateTime? detectedAt,
          bool? delivered}) =>
      NotificationOutboxData(
        id: id ?? this.id,
        generation: generation ?? this.generation,
        owner: owner ?? this.owner,
        courseId: courseId ?? this.courseId,
        courseName: courseName ?? this.courseName,
        kind: kind ?? this.kind,
        title: title ?? this.title,
        itemId: itemId ?? this.itemId,
        detectedAt: detectedAt ?? this.detectedAt,
        delivered: delivered ?? this.delivered,
      );
  NotificationOutboxData copyWithCompanion(NotificationOutboxCompanion data) {
    return NotificationOutboxData(
      id: data.id.present ? data.id.value : this.id,
      generation:
          data.generation.present ? data.generation.value : this.generation,
      owner: data.owner.present ? data.owner.value : this.owner,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      courseName:
          data.courseName.present ? data.courseName.value : this.courseName,
      kind: data.kind.present ? data.kind.value : this.kind,
      title: data.title.present ? data.title.value : this.title,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      detectedAt:
          data.detectedAt.present ? data.detectedAt.value : this.detectedAt,
      delivered: data.delivered.present ? data.delivered.value : this.delivered,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationOutboxData(')
          ..write('id: $id, ')
          ..write('generation: $generation, ')
          ..write('owner: $owner, ')
          ..write('courseId: $courseId, ')
          ..write('courseName: $courseName, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('itemId: $itemId, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('delivered: $delivered')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, generation, owner, courseId, courseName,
      kind, title, itemId, detectedAt, delivered);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationOutboxData &&
          other.id == this.id &&
          other.generation == this.generation &&
          other.owner == this.owner &&
          other.courseId == this.courseId &&
          other.courseName == this.courseName &&
          other.kind == this.kind &&
          other.title == this.title &&
          other.itemId == this.itemId &&
          other.detectedAt == this.detectedAt &&
          other.delivered == this.delivered);
}

class NotificationOutboxCompanion
    extends UpdateCompanion<NotificationOutboxData> {
  final Value<int> id;
  final Value<String> generation;
  final Value<String> owner;
  final Value<int> courseId;
  final Value<String> courseName;
  final Value<String> kind;
  final Value<String> title;
  final Value<String> itemId;
  final Value<DateTime> detectedAt;
  final Value<bool> delivered;
  const NotificationOutboxCompanion({
    this.id = const Value.absent(),
    this.generation = const Value.absent(),
    this.owner = const Value.absent(),
    this.courseId = const Value.absent(),
    this.courseName = const Value.absent(),
    this.kind = const Value.absent(),
    this.title = const Value.absent(),
    this.itemId = const Value.absent(),
    this.detectedAt = const Value.absent(),
    this.delivered = const Value.absent(),
  });
  NotificationOutboxCompanion.insert({
    this.id = const Value.absent(),
    required String generation,
    required String owner,
    required int courseId,
    required String courseName,
    required String kind,
    required String title,
    this.itemId = const Value.absent(),
    this.detectedAt = const Value.absent(),
    this.delivered = const Value.absent(),
  })  : generation = Value(generation),
        owner = Value(owner),
        courseId = Value(courseId),
        courseName = Value(courseName),
        kind = Value(kind),
        title = Value(title);
  static Insertable<NotificationOutboxData> custom({
    Expression<int>? id,
    Expression<String>? generation,
    Expression<String>? owner,
    Expression<int>? courseId,
    Expression<String>? courseName,
    Expression<String>? kind,
    Expression<String>? title,
    Expression<String>? itemId,
    Expression<DateTime>? detectedAt,
    Expression<bool>? delivered,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (generation != null) 'generation': generation,
      if (owner != null) 'owner': owner,
      if (courseId != null) 'course_id': courseId,
      if (courseName != null) 'course_name': courseName,
      if (kind != null) 'kind': kind,
      if (title != null) 'title': title,
      if (itemId != null) 'item_id': itemId,
      if (detectedAt != null) 'detected_at': detectedAt,
      if (delivered != null) 'delivered': delivered,
    });
  }

  NotificationOutboxCompanion copyWith(
      {Value<int>? id,
      Value<String>? generation,
      Value<String>? owner,
      Value<int>? courseId,
      Value<String>? courseName,
      Value<String>? kind,
      Value<String>? title,
      Value<String>? itemId,
      Value<DateTime>? detectedAt,
      Value<bool>? delivered}) {
    return NotificationOutboxCompanion(
      id: id ?? this.id,
      generation: generation ?? this.generation,
      owner: owner ?? this.owner,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      itemId: itemId ?? this.itemId,
      detectedAt: detectedAt ?? this.detectedAt,
      delivered: delivered ?? this.delivered,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (generation.present) {
      map['generation'] = Variable<String>(generation.value);
    }
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<int>(courseId.value);
    }
    if (courseName.present) {
      map['course_name'] = Variable<String>(courseName.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (detectedAt.present) {
      map['detected_at'] = Variable<DateTime>(detectedAt.value);
    }
    if (delivered.present) {
      map['delivered'] = Variable<bool>(delivered.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationOutboxCompanion(')
          ..write('id: $id, ')
          ..write('generation: $generation, ')
          ..write('owner: $owner, ')
          ..write('courseId: $courseId, ')
          ..write('courseName: $courseName, ')
          ..write('kind: $kind, ')
          ..write('title: $title, ')
          ..write('itemId: $itemId, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('delivered: $delivered')
          ..write(')'))
        .toString();
  }
}

class $DownloadSettingsTable extends DownloadSettings
    with TableInfo<$DownloadSettingsTable, DownloadSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
      'owner', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _treeUriMeta =
      const VerificationMeta('treeUri');
  @override
  late final GeneratedColumn<String> treeUri = GeneratedColumn<String>(
      'tree_uri', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _folderNameMeta =
      const VerificationMeta('folderName');
  @override
  late final GeneratedColumn<String> folderName = GeneratedColumn<String>(
      'folder_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _enabledMeta =
      const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
      'enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _generationMeta =
      const VerificationMeta('generation');
  @override
  late final GeneratedColumn<String> generation = GeneratedColumn<String>(
      'generation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _leaseMeta = const VerificationMeta('lease');
  @override
  late final GeneratedColumn<String> lease = GeneratedColumn<String>(
      'lease', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _leaseUntilMeta =
      const VerificationMeta('leaseUntil');
  @override
  late final GeneratedColumn<int> leaseUntil = GeneratedColumn<int>(
      'lease_until', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _lastAttemptMeta =
      const VerificationMeta('lastAttempt');
  @override
  late final GeneratedColumn<int> lastAttempt = GeneratedColumn<int>(
      'last_attempt', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('저장 폴더를 선택해 주세요.'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        owner,
        treeUri,
        folderName,
        enabled,
        generation,
        lease,
        leaseUntil,
        lastAttempt,
        status
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_settings';
  @override
  VerificationContext validateIntegrity(Insertable<DownloadSetting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('owner')) {
      context.handle(
          _ownerMeta, owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta));
    } else if (isInserting) {
      context.missing(_ownerMeta);
    }
    if (data.containsKey('tree_uri')) {
      context.handle(_treeUriMeta,
          treeUri.isAcceptableOrUnknown(data['tree_uri']!, _treeUriMeta));
    } else if (isInserting) {
      context.missing(_treeUriMeta);
    }
    if (data.containsKey('folder_name')) {
      context.handle(
          _folderNameMeta,
          folderName.isAcceptableOrUnknown(
              data['folder_name']!, _folderNameMeta));
    } else if (isInserting) {
      context.missing(_folderNameMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta,
          enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('generation')) {
      context.handle(
          _generationMeta,
          generation.isAcceptableOrUnknown(
              data['generation']!, _generationMeta));
    } else if (isInserting) {
      context.missing(_generationMeta);
    }
    if (data.containsKey('lease')) {
      context.handle(
          _leaseMeta, lease.isAcceptableOrUnknown(data['lease']!, _leaseMeta));
    }
    if (data.containsKey('lease_until')) {
      context.handle(
          _leaseUntilMeta,
          leaseUntil.isAcceptableOrUnknown(
              data['lease_until']!, _leaseUntilMeta));
    }
    if (data.containsKey('last_attempt')) {
      context.handle(
          _lastAttemptMeta,
          lastAttempt.isAcceptableOrUnknown(
              data['last_attempt']!, _lastAttemptMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadSetting(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      owner: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner'])!,
      treeUri: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tree_uri'])!,
      folderName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}folder_name'])!,
      enabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}enabled'])!,
      generation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}generation'])!,
      lease: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lease']),
      leaseUntil: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}lease_until']),
      lastAttempt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_attempt']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
    );
  }

  @override
  $DownloadSettingsTable createAlias(String alias) {
    return $DownloadSettingsTable(attachedDatabase, alias);
  }
}

class DownloadSetting extends DataClass implements Insertable<DownloadSetting> {
  final int id;
  final String owner;
  final String treeUri;
  final String folderName;
  final bool enabled;
  final String generation;
  final String? lease;
  final int? leaseUntil;
  final int? lastAttempt;
  final String status;
  const DownloadSetting(
      {required this.id,
      required this.owner,
      required this.treeUri,
      required this.folderName,
      required this.enabled,
      required this.generation,
      this.lease,
      this.leaseUntil,
      this.lastAttempt,
      required this.status});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['owner'] = Variable<String>(owner);
    map['tree_uri'] = Variable<String>(treeUri);
    map['folder_name'] = Variable<String>(folderName);
    map['enabled'] = Variable<bool>(enabled);
    map['generation'] = Variable<String>(generation);
    if (!nullToAbsent || lease != null) {
      map['lease'] = Variable<String>(lease);
    }
    if (!nullToAbsent || leaseUntil != null) {
      map['lease_until'] = Variable<int>(leaseUntil);
    }
    if (!nullToAbsent || lastAttempt != null) {
      map['last_attempt'] = Variable<int>(lastAttempt);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  DownloadSettingsCompanion toCompanion(bool nullToAbsent) {
    return DownloadSettingsCompanion(
      id: Value(id),
      owner: Value(owner),
      treeUri: Value(treeUri),
      folderName: Value(folderName),
      enabled: Value(enabled),
      generation: Value(generation),
      lease:
          lease == null && nullToAbsent ? const Value.absent() : Value(lease),
      leaseUntil: leaseUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseUntil),
      lastAttempt: lastAttempt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttempt),
      status: Value(status),
    );
  }

  factory DownloadSetting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadSetting(
      id: serializer.fromJson<int>(json['id']),
      owner: serializer.fromJson<String>(json['owner']),
      treeUri: serializer.fromJson<String>(json['treeUri']),
      folderName: serializer.fromJson<String>(json['folderName']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      generation: serializer.fromJson<String>(json['generation']),
      lease: serializer.fromJson<String?>(json['lease']),
      leaseUntil: serializer.fromJson<int?>(json['leaseUntil']),
      lastAttempt: serializer.fromJson<int?>(json['lastAttempt']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'owner': serializer.toJson<String>(owner),
      'treeUri': serializer.toJson<String>(treeUri),
      'folderName': serializer.toJson<String>(folderName),
      'enabled': serializer.toJson<bool>(enabled),
      'generation': serializer.toJson<String>(generation),
      'lease': serializer.toJson<String?>(lease),
      'leaseUntil': serializer.toJson<int?>(leaseUntil),
      'lastAttempt': serializer.toJson<int?>(lastAttempt),
      'status': serializer.toJson<String>(status),
    };
  }

  DownloadSetting copyWith(
          {int? id,
          String? owner,
          String? treeUri,
          String? folderName,
          bool? enabled,
          String? generation,
          Value<String?> lease = const Value.absent(),
          Value<int?> leaseUntil = const Value.absent(),
          Value<int?> lastAttempt = const Value.absent(),
          String? status}) =>
      DownloadSetting(
        id: id ?? this.id,
        owner: owner ?? this.owner,
        treeUri: treeUri ?? this.treeUri,
        folderName: folderName ?? this.folderName,
        enabled: enabled ?? this.enabled,
        generation: generation ?? this.generation,
        lease: lease.present ? lease.value : this.lease,
        leaseUntil: leaseUntil.present ? leaseUntil.value : this.leaseUntil,
        lastAttempt: lastAttempt.present ? lastAttempt.value : this.lastAttempt,
        status: status ?? this.status,
      );
  DownloadSetting copyWithCompanion(DownloadSettingsCompanion data) {
    return DownloadSetting(
      id: data.id.present ? data.id.value : this.id,
      owner: data.owner.present ? data.owner.value : this.owner,
      treeUri: data.treeUri.present ? data.treeUri.value : this.treeUri,
      folderName:
          data.folderName.present ? data.folderName.value : this.folderName,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      generation:
          data.generation.present ? data.generation.value : this.generation,
      lease: data.lease.present ? data.lease.value : this.lease,
      leaseUntil:
          data.leaseUntil.present ? data.leaseUntil.value : this.leaseUntil,
      lastAttempt:
          data.lastAttempt.present ? data.lastAttempt.value : this.lastAttempt,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadSetting(')
          ..write('id: $id, ')
          ..write('owner: $owner, ')
          ..write('treeUri: $treeUri, ')
          ..write('folderName: $folderName, ')
          ..write('enabled: $enabled, ')
          ..write('generation: $generation, ')
          ..write('lease: $lease, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('lastAttempt: $lastAttempt, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, owner, treeUri, folderName, enabled,
      generation, lease, leaseUntil, lastAttempt, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadSetting &&
          other.id == this.id &&
          other.owner == this.owner &&
          other.treeUri == this.treeUri &&
          other.folderName == this.folderName &&
          other.enabled == this.enabled &&
          other.generation == this.generation &&
          other.lease == this.lease &&
          other.leaseUntil == this.leaseUntil &&
          other.lastAttempt == this.lastAttempt &&
          other.status == this.status);
}

class DownloadSettingsCompanion extends UpdateCompanion<DownloadSetting> {
  final Value<int> id;
  final Value<String> owner;
  final Value<String> treeUri;
  final Value<String> folderName;
  final Value<bool> enabled;
  final Value<String> generation;
  final Value<String?> lease;
  final Value<int?> leaseUntil;
  final Value<int?> lastAttempt;
  final Value<String> status;
  const DownloadSettingsCompanion({
    this.id = const Value.absent(),
    this.owner = const Value.absent(),
    this.treeUri = const Value.absent(),
    this.folderName = const Value.absent(),
    this.enabled = const Value.absent(),
    this.generation = const Value.absent(),
    this.lease = const Value.absent(),
    this.leaseUntil = const Value.absent(),
    this.lastAttempt = const Value.absent(),
    this.status = const Value.absent(),
  });
  DownloadSettingsCompanion.insert({
    this.id = const Value.absent(),
    required String owner,
    required String treeUri,
    required String folderName,
    this.enabled = const Value.absent(),
    required String generation,
    this.lease = const Value.absent(),
    this.leaseUntil = const Value.absent(),
    this.lastAttempt = const Value.absent(),
    this.status = const Value.absent(),
  })  : owner = Value(owner),
        treeUri = Value(treeUri),
        folderName = Value(folderName),
        generation = Value(generation);
  static Insertable<DownloadSetting> custom({
    Expression<int>? id,
    Expression<String>? owner,
    Expression<String>? treeUri,
    Expression<String>? folderName,
    Expression<bool>? enabled,
    Expression<String>? generation,
    Expression<String>? lease,
    Expression<int>? leaseUntil,
    Expression<int>? lastAttempt,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (owner != null) 'owner': owner,
      if (treeUri != null) 'tree_uri': treeUri,
      if (folderName != null) 'folder_name': folderName,
      if (enabled != null) 'enabled': enabled,
      if (generation != null) 'generation': generation,
      if (lease != null) 'lease': lease,
      if (leaseUntil != null) 'lease_until': leaseUntil,
      if (lastAttempt != null) 'last_attempt': lastAttempt,
      if (status != null) 'status': status,
    });
  }

  DownloadSettingsCompanion copyWith(
      {Value<int>? id,
      Value<String>? owner,
      Value<String>? treeUri,
      Value<String>? folderName,
      Value<bool>? enabled,
      Value<String>? generation,
      Value<String?>? lease,
      Value<int?>? leaseUntil,
      Value<int?>? lastAttempt,
      Value<String>? status}) {
    return DownloadSettingsCompanion(
      id: id ?? this.id,
      owner: owner ?? this.owner,
      treeUri: treeUri ?? this.treeUri,
      folderName: folderName ?? this.folderName,
      enabled: enabled ?? this.enabled,
      generation: generation ?? this.generation,
      lease: lease ?? this.lease,
      leaseUntil: leaseUntil ?? this.leaseUntil,
      lastAttempt: lastAttempt ?? this.lastAttempt,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (treeUri.present) {
      map['tree_uri'] = Variable<String>(treeUri.value);
    }
    if (folderName.present) {
      map['folder_name'] = Variable<String>(folderName.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (generation.present) {
      map['generation'] = Variable<String>(generation.value);
    }
    if (lease.present) {
      map['lease'] = Variable<String>(lease.value);
    }
    if (leaseUntil.present) {
      map['lease_until'] = Variable<int>(leaseUntil.value);
    }
    if (lastAttempt.present) {
      map['last_attempt'] = Variable<int>(lastAttempt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadSettingsCompanion(')
          ..write('id: $id, ')
          ..write('owner: $owner, ')
          ..write('treeUri: $treeUri, ')
          ..write('folderName: $folderName, ')
          ..write('enabled: $enabled, ')
          ..write('generation: $generation, ')
          ..write('lease: $lease, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('lastAttempt: $lastAttempt, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $DownloadedFilesTable extends DownloadedFiles
    with TableInfo<$DownloadedFilesTable, DownloadedFile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadedFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
      'owner', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _treeUriMeta =
      const VerificationMeta('treeUri');
  @override
  late final GeneratedColumn<String> treeUri = GeneratedColumn<String>(
      'tree_uri', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _courseIdMeta =
      const VerificationMeta('courseId');
  @override
  late final GeneratedColumn<int> courseId = GeneratedColumn<int>(
      'course_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _fileIdMeta = const VerificationMeta('fileId');
  @override
  late final GeneratedColumn<String> fileId = GeneratedColumn<String>(
      'file_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _documentUriMeta =
      const VerificationMeta('documentUri');
  @override
  late final GeneratedColumn<String> documentUri = GeneratedColumn<String>(
      'document_uri', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [owner, treeUri, courseId, fileId, documentUri];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloaded_files';
  @override
  VerificationContext validateIntegrity(Insertable<DownloadedFile> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner')) {
      context.handle(
          _ownerMeta, owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta));
    } else if (isInserting) {
      context.missing(_ownerMeta);
    }
    if (data.containsKey('tree_uri')) {
      context.handle(_treeUriMeta,
          treeUri.isAcceptableOrUnknown(data['tree_uri']!, _treeUriMeta));
    } else if (isInserting) {
      context.missing(_treeUriMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(_courseIdMeta,
          courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta));
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('file_id')) {
      context.handle(_fileIdMeta,
          fileId.isAcceptableOrUnknown(data['file_id']!, _fileIdMeta));
    } else if (isInserting) {
      context.missing(_fileIdMeta);
    }
    if (data.containsKey('document_uri')) {
      context.handle(
          _documentUriMeta,
          documentUri.isAcceptableOrUnknown(
              data['document_uri']!, _documentUriMeta));
    } else if (isInserting) {
      context.missing(_documentUriMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {owner, treeUri, courseId, fileId};
  @override
  DownloadedFile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadedFile(
      owner: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}owner'])!,
      treeUri: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tree_uri'])!,
      courseId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}course_id'])!,
      fileId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_id'])!,
      documentUri: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}document_uri'])!,
    );
  }

  @override
  $DownloadedFilesTable createAlias(String alias) {
    return $DownloadedFilesTable(attachedDatabase, alias);
  }
}

class DownloadedFile extends DataClass implements Insertable<DownloadedFile> {
  final String owner;
  final String treeUri;
  final int courseId;
  final String fileId;
  final String documentUri;
  const DownloadedFile(
      {required this.owner,
      required this.treeUri,
      required this.courseId,
      required this.fileId,
      required this.documentUri});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner'] = Variable<String>(owner);
    map['tree_uri'] = Variable<String>(treeUri);
    map['course_id'] = Variable<int>(courseId);
    map['file_id'] = Variable<String>(fileId);
    map['document_uri'] = Variable<String>(documentUri);
    return map;
  }

  DownloadedFilesCompanion toCompanion(bool nullToAbsent) {
    return DownloadedFilesCompanion(
      owner: Value(owner),
      treeUri: Value(treeUri),
      courseId: Value(courseId),
      fileId: Value(fileId),
      documentUri: Value(documentUri),
    );
  }

  factory DownloadedFile.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadedFile(
      owner: serializer.fromJson<String>(json['owner']),
      treeUri: serializer.fromJson<String>(json['treeUri']),
      courseId: serializer.fromJson<int>(json['courseId']),
      fileId: serializer.fromJson<String>(json['fileId']),
      documentUri: serializer.fromJson<String>(json['documentUri']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'owner': serializer.toJson<String>(owner),
      'treeUri': serializer.toJson<String>(treeUri),
      'courseId': serializer.toJson<int>(courseId),
      'fileId': serializer.toJson<String>(fileId),
      'documentUri': serializer.toJson<String>(documentUri),
    };
  }

  DownloadedFile copyWith(
          {String? owner,
          String? treeUri,
          int? courseId,
          String? fileId,
          String? documentUri}) =>
      DownloadedFile(
        owner: owner ?? this.owner,
        treeUri: treeUri ?? this.treeUri,
        courseId: courseId ?? this.courseId,
        fileId: fileId ?? this.fileId,
        documentUri: documentUri ?? this.documentUri,
      );
  DownloadedFile copyWithCompanion(DownloadedFilesCompanion data) {
    return DownloadedFile(
      owner: data.owner.present ? data.owner.value : this.owner,
      treeUri: data.treeUri.present ? data.treeUri.value : this.treeUri,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      fileId: data.fileId.present ? data.fileId.value : this.fileId,
      documentUri:
          data.documentUri.present ? data.documentUri.value : this.documentUri,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadedFile(')
          ..write('owner: $owner, ')
          ..write('treeUri: $treeUri, ')
          ..write('courseId: $courseId, ')
          ..write('fileId: $fileId, ')
          ..write('documentUri: $documentUri')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(owner, treeUri, courseId, fileId, documentUri);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadedFile &&
          other.owner == this.owner &&
          other.treeUri == this.treeUri &&
          other.courseId == this.courseId &&
          other.fileId == this.fileId &&
          other.documentUri == this.documentUri);
}

class DownloadedFilesCompanion extends UpdateCompanion<DownloadedFile> {
  final Value<String> owner;
  final Value<String> treeUri;
  final Value<int> courseId;
  final Value<String> fileId;
  final Value<String> documentUri;
  final Value<int> rowid;
  const DownloadedFilesCompanion({
    this.owner = const Value.absent(),
    this.treeUri = const Value.absent(),
    this.courseId = const Value.absent(),
    this.fileId = const Value.absent(),
    this.documentUri = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadedFilesCompanion.insert({
    required String owner,
    required String treeUri,
    required int courseId,
    required String fileId,
    required String documentUri,
    this.rowid = const Value.absent(),
  })  : owner = Value(owner),
        treeUri = Value(treeUri),
        courseId = Value(courseId),
        fileId = Value(fileId),
        documentUri = Value(documentUri);
  static Insertable<DownloadedFile> custom({
    Expression<String>? owner,
    Expression<String>? treeUri,
    Expression<int>? courseId,
    Expression<String>? fileId,
    Expression<String>? documentUri,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (owner != null) 'owner': owner,
      if (treeUri != null) 'tree_uri': treeUri,
      if (courseId != null) 'course_id': courseId,
      if (fileId != null) 'file_id': fileId,
      if (documentUri != null) 'document_uri': documentUri,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadedFilesCompanion copyWith(
      {Value<String>? owner,
      Value<String>? treeUri,
      Value<int>? courseId,
      Value<String>? fileId,
      Value<String>? documentUri,
      Value<int>? rowid}) {
    return DownloadedFilesCompanion(
      owner: owner ?? this.owner,
      treeUri: treeUri ?? this.treeUri,
      courseId: courseId ?? this.courseId,
      fileId: fileId ?? this.fileId,
      documentUri: documentUri ?? this.documentUri,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (treeUri.present) {
      map['tree_uri'] = Variable<String>(treeUri.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<int>(courseId.value);
    }
    if (fileId.present) {
      map['file_id'] = Variable<String>(fileId.value);
    }
    if (documentUri.present) {
      map['document_uri'] = Variable<String>(documentUri.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadedFilesCompanion(')
          ..write('owner: $owner, ')
          ..write('treeUri: $treeUri, ')
          ..write('courseId: $courseId, ')
          ..write('fileId: $fileId, ')
          ..write('documentUri: $documentUri, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TermsTable terms = $TermsTable(this);
  late final $CoursesTable courses = $CoursesTable(this);
  late final $CalendarEventsTable calendarEvents = $CalendarEventsTable(this);
  late final $AnnouncementsTable announcements = $AnnouncementsTable(this);
  late final $CacheMetaEntriesTable cacheMetaEntries =
      $CacheMetaEntriesTable(this);
  late final $CanvasCacheEntriesTable canvasCacheEntries =
      $CanvasCacheEntriesTable(this);
  late final $NotificationSettingsTable notificationSettings =
      $NotificationSettingsTable(this);
  late final $NotificationBaselinesTable notificationBaselines =
      $NotificationBaselinesTable(this);
  late final $NotificationSeenItemsTable notificationSeenItems =
      $NotificationSeenItemsTable(this);
  late final $NotificationOutboxTable notificationOutbox =
      $NotificationOutboxTable(this);
  late final $DownloadSettingsTable downloadSettings =
      $DownloadSettingsTable(this);
  late final $DownloadedFilesTable downloadedFiles =
      $DownloadedFilesTable(this);
  late final TermsDao termsDao = TermsDao(this as AppDatabase);
  late final CoursesDao coursesDao = CoursesDao(this as AppDatabase);
  late final CalendarEventsDao calendarEventsDao =
      CalendarEventsDao(this as AppDatabase);
  late final AnnouncementsDao announcementsDao =
      AnnouncementsDao(this as AppDatabase);
  late final CacheMetaDao cacheMetaDao = CacheMetaDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        terms,
        courses,
        calendarEvents,
        announcements,
        cacheMetaEntries,
        canvasCacheEntries,
        notificationSettings,
        notificationBaselines,
        notificationSeenItems,
        notificationOutbox,
        downloadSettings,
        downloadedFiles
      ];
}

typedef $$TermsTableCreateCompanionBuilder = TermsCompanion Function({
  Value<int> id,
  required String name,
  Value<DateTime?> startAt,
  Value<DateTime?> endAt,
  Value<String> workflowState,
});
typedef $$TermsTableUpdateCompanionBuilder = TermsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<DateTime?> startAt,
  Value<DateTime?> endAt,
  Value<String> workflowState,
});

class $$TermsTableFilterComposer extends Composer<_$AppDatabase, $TermsTable> {
  $$TermsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startAt => $composableBuilder(
      column: $table.startAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endAt => $composableBuilder(
      column: $table.endAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workflowState => $composableBuilder(
      column: $table.workflowState, builder: (column) => ColumnFilters(column));
}

class $$TermsTableOrderingComposer
    extends Composer<_$AppDatabase, $TermsTable> {
  $$TermsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startAt => $composableBuilder(
      column: $table.startAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endAt => $composableBuilder(
      column: $table.endAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workflowState => $composableBuilder(
      column: $table.workflowState,
      builder: (column) => ColumnOrderings(column));
}

class $$TermsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TermsTable> {
  $$TermsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumn<String> get workflowState => $composableBuilder(
      column: $table.workflowState, builder: (column) => column);
}

class $$TermsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TermsTable,
    TermRow,
    $$TermsTableFilterComposer,
    $$TermsTableOrderingComposer,
    $$TermsTableAnnotationComposer,
    $$TermsTableCreateCompanionBuilder,
    $$TermsTableUpdateCompanionBuilder,
    (TermRow, BaseReferences<_$AppDatabase, $TermsTable, TermRow>),
    TermRow,
    PrefetchHooks Function()> {
  $$TermsTableTableManager(_$AppDatabase db, $TermsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TermsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TermsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TermsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime?> startAt = const Value.absent(),
            Value<DateTime?> endAt = const Value.absent(),
            Value<String> workflowState = const Value.absent(),
          }) =>
              TermsCompanion(
            id: id,
            name: name,
            startAt: startAt,
            endAt: endAt,
            workflowState: workflowState,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<DateTime?> startAt = const Value.absent(),
            Value<DateTime?> endAt = const Value.absent(),
            Value<String> workflowState = const Value.absent(),
          }) =>
              TermsCompanion.insert(
            id: id,
            name: name,
            startAt: startAt,
            endAt: endAt,
            workflowState: workflowState,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TermsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TermsTable,
    TermRow,
    $$TermsTableFilterComposer,
    $$TermsTableOrderingComposer,
    $$TermsTableAnnotationComposer,
    $$TermsTableCreateCompanionBuilder,
    $$TermsTableUpdateCompanionBuilder,
    (TermRow, BaseReferences<_$AppDatabase, $TermsTable, TermRow>),
    TermRow,
    PrefetchHooks Function()>;
typedef $$CoursesTableCreateCompanionBuilder = CoursesCompanion Function({
  Value<int> id,
  required int termId,
  required String name,
  required String courseCode,
  Value<String> institution,
  Value<String> teacherNames,
  Value<int> totalStudents,
  Value<String> workflowState,
  Value<String> courseFormat,
});
typedef $$CoursesTableUpdateCompanionBuilder = CoursesCompanion Function({
  Value<int> id,
  Value<int> termId,
  Value<String> name,
  Value<String> courseCode,
  Value<String> institution,
  Value<String> teacherNames,
  Value<int> totalStudents,
  Value<String> workflowState,
  Value<String> courseFormat,
});

class $$CoursesTableFilterComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get termId => $composableBuilder(
      column: $table.termId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get courseCode => $composableBuilder(
      column: $table.courseCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get institution => $composableBuilder(
      column: $table.institution, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get teacherNames => $composableBuilder(
      column: $table.teacherNames, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalStudents => $composableBuilder(
      column: $table.totalStudents, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workflowState => $composableBuilder(
      column: $table.workflowState, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get courseFormat => $composableBuilder(
      column: $table.courseFormat, builder: (column) => ColumnFilters(column));
}

class $$CoursesTableOrderingComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get termId => $composableBuilder(
      column: $table.termId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get courseCode => $composableBuilder(
      column: $table.courseCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get institution => $composableBuilder(
      column: $table.institution, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get teacherNames => $composableBuilder(
      column: $table.teacherNames,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalStudents => $composableBuilder(
      column: $table.totalStudents,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workflowState => $composableBuilder(
      column: $table.workflowState,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get courseFormat => $composableBuilder(
      column: $table.courseFormat,
      builder: (column) => ColumnOrderings(column));
}

class $$CoursesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoursesTable> {
  $$CoursesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get termId =>
      $composableBuilder(column: $table.termId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get courseCode => $composableBuilder(
      column: $table.courseCode, builder: (column) => column);

  GeneratedColumn<String> get institution => $composableBuilder(
      column: $table.institution, builder: (column) => column);

  GeneratedColumn<String> get teacherNames => $composableBuilder(
      column: $table.teacherNames, builder: (column) => column);

  GeneratedColumn<int> get totalStudents => $composableBuilder(
      column: $table.totalStudents, builder: (column) => column);

  GeneratedColumn<String> get workflowState => $composableBuilder(
      column: $table.workflowState, builder: (column) => column);

  GeneratedColumn<String> get courseFormat => $composableBuilder(
      column: $table.courseFormat, builder: (column) => column);
}

class $$CoursesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CoursesTable,
    CourseRow,
    $$CoursesTableFilterComposer,
    $$CoursesTableOrderingComposer,
    $$CoursesTableAnnotationComposer,
    $$CoursesTableCreateCompanionBuilder,
    $$CoursesTableUpdateCompanionBuilder,
    (CourseRow, BaseReferences<_$AppDatabase, $CoursesTable, CourseRow>),
    CourseRow,
    PrefetchHooks Function()> {
  $$CoursesTableTableManager(_$AppDatabase db, $CoursesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoursesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoursesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoursesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> termId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> courseCode = const Value.absent(),
            Value<String> institution = const Value.absent(),
            Value<String> teacherNames = const Value.absent(),
            Value<int> totalStudents = const Value.absent(),
            Value<String> workflowState = const Value.absent(),
            Value<String> courseFormat = const Value.absent(),
          }) =>
              CoursesCompanion(
            id: id,
            termId: termId,
            name: name,
            courseCode: courseCode,
            institution: institution,
            teacherNames: teacherNames,
            totalStudents: totalStudents,
            workflowState: workflowState,
            courseFormat: courseFormat,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int termId,
            required String name,
            required String courseCode,
            Value<String> institution = const Value.absent(),
            Value<String> teacherNames = const Value.absent(),
            Value<int> totalStudents = const Value.absent(),
            Value<String> workflowState = const Value.absent(),
            Value<String> courseFormat = const Value.absent(),
          }) =>
              CoursesCompanion.insert(
            id: id,
            termId: termId,
            name: name,
            courseCode: courseCode,
            institution: institution,
            teacherNames: teacherNames,
            totalStudents: totalStudents,
            workflowState: workflowState,
            courseFormat: courseFormat,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CoursesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CoursesTable,
    CourseRow,
    $$CoursesTableFilterComposer,
    $$CoursesTableOrderingComposer,
    $$CoursesTableAnnotationComposer,
    $$CoursesTableCreateCompanionBuilder,
    $$CoursesTableUpdateCompanionBuilder,
    (CourseRow, BaseReferences<_$AppDatabase, $CoursesTable, CourseRow>),
    CourseRow,
    PrefetchHooks Function()>;
typedef $$CalendarEventsTableCreateCompanionBuilder = CalendarEventsCompanion
    Function({
  required String id,
  required int termId,
  Value<int?> courseId,
  Value<String> contextName,
  required String title,
  Value<String> description,
  Value<DateTime?> startAt,
  Value<DateTime?> endAt,
  Value<bool> allDay,
  Value<String> htmlUrl,
  Value<String> workflowState,
  Value<int> rowid,
});
typedef $$CalendarEventsTableUpdateCompanionBuilder = CalendarEventsCompanion
    Function({
  Value<String> id,
  Value<int> termId,
  Value<int?> courseId,
  Value<String> contextName,
  Value<String> title,
  Value<String> description,
  Value<DateTime?> startAt,
  Value<DateTime?> endAt,
  Value<bool> allDay,
  Value<String> htmlUrl,
  Value<String> workflowState,
  Value<int> rowid,
});

class $$CalendarEventsTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarEventsTable> {
  $$CalendarEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get termId => $composableBuilder(
      column: $table.termId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get courseId => $composableBuilder(
      column: $table.courseId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contextName => $composableBuilder(
      column: $table.contextName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startAt => $composableBuilder(
      column: $table.startAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endAt => $composableBuilder(
      column: $table.endAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get allDay => $composableBuilder(
      column: $table.allDay, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get htmlUrl => $composableBuilder(
      column: $table.htmlUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workflowState => $composableBuilder(
      column: $table.workflowState, builder: (column) => ColumnFilters(column));
}

class $$CalendarEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarEventsTable> {
  $$CalendarEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get termId => $composableBuilder(
      column: $table.termId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get courseId => $composableBuilder(
      column: $table.courseId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contextName => $composableBuilder(
      column: $table.contextName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startAt => $composableBuilder(
      column: $table.startAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endAt => $composableBuilder(
      column: $table.endAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get allDay => $composableBuilder(
      column: $table.allDay, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get htmlUrl => $composableBuilder(
      column: $table.htmlUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workflowState => $composableBuilder(
      column: $table.workflowState,
      builder: (column) => ColumnOrderings(column));
}

class $$CalendarEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarEventsTable> {
  $$CalendarEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get termId =>
      $composableBuilder(column: $table.termId, builder: (column) => column);

  GeneratedColumn<int> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get contextName => $composableBuilder(
      column: $table.contextName, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<DateTime> get startAt =>
      $composableBuilder(column: $table.startAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endAt =>
      $composableBuilder(column: $table.endAt, builder: (column) => column);

  GeneratedColumn<bool> get allDay =>
      $composableBuilder(column: $table.allDay, builder: (column) => column);

  GeneratedColumn<String> get htmlUrl =>
      $composableBuilder(column: $table.htmlUrl, builder: (column) => column);

  GeneratedColumn<String> get workflowState => $composableBuilder(
      column: $table.workflowState, builder: (column) => column);
}

class $$CalendarEventsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CalendarEventsTable,
    CalendarEventRow,
    $$CalendarEventsTableFilterComposer,
    $$CalendarEventsTableOrderingComposer,
    $$CalendarEventsTableAnnotationComposer,
    $$CalendarEventsTableCreateCompanionBuilder,
    $$CalendarEventsTableUpdateCompanionBuilder,
    (
      CalendarEventRow,
      BaseReferences<_$AppDatabase, $CalendarEventsTable, CalendarEventRow>
    ),
    CalendarEventRow,
    PrefetchHooks Function()> {
  $$CalendarEventsTableTableManager(
      _$AppDatabase db, $CalendarEventsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int> termId = const Value.absent(),
            Value<int?> courseId = const Value.absent(),
            Value<String> contextName = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<DateTime?> startAt = const Value.absent(),
            Value<DateTime?> endAt = const Value.absent(),
            Value<bool> allDay = const Value.absent(),
            Value<String> htmlUrl = const Value.absent(),
            Value<String> workflowState = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CalendarEventsCompanion(
            id: id,
            termId: termId,
            courseId: courseId,
            contextName: contextName,
            title: title,
            description: description,
            startAt: startAt,
            endAt: endAt,
            allDay: allDay,
            htmlUrl: htmlUrl,
            workflowState: workflowState,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required int termId,
            Value<int?> courseId = const Value.absent(),
            Value<String> contextName = const Value.absent(),
            required String title,
            Value<String> description = const Value.absent(),
            Value<DateTime?> startAt = const Value.absent(),
            Value<DateTime?> endAt = const Value.absent(),
            Value<bool> allDay = const Value.absent(),
            Value<String> htmlUrl = const Value.absent(),
            Value<String> workflowState = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CalendarEventsCompanion.insert(
            id: id,
            termId: termId,
            courseId: courseId,
            contextName: contextName,
            title: title,
            description: description,
            startAt: startAt,
            endAt: endAt,
            allDay: allDay,
            htmlUrl: htmlUrl,
            workflowState: workflowState,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CalendarEventsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CalendarEventsTable,
    CalendarEventRow,
    $$CalendarEventsTableFilterComposer,
    $$CalendarEventsTableOrderingComposer,
    $$CalendarEventsTableAnnotationComposer,
    $$CalendarEventsTableCreateCompanionBuilder,
    $$CalendarEventsTableUpdateCompanionBuilder,
    (
      CalendarEventRow,
      BaseReferences<_$AppDatabase, $CalendarEventsTable, CalendarEventRow>
    ),
    CalendarEventRow,
    PrefetchHooks Function()>;
typedef $$AnnouncementsTableCreateCompanionBuilder = AnnouncementsCompanion
    Function({
  required String id,
  required int termId,
  Value<int?> courseId,
  Value<String> contextName,
  required String title,
  Value<String> message,
  Value<String> authorName,
  Value<DateTime?> postedAt,
  Value<String> htmlUrl,
  Value<int> rowid,
});
typedef $$AnnouncementsTableUpdateCompanionBuilder = AnnouncementsCompanion
    Function({
  Value<String> id,
  Value<int> termId,
  Value<int?> courseId,
  Value<String> contextName,
  Value<String> title,
  Value<String> message,
  Value<String> authorName,
  Value<DateTime?> postedAt,
  Value<String> htmlUrl,
  Value<int> rowid,
});

class $$AnnouncementsTableFilterComposer
    extends Composer<_$AppDatabase, $AnnouncementsTable> {
  $$AnnouncementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get termId => $composableBuilder(
      column: $table.termId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get courseId => $composableBuilder(
      column: $table.courseId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contextName => $composableBuilder(
      column: $table.contextName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get message => $composableBuilder(
      column: $table.message, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get authorName => $composableBuilder(
      column: $table.authorName, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get postedAt => $composableBuilder(
      column: $table.postedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get htmlUrl => $composableBuilder(
      column: $table.htmlUrl, builder: (column) => ColumnFilters(column));
}

class $$AnnouncementsTableOrderingComposer
    extends Composer<_$AppDatabase, $AnnouncementsTable> {
  $$AnnouncementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get termId => $composableBuilder(
      column: $table.termId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get courseId => $composableBuilder(
      column: $table.courseId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contextName => $composableBuilder(
      column: $table.contextName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get message => $composableBuilder(
      column: $table.message, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get authorName => $composableBuilder(
      column: $table.authorName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get postedAt => $composableBuilder(
      column: $table.postedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get htmlUrl => $composableBuilder(
      column: $table.htmlUrl, builder: (column) => ColumnOrderings(column));
}

class $$AnnouncementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnnouncementsTable> {
  $$AnnouncementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get termId =>
      $composableBuilder(column: $table.termId, builder: (column) => column);

  GeneratedColumn<int> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get contextName => $composableBuilder(
      column: $table.contextName, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<String> get authorName => $composableBuilder(
      column: $table.authorName, builder: (column) => column);

  GeneratedColumn<DateTime> get postedAt =>
      $composableBuilder(column: $table.postedAt, builder: (column) => column);

  GeneratedColumn<String> get htmlUrl =>
      $composableBuilder(column: $table.htmlUrl, builder: (column) => column);
}

class $$AnnouncementsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AnnouncementsTable,
    AnnouncementRow,
    $$AnnouncementsTableFilterComposer,
    $$AnnouncementsTableOrderingComposer,
    $$AnnouncementsTableAnnotationComposer,
    $$AnnouncementsTableCreateCompanionBuilder,
    $$AnnouncementsTableUpdateCompanionBuilder,
    (
      AnnouncementRow,
      BaseReferences<_$AppDatabase, $AnnouncementsTable, AnnouncementRow>
    ),
    AnnouncementRow,
    PrefetchHooks Function()> {
  $$AnnouncementsTableTableManager(_$AppDatabase db, $AnnouncementsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnnouncementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnnouncementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnnouncementsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int> termId = const Value.absent(),
            Value<int?> courseId = const Value.absent(),
            Value<String> contextName = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> message = const Value.absent(),
            Value<String> authorName = const Value.absent(),
            Value<DateTime?> postedAt = const Value.absent(),
            Value<String> htmlUrl = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AnnouncementsCompanion(
            id: id,
            termId: termId,
            courseId: courseId,
            contextName: contextName,
            title: title,
            message: message,
            authorName: authorName,
            postedAt: postedAt,
            htmlUrl: htmlUrl,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required int termId,
            Value<int?> courseId = const Value.absent(),
            Value<String> contextName = const Value.absent(),
            required String title,
            Value<String> message = const Value.absent(),
            Value<String> authorName = const Value.absent(),
            Value<DateTime?> postedAt = const Value.absent(),
            Value<String> htmlUrl = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AnnouncementsCompanion.insert(
            id: id,
            termId: termId,
            courseId: courseId,
            contextName: contextName,
            title: title,
            message: message,
            authorName: authorName,
            postedAt: postedAt,
            htmlUrl: htmlUrl,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AnnouncementsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AnnouncementsTable,
    AnnouncementRow,
    $$AnnouncementsTableFilterComposer,
    $$AnnouncementsTableOrderingComposer,
    $$AnnouncementsTableAnnotationComposer,
    $$AnnouncementsTableCreateCompanionBuilder,
    $$AnnouncementsTableUpdateCompanionBuilder,
    (
      AnnouncementRow,
      BaseReferences<_$AppDatabase, $AnnouncementsTable, AnnouncementRow>
    ),
    AnnouncementRow,
    PrefetchHooks Function()>;
typedef $$CacheMetaEntriesTableCreateCompanionBuilder
    = CacheMetaEntriesCompanion Function({
  required String key,
  required DateTime fetchedAt,
  Value<int> rowid,
});
typedef $$CacheMetaEntriesTableUpdateCompanionBuilder
    = CacheMetaEntriesCompanion Function({
  Value<String> key,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});

class $$CacheMetaEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CacheMetaEntriesTable> {
  $$CacheMetaEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnFilters(column));
}

class $$CacheMetaEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CacheMetaEntriesTable> {
  $$CacheMetaEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));
}

class $$CacheMetaEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CacheMetaEntriesTable> {
  $$CacheMetaEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CacheMetaEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CacheMetaEntriesTable,
    CacheMetaEntry,
    $$CacheMetaEntriesTableFilterComposer,
    $$CacheMetaEntriesTableOrderingComposer,
    $$CacheMetaEntriesTableAnnotationComposer,
    $$CacheMetaEntriesTableCreateCompanionBuilder,
    $$CacheMetaEntriesTableUpdateCompanionBuilder,
    (
      CacheMetaEntry,
      BaseReferences<_$AppDatabase, $CacheMetaEntriesTable, CacheMetaEntry>
    ),
    CacheMetaEntry,
    PrefetchHooks Function()> {
  $$CacheMetaEntriesTableTableManager(
      _$AppDatabase db, $CacheMetaEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheMetaEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheMetaEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheMetaEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<DateTime> fetchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CacheMetaEntriesCompanion(
            key: key,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required DateTime fetchedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CacheMetaEntriesCompanion.insert(
            key: key,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CacheMetaEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CacheMetaEntriesTable,
    CacheMetaEntry,
    $$CacheMetaEntriesTableFilterComposer,
    $$CacheMetaEntriesTableOrderingComposer,
    $$CacheMetaEntriesTableAnnotationComposer,
    $$CacheMetaEntriesTableCreateCompanionBuilder,
    $$CacheMetaEntriesTableUpdateCompanionBuilder,
    (
      CacheMetaEntry,
      BaseReferences<_$AppDatabase, $CacheMetaEntriesTable, CacheMetaEntry>
    ),
    CacheMetaEntry,
    PrefetchHooks Function()>;
typedef $$CanvasCacheEntriesTableCreateCompanionBuilder
    = CanvasCacheEntriesCompanion Function({
  required String key,
  required String payload,
  required DateTime fetchedAt,
  Value<int> rowid,
});
typedef $$CanvasCacheEntriesTableUpdateCompanionBuilder
    = CanvasCacheEntriesCompanion Function({
  Value<String> key,
  Value<String> payload,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});

class $$CanvasCacheEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CanvasCacheEntriesTable> {
  $$CanvasCacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnFilters(column));
}

class $$CanvasCacheEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CanvasCacheEntriesTable> {
  $$CanvasCacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
      column: $table.fetchedAt, builder: (column) => ColumnOrderings(column));
}

class $$CanvasCacheEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CanvasCacheEntriesTable> {
  $$CanvasCacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CanvasCacheEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CanvasCacheEntriesTable,
    CanvasCacheEntry,
    $$CanvasCacheEntriesTableFilterComposer,
    $$CanvasCacheEntriesTableOrderingComposer,
    $$CanvasCacheEntriesTableAnnotationComposer,
    $$CanvasCacheEntriesTableCreateCompanionBuilder,
    $$CanvasCacheEntriesTableUpdateCompanionBuilder,
    (
      CanvasCacheEntry,
      BaseReferences<_$AppDatabase, $CanvasCacheEntriesTable, CanvasCacheEntry>
    ),
    CanvasCacheEntry,
    PrefetchHooks Function()> {
  $$CanvasCacheEntriesTableTableManager(
      _$AppDatabase db, $CanvasCacheEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CanvasCacheEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CanvasCacheEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CanvasCacheEntriesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<DateTime> fetchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CanvasCacheEntriesCompanion(
            key: key,
            payload: payload,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String payload,
            required DateTime fetchedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CanvasCacheEntriesCompanion.insert(
            key: key,
            payload: payload,
            fetchedAt: fetchedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CanvasCacheEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CanvasCacheEntriesTable,
    CanvasCacheEntry,
    $$CanvasCacheEntriesTableFilterComposer,
    $$CanvasCacheEntriesTableOrderingComposer,
    $$CanvasCacheEntriesTableAnnotationComposer,
    $$CanvasCacheEntriesTableCreateCompanionBuilder,
    $$CanvasCacheEntriesTableUpdateCompanionBuilder,
    (
      CanvasCacheEntry,
      BaseReferences<_$AppDatabase, $CanvasCacheEntriesTable, CanvasCacheEntry>
    ),
    CanvasCacheEntry,
    PrefetchHooks Function()>;
typedef $$NotificationSettingsTableCreateCompanionBuilder
    = NotificationSettingsCompanion Function({
  Value<int> id,
  required String owner,
  required String generation,
  required bool enabled,
  Value<int?> lastAttempt,
  Value<int?> lastSuccess,
  Value<String> status,
  Value<String?> lease,
  Value<int> cursor,
  Value<int?> leaseUntil,
});
typedef $$NotificationSettingsTableUpdateCompanionBuilder
    = NotificationSettingsCompanion Function({
  Value<int> id,
  Value<String> owner,
  Value<String> generation,
  Value<bool> enabled,
  Value<int?> lastAttempt,
  Value<int?> lastSuccess,
  Value<String> status,
  Value<String?> lease,
  Value<int> cursor,
  Value<int?> leaseUntil,
});

class $$NotificationSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationSettingsTable> {
  $$NotificationSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get owner => $composableBuilder(
      column: $table.owner, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get generation => $composableBuilder(
      column: $table.generation, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastAttempt => $composableBuilder(
      column: $table.lastAttempt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastSuccess => $composableBuilder(
      column: $table.lastSuccess, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lease => $composableBuilder(
      column: $table.lease, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cursor => $composableBuilder(
      column: $table.cursor, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get leaseUntil => $composableBuilder(
      column: $table.leaseUntil, builder: (column) => ColumnFilters(column));
}

class $$NotificationSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationSettingsTable> {
  $$NotificationSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get owner => $composableBuilder(
      column: $table.owner, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get generation => $composableBuilder(
      column: $table.generation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastAttempt => $composableBuilder(
      column: $table.lastAttempt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastSuccess => $composableBuilder(
      column: $table.lastSuccess, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lease => $composableBuilder(
      column: $table.lease, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cursor => $composableBuilder(
      column: $table.cursor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get leaseUntil => $composableBuilder(
      column: $table.leaseUntil, builder: (column) => ColumnOrderings(column));
}

class $$NotificationSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationSettingsTable> {
  $$NotificationSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<String> get generation => $composableBuilder(
      column: $table.generation, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get lastAttempt => $composableBuilder(
      column: $table.lastAttempt, builder: (column) => column);

  GeneratedColumn<int> get lastSuccess => $composableBuilder(
      column: $table.lastSuccess, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get lease =>
      $composableBuilder(column: $table.lease, builder: (column) => column);

  GeneratedColumn<int> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);

  GeneratedColumn<int> get leaseUntil => $composableBuilder(
      column: $table.leaseUntil, builder: (column) => column);
}

class $$NotificationSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NotificationSettingsTable,
    NotificationSetting,
    $$NotificationSettingsTableFilterComposer,
    $$NotificationSettingsTableOrderingComposer,
    $$NotificationSettingsTableAnnotationComposer,
    $$NotificationSettingsTableCreateCompanionBuilder,
    $$NotificationSettingsTableUpdateCompanionBuilder,
    (
      NotificationSetting,
      BaseReferences<_$AppDatabase, $NotificationSettingsTable,
          NotificationSetting>
    ),
    NotificationSetting,
    PrefetchHooks Function()> {
  $$NotificationSettingsTableTableManager(
      _$AppDatabase db, $NotificationSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotificationSettingsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotificationSettingsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> owner = const Value.absent(),
            Value<String> generation = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<int?> lastAttempt = const Value.absent(),
            Value<int?> lastSuccess = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> lease = const Value.absent(),
            Value<int> cursor = const Value.absent(),
            Value<int?> leaseUntil = const Value.absent(),
          }) =>
              NotificationSettingsCompanion(
            id: id,
            owner: owner,
            generation: generation,
            enabled: enabled,
            lastAttempt: lastAttempt,
            lastSuccess: lastSuccess,
            status: status,
            lease: lease,
            cursor: cursor,
            leaseUntil: leaseUntil,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String owner,
            required String generation,
            required bool enabled,
            Value<int?> lastAttempt = const Value.absent(),
            Value<int?> lastSuccess = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> lease = const Value.absent(),
            Value<int> cursor = const Value.absent(),
            Value<int?> leaseUntil = const Value.absent(),
          }) =>
              NotificationSettingsCompanion.insert(
            id: id,
            owner: owner,
            generation: generation,
            enabled: enabled,
            lastAttempt: lastAttempt,
            lastSuccess: lastSuccess,
            status: status,
            lease: lease,
            cursor: cursor,
            leaseUntil: leaseUntil,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$NotificationSettingsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $NotificationSettingsTable,
        NotificationSetting,
        $$NotificationSettingsTableFilterComposer,
        $$NotificationSettingsTableOrderingComposer,
        $$NotificationSettingsTableAnnotationComposer,
        $$NotificationSettingsTableCreateCompanionBuilder,
        $$NotificationSettingsTableUpdateCompanionBuilder,
        (
          NotificationSetting,
          BaseReferences<_$AppDatabase, $NotificationSettingsTable,
              NotificationSetting>
        ),
        NotificationSetting,
        PrefetchHooks Function()>;
typedef $$NotificationBaselinesTableCreateCompanionBuilder
    = NotificationBaselinesCompanion Function({
  required String scope,
  Value<int> rowid,
});
typedef $$NotificationBaselinesTableUpdateCompanionBuilder
    = NotificationBaselinesCompanion Function({
  Value<String> scope,
  Value<int> rowid,
});

class $$NotificationBaselinesTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationBaselinesTable> {
  $$NotificationBaselinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
      column: $table.scope, builder: (column) => ColumnFilters(column));
}

class $$NotificationBaselinesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationBaselinesTable> {
  $$NotificationBaselinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
      column: $table.scope, builder: (column) => ColumnOrderings(column));
}

class $$NotificationBaselinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationBaselinesTable> {
  $$NotificationBaselinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);
}

class $$NotificationBaselinesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NotificationBaselinesTable,
    NotificationBaseline,
    $$NotificationBaselinesTableFilterComposer,
    $$NotificationBaselinesTableOrderingComposer,
    $$NotificationBaselinesTableAnnotationComposer,
    $$NotificationBaselinesTableCreateCompanionBuilder,
    $$NotificationBaselinesTableUpdateCompanionBuilder,
    (
      NotificationBaseline,
      BaseReferences<_$AppDatabase, $NotificationBaselinesTable,
          NotificationBaseline>
    ),
    NotificationBaseline,
    PrefetchHooks Function()> {
  $$NotificationBaselinesTableTableManager(
      _$AppDatabase db, $NotificationBaselinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationBaselinesTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$NotificationBaselinesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotificationBaselinesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> scope = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NotificationBaselinesCompanion(
            scope: scope,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String scope,
            Value<int> rowid = const Value.absent(),
          }) =>
              NotificationBaselinesCompanion.insert(
            scope: scope,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$NotificationBaselinesTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $NotificationBaselinesTable,
        NotificationBaseline,
        $$NotificationBaselinesTableFilterComposer,
        $$NotificationBaselinesTableOrderingComposer,
        $$NotificationBaselinesTableAnnotationComposer,
        $$NotificationBaselinesTableCreateCompanionBuilder,
        $$NotificationBaselinesTableUpdateCompanionBuilder,
        (
          NotificationBaseline,
          BaseReferences<_$AppDatabase, $NotificationBaselinesTable,
              NotificationBaseline>
        ),
        NotificationBaseline,
        PrefetchHooks Function()>;
typedef $$NotificationSeenItemsTableCreateCompanionBuilder
    = NotificationSeenItemsCompanion Function({
  required String scope,
  required String itemId,
  Value<int> rowid,
});
typedef $$NotificationSeenItemsTableUpdateCompanionBuilder
    = NotificationSeenItemsCompanion Function({
  Value<String> scope,
  Value<String> itemId,
  Value<int> rowid,
});

class $$NotificationSeenItemsTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationSeenItemsTable> {
  $$NotificationSeenItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
      column: $table.scope, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));
}

class $$NotificationSeenItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationSeenItemsTable> {
  $$NotificationSeenItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
      column: $table.scope, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));
}

class $$NotificationSeenItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationSeenItemsTable> {
  $$NotificationSeenItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);
}

class $$NotificationSeenItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NotificationSeenItemsTable,
    NotificationSeenItem,
    $$NotificationSeenItemsTableFilterComposer,
    $$NotificationSeenItemsTableOrderingComposer,
    $$NotificationSeenItemsTableAnnotationComposer,
    $$NotificationSeenItemsTableCreateCompanionBuilder,
    $$NotificationSeenItemsTableUpdateCompanionBuilder,
    (
      NotificationSeenItem,
      BaseReferences<_$AppDatabase, $NotificationSeenItemsTable,
          NotificationSeenItem>
    ),
    NotificationSeenItem,
    PrefetchHooks Function()> {
  $$NotificationSeenItemsTableTableManager(
      _$AppDatabase db, $NotificationSeenItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationSeenItemsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$NotificationSeenItemsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotificationSeenItemsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> scope = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              NotificationSeenItemsCompanion(
            scope: scope,
            itemId: itemId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String scope,
            required String itemId,
            Value<int> rowid = const Value.absent(),
          }) =>
              NotificationSeenItemsCompanion.insert(
            scope: scope,
            itemId: itemId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$NotificationSeenItemsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $NotificationSeenItemsTable,
        NotificationSeenItem,
        $$NotificationSeenItemsTableFilterComposer,
        $$NotificationSeenItemsTableOrderingComposer,
        $$NotificationSeenItemsTableAnnotationComposer,
        $$NotificationSeenItemsTableCreateCompanionBuilder,
        $$NotificationSeenItemsTableUpdateCompanionBuilder,
        (
          NotificationSeenItem,
          BaseReferences<_$AppDatabase, $NotificationSeenItemsTable,
              NotificationSeenItem>
        ),
        NotificationSeenItem,
        PrefetchHooks Function()>;
typedef $$NotificationOutboxTableCreateCompanionBuilder
    = NotificationOutboxCompanion Function({
  Value<int> id,
  required String generation,
  required String owner,
  required int courseId,
  required String courseName,
  required String kind,
  required String title,
  Value<String> itemId,
  Value<DateTime> detectedAt,
  Value<bool> delivered,
});
typedef $$NotificationOutboxTableUpdateCompanionBuilder
    = NotificationOutboxCompanion Function({
  Value<int> id,
  Value<String> generation,
  Value<String> owner,
  Value<int> courseId,
  Value<String> courseName,
  Value<String> kind,
  Value<String> title,
  Value<String> itemId,
  Value<DateTime> detectedAt,
  Value<bool> delivered,
});

class $$NotificationOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationOutboxTable> {
  $$NotificationOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get generation => $composableBuilder(
      column: $table.generation, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get owner => $composableBuilder(
      column: $table.owner, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get courseId => $composableBuilder(
      column: $table.courseId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get courseName => $composableBuilder(
      column: $table.courseName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get detectedAt => $composableBuilder(
      column: $table.detectedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get delivered => $composableBuilder(
      column: $table.delivered, builder: (column) => ColumnFilters(column));
}

class $$NotificationOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationOutboxTable> {
  $$NotificationOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get generation => $composableBuilder(
      column: $table.generation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get owner => $composableBuilder(
      column: $table.owner, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get courseId => $composableBuilder(
      column: $table.courseId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get courseName => $composableBuilder(
      column: $table.courseName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get detectedAt => $composableBuilder(
      column: $table.detectedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get delivered => $composableBuilder(
      column: $table.delivered, builder: (column) => ColumnOrderings(column));
}

class $$NotificationOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationOutboxTable> {
  $$NotificationOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get generation => $composableBuilder(
      column: $table.generation, builder: (column) => column);

  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<int> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get courseName => $composableBuilder(
      column: $table.courseName, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<DateTime> get detectedAt => $composableBuilder(
      column: $table.detectedAt, builder: (column) => column);

  GeneratedColumn<bool> get delivered =>
      $composableBuilder(column: $table.delivered, builder: (column) => column);
}

class $$NotificationOutboxTableTableManager extends RootTableManager<
    _$AppDatabase,
    $NotificationOutboxTable,
    NotificationOutboxData,
    $$NotificationOutboxTableFilterComposer,
    $$NotificationOutboxTableOrderingComposer,
    $$NotificationOutboxTableAnnotationComposer,
    $$NotificationOutboxTableCreateCompanionBuilder,
    $$NotificationOutboxTableUpdateCompanionBuilder,
    (
      NotificationOutboxData,
      BaseReferences<_$AppDatabase, $NotificationOutboxTable,
          NotificationOutboxData>
    ),
    NotificationOutboxData,
    PrefetchHooks Function()> {
  $$NotificationOutboxTableTableManager(
      _$AppDatabase db, $NotificationOutboxTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotificationOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotificationOutboxTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> generation = const Value.absent(),
            Value<String> owner = const Value.absent(),
            Value<int> courseId = const Value.absent(),
            Value<String> courseName = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<DateTime> detectedAt = const Value.absent(),
            Value<bool> delivered = const Value.absent(),
          }) =>
              NotificationOutboxCompanion(
            id: id,
            generation: generation,
            owner: owner,
            courseId: courseId,
            courseName: courseName,
            kind: kind,
            title: title,
            itemId: itemId,
            detectedAt: detectedAt,
            delivered: delivered,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String generation,
            required String owner,
            required int courseId,
            required String courseName,
            required String kind,
            required String title,
            Value<String> itemId = const Value.absent(),
            Value<DateTime> detectedAt = const Value.absent(),
            Value<bool> delivered = const Value.absent(),
          }) =>
              NotificationOutboxCompanion.insert(
            id: id,
            generation: generation,
            owner: owner,
            courseId: courseId,
            courseName: courseName,
            kind: kind,
            title: title,
            itemId: itemId,
            detectedAt: detectedAt,
            delivered: delivered,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$NotificationOutboxTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $NotificationOutboxTable,
    NotificationOutboxData,
    $$NotificationOutboxTableFilterComposer,
    $$NotificationOutboxTableOrderingComposer,
    $$NotificationOutboxTableAnnotationComposer,
    $$NotificationOutboxTableCreateCompanionBuilder,
    $$NotificationOutboxTableUpdateCompanionBuilder,
    (
      NotificationOutboxData,
      BaseReferences<_$AppDatabase, $NotificationOutboxTable,
          NotificationOutboxData>
    ),
    NotificationOutboxData,
    PrefetchHooks Function()>;
typedef $$DownloadSettingsTableCreateCompanionBuilder
    = DownloadSettingsCompanion Function({
  Value<int> id,
  required String owner,
  required String treeUri,
  required String folderName,
  Value<bool> enabled,
  required String generation,
  Value<String?> lease,
  Value<int?> leaseUntil,
  Value<int?> lastAttempt,
  Value<String> status,
});
typedef $$DownloadSettingsTableUpdateCompanionBuilder
    = DownloadSettingsCompanion Function({
  Value<int> id,
  Value<String> owner,
  Value<String> treeUri,
  Value<String> folderName,
  Value<bool> enabled,
  Value<String> generation,
  Value<String?> lease,
  Value<int?> leaseUntil,
  Value<int?> lastAttempt,
  Value<String> status,
});

class $$DownloadSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadSettingsTable> {
  $$DownloadSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get owner => $composableBuilder(
      column: $table.owner, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get treeUri => $composableBuilder(
      column: $table.treeUri, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get folderName => $composableBuilder(
      column: $table.folderName, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get generation => $composableBuilder(
      column: $table.generation, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lease => $composableBuilder(
      column: $table.lease, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get leaseUntil => $composableBuilder(
      column: $table.leaseUntil, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastAttempt => $composableBuilder(
      column: $table.lastAttempt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));
}

class $$DownloadSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadSettingsTable> {
  $$DownloadSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get owner => $composableBuilder(
      column: $table.owner, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get treeUri => $composableBuilder(
      column: $table.treeUri, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get folderName => $composableBuilder(
      column: $table.folderName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get generation => $composableBuilder(
      column: $table.generation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lease => $composableBuilder(
      column: $table.lease, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get leaseUntil => $composableBuilder(
      column: $table.leaseUntil, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastAttempt => $composableBuilder(
      column: $table.lastAttempt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));
}

class $$DownloadSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadSettingsTable> {
  $$DownloadSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<String> get treeUri =>
      $composableBuilder(column: $table.treeUri, builder: (column) => column);

  GeneratedColumn<String> get folderName => $composableBuilder(
      column: $table.folderName, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get generation => $composableBuilder(
      column: $table.generation, builder: (column) => column);

  GeneratedColumn<String> get lease =>
      $composableBuilder(column: $table.lease, builder: (column) => column);

  GeneratedColumn<int> get leaseUntil => $composableBuilder(
      column: $table.leaseUntil, builder: (column) => column);

  GeneratedColumn<int> get lastAttempt => $composableBuilder(
      column: $table.lastAttempt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$DownloadSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DownloadSettingsTable,
    DownloadSetting,
    $$DownloadSettingsTableFilterComposer,
    $$DownloadSettingsTableOrderingComposer,
    $$DownloadSettingsTableAnnotationComposer,
    $$DownloadSettingsTableCreateCompanionBuilder,
    $$DownloadSettingsTableUpdateCompanionBuilder,
    (
      DownloadSetting,
      BaseReferences<_$AppDatabase, $DownloadSettingsTable, DownloadSetting>
    ),
    DownloadSetting,
    PrefetchHooks Function()> {
  $$DownloadSettingsTableTableManager(
      _$AppDatabase db, $DownloadSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> owner = const Value.absent(),
            Value<String> treeUri = const Value.absent(),
            Value<String> folderName = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<String> generation = const Value.absent(),
            Value<String?> lease = const Value.absent(),
            Value<int?> leaseUntil = const Value.absent(),
            Value<int?> lastAttempt = const Value.absent(),
            Value<String> status = const Value.absent(),
          }) =>
              DownloadSettingsCompanion(
            id: id,
            owner: owner,
            treeUri: treeUri,
            folderName: folderName,
            enabled: enabled,
            generation: generation,
            lease: lease,
            leaseUntil: leaseUntil,
            lastAttempt: lastAttempt,
            status: status,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String owner,
            required String treeUri,
            required String folderName,
            Value<bool> enabled = const Value.absent(),
            required String generation,
            Value<String?> lease = const Value.absent(),
            Value<int?> leaseUntil = const Value.absent(),
            Value<int?> lastAttempt = const Value.absent(),
            Value<String> status = const Value.absent(),
          }) =>
              DownloadSettingsCompanion.insert(
            id: id,
            owner: owner,
            treeUri: treeUri,
            folderName: folderName,
            enabled: enabled,
            generation: generation,
            lease: lease,
            leaseUntil: leaseUntil,
            lastAttempt: lastAttempt,
            status: status,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DownloadSettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DownloadSettingsTable,
    DownloadSetting,
    $$DownloadSettingsTableFilterComposer,
    $$DownloadSettingsTableOrderingComposer,
    $$DownloadSettingsTableAnnotationComposer,
    $$DownloadSettingsTableCreateCompanionBuilder,
    $$DownloadSettingsTableUpdateCompanionBuilder,
    (
      DownloadSetting,
      BaseReferences<_$AppDatabase, $DownloadSettingsTable, DownloadSetting>
    ),
    DownloadSetting,
    PrefetchHooks Function()>;
typedef $$DownloadedFilesTableCreateCompanionBuilder = DownloadedFilesCompanion
    Function({
  required String owner,
  required String treeUri,
  required int courseId,
  required String fileId,
  required String documentUri,
  Value<int> rowid,
});
typedef $$DownloadedFilesTableUpdateCompanionBuilder = DownloadedFilesCompanion
    Function({
  Value<String> owner,
  Value<String> treeUri,
  Value<int> courseId,
  Value<String> fileId,
  Value<String> documentUri,
  Value<int> rowid,
});

class $$DownloadedFilesTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadedFilesTable> {
  $$DownloadedFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get owner => $composableBuilder(
      column: $table.owner, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get treeUri => $composableBuilder(
      column: $table.treeUri, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get courseId => $composableBuilder(
      column: $table.courseId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fileId => $composableBuilder(
      column: $table.fileId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get documentUri => $composableBuilder(
      column: $table.documentUri, builder: (column) => ColumnFilters(column));
}

class $$DownloadedFilesTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadedFilesTable> {
  $$DownloadedFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get owner => $composableBuilder(
      column: $table.owner, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get treeUri => $composableBuilder(
      column: $table.treeUri, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get courseId => $composableBuilder(
      column: $table.courseId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fileId => $composableBuilder(
      column: $table.fileId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get documentUri => $composableBuilder(
      column: $table.documentUri, builder: (column) => ColumnOrderings(column));
}

class $$DownloadedFilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadedFilesTable> {
  $$DownloadedFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<String> get treeUri =>
      $composableBuilder(column: $table.treeUri, builder: (column) => column);

  GeneratedColumn<int> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => column);

  GeneratedColumn<String> get documentUri => $composableBuilder(
      column: $table.documentUri, builder: (column) => column);
}

class $$DownloadedFilesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DownloadedFilesTable,
    DownloadedFile,
    $$DownloadedFilesTableFilterComposer,
    $$DownloadedFilesTableOrderingComposer,
    $$DownloadedFilesTableAnnotationComposer,
    $$DownloadedFilesTableCreateCompanionBuilder,
    $$DownloadedFilesTableUpdateCompanionBuilder,
    (
      DownloadedFile,
      BaseReferences<_$AppDatabase, $DownloadedFilesTable, DownloadedFile>
    ),
    DownloadedFile,
    PrefetchHooks Function()> {
  $$DownloadedFilesTableTableManager(
      _$AppDatabase db, $DownloadedFilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadedFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadedFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadedFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> owner = const Value.absent(),
            Value<String> treeUri = const Value.absent(),
            Value<int> courseId = const Value.absent(),
            Value<String> fileId = const Value.absent(),
            Value<String> documentUri = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DownloadedFilesCompanion(
            owner: owner,
            treeUri: treeUri,
            courseId: courseId,
            fileId: fileId,
            documentUri: documentUri,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String owner,
            required String treeUri,
            required int courseId,
            required String fileId,
            required String documentUri,
            Value<int> rowid = const Value.absent(),
          }) =>
              DownloadedFilesCompanion.insert(
            owner: owner,
            treeUri: treeUri,
            courseId: courseId,
            fileId: fileId,
            documentUri: documentUri,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DownloadedFilesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DownloadedFilesTable,
    DownloadedFile,
    $$DownloadedFilesTableFilterComposer,
    $$DownloadedFilesTableOrderingComposer,
    $$DownloadedFilesTableAnnotationComposer,
    $$DownloadedFilesTableCreateCompanionBuilder,
    $$DownloadedFilesTableUpdateCompanionBuilder,
    (
      DownloadedFile,
      BaseReferences<_$AppDatabase, $DownloadedFilesTable, DownloadedFile>
    ),
    DownloadedFile,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TermsTableTableManager get terms =>
      $$TermsTableTableManager(_db, _db.terms);
  $$CoursesTableTableManager get courses =>
      $$CoursesTableTableManager(_db, _db.courses);
  $$CalendarEventsTableTableManager get calendarEvents =>
      $$CalendarEventsTableTableManager(_db, _db.calendarEvents);
  $$AnnouncementsTableTableManager get announcements =>
      $$AnnouncementsTableTableManager(_db, _db.announcements);
  $$CacheMetaEntriesTableTableManager get cacheMetaEntries =>
      $$CacheMetaEntriesTableTableManager(_db, _db.cacheMetaEntries);
  $$CanvasCacheEntriesTableTableManager get canvasCacheEntries =>
      $$CanvasCacheEntriesTableTableManager(_db, _db.canvasCacheEntries);
  $$NotificationSettingsTableTableManager get notificationSettings =>
      $$NotificationSettingsTableTableManager(_db, _db.notificationSettings);
  $$NotificationBaselinesTableTableManager get notificationBaselines =>
      $$NotificationBaselinesTableTableManager(_db, _db.notificationBaselines);
  $$NotificationSeenItemsTableTableManager get notificationSeenItems =>
      $$NotificationSeenItemsTableTableManager(_db, _db.notificationSeenItems);
  $$NotificationOutboxTableTableManager get notificationOutbox =>
      $$NotificationOutboxTableTableManager(_db, _db.notificationOutbox);
  $$DownloadSettingsTableTableManager get downloadSettings =>
      $$DownloadSettingsTableTableManager(_db, _db.downloadSettings);
  $$DownloadedFilesTableTableManager get downloadedFiles =>
      $$DownloadedFilesTableTableManager(_db, _db.downloadedFiles);
}

mixin _$TermsDaoMixin on DatabaseAccessor<AppDatabase> {
  $TermsTable get terms => attachedDatabase.terms;
  TermsDaoManager get managers => TermsDaoManager(this);
}

class TermsDaoManager {
  final _$TermsDaoMixin _db;
  TermsDaoManager(this._db);
  $$TermsTableTableManager get terms =>
      $$TermsTableTableManager(_db.attachedDatabase, _db.terms);
}

mixin _$CoursesDaoMixin on DatabaseAccessor<AppDatabase> {
  $CoursesTable get courses => attachedDatabase.courses;
  CoursesDaoManager get managers => CoursesDaoManager(this);
}

class CoursesDaoManager {
  final _$CoursesDaoMixin _db;
  CoursesDaoManager(this._db);
  $$CoursesTableTableManager get courses =>
      $$CoursesTableTableManager(_db.attachedDatabase, _db.courses);
}

mixin _$CalendarEventsDaoMixin on DatabaseAccessor<AppDatabase> {
  $CalendarEventsTable get calendarEvents => attachedDatabase.calendarEvents;
  CalendarEventsDaoManager get managers => CalendarEventsDaoManager(this);
}

class CalendarEventsDaoManager {
  final _$CalendarEventsDaoMixin _db;
  CalendarEventsDaoManager(this._db);
  $$CalendarEventsTableTableManager get calendarEvents =>
      $$CalendarEventsTableTableManager(
          _db.attachedDatabase, _db.calendarEvents);
}

mixin _$AnnouncementsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AnnouncementsTable get announcements => attachedDatabase.announcements;
  AnnouncementsDaoManager get managers => AnnouncementsDaoManager(this);
}

class AnnouncementsDaoManager {
  final _$AnnouncementsDaoMixin _db;
  AnnouncementsDaoManager(this._db);
  $$AnnouncementsTableTableManager get announcements =>
      $$AnnouncementsTableTableManager(_db.attachedDatabase, _db.announcements);
}

mixin _$CacheMetaDaoMixin on DatabaseAccessor<AppDatabase> {
  $CacheMetaEntriesTable get cacheMetaEntries =>
      attachedDatabase.cacheMetaEntries;
  CacheMetaDaoManager get managers => CacheMetaDaoManager(this);
}

class CacheMetaDaoManager {
  final _$CacheMetaDaoMixin _db;
  CacheMetaDaoManager(this._db);
  $$CacheMetaEntriesTableTableManager get cacheMetaEntries =>
      $$CacheMetaEntriesTableTableManager(
          _db.attachedDatabase, _db.cacheMetaEntries);
}
