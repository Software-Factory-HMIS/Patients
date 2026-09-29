import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:record/record.dart' hide IosAudioCategory;

import '../models/appointment_models.dart';
import '../utils/emr_api_client.dart';
import '../utils/user_storage.dart';
import 'hospital_catalog_cache.dart';
import 'llm/gemini_live_booking_session.dart';
import 'llm/patient_ai_settings.dart';
import 'llm/urdu_script_converter.dart';
import 'nearest_hospital_service.dart';
import 'patient_location_service.dart';
import 'patient_portal_service.dart';

enum VoiceBookStep {
  idle,
  connecting,
  existingToken,
  askHospital,
  confirmHospital,
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
  UrduScriptConverter? _script;
  int _heardGen = 0;
  int _saidGen = 0;

  VoiceBookStep step = VoiceBookStep.idle;
  String status = '';
  String lastHeard = '';
  String lastSaid = '';
  Hospital? hospital;
  DateTime? visitDate;
  String complaint = '';
  HospitalDepartment? department;
  List<HospitalDepartment> _depts = [];
  List<Hospital> nearby = [];
  AppointmentDetails? booked;
  Map<String, dynamic>? existingVisit;
  String? error;
  bool missingVoiceKey = false;

  String? get bookedToken => booked?.queueResponse.tokenNumber;
  String? get existingToken => existingVisit?['tokenNumber']?.toString();

  bool _disposed = false;
  bool _pcmReady = false;

  // Playback is queued in Dart and only a short slice is handed to the native
  // player, so a tap can cut the reply off without tearing the engine down.
  static const _playerBufferFrames = 9600; // 400 ms at 24 kHz
  final _queue = ListQueue<PcmArrayInt16>();
  int _bufferedFrames = 0;
  bool _speaking = false;
  Timer? _quietTimer;
  DateTime _dropAudioUntil = DateTime.fromMillisecondsSinceEpoch(0);

  // Half duplex: the phone speaker bleeds into the mic, and the recorder's echo
  // canceller cannot see the player's output. Anything we sent while speaking
  // would read as a barge-in and make the model restart.
  DateTime _micOpenAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _turnEnded = false;

  bool get isLive => _live?.isOpen == true;
  bool get isSpeaking => _speaking;
  bool get isListening =>
      isLive && !_speaking && !DateTime.now().isBefore(_micOpenAt);

  Future<void> start() async {
    error = null;
    booked = null;
    hospital = null;
    visitDate = null;
    complaint = '';
    department = null;
    _depts = [];
    nearby = [];
    existingVisit = null;
    missingVoiceKey = false;
    step = VoiceBookStep.connecting;
    status = 'جڑ رہا ہے…';
    notifyListeners();

    final settings = await PatientAiSettings.load();
    var apiKey = settings.apiKey.trim();
    String? accessToken;
    var model = settings.model;

    if (apiKey.isEmpty) {
      status = 'جڑ رہا ہے…';
      notifyListeners();
      final tok = await _api.fetchPatientLiveToken();
      if (tok == null) {
        step = VoiceBookStep.failed;
        missingVoiceKey = true;
        error =
            'ترتیبات میں Gemini کلید لکھیں، یا منتظم سے ہسپتال کی Gemini کلید محفوظ کروانے کو کہیں۔';
        status = error!;
        notifyListeners();
        return;
      }
      accessToken = tok.token;
      if (tok.model.isNotEmpty) model = tok.model;
    }

    if (!await _pcm.hasPermission()) {
      step = VoiceBookStep.failed;
      error = 'مائیکروفون کی اجازت درکار ہے۔';
      status = error!;
      notifyListeners();
      return;
    }

    // Everything the model needs is gathered before the socket opens, so the
    // session never has to be interrupted to be told something.
    final loaded = await _loadNearbyBookable();
    if (_disposed) return;
    if (!loaded) return;
    await _loadExistingVisit();
    if (_disposed) return;

    _script = UrduScriptConverter(
      api: _api,
      apiKey: apiKey.isEmpty ? null : apiKey,
    );
    final live = GeminiLiveBookingSession(
      apiKey: apiKey.isEmpty ? null : apiKey,
      accessToken: accessToken,
      model: model,
      instruction: GeminiLiveBookingSession.buildInstruction(
        hospitalList: _hospitalToolList(),
        existingToken: existingToken,
      ),
    );
    live.onUserTranscript = _onUser;
    live.onUserPartial = _onUserPartial;
    live.onAssistantTranscript = (t) {
      if (_disposed) return;
      lastSaid = t;
      notifyListeners();
      unawaited(_showSaidScript(t));
    };
    live.onAssistantAudio = _enqueueReply;
    live.onInterrupted = _stopSpeaking;
    live.onTurnComplete = () {
      _turnEnded = false;
    };
    live.onToolCalls = (calls) {
      unawaited(_onToolCalls(calls));
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
      missingVoiceKey = true;
      error = 'آواز والا معاون شروع نہیں ہوا۔ ترتیبات میں کلید اور ماڈل چیک کریں۔';
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
    if (existingVisit != null) {
      step = VoiceBookStep.existingToken;
      status = 'ٹوکن $existingToken';
    } else {
      step = VoiceBookStep.askHospital;
      status = 'ہسپتال چنیں';
    }
    _kickOff(live);
    notifyListeners();
  }

  /// One nudge so the model speaks first. Sent before it has said anything, so
  /// there is no reply to interrupt.
  void _kickOff(GeminiLiveBookingSession live) {
    if (live.usesEphemeralToken) {
      // The server owns the system instruction on the token path, so the
      // hospital list has to ride along with the opening nudge.
      live.sendUserText(
        '[APP] Start now. Hospitals you may book:\n${_hospitalToolList()}\n'
        '${existingToken == null ? '' : 'They already hold token $existingToken today. '}'
        'Greet in Urdu with one short sentence.',
      );
    } else {
      live.sendUserText('[APP] Start now.');
    }
    _micOpenAt = DateTime.now().add(const Duration(seconds: 2));
  }

  String _hospitalToolList() => nearby
      .map((h) => '${h.hospitalID}: ${h.name}')
      .join('\n');

  Future<void> _loadExistingVisit() async {
    try {
      final cnic = (savedUserData?['CNIC'] ??
              savedUserData?['cnic'] ??
              patient['CNIC'] ??
              patient['cnic'] ??
              '')
          .toString();
      final visit = await PatientPortalService().loadUpcomingVisit(
        patientId: patientId,
        patientCnic: cnic,
        patient: patient,
      );
      if (visit == null) return;
      final token = visit['tokenNumber']?.toString().trim();
      final when = DateTime.tryParse(
        visit['appointmentDate']?.toString() ??
            visit['queueDate']?.toString() ??
            '',
      );
      final today = DateTime.now();
      final isToday = when != null &&
          when.year == today.year &&
          when.month == today.month &&
          when.day == today.day;
      if (token == null || token.isEmpty || !isToday) return;
      existingVisit = visit;
    } catch (_) {}
  }

  Future<bool> _loadNearbyBookable() async {
    status = 'ہسپتال…';
    notifyListeners();
    final all = await HospitalCatalogCache.instance.thqDhqHospitals();
    final lastId = await UserStorage.getLastBookedHospitalId();
    Hospital? last;
    if (lastId != null) {
      for (final h in all) {
        if (h.hospitalID == lastId) {
          last = h;
          break;
        }
      }
    }

    final position =
        await PatientLocationService.instance.requestCurrentPosition();
    final picked = <Hospital>[];
    if (position != null) {
      final results = await NearestHospitalService(api: _api).findNearestHospitals(
        latitude: position.latitude,
        longitude: position.longitude,
        limit: 5,
      );
      picked.addAll(results.map((e) => e.hospital));
    }
    if (last != null && !picked.any((h) => h.hospitalID == last!.hospitalID)) {
      picked.insert(0, last);
    }
    if (picked.isEmpty && last != null) picked.add(last);
    if (picked.isEmpty) {
      final known = await UserStorage.getKnownHospitalIds();
      for (final id in known) {
        for (final h in all) {
          if (h.hospitalID == id &&
              !picked.any((x) => x.hospitalID == id)) {
            picked.add(h);
          }
        }
        if (picked.length >= 5) break;
      }
    }
    nearby = picked;
    if (nearby.isEmpty) {
      step = VoiceBookStep.failed;
      error = position == null
          ? 'لوکیشن آن کریں، یا لکھ کر بک کریں۔ پہلے والا ہسپتال نہیں ملا۔'
          : 'قریب کوئی تحصیل یا ضلع ہسپتال نہیں ملا۔';
      status = error!;
      notifyListeners();
      return false;
    }
    await HospitalCatalogCache.instance.prefetchDepartments(
      nearby.map((h) => h.hospitalID),
    );
    return true;
  }

  Future<void> _configureAudio() async {
    if (_pcmReady) return;
    try {
      await FlutterPcmSound.setup(
        sampleRate: 24000,
        channelCount: 1,
        iosAudioCategory: IosAudioCategory.playAndRecord,
      );
      await FlutterPcmSound.setFeedThreshold(2400);
      FlutterPcmSound.setFeedCallback(_onFeed);
      FlutterPcmSound.start();
      _pcmReady = true;
    } catch (_) {
      _pcmReady = false;
    }
  }

  void _onFeed(int remaining) {
    if (_disposed) return;
    _bufferedFrames = remaining;
    _pumpAudio();
    if (remaining <= 0 && _queue.isEmpty) _markQuiet();
  }

  void _enqueueReply(Uint8List pcm) {
    if (pcm.isEmpty || _disposed || !_pcmReady) return;
    // Audio still in flight from a turn the server already cancelled.
    if (DateTime.now().isBefore(_dropAudioUntil)) return;
    final n = pcm.lengthInBytes ~/ 2;
    if (n <= 0) return;
    final bd = ByteData.sublistView(pcm);
    _queue.add(
      PcmArrayInt16.fromList(
        List<int>.generate(n, (i) => bd.getInt16(i * 2, Endian.little)),
      ),
    );
    _markSpeaking();
    _pumpAudio();
  }

  void _pumpAudio() {
    while (_queue.isNotEmpty && _bufferedFrames < _playerBufferFrames) {
      final chunk = _queue.removeFirst();
      _bufferedFrames += chunk.count;
      unawaited(FlutterPcmSound.feed(chunk).catchError((_) {}));
    }
  }

  void _markSpeaking() {
    _quietTimer?.cancel();
    _quietTimer = null;
    if (_speaking) return;
    _speaking = true;
    notifyListeners();
  }

  /// Brief gaps between chunks are normal, so only call it quiet after the
  /// player has actually stayed empty.
  void _markQuiet() {
    if (!_speaking || _quietTimer != null) return;
    _quietTimer = Timer(const Duration(milliseconds: 300), () {
      _quietTimer = null;
      if (_disposed || !_speaking || _queue.isNotEmpty) return;
      _speaking = false;
      // Let the room stop ringing before the mic counts again.
      _micOpenAt = DateTime.now().add(const Duration(milliseconds: 500));
      notifyListeners();
    });
  }

  /// Drop whatever is queued. The native player keeps at most
  /// [_playerBufferFrames], so the tail is short and the engine stays up.
  void _stopSpeaking({Duration drop = const Duration(milliseconds: 250)}) {
    _queue.clear();
    _dropAudioUntil = DateTime.now().add(drop);
    _quietTimer?.cancel();
    _quietTimer = null;
    if (_speaking) {
      _speaking = false;
      _micOpenAt = DateTime.now().add(const Duration(milliseconds: 500));
      if (!_disposed) notifyListeners();
    }
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
      if (_disposed || _speaking) return;
      if (DateTime.now().isBefore(_micOpenAt)) return;
      _live?.sendPcm16k(chunk);
    });
  }

  Future<void> _showHeardScript(String raw) async {
    final gen = ++_heardGen;
    lastHeard = raw;
    notifyListeners();
    final converted = await _script?.toScript(raw);
    if (_disposed || gen != _heardGen || converted == null) return;
    lastHeard = converted;
    notifyListeners();
  }

  Future<void> _showSaidScript(String raw) async {
    if (UrduScriptConverter.isUrduScript(raw)) return;
    final gen = ++_saidGen;
    final converted = await _script?.toScript(raw);
    if (_disposed || gen != _saidGen || converted == null) return;
    lastSaid = converted;
    notifyListeners();
  }

  Future<void> _onToolCalls(List<GeminiLiveToolCall> calls) async {
    if (_disposed || calls.isEmpty) return;
    final results = <String>[];
    for (final call in calls) {
      results.add(await _runTool(call));
    }
    _live?.sendToolResults(calls, results);
    if (step == VoiceBookStep.done) _finishAfterSpeech();
  }

  /// The model drives the conversation; this only validates and answers.
  /// Function calling on the Live models is sequential, so the model waits for
  /// the result and speaks once — nothing here may push a turn of its own.
  Future<String> _runTool(GeminiLiveToolCall call) async {
    switch (call.name) {
      case 'pick_hospital':
        final id = int.tryParse('${call.args['hospital_id'] ?? ''}');
        Hospital? match;
        if (id != null) {
          for (final h in nearby) {
            if (h.hospitalID == id) {
              match = h;
              break;
            }
          }
        }
        if (match == null) {
          return 'Not a listed hospital. Ask again and call pick_hospital with '
              'one of these HospitalIDs:\n${_hospitalToolList()}';
        }
        hospital = match;
        department = null;
        complaint = '';
        _depts = [];
        step = VoiceBookStep.confirmHospital;
        status = '${match.name}؟';
        notifyListeners();
        return 'Hospital set to ${match.name}. Ask them in Urdu to confirm it, '
            'جی یا نہیں. If yes, ask exactly: آپ کو کیا شکایت ہے؟ '
            'Never say مسئلہ or تکلیف. Then call set_complaint. '
            'If no, call pick_hospital with another id.';
      case 'set_complaint':
        final text = (call.args['text'] ?? '').toString().trim();
        if (hospital == null) {
          return 'No hospital yet. Call pick_hospital first.';
        }
        if (text.isEmpty) {
          return 'Nothing heard. Ask exactly: آپ کو کیا شکایت ہے؟';
        }
        if (_heardTomorrow(text)) {
          status = 'کل آئیں';
          notifyListeners();
          return 'They want a later day. Only today exists. Tell them کل آئیں '
              'اور اسی وقت بک کریں. Do not book.';
        }
        await _applyComplaint(text);
        if (department != null) {
          return 'Saved. Department is ${department!.departmentName}. Read back '
              '${hospital!.name}، آج، ${department!.departmentName} and ask جی '
              'یا نہیں. If yes, call book_token.';
        }
        return 'Saved, but the department is unclear. Ask them to pick one of: '
            '${_departmentChoices()}. Then call pick_department.';
      case 'pick_department':
        final picked = matchDepartmentByName(
          _depts,
          (call.args['name'] ?? '').toString(),
        );
        if (picked == null) {
          return 'Not on the list. Ask again from: ${_departmentChoices()}';
        }
        department = picked;
        step = VoiceBookStep.confirm;
        status = 'جی؟';
        notifyListeners();
        return 'Department is ${picked.departmentName}. Read back '
            '${hospital!.name}، آج، ${picked.departmentName} and ask جی یا نہیں. '
            'If yes, call book_token.';
      case 'book_token':
        if (hospital == null) return 'No hospital yet. Call pick_hospital.';
        if (department == null) {
          return 'No department yet. Ask exactly: آپ کو کیا شکایت ہے؟ '
              'Then call set_complaint.';
        }
        if (bookedToken != null) {
          return 'Already booked, token $bookedToken. Do not book again.';
        }
        await _book();
        if (bookedToken == null) {
          return 'Booking failed. Apologise in one short line and stop.';
        }
        return 'Booked. Tell them token $bookedToken at ${hospital!.name} in '
            'Urdu, wish them well, then stop.';
      case 'keep_existing_token':
        _markKeepExisting();
        return 'Fine. Say one short goodbye in Urdu and stop.';
      case 'start_new_booking':
        _resetForNewBooking();
        return 'Ask which hospital they want from the list, then call '
            'pick_hospital.';
      default:
        return 'Unknown tool.';
    }
  }

  String _departmentChoices() =>
      _depts.take(6).map((d) => d.departmentName).join(', ');

  Future<void> _applyComplaint(String text) async {
    final now = DateTime.now();
    complaint = text;
    visitDate = DateTime(now.year, now.month, now.day);
    status = 'شعبہ…';
    notifyListeners();
    _depts = await HospitalCatalogCache.instance.departments(
      hospital!.hospitalID,
    );
    final guessed = guessDepartment(_depts, text);
    if (guessed != null) {
      department = guessed;
      step = VoiceBookStep.confirm;
      status = 'جی؟';
    } else {
      step = VoiceBookStep.askDepartment;
      status = 'شعبہ؟';
    }
    notifyListeners();
  }

  void _resetForNewBooking() {
    existingVisit = null;
    hospital = null;
    department = null;
    complaint = '';
    _depts = [];
    step = VoiceBookStep.askHospital;
    status = 'ہسپتال چنیں';
    notifyListeners();
  }

  /// Taps cut the reply off straight away, then tell the model what changed.
  void _tapped(String note) {
    _stopSpeaking(drop: Duration.zero);
    _turnEnded = false;
    _live?.sendUserText('[APP] $note');
  }

  Future<void> tapHospital(Hospital match) async {
    if (_disposed || _live == null) return;
    hospital = match;
    department = null;
    complaint = '';
    _depts = [];
    step = VoiceBookStep.askComplaint;
    status = 'شکایت؟';
    notifyListeners();
    _tapped(
      'They tapped ${match.name} on screen, so the hospital is settled. '
      'Do not confirm it again. Ask exactly: آپ کو کیا شکایت ہے؟ '
      'Never say مسئلہ or تکلیف. Then call set_complaint.',
    );
  }

  void _markKeepExisting() {
    final token = existingToken ?? '';
    step = VoiceBookStep.done;
    status = token.isEmpty ? 'ٹھیک' : 'ٹوکن $token';
    notifyListeners();
  }

  void keepExisting() {
    if (_disposed || _live == null) return;
    _markKeepExisting();
    _tapped(
      'They tapped keep the token they already have. Say one short goodbye in '
      'Urdu and stop.',
    );
    _finishAfterSpeech();
  }

  void bookAnother() {
    if (_disposed || _live == null) return;
    _resetForNewBooking();
    _tapped(
      'They want a different hospital instead of the token they hold. '
      'Ask which hospital from the list, then call pick_hospital.',
    );
  }

  void fixHospital() {
    if (_disposed || _live == null) return;
    _resetForNewBooking();
    _tapped(
      'The hospital on screen was wrong. Ask which hospital from the list, '
      'then call pick_hospital.',
    );
  }

  void fixComplaint() {
    if (_disposed || _live == null) return;
    department = null;
    complaint = '';
    step = VoiceBookStep.askComplaint;
    status = 'شکایت؟';
    notifyListeners();
    _tapped(
      'The شکایت on screen was wrong. Ask exactly: آپ کو کیا شکایت ہے؟ '
      'Never say مسئلہ or تکلیف. Then call set_complaint.',
    );
  }

  void fixDepartment() {
    if (_disposed || _live == null) return;
    department = null;
    step = VoiceBookStep.askDepartment;
    status = 'شعبہ؟';
    notifyListeners();
    _tapped(
      'The department on screen was wrong. Ask them to pick one of: '
      '${_departmentChoices()}. Then call pick_department.',
    );
  }

  /// Transcripts are for the screen only. The model already heard the patient,
  /// so anything sent from here would cancel the reply it is building.
  Future<void> _onUser(String raw) async {
    if (_disposed) return;
    final text = raw.trim();
    if (text.isEmpty) return;
    unawaited(_showHeardScript(text));
  }

  /// A clear short answer does not need the full silence window. Marking the
  /// audio as ended lets the server reply at once, so yes/no exchanges stay
  /// quick while longer sentences still get their pauses.
  void _onUserPartial(String text) {
    if (_disposed || _turnEnded || _speaking) return;
    if (!_isQuickAnswer(text)) return;
    _turnEnded = true;
    _live?.sendAudioStreamEnd();
    _micOpenAt = DateTime.now().add(const Duration(seconds: 2));
  }

  bool _isQuickAnswer(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    final words = t.split(RegExp(r'\s+'));
    if (words.length <= 3 && (_heardYes(t) || _heardNo(t))) return true;
    if (words.length > 6) return false;
    final lower = t.toLowerCase();
    for (final h in nearby) {
      if (lower.contains(h.name.toLowerCase())) return true;
    }
    return false;
  }

  static bool _heardTomorrow(String text) {
    final t = text.toLowerCase();
    return RegExp(r'\b(tomorrow|kal|parson)\b').hasMatch(t) ||
        text.contains('کل') ||
        text.contains('پرسوں');
  }

  static bool _heardYes(String text) {
    final t = text.toLowerCase();
    return RegExp(r'\b(yes|yeah|ok|okay|haan|han|ji|theek|book|confirm|sahi)\b')
            .hasMatch(t) ||
        text.contains('جی') ||
        text.contains('ہاں') ||
        text.contains('هان') ||
        text.contains('ٹھیک') ||
        text.contains('صحیح');
  }

  static bool _heardNo(String text) {
    final t = text.toLowerCase();
    return RegExp(r'\b(no|nah|nahi|cancel|mat|stop)\b').hasMatch(t) ||
        text.contains('نہیں') ||
        text.contains('نهیں') ||
        text.contains('منسوخ');
  }

  Future<void> _book() async {
    step = VoiceBookStep.booking;
    status = 'بک…';
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
      // The session stays open: the model still has to read the token out.
      step = VoiceBookStep.done;
      status = 'ٹوکن $tokenNumber';
      notifyListeners();
    } catch (e) {
      step = VoiceBookStep.failed;
      error = e.toString().replaceFirst('Exception: ', '');
      status = error!;
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
    _quietTimer?.cancel();
    _quietTimer = null;
    _queue.clear();
    _bufferedFrames = 0;
    _speaking = false;
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

  /// Close only once the goodbye has actually been heard, not when the server
  /// says the turn is done — the audio is still queued at that point.
  void _finishAfterSpeech() {
    unawaited(() async {
      await _waitForSpeech();
      if (_disposed) return;
      await stop(resetStep: false);
    }());
  }

  Future<void> _waitForSpeech() async {
    final startBy = DateTime.now().add(const Duration(seconds: 4));
    while (!_disposed && !_speaking && DateTime.now().isBefore(startBy)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final endBy = DateTime.now().add(const Duration(seconds: 25));
    while (!_disposed && _speaking && DateTime.now().isBefore(endBy)) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
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
    if (RegExp(r'\b(today|aaj|aj)\b').hasMatch(t) || raw.contains('آج')) {
      return today;
    }
    if (RegExp(r'\b(tomorrow|kal)\b').hasMatch(t) || raw.contains('کل')) {
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

  /// Spoken department name from the patient or the model, not a complaint.
  static HospitalDepartment? matchDepartmentByName(
    List<HospitalDepartment> depts,
    String spoken,
  ) {
    final q = spoken.trim().toLowerCase();
    if (q.isEmpty || depts.isEmpty) return null;
    for (final d in depts) {
      if (d.departmentName.toLowerCase() == q) return d;
    }
    final hits = depts.where((d) {
      final n = '${d.departmentName} ${d.speciality ?? ''}'.toLowerCase();
      if (q.length <= 3) {
        return RegExp('\\b${RegExp.escape(q)}\\b').hasMatch(n);
      }
      return n.contains(q) || q.contains(d.departmentName.toLowerCase());
    }).toList();
    return hits.length == 1 ? hits.first : guessDepartment(depts, spoken);
  }

  /// Highest-priority clinic for the whole شکایت, not the first word.
  /// Throat / گلہ is ENT, or Medicine if that hospital has no ENT.
  /// Dental is دانت / tooth only.
  static HospitalDepartment? guessDepartment(
    List<HospitalDepartment> depts,
    String complaint,
  ) {
    if (depts.isEmpty) return null;
    final c = complaint.toLowerCase();
    final hits = <_DeptKind>{};
    for (final rule in _complaintRules) {
      if (rule.pattern.hasMatch(c)) hits.add(rule.kind);
    }
    if (hits.isEmpty) {
      return _findDept(depts, _DeptKind.medicine) ??
          (depts.length == 1 ? depts.first : null);
    }
    var best = _DeptKind.medicine;
    var bestRank = -1;
    for (final kind in hits) {
      final rank = kind.rank;
      if (rank > bestRank) {
        best = kind;
        bestRank = rank;
      }
    }
    final found = _findDept(depts, best);
    if (found != null) return found;
    if (best == _DeptKind.ent) return _findDept(depts, _DeptKind.medicine);
    return _findDept(depts, _DeptKind.medicine) ??
        (depts.length == 1 ? depts.first : null);
  }

  static HospitalDepartment? _findDept(
    List<HospitalDepartment> depts,
    _DeptKind kind,
  ) {
    for (final hint in kind.hints) {
      for (final d in depts) {
        final n = '${d.departmentName} ${d.speciality ?? ''}'.toLowerCase();
        if (_nameHasHint(n, hint)) return d;
      }
    }
    return null;
  }

  /// Short hints like "ent" must be a whole word. Otherwise "dental"
  /// matches "ent" and throat is sent to Dental.
  static bool _nameHasHint(String name, String hint) {
    if (hint.length <= 3) {
      return RegExp('\\b${RegExp.escape(hint)}\\b').hasMatch(name);
    }
    return name.contains(hint);
  }
}

enum _DeptKind { emergency, gynae, peads, ortho, eye, dental, ent, medicine }

extension on _DeptKind {
  int get rank => switch (this) {
        _DeptKind.emergency => 8,
        _DeptKind.gynae => 7,
        _DeptKind.peads => 6,
        _DeptKind.ortho => 5,
        _DeptKind.eye => 4,
        _DeptKind.dental => 3,
        _DeptKind.ent => 2,
        _DeptKind.medicine => 1,
      };

  List<String> get hints => switch (this) {
        _DeptKind.emergency => const ['emergency', 'er', 'casualty'],
        _DeptKind.gynae => const ['gynae', 'gyne', 'obstetric', 'lady'],
        _DeptKind.peads => const ['pead', 'pedia', 'child'],
        _DeptKind.ortho => const ['orth'],
        _DeptKind.eye => const ['eye', 'ophthal'],
        _DeptKind.dental => const ['dental'],
        _DeptKind.ent => const ['otorhin', 'otolar', 'ent', 'ear nose'],
        _DeptKind.medicine => const [
            'medicine',
            'medical',
            'cardio',
            'general',
            'opd',
          ],
      };
}

class _ComplaintRule {
  const _ComplaintRule(this.pattern, this.kind);
  final RegExp pattern;
  final _DeptKind kind;
}

final _complaintRules = <_ComplaintRule>[
  _ComplaintRule(
    RegExp(r'emerg|accident|hadsa|zakhm|bleeding'),
    _DeptKind.emergency,
  ),
  _ComplaintRule(
    RegExp(r'pregnan|haml|gyne|lady|delivery'),
    _DeptKind.gynae,
  ),
  _ComplaintRule(
    RegExp(r'child|bachch|pead|pedia|infant'),
    _DeptKind.peads,
  ),
  _ComplaintRule(
    RegExp(r'bone|fracture|orth|\bjore\b|\bhaddi\b'),
    _DeptKind.ortho,
  ),
  _ComplaintRule(
    RegExp(r'eye|aankh|ophthal|آنکھ'),
    _DeptKind.eye,
  ),
  _ComplaintRule(
    RegExp(
      r'\btooth\b|\bteeth\b|\bdant\b|\bdaant\b|\bmolar\b|دانت|مسوڑھ',
    ),
    _DeptKind.dental,
  ),
  _ComplaintRule(
    RegExp(
      r'throat|\bgale\b|\bgala\b|\bgulay\b|\bhalq\b|\bhalaq\b|گلہ|گلا|گلے|حلق',
    ),
    _DeptKind.ent,
  ),
  _ComplaintRule(
    RegExp(
      r'chest|dil|heart|bp|blood pressure|saans|cough|khansi|'
      r'bukhar|fever|pet|stomach|کھانسی|بخار|پیٹ',
    ),
    _DeptKind.medicine,
  ),
];
