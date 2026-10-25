import 'dart:async';

import '../models/appointment_models.dart';
import '../utils/emr_api_client.dart';

/// In-memory hospital + department catalog. Refreshed every 12 hours.
class HospitalCatalogCache {
  HospitalCatalogCache._();
  static final instance = HospitalCatalogCache._();

  static const ttl = Duration(hours: 12);

  final EmrApiClient _api = EmrApiClient();

  DateTime? _hospitalsAt;
  List<Hospital> _hospitals = [];
  DateTime? _bookableAt;
  List<Hospital> _bookable = [];
  DateTime? _deptsAt;
  final Map<int, List<HospitalDepartment>> _depts = {};
  Future<List<Hospital>>? _hospitalsInFlight;

  Future<List<Hospital>> hospitals({bool force = false}) async {
    if (!force &&
        _hospitals.isNotEmpty &&
        _hospitalsAt != null &&
        DateTime.now().difference(_hospitalsAt!) < ttl) {
      return _hospitals;
    }
    final pending = _hospitalsInFlight;
    if (pending != null) return pending;
    final future = _loadHospitals();
    _hospitalsInFlight = future;
    try {
      return await future;
    } finally {
      _hospitalsInFlight = null;
    }
  }

  Future<List<Hospital>> _loadHospitals() async {
    final rows = await _api.searchHospitals('', limit: 1000);
    final list = <Hospital>[];
    for (final row in rows) {
      try {
        final h = Hospital.fromJson(Map<String, dynamic>.from(row as Map));
        if (h.isActive && h.hospitalID > 0 && h.name.isNotEmpty) {
          list.add(h);
        }
      } catch (_) {}
    }
    _hospitals = list;
    _hospitalsAt = DateTime.now();
    return list;
  }

  Future<List<Hospital>> thqDhqHospitals({bool force = false}) async {
    return (await hospitals(force: force)).where((h) => h.isThqOrDhq).toList();
  }

  /// THQ, DHQ, MNH, and MNHC only, loaded per level so a name-sorted first page
  /// cannot hide the nearby ones behind demo or admin sites.
  Future<List<Hospital>> nearbyBookableHospitals({bool force = false}) async {
    if (!force &&
        _bookable.isNotEmpty &&
        _bookableAt != null &&
        DateTime.now().difference(_bookableAt!) < ttl) {
      return _bookable;
    }
    const levels = ['THQ', 'DHQ', 'MNH', 'MNHC', 'MHHC'];
    final merged = <int, Hospital>{};
    for (final level in levels) {
      final rows = await _api.searchHospitals('', limit: 1000, hospitalLevel: level);
      for (final row in rows) {
        try {
          final h = Hospital.fromJson(Map<String, dynamic>.from(row as Map));
          if (h.isActive && h.hospitalID > 0 && h.isNearbyBookable) {
            merged[h.hospitalID] = h;
          }
        } catch (_) {}
      }
    }
    _bookable = merged.values.toList();
    _bookableAt = DateTime.now();
    return _bookable;
  }

  Future<List<HospitalDepartment>> departments(int hospitalId) async {
    if (hospitalId <= 0) return const [];
    if (_deptsAt != null && DateTime.now().difference(_deptsAt!) >= ttl) {
      _depts.clear();
      _deptsAt = null;
    }
    final cached = _depts[hospitalId];
    if (cached != null) return cached;
    try {
      final data = await _api.fetchHospitalDepartments(hospitalId);
      final depts = <HospitalDepartment>[];
      for (final item in data) {
        try {
          final d = HospitalDepartment.fromJson(
            Map<String, dynamic>.from(item as Map),
          );
          if (d.hospitalDepartmentID > 0) depts.add(d);
        } catch (_) {}
      }
      _depts[hospitalId] = depts;
      _deptsAt ??= DateTime.now();
      return depts;
    } catch (_) {
      return const [];
    }
  }

  void clear() {
    _hospitals = [];
    _hospitalsAt = null;
    _bookable = [];
    _bookableAt = null;
    _hospitalsInFlight = null;
    _depts.clear();
    _deptsAt = null;
  }

  Future<void> prefetchDepartments(Iterable<int> hospitalIds) async {
    for (final id in hospitalIds) {
      await departments(id);
    }
  }

  /// Warm hospitals, then fill THQ/DHQ departments in the background.
  Future<void> warmUp() async {
    final thq = await thqDhqHospitals();
    unawaited(_prefetchAll(thq.map((h) => h.hospitalID)));
  }

  Future<void> _prefetchAll(Iterable<int> ids) async {
    for (final id in ids) {
      await departments(id);
    }
  }
}
