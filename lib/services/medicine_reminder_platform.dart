bool get reminderSupported => false;

Future<void> initReminders() async {}

Future<List<String>> timesFor(String medicine) async => const [];

Future<void> addReminder(String medicine, int hour, int minute, String body) async {}

Future<bool> askExactAlarmOnce() async => false;

Future<void> removeReminder(String medicine, int hour, int minute) async {}
