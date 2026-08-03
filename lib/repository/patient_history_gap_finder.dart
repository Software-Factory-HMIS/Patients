import '../models/patient_history_models.dart';

/// Returns true if [a] and [b] are the same calendar day (date-only).
bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Normalizes [d] to date-only (midnight UTC).
DateTime dateOnly(DateTime d) {
  return DateTime.utc(d.year, d.month, d.day);
}

/// Given a list of calendar days to fetch, merges consecutive days into
/// contiguous [DateRange]s to minimize API calls.
List<DateRange> convertDaysToRanges(List<DateTime> days) {
  if (days.isEmpty) return [];
  final sorted = List<DateTime>.from(days)..sort((a, b) => a.compareTo(b));
  final ranges = <DateRange>[];
  DateTime rangeStart = dateOnly(sorted.first);
  DateTime rangeEnd = rangeStart;

  for (int i = 1; i < sorted.length; i++) {
    final d = dateOnly(sorted[i]);
    final gap = d.difference(rangeEnd).inDays;
    if (gap <= 1) {
      rangeEnd = d;
    } else {
      ranges.add(DateRange(start: rangeStart, end: rangeEnd));
      rangeStart = d;
      rangeEnd = d;
    }
  }
  ranges.add(DateRange(start: rangeStart, end: rangeEnd));
  return ranges;
}

/// Computes which days in [reqStart, reqEnd] need to be fetched from the API.
/// [getCompletedDays] returns dates that are already COMPLETE in the DB.
/// [today] is the current date (use one value for the whole sync).
/// Rule: any day not in completedDays, or that is today, must be fetched.
List<DateTime> computeDaysToFetch({
  required DateTime reqStart,
  required DateTime reqEnd,
  required List<DateTime> completedDays,
  required DateTime today,
}) {
  final start = dateOnly(reqStart);
  final end = dateOnly(reqEnd);
  final completedSet = completedDays.map(dateOnly).toSet();
  final daysToFetch = <DateTime>[];

  for (DateTime d = start;
      !d.isAfter(end);
      d = d.add(const Duration(days: 1))) {
    final day = dateOnly(d);
    final isCompleted = completedSet.contains(day);
    final isToday = isSameDay(day, today);
    if (!isCompleted || isToday) {
      daysToFetch.add(day);
    }
  }
  return daysToFetch;
}
