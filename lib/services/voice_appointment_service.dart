import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/appointment_models.dart';
import '../utils/emr_api_client.dart';
import '../utils/user_storage.dart';
import 'llm/gemini_live_booking_session.dart';
import 'llm/patient_ai_settings.dart';
import 'patient_portal_service.dart';

enum VoiceBookStep {
  idle,
  connecting,
  askHospital,
  askDate,
  rejectFutureDate,
  askComplaint,
  askDepartment,
  confirm,
  booking,
  done,
  failed,
}

class VoiceAppointmentService extends ChangeNotifier {
  VoiceAppointmentService({
    required this.patientId,
    required this.patient,
    this.savedUserData,
  });

  final int patientId;
  final Map<String, dynamic> patient;
  final Map<String, dynamic>? savedUserData;

  final _api = EmrApiClient();
  final _pcm = AudioRecorder();
  final _player = AudioPlayer();

  GeminiLiveBookingSession? _live;
  StreamSubscription<Uint8List>? _micSub;
  final BytesBuilder _replyPcm = BytesBuilder(copy: false);

  VoiceBookStep step = VoiceBookStep.idle;
  String status = '';
  String lastHeard = '';
  String lastSaid = '';
  Hospital? hospital;
  DateTime? visitDate;
  String complaint = '';
  HospitalDepartment? department;
  List<HospitalDepartment> _depts = [];
  AppointmentDetails? booked;
  String? error;

  bool get isLive => _live?.isOpen == true;

  Future<void> start() async {
    error = null;
    booked = null;
    hospital = null;
    visitDate = null;
    complaint = '';
    department = null;
    _depts = [];
    step = VoiceBookStep.connecting;
    status = 'Connecting to Gemini…';
    notifyListeners();

    final settings = await PatientAiSettings.load();
    if (!settings.isReady) {
      step = VoiceBookStep.failed;
      error = 'Add a Gemini API key in Settings → Voice booking.';
      status = error!;
      notifyListeners();
      return;
    }
    if (!await _pcm.hasPermission()) {
      step = VoiceBookStep.failed;
      error = 'Microphone permission is required.';
      status = error!;
      notifyListeners();
      return;
    }

    final live = GeminiLiveBookingSession(
      apiKey: settings.apiKey,
      model: settings.model,
    );
    live.onUserTranscript = _onUser;
    live.onAssistantTranscript = (t) {
      lastSaid = t;
      notifyListeners();
    };
    live.onAssistantAudio = (pcm) => _replyPcm.add(pcm);
    live.onTurnComplete = _playReply;
    live.onError = (e) {
      error = e;
      status = e;
      notifyListeners();
    };
    final ok = await live.connect();
    if (!ok) {
      step = VoiceBookStep.failed;
      error = 'Could not start Gemini Live. Check the key and model in Settings.';
      status = error!;
      notifyListeners();
      return;
    }
    _live = live;
    await _startMic();
    step = VoiceBookStep.askHospital;
    status = 'Which hospital?';
    live.sendAppText(
      'Greet the patient briefly. Ask which hospital they want to visit. One short sentence.',
    );
    notifyListeners();
  }

  Future<void> _playReply() async {
    final bytes = _replyPcm.takeBytes();
    if (bytes.isEmpty) return;
    try {
      final wav = _pcm16ToWav(bytes, sampleRate: 24000);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/gemini_live_reply.wav');
      await file.writeAsBytes(wav, flush: true);
      await _player.stop();
      await _player.play(DeviceFileSource(file.path));
    } catch (_) {}
  }

  static Uint8List _pcm16ToWav(List<int> pcm, {required int sampleRate}) {
    final data = Uint8List.fromList(pcm);
    final header = BytesBuilder();
    final byteRate = sampleRate * 2;
    header.add('RIFF'.codeUnits);
    header.add(_le32(36 + data.length));
    header.add('WAVE'.codeUnits);
    header.add('fmt '.codeUnits);
    header.add(_le32(16));
    header.add(_le16(1));
    header.add(_le16(1));
    header.add(_le32(sampleRate));
    header.add(_le32(byteRate));
    header.add(_le16(2));
    header.add(_le16(16));
    header.add('data'.codeUnits);
    header.add(_le32(data.length));
    header.add(data);
    return header.takeBytes();
  }

  static List<int> _le16(int v) => [v & 0xff, (v >> 8) & 0xff];
  static List<int> _le32(int v) => [
        v & 0xff,
        (v >> 8) & 0xff,
        (v >> 16) & 0xff,
        (v >> 24) & 0xff,
      ];

  Future<void> _startMic() async {
    final stream = await _pcm.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        numChannels: 1,
        sampleRate: 16000,
      ),
    );
    _micSub = stream.listen((chunk) {
      _live?.sendPcm16k(chunk);
    });
  }

  Future<void> _onUser(String raw) async {
    lastHeard = raw;
    notifyListeners();
    final text = raw.trim();
    if (text.isEmpty) return;

    switch (step) {
      case VoiceBookStep.askHospital:
        await _resolveHospital(text);
      case VoiceBookStep.askDate:
      case VoiceBookStep.rejectFutureDate:
        await _resolveDate(text);
      case VoiceBookStep.askComplaint:
        await _resolveComplaint(text);
      case VoiceBookStep.askDepartment:
        await _resolveDepartmentSpoken(text);
      case VoiceBookStep.confirm:
        await _resolveConfirm(text);
      default:
        break;
    }
  }

  Future<void> _resolveHospital(String text) async {
    final cleaned = text
        .replaceAll(RegExp(r'(i want|please|appointment|visit|hospital|ke liye|ka|ki|mein|me)', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final q = cleaned.isEmpty ? text : cleaned;
    try {
      final rows = await _api.searchHospitals(q, limit: 20);
      final hospitals = rows
          .map((e) => Hospital.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((h) => h.isActive && h.hospitalID > 0)
          .toList();
      Hospital? match;
      final needle = q.toLowerCase();
      for (final h in hospitals) {
        if (h.name.toLowerCase() == needle) {
          match = h;
          break;
        }
      }
      match ??= hospitals.cast<Hospital?>().firstWhere(
        (h) => h!.name.toLowerCase().contains(needle) || needle.contains(h.name.toLowerCase()),
        orElse: () => hospitals.isNotEmpty ? hospitals.first : null,
      );
      if (match == null) {
        _live?.sendAppText(
          'No hospital matched "$text". Ask them to say the hospital name again, slowly.',
        );
        status = 'Hospital not found. Say the name again.';
        notifyListeners();
        return;
      }
      hospital = match;
      step = VoiceBookStep.askDate;
      status = 'Hospital: ${match.name}. What date?';
      _live?.sendAppText(
        'Hospital found: ${match.name}. Ask what date they want. Remind them we can only book today\'s token.',
      );
      notifyListeners();
    } catch (e) {
      _live?.sendAppText('Hospital search failed. Ask them to repeat the hospital name.');
    }
  }

  Future<void> _resolveDate(String text) async {
    final parsed = parseSpokenDate(text);
    if (parsed == null) {
      _live?.sendAppText(
        'Could not understand the date. Ask them to say today, tomorrow, or a day and month.',
      );
      status = 'Say a date (today, or 20 September).';
      notifyListeners();
      return;
    }
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final day = DateTime(parsed.year, parsed.month, parsed.day);
    if (day.isBefore(today)) {
      _live?.sendAppText('That date is in the past. Ask for today or a future date.');
      status = 'Date is in the past.';
      notifyListeners();
      return;
    }
    if (day.isAfter(today)) {
      visitDate = day;
      step = VoiceBookStep.rejectFutureDate;
      status = 'We can only issue today\'s token.';
      _live?.sendAppText(
        'They asked for ${day.day}/${day.month}/${day.year}. Tell them we can only issue a queue token for today, not a future date. Ask them to say "today" if they want today\'s visit.',
      );
      notifyListeners();
      return;
    }
    visitDate = today;
    step = VoiceBookStep.askComplaint;
    status = 'Today. What is the complaint?';
    _live?.sendAppText(
      'Date accepted: today. Ask them to briefly say their complaint or symptom.',
    );
    notifyListeners();
  }

  Future<void> _resolveComplaint(String text) async {
    complaint = text;
    status = 'Finding department…';
    notifyListeners();
    try {
      final data = await _api.fetchHospitalDepartments(hospital!.hospitalID);
      _depts = [];
      for (final item in data) {
        try {
          final d = HospitalDepartment.fromJson(Map<String, dynamic>.from(item as Map));
          if (d.hospitalDepartmentID > 0) _depts.add(d);
        } catch (_) {}
      }
    } catch (_) {
      _depts = [];
    }
    final guessed = guessDepartment(_depts, text);
    if (guessed != null) {
      department = guessed;
      step = VoiceBookStep.confirm;
      status = 'Confirm booking';
      _live?.sendAppText(
        'Complaint: $text. Department: ${guessed.departmentName}. '
        'Ask them to confirm: book ${hospital!.name}, today, ${guessed.departmentName}, complaint "$text". '
        'They should say yes or no.',
      );
    } else {
      step = VoiceBookStep.askDepartment;
      status = 'Which department?';
      final names = _depts.take(6).map((d) => d.departmentName).join(', ');
      _live?.sendAppText(
        'Could not guess the department. Ask them to pick one: $names',
      );
    }
    notifyListeners();
  }

  Future<void> _resolveDepartmentSpoken(String text) async {
    final guessed = guessDepartment(_depts, text);
    if (guessed == null) {
      _live?.sendAppText('Department not found. Ask them to repeat a department name.');
      return;
    }
    department = guessed;
    step = VoiceBookStep.confirm;
    status = 'Confirm booking';
    _live?.sendAppText(
      'Ask them to say yes to book ${hospital!.name}, today, ${guessed.departmentName}, complaint "$complaint".',
    );
    notifyListeners();
  }

  Future<void> _resolveConfirm(String text) async {
    final t = text.toLowerCase();
    final yes = RegExp(r'\b(yes|yeah|ok|okay|haan|han|ji|theek|book|confirm|sahi)\b')
        .hasMatch(t);
    final no = RegExp(r'\b(no|nah|nahi|cancel|mat|stop)\b').hasMatch(t);
    if (no) {
      step = VoiceBookStep.failed;
      status = 'Cancelled.';
      _live?.sendAppText('They cancelled. Say goodbye briefly.');
      notifyListeners();
      await stop();
      return;
    }
    if (!yes) {
      _live?.sendAppText('Ask again: say yes to book, or no to cancel.');
      return;
    }
    await _book();
  }

  Future<void> _book() async {
    step = VoiceBookStep.booking;
    status = 'Booking…';
    notifyListeners();
    try {
      final deptName = department!.departmentName.toLowerCase();
      final queueResponse = await _api.addPatientToQueue(
        patientId: patientId,
        hospitalId: hospital!.hospitalID,
        hospitalDepartmentId: department!.hospitalDepartmentID,
        createdBy: 1,
        priority: 'Normal',
        queueType: deptName.contains('emergency') ? 'Emergency' : 'OPD',
        visitPurpose: 'Check-Up',
        patientSource: 'SELF_CHECKIN',
        patientComplaint: complaint,
      );
      final queueId = QueueResponse.readInt(queueResponse['queueId']);
      final tokenNumber = queueResponse['tokenNumber']?.toString() ?? 'N/A';
      if (queueId == null || queueId <= 0) {
        throw Exception('Queue ID not returned');
      }
      Map<String, dynamic> receipt = {};
      try {
        receipt = await _api.printQueueReceipt(queueId: queueId);
      } catch (_) {}

      final patientName = savedUserData?['FullName']?.toString() ??
          savedUserData?['fullName']?.toString() ??
          patient['fullName']?.toString() ??
          patient['name']?.toString() ??
          'Patient';
      final mrn = savedUserData?['MRN']?.toString() ??
          savedUserData?['mrn']?.toString() ??
          patient['mrn']?.toString() ??
          '';

      booked = AppointmentDetails(
        queueResponse: QueueResponse(queueId: queueId, tokenNumber: tokenNumber),
        hospital: hospital!,
        department: Department(
          departmentID: department!.departmentID,
          name: department!.departmentName,
          isActive: true,
          hospitalCount: 0,
        ),
        patientName: patientName,
        patientMRN: mrn,
        appointmentDate: DateTime.now(),
        receiptData: receipt.isNotEmpty ? receipt : null,
      );
      await UserStorage.addKnownHospitalId(hospital!.hospitalID);
      PatientPortalService.notifyVisitsChanged();
      step = VoiceBookStep.done;
      status = 'Booked. Token $tokenNumber';
      _live?.sendAppText(
        'Booking succeeded. Token $tokenNumber at ${hospital!.name}. Tell them briefly. Do not ask more questions.',
      );
      notifyListeners();
      await Future<void>.delayed(const Duration(seconds: 4));
      await stop();
    } catch (e) {
      step = VoiceBookStep.failed;
      error = e.toString().replaceFirst('Exception: ', '');
      status = error!;
      _live?.sendAppText('Booking failed: $error. Apologise briefly.');
      notifyListeners();
    }
  }

  Future<void> stop() async {
    await _micSub?.cancel();
    _micSub = null;
    try {
      if (await _pcm.isRecording()) await _pcm.stop();
    } catch (_) {}
    await _live?.close();
    _live = null;
    await _player.stop();
    if (step != VoiceBookStep.done && step != VoiceBookStep.failed) {
      step = VoiceBookStep.idle;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _player.dispose();
    super.dispose();
  }

  static DateTime? parseSpokenDate(String raw) {
    final t = raw.toLowerCase().trim();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (RegExp(r'\b(today|aaj|aj)\b').hasMatch(t)) return today;
    if (RegExp(r'\b(tomorrow|kal)\b').hasMatch(t)) {
      return today.add(const Duration(days: 1));
    }
    if (RegExp(r'\b(parson|day after)\b').hasMatch(t)) {
      return today.add(const Duration(days: 2));
    }
    final iso = DateTime.tryParse(t);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    final dmy = RegExp(r'(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})').firstMatch(t);
    if (dmy != null) {
      var y = int.parse(dmy.group(3)!);
      if (y < 100) y += 2000;
      return DateTime(y, int.parse(dmy.group(2)!), int.parse(dmy.group(1)!));
    }
    const months = {
      'jan': 1, 'january': 1, 'januari': 1,
      'feb': 2, 'february': 2, 'farwari': 2,
      'mar': 3, 'march': 3,
      'apr': 4, 'april': 4,
      'may': 5, 'mai': 5,
      'jun': 6, 'june': 6,
      'jul': 7, 'july': 7, 'julai': 7,
      'aug': 8, 'august': 8, 'agast': 8,
      'sep': 9, 'sept': 9, 'september': 9, 'sitambar': 9,
      'oct': 10, 'october': 10, 'aktubar': 10,
      'nov': 11, 'november': 11, 'navambar': 11,
      'dec': 12, 'december': 12, 'dasambar': 12,
    };
    final named = RegExp(r'(\d{1,2})\s+([a-z]+)').firstMatch(t);
    if (named != null) {
      final m = months[named.group(2)];
      if (m != null) {
        var year = now.year;
        final day = int.parse(named.group(1)!);
        var dt = DateTime(year, m, day);
        if (dt.isBefore(today)) dt = DateTime(year + 1, m, day);
        return dt;
      }
    }
    return null;
  }

  static HospitalDepartment? guessDepartment(
    List<HospitalDepartment> depts,
    String complaint,
  ) {
    if (depts.isEmpty) return null;
    final c = complaint.toLowerCase();
    final rules = <RegExp, List<String>>{
      RegExp(r'emerg|accident|hadsa|zakhm|bleeding|blood'): ['emergency', 'er', 'casualty'],
      RegExp(r'pregnan|haml|gyne|lady|delivery'): ['gynae', 'gyne', 'obstetric', 'lady'],
      RegExp(r'child|bach|pead|pedia|infant'): ['pead', 'pedia', 'child'],
      RegExp(r'bone|fracture|orth|jore|had'): ['orth'],
      RegExp(r'eye|aankh|ophthal'): ['eye', 'ophthal'],
      RegExp(r'tooth|dant|dental'): ['dental'],
      RegExp(r'chest|dil|heart|bp|blood pressure|saans|cough|bukhar|fever|pet|stomach'):
          ['medicine', 'medical', 'cardio', 'opd'],
    };
    for (final e in rules.entries) {
      if (!e.key.hasMatch(c)) continue;
      for (final hint in e.value) {
        for (final d in depts) {
          final n = '${d.departmentName} ${d.speciality ?? ''}'.toLowerCase();
          if (n.contains(hint)) return d;
        }
      }
    }
    for (final d in depts) {
      final n = d.departmentName.toLowerCase();
      if (n.contains('medicine') || n.contains('opd') || n.contains('general')) {
        return d;
      }
    }
    return depts.length == 1 ? depts.first : null;
  }
}
