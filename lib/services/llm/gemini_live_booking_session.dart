import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Gemini Live: mic PCM in, spoken reply + transcripts out.
class GeminiLiveBookingSession {
  GeminiLiveBookingSession({required this.apiKey, this.model});

  final String apiKey;
  final String? model;

  static const _host =
      'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';

  static const systemInstruction = '''
You are a helpful Punjab HMIS voice assistant for patients booking a hospital visit.
Speak briefly in the patient's language (Urdu, Roman Urdu, or English — mix is OK).
You only help book a visit. Do not give medical advice.
Ask one question at a time.
Steps: hospital name → date → complaint → confirm yes/no.
If they name a future date, say we can only issue today's queue token.
When the app sends you a fact (hospital found, date accepted), acknowledge in one short sentence and ask the next question.
''';

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Completer<void>? _ready;
  bool _open = false;
  String _inUtterance = '';
  String _outUtterance = '';

  void Function(String text)? onUserTranscript;
  void Function(String text)? onAssistantTranscript;
  void Function(Uint8List pcm)? onAssistantAudio;
  void Function()? onTurnComplete;
  void Function(String err)? onError;

  bool get isOpen => _open;

  Future<bool> connect() async {
    final id = model?.trim().isNotEmpty == true
        ? model!.trim()
        : 'gemini-3.1-flash-live-preview';
    try {
      await _openSocket(id);
      return true;
    } catch (_) {
      await close();
      try {
        await _openSocket('gemini-live-2.5-flash-native-audio');
        return true;
      } catch (e) {
        onError?.call(e.toString());
        await close();
        return false;
      }
    }
  }

  Future<void> _openSocket(String modelId) async {
    final uri = Uri.parse(
      '$_host?key=${Uri.encodeQueryComponent(apiKey.trim())}',
    );
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
    channel.sink.add(jsonEncode({
      'setup': {
        'model': 'models/$modelId',
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {'voiceName': 'Puck'},
            },
          },
        },
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction},
          ]
        },
        'inputAudioTranscription': <String, dynamic>{},
        'outputAudioTranscription': <String, dynamic>{},
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

  void sendAppText(String text) {
    if (!_open || text.trim().isEmpty) return;
    _channel?.sink.add(jsonEncode({
      'clientContent': {
        'turns': [
          {
            'role': 'user',
            'parts': [
              {'text': text},
            ],
          }
        ],
        'turnComplete': true,
      },
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

    final sc = map['serverContent'] ?? map['server_content'];
    if (sc is Map) {
      _readIn(sc['inputTranscription'] ?? sc['input_transcription']);
      _readOut(sc['outputTranscription'] ?? sc['output_transcription']);
      _readAudio(sc['modelTurn'] ?? sc['model_turn']);
      final done = sc['turnComplete'] == true || sc['turn_complete'] == true;
      if (done) {
        _flushIn();
        _flushOut();
        onTurnComplete?.call();
      }
    }
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
    _flushIn();
    _flushOut();
    _open = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}
