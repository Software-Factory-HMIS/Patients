import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

class GeminiLiveToolCall {
  GeminiLiveToolCall({
    required this.id,
    required this.name,
    required this.args,
  });

  final String id;
  final String name;
  final Map<String, dynamic> args;
}

/// Gemini Live: mic PCM in, spoken reply + transcripts + booking tools out.
class GeminiLiveBookingSession {
  GeminiLiveBookingSession({
    this.apiKey,
    this.accessToken,
    this.model,
    this.instruction,
  });

  final String? apiKey;
  final String? accessToken;
  final String? model;

  /// Full system instruction, built once before connecting. Everything the
  /// model needs must live here: injecting text mid-session cancels whatever
  /// it is saying and makes it restart the sentence.
  final String? instruction;

  static const _hostBeta =
      'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';
  static const _hostAlpha =
      'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContentConstrained';

  static const systemInstruction = '''
You are the booking desk of a Punjab government hospital. You only issue today's token.

LANGUAGE
Speak Pakistani Urdu in Urdu script. Never Hindi. Never Devanagari. Never Roman Urdu.
Reply in English only if the patient speaks English. Hospital and department names may stay English.

MANNER
One short sentence at a time, warm and calm. Let the patient finish before you answer.
Never say you are a computer, an AI, a clerk or an assistant. Do not introduce yourself.
Never give medical advice. Only book. If they ask anything else, bring them back in one short line.

FIRST LINE
میں ہسپتال وزٹ بک کرنے میں مدد کر سکتا ہوں۔ آپ کہاں چیک اپ کرانا چاہتے ہیں؟
Then stop and listen.

DATE
Only today's token exists. Never ask for a date.
If they want tomorrow or later: کل آئیں اور اسی وقت بک کریں۔ Do not book.

WORDS
When you ask about the visit, say exactly: آپ کو کیا شکایت ہے؟
Never say مسئلہ. Never say تکلیف. Never say "problem". شکایت only.

TOOLS
pick_hospital with a HospitalID from the app list. Never invent a hospital.
set_complaint with the patient's شکایت in a few words. Keep every شکایت they named.
pick_department only when the app asks you to choose one. Never pick Dental for گلہ / throat. Dental is دانت / tooth only.
book_token only after they clearly say جی، ہاں or yes.
keep_existing_token or start_new_booking when they already hold today's token.
After every tool the app sends back a short instruction. Follow it, but never read it out loud.
Never say a token number before book_token has succeeded.
Messages that start with [APP] come from the screen, not the patient. Act on them, never read them.
''';

  /// System instruction plus the data that changes per session. Built before
  /// [connect] so nothing has to be injected while the model is talking.
  static String buildInstruction({
    required String hospitalList,
    String? existingToken,
  }) {
    final buffer = StringBuffer(systemInstruction)
      ..writeln()
      ..writeln('HOSPITALS you may book. Use only these HospitalIDs:')
      ..writeln(hospitalList);
    if (existingToken != null && existingToken.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(
          'The patient already holds token $existingToken for today. '
          'Open by telling them that token, then ask whether they want to keep '
          'it or book another hospital. Then call keep_existing_token or '
          'start_new_booking. Do not use the normal first line.',
        );
    }
    return buffer.toString();
  }

  static const defaultModel = 'gemini-3.8-live';
  static const _fallbackModel = 'gemini-2.5-flash-native-audio-preview-12-2025';

  /// Gemini 3.8 Live defaults to async tool calls, where the model keeps
  /// talking instead of waiting for our answer. The booking flow needs the
  /// answer first, so ask for the blocking mode it still supports.
  static bool _supportsBlockingTools(String modelId) =>
      modelId.startsWith('gemini-3.8-live') &&
      !modelId.contains('extended-thinking');

  /// Extended thinking rejects `MINIMAL`, and the others reject the field
  /// altogether, so only it gets a thinking level.
  static bool _needsThinkingLevel(String modelId) =>
      modelId.contains('extended-thinking');

  static List<Map<String, Object?>> toolsFor(String modelId) {
    final declarations = _functionDeclarations;
    if (!_supportsBlockingTools(modelId)) {
      return [
        {'functionDeclarations': declarations}
      ];
    }
    return [
      {
        'functionDeclarations': [
          for (final fn in declarations) {...fn, 'behavior': 'BLOCKING'},
        ],
      }
    ];
  }

  static final _functionDeclarations = <Map<String, Object?>>[
    {
      'name': 'pick_hospital',
      'description':
          'Select one listed hospital. Only a HospitalID from the app list.',
      'parameters': {
        'type': 'object',
        'properties': {
          'hospital_id': {
            'type': 'integer',
            'description': 'HospitalID from the app list',
          }
        },
        'required': ['hospital_id'],
      },
    },
    {
      'name': 'set_complaint',
          'description':
              'Save the patient\'s شکایت in a few words. Keep every شکایت they named. No medical advice.',
      'parameters': {
        'type': 'object',
        'properties': {
          'text': {
            'type': 'string',
            'description': "Patient's complaint",
          }
        },
        'required': ['text'],
      },
    },
    {
      'name': 'pick_department',
      'description': 'Select a department from the hospital list.',
      'parameters': {
        'type': 'object',
        'properties': {
          'name': {
            'type': 'string',
            'description': 'Department name from the app list',
          }
        },
        'required': ['name'],
      },
    },
    {
      'name': 'book_token',
      'description':
          "Issue today's token only after the patient clearly says yes.",
    },
    {
      'name': 'keep_existing_token',
      'description':
          'Patient will use the token they already have today. Do not book again.',
    },
    {
      'name': 'start_new_booking',
      'description':
          'Patient wants another hospital instead of the existing token.',
    },
  ];

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Completer<void>? _ready;
  bool _open = false;
  String _inUtterance = '';
  String _outUtterance = '';

  void Function(String text)? onUserTranscript;
  void Function(String text)? onUserPartial;
  void Function(String text)? onAssistantTranscript;
  void Function(Uint8List pcm)? onAssistantAudio;
  void Function()? onTurnComplete;
  void Function()? onGenerationComplete;
  void Function()? onInterrupted;
  void Function(List<GeminiLiveToolCall> calls)? onToolCalls;
  void Function(String err)? onError;

  bool get isOpen => _open;
  bool get usesEphemeralToken => (accessToken ?? '').trim().isNotEmpty;

  Future<bool> connect() async {
    final id =
        model?.trim().isNotEmpty == true ? model!.trim() : defaultModel;
    try {
      await _openSocket(id);
      return true;
    } catch (_) {
      await close();
      if (usesEphemeralToken) {
        onError?.call('Could not start Gemini Live.');
        return false;
      }
      if (id == _fallbackModel) {
        onError?.call('Could not start Gemini Live.');
        return false;
      }
      try {
        await _openSocket(_fallbackModel);
        return true;
      } catch (e) {
        onError?.call(e.toString());
        await close();
        return false;
      }
    }
  }

  Future<void> _openSocket(String modelId) async {
    final token = accessToken?.trim();
    final key = apiKey?.trim();
    final Uri uri;
    if (token != null && token.isNotEmpty) {
      uri = Uri.parse(
        '$_hostAlpha?access_token=${Uri.encodeQueryComponent(token)}',
      );
    } else if (key != null && key.isNotEmpty) {
      uri = Uri.parse('$_hostBeta?key=${Uri.encodeQueryComponent(key)}');
    } else {
      throw StateError('No Live credential.');
    }

    final channel = WebSocketChannel.connect(uri);
    await channel.ready.timeout(const Duration(seconds: 12));
    _channel = channel;
    _ready = Completer<void>();
    _sub = channel.stream.listen(
      _onMessage,
      onError: (e) {
        _open = false;
        onError?.call(e.toString());
        if (_ready != null && !_ready!.isCompleted) _ready!.completeError(e);
      },
      onDone: () {
        _open = false;
        if (_ready != null && !_ready!.isCompleted) {
          _ready!.completeError(StateError('Live socket closed.'));
        }
      },
    );

    if (token != null && token.isNotEmpty) {
      try {
        await _ready!.future.timeout(const Duration(seconds: 2));
      } catch (_) {
        if (_ready != null && !_ready!.isCompleted) _ready!.complete();
      }
      _open = true;
      return;
    }

    final generationConfig = <String, Object?>{
      'responseModalities': ['AUDIO'],
      'speechConfig': {
        'voiceConfig': {
          'prebuiltVoiceConfig': {'voiceName': 'Puck'},
        },
      },
    };
    if (_needsThinkingLevel(modelId)) {
      generationConfig['thinkingConfig'] = {'thinkingLevel': 'low'};
    }

    channel.sink.add(jsonEncode({
      'setup': {
        'model': 'models/$modelId',
        'generationConfig': generationConfig,
        'systemInstruction': {
          'parts': [
            {'text': instruction ?? systemInstruction},
          ]
        },
        // Patients pause mid-sentence in Urdu. Wait longer before assuming the
        // turn ended, and be slow to treat a noise as the start of speech.
        'realtimeInputConfig': {
          'automaticActivityDetection': {
            'startOfSpeechSensitivity': 'START_SENSITIVITY_LOW',
            'endOfSpeechSensitivity': 'END_SENSITIVITY_LOW',
            'prefixPaddingMs': 300,
            'silenceDurationMs': 800,
          },
        },
        'inputAudioTranscription': <String, dynamic>{},
        'outputAudioTranscription': <String, dynamic>{},
        'tools': toolsFor(modelId),
      },
    }));
    await _ready!.future.timeout(const Duration(seconds: 12));
    _open = true;
  }

  void sendPcm16k(List<int> bytes) {
    if (!_open || bytes.isEmpty) return;
    _channel?.sink.add(jsonEncode({
      'realtimeInput': {
        'audio': {
          'mimeType': 'audio/pcm;rate=16000',
          'data': base64Encode(bytes),
        },
      },
    }));
  }

  /// Text from the screen (a tap, or the opening kick-off).
  ///
  /// Goes over `realtimeInput`, not `clientContent`: a `clientContent` turn
  /// cancels the reply in progress, which is what made the model restart its
  /// sentences. `gemini-3.1-flash-live-preview` only accepts `clientContent`
  /// for seeding history anyway.
  void sendUserText(String text) {
    if (!_open || text.trim().isEmpty) return;
    _channel?.sink.add(jsonEncode({
      'realtimeInput': {'text': text},
    }));
  }

  /// Tell the server the patient has finished, without waiting out the full
  /// silence window. Used when we already heard a complete answer.
  void sendAudioStreamEnd() {
    if (!_open) return;
    _channel?.sink.add(jsonEncode({
      'realtimeInput': {'audioStreamEnd': true},
    }));
  }

  void sendToolResults(List<GeminiLiveToolCall> calls, List<String> results) {
    if (!_open || calls.isEmpty) return;
    final responses = <Map<String, dynamic>>[];
    for (var i = 0; i < calls.length; i++) {
      final call = calls[i];
      final text = i < results.length ? results[i] : '';
      responses.add({
        'id': call.id,
        'name': call.name,
        'response': {'result': text},
      });
    }
    _channel?.sink.add(jsonEncode({
      'toolResponse': {'functionResponses': responses},
    }));
  }

  void _onMessage(dynamic raw) {
    Map<String, dynamic>? map;
    try {
      final decoded = raw is String
          ? jsonDecode(raw)
          : jsonDecode(utf8.decode(raw as List<int>));
      if (decoded is Map<String, dynamic>) {
        map = decoded;
      } else if (decoded is Map) {
        map = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return;
    }
    if (map == null) return;

    if (map.containsKey('setupComplete') || map.containsKey('setup_complete')) {
      if (_ready != null && !_ready!.isCompleted) _ready!.complete();
      return;
    }
    if (map['error'] is Map) {
      final msg = map['error']['message']?.toString() ?? 'Live error';
      onError?.call(msg);
      if (_ready != null && !_ready!.isCompleted) {
        _ready!.completeError(StateError(msg));
      }
      return;
    }

    final tool = map['toolCall'] ?? map['tool_call'];
    if (tool is Map) {
      final calls = _readToolCalls(tool);
      if (calls.isNotEmpty) onToolCalls?.call(calls);
    }

    final sc = map['serverContent'] ?? map['server_content'];
    if (sc is Map) {
      if (sc['interrupted'] == true) onInterrupted?.call();
      _readIn(sc['inputTranscription'] ?? sc['input_transcription']);
      _readOut(sc['outputTranscription'] ?? sc['output_transcription']);
      _readAudio(sc['modelTurn'] ?? sc['model_turn']);
      if (sc['generationComplete'] == true ||
          sc['generation_complete'] == true) {
        onGenerationComplete?.call();
      }
      final done = sc['turnComplete'] == true || sc['turn_complete'] == true;
      if (done) {
        _flushIn();
        _flushOut();
        onTurnComplete?.call();
      }
    }
  }

  List<GeminiLiveToolCall> _readToolCalls(Map tool) {
    final raw = tool['functionCalls'] ?? tool['function_calls'];
    if (raw is! List) return const [];
    final out = <GeminiLiveToolCall>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final name = (item['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final id = (item['id'] ?? item['name'] ?? 'tool').toString();
      final argsRaw = item['args'] ?? item['arguments'] ?? {};
      final args = argsRaw is Map
          ? Map<String, dynamic>.from(argsRaw)
          : <String, dynamic>{};
      out.add(GeminiLiveToolCall(id: id, name: name, args: args));
    }
    return out;
  }

  void _readAudio(dynamic turn) {
    if (turn is! Map) return;
    final parts = turn['parts'];
    if (parts is! List) return;
    for (final p in parts) {
      if (p is! Map) continue;
      final inline = p['inlineData'] ?? p['inline_data'];
      if (inline is! Map) continue;
      final data = inline['data']?.toString();
      if (data == null || data.isEmpty) continue;
      try {
        onAssistantAudio?.call(Uint8List.fromList(base64Decode(data)));
      } catch (_) {}
    }
  }

  void _readIn(dynamic node) {
    final t = _textOf(node);
    if (t.isEmpty) return;
    _inUtterance = _merge(_inUtterance, t);
    onUserPartial?.call(_inUtterance);
    if (node is Map && node['finished'] == true) _flushIn();
  }

  void _readOut(dynamic node) {
    final t = _textOf(node);
    if (t.isEmpty) return;
    _outUtterance = _merge(_outUtterance, t);
    if (node is Map && node['finished'] == true) _flushOut();
  }

  String _textOf(dynamic node) {
    if (node is! Map) return '';
    return (node['text'] ?? '').toString();
  }

  String _merge(String prev, String next) {
    if (prev.isEmpty || next.startsWith(prev)) return next;
    if (prev.startsWith(next)) return prev;
    return '$prev$next';
  }

  void _flushIn() {
    final t = _inUtterance.trim();
    _inUtterance = '';
    if (t.isNotEmpty) onUserTranscript?.call(t);
  }

  void _flushOut() {
    final t = _outUtterance.trim();
    _outUtterance = '';
    if (t.isNotEmpty) onAssistantTranscript?.call(t);
  }

  Future<void> close() async {
    _inUtterance = '';
    _outUtterance = '';
    _open = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}
