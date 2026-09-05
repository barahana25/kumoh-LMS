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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TermsTable terms = $TermsTable(this);
  late final $CoursesTable courses = $CoursesTable(this);
  late final $CalendarEventsTable calendarEvents = $CalendarEventsTable(this);
  late final $AnnouncementsTable announcements = $AnnouncementsTable(this);
  late final $CacheMetaEntriesTable cacheMetaEntries =
      $CacheMetaEntriesTable(this);
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
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [terms, courses, calendarEvents, announcements, cacheMetaEntries];
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
