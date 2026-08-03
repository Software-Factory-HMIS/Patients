/// One calendar day's history: date + list of encounter-data maps
/// (same shape as _encounterDataList items in patient_history_dashboard_screen).
class PatientHistoryDay {
  final DateTime date;
  final List<Map<String, dynamic>> encounterDataList;

  const PatientHistoryDay({required this.date, required this.encounterDataList});
}

/// Contiguous date range for API requests.
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});
}
