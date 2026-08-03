import 'dart:convert';
import 'package:drift/drift.dart';
// Web when dart.library.io absent; native when present (mobile/desktop).
import 'database_connection_web.dart' if (dart.library.io) 'database_connection_native.dart' as db_connection;
import '../models/patient_history_models.dart';

part 'app_database.g.dart';

class DailySyncStatusRows extends Table {
  IntColumn get patientId => integer()();
  TextColumn get date => text()();
  TextColumn get status => text()();
  TextColumn get lastUpdated => text()();

  @override
  Set<Column<Object>> get primaryKey => {patientId, date};
}

class PatientHistoryRecords extends Table {
  IntColumn get patientId => integer()();
  TextColumn get date => text()();
  TextColumn get dataPayload => text()();

  @override
  Set<Column<Object>> get primaryKey => {patientId, date};
}

@DriftDatabase(tables: [DailySyncStatusRows, PatientHistoryRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(db_connection.openDatabaseConnection());

  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase();

  @override
  int get schemaVersion => 1;

  /// Returns completed days (status = COMPLETE) for patient in [start,end] (inclusive).
  Future<List<DateTime>> getCompletedDays(int patientId, DateTime start, DateTime end) async {
    final startStr = _toDateStr(start);
    final endStr = _toDateStr(end);
    final query = select(dailySyncStatusRows)
      ..where((t) =>
          t.patientId.equals(patientId) &
          t.date.isBetweenValues(startStr, endStr) &
          t.status.equals('COMPLETE'));
    final rows = await query.get();
    return rows.map((r) => _parseDate(r.date)).whereType<DateTime>().toList();
  }

  /// Watch history rows in range; map to [PatientHistoryDay] and emit as list (ordered by date).
  Stream<List<PatientHistoryDay>> watchHistoryInRange(int patientId, DateTime start, DateTime end) {
    final startStr = _toDateStr(start);
    final endStr = _toDateStr(end);
    final query = select(patientHistoryRecords)
      ..where((t) =>
          t.patientId.equals(patientId) &
          t.date.isBetweenValues(startStr, endStr))
      ..orderBy([(t) => OrderingTerm.asc(t.date)]);
    return query.watch().map((rows) {
      return rows.map((row) {
        final date = _parseDate(row.date);
        List<Map<String, dynamic>> list = [];
        if (row.dataPayload.isNotEmpty) {
          try {
            final decoded = json.decode(row.dataPayload);
            if (decoded is List) {
              list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            }
          } catch (_) {}
        }
        return PatientHistoryDay(date: date ?? DateTime(1970), encounterDataList: list);
      }).toList();
    });
  }

  /// Upsert one patient-day record and its sync status in a transaction.
  Future<void> upsertHistoryAndStatus({
    required int patientId,
    required DateTime date,
    required String dataPayloadJson,
    required bool isComplete,
  }) async {
    final dateStr = _toDateStr(date);
    final now = DateTime.now().toIso8601String();
    final status = isComplete ? 'COMPLETE' : 'INCOMPLETE';
    await transaction(() async {
      await patientHistoryRecords.insertOnConflictUpdate(
        PatientHistoryRecordsCompanion.insert(
          patientId: patientId,
          date: dateStr,
          dataPayload: dataPayloadJson,
        ),
      );
      await dailySyncStatusRows.insertOnConflictUpdate(
        DailySyncStatusRowsCompanion.insert(
          patientId: patientId,
          date: dateStr,
          status: status,
          lastUpdated: now,
        ),
      );
    });
  }

  /// Batch upsert: multiple days for one patient. [dayPayloads] = map of date -> JSON payload.
  /// [isCompleteForDay] = (date) => true if that day should be marked COMPLETE (false for today).
  Future<void> upsertHistoryRange({
    required int patientId,
    required Map<DateTime, String> dayPayloads,
    required bool Function(DateTime day) isCompleteForDay,
  }) async {
    await transaction(() async {
      final now = DateTime.now().toIso8601String();
      for (final entry in dayPayloads.entries) {
        final dateStr = _toDateStr(entry.key);
        final status = isCompleteForDay(entry.key) ? 'COMPLETE' : 'INCOMPLETE';
        await patientHistoryRecords.insertOnConflictUpdate(
          PatientHistoryRecordsCompanion.insert(
            patientId: patientId,
            date: dateStr,
            dataPayload: entry.value,
          ),
        );
        await dailySyncStatusRows.insertOnConflictUpdate(
          DailySyncStatusRowsCompanion.insert(
            patientId: patientId,
            date: dateStr,
            status: status,
            lastUpdated: now,
          ),
        );
      }
    });
  }

  static String _toDateStr(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static DateTime? _parseDate(String s) {
    final parts = s.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }
}
