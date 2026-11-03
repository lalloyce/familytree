// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PersonsTable extends Persons with TableInfo<$PersonsTable, PersonRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PersonsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isPlaceholderMeta = const VerificationMeta(
    'isPlaceholder',
  );
  @override
  late final GeneratedColumn<bool> isPlaceholder = GeneratedColumn<bool>(
    'is_placeholder',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_placeholder" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _nameKeyMeta = const VerificationMeta(
    'nameKey',
  );
  @override
  late final GeneratedColumn<String> nameKey = GeneratedColumn<String>(
    'name_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Sex?, String> sex =
      GeneratedColumn<String>(
        'sex',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Sex?>($PersonsTable.$convertersexn);
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    isPlaceholder,
    nameKey,
    sex,
    createdBy,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'persons';
  @override
  VerificationContext validateIntegrity(
    Insertable<PersonRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('is_placeholder')) {
      context.handle(
        _isPlaceholderMeta,
        isPlaceholder.isAcceptableOrUnknown(
          data['is_placeholder']!,
          _isPlaceholderMeta,
        ),
      );
    }
    if (data.containsKey('name_key')) {
      context.handle(
        _nameKeyMeta,
        nameKey.isAcceptableOrUnknown(data['name_key']!, _nameKeyMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PersonRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PersonRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      isPlaceholder: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_placeholder'],
      )!,
      nameKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_key'],
      ),
      sex: $PersonsTable.$convertersexn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}sex'],
        ),
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $PersonsTable createAlias(String alias) {
    return $PersonsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<Sex, String, String> $convertersex =
      const EnumNameConverter<Sex>(Sex.values);
  static JsonTypeConverter2<Sex?, String?, String?> $convertersexn =
      JsonTypeConverter2.asNullable($convertersex);
}

class PersonRow extends DataClass implements Insertable<PersonRow> {
  final String id;
  final bool isPlaceholder;
  final String? nameKey;
  final Sex? sex;
  final String createdBy;
  final DateTime? deletedAt;
  const PersonRow({
    required this.id,
    required this.isPlaceholder,
    this.nameKey,
    this.sex,
    required this.createdBy,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['is_placeholder'] = Variable<bool>(isPlaceholder);
    if (!nullToAbsent || nameKey != null) {
      map['name_key'] = Variable<String>(nameKey);
    }
    if (!nullToAbsent || sex != null) {
      map['sex'] = Variable<String>($PersonsTable.$convertersexn.toSql(sex));
    }
    map['created_by'] = Variable<String>(createdBy);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PersonsCompanion toCompanion(bool nullToAbsent) {
    return PersonsCompanion(
      id: Value(id),
      isPlaceholder: Value(isPlaceholder),
      nameKey: nameKey == null && nullToAbsent
          ? const Value.absent()
          : Value(nameKey),
      sex: sex == null && nullToAbsent ? const Value.absent() : Value(sex),
      createdBy: Value(createdBy),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PersonRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PersonRow(
      id: serializer.fromJson<String>(json['id']),
      isPlaceholder: serializer.fromJson<bool>(json['isPlaceholder']),
      nameKey: serializer.fromJson<String?>(json['nameKey']),
      sex: $PersonsTable.$convertersexn.fromJson(
        serializer.fromJson<String?>(json['sex']),
      ),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'isPlaceholder': serializer.toJson<bool>(isPlaceholder),
      'nameKey': serializer.toJson<String?>(nameKey),
      'sex': serializer.toJson<String?>(
        $PersonsTable.$convertersexn.toJson(sex),
      ),
      'createdBy': serializer.toJson<String>(createdBy),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  PersonRow copyWith({
    String? id,
    bool? isPlaceholder,
    Value<String?> nameKey = const Value.absent(),
    Value<Sex?> sex = const Value.absent(),
    String? createdBy,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => PersonRow(
    id: id ?? this.id,
    isPlaceholder: isPlaceholder ?? this.isPlaceholder,
    nameKey: nameKey.present ? nameKey.value : this.nameKey,
    sex: sex.present ? sex.value : this.sex,
    createdBy: createdBy ?? this.createdBy,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  PersonRow copyWithCompanion(PersonsCompanion data) {
    return PersonRow(
      id: data.id.present ? data.id.value : this.id,
      isPlaceholder: data.isPlaceholder.present
          ? data.isPlaceholder.value
          : this.isPlaceholder,
      nameKey: data.nameKey.present ? data.nameKey.value : this.nameKey,
      sex: data.sex.present ? data.sex.value : this.sex,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PersonRow(')
          ..write('id: $id, ')
          ..write('isPlaceholder: $isPlaceholder, ')
          ..write('nameKey: $nameKey, ')
          ..write('sex: $sex, ')
          ..write('createdBy: $createdBy, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, isPlaceholder, nameKey, sex, createdBy, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersonRow &&
          other.id == this.id &&
          other.isPlaceholder == this.isPlaceholder &&
          other.nameKey == this.nameKey &&
          other.sex == this.sex &&
          other.createdBy == this.createdBy &&
          other.deletedAt == this.deletedAt);
}

class PersonsCompanion extends UpdateCompanion<PersonRow> {
  final Value<String> id;
  final Value<bool> isPlaceholder;
  final Value<String?> nameKey;
  final Value<Sex?> sex;
  final Value<String> createdBy;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const PersonsCompanion({
    this.id = const Value.absent(),
    this.isPlaceholder = const Value.absent(),
    this.nameKey = const Value.absent(),
    this.sex = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PersonsCompanion.insert({
    required String id,
    this.isPlaceholder = const Value.absent(),
    this.nameKey = const Value.absent(),
    this.sex = const Value.absent(),
    required String createdBy,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdBy = Value(createdBy);
  static Insertable<PersonRow> custom({
    Expression<String>? id,
    Expression<bool>? isPlaceholder,
    Expression<String>? nameKey,
    Expression<String>? sex,
    Expression<String>? createdBy,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (isPlaceholder != null) 'is_placeholder': isPlaceholder,
      if (nameKey != null) 'name_key': nameKey,
      if (sex != null) 'sex': sex,
      if (createdBy != null) 'created_by': createdBy,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PersonsCompanion copyWith({
    Value<String>? id,
    Value<bool>? isPlaceholder,
    Value<String?>? nameKey,
    Value<Sex?>? sex,
    Value<String>? createdBy,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return PersonsCompanion(
      id: id ?? this.id,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
      nameKey: nameKey ?? this.nameKey,
      sex: sex ?? this.sex,
      createdBy: createdBy ?? this.createdBy,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (isPlaceholder.present) {
      map['is_placeholder'] = Variable<bool>(isPlaceholder.value);
    }
    if (nameKey.present) {
      map['name_key'] = Variable<String>(nameKey.value);
    }
    if (sex.present) {
      map['sex'] = Variable<String>(
        $PersonsTable.$convertersexn.toSql(sex.value),
      );
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PersonsCompanion(')
          ..write('id: $id, ')
          ..write('isPlaceholder: $isPlaceholder, ')
          ..write('nameKey: $nameKey, ')
          ..write('sex: $sex, ')
          ..write('createdBy: $createdBy, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HousesTable extends Houses with TableInfo<$HousesTable, HouseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HousesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _husbandIdMeta = const VerificationMeta(
    'husbandId',
  );
  @override
  late final GeneratedColumn<String> husbandId = GeneratedColumn<String>(
    'husband_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    husbandId,
    ordinal,
    createdBy,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'houses';
  @override
  VerificationContext validateIntegrity(
    Insertable<HouseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('husband_id')) {
      context.handle(
        _husbandIdMeta,
        husbandId.isAcceptableOrUnknown(data['husband_id']!, _husbandIdMeta),
      );
    } else if (isInserting) {
      context.missing(_husbandIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HouseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HouseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      husbandId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}husband_id'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $HousesTable createAlias(String alias) {
    return $HousesTable(attachedDatabase, alias);
  }
}

class HouseRow extends DataClass implements Insertable<HouseRow> {
  final String id;
  final String husbandId;
  final int? ordinal;
  final String createdBy;
  final DateTime? deletedAt;
  const HouseRow({
    required this.id,
    required this.husbandId,
    this.ordinal,
    required this.createdBy,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['husband_id'] = Variable<String>(husbandId);
    if (!nullToAbsent || ordinal != null) {
      map['ordinal'] = Variable<int>(ordinal);
    }
    map['created_by'] = Variable<String>(createdBy);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  HousesCompanion toCompanion(bool nullToAbsent) {
    return HousesCompanion(
      id: Value(id),
      husbandId: Value(husbandId),
      ordinal: ordinal == null && nullToAbsent
          ? const Value.absent()
          : Value(ordinal),
      createdBy: Value(createdBy),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory HouseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HouseRow(
      id: serializer.fromJson<String>(json['id']),
      husbandId: serializer.fromJson<String>(json['husbandId']),
      ordinal: serializer.fromJson<int?>(json['ordinal']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'husbandId': serializer.toJson<String>(husbandId),
      'ordinal': serializer.toJson<int?>(ordinal),
      'createdBy': serializer.toJson<String>(createdBy),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  HouseRow copyWith({
    String? id,
    String? husbandId,
    Value<int?> ordinal = const Value.absent(),
    String? createdBy,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => HouseRow(
    id: id ?? this.id,
    husbandId: husbandId ?? this.husbandId,
    ordinal: ordinal.present ? ordinal.value : this.ordinal,
    createdBy: createdBy ?? this.createdBy,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  HouseRow copyWithCompanion(HousesCompanion data) {
    return HouseRow(
      id: data.id.present ? data.id.value : this.id,
      husbandId: data.husbandId.present ? data.husbandId.value : this.husbandId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HouseRow(')
          ..write('id: $id, ')
          ..write('husbandId: $husbandId, ')
          ..write('ordinal: $ordinal, ')
          ..write('createdBy: $createdBy, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, husbandId, ordinal, createdBy, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HouseRow &&
          other.id == this.id &&
          other.husbandId == this.husbandId &&
          other.ordinal == this.ordinal &&
          other.createdBy == this.createdBy &&
          other.deletedAt == this.deletedAt);
}

class HousesCompanion extends UpdateCompanion<HouseRow> {
  final Value<String> id;
  final Value<String> husbandId;
  final Value<int?> ordinal;
  final Value<String> createdBy;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const HousesCompanion({
    this.id = const Value.absent(),
    this.husbandId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HousesCompanion.insert({
    required String id,
    required String husbandId,
    this.ordinal = const Value.absent(),
    required String createdBy,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       husbandId = Value(husbandId),
       createdBy = Value(createdBy);
  static Insertable<HouseRow> custom({
    Expression<String>? id,
    Expression<String>? husbandId,
    Expression<int>? ordinal,
    Expression<String>? createdBy,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (husbandId != null) 'husband_id': husbandId,
      if (ordinal != null) 'ordinal': ordinal,
      if (createdBy != null) 'created_by': createdBy,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HousesCompanion copyWith({
    Value<String>? id,
    Value<String>? husbandId,
    Value<int?>? ordinal,
    Value<String>? createdBy,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return HousesCompanion(
      id: id ?? this.id,
      husbandId: husbandId ?? this.husbandId,
      ordinal: ordinal ?? this.ordinal,
      createdBy: createdBy ?? this.createdBy,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (husbandId.present) {
      map['husband_id'] = Variable<String>(husbandId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HousesCompanion(')
          ..write('id: $id, ')
          ..write('husbandId: $husbandId, ')
          ..write('ordinal: $ordinal, ')
          ..write('createdBy: $createdBy, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClaimsTable extends Claims with TableInfo<$ClaimsTable, ClaimRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClaimsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localSeqMeta = const VerificationMeta(
    'localSeq',
  );
  @override
  late final GeneratedColumn<int> localSeq = GeneratedColumn<int>(
    'local_seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ClaimKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ClaimKind>($ClaimsTable.$converterkind);
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<String> subjectId = GeneratedColumn<String>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _objectIdMeta = const VerificationMeta(
    'objectId',
  );
  @override
  late final GeneratedColumn<String> objectId = GeneratedColumn<String>(
    'object_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Basis?, String> basis =
      GeneratedColumn<String>(
        'basis',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<Basis?>($ClaimsTable.$converterbasisn);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _assertedByMeta = const VerificationMeta(
    'assertedBy',
  );
  @override
  late final GeneratedColumn<String> assertedBy = GeneratedColumn<String>(
    'asserted_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseClaimIdMeta = const VerificationMeta(
    'baseClaimId',
  );
  @override
  late final GeneratedColumn<String> baseClaimId = GeneratedColumn<String>(
    'base_claim_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    check: () => status.isIn([claimStatusActive, claimStatusSuperseded]),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(claimStatusActive),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    localSeq,
    id,
    kind,
    subjectId,
    objectId,
    basis,
    body,
    assertedBy,
    baseClaimId,
    status,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'claims';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClaimRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_seq')) {
      context.handle(
        _localSeqMeta,
        localSeq.isAcceptableOrUnknown(data['local_seq']!, _localSeqMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('object_id')) {
      context.handle(
        _objectIdMeta,
        objectId.isAcceptableOrUnknown(data['object_id']!, _objectIdMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('asserted_by')) {
      context.handle(
        _assertedByMeta,
        assertedBy.isAcceptableOrUnknown(data['asserted_by']!, _assertedByMeta),
      );
    } else if (isInserting) {
      context.missing(_assertedByMeta);
    }
    if (data.containsKey('base_claim_id')) {
      context.handle(
        _baseClaimIdMeta,
        baseClaimId.isAcceptableOrUnknown(
          data['base_claim_id']!,
          _baseClaimIdMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localSeq};
  @override
  ClaimRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClaimRow(
      localSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_seq'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: $ClaimsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_id'],
      )!,
      objectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}object_id'],
      ),
      basis: $ClaimsTable.$converterbasisn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}basis'],
        ),
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      assertedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asserted_by'],
      )!,
      baseClaimId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_claim_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ClaimsTable createAlias(String alias) {
    return $ClaimsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ClaimKind, String, String> $converterkind =
      const EnumNameConverter<ClaimKind>(ClaimKind.values);
  static JsonTypeConverter2<Basis, String, String> $converterbasis =
      const EnumNameConverter<Basis>(Basis.values);
  static JsonTypeConverter2<Basis?, String?, String?> $converterbasisn =
      JsonTypeConverter2.asNullable($converterbasis);
}

class ClaimRow extends DataClass implements Insertable<ClaimRow> {
  final int localSeq;
  final String id;
  final ClaimKind kind;
  final String subjectId;
  final String? objectId;
  final Basis? basis;
  final String? body;
  final String assertedBy;
  final String? baseClaimId;
  final String status;
  final DateTime createdAt;
  const ClaimRow({
    required this.localSeq,
    required this.id,
    required this.kind,
    required this.subjectId,
    this.objectId,
    this.basis,
    this.body,
    required this.assertedBy,
    this.baseClaimId,
    required this.status,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_seq'] = Variable<int>(localSeq);
    map['id'] = Variable<String>(id);
    {
      map['kind'] = Variable<String>($ClaimsTable.$converterkind.toSql(kind));
    }
    map['subject_id'] = Variable<String>(subjectId);
    if (!nullToAbsent || objectId != null) {
      map['object_id'] = Variable<String>(objectId);
    }
    if (!nullToAbsent || basis != null) {
      map['basis'] = Variable<String>(
        $ClaimsTable.$converterbasisn.toSql(basis),
      );
    }
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    map['asserted_by'] = Variable<String>(assertedBy);
    if (!nullToAbsent || baseClaimId != null) {
      map['base_claim_id'] = Variable<String>(baseClaimId);
    }
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ClaimsCompanion toCompanion(bool nullToAbsent) {
    return ClaimsCompanion(
      localSeq: Value(localSeq),
      id: Value(id),
      kind: Value(kind),
      subjectId: Value(subjectId),
      objectId: objectId == null && nullToAbsent
          ? const Value.absent()
          : Value(objectId),
      basis: basis == null && nullToAbsent
          ? const Value.absent()
          : Value(basis),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      assertedBy: Value(assertedBy),
      baseClaimId: baseClaimId == null && nullToAbsent
          ? const Value.absent()
          : Value(baseClaimId),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory ClaimRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClaimRow(
      localSeq: serializer.fromJson<int>(json['localSeq']),
      id: serializer.fromJson<String>(json['id']),
      kind: $ClaimsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      subjectId: serializer.fromJson<String>(json['subjectId']),
      objectId: serializer.fromJson<String?>(json['objectId']),
      basis: $ClaimsTable.$converterbasisn.fromJson(
        serializer.fromJson<String?>(json['basis']),
      ),
      body: serializer.fromJson<String?>(json['body']),
      assertedBy: serializer.fromJson<String>(json['assertedBy']),
      baseClaimId: serializer.fromJson<String?>(json['baseClaimId']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localSeq': serializer.toJson<int>(localSeq),
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(
        $ClaimsTable.$converterkind.toJson(kind),
      ),
      'subjectId': serializer.toJson<String>(subjectId),
      'objectId': serializer.toJson<String?>(objectId),
      'basis': serializer.toJson<String?>(
        $ClaimsTable.$converterbasisn.toJson(basis),
      ),
      'body': serializer.toJson<String?>(body),
      'assertedBy': serializer.toJson<String>(assertedBy),
      'baseClaimId': serializer.toJson<String?>(baseClaimId),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ClaimRow copyWith({
    int? localSeq,
    String? id,
    ClaimKind? kind,
    String? subjectId,
    Value<String?> objectId = const Value.absent(),
    Value<Basis?> basis = const Value.absent(),
    Value<String?> body = const Value.absent(),
    String? assertedBy,
    Value<String?> baseClaimId = const Value.absent(),
    String? status,
    DateTime? createdAt,
  }) => ClaimRow(
    localSeq: localSeq ?? this.localSeq,
    id: id ?? this.id,
    kind: kind ?? this.kind,
    subjectId: subjectId ?? this.subjectId,
    objectId: objectId.present ? objectId.value : this.objectId,
    basis: basis.present ? basis.value : this.basis,
    body: body.present ? body.value : this.body,
    assertedBy: assertedBy ?? this.assertedBy,
    baseClaimId: baseClaimId.present ? baseClaimId.value : this.baseClaimId,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
  ClaimRow copyWithCompanion(ClaimsCompanion data) {
    return ClaimRow(
      localSeq: data.localSeq.present ? data.localSeq.value : this.localSeq,
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      objectId: data.objectId.present ? data.objectId.value : this.objectId,
      basis: data.basis.present ? data.basis.value : this.basis,
      body: data.body.present ? data.body.value : this.body,
      assertedBy: data.assertedBy.present
          ? data.assertedBy.value
          : this.assertedBy,
      baseClaimId: data.baseClaimId.present
          ? data.baseClaimId.value
          : this.baseClaimId,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClaimRow(')
          ..write('localSeq: $localSeq, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('subjectId: $subjectId, ')
          ..write('objectId: $objectId, ')
          ..write('basis: $basis, ')
          ..write('body: $body, ')
          ..write('assertedBy: $assertedBy, ')
          ..write('baseClaimId: $baseClaimId, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localSeq,
    id,
    kind,
    subjectId,
    objectId,
    basis,
    body,
    assertedBy,
    baseClaimId,
    status,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClaimRow &&
          other.localSeq == this.localSeq &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.subjectId == this.subjectId &&
          other.objectId == this.objectId &&
          other.basis == this.basis &&
          other.body == this.body &&
          other.assertedBy == this.assertedBy &&
          other.baseClaimId == this.baseClaimId &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class ClaimsCompanion extends UpdateCompanion<ClaimRow> {
  final Value<int> localSeq;
  final Value<String> id;
  final Value<ClaimKind> kind;
  final Value<String> subjectId;
  final Value<String?> objectId;
  final Value<Basis?> basis;
  final Value<String?> body;
  final Value<String> assertedBy;
  final Value<String?> baseClaimId;
  final Value<String> status;
  final Value<DateTime> createdAt;
  const ClaimsCompanion({
    this.localSeq = const Value.absent(),
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.objectId = const Value.absent(),
    this.basis = const Value.absent(),
    this.body = const Value.absent(),
    this.assertedBy = const Value.absent(),
    this.baseClaimId = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ClaimsCompanion.insert({
    this.localSeq = const Value.absent(),
    required String id,
    required ClaimKind kind,
    required String subjectId,
    this.objectId = const Value.absent(),
    this.basis = const Value.absent(),
    this.body = const Value.absent(),
    required String assertedBy,
    this.baseClaimId = const Value.absent(),
    this.status = const Value.absent(),
    required DateTime createdAt,
  }) : id = Value(id),
       kind = Value(kind),
       subjectId = Value(subjectId),
       assertedBy = Value(assertedBy),
       createdAt = Value(createdAt);
  static Insertable<ClaimRow> custom({
    Expression<int>? localSeq,
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? subjectId,
    Expression<String>? objectId,
    Expression<String>? basis,
    Expression<String>? body,
    Expression<String>? assertedBy,
    Expression<String>? baseClaimId,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (localSeq != null) 'local_seq': localSeq,
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (subjectId != null) 'subject_id': subjectId,
      if (objectId != null) 'object_id': objectId,
      if (basis != null) 'basis': basis,
      if (body != null) 'body': body,
      if (assertedBy != null) 'asserted_by': assertedBy,
      if (baseClaimId != null) 'base_claim_id': baseClaimId,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ClaimsCompanion copyWith({
    Value<int>? localSeq,
    Value<String>? id,
    Value<ClaimKind>? kind,
    Value<String>? subjectId,
    Value<String?>? objectId,
    Value<Basis?>? basis,
    Value<String?>? body,
    Value<String>? assertedBy,
    Value<String?>? baseClaimId,
    Value<String>? status,
    Value<DateTime>? createdAt,
  }) {
    return ClaimsCompanion(
      localSeq: localSeq ?? this.localSeq,
      id: id ?? this.id,
      kind: kind ?? this.kind,
      subjectId: subjectId ?? this.subjectId,
      objectId: objectId ?? this.objectId,
      basis: basis ?? this.basis,
      body: body ?? this.body,
      assertedBy: assertedBy ?? this.assertedBy,
      baseClaimId: baseClaimId ?? this.baseClaimId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localSeq.present) {
      map['local_seq'] = Variable<int>(localSeq.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $ClaimsTable.$converterkind.toSql(kind.value),
      );
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<String>(subjectId.value);
    }
    if (objectId.present) {
      map['object_id'] = Variable<String>(objectId.value);
    }
    if (basis.present) {
      map['basis'] = Variable<String>(
        $ClaimsTable.$converterbasisn.toSql(basis.value),
      );
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (assertedBy.present) {
      map['asserted_by'] = Variable<String>(assertedBy.value);
    }
    if (baseClaimId.present) {
      map['base_claim_id'] = Variable<String>(baseClaimId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClaimsCompanion(')
          ..write('localSeq: $localSeq, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('subjectId: $subjectId, ')
          ..write('objectId: $objectId, ')
          ..write('basis: $basis, ')
          ..write('body: $body, ')
          ..write('assertedBy: $assertedBy, ')
          ..write('baseClaimId: $baseClaimId, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $PersonNamesTable extends PersonNames
    with TableInfo<$PersonNamesTable, PersonNameRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PersonNamesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<String> personId = GeneratedColumn<String>(
    'person_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, personId, name, kind];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'person_names';
  @override
  VerificationContext validateIntegrity(
    Insertable<PersonNameRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PersonNameRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PersonNameRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
    );
  }

  @override
  $PersonNamesTable createAlias(String alias) {
    return $PersonNamesTable(attachedDatabase, alias);
  }
}

class PersonNameRow extends DataClass implements Insertable<PersonNameRow> {
  final String id;
  final String personId;
  final String name;
  final String kind;
  const PersonNameRow({
    required this.id,
    required this.personId,
    required this.name,
    required this.kind,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['person_id'] = Variable<String>(personId);
    map['name'] = Variable<String>(name);
    map['kind'] = Variable<String>(kind);
    return map;
  }

  PersonNamesCompanion toCompanion(bool nullToAbsent) {
    return PersonNamesCompanion(
      id: Value(id),
      personId: Value(personId),
      name: Value(name),
      kind: Value(kind),
    );
  }

  factory PersonNameRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PersonNameRow(
      id: serializer.fromJson<String>(json['id']),
      personId: serializer.fromJson<String>(json['personId']),
      name: serializer.fromJson<String>(json['name']),
      kind: serializer.fromJson<String>(json['kind']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'personId': serializer.toJson<String>(personId),
      'name': serializer.toJson<String>(name),
      'kind': serializer.toJson<String>(kind),
    };
  }

  PersonNameRow copyWith({
    String? id,
    String? personId,
    String? name,
    String? kind,
  }) => PersonNameRow(
    id: id ?? this.id,
    personId: personId ?? this.personId,
    name: name ?? this.name,
    kind: kind ?? this.kind,
  );
  PersonNameRow copyWithCompanion(PersonNamesCompanion data) {
    return PersonNameRow(
      id: data.id.present ? data.id.value : this.id,
      personId: data.personId.present ? data.personId.value : this.personId,
      name: data.name.present ? data.name.value : this.name,
      kind: data.kind.present ? data.kind.value : this.kind,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PersonNameRow(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('name: $name, ')
          ..write('kind: $kind')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, personId, name, kind);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PersonNameRow &&
          other.id == this.id &&
          other.personId == this.personId &&
          other.name == this.name &&
          other.kind == this.kind);
}

class PersonNamesCompanion extends UpdateCompanion<PersonNameRow> {
  final Value<String> id;
  final Value<String> personId;
  final Value<String> name;
  final Value<String> kind;
  final Value<int> rowid;
  const PersonNamesCompanion({
    this.id = const Value.absent(),
    this.personId = const Value.absent(),
    this.name = const Value.absent(),
    this.kind = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PersonNamesCompanion.insert({
    required String id,
    required String personId,
    required String name,
    required String kind,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       personId = Value(personId),
       name = Value(name),
       kind = Value(kind);
  static Insertable<PersonNameRow> custom({
    Expression<String>? id,
    Expression<String>? personId,
    Expression<String>? name,
    Expression<String>? kind,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (personId != null) 'person_id': personId,
      if (name != null) 'name': name,
      if (kind != null) 'kind': kind,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PersonNamesCompanion copyWith({
    Value<String>? id,
    Value<String>? personId,
    Value<String>? name,
    Value<String>? kind,
    Value<int>? rowid,
  }) {
    return PersonNamesCompanion(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<String>(personId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PersonNamesCompanion(')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('name: $name, ')
          ..write('kind: $kind, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FieldEditsTable extends FieldEdits
    with TableInfo<$FieldEditsTable, FieldEditRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FieldEditsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localSeqMeta = const VerificationMeta(
    'localSeq',
  );
  @override
  late final GeneratedColumn<int> localSeq = GeneratedColumn<int>(
    'local_seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldMeta = const VerificationMeta('field');
  @override
  late final GeneratedColumn<String> field = GeneratedColumn<String>(
    'field',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _assertedByMeta = const VerificationMeta(
    'assertedBy',
  );
  @override
  late final GeneratedColumn<String> assertedBy = GeneratedColumn<String>(
    'asserted_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    localSeq,
    id,
    entity,
    entityId,
    field,
    value,
    assertedBy,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'field_edits';
  @override
  VerificationContext validateIntegrity(
    Insertable<FieldEditRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_seq')) {
      context.handle(
        _localSeqMeta,
        localSeq.isAcceptableOrUnknown(data['local_seq']!, _localSeqMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('field')) {
      context.handle(
        _fieldMeta,
        field.isAcceptableOrUnknown(data['field']!, _fieldMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    if (data.containsKey('asserted_by')) {
      context.handle(
        _assertedByMeta,
        assertedBy.isAcceptableOrUnknown(data['asserted_by']!, _assertedByMeta),
      );
    } else if (isInserting) {
      context.missing(_assertedByMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localSeq};
  @override
  FieldEditRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FieldEditRow(
      localSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_seq'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      field: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
      assertedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asserted_by'],
      )!,
    );
  }

  @override
  $FieldEditsTable createAlias(String alias) {
    return $FieldEditsTable(attachedDatabase, alias);
  }
}

class FieldEditRow extends DataClass implements Insertable<FieldEditRow> {
  final int localSeq;
  final String id;
  final String entity;
  final String entityId;
  final String field;
  final String? value;
  final String assertedBy;
  const FieldEditRow({
    required this.localSeq,
    required this.id,
    required this.entity,
    required this.entityId,
    required this.field,
    this.value,
    required this.assertedBy,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_seq'] = Variable<int>(localSeq);
    map['id'] = Variable<String>(id);
    map['entity'] = Variable<String>(entity);
    map['entity_id'] = Variable<String>(entityId);
    map['field'] = Variable<String>(field);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    map['asserted_by'] = Variable<String>(assertedBy);
    return map;
  }

  FieldEditsCompanion toCompanion(bool nullToAbsent) {
    return FieldEditsCompanion(
      localSeq: Value(localSeq),
      id: Value(id),
      entity: Value(entity),
      entityId: Value(entityId),
      field: Value(field),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
      assertedBy: Value(assertedBy),
    );
  }

  factory FieldEditRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FieldEditRow(
      localSeq: serializer.fromJson<int>(json['localSeq']),
      id: serializer.fromJson<String>(json['id']),
      entity: serializer.fromJson<String>(json['entity']),
      entityId: serializer.fromJson<String>(json['entityId']),
      field: serializer.fromJson<String>(json['field']),
      value: serializer.fromJson<String?>(json['value']),
      assertedBy: serializer.fromJson<String>(json['assertedBy']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localSeq': serializer.toJson<int>(localSeq),
      'id': serializer.toJson<String>(id),
      'entity': serializer.toJson<String>(entity),
      'entityId': serializer.toJson<String>(entityId),
      'field': serializer.toJson<String>(field),
      'value': serializer.toJson<String?>(value),
      'assertedBy': serializer.toJson<String>(assertedBy),
    };
  }

  FieldEditRow copyWith({
    int? localSeq,
    String? id,
    String? entity,
    String? entityId,
    String? field,
    Value<String?> value = const Value.absent(),
    String? assertedBy,
  }) => FieldEditRow(
    localSeq: localSeq ?? this.localSeq,
    id: id ?? this.id,
    entity: entity ?? this.entity,
    entityId: entityId ?? this.entityId,
    field: field ?? this.field,
    value: value.present ? value.value : this.value,
    assertedBy: assertedBy ?? this.assertedBy,
  );
  FieldEditRow copyWithCompanion(FieldEditsCompanion data) {
    return FieldEditRow(
      localSeq: data.localSeq.present ? data.localSeq.value : this.localSeq,
      id: data.id.present ? data.id.value : this.id,
      entity: data.entity.present ? data.entity.value : this.entity,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      field: data.field.present ? data.field.value : this.field,
      value: data.value.present ? data.value.value : this.value,
      assertedBy: data.assertedBy.present
          ? data.assertedBy.value
          : this.assertedBy,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FieldEditRow(')
          ..write('localSeq: $localSeq, ')
          ..write('id: $id, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('field: $field, ')
          ..write('value: $value, ')
          ..write('assertedBy: $assertedBy')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(localSeq, id, entity, entityId, field, value, assertedBy);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FieldEditRow &&
          other.localSeq == this.localSeq &&
          other.id == this.id &&
          other.entity == this.entity &&
          other.entityId == this.entityId &&
          other.field == this.field &&
          other.value == this.value &&
          other.assertedBy == this.assertedBy);
}

class FieldEditsCompanion extends UpdateCompanion<FieldEditRow> {
  final Value<int> localSeq;
  final Value<String> id;
  final Value<String> entity;
  final Value<String> entityId;
  final Value<String> field;
  final Value<String?> value;
  final Value<String> assertedBy;
  const FieldEditsCompanion({
    this.localSeq = const Value.absent(),
    this.id = const Value.absent(),
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.field = const Value.absent(),
    this.value = const Value.absent(),
    this.assertedBy = const Value.absent(),
  });
  FieldEditsCompanion.insert({
    this.localSeq = const Value.absent(),
    required String id,
    required String entity,
    required String entityId,
    required String field,
    this.value = const Value.absent(),
    required String assertedBy,
  }) : id = Value(id),
       entity = Value(entity),
       entityId = Value(entityId),
       field = Value(field),
       assertedBy = Value(assertedBy);
  static Insertable<FieldEditRow> custom({
    Expression<int>? localSeq,
    Expression<String>? id,
    Expression<String>? entity,
    Expression<String>? entityId,
    Expression<String>? field,
    Expression<String>? value,
    Expression<String>? assertedBy,
  }) {
    return RawValuesInsertable({
      if (localSeq != null) 'local_seq': localSeq,
      if (id != null) 'id': id,
      if (entity != null) 'entity': entity,
      if (entityId != null) 'entity_id': entityId,
      if (field != null) 'field': field,
      if (value != null) 'value': value,
      if (assertedBy != null) 'asserted_by': assertedBy,
    });
  }

  FieldEditsCompanion copyWith({
    Value<int>? localSeq,
    Value<String>? id,
    Value<String>? entity,
    Value<String>? entityId,
    Value<String>? field,
    Value<String?>? value,
    Value<String>? assertedBy,
  }) {
    return FieldEditsCompanion(
      localSeq: localSeq ?? this.localSeq,
      id: id ?? this.id,
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      field: field ?? this.field,
      value: value ?? this.value,
      assertedBy: assertedBy ?? this.assertedBy,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localSeq.present) {
      map['local_seq'] = Variable<int>(localSeq.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (field.present) {
      map['field'] = Variable<String>(field.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (assertedBy.present) {
      map['asserted_by'] = Variable<String>(assertedBy.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FieldEditsCompanion(')
          ..write('localSeq: $localSeq, ')
          ..write('id: $id, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('field: $field, ')
          ..write('value: $value, ')
          ..write('assertedBy: $assertedBy')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PersonsTable persons = $PersonsTable(this);
  late final $HousesTable houses = $HousesTable(this);
  late final $ClaimsTable claims = $ClaimsTable(this);
  late final $PersonNamesTable personNames = $PersonNamesTable(this);
  late final $FieldEditsTable fieldEdits = $FieldEditsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    persons,
    houses,
    claims,
    personNames,
    fieldEdits,
  ];
}

typedef $$PersonsTableCreateCompanionBuilder = PersonsCompanion Function({
  required String id,
  Value<bool> isPlaceholder,
  Value<String?> nameKey,
  Value<Sex?> sex,
  required String createdBy,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$PersonsTableUpdateCompanionBuilder = PersonsCompanion Function({
  Value<String> id,
  Value<bool> isPlaceholder,
  Value<String?> nameKey,
  Value<Sex?> sex,
  Value<String> createdBy,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$PersonsTableFilterComposer
    extends Composer<_$AppDatabase, $PersonsTable> {
  $$PersonsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPlaceholder => $composableBuilder(
    column: $table.isPlaceholder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameKey => $composableBuilder(
    column: $table.nameKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Sex?, Sex, String> get sex =>
      $composableBuilder(
        column: $table.sex,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PersonsTableOrderingComposer
    extends Composer<_$AppDatabase, $PersonsTable> {
  $$PersonsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPlaceholder => $composableBuilder(
    column: $table.isPlaceholder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameKey => $composableBuilder(
    column: $table.nameKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PersonsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PersonsTable> {
  $$PersonsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get isPlaceholder => $composableBuilder(
    column: $table.isPlaceholder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nameKey =>
      $composableBuilder(column: $table.nameKey, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Sex?, String> get sex =>
      $composableBuilder(column: $table.sex, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$PersonsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PersonsTable,
          PersonRow,
          $$PersonsTableFilterComposer,
          $$PersonsTableOrderingComposer,
          $$PersonsTableAnnotationComposer,
          $$PersonsTableCreateCompanionBuilder,
          $$PersonsTableUpdateCompanionBuilder,
          (PersonRow, BaseReferences<_$AppDatabase, $PersonsTable, PersonRow>),
          PersonRow,
          PrefetchHooks Function()
        > {
  $$PersonsTableTableManager(_$AppDatabase db, $PersonsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PersonsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PersonsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PersonsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<bool> isPlaceholder = const Value.absent(),
                Value<String?> nameKey = const Value.absent(),
                Value<Sex?> sex = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonsCompanion(
                id: id,
                isPlaceholder: isPlaceholder,
                nameKey: nameKey,
                sex: sex,
                createdBy: createdBy,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<bool> isPlaceholder = const Value.absent(),
                Value<String?> nameKey = const Value.absent(),
                Value<Sex?> sex = const Value.absent(),
                required String createdBy,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonsCompanion.insert(
                id: id,
                isPlaceholder: isPlaceholder,
                nameKey: nameKey,
                sex: sex,
                createdBy: createdBy,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PersonsTable, PersonRow>(table),
                  BaseReferences<_$AppDatabase, $PersonsTable, PersonRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PersonsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PersonsTable,
      PersonRow,
      $$PersonsTableFilterComposer,
      $$PersonsTableOrderingComposer,
      $$PersonsTableAnnotationComposer,
      $$PersonsTableCreateCompanionBuilder,
      $$PersonsTableUpdateCompanionBuilder,
      (PersonRow, BaseReferences<_$AppDatabase, $PersonsTable, PersonRow>),
      PersonRow,
      PrefetchHooks Function()
    >;
typedef $$HousesTableCreateCompanionBuilder = HousesCompanion Function({
  required String id,
  required String husbandId,
  Value<int?> ordinal,
  required String createdBy,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$HousesTableUpdateCompanionBuilder = HousesCompanion Function({
  Value<String> id,
  Value<String> husbandId,
  Value<int?> ordinal,
  Value<String> createdBy,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$HousesTableFilterComposer
    extends Composer<_$AppDatabase, $HousesTable> {
  $$HousesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get husbandId => $composableBuilder(
    column: $table.husbandId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HousesTableOrderingComposer
    extends Composer<_$AppDatabase, $HousesTable> {
  $$HousesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get husbandId => $composableBuilder(
    column: $table.husbandId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HousesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HousesTable> {
  $$HousesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get husbandId =>
      $composableBuilder(column: $table.husbandId, builder: (column) => column);

  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$HousesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HousesTable,
          HouseRow,
          $$HousesTableFilterComposer,
          $$HousesTableOrderingComposer,
          $$HousesTableAnnotationComposer,
          $$HousesTableCreateCompanionBuilder,
          $$HousesTableUpdateCompanionBuilder,
          (HouseRow, BaseReferences<_$AppDatabase, $HousesTable, HouseRow>),
          HouseRow,
          PrefetchHooks Function()
        > {
  $$HousesTableTableManager(_$AppDatabase db, $HousesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HousesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HousesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HousesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> husbandId = const Value.absent(),
                Value<int?> ordinal = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HousesCompanion(
                id: id,
                husbandId: husbandId,
                ordinal: ordinal,
                createdBy: createdBy,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String husbandId,
                Value<int?> ordinal = const Value.absent(),
                required String createdBy,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HousesCompanion.insert(
                id: id,
                husbandId: husbandId,
                ordinal: ordinal,
                createdBy: createdBy,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HousesTable, HouseRow>(table),
                  BaseReferences<_$AppDatabase, $HousesTable, HouseRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HousesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HousesTable,
      HouseRow,
      $$HousesTableFilterComposer,
      $$HousesTableOrderingComposer,
      $$HousesTableAnnotationComposer,
      $$HousesTableCreateCompanionBuilder,
      $$HousesTableUpdateCompanionBuilder,
      (HouseRow, BaseReferences<_$AppDatabase, $HousesTable, HouseRow>),
      HouseRow,
      PrefetchHooks Function()
    >;
typedef $$ClaimsTableCreateCompanionBuilder = ClaimsCompanion Function({
  Value<int> localSeq,
  required String id,
  required ClaimKind kind,
  required String subjectId,
  Value<String?> objectId,
  Value<Basis?> basis,
  Value<String?> body,
  required String assertedBy,
  Value<String?> baseClaimId,
  Value<String> status,
  required DateTime createdAt,
});
typedef $$ClaimsTableUpdateCompanionBuilder = ClaimsCompanion Function({
  Value<int> localSeq,
  Value<String> id,
  Value<ClaimKind> kind,
  Value<String> subjectId,
  Value<String?> objectId,
  Value<Basis?> basis,
  Value<String?> body,
  Value<String> assertedBy,
  Value<String?> baseClaimId,
  Value<String> status,
  Value<DateTime> createdAt,
});

class $$ClaimsTableFilterComposer
    extends Composer<_$AppDatabase, $ClaimsTable> {
  $$ClaimsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get localSeq => $composableBuilder(
    column: $table.localSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ClaimKind, ClaimKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get objectId => $composableBuilder(
    column: $table.objectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Basis?, Basis, String> get basis =>
      $composableBuilder(
        column: $table.basis,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assertedBy => $composableBuilder(
    column: $table.assertedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseClaimId => $composableBuilder(
    column: $table.baseClaimId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClaimsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClaimsTable> {
  $$ClaimsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get localSeq => $composableBuilder(
    column: $table.localSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get objectId => $composableBuilder(
    column: $table.objectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get basis => $composableBuilder(
    column: $table.basis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assertedBy => $composableBuilder(
    column: $table.assertedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseClaimId => $composableBuilder(
    column: $table.baseClaimId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClaimsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClaimsTable> {
  $$ClaimsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get localSeq =>
      $composableBuilder(column: $table.localSeq, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ClaimKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get objectId =>
      $composableBuilder(column: $table.objectId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Basis?, String> get basis =>
      $composableBuilder(column: $table.basis, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get assertedBy => $composableBuilder(
    column: $table.assertedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseClaimId => $composableBuilder(
    column: $table.baseClaimId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ClaimsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClaimsTable,
          ClaimRow,
          $$ClaimsTableFilterComposer,
          $$ClaimsTableOrderingComposer,
          $$ClaimsTableAnnotationComposer,
          $$ClaimsTableCreateCompanionBuilder,
          $$ClaimsTableUpdateCompanionBuilder,
          (ClaimRow, BaseReferences<_$AppDatabase, $ClaimsTable, ClaimRow>),
          ClaimRow,
          PrefetchHooks Function()
        > {
  $$ClaimsTableTableManager(_$AppDatabase db, $ClaimsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClaimsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClaimsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClaimsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> localSeq = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<ClaimKind> kind = const Value.absent(),
                Value<String> subjectId = const Value.absent(),
                Value<String?> objectId = const Value.absent(),
                Value<Basis?> basis = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String> assertedBy = const Value.absent(),
                Value<String?> baseClaimId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ClaimsCompanion(
                localSeq: localSeq,
                id: id,
                kind: kind,
                subjectId: subjectId,
                objectId: objectId,
                basis: basis,
                body: body,
                assertedBy: assertedBy,
                baseClaimId: baseClaimId,
                status: status,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> localSeq = const Value.absent(),
                required String id,
                required ClaimKind kind,
                required String subjectId,
                Value<String?> objectId = const Value.absent(),
                Value<Basis?> basis = const Value.absent(),
                Value<String?> body = const Value.absent(),
                required String assertedBy,
                Value<String?> baseClaimId = const Value.absent(),
                Value<String> status = const Value.absent(),
                required DateTime createdAt,
              }) => ClaimsCompanion.insert(
                localSeq: localSeq,
                id: id,
                kind: kind,
                subjectId: subjectId,
                objectId: objectId,
                basis: basis,
                body: body,
                assertedBy: assertedBy,
                baseClaimId: baseClaimId,
                status: status,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ClaimsTable, ClaimRow>(table),
                  BaseReferences<_$AppDatabase, $ClaimsTable, ClaimRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClaimsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClaimsTable,
      ClaimRow,
      $$ClaimsTableFilterComposer,
      $$ClaimsTableOrderingComposer,
      $$ClaimsTableAnnotationComposer,
      $$ClaimsTableCreateCompanionBuilder,
      $$ClaimsTableUpdateCompanionBuilder,
      (ClaimRow, BaseReferences<_$AppDatabase, $ClaimsTable, ClaimRow>),
      ClaimRow,
      PrefetchHooks Function()
    >;
typedef $$PersonNamesTableCreateCompanionBuilder =
    PersonNamesCompanion Function({
      required String id,
      required String personId,
      required String name,
      required String kind,
      Value<int> rowid,
    });
typedef $$PersonNamesTableUpdateCompanionBuilder =
    PersonNamesCompanion Function({
      Value<String> id,
      Value<String> personId,
      Value<String> name,
      Value<String> kind,
      Value<int> rowid,
    });

class $$PersonNamesTableFilterComposer
    extends Composer<_$AppDatabase, $PersonNamesTable> {
  $$PersonNamesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PersonNamesTableOrderingComposer
    extends Composer<_$AppDatabase, $PersonNamesTable> {
  $$PersonNamesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get personId => $composableBuilder(
    column: $table.personId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PersonNamesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PersonNamesTable> {
  $$PersonNamesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get personId =>
      $composableBuilder(column: $table.personId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);
}

class $$PersonNamesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PersonNamesTable,
          PersonNameRow,
          $$PersonNamesTableFilterComposer,
          $$PersonNamesTableOrderingComposer,
          $$PersonNamesTableAnnotationComposer,
          $$PersonNamesTableCreateCompanionBuilder,
          $$PersonNamesTableUpdateCompanionBuilder,
          (
            PersonNameRow,
            BaseReferences<_$AppDatabase, $PersonNamesTable, PersonNameRow>,
          ),
          PersonNameRow,
          PrefetchHooks Function()
        > {
  $$PersonNamesTableTableManager(_$AppDatabase db, $PersonNamesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PersonNamesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PersonNamesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PersonNamesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> personId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PersonNamesCompanion(
                id: id,
                personId: personId,
                name: name,
                kind: kind,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String personId,
                required String name,
                required String kind,
                Value<int> rowid = const Value.absent(),
              }) => PersonNamesCompanion.insert(
                id: id,
                personId: personId,
                name: name,
                kind: kind,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PersonNamesTable, PersonNameRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PersonNamesTable,
                    PersonNameRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PersonNamesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PersonNamesTable,
      PersonNameRow,
      $$PersonNamesTableFilterComposer,
      $$PersonNamesTableOrderingComposer,
      $$PersonNamesTableAnnotationComposer,
      $$PersonNamesTableCreateCompanionBuilder,
      $$PersonNamesTableUpdateCompanionBuilder,
      (
        PersonNameRow,
        BaseReferences<_$AppDatabase, $PersonNamesTable, PersonNameRow>,
      ),
      PersonNameRow,
      PrefetchHooks Function()
    >;
typedef $$FieldEditsTableCreateCompanionBuilder = FieldEditsCompanion Function({
  Value<int> localSeq,
  required String id,
  required String entity,
  required String entityId,
  required String field,
  Value<String?> value,
  required String assertedBy,
});
typedef $$FieldEditsTableUpdateCompanionBuilder = FieldEditsCompanion Function({
  Value<int> localSeq,
  Value<String> id,
  Value<String> entity,
  Value<String> entityId,
  Value<String> field,
  Value<String?> value,
  Value<String> assertedBy,
});

class $$FieldEditsTableFilterComposer
    extends Composer<_$AppDatabase, $FieldEditsTable> {
  $$FieldEditsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get localSeq => $composableBuilder(
    column: $table.localSeq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assertedBy => $composableBuilder(
    column: $table.assertedBy,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FieldEditsTableOrderingComposer
    extends Composer<_$AppDatabase, $FieldEditsTable> {
  $$FieldEditsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get localSeq => $composableBuilder(
    column: $table.localSeq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assertedBy => $composableBuilder(
    column: $table.assertedBy,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FieldEditsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FieldEditsTable> {
  $$FieldEditsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get localSeq =>
      $composableBuilder(column: $table.localSeq, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get field =>
      $composableBuilder(column: $table.field, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get assertedBy => $composableBuilder(
    column: $table.assertedBy,
    builder: (column) => column,
  );
}

class $$FieldEditsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FieldEditsTable,
          FieldEditRow,
          $$FieldEditsTableFilterComposer,
          $$FieldEditsTableOrderingComposer,
          $$FieldEditsTableAnnotationComposer,
          $$FieldEditsTableCreateCompanionBuilder,
          $$FieldEditsTableUpdateCompanionBuilder,
          (
            FieldEditRow,
            BaseReferences<_$AppDatabase, $FieldEditsTable, FieldEditRow>,
          ),
          FieldEditRow,
          PrefetchHooks Function()
        > {
  $$FieldEditsTableTableManager(_$AppDatabase db, $FieldEditsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FieldEditsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FieldEditsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FieldEditsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> localSeq = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> field = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<String> assertedBy = const Value.absent(),
              }) => FieldEditsCompanion(
                localSeq: localSeq,
                id: id,
                entity: entity,
                entityId: entityId,
                field: field,
                value: value,
                assertedBy: assertedBy,
              ),
          createCompanionCallback:
              ({
                Value<int> localSeq = const Value.absent(),
                required String id,
                required String entity,
                required String entityId,
                required String field,
                Value<String?> value = const Value.absent(),
                required String assertedBy,
              }) => FieldEditsCompanion.insert(
                localSeq: localSeq,
                id: id,
                entity: entity,
                entityId: entityId,
                field: field,
                value: value,
                assertedBy: assertedBy,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FieldEditsTable, FieldEditRow>(table),
                  BaseReferences<_$AppDatabase, $FieldEditsTable, FieldEditRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FieldEditsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FieldEditsTable,
      FieldEditRow,
      $$FieldEditsTableFilterComposer,
      $$FieldEditsTableOrderingComposer,
      $$FieldEditsTableAnnotationComposer,
      $$FieldEditsTableCreateCompanionBuilder,
      $$FieldEditsTableUpdateCompanionBuilder,
      (
        FieldEditRow,
        BaseReferences<_$AppDatabase, $FieldEditsTable, FieldEditRow>,
      ),
      FieldEditRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PersonsTableTableManager get persons =>
      $$PersonsTableTableManager(_db, _db.persons);
  $$HousesTableTableManager get houses =>
      $$HousesTableTableManager(_db, _db.houses);
  $$ClaimsTableTableManager get claims =>
      $$ClaimsTableTableManager(_db, _db.claims);
  $$PersonNamesTableTableManager get personNames =>
      $$PersonNamesTableTableManager(_db, _db.personNames);
  $$FieldEditsTableTableManager get fieldEdits =>
      $$FieldEditsTableTableManager(_db, _db.fieldEdits);
}
