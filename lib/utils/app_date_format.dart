import 'package:intl/intl.dart';

/// Consistent user-facing date formatting across the Patients app.
class AppDateFormat {
  AppDateFormat._();

  static final DateFormat _date = DateFormat('dd-MM-yyyy');
  static final DateFormat _dateTime = DateFormat('dd-MM-yyyy HH:mm');
  static final DateFormat _time = DateFormat('h:mm a');

  static DateTime? parse(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static String? formatDateOrNull(dynamic value) {
    if (value == null) return null;
    final formatted = formatDate(value);
    return formatted.isEmpty ? null : formatted;
  }

  static String formatDate(dynamic value, {String fallback = ''}) {
    final dt = parse(value);
    if (dt == null) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? fallback : text;
    }
    return _date.format(dt);
  }

  static String formatDateTime(dynamic value, {String fallback = ''}) {
    final dt = parse(value);
    if (dt == null) return fallback;
    return _dateTime.format(dt);
  }

  static String formatTime(dynamic value, {String fallback = ''}) {
    final dt = parse(value);
    if (dt == null) return fallback;
    return _time.format(dt);
  }
}
