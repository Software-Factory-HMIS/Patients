import 'dart:convert';
import '../database/app_database.dart';
import '../models/patient_history_models.dart';
import '../services/encounter_service.dart';
import 'patient_history_gap_finder.dart' show dateOnly, isSameDay, computeDaysToFetch, convertDaysToRanges;

class PatientHistoryRepository {
  final EncounterService _encounterService;
  final AppDatabase _db;

  PatientHistoryRepository(this._encounterService, this._db);

  /// UI listens to this stream. Data always comes from local DB; sync runs in background.
  Stream<List<PatientHistoryDay>> getHistory(
    int patientId,
    DateTime start,
    DateTime end,
  ) async* {
    yield* _db.watchHistoryInRange(patientId, start, end);
    // Trigger gap-fill in background; DB stream will emit when new data is written.
    unawaited(_syncMissingData(patientId, start, end));
  }

  Future<void> _syncMissingData(int patientId, DateTime start, DateTime end) async {
    final today = dateOnly(DateTime.now());
    final completedDays = await _db.getCompletedDays(patientId, start, end);
    final daysToFetch = computeDaysToFetch(
      reqStart: start,
      reqEnd: end,
      completedDays: completedDays,
      today: today,
    );
    if (daysToFetch.isEmpty) return;

    final ranges = convertDaysToRanges(daysToFetch);

    for (final range in ranges) {
      try {
        final encounters = await _encounterService.getAllPatientEncounters(
          patientId,
          fromDate: range.start,
          toDate: range.end,
        );
        final vitals = await _encounterService.getPatientVitals(
          patientId,
          fromDate: range.start,
          toDate: range.end,
        );

        final vitalsByEncounterId = <int, List<dynamic>>{};
        for (final v in vitals) {
          final eid = v['encounterId'] ?? v['EncounterID'] ?? v['encounterID'];
          if (eid == null) continue;
          final id = eid is int ? eid : int.tryParse(eid.toString());
          if (id != null) {
            vitalsByEncounterId.putIfAbsent(id, () => []).add(v);
          }
        }

        final encounterDataByDay = <DateTime, List<Map<String, dynamic>>>{};

        for (final encounter in encounters) {
          final encounterId = encounter['encounterId'] ?? encounter['EncounterID'] ?? encounter['encounterID'];
          if (encounterId == null) continue;
          final parsedId = encounterId is int ? encounterId : int.tryParse(encounterId.toString());
          if (parsedId == null) continue;

          Map<String, dynamic> consultationData = {};
          try {
            consultationData = await _encounterService.getEncounterConsultationData(
              parsedId,
              patientId: patientId,
            );
          } catch (_) {}

          final item = {
            'encounter': encounter,
            'vitals': vitalsByEncounterId[parsedId] ?? [],
            'complaints': consultationData['complaints'] ?? [],
            'symptoms': consultationData['symptoms'] ?? [],
            'diagnoses': consultationData['diagnoses'] ?? [],
            'labOrders': consultationData['labOrders'] ?? [],
            'radiologyOrders': consultationData['radiologyOrders'] ?? [],
            'medicines': consultationData['medicines'] ?? [],
            'notes': consultationData['notes'] ?? consultationData['patientNotes'] ?? [],
            'clinicalNotes': consultationData['clinicalNotes'] ?? consultationData['clinicalNote'] ?? '',
          };

          final encounterDateRaw = encounter['encounterDate'] ?? encounter['EncounterDate'] ?? encounter['checkInTime'];
          final day = _dayFromEncounterDate(encounterDateRaw);
          if (day != null) {
            encounterDataByDay.putIfAbsent(day, () => []).add(item);
          }
        }

        // Ensure every day in range has an entry (even if empty)
        for (DateTime d = dateOnly(range.start);
            !d.isAfter(dateOnly(range.end));
            d = d.add(const Duration(days: 1))) {
          encounterDataByDay.putIfAbsent(d, () => []);
        }

        final dayPayloads = <DateTime, String>{};
        for (final entry in encounterDataByDay.entries) {
          dayPayloads[entry.key] = json.encode(entry.value);
        }

        await _db.upsertHistoryRange(
          patientId: patientId,
          dayPayloads: dayPayloads,
          isCompleteForDay: (day) => !isSameDay(day, today),
        );
      } catch (e) {
        print('Could not sync range: ${range.start} - ${range.end}: $e');
      }
    }
  }

  static DateTime? _dayFromEncounterDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return dateOnly(value);
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    final dt = DateTime.tryParse(s);
    return dt != null ? dateOnly(dt) : null;
  }
}

void unawaited(Future<void> f) {
  // ignore: unawaited_futures
  f;
}
