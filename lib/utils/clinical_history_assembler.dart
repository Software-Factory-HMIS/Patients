/// Turns `GET .../clinical-history` JSON into per-visit maps used by
/// OPD file, IPD file, and history dashboard.
class ClinicalHistoryAssembler {
  static int? parseId(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static Map<int, List<dynamic>> groupByEncounterId(List<dynamic>? rows) {
    final map = <int, List<dynamic>>{};
    if (rows == null) return map;
    for (final row in rows) {
      if (row is! Map) continue;
      final id = parseId(
        row['encounterId'] ?? row['EncounterId'] ?? row['EncounterID'],
      );
      if (id == null) continue;
      map.putIfAbsent(id, () => []).add(Map<String, dynamic>.from(row));
    }
    return map;
  }

  static List<Map<String, dynamic>> fromHistory(Map<String, dynamic> history) {
    final encounters = List<Map<String, dynamic>>.from(
      (history['encounters'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map)) ??
          const [],
    );
    final modules =
        (history['encounterModules'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final vitalsBy = groupByEncounterId(history['vitals'] as List?);
    final complaintsBy = groupByEncounterId(modules['complaints'] as List?);
    final symptomsBy = groupByEncounterId(modules['symptoms'] as List?);
    final diagnosesBy = groupByEncounterId(modules['diagnoses'] as List?);
    final labBy = groupByEncounterId(modules['labOrders'] as List?);
    final radBy = groupByEncounterId(modules['radiologyOrders'] as List?);
    final medsBy = groupByEncounterId(modules['medicines'] as List?);
    final notesBy = groupByEncounterId(modules['notes'] as List?);

    final out = <Map<String, dynamic>>[];
    for (final encounter in encounters) {
      final id = parseId(encounter['encounterId'] ?? encounter['EncounterID']);
      if (id == null) continue;
      final notes = notesBy[id] ?? const [];
      out.add({
        'encounter': encounter,
        'vitals': vitalsBy[id] ?? const [],
        'complaints': complaintsBy[id] ?? const [],
        'symptoms': symptomsBy[id] ?? const [],
        'diagnoses': diagnosesBy[id] ?? const [],
        'labOrders': labBy[id] ?? const [],
        'radiologyOrders': radBy[id] ?? const [],
        'medicines': medsBy[id] ?? const [],
        'notes': notes,
        'clinicalNotes': notes,
      });
    }
    return out;
  }
}
