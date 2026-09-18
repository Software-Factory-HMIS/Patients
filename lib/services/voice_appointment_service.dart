import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
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
  confirmHospital,
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

  GeminiLiveBookingSession? _live;
  StreamSubscription<Uint8List>? _micSub;

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

  bool _busy = false;
  bool _playing = false;
  bool _disposed = false;
  bool _pcmReady = false;

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
    var apiKey = settings.apiKey.trim();
    String? accessToken;
    var model = settings.model;

    if (apiKey.isEmpty) {
      status = 'Connecting via HMIS…';
      notifyListeners();
      final tok = await _api.fetchPatientLiveToken();
      if (tok == null) {
        step = VoiceBookStep.failed;
        error =
            'Add a Gemini API key in Settings → Voice booking, or ask admin to save a Gemini hospital key.';
        status = error!;
        notifyListeners();
        return;
      }
      accessToken = tok.token;
      if (tok.model.isNotEmpty) model = tok.model;
    }

    if (!await _pcm.hasPermission()) {
      step = VoiceBookStep.failed;
      error = 'Microphone permission is required.';
      status = error!;
      notifyListeners();
      return;
    }

    final live = GeminiLiveBookingSession(
      apiKey: apiKey.isEmpty ? null : apiKey,
      accessToken: accessToken,
      model: model,
    );
    live.onUserTranscript = _onUser;
    live.onAssistantTranscript = (t) {
      if (_disposed) return;
      lastSaid = t;
      notifyListeners();
    };
    live.onAssistantAudio = (pcm) {
      unawaited(_streamReply(pcm));
    };
    live.onError = (e) {
      if (_disposed) return;
      error = e;
      status = e;
      notifyListeners();
    };
    final ok = await live.connect();
    if (_disposed) {
      await live.close();
      return;
    }
    if (!ok) {
      step = VoiceBookStep.failed;
      error = 'Could not start Gemini Live. Check the key and model in Settings.';
      status = error!;
      notifyListeners();
      return;
    }
    _live = live;
    await _configureAudio();
    await _startMic();
    if (_disposed) {
      await stop(resetStep: false);
      return;
    }
    step = VoiceBookStep.askHospital;
    status = 'Which hospital?';
    live.sendAppText(
      'Greet the patient briefly. Ask which hospital they want to visit. One short sentence.',
    );
    notifyListeners();
  }

  Future<void> _configureAudio() async {
    try {
      await FlutterPcmSound.setup(
        sampleRate: 24000,
        channelCount: 1,
        iosAudioCategory: IosAudioCategory.playAndRecord,
      );
      await FlutterPcmSound.setFeedThreshold(2400);
      FlutterPcmSound.setFeedCallback((remaining) {
        if (remaining <= 0) _playing = false;
      });
      FlutterPcmSound.start();
      _pcmReady = true;
    } catch (_) {
      _pcmReady = false;
    }
  }

  Future<void> _streamReply(Uint8List pcm) async {
    if (pcm.isEmpty || _disposed) return;
    _playing = true;
    if (!_pcmReady) await _configureAudio();
    if (!_pcmReady || _disposed) {
      _playing = false;
      return;
    }
    try {
      final n = pcm.lengthInBytes ~/ 2;
      if (n <= 0) return;
      final bd = ByteData.sublistView(pcm);
      final samples = List<int>.generate(
        n,
        (i) => bd.getInt16(i * 2, Endian.little),
      );
      await FlutterPcmSound.feed(PcmArrayInt16.fromList(samples));
    } catch (_) {}
  }

  Future<void> _startMic() async {
    final stream = await _pcm.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        numChannels: 1,
        sampleRate: 16000,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
      ),
    );
    _micSub = stream.listen((chunk) {
      if (_playing || _disposed) return;
      _live?.sendPcm16k(chunk);
    });
  }

  Future<void> _onUser(String raw) async {
    if (_disposed || _busy || _playing) return;
    lastHeard = raw;
    notifyListeners();
    final text = raw.trim();
    if (text.isEmpty) return;
    if (step == VoiceBookStep.booking ||
        step == VoiceBookStep.done ||
        step == VoiceBookStep.failed ||
        step == VoiceBookStep.connecting ||
        step == VoiceBookStep.idle) {
      return;
    }

    _busy = true;
    try {
      switch (step) {
        case VoiceBookStep.askHospital:
          await _resolveHospital(text);
        case VoiceBookStep.confirmHospital:
          await _resolveHospitalConfirm(text);
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
    } finally {
      _busy = false;
    }
  }

  Future<void> _resolveHospital(String text) async {
    final cleaned = text
        .replaceAll(
          RegExp(
            r'\b(i want|please|appointment|visit|hospital|ke liye|ka|ki|mein)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final q = cleaned.isEmpty ? text : cleaned;
    if (q.trim().length < 3) {
      _live?.sendAppText(
        'Hospital name was too short. Ask them to say the full hospital name.',
      );
      status = 'Say the hospital name again.';
      notifyListeners();
      return;
    }
    try {
      final rows = await _api.searchHospitals(q, limit: 20);
      final hospitals = rows
          .map((e) => Hospital.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((h) => h.isActive && h.hospitalID > 0 && h.name.isNotEmpty)
          .toList();
      final needle = q.toLowerCase();
      Hospital? match;
      for (final h in hospitals) {
        if (h.name.toLowerCase() == needle) {
          match = h;
          break;
        }
      }
      if (match == null) {
        final partial = hospitals
            .where(
              (h) =>
                  h.name.toLowerCase().contains(needle) ||
                  needle.contains(h.name.toLowerCase()),
            )
            .toList();
        if (partial.isNotEmpty) match = partial.first;
      }
      if (match == null) {
        _live?.sendAppText(
          'No hospital matched "$text". Ask them to say the hospital name again, slowly.',
        );
        status = 'Hospital not found. Say the name again.';
        notifyListeners();
        return;
      }
      await _offerHospital(match);
    } catch (e) {
      _live?.sendAppText('Hospital search failed. Ask them to repeat the hospital name.');
    }
  }

  Future<void> _offerHospital(Hospital match) async {
    hospital = match;
    step = VoiceBookStep.confirmHospital;
    status = 'Confirm: ${match.name}?';
    _live?.sendAppText(
      'Ask: I heard ${match.name}. Is that right? They should say yes or no.',
    );
    notifyListeners();
  }

  Future<void> _resolveHospitalConfirm(String text) async {
    if (_heardNo(text)) {
      hospital = null;
      step = VoiceBookStep.askHospital;
      status = 'Which hospital?';
      _live?.sendAppText('They said no. Ask which hospital they want.');
      notifyListeners();
      return;
    }
    if (!_heardYes(text)) {
      _live?.sendAppText(
        'Ask again: I heard ${hospital?.name ?? "that hospital"}. Yes or no?',
      );
      return;
    }
    step = VoiceBookStep.askDate;
    status = 'Hospital: ${hospital!.name}. What date?';
    _live?.sendAppText(
      'Hospital confirmed: ${hospital!.name}. Ask what date they want. Remind them we can only book today\'s token.',
    );
    notifyListeners();
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
    if (_heardNo(text)) {
      step = VoiceBookStep.failed;
      status = 'Cancelled.';
      _live?.sendAppText('They cancelled. Say goodbye briefly.');
      notifyListeners();
      await stop();
      return;
    }
    if (!_heardYes(text)) {
      _live?.sendAppText('Ask again: say yes to book, or no to cancel.');
      return;
    }
    await _book();
  }

  static bool _heardYes(String text) =>
      RegExp(r'\b(yes|yeah|ok|okay|haan|han|ji|theek|book|confirm|sahi)\b')
          .hasMatch(text.toLowerCase());

  static bool _heardNo(String text) =>
      RegExp(r'\b(no|nah|nahi|cancel|mat|stop)\b').hasMatch(text.toLowerCase());

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
      status = 'Booked. Token $tokenNumber';
      notifyListeners();
      _live?.sendAppText(
        'Booking succeeded. Token $tokenNumber at ${hospital!.name}. Tell them briefly. Do not ask more questions.',
      );
      await _waitForSpeech();
      await stop(resetStep: false);
      if (_disposed) return;
      step = VoiceBookStep.done;
      notifyListeners();
    } catch (e) {
      step = VoiceBookStep.failed;
      error = e.toString().replaceFirst('Exception: ', '');
      status = error!;
      _live?.sendAppText('Booking failed: $error. Apologise briefly.');
      notifyListeners();
    }
  }

  Future<void> stop({bool resetStep = true}) async {
    await _micSub?.cancel();
    _micSub = null;
    try {
      if (await _pcm.isRecording()) await _pcm.stop();
    } catch (_) {}
    await _live?.close();
    _live = null;
    _playing = false;
    try {
      await FlutterPcmSound.release();
    } catch (_) {}
    _pcmReady = false;
    if (resetStep &&
        step != VoiceBookStep.done &&
        step != VoiceBookStep.failed) {
      step = VoiceBookStep.idle;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> _waitForSpeech() async {
    final deadline = DateTime.now().add(const Duration(seconds: 6));
    while (!_disposed && DateTime.now().isBefore(deadline)) {
      if (!_playing) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (!_playing) return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stop(resetStep: false);
    _pcm.dispose();
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
      RegExp(r'emerg|accident|hadsa|zakhm|bleeding'): ['emergency', 'er', 'casualty'],
      RegExp(r'pregnan|haml|gyne|lady|delivery'): ['gynae', 'gyne', 'obstetric', 'lady'],
      RegExp(r'child|bachch|pead|pedia|infant'): ['pead', 'pedia', 'child'],
      RegExp(r'bone|fracture|orth|\bjore\b|\bhaddi\b'): ['orth'],
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
