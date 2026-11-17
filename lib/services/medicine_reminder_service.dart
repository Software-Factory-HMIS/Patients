import 'medicine_reminder_platform.dart' as platform
    if (dart.library.io) 'medicine_reminder_io.dart';

class MedicineReminderService {
  static bool get supported => platform.reminderSupported;

  static Future<void> init() => platform.initReminders();

  static Future<List<String>> timesFor(String medicine) =>
      platform.timesFor(medicine);

  static Future<bool> askExactAlarmOnce() => platform.askExactAlarmOnce();

  static Future<void> addTime(
    String medicine,
    int hour,
    int minute, {
    required String body,
  }) =>
      platform.addReminder(medicine, hour, minute, body);

  static Future<void> removeTime(String medicine, int hour, int minute) =>
      platform.removeReminder(medicine, hour, minute);
}
