// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isProtectedMeta = const VerificationMeta(
    'isProtected',
  );
  @override
  late final GeneratedColumn<bool> isProtected = GeneratedColumn<bool>(
    'is_protected',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_protected" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _creditLimitMeta = const VerificationMeta(
    'creditLimit',
  );
  @override
  late final GeneratedColumn<double> creditLimit = GeneratedColumn<double>(
    'credit_limit',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _closingDayMeta = const VerificationMeta(
    'closingDay',
  );
  @override
  late final GeneratedColumn<int> closingDay = GeneratedColumn<int>(
    'closing_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _paymentDayMeta = const VerificationMeta(
    'paymentDay',
  );
  @override
  late final GeneratedColumn<int> paymentDay = GeneratedColumn<int>(
    'payment_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _interestRateMeta = const VerificationMeta(
    'interestRate',
  );
  @override
  late final GeneratedColumn<double> interestRate = GeneratedColumn<double>(
    'interest_rate',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minimumPaymentPctMeta = const VerificationMeta(
    'minimumPaymentPct',
  );
  @override
  late final GeneratedColumn<double> minimumPaymentPct =
      GeneratedColumn<double>(
        'minimum_payment_pct',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _minimumCapitalPctMeta = const VerificationMeta(
    'minimumCapitalPct',
  );
  @override
  late final GeneratedColumn<double> minimumCapitalPct =
      GeneratedColumn<double>(
        'minimum_capital_pct',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0.015),
      );
  static const VerificationMeta _minimumFloorMeta = const VerificationMeta(
    'minimumFloor',
  );
  @override
  late final GeneratedColumn<double> minimumFloor = GeneratedColumn<double>(
    'minimum_floor',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(150),
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    description,
    isProtected,
    creditLimit,
    closingDay,
    paymentDay,
    interestRate,
    minimumPaymentPct,
    minimumCapitalPct,
    minimumFloor,
    createdAt,
    updatedAt,
    deletedAt,
    archivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Account> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('is_protected')) {
      context.handle(
        _isProtectedMeta,
        isProtected.isAcceptableOrUnknown(
          data['is_protected']!,
          _isProtectedMeta,
        ),
      );
    }
    if (data.containsKey('credit_limit')) {
      context.handle(
        _creditLimitMeta,
        creditLimit.isAcceptableOrUnknown(
          data['credit_limit']!,
          _creditLimitMeta,
        ),
      );
    }
    if (data.containsKey('closing_day')) {
      context.handle(
        _closingDayMeta,
        closingDay.isAcceptableOrUnknown(data['closing_day']!, _closingDayMeta),
      );
    }
    if (data.containsKey('payment_day')) {
      context.handle(
        _paymentDayMeta,
        paymentDay.isAcceptableOrUnknown(data['payment_day']!, _paymentDayMeta),
      );
    }
    if (data.containsKey('interest_rate')) {
      context.handle(
        _interestRateMeta,
        interestRate.isAcceptableOrUnknown(
          data['interest_rate']!,
          _interestRateMeta,
        ),
      );
    }
    if (data.containsKey('minimum_payment_pct')) {
      context.handle(
        _minimumPaymentPctMeta,
        minimumPaymentPct.isAcceptableOrUnknown(
          data['minimum_payment_pct']!,
          _minimumPaymentPctMeta,
        ),
      );
    }
    if (data.containsKey('minimum_capital_pct')) {
      context.handle(
        _minimumCapitalPctMeta,
        minimumCapitalPct.isAcceptableOrUnknown(
          data['minimum_capital_pct']!,
          _minimumCapitalPctMeta,
        ),
      );
    }
    if (data.containsKey('minimum_floor')) {
      context.handle(
        _minimumFloorMeta,
        minimumFloor.isAcceptableOrUnknown(
          data['minimum_floor']!,
          _minimumFloorMeta,
        ),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      type:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}type'],
          )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      isProtected:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_protected'],
          )!,
      creditLimit:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}credit_limit'],
          )!,
      closingDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}closing_day'],
      ),
      paymentDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}payment_day'],
      ),
      interestRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}interest_rate'],
      ),
      minimumPaymentPct: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}minimum_payment_pct'],
      ),
      minimumCapitalPct:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}minimum_capital_pct'],
          )!,
      minimumFloor:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}minimum_floor'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class Account extends DataClass implements Insertable<Account> {
  final String id;
  final String name;
  final String type;
  final String? description;
  final bool isProtected;
  final double creditLimit;
  final int? closingDay;
  final int? paymentDay;
  final double? interestRate;
  final double? minimumPaymentPct;
  final double minimumCapitalPct;
  final double minimumFloor;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? archivedAt;
  const Account({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    required this.isProtected,
    required this.creditLimit,
    this.closingDay,
    this.paymentDay,
    this.interestRate,
    this.minimumPaymentPct,
    required this.minimumCapitalPct,
    required this.minimumFloor,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.archivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['is_protected'] = Variable<bool>(isProtected);
    map['credit_limit'] = Variable<double>(creditLimit);
    if (!nullToAbsent || closingDay != null) {
      map['closing_day'] = Variable<int>(closingDay);
    }
    if (!nullToAbsent || paymentDay != null) {
      map['payment_day'] = Variable<int>(paymentDay);
    }
    if (!nullToAbsent || interestRate != null) {
      map['interest_rate'] = Variable<double>(interestRate);
    }
    if (!nullToAbsent || minimumPaymentPct != null) {
      map['minimum_payment_pct'] = Variable<double>(minimumPaymentPct);
    }
    map['minimum_capital_pct'] = Variable<double>(minimumCapitalPct);
    map['minimum_floor'] = Variable<double>(minimumFloor);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      description:
          description == null && nullToAbsent
              ? const Value.absent()
              : Value(description),
      isProtected: Value(isProtected),
      creditLimit: Value(creditLimit),
      closingDay:
          closingDay == null && nullToAbsent
              ? const Value.absent()
              : Value(closingDay),
      paymentDay:
          paymentDay == null && nullToAbsent
              ? const Value.absent()
              : Value(paymentDay),
      interestRate:
          interestRate == null && nullToAbsent
              ? const Value.absent()
              : Value(interestRate),
      minimumPaymentPct:
          minimumPaymentPct == null && nullToAbsent
              ? const Value.absent()
              : Value(minimumPaymentPct),
      minimumCapitalPct: Value(minimumCapitalPct),
      minimumFloor: Value(minimumFloor),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt:
          deletedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(deletedAt),
      archivedAt:
          archivedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(archivedAt),
    );
  }

  factory Account.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      description: serializer.fromJson<String?>(json['description']),
      isProtected: serializer.fromJson<bool>(json['isProtected']),
      creditLimit: serializer.fromJson<double>(json['creditLimit']),
      closingDay: serializer.fromJson<int?>(json['closingDay']),
      paymentDay: serializer.fromJson<int?>(json['paymentDay']),
      interestRate: serializer.fromJson<double?>(json['interestRate']),
      minimumPaymentPct: serializer.fromJson<double?>(
        json['minimumPaymentPct'],
      ),
      minimumCapitalPct: serializer.fromJson<double>(json['minimumCapitalPct']),
      minimumFloor: serializer.fromJson<double>(json['minimumFloor']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'description': serializer.toJson<String?>(description),
      'isProtected': serializer.toJson<bool>(isProtected),
      'creditLimit': serializer.toJson<double>(creditLimit),
      'closingDay': serializer.toJson<int?>(closingDay),
      'paymentDay': serializer.toJson<int?>(paymentDay),
      'interestRate': serializer.toJson<double?>(interestRate),
      'minimumPaymentPct': serializer.toJson<double?>(minimumPaymentPct),
      'minimumCapitalPct': serializer.toJson<double>(minimumCapitalPct),
      'minimumFloor': serializer.toJson<double>(minimumFloor),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
    };
  }

  Account copyWith({
    String? id,
    String? name,
    String? type,
    Value<String?> description = const Value.absent(),
    bool? isProtected,
    double? creditLimit,
    Value<int?> closingDay = const Value.absent(),
    Value<int?> paymentDay = const Value.absent(),
    Value<double?> interestRate = const Value.absent(),
    Value<double?> minimumPaymentPct = const Value.absent(),
    double? minimumCapitalPct,
    double? minimumFloor,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<DateTime?> archivedAt = const Value.absent(),
  }) => Account(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    description: description.present ? description.value : this.description,
    isProtected: isProtected ?? this.isProtected,
    creditLimit: creditLimit ?? this.creditLimit,
    closingDay: closingDay.present ? closingDay.value : this.closingDay,
    paymentDay: paymentDay.present ? paymentDay.value : this.paymentDay,
    interestRate: interestRate.present ? interestRate.value : this.interestRate,
    minimumPaymentPct:
        minimumPaymentPct.present
            ? minimumPaymentPct.value
            : this.minimumPaymentPct,
    minimumCapitalPct: minimumCapitalPct ?? this.minimumCapitalPct,
    minimumFloor: minimumFloor ?? this.minimumFloor,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      description:
          data.description.present ? data.description.value : this.description,
      isProtected:
          data.isProtected.present ? data.isProtected.value : this.isProtected,
      creditLimit:
          data.creditLimit.present ? data.creditLimit.value : this.creditLimit,
      closingDay:
          data.closingDay.present ? data.closingDay.value : this.closingDay,
      paymentDay:
          data.paymentDay.present ? data.paymentDay.value : this.paymentDay,
      interestRate:
          data.interestRate.present
              ? data.interestRate.value
              : this.interestRate,
      minimumPaymentPct:
          data.minimumPaymentPct.present
              ? data.minimumPaymentPct.value
              : this.minimumPaymentPct,
      minimumCapitalPct:
          data.minimumCapitalPct.present
              ? data.minimumCapitalPct.value
              : this.minimumCapitalPct,
      minimumFloor:
          data.minimumFloor.present
              ? data.minimumFloor.value
              : this.minimumFloor,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      archivedAt:
          data.archivedAt.present ? data.archivedAt.value : this.archivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('description: $description, ')
          ..write('isProtected: $isProtected, ')
          ..write('creditLimit: $creditLimit, ')
          ..write('closingDay: $closingDay, ')
          ..write('paymentDay: $paymentDay, ')
          ..write('interestRate: $interestRate, ')
          ..write('minimumPaymentPct: $minimumPaymentPct, ')
          ..write('minimumCapitalPct: $minimumCapitalPct, ')
          ..write('minimumFloor: $minimumFloor, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('archivedAt: $archivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    description,
    isProtected,
    creditLimit,
    closingDay,
    paymentDay,
    interestRate,
    minimumPaymentPct,
    minimumCapitalPct,
    minimumFloor,
    createdAt,
    updatedAt,
    deletedAt,
    archivedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.description == this.description &&
          other.isProtected == this.isProtected &&
          other.creditLimit == this.creditLimit &&
          other.closingDay == this.closingDay &&
          other.paymentDay == this.paymentDay &&
          other.interestRate == this.interestRate &&
          other.minimumPaymentPct == this.minimumPaymentPct &&
          other.minimumCapitalPct == this.minimumCapitalPct &&
          other.minimumFloor == this.minimumFloor &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.archivedAt == this.archivedAt);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> description;
  final Value<bool> isProtected;
  final Value<double> creditLimit;
  final Value<int?> closingDay;
  final Value<int?> paymentDay;
  final Value<double?> interestRate;
  final Value<double?> minimumPaymentPct;
  final Value<double> minimumCapitalPct;
  final Value<double> minimumFloor;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<DateTime?> archivedAt;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.description = const Value.absent(),
    this.isProtected = const Value.absent(),
    this.creditLimit = const Value.absent(),
    this.closingDay = const Value.absent(),
    this.paymentDay = const Value.absent(),
    this.interestRate = const Value.absent(),
    this.minimumPaymentPct = const Value.absent(),
    this.minimumCapitalPct = const Value.absent(),
    this.minimumFloor = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String id,
    required String name,
    required String type,
    this.description = const Value.absent(),
    this.isProtected = const Value.absent(),
    this.creditLimit = const Value.absent(),
    this.closingDay = const Value.absent(),
    this.paymentDay = const Value.absent(),
    this.interestRate = const Value.absent(),
    this.minimumPaymentPct = const Value.absent(),
    this.minimumCapitalPct = const Value.absent(),
    this.minimumFloor = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       type = Value(type),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Account> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? description,
    Expression<bool>? isProtected,
    Expression<double>? creditLimit,
    Expression<int>? closingDay,
    Expression<int>? paymentDay,
    Expression<double>? interestRate,
    Expression<double>? minimumPaymentPct,
    Expression<double>? minimumCapitalPct,
    Expression<double>? minimumFloor,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? archivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (description != null) 'description': description,
      if (isProtected != null) 'is_protected': isProtected,
      if (creditLimit != null) 'credit_limit': creditLimit,
      if (closingDay != null) 'closing_day': closingDay,
      if (paymentDay != null) 'payment_day': paymentDay,
      if (interestRate != null) 'interest_rate': interestRate,
      if (minimumPaymentPct != null) 'minimum_payment_pct': minimumPaymentPct,
      if (minimumCapitalPct != null) 'minimum_capital_pct': minimumCapitalPct,
      if (minimumFloor != null) 'minimum_floor': minimumFloor,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String?>? description,
    Value<bool>? isProtected,
    Value<double>? creditLimit,
    Value<int?>? closingDay,
    Value<int?>? paymentDay,
    Value<double?>? interestRate,
    Value<double?>? minimumPaymentPct,
    Value<double>? minimumCapitalPct,
    Value<double>? minimumFloor,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<DateTime?>? archivedAt,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      description: description ?? this.description,
      isProtected: isProtected ?? this.isProtected,
      creditLimit: creditLimit ?? this.creditLimit,
      closingDay: closingDay ?? this.closingDay,
      paymentDay: paymentDay ?? this.paymentDay,
      interestRate: interestRate ?? this.interestRate,
      minimumPaymentPct: minimumPaymentPct ?? this.minimumPaymentPct,
      minimumCapitalPct: minimumCapitalPct ?? this.minimumCapitalPct,
      minimumFloor: minimumFloor ?? this.minimumFloor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (isProtected.present) {
      map['is_protected'] = Variable<bool>(isProtected.value);
    }
    if (creditLimit.present) {
      map['credit_limit'] = Variable<double>(creditLimit.value);
    }
    if (closingDay.present) {
      map['closing_day'] = Variable<int>(closingDay.value);
    }
    if (paymentDay.present) {
      map['payment_day'] = Variable<int>(paymentDay.value);
    }
    if (interestRate.present) {
      map['interest_rate'] = Variable<double>(interestRate.value);
    }
    if (minimumPaymentPct.present) {
      map['minimum_payment_pct'] = Variable<double>(minimumPaymentPct.value);
    }
    if (minimumCapitalPct.present) {
      map['minimum_capital_pct'] = Variable<double>(minimumCapitalPct.value);
    }
    if (minimumFloor.present) {
      map['minimum_floor'] = Variable<double>(minimumFloor.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('description: $description, ')
          ..write('isProtected: $isProtected, ')
          ..write('creditLimit: $creditLimit, ')
          ..write('closingDay: $closingDay, ')
          ..write('paymentDay: $paymentDay, ')
          ..write('interestRate: $interestRate, ')
          ..write('minimumPaymentPct: $minimumPaymentPct, ')
          ..write('minimumCapitalPct: $minimumCapitalPct, ')
          ..write('minimumFloor: $minimumFloor, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _appliesToMeta = const VerificationMeta(
    'appliesTo',
  );
  @override
  late final GeneratedColumn<String> appliesTo = GeneratedColumn<String>(
    'applies_to',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorSlugMeta = const VerificationMeta(
    'colorSlug',
  );
  @override
  late final GeneratedColumn<String> colorSlug = GeneratedColumn<String>(
    'color_slug',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconSlugMeta = const VerificationMeta(
    'iconSlug',
  );
  @override
  late final GeneratedColumn<String> iconSlug = GeneratedColumn<String>(
    'icon_slug',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthlyLimitMeta = const VerificationMeta(
    'monthlyLimit',
  );
  @override
  late final GeneratedColumn<double> monthlyLimit = GeneratedColumn<double>(
    'monthly_limit',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
    name,
    appliesTo,
    colorSlug,
    iconSlug,
    monthlyLimit,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('applies_to')) {
      context.handle(
        _appliesToMeta,
        appliesTo.isAcceptableOrUnknown(data['applies_to']!, _appliesToMeta),
      );
    } else if (isInserting) {
      context.missing(_appliesToMeta);
    }
    if (data.containsKey('color_slug')) {
      context.handle(
        _colorSlugMeta,
        colorSlug.isAcceptableOrUnknown(data['color_slug']!, _colorSlugMeta),
      );
    } else if (isInserting) {
      context.missing(_colorSlugMeta);
    }
    if (data.containsKey('icon_slug')) {
      context.handle(
        _iconSlugMeta,
        iconSlug.isAcceptableOrUnknown(data['icon_slug']!, _iconSlugMeta),
      );
    } else if (isInserting) {
      context.missing(_iconSlugMeta);
    }
    if (data.containsKey('monthly_limit')) {
      context.handle(
        _monthlyLimitMeta,
        monthlyLimit.isAcceptableOrUnknown(
          data['monthly_limit']!,
          _monthlyLimitMeta,
        ),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
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
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      appliesTo:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}applies_to'],
          )!,
      colorSlug:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}color_slug'],
          )!,
      iconSlug:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}icon_slug'],
          )!,
      monthlyLimit: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monthly_limit'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final String id;
  final String name;
  final String appliesTo;
  final String colorSlug;
  final String iconSlug;
  final double? monthlyLimit;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Category({
    required this.id,
    required this.name,
    required this.appliesTo,
    required this.colorSlug,
    required this.iconSlug,
    this.monthlyLimit,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['applies_to'] = Variable<String>(appliesTo);
    map['color_slug'] = Variable<String>(colorSlug);
    map['icon_slug'] = Variable<String>(iconSlug);
    if (!nullToAbsent || monthlyLimit != null) {
      map['monthly_limit'] = Variable<double>(monthlyLimit);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      appliesTo: Value(appliesTo),
      colorSlug: Value(colorSlug),
      iconSlug: Value(iconSlug),
      monthlyLimit:
          monthlyLimit == null && nullToAbsent
              ? const Value.absent()
              : Value(monthlyLimit),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt:
          deletedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(deletedAt),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      appliesTo: serializer.fromJson<String>(json['appliesTo']),
      colorSlug: serializer.fromJson<String>(json['colorSlug']),
      iconSlug: serializer.fromJson<String>(json['iconSlug']),
      monthlyLimit: serializer.fromJson<double?>(json['monthlyLimit']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'appliesTo': serializer.toJson<String>(appliesTo),
      'colorSlug': serializer.toJson<String>(colorSlug),
      'iconSlug': serializer.toJson<String>(iconSlug),
      'monthlyLimit': serializer.toJson<double?>(monthlyLimit),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Category copyWith({
    String? id,
    String? name,
    String? appliesTo,
    String? colorSlug,
    String? iconSlug,
    Value<double?> monthlyLimit = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    appliesTo: appliesTo ?? this.appliesTo,
    colorSlug: colorSlug ?? this.colorSlug,
    iconSlug: iconSlug ?? this.iconSlug,
    monthlyLimit: monthlyLimit.present ? monthlyLimit.value : this.monthlyLimit,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      appliesTo: data.appliesTo.present ? data.appliesTo.value : this.appliesTo,
      colorSlug: data.colorSlug.present ? data.colorSlug.value : this.colorSlug,
      iconSlug: data.iconSlug.present ? data.iconSlug.value : this.iconSlug,
      monthlyLimit:
          data.monthlyLimit.present
              ? data.monthlyLimit.value
              : this.monthlyLimit,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('appliesTo: $appliesTo, ')
          ..write('colorSlug: $colorSlug, ')
          ..write('iconSlug: $iconSlug, ')
          ..write('monthlyLimit: $monthlyLimit, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    appliesTo,
    colorSlug,
    iconSlug,
    monthlyLimit,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.name == this.name &&
          other.appliesTo == this.appliesTo &&
          other.colorSlug == this.colorSlug &&
          other.iconSlug == this.iconSlug &&
          other.monthlyLimit == this.monthlyLimit &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> appliesTo;
  final Value<String> colorSlug;
  final Value<String> iconSlug;
  final Value<double?> monthlyLimit;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.appliesTo = const Value.absent(),
    this.colorSlug = const Value.absent(),
    this.iconSlug = const Value.absent(),
    this.monthlyLimit = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String name,
    required String appliesTo,
    required String colorSlug,
    required String iconSlug,
    this.monthlyLimit = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       appliesTo = Value(appliesTo),
       colorSlug = Value(colorSlug),
       iconSlug = Value(iconSlug),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Category> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? appliesTo,
    Expression<String>? colorSlug,
    Expression<String>? iconSlug,
    Expression<double>? monthlyLimit,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (appliesTo != null) 'applies_to': appliesTo,
      if (colorSlug != null) 'color_slug': colorSlug,
      if (iconSlug != null) 'icon_slug': iconSlug,
      if (monthlyLimit != null) 'monthly_limit': monthlyLimit,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? appliesTo,
    Value<String>? colorSlug,
    Value<String>? iconSlug,
    Value<double?>? monthlyLimit,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      appliesTo: appliesTo ?? this.appliesTo,
      colorSlug: colorSlug ?? this.colorSlug,
      iconSlug: iconSlug ?? this.iconSlug,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (appliesTo.present) {
      map['applies_to'] = Variable<String>(appliesTo.value);
    }
    if (colorSlug.present) {
      map['color_slug'] = Variable<String>(colorSlug.value);
    }
    if (iconSlug.present) {
      map['icon_slug'] = Variable<String>(iconSlug.value);
    }
    if (monthlyLimit.present) {
      map['monthly_limit'] = Variable<double>(monthlyLimit.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
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
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('appliesTo: $appliesTo, ')
          ..write('colorSlug: $colorSlug, ')
          ..write('iconSlug: $iconSlug, ')
          ..write('monthlyLimit: $monthlyLimit, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $JournalEntriesTable extends JournalEntries
    with TableInfo<$JournalEntriesTable, JournalEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JournalEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _accountOriginIdMeta = const VerificationMeta(
    'accountOriginId',
  );
  @override
  late final GeneratedColumn<String> accountOriginId = GeneratedColumn<String>(
    'account_origin_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _accountDestinationIdMeta =
      const VerificationMeta('accountDestinationId');
  @override
  late final GeneratedColumn<String> accountDestinationId =
      GeneratedColumn<String>(
        'account_destination_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES accounts (id)',
        ),
      );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
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
    kind,
    accountOriginId,
    accountDestinationId,
    amount,
    description,
    occurredAt,
    categoryId,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'journal_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<JournalEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('account_origin_id')) {
      context.handle(
        _accountOriginIdMeta,
        accountOriginId.isAcceptableOrUnknown(
          data['account_origin_id']!,
          _accountOriginIdMeta,
        ),
      );
    }
    if (data.containsKey('account_destination_id')) {
      context.handle(
        _accountDestinationIdMeta,
        accountDestinationId.isAcceptableOrUnknown(
          data['account_destination_id']!,
          _accountDestinationIdMeta,
        ),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
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
  JournalEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JournalEntry(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      kind:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}kind'],
          )!,
      accountOriginId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_origin_id'],
      ),
      accountDestinationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_destination_id'],
      ),
      amount:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}amount'],
          )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      occurredAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}occurred_at'],
          )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $JournalEntriesTable createAlias(String alias) {
    return $JournalEntriesTable(attachedDatabase, alias);
  }
}

class JournalEntry extends DataClass implements Insertable<JournalEntry> {
  final String id;
  final String kind;
  final String? accountOriginId;
  final String? accountDestinationId;
  final double amount;
  final String? description;
  final DateTime occurredAt;
  final String? categoryId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const JournalEntry({
    required this.id,
    required this.kind,
    this.accountOriginId,
    this.accountDestinationId,
    required this.amount,
    this.description,
    required this.occurredAt,
    this.categoryId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || accountOriginId != null) {
      map['account_origin_id'] = Variable<String>(accountOriginId);
    }
    if (!nullToAbsent || accountDestinationId != null) {
      map['account_destination_id'] = Variable<String>(accountDestinationId);
    }
    map['amount'] = Variable<double>(amount);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  JournalEntriesCompanion toCompanion(bool nullToAbsent) {
    return JournalEntriesCompanion(
      id: Value(id),
      kind: Value(kind),
      accountOriginId:
          accountOriginId == null && nullToAbsent
              ? const Value.absent()
              : Value(accountOriginId),
      accountDestinationId:
          accountDestinationId == null && nullToAbsent
              ? const Value.absent()
              : Value(accountDestinationId),
      amount: Value(amount),
      description:
          description == null && nullToAbsent
              ? const Value.absent()
              : Value(description),
      occurredAt: Value(occurredAt),
      categoryId:
          categoryId == null && nullToAbsent
              ? const Value.absent()
              : Value(categoryId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt:
          deletedAt == null && nullToAbsent
              ? const Value.absent()
              : Value(deletedAt),
    );
  }

  factory JournalEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JournalEntry(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      accountOriginId: serializer.fromJson<String?>(json['accountOriginId']),
      accountDestinationId: serializer.fromJson<String?>(
        json['accountDestinationId'],
      ),
      amount: serializer.fromJson<double>(json['amount']),
      description: serializer.fromJson<String?>(json['description']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'accountOriginId': serializer.toJson<String?>(accountOriginId),
      'accountDestinationId': serializer.toJson<String?>(accountDestinationId),
      'amount': serializer.toJson<double>(amount),
      'description': serializer.toJson<String?>(description),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'categoryId': serializer.toJson<String?>(categoryId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  JournalEntry copyWith({
    String? id,
    String? kind,
    Value<String?> accountOriginId = const Value.absent(),
    Value<String?> accountDestinationId = const Value.absent(),
    double? amount,
    Value<String?> description = const Value.absent(),
    DateTime? occurredAt,
    Value<String?> categoryId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => JournalEntry(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    accountOriginId:
        accountOriginId.present ? accountOriginId.value : this.accountOriginId,
    accountDestinationId:
        accountDestinationId.present
            ? accountDestinationId.value
            : this.accountDestinationId,
    amount: amount ?? this.amount,
    description: description.present ? description.value : this.description,
    occurredAt: occurredAt ?? this.occurredAt,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  JournalEntry copyWithCompanion(JournalEntriesCompanion data) {
    return JournalEntry(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      accountOriginId:
          data.accountOriginId.present
              ? data.accountOriginId.value
              : this.accountOriginId,
      accountDestinationId:
          data.accountDestinationId.present
              ? data.accountDestinationId.value
              : this.accountDestinationId,
      amount: data.amount.present ? data.amount.value : this.amount,
      description:
          data.description.present ? data.description.value : this.description,
      occurredAt:
          data.occurredAt.present ? data.occurredAt.value : this.occurredAt,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JournalEntry(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('accountOriginId: $accountOriginId, ')
          ..write('accountDestinationId: $accountDestinationId, ')
          ..write('amount: $amount, ')
          ..write('description: $description, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('categoryId: $categoryId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    accountOriginId,
    accountDestinationId,
    amount,
    description,
    occurredAt,
    categoryId,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JournalEntry &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.accountOriginId == this.accountOriginId &&
          other.accountDestinationId == this.accountDestinationId &&
          other.amount == this.amount &&
          other.description == this.description &&
          other.occurredAt == this.occurredAt &&
          other.categoryId == this.categoryId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class JournalEntriesCompanion extends UpdateCompanion<JournalEntry> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String?> accountOriginId;
  final Value<String?> accountDestinationId;
  final Value<double> amount;
  final Value<String?> description;
  final Value<DateTime> occurredAt;
  final Value<String?> categoryId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const JournalEntriesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.accountOriginId = const Value.absent(),
    this.accountDestinationId = const Value.absent(),
    this.amount = const Value.absent(),
    this.description = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JournalEntriesCompanion.insert({
    required String id,
    required String kind,
    this.accountOriginId = const Value.absent(),
    this.accountDestinationId = const Value.absent(),
    required double amount,
    this.description = const Value.absent(),
    required DateTime occurredAt,
    this.categoryId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       amount = Value(amount),
       occurredAt = Value(occurredAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<JournalEntry> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? accountOriginId,
    Expression<String>? accountDestinationId,
    Expression<double>? amount,
    Expression<String>? description,
    Expression<DateTime>? occurredAt,
    Expression<String>? categoryId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (accountOriginId != null) 'account_origin_id': accountOriginId,
      if (accountDestinationId != null)
        'account_destination_id': accountDestinationId,
      if (amount != null) 'amount': amount,
      if (description != null) 'description': description,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (categoryId != null) 'category_id': categoryId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JournalEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String?>? accountOriginId,
    Value<String?>? accountDestinationId,
    Value<double>? amount,
    Value<String?>? description,
    Value<DateTime>? occurredAt,
    Value<String?>? categoryId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return JournalEntriesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      accountOriginId: accountOriginId ?? this.accountOriginId,
      accountDestinationId: accountDestinationId ?? this.accountDestinationId,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      occurredAt: occurredAt ?? this.occurredAt,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (accountOriginId.present) {
      map['account_origin_id'] = Variable<String>(accountOriginId.value);
    }
    if (accountDestinationId.present) {
      map['account_destination_id'] = Variable<String>(
        accountDestinationId.value,
      );
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
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
    return (StringBuffer('JournalEntriesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('accountOriginId: $accountOriginId, ')
          ..write('accountDestinationId: $accountDestinationId, ')
          ..write('amount: $amount, ')
          ..write('description: $description, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('categoryId: $categoryId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SavedViewsTable extends SavedViews
    with TableInfo<$SavedViewsTable, SavedViewRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SavedViewsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _filtersJsonMeta = const VerificationMeta(
    'filtersJson',
  );
  @override
  late final GeneratedColumn<String> filtersJson = GeneratedColumn<String>(
    'filters_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  List<GeneratedColumn> get $columns => [id, name, filtersJson, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'saved_views';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedViewRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('filters_json')) {
      context.handle(
        _filtersJsonMeta,
        filtersJson.isAcceptableOrUnknown(
          data['filters_json']!,
          _filtersJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_filtersJsonMeta);
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SavedViewRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedViewRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      filtersJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}filters_json'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
    );
  }

  @override
  $SavedViewsTable createAlias(String alias) {
    return $SavedViewsTable(attachedDatabase, alias);
  }
}

class SavedViewRow extends DataClass implements Insertable<SavedViewRow> {
  final String id;
  final String name;
  final String filtersJson;
  final DateTime createdAt;
  const SavedViewRow({
    required this.id,
    required this.name,
    required this.filtersJson,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['filters_json'] = Variable<String>(filtersJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SavedViewsCompanion toCompanion(bool nullToAbsent) {
    return SavedViewsCompanion(
      id: Value(id),
      name: Value(name),
      filtersJson: Value(filtersJson),
      createdAt: Value(createdAt),
    );
  }

  factory SavedViewRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedViewRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      filtersJson: serializer.fromJson<String>(json['filtersJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'filtersJson': serializer.toJson<String>(filtersJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SavedViewRow copyWith({
    String? id,
    String? name,
    String? filtersJson,
    DateTime? createdAt,
  }) => SavedViewRow(
    id: id ?? this.id,
    name: name ?? this.name,
    filtersJson: filtersJson ?? this.filtersJson,
    createdAt: createdAt ?? this.createdAt,
  );
  SavedViewRow copyWithCompanion(SavedViewsCompanion data) {
    return SavedViewRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      filtersJson:
          data.filtersJson.present ? data.filtersJson.value : this.filtersJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedViewRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('filtersJson: $filtersJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, filtersJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedViewRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.filtersJson == this.filtersJson &&
          other.createdAt == this.createdAt);
}

class SavedViewsCompanion extends UpdateCompanion<SavedViewRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> filtersJson;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SavedViewsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.filtersJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SavedViewsCompanion.insert({
    required String id,
    required String name,
    required String filtersJson,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       filtersJson = Value(filtersJson),
       createdAt = Value(createdAt);
  static Insertable<SavedViewRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? filtersJson,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (filtersJson != null) 'filters_json': filtersJson,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SavedViewsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? filtersJson,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SavedViewsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      filtersJson: filtersJson ?? this.filtersJson,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (filtersJson.present) {
      map['filters_json'] = Variable<String>(filtersJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SavedViewsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('filtersJson: $filtersJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppPreferencesTable extends AppPreferences
    with TableInfo<$AppPreferencesTable, AppPreferenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppPreferenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppPreferenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppPreferenceRow(
      key:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}key'],
          )!,
      value:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}value'],
          )!,
    );
  }

  @override
  $AppPreferencesTable createAlias(String alias) {
    return $AppPreferencesTable(attachedDatabase, alias);
  }
}

class AppPreferenceRow extends DataClass
    implements Insertable<AppPreferenceRow> {
  final String key;
  final String value;
  const AppPreferenceRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppPreferencesCompanion toCompanion(bool nullToAbsent) {
    return AppPreferencesCompanion(key: Value(key), value: Value(value));
  }

  factory AppPreferenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppPreferenceRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppPreferenceRow copyWith({String? key, String? value}) =>
      AppPreferenceRow(key: key ?? this.key, value: value ?? this.value);
  AppPreferenceRow copyWithCompanion(AppPreferencesCompanion data) {
    return AppPreferenceRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppPreferenceRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppPreferenceRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppPreferencesCompanion extends UpdateCompanion<AppPreferenceRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppPreferencesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppPreferencesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppPreferenceRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppPreferencesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppPreferencesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppPreferencesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WeeklyBudgetsTable extends WeeklyBudgets
    with TableInfo<$WeeklyBudgetsTable, WeeklyBudgetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeeklyBudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weekStartDateMeta = const VerificationMeta(
    'weekStartDate',
  );
  @override
  late final GeneratedColumn<DateTime> weekStartDate =
      GeneratedColumn<DateTime>(
        'week_start_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isTemplateMeta = const VerificationMeta(
    'isTemplate',
  );
  @override
  late final GeneratedColumn<bool> isTemplate = GeneratedColumn<bool>(
    'is_template',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_template" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    weekStartDate,
    label,
    isTemplate,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weekly_budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<WeeklyBudgetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('week_start_date')) {
      context.handle(
        _weekStartDateMeta,
        weekStartDate.isAcceptableOrUnknown(
          data['week_start_date']!,
          _weekStartDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_weekStartDateMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('is_template')) {
      context.handle(
        _isTemplateMeta,
        isTemplate.isAcceptableOrUnknown(data['is_template']!, _isTemplateMeta),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WeeklyBudgetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeeklyBudgetRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      weekStartDate:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}week_start_date'],
          )!,
      label:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}label'],
          )!,
      isTemplate:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_template'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $WeeklyBudgetsTable createAlias(String alias) {
    return $WeeklyBudgetsTable(attachedDatabase, alias);
  }
}

class WeeklyBudgetRow extends DataClass implements Insertable<WeeklyBudgetRow> {
  final String id;
  final DateTime weekStartDate;
  final String label;
  final bool isTemplate;
  final DateTime createdAt;
  final DateTime updatedAt;
  const WeeklyBudgetRow({
    required this.id,
    required this.weekStartDate,
    required this.label,
    required this.isTemplate,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['week_start_date'] = Variable<DateTime>(weekStartDate);
    map['label'] = Variable<String>(label);
    map['is_template'] = Variable<bool>(isTemplate);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WeeklyBudgetsCompanion toCompanion(bool nullToAbsent) {
    return WeeklyBudgetsCompanion(
      id: Value(id),
      weekStartDate: Value(weekStartDate),
      label: Value(label),
      isTemplate: Value(isTemplate),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory WeeklyBudgetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeeklyBudgetRow(
      id: serializer.fromJson<String>(json['id']),
      weekStartDate: serializer.fromJson<DateTime>(json['weekStartDate']),
      label: serializer.fromJson<String>(json['label']),
      isTemplate: serializer.fromJson<bool>(json['isTemplate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'weekStartDate': serializer.toJson<DateTime>(weekStartDate),
      'label': serializer.toJson<String>(label),
      'isTemplate': serializer.toJson<bool>(isTemplate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  WeeklyBudgetRow copyWith({
    String? id,
    DateTime? weekStartDate,
    String? label,
    bool? isTemplate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => WeeklyBudgetRow(
    id: id ?? this.id,
    weekStartDate: weekStartDate ?? this.weekStartDate,
    label: label ?? this.label,
    isTemplate: isTemplate ?? this.isTemplate,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WeeklyBudgetRow copyWithCompanion(WeeklyBudgetsCompanion data) {
    return WeeklyBudgetRow(
      id: data.id.present ? data.id.value : this.id,
      weekStartDate:
          data.weekStartDate.present
              ? data.weekStartDate.value
              : this.weekStartDate,
      label: data.label.present ? data.label.value : this.label,
      isTemplate:
          data.isTemplate.present ? data.isTemplate.value : this.isTemplate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyBudgetRow(')
          ..write('id: $id, ')
          ..write('weekStartDate: $weekStartDate, ')
          ..write('label: $label, ')
          ..write('isTemplate: $isTemplate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, weekStartDate, label, isTemplate, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeeklyBudgetRow &&
          other.id == this.id &&
          other.weekStartDate == this.weekStartDate &&
          other.label == this.label &&
          other.isTemplate == this.isTemplate &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class WeeklyBudgetsCompanion extends UpdateCompanion<WeeklyBudgetRow> {
  final Value<String> id;
  final Value<DateTime> weekStartDate;
  final Value<String> label;
  final Value<bool> isTemplate;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const WeeklyBudgetsCompanion({
    this.id = const Value.absent(),
    this.weekStartDate = const Value.absent(),
    this.label = const Value.absent(),
    this.isTemplate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WeeklyBudgetsCompanion.insert({
    required String id,
    required DateTime weekStartDate,
    required String label,
    this.isTemplate = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       weekStartDate = Value(weekStartDate),
       label = Value(label),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<WeeklyBudgetRow> custom({
    Expression<String>? id,
    Expression<DateTime>? weekStartDate,
    Expression<String>? label,
    Expression<bool>? isTemplate,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (weekStartDate != null) 'week_start_date': weekStartDate,
      if (label != null) 'label': label,
      if (isTemplate != null) 'is_template': isTemplate,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WeeklyBudgetsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? weekStartDate,
    Value<String>? label,
    Value<bool>? isTemplate,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return WeeklyBudgetsCompanion(
      id: id ?? this.id,
      weekStartDate: weekStartDate ?? this.weekStartDate,
      label: label ?? this.label,
      isTemplate: isTemplate ?? this.isTemplate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (weekStartDate.present) {
      map['week_start_date'] = Variable<DateTime>(weekStartDate.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (isTemplate.present) {
      map['is_template'] = Variable<bool>(isTemplate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyBudgetsCompanion(')
          ..write('id: $id, ')
          ..write('weekStartDate: $weekStartDate, ')
          ..write('label: $label, ')
          ..write('isTemplate: $isTemplate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WeeklyBudgetItemsTable extends WeeklyBudgetItems
    with TableInfo<$WeeklyBudgetItemsTable, WeeklyBudgetItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeeklyBudgetItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _budgetIdMeta = const VerificationMeta(
    'budgetId',
  );
  @override
  late final GeneratedColumn<String> budgetId = GeneratedColumn<String>(
    'budget_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES weekly_budgets (id)',
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
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    budgetId,
    name,
    categoryId,
    amount,
    kind,
    sortOrder,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weekly_budget_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<WeeklyBudgetItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('budget_id')) {
      context.handle(
        _budgetIdMeta,
        budgetId.isAcceptableOrUnknown(data['budget_id']!, _budgetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_budgetIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WeeklyBudgetItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeeklyBudgetItemRow(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}id'],
          )!,
      budgetId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}budget_id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      amount:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}amount'],
          )!,
      kind:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}kind'],
          )!,
      sortOrder:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}sort_order'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      updatedAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}updated_at'],
          )!,
    );
  }

  @override
  $WeeklyBudgetItemsTable createAlias(String alias) {
    return $WeeklyBudgetItemsTable(attachedDatabase, alias);
  }
}

class WeeklyBudgetItemRow extends DataClass
    implements Insertable<WeeklyBudgetItemRow> {
  final String id;
  final String budgetId;
  final String name;
  final String? categoryId;
  final double amount;
  final String kind;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  const WeeklyBudgetItemRow({
    required this.id,
    required this.budgetId,
    required this.name,
    this.categoryId,
    required this.amount,
    required this.kind,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['budget_id'] = Variable<String>(budgetId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['amount'] = Variable<double>(amount);
    map['kind'] = Variable<String>(kind);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  WeeklyBudgetItemsCompanion toCompanion(bool nullToAbsent) {
    return WeeklyBudgetItemsCompanion(
      id: Value(id),
      budgetId: Value(budgetId),
      name: Value(name),
      categoryId:
          categoryId == null && nullToAbsent
              ? const Value.absent()
              : Value(categoryId),
      amount: Value(amount),
      kind: Value(kind),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory WeeklyBudgetItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeeklyBudgetItemRow(
      id: serializer.fromJson<String>(json['id']),
      budgetId: serializer.fromJson<String>(json['budgetId']),
      name: serializer.fromJson<String>(json['name']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      amount: serializer.fromJson<double>(json['amount']),
      kind: serializer.fromJson<String>(json['kind']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'budgetId': serializer.toJson<String>(budgetId),
      'name': serializer.toJson<String>(name),
      'categoryId': serializer.toJson<String?>(categoryId),
      'amount': serializer.toJson<double>(amount),
      'kind': serializer.toJson<String>(kind),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  WeeklyBudgetItemRow copyWith({
    String? id,
    String? budgetId,
    String? name,
    Value<String?> categoryId = const Value.absent(),
    double? amount,
    String? kind,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => WeeklyBudgetItemRow(
    id: id ?? this.id,
    budgetId: budgetId ?? this.budgetId,
    name: name ?? this.name,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    amount: amount ?? this.amount,
    kind: kind ?? this.kind,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  WeeklyBudgetItemRow copyWithCompanion(WeeklyBudgetItemsCompanion data) {
    return WeeklyBudgetItemRow(
      id: data.id.present ? data.id.value : this.id,
      budgetId: data.budgetId.present ? data.budgetId.value : this.budgetId,
      name: data.name.present ? data.name.value : this.name,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      amount: data.amount.present ? data.amount.value : this.amount,
      kind: data.kind.present ? data.kind.value : this.kind,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyBudgetItemRow(')
          ..write('id: $id, ')
          ..write('budgetId: $budgetId, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('kind: $kind, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    budgetId,
    name,
    categoryId,
    amount,
    kind,
    sortOrder,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeeklyBudgetItemRow &&
          other.id == this.id &&
          other.budgetId == this.budgetId &&
          other.name == this.name &&
          other.categoryId == this.categoryId &&
          other.amount == this.amount &&
          other.kind == this.kind &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class WeeklyBudgetItemsCompanion extends UpdateCompanion<WeeklyBudgetItemRow> {
  final Value<String> id;
  final Value<String> budgetId;
  final Value<String> name;
  final Value<String?> categoryId;
  final Value<double> amount;
  final Value<String> kind;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const WeeklyBudgetItemsCompanion({
    this.id = const Value.absent(),
    this.budgetId = const Value.absent(),
    this.name = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.amount = const Value.absent(),
    this.kind = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WeeklyBudgetItemsCompanion.insert({
    required String id,
    required String budgetId,
    required String name,
    this.categoryId = const Value.absent(),
    required double amount,
    required String kind,
    required int sortOrder,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       budgetId = Value(budgetId),
       name = Value(name),
       amount = Value(amount),
       kind = Value(kind),
       sortOrder = Value(sortOrder),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<WeeklyBudgetItemRow> custom({
    Expression<String>? id,
    Expression<String>? budgetId,
    Expression<String>? name,
    Expression<String>? categoryId,
    Expression<double>? amount,
    Expression<String>? kind,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (budgetId != null) 'budget_id': budgetId,
      if (name != null) 'name': name,
      if (categoryId != null) 'category_id': categoryId,
      if (amount != null) 'amount': amount,
      if (kind != null) 'kind': kind,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WeeklyBudgetItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? budgetId,
    Value<String>? name,
    Value<String?>? categoryId,
    Value<double>? amount,
    Value<String>? kind,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return WeeklyBudgetItemsCompanion(
      id: id ?? this.id,
      budgetId: budgetId ?? this.budgetId,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      kind: kind ?? this.kind,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (budgetId.present) {
      map['budget_id'] = Variable<String>(budgetId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyBudgetItemsCompanion(')
          ..write('id: $id, ')
          ..write('budgetId: $budgetId, ')
          ..write('name: $name, ')
          ..write('categoryId: $categoryId, ')
          ..write('amount: $amount, ')
          ..write('kind: $kind, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$FincoreDatabase extends GeneratedDatabase {
  _$FincoreDatabase(QueryExecutor e) : super(e);
  $FincoreDatabaseManager get managers => $FincoreDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $JournalEntriesTable journalEntries = $JournalEntriesTable(this);
  late final $SavedViewsTable savedViews = $SavedViewsTable(this);
  late final $AppPreferencesTable appPreferences = $AppPreferencesTable(this);
  late final $WeeklyBudgetsTable weeklyBudgets = $WeeklyBudgetsTable(this);
  late final $WeeklyBudgetItemsTable weeklyBudgetItems =
      $WeeklyBudgetItemsTable(this);
  late final AccountsDao accountsDao = AccountsDao(this as FincoreDatabase);
  late final CategoriesDao categoriesDao = CategoriesDao(
    this as FincoreDatabase,
  );
  late final EntriesDao entriesDao = EntriesDao(this as FincoreDatabase);
  late final SavedViewsDao savedViewsDao = SavedViewsDao(
    this as FincoreDatabase,
  );
  late final AppPreferencesDao appPreferencesDao = AppPreferencesDao(
    this as FincoreDatabase,
  );
  late final WeeklyBudgetsDao weeklyBudgetsDao = WeeklyBudgetsDao(
    this as FincoreDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    categories,
    journalEntries,
    savedViews,
    appPreferences,
    weeklyBudgets,
    weeklyBudgetItems,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$AccountsTableCreateCompanionBuilder =
    AccountsCompanion Function({
      required String id,
      required String name,
      required String type,
      Value<String?> description,
      Value<bool> isProtected,
      Value<double> creditLimit,
      Value<int?> closingDay,
      Value<int?> paymentDay,
      Value<double?> interestRate,
      Value<double?> minimumPaymentPct,
      Value<double> minimumCapitalPct,
      Value<double> minimumFloor,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<DateTime?> archivedAt,
      Value<int> rowid,
    });
typedef $$AccountsTableUpdateCompanionBuilder =
    AccountsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> type,
      Value<String?> description,
      Value<bool> isProtected,
      Value<double> creditLimit,
      Value<int?> closingDay,
      Value<int?> paymentDay,
      Value<double?> interestRate,
      Value<double?> minimumPaymentPct,
      Value<double> minimumCapitalPct,
      Value<double> minimumFloor,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<DateTime?> archivedAt,
      Value<int> rowid,
    });

class $$AccountsTableFilterComposer
    extends Composer<_$FincoreDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isProtected => $composableBuilder(
    column: $table.isProtected,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get creditLimit => $composableBuilder(
    column: $table.creditLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get closingDay => $composableBuilder(
    column: $table.closingDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paymentDay => $composableBuilder(
    column: $table.paymentDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get interestRate => $composableBuilder(
    column: $table.interestRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get minimumPaymentPct => $composableBuilder(
    column: $table.minimumPaymentPct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get minimumCapitalPct => $composableBuilder(
    column: $table.minimumCapitalPct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get minimumFloor => $composableBuilder(
    column: $table.minimumFloor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccountsTableOrderingComposer
    extends Composer<_$FincoreDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isProtected => $composableBuilder(
    column: $table.isProtected,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get creditLimit => $composableBuilder(
    column: $table.creditLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get closingDay => $composableBuilder(
    column: $table.closingDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paymentDay => $composableBuilder(
    column: $table.paymentDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get interestRate => $composableBuilder(
    column: $table.interestRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get minimumPaymentPct => $composableBuilder(
    column: $table.minimumPaymentPct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get minimumCapitalPct => $composableBuilder(
    column: $table.minimumCapitalPct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get minimumFloor => $composableBuilder(
    column: $table.minimumFloor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$FincoreDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isProtected => $composableBuilder(
    column: $table.isProtected,
    builder: (column) => column,
  );

  GeneratedColumn<double> get creditLimit => $composableBuilder(
    column: $table.creditLimit,
    builder: (column) => column,
  );

  GeneratedColumn<int> get closingDay => $composableBuilder(
    column: $table.closingDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get paymentDay => $composableBuilder(
    column: $table.paymentDay,
    builder: (column) => column,
  );

  GeneratedColumn<double> get interestRate => $composableBuilder(
    column: $table.interestRate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get minimumPaymentPct => $composableBuilder(
    column: $table.minimumPaymentPct,
    builder: (column) => column,
  );

  GeneratedColumn<double> get minimumCapitalPct => $composableBuilder(
    column: $table.minimumCapitalPct,
    builder: (column) => column,
  );

  GeneratedColumn<double> get minimumFloor => $composableBuilder(
    column: $table.minimumFloor,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$FincoreDatabase,
          $AccountsTable,
          Account,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (Account, BaseReferences<_$FincoreDatabase, $AccountsTable, Account>),
          Account,
          PrefetchHooks Function()
        > {
  $$AccountsTableTableManager(_$FincoreDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<bool> isProtected = const Value.absent(),
                Value<double> creditLimit = const Value.absent(),
                Value<int?> closingDay = const Value.absent(),
                Value<int?> paymentDay = const Value.absent(),
                Value<double?> interestRate = const Value.absent(),
                Value<double?> minimumPaymentPct = const Value.absent(),
                Value<double> minimumCapitalPct = const Value.absent(),
                Value<double> minimumFloor = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                name: name,
                type: type,
                description: description,
                isProtected: isProtected,
                creditLimit: creditLimit,
                closingDay: closingDay,
                paymentDay: paymentDay,
                interestRate: interestRate,
                minimumPaymentPct: minimumPaymentPct,
                minimumCapitalPct: minimumCapitalPct,
                minimumFloor: minimumFloor,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String type,
                Value<String?> description = const Value.absent(),
                Value<bool> isProtected = const Value.absent(),
                Value<double> creditLimit = const Value.absent(),
                Value<int?> closingDay = const Value.absent(),
                Value<int?> paymentDay = const Value.absent(),
                Value<double?> interestRate = const Value.absent(),
                Value<double?> minimumPaymentPct = const Value.absent(),
                Value<double> minimumCapitalPct = const Value.absent(),
                Value<double> minimumFloor = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                name: name,
                type: type,
                description: description,
                isProtected: isProtected,
                creditLimit: creditLimit,
                closingDay: closingDay,
                paymentDay: paymentDay,
                interestRate: interestRate,
                minimumPaymentPct: minimumPaymentPct,
                minimumCapitalPct: minimumCapitalPct,
                minimumFloor: minimumFloor,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                archivedAt: archivedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$FincoreDatabase,
      $AccountsTable,
      Account,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (Account, BaseReferences<_$FincoreDatabase, $AccountsTable, Account>),
      Account,
      PrefetchHooks Function()
    >;
typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      required String id,
      required String name,
      required String appliesTo,
      required String colorSlug,
      required String iconSlug,
      Value<double?> monthlyLimit,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> appliesTo,
      Value<String> colorSlug,
      Value<String> iconSlug,
      Value<double?> monthlyLimit,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$CategoriesTableReferences
    extends BaseReferences<_$FincoreDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$JournalEntriesTable, List<JournalEntry>>
  _journalEntriesRefsTable(_$FincoreDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.journalEntries,
        aliasName: $_aliasNameGenerator(
          db.categories.id,
          db.journalEntries.categoryId,
        ),
      );

  $$JournalEntriesTableProcessedTableManager get journalEntriesRefs {
    final manager = $$JournalEntriesTableTableManager(
      $_db,
      $_db.journalEntries,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_journalEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$WeeklyBudgetItemsTable, List<WeeklyBudgetItemRow>>
  _weeklyBudgetItemsRefsTable(_$FincoreDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.weeklyBudgetItems,
        aliasName: $_aliasNameGenerator(
          db.categories.id,
          db.weeklyBudgetItems.categoryId,
        ),
      );

  $$WeeklyBudgetItemsTableProcessedTableManager get weeklyBudgetItemsRefs {
    final manager = $$WeeklyBudgetItemsTableTableManager(
      $_db,
      $_db.weeklyBudgetItems,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _weeklyBudgetItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$FincoreDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appliesTo => $composableBuilder(
    column: $table.appliesTo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorSlug => $composableBuilder(
    column: $table.colorSlug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconSlug => $composableBuilder(
    column: $table.iconSlug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get monthlyLimit => $composableBuilder(
    column: $table.monthlyLimit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> journalEntriesRefs(
    Expression<bool> Function($$JournalEntriesTableFilterComposer f) f,
  ) {
    final $$JournalEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.journalEntries,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JournalEntriesTableFilterComposer(
            $db: $db,
            $table: $db.journalEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> weeklyBudgetItemsRefs(
    Expression<bool> Function($$WeeklyBudgetItemsTableFilterComposer f) f,
  ) {
    final $$WeeklyBudgetItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.weeklyBudgetItems,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WeeklyBudgetItemsTableFilterComposer(
            $db: $db,
            $table: $db.weeklyBudgetItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$FincoreDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appliesTo => $composableBuilder(
    column: $table.appliesTo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorSlug => $composableBuilder(
    column: $table.colorSlug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconSlug => $composableBuilder(
    column: $table.iconSlug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get monthlyLimit => $composableBuilder(
    column: $table.monthlyLimit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$FincoreDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get appliesTo =>
      $composableBuilder(column: $table.appliesTo, builder: (column) => column);

  GeneratedColumn<String> get colorSlug =>
      $composableBuilder(column: $table.colorSlug, builder: (column) => column);

  GeneratedColumn<String> get iconSlug =>
      $composableBuilder(column: $table.iconSlug, builder: (column) => column);

  GeneratedColumn<double> get monthlyLimit => $composableBuilder(
    column: $table.monthlyLimit,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> journalEntriesRefs<T extends Object>(
    Expression<T> Function($$JournalEntriesTableAnnotationComposer a) f,
  ) {
    final $$JournalEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.journalEntries,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$JournalEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.journalEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> weeklyBudgetItemsRefs<T extends Object>(
    Expression<T> Function($$WeeklyBudgetItemsTableAnnotationComposer a) f,
  ) {
    final $$WeeklyBudgetItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.weeklyBudgetItems,
          getReferencedColumn: (t) => t.categoryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WeeklyBudgetItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.weeklyBudgetItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$FincoreDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, $$CategoriesTableReferences),
          Category,
          PrefetchHooks Function({
            bool journalEntriesRefs,
            bool weeklyBudgetItemsRefs,
          })
        > {
  $$CategoriesTableTableManager(_$FincoreDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> appliesTo = const Value.absent(),
                Value<String> colorSlug = const Value.absent(),
                Value<String> iconSlug = const Value.absent(),
                Value<double?> monthlyLimit = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                appliesTo: appliesTo,
                colorSlug: colorSlug,
                iconSlug: iconSlug,
                monthlyLimit: monthlyLimit,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String appliesTo,
                required String colorSlug,
                required String iconSlug,
                Value<double?> monthlyLimit = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                appliesTo: appliesTo,
                colorSlug: colorSlug,
                iconSlug: iconSlug,
                monthlyLimit: monthlyLimit,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$CategoriesTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            journalEntriesRefs = false,
            weeklyBudgetItemsRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (journalEntriesRefs) db.journalEntries,
                if (weeklyBudgetItemsRefs) db.weeklyBudgetItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (journalEntriesRefs)
                    await $_getPrefetchedData<
                      Category,
                      $CategoriesTable,
                      JournalEntry
                    >(
                      currentTable: table,
                      referencedTable: $$CategoriesTableReferences
                          ._journalEntriesRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).journalEntriesRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.categoryId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (weeklyBudgetItemsRefs)
                    await $_getPrefetchedData<
                      Category,
                      $CategoriesTable,
                      WeeklyBudgetItemRow
                    >(
                      currentTable: table,
                      referencedTable: $$CategoriesTableReferences
                          ._weeklyBudgetItemsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$CategoriesTableReferences(
                                db,
                                table,
                                p0,
                              ).weeklyBudgetItemsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.categoryId == item.id,
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

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$FincoreDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, $$CategoriesTableReferences),
      Category,
      PrefetchHooks Function({
        bool journalEntriesRefs,
        bool weeklyBudgetItemsRefs,
      })
    >;
typedef $$JournalEntriesTableCreateCompanionBuilder =
    JournalEntriesCompanion Function({
      required String id,
      required String kind,
      Value<String?> accountOriginId,
      Value<String?> accountDestinationId,
      required double amount,
      Value<String?> description,
      required DateTime occurredAt,
      Value<String?> categoryId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$JournalEntriesTableUpdateCompanionBuilder =
    JournalEntriesCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String?> accountOriginId,
      Value<String?> accountDestinationId,
      Value<double> amount,
      Value<String?> description,
      Value<DateTime> occurredAt,
      Value<String?> categoryId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$JournalEntriesTableReferences
    extends
        BaseReferences<_$FincoreDatabase, $JournalEntriesTable, JournalEntry> {
  $$JournalEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $AccountsTable _accountOriginIdTable(_$FincoreDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(db.journalEntries.accountOriginId, db.accounts.id),
      );

  $$AccountsTableProcessedTableManager? get accountOriginId {
    final $_column = $_itemColumn<String>('account_origin_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountOriginIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AccountsTable _accountDestinationIdTable(_$FincoreDatabase db) =>
      db.accounts.createAlias(
        $_aliasNameGenerator(
          db.journalEntries.accountDestinationId,
          db.accounts.id,
        ),
      );

  $$AccountsTableProcessedTableManager? get accountDestinationId {
    final $_column = $_itemColumn<String>('account_destination_id');
    if ($_column == null) return null;
    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(
      _accountDestinationIdTable($_db),
    );
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$FincoreDatabase db) =>
      db.categories.createAlias(
        $_aliasNameGenerator(db.journalEntries.categoryId, db.categories.id),
      );

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<String>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$JournalEntriesTableFilterComposer
    extends Composer<_$FincoreDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountOriginId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountOriginId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableFilterComposer get accountDestinationId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountDestinationId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$JournalEntriesTableOrderingComposer
    extends Composer<_$FincoreDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountOriginId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountOriginId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableOrderingComposer get accountDestinationId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountDestinationId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$JournalEntriesTableAnnotationComposer
    extends Composer<_$FincoreDatabase, $JournalEntriesTable> {
  $$JournalEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountOriginId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountOriginId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountsTableAnnotationComposer get accountDestinationId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountDestinationId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$JournalEntriesTableTableManager
    extends
        RootTableManager<
          _$FincoreDatabase,
          $JournalEntriesTable,
          JournalEntry,
          $$JournalEntriesTableFilterComposer,
          $$JournalEntriesTableOrderingComposer,
          $$JournalEntriesTableAnnotationComposer,
          $$JournalEntriesTableCreateCompanionBuilder,
          $$JournalEntriesTableUpdateCompanionBuilder,
          (JournalEntry, $$JournalEntriesTableReferences),
          JournalEntry,
          PrefetchHooks Function({
            bool accountOriginId,
            bool accountDestinationId,
            bool categoryId,
          })
        > {
  $$JournalEntriesTableTableManager(
    _$FincoreDatabase db,
    $JournalEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$JournalEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$JournalEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$JournalEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> accountOriginId = const Value.absent(),
                Value<String?> accountDestinationId = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JournalEntriesCompanion(
                id: id,
                kind: kind,
                accountOriginId: accountOriginId,
                accountDestinationId: accountDestinationId,
                amount: amount,
                description: description,
                occurredAt: occurredAt,
                categoryId: categoryId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                Value<String?> accountOriginId = const Value.absent(),
                Value<String?> accountDestinationId = const Value.absent(),
                required double amount,
                Value<String?> description = const Value.absent(),
                required DateTime occurredAt,
                Value<String?> categoryId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => JournalEntriesCompanion.insert(
                id: id,
                kind: kind,
                accountOriginId: accountOriginId,
                accountDestinationId: accountDestinationId,
                amount: amount,
                description: description,
                occurredAt: occurredAt,
                categoryId: categoryId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$JournalEntriesTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            accountOriginId = false,
            accountDestinationId = false,
            categoryId = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                if (accountOriginId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.accountOriginId,
                            referencedTable: $$JournalEntriesTableReferences
                                ._accountOriginIdTable(db),
                            referencedColumn:
                                $$JournalEntriesTableReferences
                                    ._accountOriginIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (accountDestinationId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.accountDestinationId,
                            referencedTable: $$JournalEntriesTableReferences
                                ._accountDestinationIdTable(db),
                            referencedColumn:
                                $$JournalEntriesTableReferences
                                    ._accountDestinationIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (categoryId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.categoryId,
                            referencedTable: $$JournalEntriesTableReferences
                                ._categoryIdTable(db),
                            referencedColumn:
                                $$JournalEntriesTableReferences
                                    ._categoryIdTable(db)
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

typedef $$JournalEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$FincoreDatabase,
      $JournalEntriesTable,
      JournalEntry,
      $$JournalEntriesTableFilterComposer,
      $$JournalEntriesTableOrderingComposer,
      $$JournalEntriesTableAnnotationComposer,
      $$JournalEntriesTableCreateCompanionBuilder,
      $$JournalEntriesTableUpdateCompanionBuilder,
      (JournalEntry, $$JournalEntriesTableReferences),
      JournalEntry,
      PrefetchHooks Function({
        bool accountOriginId,
        bool accountDestinationId,
        bool categoryId,
      })
    >;
typedef $$SavedViewsTableCreateCompanionBuilder =
    SavedViewsCompanion Function({
      required String id,
      required String name,
      required String filtersJson,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$SavedViewsTableUpdateCompanionBuilder =
    SavedViewsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> filtersJson,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$SavedViewsTableFilterComposer
    extends Composer<_$FincoreDatabase, $SavedViewsTable> {
  $$SavedViewsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filtersJson => $composableBuilder(
    column: $table.filtersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SavedViewsTableOrderingComposer
    extends Composer<_$FincoreDatabase, $SavedViewsTable> {
  $$SavedViewsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filtersJson => $composableBuilder(
    column: $table.filtersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SavedViewsTableAnnotationComposer
    extends Composer<_$FincoreDatabase, $SavedViewsTable> {
  $$SavedViewsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get filtersJson => $composableBuilder(
    column: $table.filtersJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SavedViewsTableTableManager
    extends
        RootTableManager<
          _$FincoreDatabase,
          $SavedViewsTable,
          SavedViewRow,
          $$SavedViewsTableFilterComposer,
          $$SavedViewsTableOrderingComposer,
          $$SavedViewsTableAnnotationComposer,
          $$SavedViewsTableCreateCompanionBuilder,
          $$SavedViewsTableUpdateCompanionBuilder,
          (
            SavedViewRow,
            BaseReferences<_$FincoreDatabase, $SavedViewsTable, SavedViewRow>,
          ),
          SavedViewRow,
          PrefetchHooks Function()
        > {
  $$SavedViewsTableTableManager(_$FincoreDatabase db, $SavedViewsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$SavedViewsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$SavedViewsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$SavedViewsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> filtersJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SavedViewsCompanion(
                id: id,
                name: name,
                filtersJson: filtersJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String filtersJson,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SavedViewsCompanion.insert(
                id: id,
                name: name,
                filtersJson: filtersJson,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SavedViewsTableProcessedTableManager =
    ProcessedTableManager<
      _$FincoreDatabase,
      $SavedViewsTable,
      SavedViewRow,
      $$SavedViewsTableFilterComposer,
      $$SavedViewsTableOrderingComposer,
      $$SavedViewsTableAnnotationComposer,
      $$SavedViewsTableCreateCompanionBuilder,
      $$SavedViewsTableUpdateCompanionBuilder,
      (
        SavedViewRow,
        BaseReferences<_$FincoreDatabase, $SavedViewsTable, SavedViewRow>,
      ),
      SavedViewRow,
      PrefetchHooks Function()
    >;
typedef $$AppPreferencesTableCreateCompanionBuilder =
    AppPreferencesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppPreferencesTableUpdateCompanionBuilder =
    AppPreferencesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppPreferencesTableFilterComposer
    extends Composer<_$FincoreDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppPreferencesTableOrderingComposer
    extends Composer<_$FincoreDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppPreferencesTableAnnotationComposer
    extends Composer<_$FincoreDatabase, $AppPreferencesTable> {
  $$AppPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppPreferencesTableTableManager
    extends
        RootTableManager<
          _$FincoreDatabase,
          $AppPreferencesTable,
          AppPreferenceRow,
          $$AppPreferencesTableFilterComposer,
          $$AppPreferencesTableOrderingComposer,
          $$AppPreferencesTableAnnotationComposer,
          $$AppPreferencesTableCreateCompanionBuilder,
          $$AppPreferencesTableUpdateCompanionBuilder,
          (
            AppPreferenceRow,
            BaseReferences<
              _$FincoreDatabase,
              $AppPreferencesTable,
              AppPreferenceRow
            >,
          ),
          AppPreferenceRow,
          PrefetchHooks Function()
        > {
  $$AppPreferencesTableTableManager(
    _$FincoreDatabase db,
    $AppPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$AppPreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$AppPreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$AppPreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  AppPreferencesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppPreferencesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$FincoreDatabase,
      $AppPreferencesTable,
      AppPreferenceRow,
      $$AppPreferencesTableFilterComposer,
      $$AppPreferencesTableOrderingComposer,
      $$AppPreferencesTableAnnotationComposer,
      $$AppPreferencesTableCreateCompanionBuilder,
      $$AppPreferencesTableUpdateCompanionBuilder,
      (
        AppPreferenceRow,
        BaseReferences<
          _$FincoreDatabase,
          $AppPreferencesTable,
          AppPreferenceRow
        >,
      ),
      AppPreferenceRow,
      PrefetchHooks Function()
    >;
typedef $$WeeklyBudgetsTableCreateCompanionBuilder =
    WeeklyBudgetsCompanion Function({
      required String id,
      required DateTime weekStartDate,
      required String label,
      Value<bool> isTemplate,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$WeeklyBudgetsTableUpdateCompanionBuilder =
    WeeklyBudgetsCompanion Function({
      Value<String> id,
      Value<DateTime> weekStartDate,
      Value<String> label,
      Value<bool> isTemplate,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$WeeklyBudgetsTableReferences
    extends
        BaseReferences<
          _$FincoreDatabase,
          $WeeklyBudgetsTable,
          WeeklyBudgetRow
        > {
  $$WeeklyBudgetsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$WeeklyBudgetItemsTable, List<WeeklyBudgetItemRow>>
  _weeklyBudgetItemsRefsTable(_$FincoreDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.weeklyBudgetItems,
        aliasName: $_aliasNameGenerator(
          db.weeklyBudgets.id,
          db.weeklyBudgetItems.budgetId,
        ),
      );

  $$WeeklyBudgetItemsTableProcessedTableManager get weeklyBudgetItemsRefs {
    final manager = $$WeeklyBudgetItemsTableTableManager(
      $_db,
      $_db.weeklyBudgetItems,
    ).filter((f) => f.budgetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _weeklyBudgetItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WeeklyBudgetsTableFilterComposer
    extends Composer<_$FincoreDatabase, $WeeklyBudgetsTable> {
  $$WeeklyBudgetsTableFilterComposer({
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

  ColumnFilters<DateTime> get weekStartDate => $composableBuilder(
    column: $table.weekStartDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isTemplate => $composableBuilder(
    column: $table.isTemplate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> weeklyBudgetItemsRefs(
    Expression<bool> Function($$WeeklyBudgetItemsTableFilterComposer f) f,
  ) {
    final $$WeeklyBudgetItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.weeklyBudgetItems,
      getReferencedColumn: (t) => t.budgetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WeeklyBudgetItemsTableFilterComposer(
            $db: $db,
            $table: $db.weeklyBudgetItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$WeeklyBudgetsTableOrderingComposer
    extends Composer<_$FincoreDatabase, $WeeklyBudgetsTable> {
  $$WeeklyBudgetsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get weekStartDate => $composableBuilder(
    column: $table.weekStartDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isTemplate => $composableBuilder(
    column: $table.isTemplate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WeeklyBudgetsTableAnnotationComposer
    extends Composer<_$FincoreDatabase, $WeeklyBudgetsTable> {
  $$WeeklyBudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get weekStartDate => $composableBuilder(
    column: $table.weekStartDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<bool> get isTemplate => $composableBuilder(
    column: $table.isTemplate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> weeklyBudgetItemsRefs<T extends Object>(
    Expression<T> Function($$WeeklyBudgetItemsTableAnnotationComposer a) f,
  ) {
    final $$WeeklyBudgetItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.weeklyBudgetItems,
          getReferencedColumn: (t) => t.budgetId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WeeklyBudgetItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.weeklyBudgetItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$WeeklyBudgetsTableTableManager
    extends
        RootTableManager<
          _$FincoreDatabase,
          $WeeklyBudgetsTable,
          WeeklyBudgetRow,
          $$WeeklyBudgetsTableFilterComposer,
          $$WeeklyBudgetsTableOrderingComposer,
          $$WeeklyBudgetsTableAnnotationComposer,
          $$WeeklyBudgetsTableCreateCompanionBuilder,
          $$WeeklyBudgetsTableUpdateCompanionBuilder,
          (WeeklyBudgetRow, $$WeeklyBudgetsTableReferences),
          WeeklyBudgetRow,
          PrefetchHooks Function({bool weeklyBudgetItemsRefs})
        > {
  $$WeeklyBudgetsTableTableManager(
    _$FincoreDatabase db,
    $WeeklyBudgetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$WeeklyBudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$WeeklyBudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$WeeklyBudgetsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> weekStartDate = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<bool> isTemplate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WeeklyBudgetsCompanion(
                id: id,
                weekStartDate: weekStartDate,
                label: label,
                isTemplate: isTemplate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime weekStartDate,
                required String label,
                Value<bool> isTemplate = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => WeeklyBudgetsCompanion.insert(
                id: id,
                weekStartDate: weekStartDate,
                label: label,
                isTemplate: isTemplate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$WeeklyBudgetsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({weeklyBudgetItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (weeklyBudgetItemsRefs) db.weeklyBudgetItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (weeklyBudgetItemsRefs)
                    await $_getPrefetchedData<
                      WeeklyBudgetRow,
                      $WeeklyBudgetsTable,
                      WeeklyBudgetItemRow
                    >(
                      currentTable: table,
                      referencedTable: $$WeeklyBudgetsTableReferences
                          ._weeklyBudgetItemsRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$WeeklyBudgetsTableReferences(
                                db,
                                table,
                                p0,
                              ).weeklyBudgetItemsRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.budgetId == item.id,
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

typedef $$WeeklyBudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$FincoreDatabase,
      $WeeklyBudgetsTable,
      WeeklyBudgetRow,
      $$WeeklyBudgetsTableFilterComposer,
      $$WeeklyBudgetsTableOrderingComposer,
      $$WeeklyBudgetsTableAnnotationComposer,
      $$WeeklyBudgetsTableCreateCompanionBuilder,
      $$WeeklyBudgetsTableUpdateCompanionBuilder,
      (WeeklyBudgetRow, $$WeeklyBudgetsTableReferences),
      WeeklyBudgetRow,
      PrefetchHooks Function({bool weeklyBudgetItemsRefs})
    >;
typedef $$WeeklyBudgetItemsTableCreateCompanionBuilder =
    WeeklyBudgetItemsCompanion Function({
      required String id,
      required String budgetId,
      required String name,
      Value<String?> categoryId,
      required double amount,
      required String kind,
      required int sortOrder,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$WeeklyBudgetItemsTableUpdateCompanionBuilder =
    WeeklyBudgetItemsCompanion Function({
      Value<String> id,
      Value<String> budgetId,
      Value<String> name,
      Value<String?> categoryId,
      Value<double> amount,
      Value<String> kind,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$WeeklyBudgetItemsTableReferences
    extends
        BaseReferences<
          _$FincoreDatabase,
          $WeeklyBudgetItemsTable,
          WeeklyBudgetItemRow
        > {
  $$WeeklyBudgetItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WeeklyBudgetsTable _budgetIdTable(_$FincoreDatabase db) =>
      db.weeklyBudgets.createAlias(
        $_aliasNameGenerator(
          db.weeklyBudgetItems.budgetId,
          db.weeklyBudgets.id,
        ),
      );

  $$WeeklyBudgetsTableProcessedTableManager get budgetId {
    final $_column = $_itemColumn<String>('budget_id')!;

    final manager = $$WeeklyBudgetsTableTableManager(
      $_db,
      $_db.weeklyBudgets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_budgetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$FincoreDatabase db) =>
      db.categories.createAlias(
        $_aliasNameGenerator(db.weeklyBudgetItems.categoryId, db.categories.id),
      );

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<String>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WeeklyBudgetItemsTableFilterComposer
    extends Composer<_$FincoreDatabase, $WeeklyBudgetItemsTable> {
  $$WeeklyBudgetItemsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$WeeklyBudgetsTableFilterComposer get budgetId {
    final $$WeeklyBudgetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.budgetId,
      referencedTable: $db.weeklyBudgets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WeeklyBudgetsTableFilterComposer(
            $db: $db,
            $table: $db.weeklyBudgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WeeklyBudgetItemsTableOrderingComposer
    extends Composer<_$FincoreDatabase, $WeeklyBudgetItemsTable> {
  $$WeeklyBudgetItemsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$WeeklyBudgetsTableOrderingComposer get budgetId {
    final $$WeeklyBudgetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.budgetId,
      referencedTable: $db.weeklyBudgets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WeeklyBudgetsTableOrderingComposer(
            $db: $db,
            $table: $db.weeklyBudgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WeeklyBudgetItemsTableAnnotationComposer
    extends Composer<_$FincoreDatabase, $WeeklyBudgetItemsTable> {
  $$WeeklyBudgetItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$WeeklyBudgetsTableAnnotationComposer get budgetId {
    final $$WeeklyBudgetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.budgetId,
      referencedTable: $db.weeklyBudgets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WeeklyBudgetsTableAnnotationComposer(
            $db: $db,
            $table: $db.weeklyBudgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WeeklyBudgetItemsTableTableManager
    extends
        RootTableManager<
          _$FincoreDatabase,
          $WeeklyBudgetItemsTable,
          WeeklyBudgetItemRow,
          $$WeeklyBudgetItemsTableFilterComposer,
          $$WeeklyBudgetItemsTableOrderingComposer,
          $$WeeklyBudgetItemsTableAnnotationComposer,
          $$WeeklyBudgetItemsTableCreateCompanionBuilder,
          $$WeeklyBudgetItemsTableUpdateCompanionBuilder,
          (WeeklyBudgetItemRow, $$WeeklyBudgetItemsTableReferences),
          WeeklyBudgetItemRow,
          PrefetchHooks Function({bool budgetId, bool categoryId})
        > {
  $$WeeklyBudgetItemsTableTableManager(
    _$FincoreDatabase db,
    $WeeklyBudgetItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$WeeklyBudgetItemsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$WeeklyBudgetItemsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$WeeklyBudgetItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> budgetId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WeeklyBudgetItemsCompanion(
                id: id,
                budgetId: budgetId,
                name: name,
                categoryId: categoryId,
                amount: amount,
                kind: kind,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String budgetId,
                required String name,
                Value<String?> categoryId = const Value.absent(),
                required double amount,
                required String kind,
                required int sortOrder,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => WeeklyBudgetItemsCompanion.insert(
                id: id,
                budgetId: budgetId,
                name: name,
                categoryId: categoryId,
                amount: amount,
                kind: kind,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$WeeklyBudgetItemsTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({budgetId = false, categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
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
                if (budgetId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.budgetId,
                            referencedTable: $$WeeklyBudgetItemsTableReferences
                                ._budgetIdTable(db),
                            referencedColumn:
                                $$WeeklyBudgetItemsTableReferences
                                    ._budgetIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (categoryId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.categoryId,
                            referencedTable: $$WeeklyBudgetItemsTableReferences
                                ._categoryIdTable(db),
                            referencedColumn:
                                $$WeeklyBudgetItemsTableReferences
                                    ._categoryIdTable(db)
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

typedef $$WeeklyBudgetItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$FincoreDatabase,
      $WeeklyBudgetItemsTable,
      WeeklyBudgetItemRow,
      $$WeeklyBudgetItemsTableFilterComposer,
      $$WeeklyBudgetItemsTableOrderingComposer,
      $$WeeklyBudgetItemsTableAnnotationComposer,
      $$WeeklyBudgetItemsTableCreateCompanionBuilder,
      $$WeeklyBudgetItemsTableUpdateCompanionBuilder,
      (WeeklyBudgetItemRow, $$WeeklyBudgetItemsTableReferences),
      WeeklyBudgetItemRow,
      PrefetchHooks Function({bool budgetId, bool categoryId})
    >;

class $FincoreDatabaseManager {
  final _$FincoreDatabase _db;
  $FincoreDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$JournalEntriesTableTableManager get journalEntries =>
      $$JournalEntriesTableTableManager(_db, _db.journalEntries);
  $$SavedViewsTableTableManager get savedViews =>
      $$SavedViewsTableTableManager(_db, _db.savedViews);
  $$AppPreferencesTableTableManager get appPreferences =>
      $$AppPreferencesTableTableManager(_db, _db.appPreferences);
  $$WeeklyBudgetsTableTableManager get weeklyBudgets =>
      $$WeeklyBudgetsTableTableManager(_db, _db.weeklyBudgets);
  $$WeeklyBudgetItemsTableTableManager get weeklyBudgetItems =>
      $$WeeklyBudgetItemsTableTableManager(_db, _db.weeklyBudgetItems);
}
