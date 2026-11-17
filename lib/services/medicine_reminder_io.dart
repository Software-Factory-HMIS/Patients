import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool get reminderSupported => true;

const _prefsKey = 'patient_medicine_reminders_v1';
const _exactAskedKey = 'patient_exact_alarm_asked_v1';
final _plugin = FlutterLocalNotificationsPlugin();
var _ready = false;

Future<void> initReminders() async {
  if (_ready) return;
  try {
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  await _plugin.initialize(
    const InitializationSettings(android: android, iOS: ios),
  );
  await _plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
  _ready = true;
  final saved = await _load();
  for (final item in saved) {
    try {
      await _schedule(item);
    } catch (_) {}
  }
  } catch (_) {
    _ready = false;
  }
}

Future<List<String>> timesFor(String medicine) async {
  final saved = await _load();
  final times = saved
      .where((e) => e.medicine == medicine)
      .map((e) => _label(e.hour, e.minute))
      .toList();
  times.sort();
  return times;
}

Future<bool> askExactAlarmOnce() async {
  await initReminders();
  final android = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  if (android == null) return false;
  final allowed = await android.canScheduleExactNotifications();
  if (allowed == true) return false;
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_exactAskedKey) == true) return false;
  await prefs.setBool(_exactAskedKey, true);
  try {
    await android.requestExactAlarmsPermission();
  } catch (_) {}
  final nowAllowed = await android.canScheduleExactNotifications();
  return nowAllowed != true;
}

Future<void> addReminder(
  String medicine,
  int hour,
  int minute,
  String body,
) async {
  await initReminders();
  if (!_ready) {
    throw Exception('Could not save the reminder on this phone.');
  }
  final saved = await _load();
  final next = _Reminder(medicine, hour, minute, body);
  if (saved.any((e) => e.id == next.id)) return;
  saved.add(next);
  await _save(saved);
  try {
    await _schedule(next);
  } catch (_) {
    saved.removeWhere((e) => e.id == next.id);
    await _save(saved);
    throw Exception('Could not save the reminder on this phone.');
  }
}

Future<void> removeReminder(String medicine, int hour, int minute) async {
  final item = _Reminder(medicine, hour, minute, '');
  final saved = await _load();
  saved.removeWhere((e) => e.id == item.id);
  await _save(saved);
  if (_ready) await _plugin.cancel(item.id);
}

Future<void> _schedule(_Reminder item) async {
  final now = tz.TZDateTime.now(tz.local);
  var when = tz.TZDateTime(
    tz.local,
    now.year,
    now.month,
    now.day,
    item.hour,
    item.minute,
  );
  if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
  final android = _plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  final exact = await android?.canScheduleExactNotifications() ?? false;
  await _plugin.zonedSchedule(
    item.id,
    item.medicine,
    item.body.isEmpty ? item.medicine : item.body,
    when,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'medicines',
        'Medicine reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
    androidScheduleMode: exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
  );
}

Future<List<_Reminder>> _load() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_prefsKey);
  if (raw == null || raw.isEmpty) return [];
  final decoded = jsonDecode(raw);
  if (decoded is! List) return [];
  return decoded
      .whereType<Map>()
      .map((e) => _Reminder(
            e['medicine']?.toString() ?? '',
            int.tryParse(e['hour']?.toString() ?? '') ?? 0,
            int.tryParse(e['minute']?.toString() ?? '') ?? 0,
            e['body']?.toString() ?? '',
          ))
      .where((e) => e.medicine.isNotEmpty)
      .toList();
}

Future<void> _save(List<_Reminder> items) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _prefsKey,
    jsonEncode(items
        .map((e) => {
              'medicine': e.medicine,
              'hour': e.hour,
              'minute': e.minute,
              'body': e.body,
            })
        .toList()),
  );
}

String _label(int hour, int minute) {
  final h = hour.toString().padLeft(2, '0');
  final m = minute.toString().padLeft(2, '0');
  return '$h:$m';
}

class _Reminder {
  final String medicine;
  final int hour;
  final int minute;
  final String body;

  _Reminder(this.medicine, this.hour, this.minute, this.body);

  int get id => _stableId('$medicine|$hour|$minute');
}

int _stableId(String value) {
  var hash = 2166136261;
  for (final code in value.codeUnits) {
    hash ^= code;
    hash = (hash * 16777619) & 0x3fffffff;
  }
  return hash == 0 ? 1 : hash;
}
