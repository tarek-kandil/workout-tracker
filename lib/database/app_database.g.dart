// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ExercisesTable extends Exercises
    with TableInfo<$ExercisesTable, Exercise> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Other'),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isTimedMeta = const VerificationMeta(
    'isTimed',
  );
  @override
  late final GeneratedColumn<bool> isTimed = GeneratedColumn<bool>(
    'is_timed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_timed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, category, notes, isTimed];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<Exercise> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('is_timed')) {
      context.handle(
        _isTimedMeta,
        isTimed.isAcceptableOrUnknown(data['is_timed']!, _isTimedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Exercise map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Exercise(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      isTimed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_timed'],
      )!,
    );
  }

  @override
  $ExercisesTable createAlias(String alias) {
    return $ExercisesTable(attachedDatabase, alias);
  }
}

class Exercise extends DataClass implements Insertable<Exercise> {
  final int id;
  final String name;
  final String category;
  final String? notes;
  final bool isTimed;
  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    this.notes,
    required this.isTimed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['is_timed'] = Variable<bool>(isTimed);
    return map;
  }

  ExercisesCompanion toCompanion(bool nullToAbsent) {
    return ExercisesCompanion(
      id: Value(id),
      name: Value(name),
      category: Value(category),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      isTimed: Value(isTimed),
    );
  }

  factory Exercise.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Exercise(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String>(json['category']),
      notes: serializer.fromJson<String?>(json['notes']),
      isTimed: serializer.fromJson<bool>(json['isTimed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String>(category),
      'notes': serializer.toJson<String?>(notes),
      'isTimed': serializer.toJson<bool>(isTimed),
    };
  }

  Exercise copyWith({
    int? id,
    String? name,
    String? category,
    Value<String?> notes = const Value.absent(),
    bool? isTimed,
  }) => Exercise(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    notes: notes.present ? notes.value : this.notes,
    isTimed: isTimed ?? this.isTimed,
  );
  Exercise copyWithCompanion(ExercisesCompanion data) {
    return Exercise(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      notes: data.notes.present ? data.notes.value : this.notes,
      isTimed: data.isTimed.present ? data.isTimed.value : this.isTimed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Exercise(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('notes: $notes, ')
          ..write('isTimed: $isTimed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, category, notes, isTimed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Exercise &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.notes == this.notes &&
          other.isTimed == this.isTimed);
}

class ExercisesCompanion extends UpdateCompanion<Exercise> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> category;
  final Value<String?> notes;
  final Value<bool> isTimed;
  const ExercisesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.notes = const Value.absent(),
    this.isTimed = const Value.absent(),
  });
  ExercisesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.category = const Value.absent(),
    this.notes = const Value.absent(),
    this.isTimed = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Exercise> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? notes,
    Expression<bool>? isTimed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (notes != null) 'notes': notes,
      if (isTimed != null) 'is_timed': isTimed,
    });
  }

  ExercisesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? category,
    Value<String?>? notes,
    Value<bool>? isTimed,
  }) {
    return ExercisesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      isTimed: isTimed ?? this.isTimed,
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
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (isTimed.present) {
      map['is_timed'] = Variable<bool>(isTimed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExercisesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('notes: $notes, ')
          ..write('isTimed: $isTimed')
          ..write(')'))
        .toString();
  }
}

class $ProgramsTable extends Programs with TableInfo<$ProgramsTable, Program> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgramsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, status, notes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'programs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Program> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Program map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Program(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $ProgramsTable createAlias(String alias) {
    return $ProgramsTable(attachedDatabase, alias);
  }
}

class Program extends DataClass implements Insertable<Program> {
  final int id;
  final String name;
  final int status;
  final String? notes;
  const Program({
    required this.id,
    required this.name,
    required this.status,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['status'] = Variable<int>(status);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  ProgramsCompanion toCompanion(bool nullToAbsent) {
    return ProgramsCompanion(
      id: Value(id),
      name: Value(name),
      status: Value(status),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory Program.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Program(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      status: serializer.fromJson<int>(json['status']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'status': serializer.toJson<int>(status),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  Program copyWith({
    int? id,
    String? name,
    int? status,
    Value<String?> notes = const Value.absent(),
  }) => Program(
    id: id ?? this.id,
    name: name ?? this.name,
    status: status ?? this.status,
    notes: notes.present ? notes.value : this.notes,
  );
  Program copyWithCompanion(ProgramsCompanion data) {
    return Program(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      status: data.status.present ? data.status.value : this.status,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Program(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, status, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Program &&
          other.id == this.id &&
          other.name == this.name &&
          other.status == this.status &&
          other.notes == this.notes);
}

class ProgramsCompanion extends UpdateCompanion<Program> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> status;
  final Value<String?> notes;
  const ProgramsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
  });
  ProgramsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.status = const Value.absent(),
    this.notes = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Program> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? status,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (notes != null) 'notes': notes,
    });
  }

  ProgramsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? status,
    Value<String?>? notes,
  }) {
    return ProgramsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      notes: notes ?? this.notes,
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
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgramsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $ProgramPhasesTable extends ProgramPhases
    with TableInfo<$ProgramPhasesTable, ProgramPhase> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgramPhasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _programIdMeta = const VerificationMeta(
    'programId',
  );
  @override
  late final GeneratedColumn<int> programId = GeneratedColumn<int>(
    'program_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES programs (id)',
    ),
  );
  static const VerificationMeta _phaseNumberMeta = const VerificationMeta(
    'phaseNumber',
  );
  @override
  late final GeneratedColumn<int> phaseNumber = GeneratedColumn<int>(
    'phase_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationWeeksMeta = const VerificationMeta(
    'durationWeeks',
  );
  @override
  late final GeneratedColumn<int> durationWeeks = GeneratedColumn<int>(
    'duration_weeks',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    programId,
    phaseNumber,
    name,
    durationWeeks,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'program_phases';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgramPhase> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('program_id')) {
      context.handle(
        _programIdMeta,
        programId.isAcceptableOrUnknown(data['program_id']!, _programIdMeta),
      );
    } else if (isInserting) {
      context.missing(_programIdMeta);
    }
    if (data.containsKey('phase_number')) {
      context.handle(
        _phaseNumberMeta,
        phaseNumber.isAcceptableOrUnknown(
          data['phase_number']!,
          _phaseNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_phaseNumberMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('duration_weeks')) {
      context.handle(
        _durationWeeksMeta,
        durationWeeks.isAcceptableOrUnknown(
          data['duration_weeks']!,
          _durationWeeksMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationWeeksMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProgramPhase map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgramPhase(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      programId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}program_id'],
      )!,
      phaseNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}phase_number'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      durationWeeks: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_weeks'],
      )!,
    );
  }

  @override
  $ProgramPhasesTable createAlias(String alias) {
    return $ProgramPhasesTable(attachedDatabase, alias);
  }
}

class ProgramPhase extends DataClass implements Insertable<ProgramPhase> {
  final int id;
  final int programId;
  final int phaseNumber;
  final String name;
  final int durationWeeks;
  const ProgramPhase({
    required this.id,
    required this.programId,
    required this.phaseNumber,
    required this.name,
    required this.durationWeeks,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['program_id'] = Variable<int>(programId);
    map['phase_number'] = Variable<int>(phaseNumber);
    map['name'] = Variable<String>(name);
    map['duration_weeks'] = Variable<int>(durationWeeks);
    return map;
  }

  ProgramPhasesCompanion toCompanion(bool nullToAbsent) {
    return ProgramPhasesCompanion(
      id: Value(id),
      programId: Value(programId),
      phaseNumber: Value(phaseNumber),
      name: Value(name),
      durationWeeks: Value(durationWeeks),
    );
  }

  factory ProgramPhase.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgramPhase(
      id: serializer.fromJson<int>(json['id']),
      programId: serializer.fromJson<int>(json['programId']),
      phaseNumber: serializer.fromJson<int>(json['phaseNumber']),
      name: serializer.fromJson<String>(json['name']),
      durationWeeks: serializer.fromJson<int>(json['durationWeeks']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'programId': serializer.toJson<int>(programId),
      'phaseNumber': serializer.toJson<int>(phaseNumber),
      'name': serializer.toJson<String>(name),
      'durationWeeks': serializer.toJson<int>(durationWeeks),
    };
  }

  ProgramPhase copyWith({
    int? id,
    int? programId,
    int? phaseNumber,
    String? name,
    int? durationWeeks,
  }) => ProgramPhase(
    id: id ?? this.id,
    programId: programId ?? this.programId,
    phaseNumber: phaseNumber ?? this.phaseNumber,
    name: name ?? this.name,
    durationWeeks: durationWeeks ?? this.durationWeeks,
  );
  ProgramPhase copyWithCompanion(ProgramPhasesCompanion data) {
    return ProgramPhase(
      id: data.id.present ? data.id.value : this.id,
      programId: data.programId.present ? data.programId.value : this.programId,
      phaseNumber: data.phaseNumber.present
          ? data.phaseNumber.value
          : this.phaseNumber,
      name: data.name.present ? data.name.value : this.name,
      durationWeeks: data.durationWeeks.present
          ? data.durationWeeks.value
          : this.durationWeeks,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgramPhase(')
          ..write('id: $id, ')
          ..write('programId: $programId, ')
          ..write('phaseNumber: $phaseNumber, ')
          ..write('name: $name, ')
          ..write('durationWeeks: $durationWeeks')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, programId, phaseNumber, name, durationWeeks);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgramPhase &&
          other.id == this.id &&
          other.programId == this.programId &&
          other.phaseNumber == this.phaseNumber &&
          other.name == this.name &&
          other.durationWeeks == this.durationWeeks);
}

class ProgramPhasesCompanion extends UpdateCompanion<ProgramPhase> {
  final Value<int> id;
  final Value<int> programId;
  final Value<int> phaseNumber;
  final Value<String> name;
  final Value<int> durationWeeks;
  const ProgramPhasesCompanion({
    this.id = const Value.absent(),
    this.programId = const Value.absent(),
    this.phaseNumber = const Value.absent(),
    this.name = const Value.absent(),
    this.durationWeeks = const Value.absent(),
  });
  ProgramPhasesCompanion.insert({
    this.id = const Value.absent(),
    required int programId,
    required int phaseNumber,
    required String name,
    required int durationWeeks,
  }) : programId = Value(programId),
       phaseNumber = Value(phaseNumber),
       name = Value(name),
       durationWeeks = Value(durationWeeks);
  static Insertable<ProgramPhase> custom({
    Expression<int>? id,
    Expression<int>? programId,
    Expression<int>? phaseNumber,
    Expression<String>? name,
    Expression<int>? durationWeeks,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (programId != null) 'program_id': programId,
      if (phaseNumber != null) 'phase_number': phaseNumber,
      if (name != null) 'name': name,
      if (durationWeeks != null) 'duration_weeks': durationWeeks,
    });
  }

  ProgramPhasesCompanion copyWith({
    Value<int>? id,
    Value<int>? programId,
    Value<int>? phaseNumber,
    Value<String>? name,
    Value<int>? durationWeeks,
  }) {
    return ProgramPhasesCompanion(
      id: id ?? this.id,
      programId: programId ?? this.programId,
      phaseNumber: phaseNumber ?? this.phaseNumber,
      name: name ?? this.name,
      durationWeeks: durationWeeks ?? this.durationWeeks,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (programId.present) {
      map['program_id'] = Variable<int>(programId.value);
    }
    if (phaseNumber.present) {
      map['phase_number'] = Variable<int>(phaseNumber.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (durationWeeks.present) {
      map['duration_weeks'] = Variable<int>(durationWeeks.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgramPhasesCompanion(')
          ..write('id: $id, ')
          ..write('programId: $programId, ')
          ..write('phaseNumber: $phaseNumber, ')
          ..write('name: $name, ')
          ..write('durationWeeks: $durationWeeks')
          ..write(')'))
        .toString();
  }
}

class $WodTemplatesTable extends WodTemplates
    with TableInfo<$WodTemplatesTable, WodTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WodTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _phaseIdMeta = const VerificationMeta(
    'phaseId',
  );
  @override
  late final GeneratedColumn<int> phaseId = GeneratedColumn<int>(
    'phase_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES program_phases (id)',
    ),
  );
  static const VerificationMeta _wodNumberMeta = const VerificationMeta(
    'wodNumber',
  );
  @override
  late final GeneratedColumn<int> wodNumber = GeneratedColumn<int>(
    'wod_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _restSecondsMeta = const VerificationMeta(
    'restSeconds',
  );
  @override
  late final GeneratedColumn<int> restSeconds = GeneratedColumn<int>(
    'rest_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(90),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    phaseId,
    wodNumber,
    name,
    notes,
    restSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wod_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<WodTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('phase_id')) {
      context.handle(
        _phaseIdMeta,
        phaseId.isAcceptableOrUnknown(data['phase_id']!, _phaseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_phaseIdMeta);
    }
    if (data.containsKey('wod_number')) {
      context.handle(
        _wodNumberMeta,
        wodNumber.isAcceptableOrUnknown(data['wod_number']!, _wodNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_wodNumberMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('rest_seconds')) {
      context.handle(
        _restSecondsMeta,
        restSeconds.isAcceptableOrUnknown(
          data['rest_seconds']!,
          _restSecondsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WodTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WodTemplate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      phaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}phase_id'],
      )!,
      wodNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wod_number'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      restSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_seconds'],
      )!,
    );
  }

  @override
  $WodTemplatesTable createAlias(String alias) {
    return $WodTemplatesTable(attachedDatabase, alias);
  }
}

class WodTemplate extends DataClass implements Insertable<WodTemplate> {
  final int id;
  final int phaseId;
  final int wodNumber;
  final String name;
  final String? notes;
  final int restSeconds;
  const WodTemplate({
    required this.id,
    required this.phaseId,
    required this.wodNumber,
    required this.name,
    this.notes,
    required this.restSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['phase_id'] = Variable<int>(phaseId);
    map['wod_number'] = Variable<int>(wodNumber);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['rest_seconds'] = Variable<int>(restSeconds);
    return map;
  }

  WodTemplatesCompanion toCompanion(bool nullToAbsent) {
    return WodTemplatesCompanion(
      id: Value(id),
      phaseId: Value(phaseId),
      wodNumber: Value(wodNumber),
      name: Value(name),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      restSeconds: Value(restSeconds),
    );
  }

  factory WodTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WodTemplate(
      id: serializer.fromJson<int>(json['id']),
      phaseId: serializer.fromJson<int>(json['phaseId']),
      wodNumber: serializer.fromJson<int>(json['wodNumber']),
      name: serializer.fromJson<String>(json['name']),
      notes: serializer.fromJson<String?>(json['notes']),
      restSeconds: serializer.fromJson<int>(json['restSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'phaseId': serializer.toJson<int>(phaseId),
      'wodNumber': serializer.toJson<int>(wodNumber),
      'name': serializer.toJson<String>(name),
      'notes': serializer.toJson<String?>(notes),
      'restSeconds': serializer.toJson<int>(restSeconds),
    };
  }

  WodTemplate copyWith({
    int? id,
    int? phaseId,
    int? wodNumber,
    String? name,
    Value<String?> notes = const Value.absent(),
    int? restSeconds,
  }) => WodTemplate(
    id: id ?? this.id,
    phaseId: phaseId ?? this.phaseId,
    wodNumber: wodNumber ?? this.wodNumber,
    name: name ?? this.name,
    notes: notes.present ? notes.value : this.notes,
    restSeconds: restSeconds ?? this.restSeconds,
  );
  WodTemplate copyWithCompanion(WodTemplatesCompanion data) {
    return WodTemplate(
      id: data.id.present ? data.id.value : this.id,
      phaseId: data.phaseId.present ? data.phaseId.value : this.phaseId,
      wodNumber: data.wodNumber.present ? data.wodNumber.value : this.wodNumber,
      name: data.name.present ? data.name.value : this.name,
      notes: data.notes.present ? data.notes.value : this.notes,
      restSeconds: data.restSeconds.present
          ? data.restSeconds.value
          : this.restSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WodTemplate(')
          ..write('id: $id, ')
          ..write('phaseId: $phaseId, ')
          ..write('wodNumber: $wodNumber, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('restSeconds: $restSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, phaseId, wodNumber, name, notes, restSeconds);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WodTemplate &&
          other.id == this.id &&
          other.phaseId == this.phaseId &&
          other.wodNumber == this.wodNumber &&
          other.name == this.name &&
          other.notes == this.notes &&
          other.restSeconds == this.restSeconds);
}

class WodTemplatesCompanion extends UpdateCompanion<WodTemplate> {
  final Value<int> id;
  final Value<int> phaseId;
  final Value<int> wodNumber;
  final Value<String> name;
  final Value<String?> notes;
  final Value<int> restSeconds;
  const WodTemplatesCompanion({
    this.id = const Value.absent(),
    this.phaseId = const Value.absent(),
    this.wodNumber = const Value.absent(),
    this.name = const Value.absent(),
    this.notes = const Value.absent(),
    this.restSeconds = const Value.absent(),
  });
  WodTemplatesCompanion.insert({
    this.id = const Value.absent(),
    required int phaseId,
    required int wodNumber,
    required String name,
    this.notes = const Value.absent(),
    this.restSeconds = const Value.absent(),
  }) : phaseId = Value(phaseId),
       wodNumber = Value(wodNumber),
       name = Value(name);
  static Insertable<WodTemplate> custom({
    Expression<int>? id,
    Expression<int>? phaseId,
    Expression<int>? wodNumber,
    Expression<String>? name,
    Expression<String>? notes,
    Expression<int>? restSeconds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (phaseId != null) 'phase_id': phaseId,
      if (wodNumber != null) 'wod_number': wodNumber,
      if (name != null) 'name': name,
      if (notes != null) 'notes': notes,
      if (restSeconds != null) 'rest_seconds': restSeconds,
    });
  }

  WodTemplatesCompanion copyWith({
    Value<int>? id,
    Value<int>? phaseId,
    Value<int>? wodNumber,
    Value<String>? name,
    Value<String?>? notes,
    Value<int>? restSeconds,
  }) {
    return WodTemplatesCompanion(
      id: id ?? this.id,
      phaseId: phaseId ?? this.phaseId,
      wodNumber: wodNumber ?? this.wodNumber,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      restSeconds: restSeconds ?? this.restSeconds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (phaseId.present) {
      map['phase_id'] = Variable<int>(phaseId.value);
    }
    if (wodNumber.present) {
      map['wod_number'] = Variable<int>(wodNumber.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (restSeconds.present) {
      map['rest_seconds'] = Variable<int>(restSeconds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WodTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('phaseId: $phaseId, ')
          ..write('wodNumber: $wodNumber, ')
          ..write('name: $name, ')
          ..write('notes: $notes, ')
          ..write('restSeconds: $restSeconds')
          ..write(')'))
        .toString();
  }
}

class $WorkoutSessionsTable extends WorkoutSessions
    with TableInfo<$WorkoutSessionsTable, WorkoutSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workoutNameMeta = const VerificationMeta(
    'workoutName',
  );
  @override
  late final GeneratedColumn<String> workoutName = GeneratedColumn<String>(
    'workout_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wodTemplateIdMeta = const VerificationMeta(
    'wodTemplateId',
  );
  @override
  late final GeneratedColumn<int> wodTemplateId = GeneratedColumn<int>(
    'wod_template_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES wod_templates (id)',
    ),
  );
  static const VerificationMeta _weekNumberMeta = const VerificationMeta(
    'weekNumber',
  );
  @override
  late final GeneratedColumn<int> weekNumber = GeneratedColumn<int>(
    'week_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    workoutName,
    wodTemplateId,
    weekNumber,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('workout_name')) {
      context.handle(
        _workoutNameMeta,
        workoutName.isAcceptableOrUnknown(
          data['workout_name']!,
          _workoutNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workoutNameMeta);
    }
    if (data.containsKey('wod_template_id')) {
      context.handle(
        _wodTemplateIdMeta,
        wodTemplateId.isAcceptableOrUnknown(
          data['wod_template_id']!,
          _wodTemplateIdMeta,
        ),
      );
    }
    if (data.containsKey('week_number')) {
      context.handle(
        _weekNumberMeta,
        weekNumber.isAcceptableOrUnknown(data['week_number']!, _weekNumberMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      workoutName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workout_name'],
      )!,
      wodTemplateId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wod_template_id'],
      ),
      weekNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}week_number'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $WorkoutSessionsTable createAlias(String alias) {
    return $WorkoutSessionsTable(attachedDatabase, alias);
  }
}

class WorkoutSession extends DataClass implements Insertable<WorkoutSession> {
  final int id;
  final DateTime date;
  final String workoutName;
  final int? wodTemplateId;
  final int? weekNumber;
  final String? notes;
  const WorkoutSession({
    required this.id,
    required this.date,
    required this.workoutName,
    this.wodTemplateId,
    this.weekNumber,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['workout_name'] = Variable<String>(workoutName);
    if (!nullToAbsent || wodTemplateId != null) {
      map['wod_template_id'] = Variable<int>(wodTemplateId);
    }
    if (!nullToAbsent || weekNumber != null) {
      map['week_number'] = Variable<int>(weekNumber);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  WorkoutSessionsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSessionsCompanion(
      id: Value(id),
      date: Value(date),
      workoutName: Value(workoutName),
      wodTemplateId: wodTemplateId == null && nullToAbsent
          ? const Value.absent()
          : Value(wodTemplateId),
      weekNumber: weekNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(weekNumber),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory WorkoutSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSession(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      workoutName: serializer.fromJson<String>(json['workoutName']),
      wodTemplateId: serializer.fromJson<int?>(json['wodTemplateId']),
      weekNumber: serializer.fromJson<int?>(json['weekNumber']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'workoutName': serializer.toJson<String>(workoutName),
      'wodTemplateId': serializer.toJson<int?>(wodTemplateId),
      'weekNumber': serializer.toJson<int?>(weekNumber),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  WorkoutSession copyWith({
    int? id,
    DateTime? date,
    String? workoutName,
    Value<int?> wodTemplateId = const Value.absent(),
    Value<int?> weekNumber = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => WorkoutSession(
    id: id ?? this.id,
    date: date ?? this.date,
    workoutName: workoutName ?? this.workoutName,
    wodTemplateId: wodTemplateId.present
        ? wodTemplateId.value
        : this.wodTemplateId,
    weekNumber: weekNumber.present ? weekNumber.value : this.weekNumber,
    notes: notes.present ? notes.value : this.notes,
  );
  WorkoutSession copyWithCompanion(WorkoutSessionsCompanion data) {
    return WorkoutSession(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      workoutName: data.workoutName.present
          ? data.workoutName.value
          : this.workoutName,
      wodTemplateId: data.wodTemplateId.present
          ? data.wodTemplateId.value
          : this.wodTemplateId,
      weekNumber: data.weekNumber.present
          ? data.weekNumber.value
          : this.weekNumber,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSession(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('workoutName: $workoutName, ')
          ..write('wodTemplateId: $wodTemplateId, ')
          ..write('weekNumber: $weekNumber, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, date, workoutName, wodTemplateId, weekNumber, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSession &&
          other.id == this.id &&
          other.date == this.date &&
          other.workoutName == this.workoutName &&
          other.wodTemplateId == this.wodTemplateId &&
          other.weekNumber == this.weekNumber &&
          other.notes == this.notes);
}

class WorkoutSessionsCompanion extends UpdateCompanion<WorkoutSession> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<String> workoutName;
  final Value<int?> wodTemplateId;
  final Value<int?> weekNumber;
  final Value<String?> notes;
  const WorkoutSessionsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.workoutName = const Value.absent(),
    this.wodTemplateId = const Value.absent(),
    this.weekNumber = const Value.absent(),
    this.notes = const Value.absent(),
  });
  WorkoutSessionsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required String workoutName,
    this.wodTemplateId = const Value.absent(),
    this.weekNumber = const Value.absent(),
    this.notes = const Value.absent(),
  }) : date = Value(date),
       workoutName = Value(workoutName);
  static Insertable<WorkoutSession> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<String>? workoutName,
    Expression<int>? wodTemplateId,
    Expression<int>? weekNumber,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (workoutName != null) 'workout_name': workoutName,
      if (wodTemplateId != null) 'wod_template_id': wodTemplateId,
      if (weekNumber != null) 'week_number': weekNumber,
      if (notes != null) 'notes': notes,
    });
  }

  WorkoutSessionsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<String>? workoutName,
    Value<int?>? wodTemplateId,
    Value<int?>? weekNumber,
    Value<String?>? notes,
  }) {
    return WorkoutSessionsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      workoutName: workoutName ?? this.workoutName,
      wodTemplateId: wodTemplateId ?? this.wodTemplateId,
      weekNumber: weekNumber ?? this.weekNumber,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (workoutName.present) {
      map['workout_name'] = Variable<String>(workoutName.value);
    }
    if (wodTemplateId.present) {
      map['wod_template_id'] = Variable<int>(wodTemplateId.value);
    }
    if (weekNumber.present) {
      map['week_number'] = Variable<int>(weekNumber.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSessionsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('workoutName: $workoutName, ')
          ..write('wodTemplateId: $wodTemplateId, ')
          ..write('weekNumber: $weekNumber, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $WorkoutSetsTable extends WorkoutSets
    with TableInfo<$WorkoutSetsTable, WorkoutSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workout_sessions (id)',
    ),
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<int> exerciseId = GeneratedColumn<int>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES exercises (id)',
    ),
  );
  static const VerificationMeta _setNumberMeta = const VerificationMeta(
    'setNumber',
  );
  @override
  late final GeneratedColumn<int> setNumber = GeneratedColumn<int>(
    'set_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rpeMeta = const VerificationMeta('rpe');
  @override
  late final GeneratedColumn<double> rpe = GeneratedColumn<double>(
    'rpe',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    exerciseId,
    setNumber,
    reps,
    weightKg,
    durationSeconds,
    rpe,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_sets';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutSet> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('set_number')) {
      context.handle(
        _setNumberMeta,
        setNumber.isAcceptableOrUnknown(data['set_number']!, _setNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_setNumberMeta);
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    } else if (isInserting) {
      context.missing(_repsMeta);
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    } else if (isInserting) {
      context.missing(_weightKgMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('rpe')) {
      context.handle(
        _rpeMeta,
        rpe.isAcceptableOrUnknown(data['rpe']!, _rpeMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exercise_id'],
      )!,
      setNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}set_number'],
      )!,
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      )!,
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      ),
      rpe: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}rpe'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $WorkoutSetsTable createAlias(String alias) {
    return $WorkoutSetsTable(attachedDatabase, alias);
  }
}

class WorkoutSet extends DataClass implements Insertable<WorkoutSet> {
  final int id;
  final int sessionId;
  final int exerciseId;
  final int setNumber;
  final int reps;
  final double weightKg;
  final int? durationSeconds;
  final double? rpe;
  final String? notes;
  const WorkoutSet({
    required this.id,
    required this.sessionId,
    required this.exerciseId,
    required this.setNumber,
    required this.reps,
    required this.weightKg,
    this.durationSeconds,
    this.rpe,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['exercise_id'] = Variable<int>(exerciseId);
    map['set_number'] = Variable<int>(setNumber);
    map['reps'] = Variable<int>(reps);
    map['weight_kg'] = Variable<double>(weightKg);
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    if (!nullToAbsent || rpe != null) {
      map['rpe'] = Variable<double>(rpe);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  WorkoutSetsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSetsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      exerciseId: Value(exerciseId),
      setNumber: Value(setNumber),
      reps: Value(reps),
      weightKg: Value(weightKg),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      rpe: rpe == null && nullToAbsent ? const Value.absent() : Value(rpe),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory WorkoutSet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSet(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      exerciseId: serializer.fromJson<int>(json['exerciseId']),
      setNumber: serializer.fromJson<int>(json['setNumber']),
      reps: serializer.fromJson<int>(json['reps']),
      weightKg: serializer.fromJson<double>(json['weightKg']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      rpe: serializer.fromJson<double?>(json['rpe']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'exerciseId': serializer.toJson<int>(exerciseId),
      'setNumber': serializer.toJson<int>(setNumber),
      'reps': serializer.toJson<int>(reps),
      'weightKg': serializer.toJson<double>(weightKg),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'rpe': serializer.toJson<double?>(rpe),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  WorkoutSet copyWith({
    int? id,
    int? sessionId,
    int? exerciseId,
    int? setNumber,
    int? reps,
    double? weightKg,
    Value<int?> durationSeconds = const Value.absent(),
    Value<double?> rpe = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => WorkoutSet(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    exerciseId: exerciseId ?? this.exerciseId,
    setNumber: setNumber ?? this.setNumber,
    reps: reps ?? this.reps,
    weightKg: weightKg ?? this.weightKg,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    rpe: rpe.present ? rpe.value : this.rpe,
    notes: notes.present ? notes.value : this.notes,
  );
  WorkoutSet copyWithCompanion(WorkoutSetsCompanion data) {
    return WorkoutSet(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      setNumber: data.setNumber.present ? data.setNumber.value : this.setNumber,
      reps: data.reps.present ? data.reps.value : this.reps,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      rpe: data.rpe.present ? data.rpe.value : this.rpe,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSet(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('setNumber: $setNumber, ')
          ..write('reps: $reps, ')
          ..write('weightKg: $weightKg, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('rpe: $rpe, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    exerciseId,
    setNumber,
    reps,
    weightKg,
    durationSeconds,
    rpe,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSet &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.exerciseId == this.exerciseId &&
          other.setNumber == this.setNumber &&
          other.reps == this.reps &&
          other.weightKg == this.weightKg &&
          other.durationSeconds == this.durationSeconds &&
          other.rpe == this.rpe &&
          other.notes == this.notes);
}

class WorkoutSetsCompanion extends UpdateCompanion<WorkoutSet> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<int> exerciseId;
  final Value<int> setNumber;
  final Value<int> reps;
  final Value<double> weightKg;
  final Value<int?> durationSeconds;
  final Value<double?> rpe;
  final Value<String?> notes;
  const WorkoutSetsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.setNumber = const Value.absent(),
    this.reps = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.rpe = const Value.absent(),
    this.notes = const Value.absent(),
  });
  WorkoutSetsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required int exerciseId,
    required int setNumber,
    required int reps,
    required double weightKg,
    this.durationSeconds = const Value.absent(),
    this.rpe = const Value.absent(),
    this.notes = const Value.absent(),
  }) : sessionId = Value(sessionId),
       exerciseId = Value(exerciseId),
       setNumber = Value(setNumber),
       reps = Value(reps),
       weightKg = Value(weightKg);
  static Insertable<WorkoutSet> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<int>? exerciseId,
    Expression<int>? setNumber,
    Expression<int>? reps,
    Expression<double>? weightKg,
    Expression<int>? durationSeconds,
    Expression<double>? rpe,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (setNumber != null) 'set_number': setNumber,
      if (reps != null) 'reps': reps,
      if (weightKg != null) 'weight_kg': weightKg,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (rpe != null) 'rpe': rpe,
      if (notes != null) 'notes': notes,
    });
  }

  WorkoutSetsCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionId,
    Value<int>? exerciseId,
    Value<int>? setNumber,
    Value<int>? reps,
    Value<double>? weightKg,
    Value<int?>? durationSeconds,
    Value<double?>? rpe,
    Value<String?>? notes,
  }) {
    return WorkoutSetsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      exerciseId: exerciseId ?? this.exerciseId,
      setNumber: setNumber ?? this.setNumber,
      reps: reps ?? this.reps,
      weightKg: weightKg ?? this.weightKg,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      rpe: rpe ?? this.rpe,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<int>(exerciseId.value);
    }
    if (setNumber.present) {
      map['set_number'] = Variable<int>(setNumber.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (rpe.present) {
      map['rpe'] = Variable<double>(rpe.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSetsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('setNumber: $setNumber, ')
          ..write('reps: $reps, ')
          ..write('weightKg: $weightKg, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('rpe: $rpe, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $BodyweightEntriesTable extends BodyweightEntries
    with TableInfo<$BodyweightEntriesTable, BodyweightEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BodyweightEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, date, weightKg, notes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bodyweight_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<BodyweightEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    } else if (isInserting) {
      context.missing(_weightKgMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BodyweightEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BodyweightEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $BodyweightEntriesTable createAlias(String alias) {
    return $BodyweightEntriesTable(attachedDatabase, alias);
  }
}

class BodyweightEntry extends DataClass implements Insertable<BodyweightEntry> {
  final int id;
  final DateTime date;
  final double weightKg;
  final String? notes;
  const BodyweightEntry({
    required this.id,
    required this.date,
    required this.weightKg,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['weight_kg'] = Variable<double>(weightKg);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  BodyweightEntriesCompanion toCompanion(bool nullToAbsent) {
    return BodyweightEntriesCompanion(
      id: Value(id),
      date: Value(date),
      weightKg: Value(weightKg),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory BodyweightEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BodyweightEntry(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      weightKg: serializer.fromJson<double>(json['weightKg']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'weightKg': serializer.toJson<double>(weightKg),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  BodyweightEntry copyWith({
    int? id,
    DateTime? date,
    double? weightKg,
    Value<String?> notes = const Value.absent(),
  }) => BodyweightEntry(
    id: id ?? this.id,
    date: date ?? this.date,
    weightKg: weightKg ?? this.weightKg,
    notes: notes.present ? notes.value : this.notes,
  );
  BodyweightEntry copyWithCompanion(BodyweightEntriesCompanion data) {
    return BodyweightEntry(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BodyweightEntry(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('weightKg: $weightKg, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, date, weightKg, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BodyweightEntry &&
          other.id == this.id &&
          other.date == this.date &&
          other.weightKg == this.weightKg &&
          other.notes == this.notes);
}

class BodyweightEntriesCompanion extends UpdateCompanion<BodyweightEntry> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<double> weightKg;
  final Value<String?> notes;
  const BodyweightEntriesCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.notes = const Value.absent(),
  });
  BodyweightEntriesCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required double weightKg,
    this.notes = const Value.absent(),
  }) : date = Value(date),
       weightKg = Value(weightKg);
  static Insertable<BodyweightEntry> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<double>? weightKg,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (weightKg != null) 'weight_kg': weightKg,
      if (notes != null) 'notes': notes,
    });
  }

  BodyweightEntriesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<double>? weightKg,
    Value<String?>? notes,
  }) {
    return BodyweightEntriesCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      weightKg: weightKg ?? this.weightKg,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BodyweightEntriesCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('weightKg: $weightKg, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $WodExerciseGroupsTable extends WodExerciseGroups
    with TableInfo<$WodExerciseGroupsTable, WodExerciseGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WodExerciseGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _wodTemplateIdMeta = const VerificationMeta(
    'wodTemplateId',
  );
  @override
  late final GeneratedColumn<int> wodTemplateId = GeneratedColumn<int>(
    'wod_template_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES wod_templates (id)',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roundsMeta = const VerificationMeta('rounds');
  @override
  late final GeneratedColumn<int> rounds = GeneratedColumn<int>(
    'rounds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _restBetweenExercisesSecondsMeta =
      const VerificationMeta('restBetweenExercisesSeconds');
  @override
  late final GeneratedColumn<int> restBetweenExercisesSeconds =
      GeneratedColumn<int>(
        'rest_between_exercises_seconds',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _restBetweenRoundsSecondsMeta =
      const VerificationMeta('restBetweenRoundsSeconds');
  @override
  late final GeneratedColumn<int> restBetweenRoundsSeconds =
      GeneratedColumn<int>(
        'rest_between_rounds_seconds',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(90),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    wodTemplateId,
    sortOrder,
    name,
    rounds,
    restBetweenExercisesSeconds,
    restBetweenRoundsSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wod_exercise_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<WodExerciseGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('wod_template_id')) {
      context.handle(
        _wodTemplateIdMeta,
        wodTemplateId.isAcceptableOrUnknown(
          data['wod_template_id']!,
          _wodTemplateIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_wodTemplateIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('rounds')) {
      context.handle(
        _roundsMeta,
        rounds.isAcceptableOrUnknown(data['rounds']!, _roundsMeta),
      );
    }
    if (data.containsKey('rest_between_exercises_seconds')) {
      context.handle(
        _restBetweenExercisesSecondsMeta,
        restBetweenExercisesSeconds.isAcceptableOrUnknown(
          data['rest_between_exercises_seconds']!,
          _restBetweenExercisesSecondsMeta,
        ),
      );
    }
    if (data.containsKey('rest_between_rounds_seconds')) {
      context.handle(
        _restBetweenRoundsSecondsMeta,
        restBetweenRoundsSeconds.isAcceptableOrUnknown(
          data['rest_between_rounds_seconds']!,
          _restBetweenRoundsSecondsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WodExerciseGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WodExerciseGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      wodTemplateId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wod_template_id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      rounds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rounds'],
      )!,
      restBetweenExercisesSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_between_exercises_seconds'],
      )!,
      restBetweenRoundsSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_between_rounds_seconds'],
      )!,
    );
  }

  @override
  $WodExerciseGroupsTable createAlias(String alias) {
    return $WodExerciseGroupsTable(attachedDatabase, alias);
  }
}

class WodExerciseGroup extends DataClass
    implements Insertable<WodExerciseGroup> {
  final int id;
  final int wodTemplateId;
  final int sortOrder;
  final String? name;
  final int rounds;
  final int restBetweenExercisesSeconds;
  final int restBetweenRoundsSeconds;
  const WodExerciseGroup({
    required this.id,
    required this.wodTemplateId,
    required this.sortOrder,
    this.name,
    required this.rounds,
    required this.restBetweenExercisesSeconds,
    required this.restBetweenRoundsSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['wod_template_id'] = Variable<int>(wodTemplateId);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['rounds'] = Variable<int>(rounds);
    map['rest_between_exercises_seconds'] = Variable<int>(
      restBetweenExercisesSeconds,
    );
    map['rest_between_rounds_seconds'] = Variable<int>(
      restBetweenRoundsSeconds,
    );
    return map;
  }

  WodExerciseGroupsCompanion toCompanion(bool nullToAbsent) {
    return WodExerciseGroupsCompanion(
      id: Value(id),
      wodTemplateId: Value(wodTemplateId),
      sortOrder: Value(sortOrder),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      rounds: Value(rounds),
      restBetweenExercisesSeconds: Value(restBetweenExercisesSeconds),
      restBetweenRoundsSeconds: Value(restBetweenRoundsSeconds),
    );
  }

  factory WodExerciseGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WodExerciseGroup(
      id: serializer.fromJson<int>(json['id']),
      wodTemplateId: serializer.fromJson<int>(json['wodTemplateId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      name: serializer.fromJson<String?>(json['name']),
      rounds: serializer.fromJson<int>(json['rounds']),
      restBetweenExercisesSeconds: serializer.fromJson<int>(
        json['restBetweenExercisesSeconds'],
      ),
      restBetweenRoundsSeconds: serializer.fromJson<int>(
        json['restBetweenRoundsSeconds'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'wodTemplateId': serializer.toJson<int>(wodTemplateId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'name': serializer.toJson<String?>(name),
      'rounds': serializer.toJson<int>(rounds),
      'restBetweenExercisesSeconds': serializer.toJson<int>(
        restBetweenExercisesSeconds,
      ),
      'restBetweenRoundsSeconds': serializer.toJson<int>(
        restBetweenRoundsSeconds,
      ),
    };
  }

  WodExerciseGroup copyWith({
    int? id,
    int? wodTemplateId,
    int? sortOrder,
    Value<String?> name = const Value.absent(),
    int? rounds,
    int? restBetweenExercisesSeconds,
    int? restBetweenRoundsSeconds,
  }) => WodExerciseGroup(
    id: id ?? this.id,
    wodTemplateId: wodTemplateId ?? this.wodTemplateId,
    sortOrder: sortOrder ?? this.sortOrder,
    name: name.present ? name.value : this.name,
    rounds: rounds ?? this.rounds,
    restBetweenExercisesSeconds:
        restBetweenExercisesSeconds ?? this.restBetweenExercisesSeconds,
    restBetweenRoundsSeconds:
        restBetweenRoundsSeconds ?? this.restBetweenRoundsSeconds,
  );
  WodExerciseGroup copyWithCompanion(WodExerciseGroupsCompanion data) {
    return WodExerciseGroup(
      id: data.id.present ? data.id.value : this.id,
      wodTemplateId: data.wodTemplateId.present
          ? data.wodTemplateId.value
          : this.wodTemplateId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      name: data.name.present ? data.name.value : this.name,
      rounds: data.rounds.present ? data.rounds.value : this.rounds,
      restBetweenExercisesSeconds: data.restBetweenExercisesSeconds.present
          ? data.restBetweenExercisesSeconds.value
          : this.restBetweenExercisesSeconds,
      restBetweenRoundsSeconds: data.restBetweenRoundsSeconds.present
          ? data.restBetweenRoundsSeconds.value
          : this.restBetweenRoundsSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WodExerciseGroup(')
          ..write('id: $id, ')
          ..write('wodTemplateId: $wodTemplateId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('name: $name, ')
          ..write('rounds: $rounds, ')
          ..write('restBetweenExercisesSeconds: $restBetweenExercisesSeconds, ')
          ..write('restBetweenRoundsSeconds: $restBetweenRoundsSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    wodTemplateId,
    sortOrder,
    name,
    rounds,
    restBetweenExercisesSeconds,
    restBetweenRoundsSeconds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WodExerciseGroup &&
          other.id == this.id &&
          other.wodTemplateId == this.wodTemplateId &&
          other.sortOrder == this.sortOrder &&
          other.name == this.name &&
          other.rounds == this.rounds &&
          other.restBetweenExercisesSeconds ==
              this.restBetweenExercisesSeconds &&
          other.restBetweenRoundsSeconds == this.restBetweenRoundsSeconds);
}

class WodExerciseGroupsCompanion extends UpdateCompanion<WodExerciseGroup> {
  final Value<int> id;
  final Value<int> wodTemplateId;
  final Value<int> sortOrder;
  final Value<String?> name;
  final Value<int> rounds;
  final Value<int> restBetweenExercisesSeconds;
  final Value<int> restBetweenRoundsSeconds;
  const WodExerciseGroupsCompanion({
    this.id = const Value.absent(),
    this.wodTemplateId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.name = const Value.absent(),
    this.rounds = const Value.absent(),
    this.restBetweenExercisesSeconds = const Value.absent(),
    this.restBetweenRoundsSeconds = const Value.absent(),
  });
  WodExerciseGroupsCompanion.insert({
    this.id = const Value.absent(),
    required int wodTemplateId,
    required int sortOrder,
    this.name = const Value.absent(),
    this.rounds = const Value.absent(),
    this.restBetweenExercisesSeconds = const Value.absent(),
    this.restBetweenRoundsSeconds = const Value.absent(),
  }) : wodTemplateId = Value(wodTemplateId),
       sortOrder = Value(sortOrder);
  static Insertable<WodExerciseGroup> custom({
    Expression<int>? id,
    Expression<int>? wodTemplateId,
    Expression<int>? sortOrder,
    Expression<String>? name,
    Expression<int>? rounds,
    Expression<int>? restBetweenExercisesSeconds,
    Expression<int>? restBetweenRoundsSeconds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (wodTemplateId != null) 'wod_template_id': wodTemplateId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (name != null) 'name': name,
      if (rounds != null) 'rounds': rounds,
      if (restBetweenExercisesSeconds != null)
        'rest_between_exercises_seconds': restBetweenExercisesSeconds,
      if (restBetweenRoundsSeconds != null)
        'rest_between_rounds_seconds': restBetweenRoundsSeconds,
    });
  }

  WodExerciseGroupsCompanion copyWith({
    Value<int>? id,
    Value<int>? wodTemplateId,
    Value<int>? sortOrder,
    Value<String?>? name,
    Value<int>? rounds,
    Value<int>? restBetweenExercisesSeconds,
    Value<int>? restBetweenRoundsSeconds,
  }) {
    return WodExerciseGroupsCompanion(
      id: id ?? this.id,
      wodTemplateId: wodTemplateId ?? this.wodTemplateId,
      sortOrder: sortOrder ?? this.sortOrder,
      name: name ?? this.name,
      rounds: rounds ?? this.rounds,
      restBetweenExercisesSeconds:
          restBetweenExercisesSeconds ?? this.restBetweenExercisesSeconds,
      restBetweenRoundsSeconds:
          restBetweenRoundsSeconds ?? this.restBetweenRoundsSeconds,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (wodTemplateId.present) {
      map['wod_template_id'] = Variable<int>(wodTemplateId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rounds.present) {
      map['rounds'] = Variable<int>(rounds.value);
    }
    if (restBetweenExercisesSeconds.present) {
      map['rest_between_exercises_seconds'] = Variable<int>(
        restBetweenExercisesSeconds.value,
      );
    }
    if (restBetweenRoundsSeconds.present) {
      map['rest_between_rounds_seconds'] = Variable<int>(
        restBetweenRoundsSeconds.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WodExerciseGroupsCompanion(')
          ..write('id: $id, ')
          ..write('wodTemplateId: $wodTemplateId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('name: $name, ')
          ..write('rounds: $rounds, ')
          ..write('restBetweenExercisesSeconds: $restBetweenExercisesSeconds, ')
          ..write('restBetweenRoundsSeconds: $restBetweenRoundsSeconds')
          ..write(')'))
        .toString();
  }
}

class $WodTemplateExercisesTable extends WodTemplateExercises
    with TableInfo<$WodTemplateExercisesTable, WodTemplateExercise> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WodTemplateExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _wodTemplateIdMeta = const VerificationMeta(
    'wodTemplateId',
  );
  @override
  late final GeneratedColumn<int> wodTemplateId = GeneratedColumn<int>(
    'wod_template_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES wod_templates (id)',
    ),
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<int> exerciseId = GeneratedColumn<int>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES exercises (id)',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES wod_exercise_groups (id)',
    ),
  );
  static const VerificationMeta _targetSetsMeta = const VerificationMeta(
    'targetSets',
  );
  @override
  late final GeneratedColumn<int> targetSets = GeneratedColumn<int>(
    'target_sets',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _repRangeMinMeta = const VerificationMeta(
    'repRangeMin',
  );
  @override
  late final GeneratedColumn<int> repRangeMin = GeneratedColumn<int>(
    'rep_range_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(6),
  );
  static const VerificationMeta _repRangeMaxMeta = const VerificationMeta(
    'repRangeMax',
  );
  @override
  late final GeneratedColumn<int> repRangeMax = GeneratedColumn<int>(
    'rep_range_max',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(12),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _restSecondsMeta = const VerificationMeta(
    'restSeconds',
  );
  @override
  late final GeneratedColumn<int> restSeconds = GeneratedColumn<int>(
    'rest_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _restBetweenSetsSecondsMeta =
      const VerificationMeta('restBetweenSetsSeconds');
  @override
  late final GeneratedColumn<int> restBetweenSetsSeconds = GeneratedColumn<int>(
    'rest_between_sets_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetRpeMeta = const VerificationMeta(
    'targetRpe',
  );
  @override
  late final GeneratedColumn<double> targetRpe = GeneratedColumn<double>(
    'target_rpe',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _videoUrlMeta = const VerificationMeta(
    'videoUrl',
  );
  @override
  late final GeneratedColumn<String> videoUrl = GeneratedColumn<String>(
    'video_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    wodTemplateId,
    exerciseId,
    sortOrder,
    groupId,
    targetSets,
    repRangeMin,
    repRangeMax,
    notes,
    restSeconds,
    restBetweenSetsSeconds,
    targetRpe,
    videoUrl,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wod_template_exercises';
  @override
  VerificationContext validateIntegrity(
    Insertable<WodTemplateExercise> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('wod_template_id')) {
      context.handle(
        _wodTemplateIdMeta,
        wodTemplateId.isAcceptableOrUnknown(
          data['wod_template_id']!,
          _wodTemplateIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_wodTemplateIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('target_sets')) {
      context.handle(
        _targetSetsMeta,
        targetSets.isAcceptableOrUnknown(data['target_sets']!, _targetSetsMeta),
      );
    }
    if (data.containsKey('rep_range_min')) {
      context.handle(
        _repRangeMinMeta,
        repRangeMin.isAcceptableOrUnknown(
          data['rep_range_min']!,
          _repRangeMinMeta,
        ),
      );
    }
    if (data.containsKey('rep_range_max')) {
      context.handle(
        _repRangeMaxMeta,
        repRangeMax.isAcceptableOrUnknown(
          data['rep_range_max']!,
          _repRangeMaxMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('rest_seconds')) {
      context.handle(
        _restSecondsMeta,
        restSeconds.isAcceptableOrUnknown(
          data['rest_seconds']!,
          _restSecondsMeta,
        ),
      );
    }
    if (data.containsKey('rest_between_sets_seconds')) {
      context.handle(
        _restBetweenSetsSecondsMeta,
        restBetweenSetsSeconds.isAcceptableOrUnknown(
          data['rest_between_sets_seconds']!,
          _restBetweenSetsSecondsMeta,
        ),
      );
    }
    if (data.containsKey('target_rpe')) {
      context.handle(
        _targetRpeMeta,
        targetRpe.isAcceptableOrUnknown(data['target_rpe']!, _targetRpeMeta),
      );
    }
    if (data.containsKey('video_url')) {
      context.handle(
        _videoUrlMeta,
        videoUrl.isAcceptableOrUnknown(data['video_url']!, _videoUrlMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WodTemplateExercise map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WodTemplateExercise(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      wodTemplateId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wod_template_id'],
      )!,
      exerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}exercise_id'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      ),
      targetSets: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_sets'],
      )!,
      repRangeMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rep_range_min'],
      )!,
      repRangeMax: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rep_range_max'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      restSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_seconds'],
      ),
      restBetweenSetsSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rest_between_sets_seconds'],
      ),
      targetRpe: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_rpe'],
      ),
      videoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_url'],
      ),
    );
  }

  @override
  $WodTemplateExercisesTable createAlias(String alias) {
    return $WodTemplateExercisesTable(attachedDatabase, alias);
  }
}

class WodTemplateExercise extends DataClass
    implements Insertable<WodTemplateExercise> {
  final int id;
  final int wodTemplateId;
  final int exerciseId;
  final int sortOrder;
  final int? groupId;
  final int targetSets;
  final int repRangeMin;
  final int repRangeMax;
  final String? notes;
  final int? restSeconds;
  final int? restBetweenSetsSeconds;
  final double? targetRpe;
  final String? videoUrl;
  const WodTemplateExercise({
    required this.id,
    required this.wodTemplateId,
    required this.exerciseId,
    required this.sortOrder,
    this.groupId,
    required this.targetSets,
    required this.repRangeMin,
    required this.repRangeMax,
    this.notes,
    this.restSeconds,
    this.restBetweenSetsSeconds,
    this.targetRpe,
    this.videoUrl,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['wod_template_id'] = Variable<int>(wodTemplateId);
    map['exercise_id'] = Variable<int>(exerciseId);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<int>(groupId);
    }
    map['target_sets'] = Variable<int>(targetSets);
    map['rep_range_min'] = Variable<int>(repRangeMin);
    map['rep_range_max'] = Variable<int>(repRangeMax);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || restSeconds != null) {
      map['rest_seconds'] = Variable<int>(restSeconds);
    }
    if (!nullToAbsent || restBetweenSetsSeconds != null) {
      map['rest_between_sets_seconds'] = Variable<int>(restBetweenSetsSeconds);
    }
    if (!nullToAbsent || targetRpe != null) {
      map['target_rpe'] = Variable<double>(targetRpe);
    }
    if (!nullToAbsent || videoUrl != null) {
      map['video_url'] = Variable<String>(videoUrl);
    }
    return map;
  }

  WodTemplateExercisesCompanion toCompanion(bool nullToAbsent) {
    return WodTemplateExercisesCompanion(
      id: Value(id),
      wodTemplateId: Value(wodTemplateId),
      exerciseId: Value(exerciseId),
      sortOrder: Value(sortOrder),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      targetSets: Value(targetSets),
      repRangeMin: Value(repRangeMin),
      repRangeMax: Value(repRangeMax),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      restSeconds: restSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(restSeconds),
      restBetweenSetsSeconds: restBetweenSetsSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(restBetweenSetsSeconds),
      targetRpe: targetRpe == null && nullToAbsent
          ? const Value.absent()
          : Value(targetRpe),
      videoUrl: videoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(videoUrl),
    );
  }

  factory WodTemplateExercise.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WodTemplateExercise(
      id: serializer.fromJson<int>(json['id']),
      wodTemplateId: serializer.fromJson<int>(json['wodTemplateId']),
      exerciseId: serializer.fromJson<int>(json['exerciseId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      groupId: serializer.fromJson<int?>(json['groupId']),
      targetSets: serializer.fromJson<int>(json['targetSets']),
      repRangeMin: serializer.fromJson<int>(json['repRangeMin']),
      repRangeMax: serializer.fromJson<int>(json['repRangeMax']),
      notes: serializer.fromJson<String?>(json['notes']),
      restSeconds: serializer.fromJson<int?>(json['restSeconds']),
      restBetweenSetsSeconds: serializer.fromJson<int?>(
        json['restBetweenSetsSeconds'],
      ),
      targetRpe: serializer.fromJson<double?>(json['targetRpe']),
      videoUrl: serializer.fromJson<String?>(json['videoUrl']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'wodTemplateId': serializer.toJson<int>(wodTemplateId),
      'exerciseId': serializer.toJson<int>(exerciseId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'groupId': serializer.toJson<int?>(groupId),
      'targetSets': serializer.toJson<int>(targetSets),
      'repRangeMin': serializer.toJson<int>(repRangeMin),
      'repRangeMax': serializer.toJson<int>(repRangeMax),
      'notes': serializer.toJson<String?>(notes),
      'restSeconds': serializer.toJson<int?>(restSeconds),
      'restBetweenSetsSeconds': serializer.toJson<int?>(restBetweenSetsSeconds),
      'targetRpe': serializer.toJson<double?>(targetRpe),
      'videoUrl': serializer.toJson<String?>(videoUrl),
    };
  }

  WodTemplateExercise copyWith({
    int? id,
    int? wodTemplateId,
    int? exerciseId,
    int? sortOrder,
    Value<int?> groupId = const Value.absent(),
    int? targetSets,
    int? repRangeMin,
    int? repRangeMax,
    Value<String?> notes = const Value.absent(),
    Value<int?> restSeconds = const Value.absent(),
    Value<int?> restBetweenSetsSeconds = const Value.absent(),
    Value<double?> targetRpe = const Value.absent(),
    Value<String?> videoUrl = const Value.absent(),
  }) => WodTemplateExercise(
    id: id ?? this.id,
    wodTemplateId: wodTemplateId ?? this.wodTemplateId,
    exerciseId: exerciseId ?? this.exerciseId,
    sortOrder: sortOrder ?? this.sortOrder,
    groupId: groupId.present ? groupId.value : this.groupId,
    targetSets: targetSets ?? this.targetSets,
    repRangeMin: repRangeMin ?? this.repRangeMin,
    repRangeMax: repRangeMax ?? this.repRangeMax,
    notes: notes.present ? notes.value : this.notes,
    restSeconds: restSeconds.present ? restSeconds.value : this.restSeconds,
    restBetweenSetsSeconds: restBetweenSetsSeconds.present
        ? restBetweenSetsSeconds.value
        : this.restBetweenSetsSeconds,
    targetRpe: targetRpe.present ? targetRpe.value : this.targetRpe,
    videoUrl: videoUrl.present ? videoUrl.value : this.videoUrl,
  );
  WodTemplateExercise copyWithCompanion(WodTemplateExercisesCompanion data) {
    return WodTemplateExercise(
      id: data.id.present ? data.id.value : this.id,
      wodTemplateId: data.wodTemplateId.present
          ? data.wodTemplateId.value
          : this.wodTemplateId,
      exerciseId: data.exerciseId.present
          ? data.exerciseId.value
          : this.exerciseId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      targetSets: data.targetSets.present
          ? data.targetSets.value
          : this.targetSets,
      repRangeMin: data.repRangeMin.present
          ? data.repRangeMin.value
          : this.repRangeMin,
      repRangeMax: data.repRangeMax.present
          ? data.repRangeMax.value
          : this.repRangeMax,
      notes: data.notes.present ? data.notes.value : this.notes,
      restSeconds: data.restSeconds.present
          ? data.restSeconds.value
          : this.restSeconds,
      restBetweenSetsSeconds: data.restBetweenSetsSeconds.present
          ? data.restBetweenSetsSeconds.value
          : this.restBetweenSetsSeconds,
      targetRpe: data.targetRpe.present ? data.targetRpe.value : this.targetRpe,
      videoUrl: data.videoUrl.present ? data.videoUrl.value : this.videoUrl,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WodTemplateExercise(')
          ..write('id: $id, ')
          ..write('wodTemplateId: $wodTemplateId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('groupId: $groupId, ')
          ..write('targetSets: $targetSets, ')
          ..write('repRangeMin: $repRangeMin, ')
          ..write('repRangeMax: $repRangeMax, ')
          ..write('notes: $notes, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('restBetweenSetsSeconds: $restBetweenSetsSeconds, ')
          ..write('targetRpe: $targetRpe, ')
          ..write('videoUrl: $videoUrl')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    wodTemplateId,
    exerciseId,
    sortOrder,
    groupId,
    targetSets,
    repRangeMin,
    repRangeMax,
    notes,
    restSeconds,
    restBetweenSetsSeconds,
    targetRpe,
    videoUrl,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WodTemplateExercise &&
          other.id == this.id &&
          other.wodTemplateId == this.wodTemplateId &&
          other.exerciseId == this.exerciseId &&
          other.sortOrder == this.sortOrder &&
          other.groupId == this.groupId &&
          other.targetSets == this.targetSets &&
          other.repRangeMin == this.repRangeMin &&
          other.repRangeMax == this.repRangeMax &&
          other.notes == this.notes &&
          other.restSeconds == this.restSeconds &&
          other.restBetweenSetsSeconds == this.restBetweenSetsSeconds &&
          other.targetRpe == this.targetRpe &&
          other.videoUrl == this.videoUrl);
}

class WodTemplateExercisesCompanion
    extends UpdateCompanion<WodTemplateExercise> {
  final Value<int> id;
  final Value<int> wodTemplateId;
  final Value<int> exerciseId;
  final Value<int> sortOrder;
  final Value<int?> groupId;
  final Value<int> targetSets;
  final Value<int> repRangeMin;
  final Value<int> repRangeMax;
  final Value<String?> notes;
  final Value<int?> restSeconds;
  final Value<int?> restBetweenSetsSeconds;
  final Value<double?> targetRpe;
  final Value<String?> videoUrl;
  const WodTemplateExercisesCompanion({
    this.id = const Value.absent(),
    this.wodTemplateId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.groupId = const Value.absent(),
    this.targetSets = const Value.absent(),
    this.repRangeMin = const Value.absent(),
    this.repRangeMax = const Value.absent(),
    this.notes = const Value.absent(),
    this.restSeconds = const Value.absent(),
    this.restBetweenSetsSeconds = const Value.absent(),
    this.targetRpe = const Value.absent(),
    this.videoUrl = const Value.absent(),
  });
  WodTemplateExercisesCompanion.insert({
    this.id = const Value.absent(),
    required int wodTemplateId,
    required int exerciseId,
    required int sortOrder,
    this.groupId = const Value.absent(),
    this.targetSets = const Value.absent(),
    this.repRangeMin = const Value.absent(),
    this.repRangeMax = const Value.absent(),
    this.notes = const Value.absent(),
    this.restSeconds = const Value.absent(),
    this.restBetweenSetsSeconds = const Value.absent(),
    this.targetRpe = const Value.absent(),
    this.videoUrl = const Value.absent(),
  }) : wodTemplateId = Value(wodTemplateId),
       exerciseId = Value(exerciseId),
       sortOrder = Value(sortOrder);
  static Insertable<WodTemplateExercise> custom({
    Expression<int>? id,
    Expression<int>? wodTemplateId,
    Expression<int>? exerciseId,
    Expression<int>? sortOrder,
    Expression<int>? groupId,
    Expression<int>? targetSets,
    Expression<int>? repRangeMin,
    Expression<int>? repRangeMax,
    Expression<String>? notes,
    Expression<int>? restSeconds,
    Expression<int>? restBetweenSetsSeconds,
    Expression<double>? targetRpe,
    Expression<String>? videoUrl,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (wodTemplateId != null) 'wod_template_id': wodTemplateId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (groupId != null) 'group_id': groupId,
      if (targetSets != null) 'target_sets': targetSets,
      if (repRangeMin != null) 'rep_range_min': repRangeMin,
      if (repRangeMax != null) 'rep_range_max': repRangeMax,
      if (notes != null) 'notes': notes,
      if (restSeconds != null) 'rest_seconds': restSeconds,
      if (restBetweenSetsSeconds != null)
        'rest_between_sets_seconds': restBetweenSetsSeconds,
      if (targetRpe != null) 'target_rpe': targetRpe,
      if (videoUrl != null) 'video_url': videoUrl,
    });
  }

  WodTemplateExercisesCompanion copyWith({
    Value<int>? id,
    Value<int>? wodTemplateId,
    Value<int>? exerciseId,
    Value<int>? sortOrder,
    Value<int?>? groupId,
    Value<int>? targetSets,
    Value<int>? repRangeMin,
    Value<int>? repRangeMax,
    Value<String?>? notes,
    Value<int?>? restSeconds,
    Value<int?>? restBetweenSetsSeconds,
    Value<double?>? targetRpe,
    Value<String?>? videoUrl,
  }) {
    return WodTemplateExercisesCompanion(
      id: id ?? this.id,
      wodTemplateId: wodTemplateId ?? this.wodTemplateId,
      exerciseId: exerciseId ?? this.exerciseId,
      sortOrder: sortOrder ?? this.sortOrder,
      groupId: groupId ?? this.groupId,
      targetSets: targetSets ?? this.targetSets,
      repRangeMin: repRangeMin ?? this.repRangeMin,
      repRangeMax: repRangeMax ?? this.repRangeMax,
      notes: notes ?? this.notes,
      restSeconds: restSeconds ?? this.restSeconds,
      restBetweenSetsSeconds:
          restBetweenSetsSeconds ?? this.restBetweenSetsSeconds,
      targetRpe: targetRpe ?? this.targetRpe,
      videoUrl: videoUrl ?? this.videoUrl,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (wodTemplateId.present) {
      map['wod_template_id'] = Variable<int>(wodTemplateId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<int>(exerciseId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (targetSets.present) {
      map['target_sets'] = Variable<int>(targetSets.value);
    }
    if (repRangeMin.present) {
      map['rep_range_min'] = Variable<int>(repRangeMin.value);
    }
    if (repRangeMax.present) {
      map['rep_range_max'] = Variable<int>(repRangeMax.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (restSeconds.present) {
      map['rest_seconds'] = Variable<int>(restSeconds.value);
    }
    if (restBetweenSetsSeconds.present) {
      map['rest_between_sets_seconds'] = Variable<int>(
        restBetweenSetsSeconds.value,
      );
    }
    if (targetRpe.present) {
      map['target_rpe'] = Variable<double>(targetRpe.value);
    }
    if (videoUrl.present) {
      map['video_url'] = Variable<String>(videoUrl.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WodTemplateExercisesCompanion(')
          ..write('id: $id, ')
          ..write('wodTemplateId: $wodTemplateId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('groupId: $groupId, ')
          ..write('targetSets: $targetSets, ')
          ..write('repRangeMin: $repRangeMin, ')
          ..write('repRangeMax: $repRangeMax, ')
          ..write('notes: $notes, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('restBetweenSetsSeconds: $restBetweenSetsSeconds, ')
          ..write('targetRpe: $targetRpe, ')
          ..write('videoUrl: $videoUrl')
          ..write(')'))
        .toString();
  }
}

class $DailyTasksTable extends DailyTasks
    with TableInfo<$DailyTasksTable, DailyTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconNameMeta = const VerificationMeta(
    'iconName',
  );
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
    'icon_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderHourMeta = const VerificationMeta(
    'reminderHour',
  );
  @override
  late final GeneratedColumn<int> reminderHour = GeneratedColumn<int>(
    'reminder_hour',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reminderMinuteMeta = const VerificationMeta(
    'reminderMinute',
  );
  @override
  late final GeneratedColumn<int> reminderMinute = GeneratedColumn<int>(
    'reminder_minute',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    iconName,
    reminderHour,
    reminderMinute,
    isEnabled,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyTask> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon_name')) {
      context.handle(
        _iconNameMeta,
        iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta),
      );
    }
    if (data.containsKey('reminder_hour')) {
      context.handle(
        _reminderHourMeta,
        reminderHour.isAcceptableOrUnknown(
          data['reminder_hour']!,
          _reminderHourMeta,
        ),
      );
    }
    if (data.containsKey('reminder_minute')) {
      context.handle(
        _reminderMinuteMeta,
        reminderMinute.isAcceptableOrUnknown(
          data['reminder_minute']!,
          _reminderMinuteMeta,
        ),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DailyTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyTask(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      iconName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_name'],
      ),
      reminderHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_hour'],
      ),
      reminderMinute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_minute'],
      ),
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $DailyTasksTable createAlias(String alias) {
    return $DailyTasksTable(attachedDatabase, alias);
  }
}

class DailyTask extends DataClass implements Insertable<DailyTask> {
  final int id;
  final String name;
  final String? iconName;
  final int? reminderHour;
  final int? reminderMinute;
  final bool isEnabled;
  final int sortOrder;
  const DailyTask({
    required this.id,
    required this.name,
    this.iconName,
    this.reminderHour,
    this.reminderMinute,
    required this.isEnabled,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || iconName != null) {
      map['icon_name'] = Variable<String>(iconName);
    }
    if (!nullToAbsent || reminderHour != null) {
      map['reminder_hour'] = Variable<int>(reminderHour);
    }
    if (!nullToAbsent || reminderMinute != null) {
      map['reminder_minute'] = Variable<int>(reminderMinute);
    }
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  DailyTasksCompanion toCompanion(bool nullToAbsent) {
    return DailyTasksCompanion(
      id: Value(id),
      name: Value(name),
      iconName: iconName == null && nullToAbsent
          ? const Value.absent()
          : Value(iconName),
      reminderHour: reminderHour == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderHour),
      reminderMinute: reminderMinute == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderMinute),
      isEnabled: Value(isEnabled),
      sortOrder: Value(sortOrder),
    );
  }

  factory DailyTask.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyTask(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      iconName: serializer.fromJson<String?>(json['iconName']),
      reminderHour: serializer.fromJson<int?>(json['reminderHour']),
      reminderMinute: serializer.fromJson<int?>(json['reminderMinute']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'iconName': serializer.toJson<String?>(iconName),
      'reminderHour': serializer.toJson<int?>(reminderHour),
      'reminderMinute': serializer.toJson<int?>(reminderMinute),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  DailyTask copyWith({
    int? id,
    String? name,
    Value<String?> iconName = const Value.absent(),
    Value<int?> reminderHour = const Value.absent(),
    Value<int?> reminderMinute = const Value.absent(),
    bool? isEnabled,
    int? sortOrder,
  }) => DailyTask(
    id: id ?? this.id,
    name: name ?? this.name,
    iconName: iconName.present ? iconName.value : this.iconName,
    reminderHour: reminderHour.present ? reminderHour.value : this.reminderHour,
    reminderMinute: reminderMinute.present
        ? reminderMinute.value
        : this.reminderMinute,
    isEnabled: isEnabled ?? this.isEnabled,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  DailyTask copyWithCompanion(DailyTasksCompanion data) {
    return DailyTask(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      reminderHour: data.reminderHour.present
          ? data.reminderHour.value
          : this.reminderHour,
      reminderMinute: data.reminderMinute.present
          ? data.reminderMinute.value
          : this.reminderMinute,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyTask(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('iconName: $iconName, ')
          ..write('reminderHour: $reminderHour, ')
          ..write('reminderMinute: $reminderMinute, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    iconName,
    reminderHour,
    reminderMinute,
    isEnabled,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyTask &&
          other.id == this.id &&
          other.name == this.name &&
          other.iconName == this.iconName &&
          other.reminderHour == this.reminderHour &&
          other.reminderMinute == this.reminderMinute &&
          other.isEnabled == this.isEnabled &&
          other.sortOrder == this.sortOrder);
}

class DailyTasksCompanion extends UpdateCompanion<DailyTask> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> iconName;
  final Value<int?> reminderHour;
  final Value<int?> reminderMinute;
  final Value<bool> isEnabled;
  final Value<int> sortOrder;
  const DailyTasksCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.iconName = const Value.absent(),
    this.reminderHour = const Value.absent(),
    this.reminderMinute = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
  });
  DailyTasksCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.iconName = const Value.absent(),
    this.reminderHour = const Value.absent(),
    this.reminderMinute = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.sortOrder = const Value.absent(),
  }) : name = Value(name);
  static Insertable<DailyTask> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? iconName,
    Expression<int>? reminderHour,
    Expression<int>? reminderMinute,
    Expression<bool>? isEnabled,
    Expression<int>? sortOrder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (iconName != null) 'icon_name': iconName,
      if (reminderHour != null) 'reminder_hour': reminderHour,
      if (reminderMinute != null) 'reminder_minute': reminderMinute,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (sortOrder != null) 'sort_order': sortOrder,
    });
  }

  DailyTasksCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? iconName,
    Value<int?>? reminderHour,
    Value<int?>? reminderMinute,
    Value<bool>? isEnabled,
    Value<int>? sortOrder,
  }) {
    return DailyTasksCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      isEnabled: isEnabled ?? this.isEnabled,
      sortOrder: sortOrder ?? this.sortOrder,
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
    if (iconName.present) {
      map['icon_name'] = Variable<String>(iconName.value);
    }
    if (reminderHour.present) {
      map['reminder_hour'] = Variable<int>(reminderHour.value);
    }
    if (reminderMinute.present) {
      map['reminder_minute'] = Variable<int>(reminderMinute.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyTasksCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('iconName: $iconName, ')
          ..write('reminderHour: $reminderHour, ')
          ..write('reminderMinute: $reminderMinute, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }
}

class $DailyTaskCompletionsTable extends DailyTaskCompletions
    with TableInfo<$DailyTaskCompletionsTable, DailyTaskCompletion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyTaskCompletionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<int> taskId = GeneratedColumn<int>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES daily_tasks(id) ON DELETE CASCADE',
  );
  static const VerificationMeta _completedDateMeta = const VerificationMeta(
    'completedDate',
  );
  @override
  late final GeneratedColumn<DateTime> completedDate =
      GeneratedColumn<DateTime>(
        'completed_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [id, taskId, completedDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_task_completions';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyTaskCompletion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('completed_date')) {
      context.handle(
        _completedDateMeta,
        completedDate.isAcceptableOrUnknown(
          data['completed_date']!,
          _completedDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedDateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DailyTaskCompletion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyTaskCompletion(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}task_id'],
      )!,
      completedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_date'],
      )!,
    );
  }

  @override
  $DailyTaskCompletionsTable createAlias(String alias) {
    return $DailyTaskCompletionsTable(attachedDatabase, alias);
  }
}

class DailyTaskCompletion extends DataClass
    implements Insertable<DailyTaskCompletion> {
  final int id;
  final int taskId;
  final DateTime completedDate;
  const DailyTaskCompletion({
    required this.id,
    required this.taskId,
    required this.completedDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['task_id'] = Variable<int>(taskId);
    map['completed_date'] = Variable<DateTime>(completedDate);
    return map;
  }

  DailyTaskCompletionsCompanion toCompanion(bool nullToAbsent) {
    return DailyTaskCompletionsCompanion(
      id: Value(id),
      taskId: Value(taskId),
      completedDate: Value(completedDate),
    );
  }

  factory DailyTaskCompletion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyTaskCompletion(
      id: serializer.fromJson<int>(json['id']),
      taskId: serializer.fromJson<int>(json['taskId']),
      completedDate: serializer.fromJson<DateTime>(json['completedDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'taskId': serializer.toJson<int>(taskId),
      'completedDate': serializer.toJson<DateTime>(completedDate),
    };
  }

  DailyTaskCompletion copyWith({
    int? id,
    int? taskId,
    DateTime? completedDate,
  }) => DailyTaskCompletion(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    completedDate: completedDate ?? this.completedDate,
  );
  DailyTaskCompletion copyWithCompanion(DailyTaskCompletionsCompanion data) {
    return DailyTaskCompletion(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      completedDate: data.completedDate.present
          ? data.completedDate.value
          : this.completedDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyTaskCompletion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('completedDate: $completedDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, taskId, completedDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyTaskCompletion &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.completedDate == this.completedDate);
}

class DailyTaskCompletionsCompanion
    extends UpdateCompanion<DailyTaskCompletion> {
  final Value<int> id;
  final Value<int> taskId;
  final Value<DateTime> completedDate;
  const DailyTaskCompletionsCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.completedDate = const Value.absent(),
  });
  DailyTaskCompletionsCompanion.insert({
    this.id = const Value.absent(),
    required int taskId,
    required DateTime completedDate,
  }) : taskId = Value(taskId),
       completedDate = Value(completedDate);
  static Insertable<DailyTaskCompletion> custom({
    Expression<int>? id,
    Expression<int>? taskId,
    Expression<DateTime>? completedDate,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (completedDate != null) 'completed_date': completedDate,
    });
  }

  DailyTaskCompletionsCompanion copyWith({
    Value<int>? id,
    Value<int>? taskId,
    Value<DateTime>? completedDate,
  }) {
    return DailyTaskCompletionsCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      completedDate: completedDate ?? this.completedDate,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<int>(taskId.value);
    }
    if (completedDate.present) {
      map['completed_date'] = Variable<DateTime>(completedDate.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyTaskCompletionsCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('completedDate: $completedDate')
          ..write(')'))
        .toString();
  }
}

class $UserProfilesTable extends UserProfiles
    with TableInfo<$UserProfilesTable, UserProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
    'gender',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('male'),
  );
  static const VerificationMeta _ageMeta = const VerificationMeta('age');
  @override
  late final GeneratedColumn<int> age = GeneratedColumn<int>(
    'age',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightCmMeta = const VerificationMeta(
    'heightCm',
  );
  @override
  late final GeneratedColumn<double> heightCm = GeneratedColumn<double>(
    'height_cm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetWeightKgMeta = const VerificationMeta(
    'targetWeightKg',
  );
  @override
  late final GeneratedColumn<double> targetWeightKg = GeneratedColumn<double>(
    'target_weight_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fitnessGoalMeta = const VerificationMeta(
    'fitnessGoal',
  );
  @override
  late final GeneratedColumn<String> fitnessGoal = GeneratedColumn<String>(
    'fitness_goal',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('maintain'),
  );
  static const VerificationMeta _activityLevelMeta = const VerificationMeta(
    'activityLevel',
  );
  @override
  late final GeneratedColumn<String> activityLevel = GeneratedColumn<String>(
    'activity_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('moderate'),
  );
  static const VerificationMeta _weeklyRateKgMeta = const VerificationMeta(
    'weeklyRateKg',
  );
  @override
  late final GeneratedColumn<double> weeklyRateKg = GeneratedColumn<double>(
    'weekly_rate_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    gender,
    age,
    heightCm,
    weightKg,
    targetWeightKg,
    fitnessGoal,
    activityLevel,
    weeklyRateKg,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('gender')) {
      context.handle(
        _genderMeta,
        gender.isAcceptableOrUnknown(data['gender']!, _genderMeta),
      );
    }
    if (data.containsKey('age')) {
      context.handle(
        _ageMeta,
        age.isAcceptableOrUnknown(data['age']!, _ageMeta),
      );
    }
    if (data.containsKey('height_cm')) {
      context.handle(
        _heightCmMeta,
        heightCm.isAcceptableOrUnknown(data['height_cm']!, _heightCmMeta),
      );
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    }
    if (data.containsKey('target_weight_kg')) {
      context.handle(
        _targetWeightKgMeta,
        targetWeightKg.isAcceptableOrUnknown(
          data['target_weight_kg']!,
          _targetWeightKgMeta,
        ),
      );
    }
    if (data.containsKey('fitness_goal')) {
      context.handle(
        _fitnessGoalMeta,
        fitnessGoal.isAcceptableOrUnknown(
          data['fitness_goal']!,
          _fitnessGoalMeta,
        ),
      );
    }
    if (data.containsKey('activity_level')) {
      context.handle(
        _activityLevelMeta,
        activityLevel.isAcceptableOrUnknown(
          data['activity_level']!,
          _activityLevelMeta,
        ),
      );
    }
    if (data.containsKey('weekly_rate_kg')) {
      context.handle(
        _weeklyRateKgMeta,
        weeklyRateKg.isAcceptableOrUnknown(
          data['weekly_rate_kg']!,
          _weeklyRateKgMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      gender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gender'],
      )!,
      age: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}age'],
      ),
      heightCm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height_cm'],
      ),
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      ),
      targetWeightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_weight_kg'],
      ),
      fitnessGoal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fitness_goal'],
      )!,
      activityLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_level'],
      )!,
      weeklyRateKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weekly_rate_kg'],
      ),
    );
  }

  @override
  $UserProfilesTable createAlias(String alias) {
    return $UserProfilesTable(attachedDatabase, alias);
  }
}

class UserProfile extends DataClass implements Insertable<UserProfile> {
  final int id;
  final String name;
  final String gender;
  final int? age;
  final double? heightCm;
  final double? weightKg;
  final double? targetWeightKg;
  final String fitnessGoal;
  final String activityLevel;
  final double? weeklyRateKg;
  const UserProfile({
    required this.id,
    required this.name,
    required this.gender,
    this.age,
    this.heightCm,
    this.weightKg,
    this.targetWeightKg,
    required this.fitnessGoal,
    required this.activityLevel,
    this.weeklyRateKg,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['gender'] = Variable<String>(gender);
    if (!nullToAbsent || age != null) {
      map['age'] = Variable<int>(age);
    }
    if (!nullToAbsent || heightCm != null) {
      map['height_cm'] = Variable<double>(heightCm);
    }
    if (!nullToAbsent || weightKg != null) {
      map['weight_kg'] = Variable<double>(weightKg);
    }
    if (!nullToAbsent || targetWeightKg != null) {
      map['target_weight_kg'] = Variable<double>(targetWeightKg);
    }
    map['fitness_goal'] = Variable<String>(fitnessGoal);
    map['activity_level'] = Variable<String>(activityLevel);
    if (!nullToAbsent || weeklyRateKg != null) {
      map['weekly_rate_kg'] = Variable<double>(weeklyRateKg);
    }
    return map;
  }

  UserProfilesCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesCompanion(
      id: Value(id),
      name: Value(name),
      gender: Value(gender),
      age: age == null && nullToAbsent ? const Value.absent() : Value(age),
      heightCm: heightCm == null && nullToAbsent
          ? const Value.absent()
          : Value(heightCm),
      weightKg: weightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(weightKg),
      targetWeightKg: targetWeightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(targetWeightKg),
      fitnessGoal: Value(fitnessGoal),
      activityLevel: Value(activityLevel),
      weeklyRateKg: weeklyRateKg == null && nullToAbsent
          ? const Value.absent()
          : Value(weeklyRateKg),
    );
  }

  factory UserProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfile(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      gender: serializer.fromJson<String>(json['gender']),
      age: serializer.fromJson<int?>(json['age']),
      heightCm: serializer.fromJson<double?>(json['heightCm']),
      weightKg: serializer.fromJson<double?>(json['weightKg']),
      targetWeightKg: serializer.fromJson<double?>(json['targetWeightKg']),
      fitnessGoal: serializer.fromJson<String>(json['fitnessGoal']),
      activityLevel: serializer.fromJson<String>(json['activityLevel']),
      weeklyRateKg: serializer.fromJson<double?>(json['weeklyRateKg']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'gender': serializer.toJson<String>(gender),
      'age': serializer.toJson<int?>(age),
      'heightCm': serializer.toJson<double?>(heightCm),
      'weightKg': serializer.toJson<double?>(weightKg),
      'targetWeightKg': serializer.toJson<double?>(targetWeightKg),
      'fitnessGoal': serializer.toJson<String>(fitnessGoal),
      'activityLevel': serializer.toJson<String>(activityLevel),
      'weeklyRateKg': serializer.toJson<double?>(weeklyRateKg),
    };
  }

  UserProfile copyWith({
    int? id,
    String? name,
    String? gender,
    Value<int?> age = const Value.absent(),
    Value<double?> heightCm = const Value.absent(),
    Value<double?> weightKg = const Value.absent(),
    Value<double?> targetWeightKg = const Value.absent(),
    String? fitnessGoal,
    String? activityLevel,
    Value<double?> weeklyRateKg = const Value.absent(),
  }) => UserProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    gender: gender ?? this.gender,
    age: age.present ? age.value : this.age,
    heightCm: heightCm.present ? heightCm.value : this.heightCm,
    weightKg: weightKg.present ? weightKg.value : this.weightKg,
    targetWeightKg: targetWeightKg.present
        ? targetWeightKg.value
        : this.targetWeightKg,
    fitnessGoal: fitnessGoal ?? this.fitnessGoal,
    activityLevel: activityLevel ?? this.activityLevel,
    weeklyRateKg: weeklyRateKg.present ? weeklyRateKg.value : this.weeklyRateKg,
  );
  UserProfile copyWithCompanion(UserProfilesCompanion data) {
    return UserProfile(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      gender: data.gender.present ? data.gender.value : this.gender,
      age: data.age.present ? data.age.value : this.age,
      heightCm: data.heightCm.present ? data.heightCm.value : this.heightCm,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      targetWeightKg: data.targetWeightKg.present
          ? data.targetWeightKg.value
          : this.targetWeightKg,
      fitnessGoal: data.fitnessGoal.present
          ? data.fitnessGoal.value
          : this.fitnessGoal,
      activityLevel: data.activityLevel.present
          ? data.activityLevel.value
          : this.activityLevel,
      weeklyRateKg: data.weeklyRateKg.present
          ? data.weeklyRateKg.value
          : this.weeklyRateKg,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfile(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('gender: $gender, ')
          ..write('age: $age, ')
          ..write('heightCm: $heightCm, ')
          ..write('weightKg: $weightKg, ')
          ..write('targetWeightKg: $targetWeightKg, ')
          ..write('fitnessGoal: $fitnessGoal, ')
          ..write('activityLevel: $activityLevel, ')
          ..write('weeklyRateKg: $weeklyRateKg')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    gender,
    age,
    heightCm,
    weightKg,
    targetWeightKg,
    fitnessGoal,
    activityLevel,
    weeklyRateKg,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfile &&
          other.id == this.id &&
          other.name == this.name &&
          other.gender == this.gender &&
          other.age == this.age &&
          other.heightCm == this.heightCm &&
          other.weightKg == this.weightKg &&
          other.targetWeightKg == this.targetWeightKg &&
          other.fitnessGoal == this.fitnessGoal &&
          other.activityLevel == this.activityLevel &&
          other.weeklyRateKg == this.weeklyRateKg);
}

class UserProfilesCompanion extends UpdateCompanion<UserProfile> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> gender;
  final Value<int?> age;
  final Value<double?> heightCm;
  final Value<double?> weightKg;
  final Value<double?> targetWeightKg;
  final Value<String> fitnessGoal;
  final Value<String> activityLevel;
  final Value<double?> weeklyRateKg;
  const UserProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.gender = const Value.absent(),
    this.age = const Value.absent(),
    this.heightCm = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.targetWeightKg = const Value.absent(),
    this.fitnessGoal = const Value.absent(),
    this.activityLevel = const Value.absent(),
    this.weeklyRateKg = const Value.absent(),
  });
  UserProfilesCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.gender = const Value.absent(),
    this.age = const Value.absent(),
    this.heightCm = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.targetWeightKg = const Value.absent(),
    this.fitnessGoal = const Value.absent(),
    this.activityLevel = const Value.absent(),
    this.weeklyRateKg = const Value.absent(),
  });
  static Insertable<UserProfile> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? gender,
    Expression<int>? age,
    Expression<double>? heightCm,
    Expression<double>? weightKg,
    Expression<double>? targetWeightKg,
    Expression<String>? fitnessGoal,
    Expression<String>? activityLevel,
    Expression<double>? weeklyRateKg,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (gender != null) 'gender': gender,
      if (age != null) 'age': age,
      if (heightCm != null) 'height_cm': heightCm,
      if (weightKg != null) 'weight_kg': weightKg,
      if (targetWeightKg != null) 'target_weight_kg': targetWeightKg,
      if (fitnessGoal != null) 'fitness_goal': fitnessGoal,
      if (activityLevel != null) 'activity_level': activityLevel,
      if (weeklyRateKg != null) 'weekly_rate_kg': weeklyRateKg,
    });
  }

  UserProfilesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? gender,
    Value<int?>? age,
    Value<double?>? heightCm,
    Value<double?>? weightKg,
    Value<double?>? targetWeightKg,
    Value<String>? fitnessGoal,
    Value<String>? activityLevel,
    Value<double?>? weeklyRateKg,
  }) {
    return UserProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      activityLevel: activityLevel ?? this.activityLevel,
      weeklyRateKg: weeklyRateKg ?? this.weeklyRateKg,
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
    if (gender.present) {
      map['gender'] = Variable<String>(gender.value);
    }
    if (age.present) {
      map['age'] = Variable<int>(age.value);
    }
    if (heightCm.present) {
      map['height_cm'] = Variable<double>(heightCm.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (targetWeightKg.present) {
      map['target_weight_kg'] = Variable<double>(targetWeightKg.value);
    }
    if (fitnessGoal.present) {
      map['fitness_goal'] = Variable<String>(fitnessGoal.value);
    }
    if (activityLevel.present) {
      map['activity_level'] = Variable<String>(activityLevel.value);
    }
    if (weeklyRateKg.present) {
      map['weekly_rate_kg'] = Variable<double>(weeklyRateKg.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('gender: $gender, ')
          ..write('age: $age, ')
          ..write('heightCm: $heightCm, ')
          ..write('weightKg: $weightKg, ')
          ..write('targetWeightKg: $targetWeightKg, ')
          ..write('fitnessGoal: $fitnessGoal, ')
          ..write('activityLevel: $activityLevel, ')
          ..write('weeklyRateKg: $weeklyRateKg')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ExercisesTable exercises = $ExercisesTable(this);
  late final $ProgramsTable programs = $ProgramsTable(this);
  late final $ProgramPhasesTable programPhases = $ProgramPhasesTable(this);
  late final $WodTemplatesTable wodTemplates = $WodTemplatesTable(this);
  late final $WorkoutSessionsTable workoutSessions = $WorkoutSessionsTable(
    this,
  );
  late final $WorkoutSetsTable workoutSets = $WorkoutSetsTable(this);
  late final $BodyweightEntriesTable bodyweightEntries =
      $BodyweightEntriesTable(this);
  late final $WodExerciseGroupsTable wodExerciseGroups =
      $WodExerciseGroupsTable(this);
  late final $WodTemplateExercisesTable wodTemplateExercises =
      $WodTemplateExercisesTable(this);
  late final $DailyTasksTable dailyTasks = $DailyTasksTable(this);
  late final $DailyTaskCompletionsTable dailyTaskCompletions =
      $DailyTaskCompletionsTable(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  late final ExercisesDao exercisesDao = ExercisesDao(this as AppDatabase);
  late final ProgramsDao programsDao = ProgramsDao(this as AppDatabase);
  late final SessionsDao sessionsDao = SessionsDao(this as AppDatabase);
  late final SetsDao setsDao = SetsDao(this as AppDatabase);
  late final BodyweightDao bodyweightDao = BodyweightDao(this as AppDatabase);
  late final DailyTasksDao dailyTasksDao = DailyTasksDao(this as AppDatabase);
  late final UserProfileDao userProfileDao = UserProfileDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    exercises,
    programs,
    programPhases,
    wodTemplates,
    workoutSessions,
    workoutSets,
    bodyweightEntries,
    wodExerciseGroups,
    wodTemplateExercises,
    dailyTasks,
    dailyTaskCompletions,
    userProfiles,
  ];
}

typedef $$ExercisesTableCreateCompanionBuilder =
    ExercisesCompanion Function({
      Value<int> id,
      required String name,
      Value<String> category,
      Value<String?> notes,
      Value<bool> isTimed,
    });
typedef $$ExercisesTableUpdateCompanionBuilder =
    ExercisesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> category,
      Value<String?> notes,
      Value<bool> isTimed,
    });

final class $$ExercisesTableReferences
    extends BaseReferences<_$AppDatabase, $ExercisesTable, Exercise> {
  $$ExercisesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$WorkoutSetsTable, List<WorkoutSet>>
  _workoutSetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.workoutSets,
    aliasName: $_aliasNameGenerator(db.exercises.id, db.workoutSets.exerciseId),
  );

  $$WorkoutSetsTableProcessedTableManager get workoutSetsRefs {
    final manager = $$WorkoutSetsTableTableManager(
      $_db,
      $_db.workoutSets,
    ).filter((f) => f.exerciseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_workoutSetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $WodTemplateExercisesTable,
    List<WodTemplateExercise>
  >
  _wodTemplateExercisesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.wodTemplateExercises,
        aliasName: $_aliasNameGenerator(
          db.exercises.id,
          db.wodTemplateExercises.exerciseId,
        ),
      );

  $$WodTemplateExercisesTableProcessedTableManager
  get wodTemplateExercisesRefs {
    final manager = $$WodTemplateExercisesTableTableManager(
      $_db,
      $_db.wodTemplateExercises,
    ).filter((f) => f.exerciseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _wodTemplateExercisesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isTimed => $composableBuilder(
    column: $table.isTimed,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> workoutSetsRefs(
    Expression<bool> Function($$WorkoutSetsTableFilterComposer f) f,
  ) {
    final $$WorkoutSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.exerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableFilterComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> wodTemplateExercisesRefs(
    Expression<bool> Function($$WodTemplateExercisesTableFilterComposer f) f,
  ) {
    final $$WodTemplateExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wodTemplateExercises,
      getReferencedColumn: (t) => t.exerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WodTemplateExercisesTableFilterComposer(
            $db: $db,
            $table: $db.wodTemplateExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isTimed => $composableBuilder(
    column: $table.isTimed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExercisesTable> {
  $$ExercisesTableAnnotationComposer({
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

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get isTimed =>
      $composableBuilder(column: $table.isTimed, builder: (column) => column);

  Expression<T> workoutSetsRefs<T extends Object>(
    Expression<T> Function($$WorkoutSetsTableAnnotationComposer a) f,
  ) {
    final $$WorkoutSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.exerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> wodTemplateExercisesRefs<T extends Object>(
    Expression<T> Function($$WodTemplateExercisesTableAnnotationComposer a) f,
  ) {
    final $$WodTemplateExercisesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.wodTemplateExercises,
          getReferencedColumn: (t) => t.exerciseId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WodTemplateExercisesTableAnnotationComposer(
                $db: $db,
                $table: $db.wodTemplateExercises,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ExercisesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExercisesTable,
          Exercise,
          $$ExercisesTableFilterComposer,
          $$ExercisesTableOrderingComposer,
          $$ExercisesTableAnnotationComposer,
          $$ExercisesTableCreateCompanionBuilder,
          $$ExercisesTableUpdateCompanionBuilder,
          (Exercise, $$ExercisesTableReferences),
          Exercise,
          PrefetchHooks Function({
            bool workoutSetsRefs,
            bool wodTemplateExercisesRefs,
          })
        > {
  $$ExercisesTableTableManager(_$AppDatabase db, $ExercisesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> isTimed = const Value.absent(),
              }) => ExercisesCompanion(
                id: id,
                name: name,
                category: category,
                notes: notes,
                isTimed: isTimed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> category = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> isTimed = const Value.absent(),
              }) => ExercisesCompanion.insert(
                id: id,
                name: name,
                category: category,
                notes: notes,
                isTimed: isTimed,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExercisesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({workoutSetsRefs = false, wodTemplateExercisesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (workoutSetsRefs) db.workoutSets,
                    if (wodTemplateExercisesRefs) db.wodTemplateExercises,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (workoutSetsRefs)
                        await $_getPrefetchedData<
                          Exercise,
                          $ExercisesTable,
                          WorkoutSet
                        >(
                          currentTable: table,
                          referencedTable: $$ExercisesTableReferences
                              ._workoutSetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ExercisesTableReferences(
                                db,
                                table,
                                p0,
                              ).workoutSetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.exerciseId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (wodTemplateExercisesRefs)
                        await $_getPrefetchedData<
                          Exercise,
                          $ExercisesTable,
                          WodTemplateExercise
                        >(
                          currentTable: table,
                          referencedTable: $$ExercisesTableReferences
                              ._wodTemplateExercisesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ExercisesTableReferences(
                                db,
                                table,
                                p0,
                              ).wodTemplateExercisesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.exerciseId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExercisesTable,
      Exercise,
      $$ExercisesTableFilterComposer,
      $$ExercisesTableOrderingComposer,
      $$ExercisesTableAnnotationComposer,
      $$ExercisesTableCreateCompanionBuilder,
      $$ExercisesTableUpdateCompanionBuilder,
      (Exercise, $$ExercisesTableReferences),
      Exercise,
      PrefetchHooks Function({
        bool workoutSetsRefs,
        bool wodTemplateExercisesRefs,
      })
    >;
typedef $$ProgramsTableCreateCompanionBuilder =
    ProgramsCompanion Function({
      Value<int> id,
      required String name,
      Value<int> status,
      Value<String?> notes,
    });
typedef $$ProgramsTableUpdateCompanionBuilder =
    ProgramsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> status,
      Value<String?> notes,
    });

final class $$ProgramsTableReferences
    extends BaseReferences<_$AppDatabase, $ProgramsTable, Program> {
  $$ProgramsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ProgramPhasesTable, List<ProgramPhase>>
  _programPhasesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.programPhases,
    aliasName: $_aliasNameGenerator(db.programs.id, db.programPhases.programId),
  );

  $$ProgramPhasesTableProcessedTableManager get programPhasesRefs {
    final manager = $$ProgramPhasesTableTableManager(
      $_db,
      $_db.programPhases,
    ).filter((f) => f.programId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_programPhasesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProgramsTableFilterComposer
    extends Composer<_$AppDatabase, $ProgramsTable> {
  $$ProgramsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> programPhasesRefs(
    Expression<bool> Function($$ProgramPhasesTableFilterComposer f) f,
  ) {
    final $$ProgramPhasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.programPhases,
      getReferencedColumn: (t) => t.programId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramPhasesTableFilterComposer(
            $db: $db,
            $table: $db.programPhases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProgramsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProgramsTable> {
  $$ProgramsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProgramsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProgramsTable> {
  $$ProgramsTableAnnotationComposer({
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

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  Expression<T> programPhasesRefs<T extends Object>(
    Expression<T> Function($$ProgramPhasesTableAnnotationComposer a) f,
  ) {
    final $$ProgramPhasesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.programPhases,
      getReferencedColumn: (t) => t.programId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramPhasesTableAnnotationComposer(
            $db: $db,
            $table: $db.programPhases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProgramsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProgramsTable,
          Program,
          $$ProgramsTableFilterComposer,
          $$ProgramsTableOrderingComposer,
          $$ProgramsTableAnnotationComposer,
          $$ProgramsTableCreateCompanionBuilder,
          $$ProgramsTableUpdateCompanionBuilder,
          (Program, $$ProgramsTableReferences),
          Program,
          PrefetchHooks Function({bool programPhasesRefs})
        > {
  $$ProgramsTableTableManager(_$AppDatabase db, $ProgramsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProgramsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProgramsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProgramsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => ProgramsCompanion(
                id: id,
                name: name,
                status: status,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int> status = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => ProgramsCompanion.insert(
                id: id,
                name: name,
                status: status,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProgramsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({programPhasesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (programPhasesRefs) db.programPhases,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (programPhasesRefs)
                    await $_getPrefetchedData<
                      Program,
                      $ProgramsTable,
                      ProgramPhase
                    >(
                      currentTable: table,
                      referencedTable: $$ProgramsTableReferences
                          ._programPhasesRefsTable(db),
                      managerFromTypedResult: (p0) => $$ProgramsTableReferences(
                        db,
                        table,
                        p0,
                      ).programPhasesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.programId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ProgramsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProgramsTable,
      Program,
      $$ProgramsTableFilterComposer,
      $$ProgramsTableOrderingComposer,
      $$ProgramsTableAnnotationComposer,
      $$ProgramsTableCreateCompanionBuilder,
      $$ProgramsTableUpdateCompanionBuilder,
      (Program, $$ProgramsTableReferences),
      Program,
      PrefetchHooks Function({bool programPhasesRefs})
    >;
typedef $$ProgramPhasesTableCreateCompanionBuilder =
    ProgramPhasesCompanion Function({
      Value<int> id,
      required int programId,
      required int phaseNumber,
      required String name,
      required int durationWeeks,
    });
typedef $$ProgramPhasesTableUpdateCompanionBuilder =
    ProgramPhasesCompanion Function({
      Value<int> id,
      Value<int> programId,
      Value<int> phaseNumber,
      Value<String> name,
      Value<int> durationWeeks,
    });

final class $$ProgramPhasesTableReferences
    extends BaseReferences<_$AppDatabase, $ProgramPhasesTable, ProgramPhase> {
  $$ProgramPhasesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProgramsTable _programIdTable(_$AppDatabase db) =>
      db.programs.createAlias(
        $_aliasNameGenerator(db.programPhases.programId, db.programs.id),
      );

  $$ProgramsTableProcessedTableManager get programId {
    final $_column = $_itemColumn<int>('program_id')!;

    final manager = $$ProgramsTableTableManager(
      $_db,
      $_db.programs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_programIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$WodTemplatesTable, List<WodTemplate>>
  _wodTemplatesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.wodTemplates,
    aliasName: $_aliasNameGenerator(
      db.programPhases.id,
      db.wodTemplates.phaseId,
    ),
  );

  $$WodTemplatesTableProcessedTableManager get wodTemplatesRefs {
    final manager = $$WodTemplatesTableTableManager(
      $_db,
      $_db.wodTemplates,
    ).filter((f) => f.phaseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_wodTemplatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProgramPhasesTableFilterComposer
    extends Composer<_$AppDatabase, $ProgramPhasesTable> {
  $$ProgramPhasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get phaseNumber => $composableBuilder(
    column: $table.phaseNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationWeeks => $composableBuilder(
    column: $table.durationWeeks,
    builder: (column) => ColumnFilters(column),
  );

  $$ProgramsTableFilterComposer get programId {
    final $$ProgramsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.programId,
      referencedTable: $db.programs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramsTableFilterComposer(
            $db: $db,
            $table: $db.programs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> wodTemplatesRefs(
    Expression<bool> Function($$WodTemplatesTableFilterComposer f) f,
  ) {
    final $$WodTemplatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wodTemplates,
      getReferencedColumn: (t) => t.phaseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WodTemplatesTableFilterComposer(
            $db: $db,
            $table: $db.wodTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProgramPhasesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProgramPhasesTable> {
  $$ProgramPhasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get phaseNumber => $composableBuilder(
    column: $table.phaseNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationWeeks => $composableBuilder(
    column: $table.durationWeeks,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProgramsTableOrderingComposer get programId {
    final $$ProgramsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.programId,
      referencedTable: $db.programs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramsTableOrderingComposer(
            $db: $db,
            $table: $db.programs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProgramPhasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProgramPhasesTable> {
  $$ProgramPhasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get phaseNumber => $composableBuilder(
    column: $table.phaseNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get durationWeeks => $composableBuilder(
    column: $table.durationWeeks,
    builder: (column) => column,
  );

  $$ProgramsTableAnnotationComposer get programId {
    final $$ProgramsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.programId,
      referencedTable: $db.programs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramsTableAnnotationComposer(
            $db: $db,
            $table: $db.programs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> wodTemplatesRefs<T extends Object>(
    Expression<T> Function($$WodTemplatesTableAnnotationComposer a) f,
  ) {
    final $$WodTemplatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wodTemplates,
      getReferencedColumn: (t) => t.phaseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WodTemplatesTableAnnotationComposer(
            $db: $db,
            $table: $db.wodTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProgramPhasesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProgramPhasesTable,
          ProgramPhase,
          $$ProgramPhasesTableFilterComposer,
          $$ProgramPhasesTableOrderingComposer,
          $$ProgramPhasesTableAnnotationComposer,
          $$ProgramPhasesTableCreateCompanionBuilder,
          $$ProgramPhasesTableUpdateCompanionBuilder,
          (ProgramPhase, $$ProgramPhasesTableReferences),
          ProgramPhase,
          PrefetchHooks Function({bool programId, bool wodTemplatesRefs})
        > {
  $$ProgramPhasesTableTableManager(_$AppDatabase db, $ProgramPhasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProgramPhasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProgramPhasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProgramPhasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> programId = const Value.absent(),
                Value<int> phaseNumber = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> durationWeeks = const Value.absent(),
              }) => ProgramPhasesCompanion(
                id: id,
                programId: programId,
                phaseNumber: phaseNumber,
                name: name,
                durationWeeks: durationWeeks,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int programId,
                required int phaseNumber,
                required String name,
                required int durationWeeks,
              }) => ProgramPhasesCompanion.insert(
                id: id,
                programId: programId,
                phaseNumber: phaseNumber,
                name: name,
                durationWeeks: durationWeeks,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProgramPhasesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({programId = false, wodTemplatesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (wodTemplatesRefs) db.wodTemplates,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (programId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.programId,
                                    referencedTable:
                                        $$ProgramPhasesTableReferences
                                            ._programIdTable(db),
                                    referencedColumn:
                                        $$ProgramPhasesTableReferences
                                            ._programIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (wodTemplatesRefs)
                        await $_getPrefetchedData<
                          ProgramPhase,
                          $ProgramPhasesTable,
                          WodTemplate
                        >(
                          currentTable: table,
                          referencedTable: $$ProgramPhasesTableReferences
                              ._wodTemplatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProgramPhasesTableReferences(
                                db,
                                table,
                                p0,
                              ).wodTemplatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.phaseId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProgramPhasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProgramPhasesTable,
      ProgramPhase,
      $$ProgramPhasesTableFilterComposer,
      $$ProgramPhasesTableOrderingComposer,
      $$ProgramPhasesTableAnnotationComposer,
      $$ProgramPhasesTableCreateCompanionBuilder,
      $$ProgramPhasesTableUpdateCompanionBuilder,
      (ProgramPhase, $$ProgramPhasesTableReferences),
      ProgramPhase,
      PrefetchHooks Function({bool programId, bool wodTemplatesRefs})
    >;
typedef $$WodTemplatesTableCreateCompanionBuilder =
    WodTemplatesCompanion Function({
      Value<int> id,
      required int phaseId,
      required int wodNumber,
      required String name,
      Value<String?> notes,
      Value<int> restSeconds,
    });
typedef $$WodTemplatesTableUpdateCompanionBuilder =
    WodTemplatesCompanion Function({
      Value<int> id,
      Value<int> phaseId,
      Value<int> wodNumber,
      Value<String> name,
      Value<String?> notes,
      Value<int> restSeconds,
    });

final class $$WodTemplatesTableReferences
    extends BaseReferences<_$AppDatabase, $WodTemplatesTable, WodTemplate> {
  $$WodTemplatesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ProgramPhasesTable _phaseIdTable(_$AppDatabase db) =>
      db.programPhases.createAlias(
        $_aliasNameGenerator(db.wodTemplates.phaseId, db.programPhases.id),
      );

  $$ProgramPhasesTableProcessedTableManager get phaseId {
    final $_column = $_itemColumn<int>('phase_id')!;

    final manager = $$ProgramPhasesTableTableManager(
      $_db,
      $_db.programPhases,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_phaseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$WorkoutSessionsTable, List<WorkoutSession>>
  _workoutSessionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.workoutSessions,
    aliasName: $_aliasNameGenerator(
      db.wodTemplates.id,
      db.workoutSessions.wodTemplateId,
    ),
  );

  $$WorkoutSessionsTableProcessedTableManager get workoutSessionsRefs {
    final manager = $$WorkoutSessionsTableTableManager(
      $_db,
      $_db.workoutSessions,
    ).filter((f) => f.wodTemplateId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workoutSessionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WodExerciseGroupsTable, List<WodExerciseGroup>>
  _wodExerciseGroupsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.wodExerciseGroups,
        aliasName: $_aliasNameGenerator(
          db.wodTemplates.id,
          db.wodExerciseGroups.wodTemplateId,
        ),
      );

  $$WodExerciseGroupsTableProcessedTableManager get wodExerciseGroupsRefs {
    final manager = $$WodExerciseGroupsTableTableManager(
      $_db,
      $_db.wodExerciseGroups,
    ).filter((f) => f.wodTemplateId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _wodExerciseGroupsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $WodTemplateExercisesTable,
    List<WodTemplateExercise>
  >
  _wodTemplateExercisesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.wodTemplateExercises,
        aliasName: $_aliasNameGenerator(
          db.wodTemplates.id,
          db.wodTemplateExercises.wodTemplateId,
        ),
      );

  $$WodTemplateExercisesTableProcessedTableManager
  get wodTemplateExercisesRefs {
    final manager = $$WodTemplateExercisesTableTableManager(
      $_db,
      $_db.wodTemplateExercises,
    ).filter((f) => f.wodTemplateId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _wodTemplateExercisesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WodTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $WodTemplatesTable> {
  $$WodTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wodNumber => $composableBuilder(
    column: $table.wodNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnFilters(column),
  );

  $$ProgramPhasesTableFilterComposer get phaseId {
    final $$ProgramPhasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.phaseId,
      referencedTable: $db.programPhases,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramPhasesTableFilterComposer(
            $db: $db,
            $table: $db.programPhases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> workoutSessionsRefs(
    Expression<bool> Function($$WorkoutSessionsTableFilterComposer f) f,
  ) {
    final $$WorkoutSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutSessions,
      getReferencedColumn: (t) => t.wodTemplateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSessionsTableFilterComposer(
            $db: $db,
            $table: $db.workoutSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> wodExerciseGroupsRefs(
    Expression<bool> Function($$WodExerciseGroupsTableFilterComposer f) f,
  ) {
    final $$WodExerciseGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wodExerciseGroups,
      getReferencedColumn: (t) => t.wodTemplateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WodExerciseGroupsTableFilterComposer(
            $db: $db,
            $table: $db.wodExerciseGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> wodTemplateExercisesRefs(
    Expression<bool> Function($$WodTemplateExercisesTableFilterComposer f) f,
  ) {
    final $$WodTemplateExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wodTemplateExercises,
      getReferencedColumn: (t) => t.wodTemplateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WodTemplateExercisesTableFilterComposer(
            $db: $db,
            $table: $db.wodTemplateExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WodTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $WodTemplatesTable> {
  $$WodTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wodNumber => $composableBuilder(
    column: $table.wodNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProgramPhasesTableOrderingComposer get phaseId {
    final $$ProgramPhasesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.phaseId,
      referencedTable: $db.programPhases,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramPhasesTableOrderingComposer(
            $db: $db,
            $table: $db.programPhases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WodTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WodTemplatesTable> {
  $$WodTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get wodNumber =>
      $composableBuilder(column: $table.wodNumber, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => column,
  );

  $$ProgramPhasesTableAnnotationComposer get phaseId {
    final $$ProgramPhasesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.phaseId,
      referencedTable: $db.programPhases,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProgramPhasesTableAnnotationComposer(
            $db: $db,
            $table: $db.programPhases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> workoutSessionsRefs<T extends Object>(
    Expression<T> Function($$WorkoutSessionsTableAnnotationComposer a) f,
  ) {
    final $$WorkoutSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutSessions,
      getReferencedColumn: (t) => t.wodTemplateId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> wodExerciseGroupsRefs<T extends Object>(
    Expression<T> Function($$WodExerciseGroupsTableAnnotationComposer a) f,
  ) {
    final $$WodExerciseGroupsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.wodExerciseGroups,
          getReferencedColumn: (t) => t.wodTemplateId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WodExerciseGroupsTableAnnotationComposer(
                $db: $db,
                $table: $db.wodExerciseGroups,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> wodTemplateExercisesRefs<T extends Object>(
    Expression<T> Function($$WodTemplateExercisesTableAnnotationComposer a) f,
  ) {
    final $$WodTemplateExercisesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.wodTemplateExercises,
          getReferencedColumn: (t) => t.wodTemplateId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WodTemplateExercisesTableAnnotationComposer(
                $db: $db,
                $table: $db.wodTemplateExercises,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$WodTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WodTemplatesTable,
          WodTemplate,
          $$WodTemplatesTableFilterComposer,
          $$WodTemplatesTableOrderingComposer,
          $$WodTemplatesTableAnnotationComposer,
          $$WodTemplatesTableCreateCompanionBuilder,
          $$WodTemplatesTableUpdateCompanionBuilder,
          (WodTemplate, $$WodTemplatesTableReferences),
          WodTemplate,
          PrefetchHooks Function({
            bool phaseId,
            bool workoutSessionsRefs,
            bool wodExerciseGroupsRefs,
            bool wodTemplateExercisesRefs,
          })
        > {
  $$WodTemplatesTableTableManager(_$AppDatabase db, $WodTemplatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WodTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WodTemplatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WodTemplatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> phaseId = const Value.absent(),
                Value<int> wodNumber = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> restSeconds = const Value.absent(),
              }) => WodTemplatesCompanion(
                id: id,
                phaseId: phaseId,
                wodNumber: wodNumber,
                name: name,
                notes: notes,
                restSeconds: restSeconds,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int phaseId,
                required int wodNumber,
                required String name,
                Value<String?> notes = const Value.absent(),
                Value<int> restSeconds = const Value.absent(),
              }) => WodTemplatesCompanion.insert(
                id: id,
                phaseId: phaseId,
                wodNumber: wodNumber,
                name: name,
                notes: notes,
                restSeconds: restSeconds,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WodTemplatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                phaseId = false,
                workoutSessionsRefs = false,
                wodExerciseGroupsRefs = false,
                wodTemplateExercisesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (workoutSessionsRefs) db.workoutSessions,
                    if (wodExerciseGroupsRefs) db.wodExerciseGroups,
                    if (wodTemplateExercisesRefs) db.wodTemplateExercises,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (phaseId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.phaseId,
                                    referencedTable:
                                        $$WodTemplatesTableReferences
                                            ._phaseIdTable(db),
                                    referencedColumn:
                                        $$WodTemplatesTableReferences
                                            ._phaseIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (workoutSessionsRefs)
                        await $_getPrefetchedData<
                          WodTemplate,
                          $WodTemplatesTable,
                          WorkoutSession
                        >(
                          currentTable: table,
                          referencedTable: $$WodTemplatesTableReferences
                              ._workoutSessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WodTemplatesTableReferences(
                                db,
                                table,
                                p0,
                              ).workoutSessionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.wodTemplateId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (wodExerciseGroupsRefs)
                        await $_getPrefetchedData<
                          WodTemplate,
                          $WodTemplatesTable,
                          WodExerciseGroup
                        >(
                          currentTable: table,
                          referencedTable: $$WodTemplatesTableReferences
                              ._wodExerciseGroupsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WodTemplatesTableReferences(
                                db,
                                table,
                                p0,
                              ).wodExerciseGroupsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.wodTemplateId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (wodTemplateExercisesRefs)
                        await $_getPrefetchedData<
                          WodTemplate,
                          $WodTemplatesTable,
                          WodTemplateExercise
                        >(
                          currentTable: table,
                          referencedTable: $$WodTemplatesTableReferences
                              ._wodTemplateExercisesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WodTemplatesTableReferences(
                                db,
                                table,
                                p0,
                              ).wodTemplateExercisesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.wodTemplateId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$WodTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WodTemplatesTable,
      WodTemplate,
      $$WodTemplatesTableFilterComposer,
      $$WodTemplatesTableOrderingComposer,
      $$WodTemplatesTableAnnotationComposer,
      $$WodTemplatesTableCreateCompanionBuilder,
      $$WodTemplatesTableUpdateCompanionBuilder,
      (WodTemplate, $$WodTemplatesTableReferences),
      WodTemplate,
      PrefetchHooks Function({
        bool phaseId,
        bool workoutSessionsRefs,
        bool wodExerciseGroupsRefs,
        bool wodTemplateExercisesRefs,
      })
    >;
typedef $$WorkoutSessionsTableCreateCompanionBuilder =
    WorkoutSessionsCompanion Function({
      Value<int> id,
      required DateTime date,
      required String workoutName,
      Value<int?> wodTemplateId,
      Value<int?> weekNumber,
      Value<String?> notes,
    });
typedef $$WorkoutSessionsTableUpdateCompanionBuilder =
    WorkoutSessionsCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<String> workoutName,
      Value<int?> wodTemplateId,
      Value<int?> weekNumber,
      Value<String?> notes,
    });

final class $$WorkoutSessionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $WorkoutSessionsTable, WorkoutSession> {
  $$WorkoutSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WodTemplatesTable _wodTemplateIdTable(_$AppDatabase db) =>
      db.wodTemplates.createAlias(
        $_aliasNameGenerator(
          db.workoutSessions.wodTemplateId,
          db.wodTemplates.id,
        ),
      );

  $$WodTemplatesTableProcessedTableManager? get wodTemplateId {
    final $_column = $_itemColumn<int>('wod_template_id');
    if ($_column == null) return null;
    final manager = $$WodTemplatesTableTableManager(
      $_db,
      $_db.wodTemplates,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_wodTemplateIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$WorkoutSetsTable, List<WorkoutSet>>
  _workoutSetsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.workoutSets,
    aliasName: $_aliasNameGenerator(
      db.workoutSessions.id,
      db.workoutSets.sessionId,
    ),
  );

  $$WorkoutSetsTableProcessedTableManager get workoutSetsRefs {
    final manager = $$WorkoutSetsTableTableManager(
      $_db,
      $_db.workoutSets,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_workoutSetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkoutSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workoutName => $composableBuilder(
    column: $table.workoutName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekNumber => $composableBuilder(
    column: $table.weekNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$WodTemplatesTableFilterComposer get wodTemplateId {
    final $$WodTemplatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wodTemplateId,
      referencedTable: $db.wodTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WodTemplatesTableFilterComposer(
            $db: $db,
            $table: $db.wodTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> workoutSetsRefs(
    Expression<bool> Function($$WorkoutSetsTableFilterComposer f) f,
  ) {
    final $$WorkoutSetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableFilterComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkoutSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workoutName => $composableBuilder(
    column: $table.workoutName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekNumber => $composableBuilder(
    column: $table.weekNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$WodTemplatesTableOrderingComposer get wodTemplateId {
    final $$WodTemplatesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wodTemplateId,
      referencedTable: $db.wodTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WodTemplatesTableOrderingComposer(
            $db: $db,
            $table: $db.wodTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutSessionsTable> {
  $$WorkoutSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get workoutName => $composableBuilder(
    column: $table.workoutName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get weekNumber => $composableBuilder(
    column: $table.weekNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$WodTemplatesTableAnnotationComposer get wodTemplateId {
    final $$WodTemplatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wodTemplateId,
      referencedTable: $db.wodTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WodTemplatesTableAnnotationComposer(
            $db: $db,
            $table: $db.wodTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> workoutSetsRefs<T extends Object>(
    Expression<T> Function($$WorkoutSetsTableAnnotationComposer a) f,
  ) {
    final $$WorkoutSetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutSets,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetsTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutSets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WorkoutSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutSessionsTable,
          WorkoutSession,
          $$WorkoutSessionsTableFilterComposer,
          $$WorkoutSessionsTableOrderingComposer,
          $$WorkoutSessionsTableAnnotationComposer,
          $$WorkoutSessionsTableCreateCompanionBuilder,
          $$WorkoutSessionsTableUpdateCompanionBuilder,
          (WorkoutSession, $$WorkoutSessionsTableReferences),
          WorkoutSession,
          PrefetchHooks Function({bool wodTemplateId, bool workoutSetsRefs})
        > {
  $$WorkoutSessionsTableTableManager(
    _$AppDatabase db,
    $WorkoutSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> workoutName = const Value.absent(),
                Value<int?> wodTemplateId = const Value.absent(),
                Value<int?> weekNumber = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => WorkoutSessionsCompanion(
                id: id,
                date: date,
                workoutName: workoutName,
                wodTemplateId: wodTemplateId,
                weekNumber: weekNumber,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required String workoutName,
                Value<int?> wodTemplateId = const Value.absent(),
                Value<int?> weekNumber = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => WorkoutSessionsCompanion.insert(
                id: id,
                date: date,
                workoutName: workoutName,
                wodTemplateId: wodTemplateId,
                weekNumber: weekNumber,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkoutSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({wodTemplateId = false, workoutSetsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (workoutSetsRefs) db.workoutSets,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (wodTemplateId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.wodTemplateId,
                                    referencedTable:
                                        $$WorkoutSessionsTableReferences
                                            ._wodTemplateIdTable(db),
                                    referencedColumn:
                                        $$WorkoutSessionsTableReferences
                                            ._wodTemplateIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (workoutSetsRefs)
                        await $_getPrefetchedData<
                          WorkoutSession,
                          $WorkoutSessionsTable,
                          WorkoutSet
                        >(
                          currentTable: table,
                          referencedTable: $$WorkoutSessionsTableReferences
                              ._workoutSetsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WorkoutSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).workoutSetsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$WorkoutSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutSessionsTable,
      WorkoutSession,
      $$WorkoutSessionsTableFilterComposer,
      $$WorkoutSessionsTableOrderingComposer,
      $$WorkoutSessionsTableAnnotationComposer,
      $$WorkoutSessionsTableCreateCompanionBuilder,
      $$WorkoutSessionsTableUpdateCompanionBuilder,
      (WorkoutSession, $$WorkoutSessionsTableReferences),
      WorkoutSession,
      PrefetchHooks Function({bool wodTemplateId, bool workoutSetsRefs})
    >;
typedef $$WorkoutSetsTableCreateCompanionBuilder =
    WorkoutSetsCompanion Function({
      Value<int> id,
      required int sessionId,
      required int exerciseId,
      required int setNumber,
      required int reps,
      required double weightKg,
      Value<int?> durationSeconds,
      Value<double?> rpe,
      Value<String?> notes,
    });
typedef $$WorkoutSetsTableUpdateCompanionBuilder =
    WorkoutSetsCompanion Function({
      Value<int> id,
      Value<int> sessionId,
      Value<int> exerciseId,
      Value<int> setNumber,
      Value<int> reps,
      Value<double> weightKg,
      Value<int?> durationSeconds,
      Value<double?> rpe,
      Value<String?> notes,
    });

final class $$WorkoutSetsTableReferences
    extends BaseReferences<_$AppDatabase, $WorkoutSetsTable, WorkoutSet> {
  $$WorkoutSetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $WorkoutSessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.workoutSessions.createAlias(
        $_aliasNameGenerator(db.workoutSets.sessionId, db.workoutSessions.id),
      );

  $$WorkoutSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<int>('session_id')!;

    final manager = $$WorkoutSessionsTableTableManager(
      $_db,
      $_db.workoutSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ExercisesTable _exerciseIdTable(_$AppDatabase db) =>
      db.exercises.createAlias(
        $_aliasNameGenerator(db.workoutSets.exerciseId, db.exercises.id),
      );

  $$ExercisesTableProcessedTableManager get exerciseId {
    final $_column = $_itemColumn<int>('exercise_id')!;

    final manager = $$ExercisesTableTableManager(
      $_db,
      $_db.exercises,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_exerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WorkoutSetsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutSetsTable> {
  $$WorkoutSetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get setNumber => $composableBuilder(
    column: $table.setNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rpe => $composableBuilder(
    column: $table.rpe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkoutSessionsTableFilterComposer get sessionId {
    final $$WorkoutSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.workoutSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSessionsTableFilterComposer(
            $db: $db,
            $table: $db.workoutSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableFilterComposer get exerciseId {
    final $$ExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableFilterComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutSetsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutSetsTable> {
  $$WorkoutSetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get setNumber => $composableBuilder(
    column: $table.setNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rpe => $composableBuilder(
    column: $table.rpe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkoutSessionsTableOrderingComposer get sessionId {
    final $$WorkoutSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.workoutSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.workoutSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableOrderingComposer get exerciseId {
    final $$ExercisesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableOrderingComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutSetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutSetsTable> {
  $$WorkoutSetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get setNumber =>
      $composableBuilder(column: $table.setNumber, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get rpe =>
      $composableBuilder(column: $table.rpe, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$WorkoutSessionsTableAnnotationComposer get sessionId {
    final $$WorkoutSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.workoutSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableAnnotationComposer get exerciseId {
    final $$ExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutSetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutSetsTable,
          WorkoutSet,
          $$WorkoutSetsTableFilterComposer,
          $$WorkoutSetsTableOrderingComposer,
          $$WorkoutSetsTableAnnotationComposer,
          $$WorkoutSetsTableCreateCompanionBuilder,
          $$WorkoutSetsTableUpdateCompanionBuilder,
          (WorkoutSet, $$WorkoutSetsTableReferences),
          WorkoutSet,
          PrefetchHooks Function({bool sessionId, bool exerciseId})
        > {
  $$WorkoutSetsTableTableManager(_$AppDatabase db, $WorkoutSetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sessionId = const Value.absent(),
                Value<int> exerciseId = const Value.absent(),
                Value<int> setNumber = const Value.absent(),
                Value<int> reps = const Value.absent(),
                Value<double> weightKg = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<double?> rpe = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => WorkoutSetsCompanion(
                id: id,
                sessionId: sessionId,
                exerciseId: exerciseId,
                setNumber: setNumber,
                reps: reps,
                weightKg: weightKg,
                durationSeconds: durationSeconds,
                rpe: rpe,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionId,
                required int exerciseId,
                required int setNumber,
                required int reps,
                required double weightKg,
                Value<int?> durationSeconds = const Value.absent(),
                Value<double?> rpe = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => WorkoutSetsCompanion.insert(
                id: id,
                sessionId: sessionId,
                exerciseId: exerciseId,
                setNumber: setNumber,
                reps: reps,
                weightKg: weightKg,
                durationSeconds: durationSeconds,
                rpe: rpe,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkoutSetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false, exerciseId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$WorkoutSetsTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$WorkoutSetsTableReferences
                                    ._sessionIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (exerciseId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.exerciseId,
                                referencedTable: $$WorkoutSetsTableReferences
                                    ._exerciseIdTable(db),
                                referencedColumn: $$WorkoutSetsTableReferences
                                    ._exerciseIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WorkoutSetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutSetsTable,
      WorkoutSet,
      $$WorkoutSetsTableFilterComposer,
      $$WorkoutSetsTableOrderingComposer,
      $$WorkoutSetsTableAnnotationComposer,
      $$WorkoutSetsTableCreateCompanionBuilder,
      $$WorkoutSetsTableUpdateCompanionBuilder,
      (WorkoutSet, $$WorkoutSetsTableReferences),
      WorkoutSet,
      PrefetchHooks Function({bool sessionId, bool exerciseId})
    >;
typedef $$BodyweightEntriesTableCreateCompanionBuilder =
    BodyweightEntriesCompanion Function({
      Value<int> id,
      required DateTime date,
      required double weightKg,
      Value<String?> notes,
    });
typedef $$BodyweightEntriesTableUpdateCompanionBuilder =
    BodyweightEntriesCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<double> weightKg,
      Value<String?> notes,
    });

class $$BodyweightEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $BodyweightEntriesTable> {
  $$BodyweightEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BodyweightEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $BodyweightEntriesTable> {
  $$BodyweightEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BodyweightEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BodyweightEntriesTable> {
  $$BodyweightEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$BodyweightEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BodyweightEntriesTable,
          BodyweightEntry,
          $$BodyweightEntriesTableFilterComposer,
          $$BodyweightEntriesTableOrderingComposer,
          $$BodyweightEntriesTableAnnotationComposer,
          $$BodyweightEntriesTableCreateCompanionBuilder,
          $$BodyweightEntriesTableUpdateCompanionBuilder,
          (
            BodyweightEntry,
            BaseReferences<
              _$AppDatabase,
              $BodyweightEntriesTable,
              BodyweightEntry
            >,
          ),
          BodyweightEntry,
          PrefetchHooks Function()
        > {
  $$BodyweightEntriesTableTableManager(
    _$AppDatabase db,
    $BodyweightEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BodyweightEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BodyweightEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BodyweightEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double> weightKg = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => BodyweightEntriesCompanion(
                id: id,
                date: date,
                weightKg: weightKg,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required double weightKg,
                Value<String?> notes = const Value.absent(),
              }) => BodyweightEntriesCompanion.insert(
                id: id,
                date: date,
                weightKg: weightKg,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BodyweightEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BodyweightEntriesTable,
      BodyweightEntry,
      $$BodyweightEntriesTableFilterComposer,
      $$BodyweightEntriesTableOrderingComposer,
      $$BodyweightEntriesTableAnnotationComposer,
      $$BodyweightEntriesTableCreateCompanionBuilder,
      $$BodyweightEntriesTableUpdateCompanionBuilder,
      (
        BodyweightEntry,
        BaseReferences<_$AppDatabase, $BodyweightEntriesTable, BodyweightEntry>,
      ),
      BodyweightEntry,
      PrefetchHooks Function()
    >;
typedef $$WodExerciseGroupsTableCreateCompanionBuilder =
    WodExerciseGroupsCompanion Function({
      Value<int> id,
      required int wodTemplateId,
      required int sortOrder,
      Value<String?> name,
      Value<int> rounds,
      Value<int> restBetweenExercisesSeconds,
      Value<int> restBetweenRoundsSeconds,
    });
typedef $$WodExerciseGroupsTableUpdateCompanionBuilder =
    WodExerciseGroupsCompanion Function({
      Value<int> id,
      Value<int> wodTemplateId,
      Value<int> sortOrder,
      Value<String?> name,
      Value<int> rounds,
      Value<int> restBetweenExercisesSeconds,
      Value<int> restBetweenRoundsSeconds,
    });

final class $$WodExerciseGroupsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $WodExerciseGroupsTable,
          WodExerciseGroup
        > {
  $$WodExerciseGroupsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WodTemplatesTable _wodTemplateIdTable(_$AppDatabase db) =>
      db.wodTemplates.createAlias(
        $_aliasNameGenerator(
          db.wodExerciseGroups.wodTemplateId,
          db.wodTemplates.id,
        ),
      );

  $$WodTemplatesTableProcessedTableManager get wodTemplateId {
    final $_column = $_itemColumn<int>('wod_template_id')!;

    final manager = $$WodTemplatesTableTableManager(
      $_db,
      $_db.wodTemplates,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_wodTemplateIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $WodTemplateExercisesTable,
    List<WodTemplateExercise>
  >
  _wodTemplateExercisesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.wodTemplateExercises,
        aliasName: $_aliasNameGenerator(
          db.wodExerciseGroups.id,
          db.wodTemplateExercises.groupId,
        ),
      );

  $$WodTemplateExercisesTableProcessedTableManager
  get wodTemplateExercisesRefs {
    final manager = $$WodTemplateExercisesTableTableManager(
      $_db,
      $_db.wodTemplateExercises,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _wodTemplateExercisesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WodExerciseGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $WodExerciseGroupsTable> {
  $$WodExerciseGroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rounds => $composableBuilder(
    column: $table.rounds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restBetweenExercisesSeconds => $composableBuilder(
    column: $table.restBetweenExercisesSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restBetweenRoundsSeconds => $composableBuilder(
    column: $table.restBetweenRoundsSeconds,
    builder: (column) => ColumnFilters(column),
  );

  $$WodTemplatesTableFilterComposer get wodTemplateId {
    final $$WodTemplatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wodTemplateId,
      referencedTable: $db.wodTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WodTemplatesTableFilterComposer(
            $db: $db,
            $table: $db.wodTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> wodTemplateExercisesRefs(
    Expression<bool> Function($$WodTemplateExercisesTableFilterComposer f) f,
  ) {
    final $$WodTemplateExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.wodTemplateExercises,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WodTemplateExercisesTableFilterComposer(
            $db: $db,
            $table: $db.wodTemplateExercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WodExerciseGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $WodExerciseGroupsTable> {
  $$WodExerciseGroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rounds => $composableBuilder(
    column: $table.rounds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restBetweenExercisesSeconds => $composableBuilder(
    column: $table.restBetweenExercisesSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restBetweenRoundsSeconds => $composableBuilder(
    column: $table.restBetweenRoundsSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  $$WodTemplatesTableOrderingComposer get wodTemplateId {
    final $$WodTemplatesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wodTemplateId,
      referencedTable: $db.wodTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WodTemplatesTableOrderingComposer(
            $db: $db,
            $table: $db.wodTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WodExerciseGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WodExerciseGroupsTable> {
  $$WodExerciseGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get rounds =>
      $composableBuilder(column: $table.rounds, builder: (column) => column);

  GeneratedColumn<int> get restBetweenExercisesSeconds => $composableBuilder(
    column: $table.restBetweenExercisesSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get restBetweenRoundsSeconds => $composableBuilder(
    column: $table.restBetweenRoundsSeconds,
    builder: (column) => column,
  );

  $$WodTemplatesTableAnnotationComposer get wodTemplateId {
    final $$WodTemplatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wodTemplateId,
      referencedTable: $db.wodTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WodTemplatesTableAnnotationComposer(
            $db: $db,
            $table: $db.wodTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> wodTemplateExercisesRefs<T extends Object>(
    Expression<T> Function($$WodTemplateExercisesTableAnnotationComposer a) f,
  ) {
    final $$WodTemplateExercisesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.wodTemplateExercises,
          getReferencedColumn: (t) => t.groupId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WodTemplateExercisesTableAnnotationComposer(
                $db: $db,
                $table: $db.wodTemplateExercises,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$WodExerciseGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WodExerciseGroupsTable,
          WodExerciseGroup,
          $$WodExerciseGroupsTableFilterComposer,
          $$WodExerciseGroupsTableOrderingComposer,
          $$WodExerciseGroupsTableAnnotationComposer,
          $$WodExerciseGroupsTableCreateCompanionBuilder,
          $$WodExerciseGroupsTableUpdateCompanionBuilder,
          (WodExerciseGroup, $$WodExerciseGroupsTableReferences),
          WodExerciseGroup,
          PrefetchHooks Function({
            bool wodTemplateId,
            bool wodTemplateExercisesRefs,
          })
        > {
  $$WodExerciseGroupsTableTableManager(
    _$AppDatabase db,
    $WodExerciseGroupsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WodExerciseGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WodExerciseGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WodExerciseGroupsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> wodTemplateId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<int> rounds = const Value.absent(),
                Value<int> restBetweenExercisesSeconds = const Value.absent(),
                Value<int> restBetweenRoundsSeconds = const Value.absent(),
              }) => WodExerciseGroupsCompanion(
                id: id,
                wodTemplateId: wodTemplateId,
                sortOrder: sortOrder,
                name: name,
                rounds: rounds,
                restBetweenExercisesSeconds: restBetweenExercisesSeconds,
                restBetweenRoundsSeconds: restBetweenRoundsSeconds,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int wodTemplateId,
                required int sortOrder,
                Value<String?> name = const Value.absent(),
                Value<int> rounds = const Value.absent(),
                Value<int> restBetweenExercisesSeconds = const Value.absent(),
                Value<int> restBetweenRoundsSeconds = const Value.absent(),
              }) => WodExerciseGroupsCompanion.insert(
                id: id,
                wodTemplateId: wodTemplateId,
                sortOrder: sortOrder,
                name: name,
                rounds: rounds,
                restBetweenExercisesSeconds: restBetweenExercisesSeconds,
                restBetweenRoundsSeconds: restBetweenRoundsSeconds,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WodExerciseGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({wodTemplateId = false, wodTemplateExercisesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (wodTemplateExercisesRefs) db.wodTemplateExercises,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (wodTemplateId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.wodTemplateId,
                                    referencedTable:
                                        $$WodExerciseGroupsTableReferences
                                            ._wodTemplateIdTable(db),
                                    referencedColumn:
                                        $$WodExerciseGroupsTableReferences
                                            ._wodTemplateIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (wodTemplateExercisesRefs)
                        await $_getPrefetchedData<
                          WodExerciseGroup,
                          $WodExerciseGroupsTable,
                          WodTemplateExercise
                        >(
                          currentTable: table,
                          referencedTable: $$WodExerciseGroupsTableReferences
                              ._wodTemplateExercisesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$WodExerciseGroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).wodTemplateExercisesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$WodExerciseGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WodExerciseGroupsTable,
      WodExerciseGroup,
      $$WodExerciseGroupsTableFilterComposer,
      $$WodExerciseGroupsTableOrderingComposer,
      $$WodExerciseGroupsTableAnnotationComposer,
      $$WodExerciseGroupsTableCreateCompanionBuilder,
      $$WodExerciseGroupsTableUpdateCompanionBuilder,
      (WodExerciseGroup, $$WodExerciseGroupsTableReferences),
      WodExerciseGroup,
      PrefetchHooks Function({
        bool wodTemplateId,
        bool wodTemplateExercisesRefs,
      })
    >;
typedef $$WodTemplateExercisesTableCreateCompanionBuilder =
    WodTemplateExercisesCompanion Function({
      Value<int> id,
      required int wodTemplateId,
      required int exerciseId,
      required int sortOrder,
      Value<int?> groupId,
      Value<int> targetSets,
      Value<int> repRangeMin,
      Value<int> repRangeMax,
      Value<String?> notes,
      Value<int?> restSeconds,
      Value<int?> restBetweenSetsSeconds,
      Value<double?> targetRpe,
      Value<String?> videoUrl,
    });
typedef $$WodTemplateExercisesTableUpdateCompanionBuilder =
    WodTemplateExercisesCompanion Function({
      Value<int> id,
      Value<int> wodTemplateId,
      Value<int> exerciseId,
      Value<int> sortOrder,
      Value<int?> groupId,
      Value<int> targetSets,
      Value<int> repRangeMin,
      Value<int> repRangeMax,
      Value<String?> notes,
      Value<int?> restSeconds,
      Value<int?> restBetweenSetsSeconds,
      Value<double?> targetRpe,
      Value<String?> videoUrl,
    });

final class $$WodTemplateExercisesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $WodTemplateExercisesTable,
          WodTemplateExercise
        > {
  $$WodTemplateExercisesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WodTemplatesTable _wodTemplateIdTable(_$AppDatabase db) =>
      db.wodTemplates.createAlias(
        $_aliasNameGenerator(
          db.wodTemplateExercises.wodTemplateId,
          db.wodTemplates.id,
        ),
      );

  $$WodTemplatesTableProcessedTableManager get wodTemplateId {
    final $_column = $_itemColumn<int>('wod_template_id')!;

    final manager = $$WodTemplatesTableTableManager(
      $_db,
      $_db.wodTemplates,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_wodTemplateIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ExercisesTable _exerciseIdTable(_$AppDatabase db) =>
      db.exercises.createAlias(
        $_aliasNameGenerator(
          db.wodTemplateExercises.exerciseId,
          db.exercises.id,
        ),
      );

  $$ExercisesTableProcessedTableManager get exerciseId {
    final $_column = $_itemColumn<int>('exercise_id')!;

    final manager = $$ExercisesTableTableManager(
      $_db,
      $_db.exercises,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_exerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WodExerciseGroupsTable _groupIdTable(_$AppDatabase db) =>
      db.wodExerciseGroups.createAlias(
        $_aliasNameGenerator(
          db.wodTemplateExercises.groupId,
          db.wodExerciseGroups.id,
        ),
      );

  $$WodExerciseGroupsTableProcessedTableManager? get groupId {
    final $_column = $_itemColumn<int>('group_id');
    if ($_column == null) return null;
    final manager = $$WodExerciseGroupsTableTableManager(
      $_db,
      $_db.wodExerciseGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WodTemplateExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $WodTemplateExercisesTable> {
  $$WodTemplateExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetSets => $composableBuilder(
    column: $table.targetSets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repRangeMin => $composableBuilder(
    column: $table.repRangeMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repRangeMax => $composableBuilder(
    column: $table.repRangeMax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get restBetweenSetsSeconds => $composableBuilder(
    column: $table.restBetweenSetsSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetRpe => $composableBuilder(
    column: $table.targetRpe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoUrl => $composableBuilder(
    column: $table.videoUrl,
    builder: (column) => ColumnFilters(column),
  );

  $$WodTemplatesTableFilterComposer get wodTemplateId {
    final $$WodTemplatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wodTemplateId,
      referencedTable: $db.wodTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WodTemplatesTableFilterComposer(
            $db: $db,
            $table: $db.wodTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableFilterComposer get exerciseId {
    final $$ExercisesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableFilterComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WodExerciseGroupsTableFilterComposer get groupId {
    final $$WodExerciseGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.wodExerciseGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WodExerciseGroupsTableFilterComposer(
            $db: $db,
            $table: $db.wodExerciseGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WodTemplateExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $WodTemplateExercisesTable> {
  $$WodTemplateExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetSets => $composableBuilder(
    column: $table.targetSets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repRangeMin => $composableBuilder(
    column: $table.repRangeMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repRangeMax => $composableBuilder(
    column: $table.repRangeMax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get restBetweenSetsSeconds => $composableBuilder(
    column: $table.restBetweenSetsSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetRpe => $composableBuilder(
    column: $table.targetRpe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoUrl => $composableBuilder(
    column: $table.videoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  $$WodTemplatesTableOrderingComposer get wodTemplateId {
    final $$WodTemplatesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wodTemplateId,
      referencedTable: $db.wodTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WodTemplatesTableOrderingComposer(
            $db: $db,
            $table: $db.wodTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableOrderingComposer get exerciseId {
    final $$ExercisesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableOrderingComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WodExerciseGroupsTableOrderingComposer get groupId {
    final $$WodExerciseGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.wodExerciseGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WodExerciseGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.wodExerciseGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WodTemplateExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WodTemplateExercisesTable> {
  $$WodTemplateExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get targetSets => $composableBuilder(
    column: $table.targetSets,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repRangeMin => $composableBuilder(
    column: $table.repRangeMin,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repRangeMax => $composableBuilder(
    column: $table.repRangeMax,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get restSeconds => $composableBuilder(
    column: $table.restSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get restBetweenSetsSeconds => $composableBuilder(
    column: $table.restBetweenSetsSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get targetRpe =>
      $composableBuilder(column: $table.targetRpe, builder: (column) => column);

  GeneratedColumn<String> get videoUrl =>
      $composableBuilder(column: $table.videoUrl, builder: (column) => column);

  $$WodTemplatesTableAnnotationComposer get wodTemplateId {
    final $$WodTemplatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.wodTemplateId,
      referencedTable: $db.wodTemplates,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WodTemplatesTableAnnotationComposer(
            $db: $db,
            $table: $db.wodTemplates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExercisesTableAnnotationComposer get exerciseId {
    final $$ExercisesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exercises,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExercisesTableAnnotationComposer(
            $db: $db,
            $table: $db.exercises,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WodExerciseGroupsTableAnnotationComposer get groupId {
    final $$WodExerciseGroupsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.groupId,
          referencedTable: $db.wodExerciseGroups,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WodExerciseGroupsTableAnnotationComposer(
                $db: $db,
                $table: $db.wodExerciseGroups,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$WodTemplateExercisesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WodTemplateExercisesTable,
          WodTemplateExercise,
          $$WodTemplateExercisesTableFilterComposer,
          $$WodTemplateExercisesTableOrderingComposer,
          $$WodTemplateExercisesTableAnnotationComposer,
          $$WodTemplateExercisesTableCreateCompanionBuilder,
          $$WodTemplateExercisesTableUpdateCompanionBuilder,
          (WodTemplateExercise, $$WodTemplateExercisesTableReferences),
          WodTemplateExercise,
          PrefetchHooks Function({
            bool wodTemplateId,
            bool exerciseId,
            bool groupId,
          })
        > {
  $$WodTemplateExercisesTableTableManager(
    _$AppDatabase db,
    $WodTemplateExercisesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WodTemplateExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WodTemplateExercisesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$WodTemplateExercisesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> wodTemplateId = const Value.absent(),
                Value<int> exerciseId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int?> groupId = const Value.absent(),
                Value<int> targetSets = const Value.absent(),
                Value<int> repRangeMin = const Value.absent(),
                Value<int> repRangeMax = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int?> restSeconds = const Value.absent(),
                Value<int?> restBetweenSetsSeconds = const Value.absent(),
                Value<double?> targetRpe = const Value.absent(),
                Value<String?> videoUrl = const Value.absent(),
              }) => WodTemplateExercisesCompanion(
                id: id,
                wodTemplateId: wodTemplateId,
                exerciseId: exerciseId,
                sortOrder: sortOrder,
                groupId: groupId,
                targetSets: targetSets,
                repRangeMin: repRangeMin,
                repRangeMax: repRangeMax,
                notes: notes,
                restSeconds: restSeconds,
                restBetweenSetsSeconds: restBetweenSetsSeconds,
                targetRpe: targetRpe,
                videoUrl: videoUrl,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int wodTemplateId,
                required int exerciseId,
                required int sortOrder,
                Value<int?> groupId = const Value.absent(),
                Value<int> targetSets = const Value.absent(),
                Value<int> repRangeMin = const Value.absent(),
                Value<int> repRangeMax = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int?> restSeconds = const Value.absent(),
                Value<int?> restBetweenSetsSeconds = const Value.absent(),
                Value<double?> targetRpe = const Value.absent(),
                Value<String?> videoUrl = const Value.absent(),
              }) => WodTemplateExercisesCompanion.insert(
                id: id,
                wodTemplateId: wodTemplateId,
                exerciseId: exerciseId,
                sortOrder: sortOrder,
                groupId: groupId,
                targetSets: targetSets,
                repRangeMin: repRangeMin,
                repRangeMax: repRangeMax,
                notes: notes,
                restSeconds: restSeconds,
                restBetweenSetsSeconds: restBetweenSetsSeconds,
                targetRpe: targetRpe,
                videoUrl: videoUrl,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WodTemplateExercisesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({wodTemplateId = false, exerciseId = false, groupId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (wodTemplateId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.wodTemplateId,
                                    referencedTable:
                                        $$WodTemplateExercisesTableReferences
                                            ._wodTemplateIdTable(db),
                                    referencedColumn:
                                        $$WodTemplateExercisesTableReferences
                                            ._wodTemplateIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (exerciseId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.exerciseId,
                                    referencedTable:
                                        $$WodTemplateExercisesTableReferences
                                            ._exerciseIdTable(db),
                                    referencedColumn:
                                        $$WodTemplateExercisesTableReferences
                                            ._exerciseIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (groupId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.groupId,
                                    referencedTable:
                                        $$WodTemplateExercisesTableReferences
                                            ._groupIdTable(db),
                                    referencedColumn:
                                        $$WodTemplateExercisesTableReferences
                                            ._groupIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$WodTemplateExercisesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WodTemplateExercisesTable,
      WodTemplateExercise,
      $$WodTemplateExercisesTableFilterComposer,
      $$WodTemplateExercisesTableOrderingComposer,
      $$WodTemplateExercisesTableAnnotationComposer,
      $$WodTemplateExercisesTableCreateCompanionBuilder,
      $$WodTemplateExercisesTableUpdateCompanionBuilder,
      (WodTemplateExercise, $$WodTemplateExercisesTableReferences),
      WodTemplateExercise,
      PrefetchHooks Function({
        bool wodTemplateId,
        bool exerciseId,
        bool groupId,
      })
    >;
typedef $$DailyTasksTableCreateCompanionBuilder =
    DailyTasksCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> iconName,
      Value<int?> reminderHour,
      Value<int?> reminderMinute,
      Value<bool> isEnabled,
      Value<int> sortOrder,
    });
typedef $$DailyTasksTableUpdateCompanionBuilder =
    DailyTasksCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> iconName,
      Value<int?> reminderHour,
      Value<int?> reminderMinute,
      Value<bool> isEnabled,
      Value<int> sortOrder,
    });

class $$DailyTasksTableFilterComposer
    extends Composer<_$AppDatabase, $DailyTasksTable> {
  $$DailyTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderHour => $composableBuilder(
    column: $table.reminderHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderMinute => $composableBuilder(
    column: $table.reminderMinute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyTasksTable> {
  $$DailyTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderHour => $composableBuilder(
    column: $table.reminderHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderMinute => $composableBuilder(
    column: $table.reminderMinute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyTasksTable> {
  $$DailyTasksTableAnnotationComposer({
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

  GeneratedColumn<String> get iconName =>
      $composableBuilder(column: $table.iconName, builder: (column) => column);

  GeneratedColumn<int> get reminderHour => $composableBuilder(
    column: $table.reminderHour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderMinute => $composableBuilder(
    column: $table.reminderMinute,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$DailyTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyTasksTable,
          DailyTask,
          $$DailyTasksTableFilterComposer,
          $$DailyTasksTableOrderingComposer,
          $$DailyTasksTableAnnotationComposer,
          $$DailyTasksTableCreateCompanionBuilder,
          $$DailyTasksTableUpdateCompanionBuilder,
          (
            DailyTask,
            BaseReferences<_$AppDatabase, $DailyTasksTable, DailyTask>,
          ),
          DailyTask,
          PrefetchHooks Function()
        > {
  $$DailyTasksTableTableManager(_$AppDatabase db, $DailyTasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> iconName = const Value.absent(),
                Value<int?> reminderHour = const Value.absent(),
                Value<int?> reminderMinute = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => DailyTasksCompanion(
                id: id,
                name: name,
                iconName: iconName,
                reminderHour: reminderHour,
                reminderMinute: reminderMinute,
                isEnabled: isEnabled,
                sortOrder: sortOrder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> iconName = const Value.absent(),
                Value<int?> reminderHour = const Value.absent(),
                Value<int?> reminderMinute = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
              }) => DailyTasksCompanion.insert(
                id: id,
                name: name,
                iconName: iconName,
                reminderHour: reminderHour,
                reminderMinute: reminderMinute,
                isEnabled: isEnabled,
                sortOrder: sortOrder,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyTasksTable,
      DailyTask,
      $$DailyTasksTableFilterComposer,
      $$DailyTasksTableOrderingComposer,
      $$DailyTasksTableAnnotationComposer,
      $$DailyTasksTableCreateCompanionBuilder,
      $$DailyTasksTableUpdateCompanionBuilder,
      (DailyTask, BaseReferences<_$AppDatabase, $DailyTasksTable, DailyTask>),
      DailyTask,
      PrefetchHooks Function()
    >;
typedef $$DailyTaskCompletionsTableCreateCompanionBuilder =
    DailyTaskCompletionsCompanion Function({
      Value<int> id,
      required int taskId,
      required DateTime completedDate,
    });
typedef $$DailyTaskCompletionsTableUpdateCompanionBuilder =
    DailyTaskCompletionsCompanion Function({
      Value<int> id,
      Value<int> taskId,
      Value<DateTime> completedDate,
    });

class $$DailyTaskCompletionsTableFilterComposer
    extends Composer<_$AppDatabase, $DailyTaskCompletionsTable> {
  $$DailyTaskCompletionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedDate => $composableBuilder(
    column: $table.completedDate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyTaskCompletionsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyTaskCompletionsTable> {
  $$DailyTaskCompletionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taskId => $composableBuilder(
    column: $table.taskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedDate => $composableBuilder(
    column: $table.completedDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyTaskCompletionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyTaskCompletionsTable> {
  $$DailyTaskCompletionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<DateTime> get completedDate => $composableBuilder(
    column: $table.completedDate,
    builder: (column) => column,
  );
}

class $$DailyTaskCompletionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyTaskCompletionsTable,
          DailyTaskCompletion,
          $$DailyTaskCompletionsTableFilterComposer,
          $$DailyTaskCompletionsTableOrderingComposer,
          $$DailyTaskCompletionsTableAnnotationComposer,
          $$DailyTaskCompletionsTableCreateCompanionBuilder,
          $$DailyTaskCompletionsTableUpdateCompanionBuilder,
          (
            DailyTaskCompletion,
            BaseReferences<
              _$AppDatabase,
              $DailyTaskCompletionsTable,
              DailyTaskCompletion
            >,
          ),
          DailyTaskCompletion,
          PrefetchHooks Function()
        > {
  $$DailyTaskCompletionsTableTableManager(
    _$AppDatabase db,
    $DailyTaskCompletionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyTaskCompletionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyTaskCompletionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DailyTaskCompletionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> taskId = const Value.absent(),
                Value<DateTime> completedDate = const Value.absent(),
              }) => DailyTaskCompletionsCompanion(
                id: id,
                taskId: taskId,
                completedDate: completedDate,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int taskId,
                required DateTime completedDate,
              }) => DailyTaskCompletionsCompanion.insert(
                id: id,
                taskId: taskId,
                completedDate: completedDate,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyTaskCompletionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyTaskCompletionsTable,
      DailyTaskCompletion,
      $$DailyTaskCompletionsTableFilterComposer,
      $$DailyTaskCompletionsTableOrderingComposer,
      $$DailyTaskCompletionsTableAnnotationComposer,
      $$DailyTaskCompletionsTableCreateCompanionBuilder,
      $$DailyTaskCompletionsTableUpdateCompanionBuilder,
      (
        DailyTaskCompletion,
        BaseReferences<
          _$AppDatabase,
          $DailyTaskCompletionsTable,
          DailyTaskCompletion
        >,
      ),
      DailyTaskCompletion,
      PrefetchHooks Function()
    >;
typedef $$UserProfilesTableCreateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> gender,
      Value<int?> age,
      Value<double?> heightCm,
      Value<double?> weightKg,
      Value<double?> targetWeightKg,
      Value<String> fitnessGoal,
      Value<String> activityLevel,
      Value<double?> weeklyRateKg,
    });
typedef $$UserProfilesTableUpdateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> gender,
      Value<int?> age,
      Value<double?> heightCm,
      Value<double?> weightKg,
      Value<double?> targetWeightKg,
      Value<String> fitnessGoal,
      Value<String> activityLevel,
      Value<double?> weeklyRateKg,
    });

class $$UserProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetWeightKg => $composableBuilder(
    column: $table.targetWeightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fitnessGoal => $composableBuilder(
    column: $table.fitnessGoal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weeklyRateKg => $composableBuilder(
    column: $table.weeklyRateKg,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetWeightKg => $composableBuilder(
    column: $table.targetWeightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fitnessGoal => $composableBuilder(
    column: $table.fitnessGoal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weeklyRateKg => $composableBuilder(
    column: $table.weeklyRateKg,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableAnnotationComposer({
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

  GeneratedColumn<String> get gender =>
      $composableBuilder(column: $table.gender, builder: (column) => column);

  GeneratedColumn<int> get age =>
      $composableBuilder(column: $table.age, builder: (column) => column);

  GeneratedColumn<double> get heightCm =>
      $composableBuilder(column: $table.heightCm, builder: (column) => column);

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<double> get targetWeightKg => $composableBuilder(
    column: $table.targetWeightKg,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fitnessGoal => $composableBuilder(
    column: $table.fitnessGoal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => column,
  );

  GeneratedColumn<double> get weeklyRateKg => $composableBuilder(
    column: $table.weeklyRateKg,
    builder: (column) => column,
  );
}

class $$UserProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfilesTable,
          UserProfile,
          $$UserProfilesTableFilterComposer,
          $$UserProfilesTableOrderingComposer,
          $$UserProfilesTableAnnotationComposer,
          $$UserProfilesTableCreateCompanionBuilder,
          $$UserProfilesTableUpdateCompanionBuilder,
          (
            UserProfile,
            BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfile>,
          ),
          UserProfile,
          PrefetchHooks Function()
        > {
  $$UserProfilesTableTableManager(_$AppDatabase db, $UserProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> gender = const Value.absent(),
                Value<int?> age = const Value.absent(),
                Value<double?> heightCm = const Value.absent(),
                Value<double?> weightKg = const Value.absent(),
                Value<double?> targetWeightKg = const Value.absent(),
                Value<String> fitnessGoal = const Value.absent(),
                Value<String> activityLevel = const Value.absent(),
                Value<double?> weeklyRateKg = const Value.absent(),
              }) => UserProfilesCompanion(
                id: id,
                name: name,
                gender: gender,
                age: age,
                heightCm: heightCm,
                weightKg: weightKg,
                targetWeightKg: targetWeightKg,
                fitnessGoal: fitnessGoal,
                activityLevel: activityLevel,
                weeklyRateKg: weeklyRateKg,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> gender = const Value.absent(),
                Value<int?> age = const Value.absent(),
                Value<double?> heightCm = const Value.absent(),
                Value<double?> weightKg = const Value.absent(),
                Value<double?> targetWeightKg = const Value.absent(),
                Value<String> fitnessGoal = const Value.absent(),
                Value<String> activityLevel = const Value.absent(),
                Value<double?> weeklyRateKg = const Value.absent(),
              }) => UserProfilesCompanion.insert(
                id: id,
                name: name,
                gender: gender,
                age: age,
                heightCm: heightCm,
                weightKg: weightKg,
                targetWeightKg: targetWeightKg,
                fitnessGoal: fitnessGoal,
                activityLevel: activityLevel,
                weeklyRateKg: weeklyRateKg,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfilesTable,
      UserProfile,
      $$UserProfilesTableFilterComposer,
      $$UserProfilesTableOrderingComposer,
      $$UserProfilesTableAnnotationComposer,
      $$UserProfilesTableCreateCompanionBuilder,
      $$UserProfilesTableUpdateCompanionBuilder,
      (
        UserProfile,
        BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfile>,
      ),
      UserProfile,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ExercisesTableTableManager get exercises =>
      $$ExercisesTableTableManager(_db, _db.exercises);
  $$ProgramsTableTableManager get programs =>
      $$ProgramsTableTableManager(_db, _db.programs);
  $$ProgramPhasesTableTableManager get programPhases =>
      $$ProgramPhasesTableTableManager(_db, _db.programPhases);
  $$WodTemplatesTableTableManager get wodTemplates =>
      $$WodTemplatesTableTableManager(_db, _db.wodTemplates);
  $$WorkoutSessionsTableTableManager get workoutSessions =>
      $$WorkoutSessionsTableTableManager(_db, _db.workoutSessions);
  $$WorkoutSetsTableTableManager get workoutSets =>
      $$WorkoutSetsTableTableManager(_db, _db.workoutSets);
  $$BodyweightEntriesTableTableManager get bodyweightEntries =>
      $$BodyweightEntriesTableTableManager(_db, _db.bodyweightEntries);
  $$WodExerciseGroupsTableTableManager get wodExerciseGroups =>
      $$WodExerciseGroupsTableTableManager(_db, _db.wodExerciseGroups);
  $$WodTemplateExercisesTableTableManager get wodTemplateExercises =>
      $$WodTemplateExercisesTableTableManager(_db, _db.wodTemplateExercises);
  $$DailyTasksTableTableManager get dailyTasks =>
      $$DailyTasksTableTableManager(_db, _db.dailyTasks);
  $$DailyTaskCompletionsTableTableManager get dailyTaskCompletions =>
      $$DailyTaskCompletionsTableTableManager(_db, _db.dailyTaskCompletions);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db, _db.userProfiles);
}
