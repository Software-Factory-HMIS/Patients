// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DailySyncStatusRowsTable extends DailySyncStatusRows
    with TableInfo<$DailySyncStatusRowsTable, DailySyncStatusRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailySyncStatusRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _patientIdMeta = const VerificationMeta(
    'patientId',
  );
  @override
  late final GeneratedColumn<int> patientId = GeneratedColumn<int>(
    'patient_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<String> lastUpdated = GeneratedColumn<String>(
    'last_updated',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [patientId, date, status, lastUpdated];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_sync_status_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailySyncStatusRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('patient_id')) {
      context.handle(
        _patientIdMeta,
        patientId.isAcceptableOrUnknown(data['patient_id']!, _patientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_patientIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUpdatedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {patientId, date};
  @override
  DailySyncStatusRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailySyncStatusRow(
      patientId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}patient_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_updated'],
      )!,
    );
  }

  @override
  $DailySyncStatusRowsTable createAlias(String alias) {
    return $DailySyncStatusRowsTable(attachedDatabase, alias);
  }
}

class DailySyncStatusRow extends DataClass
    implements Insertable<DailySyncStatusRow> {
  final int patientId;
  final String date;
  final String status;
  final String lastUpdated;
  const DailySyncStatusRow({
    required this.patientId,
    required this.date,
    required this.status,
    required this.lastUpdated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['patient_id'] = Variable<int>(patientId);
    map['date'] = Variable<String>(date);
    map['status'] = Variable<String>(status);
    map['last_updated'] = Variable<String>(lastUpdated);
    return map;
  }

  DailySyncStatusRowsCompanion toCompanion(bool nullToAbsent) {
    return DailySyncStatusRowsCompanion(
      patientId: Value(patientId),
      date: Value(date),
      status: Value(status),
      lastUpdated: Value(lastUpdated),
    );
  }

  factory DailySyncStatusRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailySyncStatusRow(
      patientId: serializer.fromJson<int>(json['patientId']),
      date: serializer.fromJson<String>(json['date']),
      status: serializer.fromJson<String>(json['status']),
      lastUpdated: serializer.fromJson<String>(json['lastUpdated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'patientId': serializer.toJson<int>(patientId),
      'date': serializer.toJson<String>(date),
      'status': serializer.toJson<String>(status),
      'lastUpdated': serializer.toJson<String>(lastUpdated),
    };
  }

  DailySyncStatusRow copyWith({
    int? patientId,
    String? date,
    String? status,
    String? lastUpdated,
  }) => DailySyncStatusRow(
    patientId: patientId ?? this.patientId,
    date: date ?? this.date,
    status: status ?? this.status,
    lastUpdated: lastUpdated ?? this.lastUpdated,
  );
  DailySyncStatusRow copyWithCompanion(DailySyncStatusRowsCompanion data) {
    return DailySyncStatusRow(
      patientId: data.patientId.present ? data.patientId.value : this.patientId,
      date: data.date.present ? data.date.value : this.date,
      status: data.status.present ? data.status.value : this.status,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailySyncStatusRow(')
          ..write('patientId: $patientId, ')
          ..write('date: $date, ')
          ..write('status: $status, ')
          ..write('lastUpdated: $lastUpdated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(patientId, date, status, lastUpdated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailySyncStatusRow &&
          other.patientId == this.patientId &&
          other.date == this.date &&
          other.status == this.status &&
          other.lastUpdated == this.lastUpdated);
}

class DailySyncStatusRowsCompanion extends UpdateCompanion<DailySyncStatusRow> {
  final Value<int> patientId;
  final Value<String> date;
  final Value<String> status;
  final Value<String> lastUpdated;
  final Value<int> rowid;
  const DailySyncStatusRowsCompanion({
    this.patientId = const Value.absent(),
    this.date = const Value.absent(),
    this.status = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailySyncStatusRowsCompanion.insert({
    required int patientId,
    required String date,
    required String status,
    required String lastUpdated,
    this.rowid = const Value.absent(),
  }) : patientId = Value(patientId),
       date = Value(date),
       status = Value(status),
       lastUpdated = Value(lastUpdated);
  static Insertable<DailySyncStatusRow> custom({
    Expression<int>? patientId,
    Expression<String>? date,
    Expression<String>? status,
    Expression<String>? lastUpdated,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (patientId != null) 'patient_id': patientId,
      if (date != null) 'date': date,
      if (status != null) 'status': status,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailySyncStatusRowsCompanion copyWith({
    Value<int>? patientId,
    Value<String>? date,
    Value<String>? status,
    Value<String>? lastUpdated,
    Value<int>? rowid,
  }) {
    return DailySyncStatusRowsCompanion(
      patientId: patientId ?? this.patientId,
      date: date ?? this.date,
      status: status ?? this.status,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (patientId.present) {
      map['patient_id'] = Variable<int>(patientId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<String>(lastUpdated.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailySyncStatusRowsCompanion(')
          ..write('patientId: $patientId, ')
          ..write('date: $date, ')
          ..write('status: $status, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PatientHistoryRecordsTable extends PatientHistoryRecords
    with TableInfo<$PatientHistoryRecordsTable, PatientHistoryRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PatientHistoryRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _patientIdMeta = const VerificationMeta(
    'patientId',
  );
  @override
  late final GeneratedColumn<int> patientId = GeneratedColumn<int>(
    'patient_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataPayloadMeta = const VerificationMeta(
    'dataPayload',
  );
  @override
  late final GeneratedColumn<String> dataPayload = GeneratedColumn<String>(
    'data_payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [patientId, date, dataPayload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'patient_history_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<PatientHistoryRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('patient_id')) {
      context.handle(
        _patientIdMeta,
        patientId.isAcceptableOrUnknown(data['patient_id']!, _patientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_patientIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('data_payload')) {
      context.handle(
        _dataPayloadMeta,
        dataPayload.isAcceptableOrUnknown(
          data['data_payload']!,
          _dataPayloadMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dataPayloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {patientId, date};
  @override
  PatientHistoryRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PatientHistoryRecord(
      patientId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}patient_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      dataPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_payload'],
      )!,
    );
  }

  @override
  $PatientHistoryRecordsTable createAlias(String alias) {
    return $PatientHistoryRecordsTable(attachedDatabase, alias);
  }
}

class PatientHistoryRecord extends DataClass
    implements Insertable<PatientHistoryRecord> {
  final int patientId;
  final String date;
  final String dataPayload;
  const PatientHistoryRecord({
    required this.patientId,
    required this.date,
    required this.dataPayload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['patient_id'] = Variable<int>(patientId);
    map['date'] = Variable<String>(date);
    map['data_payload'] = Variable<String>(dataPayload);
    return map;
  }

  PatientHistoryRecordsCompanion toCompanion(bool nullToAbsent) {
    return PatientHistoryRecordsCompanion(
      patientId: Value(patientId),
      date: Value(date),
      dataPayload: Value(dataPayload),
    );
  }

  factory PatientHistoryRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PatientHistoryRecord(
      patientId: serializer.fromJson<int>(json['patientId']),
      date: serializer.fromJson<String>(json['date']),
      dataPayload: serializer.fromJson<String>(json['dataPayload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'patientId': serializer.toJson<int>(patientId),
      'date': serializer.toJson<String>(date),
      'dataPayload': serializer.toJson<String>(dataPayload),
    };
  }

  PatientHistoryRecord copyWith({
    int? patientId,
    String? date,
    String? dataPayload,
  }) => PatientHistoryRecord(
    patientId: patientId ?? this.patientId,
    date: date ?? this.date,
    dataPayload: dataPayload ?? this.dataPayload,
  );
  PatientHistoryRecord copyWithCompanion(PatientHistoryRecordsCompanion data) {
    return PatientHistoryRecord(
      patientId: data.patientId.present ? data.patientId.value : this.patientId,
      date: data.date.present ? data.date.value : this.date,
      dataPayload: data.dataPayload.present
          ? data.dataPayload.value
          : this.dataPayload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PatientHistoryRecord(')
          ..write('patientId: $patientId, ')
          ..write('date: $date, ')
          ..write('dataPayload: $dataPayload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(patientId, date, dataPayload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PatientHistoryRecord &&
          other.patientId == this.patientId &&
          other.date == this.date &&
          other.dataPayload == this.dataPayload);
}

class PatientHistoryRecordsCompanion
    extends UpdateCompanion<PatientHistoryRecord> {
  final Value<int> patientId;
  final Value<String> date;
  final Value<String> dataPayload;
  final Value<int> rowid;
  const PatientHistoryRecordsCompanion({
    this.patientId = const Value.absent(),
    this.date = const Value.absent(),
    this.dataPayload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PatientHistoryRecordsCompanion.insert({
    required int patientId,
    required String date,
    required String dataPayload,
    this.rowid = const Value.absent(),
  }) : patientId = Value(patientId),
       date = Value(date),
       dataPayload = Value(dataPayload);
  static Insertable<PatientHistoryRecord> custom({
    Expression<int>? patientId,
    Expression<String>? date,
    Expression<String>? dataPayload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (patientId != null) 'patient_id': patientId,
      if (date != null) 'date': date,
      if (dataPayload != null) 'data_payload': dataPayload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PatientHistoryRecordsCompanion copyWith({
    Value<int>? patientId,
    Value<String>? date,
    Value<String>? dataPayload,
    Value<int>? rowid,
  }) {
    return PatientHistoryRecordsCompanion(
      patientId: patientId ?? this.patientId,
      date: date ?? this.date,
      dataPayload: dataPayload ?? this.dataPayload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (patientId.present) {
      map['patient_id'] = Variable<int>(patientId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (dataPayload.present) {
      map['data_payload'] = Variable<String>(dataPayload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PatientHistoryRecordsCompanion(')
          ..write('patientId: $patientId, ')
          ..write('date: $date, ')
          ..write('dataPayload: $dataPayload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DailySyncStatusRowsTable dailySyncStatusRows =
      $DailySyncStatusRowsTable(this);
  late final $PatientHistoryRecordsTable patientHistoryRecords =
      $PatientHistoryRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    dailySyncStatusRows,
    patientHistoryRecords,
  ];
}

typedef $$DailySyncStatusRowsTableCreateCompanionBuilder =
    DailySyncStatusRowsCompanion Function({
      required int patientId,
      required String date,
      required String status,
      required String lastUpdated,
      Value<int> rowid,
    });
typedef $$DailySyncStatusRowsTableUpdateCompanionBuilder =
    DailySyncStatusRowsCompanion Function({
      Value<int> patientId,
      Value<String> date,
      Value<String> status,
      Value<String> lastUpdated,
      Value<int> rowid,
    });

class $$DailySyncStatusRowsTableFilterComposer
    extends Composer<_$AppDatabase, $DailySyncStatusRowsTable> {
  $$DailySyncStatusRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get patientId => $composableBuilder(
    column: $table.patientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailySyncStatusRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailySyncStatusRowsTable> {
  $$DailySyncStatusRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get patientId => $composableBuilder(
    column: $table.patientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailySyncStatusRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailySyncStatusRowsTable> {
  $$DailySyncStatusRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get patientId =>
      $composableBuilder(column: $table.patientId, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );
}

class $$DailySyncStatusRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailySyncStatusRowsTable,
          DailySyncStatusRow,
          $$DailySyncStatusRowsTableFilterComposer,
          $$DailySyncStatusRowsTableOrderingComposer,
          $$DailySyncStatusRowsTableAnnotationComposer,
          $$DailySyncStatusRowsTableCreateCompanionBuilder,
          $$DailySyncStatusRowsTableUpdateCompanionBuilder,
          (
            DailySyncStatusRow,
            BaseReferences<
              _$AppDatabase,
              $DailySyncStatusRowsTable,
              DailySyncStatusRow
            >,
          ),
          DailySyncStatusRow,
          PrefetchHooks Function()
        > {
  $$DailySyncStatusRowsTableTableManager(
    _$AppDatabase db,
    $DailySyncStatusRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailySyncStatusRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailySyncStatusRowsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DailySyncStatusRowsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> patientId = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> lastUpdated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailySyncStatusRowsCompanion(
                patientId: patientId,
                date: date,
                status: status,
                lastUpdated: lastUpdated,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int patientId,
                required String date,
                required String status,
                required String lastUpdated,
                Value<int> rowid = const Value.absent(),
              }) => DailySyncStatusRowsCompanion.insert(
                patientId: patientId,
                date: date,
                status: status,
                lastUpdated: lastUpdated,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailySyncStatusRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailySyncStatusRowsTable,
      DailySyncStatusRow,
      $$DailySyncStatusRowsTableFilterComposer,
      $$DailySyncStatusRowsTableOrderingComposer,
      $$DailySyncStatusRowsTableAnnotationComposer,
      $$DailySyncStatusRowsTableCreateCompanionBuilder,
      $$DailySyncStatusRowsTableUpdateCompanionBuilder,
      (
        DailySyncStatusRow,
        BaseReferences<
          _$AppDatabase,
          $DailySyncStatusRowsTable,
          DailySyncStatusRow
        >,
      ),
      DailySyncStatusRow,
      PrefetchHooks Function()
    >;
typedef $$PatientHistoryRecordsTableCreateCompanionBuilder =
    PatientHistoryRecordsCompanion Function({
      required int patientId,
      required String date,
      required String dataPayload,
      Value<int> rowid,
    });
typedef $$PatientHistoryRecordsTableUpdateCompanionBuilder =
    PatientHistoryRecordsCompanion Function({
      Value<int> patientId,
      Value<String> date,
      Value<String> dataPayload,
      Value<int> rowid,
    });

class $$PatientHistoryRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $PatientHistoryRecordsTable> {
  $$PatientHistoryRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get patientId => $composableBuilder(
    column: $table.patientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataPayload => $composableBuilder(
    column: $table.dataPayload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PatientHistoryRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $PatientHistoryRecordsTable> {
  $$PatientHistoryRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get patientId => $composableBuilder(
    column: $table.patientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataPayload => $composableBuilder(
    column: $table.dataPayload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PatientHistoryRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PatientHistoryRecordsTable> {
  $$PatientHistoryRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get patientId =>
      $composableBuilder(column: $table.patientId, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get dataPayload => $composableBuilder(
    column: $table.dataPayload,
    builder: (column) => column,
  );
}

class $$PatientHistoryRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PatientHistoryRecordsTable,
          PatientHistoryRecord,
          $$PatientHistoryRecordsTableFilterComposer,
          $$PatientHistoryRecordsTableOrderingComposer,
          $$PatientHistoryRecordsTableAnnotationComposer,
          $$PatientHistoryRecordsTableCreateCompanionBuilder,
          $$PatientHistoryRecordsTableUpdateCompanionBuilder,
          (
            PatientHistoryRecord,
            BaseReferences<
              _$AppDatabase,
              $PatientHistoryRecordsTable,
              PatientHistoryRecord
            >,
          ),
          PatientHistoryRecord,
          PrefetchHooks Function()
        > {
  $$PatientHistoryRecordsTableTableManager(
    _$AppDatabase db,
    $PatientHistoryRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PatientHistoryRecordsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PatientHistoryRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PatientHistoryRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> patientId = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> dataPayload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PatientHistoryRecordsCompanion(
                patientId: patientId,
                date: date,
                dataPayload: dataPayload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int patientId,
                required String date,
                required String dataPayload,
                Value<int> rowid = const Value.absent(),
              }) => PatientHistoryRecordsCompanion.insert(
                patientId: patientId,
                date: date,
                dataPayload: dataPayload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PatientHistoryRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PatientHistoryRecordsTable,
      PatientHistoryRecord,
      $$PatientHistoryRecordsTableFilterComposer,
      $$PatientHistoryRecordsTableOrderingComposer,
      $$PatientHistoryRecordsTableAnnotationComposer,
      $$PatientHistoryRecordsTableCreateCompanionBuilder,
      $$PatientHistoryRecordsTableUpdateCompanionBuilder,
      (
        PatientHistoryRecord,
        BaseReferences<
          _$AppDatabase,
          $PatientHistoryRecordsTable,
          PatientHistoryRecord
        >,
      ),
      PatientHistoryRecord,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DailySyncStatusRowsTableTableManager get dailySyncStatusRows =>
      $$DailySyncStatusRowsTableTableManager(_db, _db.dailySyncStatusRows);
  $$PatientHistoryRecordsTableTableManager get patientHistoryRecords =>
      $$PatientHistoryRecordsTableTableManager(_db, _db.patientHistoryRecords);
}
