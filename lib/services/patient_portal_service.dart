import 'package:flutter/foundation.dart';

import '../models/portal_models.dart';
import '../utils/emr_api_client.dart';
import '../utils/user_storage.dart';

class PatientPortalService {
  final EmrApiClient _api;

  PatientPortalService({EmrApiClient? api}) : _api = api ?? EmrApiClient();

  /// Bumped when queue visits change (e.g. after booking). Home listens to refresh.
  static final ValueNotifier<int> visitRevision = ValueNotifier(0);

  static void notifyVisitsChanged() => visitRevision.value++;

  Future<Map<String, dynamic>> fetchPatientProfile(String identifier) async {
    return _api.fetchPatient(identifier);
  }

  int? parsePatientId(Map<String, dynamic> patient) {
    final id = patient['patientId'] ?? patient['PatientID'];
    if (id is int) return id;
    return int.tryParse(id?.toString() ?? '');
  }

  String patientCnic(Map<String, dynamic> patient) {
    return (patient['cnic'] ?? patient['CNIC'] ?? '').toString();
  }

  static String normalizeCnic(String? value) {
    if (value == null) return '';
    return value.replaceAll(RegExp(r'\D'), '');
  }

  Future<HomeStats> loadHomeStats(int patientId) async {
    final twelveMonthsAgo = DateTime.now().subtract(const Duration(days: 365));
    final results = await Future.wait([
      _api.getAllPatientEncounters(patientId, fromDate: twelveMonthsAgo),
      _api.getActivePatientMedicines(patientId: patientId),
      _api.getPatientLabSummary(patientId),
      _api.getPatientRadiologySummary(patientId),
    ]);

    final encounters = results[0] as List<Map<String, dynamic>>;
    final activeMeds = results[1] as List<Map<String, dynamic>>;
    final labSummary = results[2] as Map<String, dynamic>;
    final radSummary = results[3] as Map<String, dynamic>;

    final lab = LabResultsSummary.fromJson(labSummary);
    final rad = RadiologySummary.fromJson(radSummary);

    return HomeStats(
      visitCount: encounters.length,
      activePrescriptions: activeMeds.length,
      labResults: lab.total,
      radiologyReports: rad.total,
      labSummary: lab,
      radiologySummary: rad,
    );
  }

  Future<LabResultsSummary> loadLabSummary(int patientId) async {
    final data = await _api.getPatientLabSummary(patientId);
    return LabResultsSummary.fromJson(data);
  }

  Future<RadiologySummary> loadRadiologySummary(int patientId) async {
    final data = await _api.getPatientRadiologySummary(patientId);
    return RadiologySummary.fromJson(data);
  }

  Future<List<LabReport>> loadLabReports(int patientId) async {
    final rows = await _api.getPatientLabResults(patientId);
    return rows.map(LabReport.fromJson).toList();
  }

  Future<List<RadiologyReport>> loadRadiologyReports(int patientId) async {
    final rows = await _api.getPatientRadiologyReports(patientId);
    return rows.map(RadiologyReport.fromJson).toList();
  }

  Future<List<PrescriptionItem>> loadPrescriptions(int patientId) async {
    final rows = await _api.getPatientPrescriptions(patientId);
    return rows.map(PrescriptionItem.fromJson).toList();
  }

  Future<List<PrescriptionItem>> loadActivePrescriptions(int patientId) async {
    final rows = await _api.getActivePatientMedicines(patientId: patientId);
    return rows.map(PrescriptionItem.fromJson).where((rx) => rx.isActive).toList();
  }

  Future<List<PrescriptionItem>> loadPrescriptionHistory(int patientId) async {
    final rows = await _api.getActivePatientMedicines(
      patientId: patientId,
      getAllHistory: true,
    );
    return rows.map(PrescriptionItem.fromJson).toList();
  }

  /// Most recent active/upcoming visit from live HMIS queue APIs only.
  Future<Map<String, dynamic>?> loadUpcomingVisit({
    required int patientId,
    required String patientCnic,
    Map<String, dynamic>? patient,
  }) async {
    final visits = await _loadLiveQueueVisits(
      patientId: patientId,
      patientCnic: patientCnic,
      patient: patient,
    );
    final upcoming = visits.where((v) => _isRelevantVisitDate(_visitDate(v))).toList();
    if (upcoming.isEmpty) return null;
    return _enrichVisitDetails(upcoming.first);
  }

  /// Recent OPD queue visits from live HMIS APIs (same source as [loadUpcomingVisit]).
  Future<List<Map<String, dynamic>>> loadRecentVisits({
    required int patientId,
    required String patientCnic,
    Map<String, dynamic>? patient,
    int limit = 5,
  }) async {
    final visits = await _loadLiveQueueVisits(
      patientId: patientId,
      patientCnic: patientCnic,
      patient: patient,
    );
    final enriched = <Map<String, dynamic>>[];
    for (final visit in visits.take(limit)) {
      enriched.add(await _enrichVisitDetails(visit));
    }
    return enriched;
  }

  Future<List<Map<String, dynamic>>> _loadLiveQueueVisits({
    required int patientId,
    required String patientCnic,
    Map<String, dynamic>? patient,
  }) async {
    final normalizedCnic = normalizeCnic(patientCnic);
    final hospitalIds = await _collectHospitalIds(patientId, patient);
    if (hospitalIds.isEmpty) return [];

    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    final mrn = patient?['mrn'] ?? patient?['MRN'];
    final searchTerms = <String>{
      if (normalizedCnic.length == 13) normalizedCnic,
      if (mrn != null && mrn.toString().trim().isNotEmpty) mrn.toString().trim(),
    };

    final byQueueId = <int, Map<String, dynamic>>{};

    void absorbRow(Map<String, dynamic> row) {
      if (!_rowBelongsToPatient(row, patientId)) return;
      if (!_isActiveQueueRow(row)) return;

      final mapped = _mapQueueRow(row);
      final token = mapped['tokenNumber']?.toString().trim();
      if (token == null || token.isEmpty) return;

      final queueId = _asInt(mapped['queueId']);
      if (queueId > 0) {
        byQueueId[queueId] = mapped;
        return;
      }

      byQueueId[byQueueId.length + 1] = mapped;
    }

    for (final hospitalId in hospitalIds) {
      final latest = await _api.getLatestPatientOpdVisits(
        patientId: patientId,
        hospitalId: hospitalId,
        howMany: 5,
      );
      for (final row in latest) {
        absorbRow(row);
      }

      for (final term in searchTerms) {
        final rows = await _api.searchPatientQueue(
          hospitalId: hospitalId,
          searchText: term,
          startDate: start,
          endDate: end,
          queueStatus: 'ALL',
        );
        for (final row in rows) {
          absorbRow(row);
        }
      }
    }

    final visits = byQueueId.values.toList();
    visits.sort((a, b) {
      final da = _visitDate(a);
      final db = _visitDate(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    return visits;
  }

  Future<Set<int>> _collectHospitalIds(
    int patientId,
    Map<String, dynamic>? patient,
  ) async {
    final ids = <int>{};

    void addId(dynamic value) {
      if (value is int && value > 0) ids.add(value);
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null && parsed > 0) ids.add(parsed);
    }

    addId(patient?['hospitalId']);
    addId(patient?['HospitalID']);

    for (final id in await UserStorage.getKnownHospitalIds()) {
      ids.add(id);
    }

    try {
      final encounters = await _api.getAllPatientEncounters(
        patientId,
        fromDate: DateTime.now().subtract(const Duration(days: 120)),
      );
      for (final e in encounters.take(20)) {
        addId(e['hospitalId']);
        addId(e['HospitalID']);
      }
    } catch (_) {}

    return ids;
  }

  bool _rowBelongsToPatient(Map<String, dynamic> row, int patientId) {
    final rowPatientId = row['patientId'] ?? row['PatientId'] ?? row['PatientID'];
    final parsed = rowPatientId is int ? rowPatientId : int.tryParse(rowPatientId?.toString() ?? '');
    return parsed == patientId;
  }

  bool _isActiveQueueRow(Map<String, dynamic> row) {
    final status = (row['queueStatus'] ?? row['QueueStatus'] ?? row['status'] ?? row['Status'] ?? '')
        .toString()
        .toLowerCase();
    if (status.contains('cancel')) return false;
    if (status.contains('checked out') || status.contains('completed')) return false;
    return true;
  }

  Future<Map<String, dynamic>> _enrichVisitDetails(Map<String, dynamic> visit) async {
    final merged = Map<String, dynamic>.from(visit);
    final hospitalId = _asInt(merged['hospitalId']);
    final deptId = _asInt(merged['hospitalDepartmentId']);

    if (hospitalId > 0 &&
        _isGenericLabel(merged['departmentName'], 'outpatient', 'department') &&
        deptId > 0) {
      try {
        final departments = await _api.fetchHospitalDepartments(hospitalId);
        for (final entry in departments) {
          if (entry is! Map) continue;
          final map = Map<String, dynamic>.from(entry as Map);
          final rowDeptId = _asInt(
            map['hospitalDepartmentID'] ?? map['hospitalDepartmentId'] ?? map['HospitalDepartmentID'],
          );
          if (rowDeptId == deptId) {
            final name = _pickField(map, const [
              'departmentName',
              'DepartmentName',
              'name',
              'Name',
            ]);
            if (name != null) merged['departmentName'] = name;
            break;
          }
        }
      } catch (_) {}
    }

    if (hospitalId > 0 && _isGenericLabel(merged['hospitalName'], 'hospital')) {
      try {
        final hospital = await _api.fetchHospitalById(hospitalId);
        if (hospital != null) {
          final name = _pickFieldInsensitive(hospital, const [
            'name',
            'hospitalName',
            'hospital_Name',
          ]);
          if (name != null) merged['hospitalName'] = name;
        }
      } catch (_) {}
    }

    return merged;
  }

  static String? _pickField(Map<String, dynamic> row, List<String> keys) {
    return _pickFieldInsensitive(row, keys);
  }

  static String? _pickFieldInsensitive(Map<String, dynamic> row, List<String> keys) {
    final normalized = <String, dynamic>{};
    row.forEach((key, value) => normalized[key.toString().toLowerCase()] = value);

    for (final key in keys) {
      final value = normalized[key.toLowerCase()];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
  }

  static dynamic _pickValueInsensitive(Map<String, dynamic> row, List<String> keys) {
    final normalized = <String, dynamic>{};
    row.forEach((key, value) => normalized[key.toString().toLowerCase()] = value);

    for (final key in keys) {
      final value = normalized[key.toLowerCase()];
      if (value != null) return value;
    }
    return null;
  }

  static bool _isGenericLabel(dynamic value, String generic, [String? generic2]) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text.isEmpty) return true;
    if (text == generic.toLowerCase()) return true;
    if (generic2 != null && text == generic2.toLowerCase()) return true;
    return false;
  }

  Map<String, dynamic> _mapQueueRow(Map<String, dynamic> row) {
    final date = _parseDate(
      _pickValueInsensitive(row, const [
        'addedToQueueAt',
        'queueDate',
        'entryTime',
        'scheduledDate',
        'appointmentDate',
        'visitDate',
        'createdAt',
      ]),
    );

    return {
      'hospitalName': _pickFieldInsensitive(row, const [
            'hospitalName',
            'hospital_Name',
            'hospital',
            'facilityName',
          ]) ??
          'Hospital',
      'departmentName': _pickFieldInsensitive(row, const [
            'departmentName',
            'department_Name',
            'hospitalDepartmentName',
            'deptName',
            'department',
          ]) ??
          'Outpatient',
      'appointmentDate': date?.toIso8601String(),
      'queueDate': date?.toIso8601String(),
      'tokenNumber': _pickValueInsensitive(row, const ['tokenNumber', 'token', 'queueToken']),
      'queueId': _pickValueInsensitive(row, const ['queueId', 'queueID']),
      'room': _pickValueInsensitive(row, const ['room', 'roomNumber']),
      'hospitalId': _pickValueInsensitive(row, const ['hospitalId', 'hospitalID']),
      'hospitalDepartmentId': _pickValueInsensitive(row, const [
        'hospitalDepartmentId',
        'hospitalDepartmentID',
        'departmentId',
        'departmentID',
      ]),
    };
  }

  bool _isRelevantVisitDate(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    if (_isSameDay(date, now)) return true;
    if (date.isAfter(now)) return true;
    return now.difference(date).inDays <= 30;
  }

  DateTime? _visitDate(Map<String, dynamic>? visit) {
    if (visit == null) return null;
    return _parseDate(visit['appointmentDate'] ?? visit['queueDate'] ?? visit['entryTime']);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
