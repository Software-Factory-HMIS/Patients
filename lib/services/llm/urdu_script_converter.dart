import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../utils/emr_api_client.dart';

/// Display-only: Roman / mixed speech → Pakistani Urdu script.
class UrduScriptConverter {
  UrduScriptConverter({required this.api, this.apiKey});

  final EmrApiClient api;
  final String? apiKey;

  static const _model = 'gemini-2.5-flash';
  static const _prompt =
      'Rewrite the patient spoken line as Pakistani Urdu script (نستعلیق / عربی رسم الخط). '
      'Output only that line. No quotes or labels. Never Roman Urdu. Never Hindi. Never Devanagari. '
      'Keep official English hospital names. Keep digits. '
      'If it is already proper English (not Roman Urdu), return it unchanged. '
      'If it is already Urdu script, return it unchanged.';

  static final _roman = RegExp(
    r'\b(haan|han|nahi|nahin|aaj|aj|kal|mein|mai|hai|hain|aap|mujhe|'
    r'chahiye|theek|sahi|jee|wala|wali|karo|karke|liye|acha|accha|'
    r'hospital|haspatal|bukhar|pet|dard)\b',
    caseSensitive: false,
  );

  static const _short = {
    'yes': 'جی',
    'yeah': 'جی',
    'yep': 'جی',
    'ok': 'ٹھیک ہے',
    'okay': 'ٹھیک ہے',
    'haan': 'ہاں',
    'han': 'ہاں',
    'ji': 'جی',
    'jee': 'جی',
    'theek': 'ٹھیک ہے',
    'sahi': 'صحیح',
    'no': 'نہیں',
    'nah': 'نہیں',
    'nahi': 'نہیں',
    'nahin': 'نہیں',
    'cancel': 'منسوخ',
    'stop': 'روکو',
    'today': 'آج',
    'aaj': 'آج',
    'aj': 'آج',
    'tomorrow': 'کل',
    'kal': 'کل',
  };

  Future<String> toScript(String raw) async {
    final t = raw.trim();
    if (t.isEmpty || isUrduScript(t)) return _stripHindi(t);
    final local = _localShort(t);
    if (local != null) return local;
    if (_isPlainEnglish(t)) return t;

    final key = apiKey?.trim() ?? '';
    if (key.isNotEmpty) {
      final via = await _viaGemini(key, t);
      if (via != null && via.isNotEmpty) return _stripHindi(via);
    }
    return _stripHindi(await api.toUrduScript(t) ?? t);
  }

  static String _stripHindi(String s) {
    return s.replaceAll(RegExp(r'[\u0900-\u097F]'), '').trim();
  }

  static bool isUrduScript(String s) {
    var letters = 0;
    var arabic = 0;
    for (final r in s.runes) {
      final letter = (r >= 0x41 && r <= 0x5A) ||
          (r >= 0x61 && r <= 0x7A) ||
          (r >= 0x0600 && r <= 0x06FF);
      if (!letter) continue;
      letters++;
      if (r >= 0x0600 && r <= 0x06FF) arabic++;
    }
    return letters > 0 && arabic * 2 >= letters;
  }

  static String? _localShort(String t) {
    final key = t.toLowerCase().replaceAll(RegExp(r'[!.?,]'), '').trim();
    return _short[key];
  }

  static bool _isPlainEnglish(String t) {
    if (_roman.hasMatch(t)) return false;
    return RegExp(r'[A-Za-z]').hasMatch(t);
  }

  Future<String?> _viaGemini(String key, String raw) async {
    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$_model:generateContent?key=${Uri.encodeQueryComponent(key)}',
      );
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'systemInstruction': {
                'parts': [
                  {'text': _prompt},
                ]
              },
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': raw},
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0,
                'maxOutputTokens': 256,
              },
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      final cands = decoded['candidates'];
      if (cands is! List || cands.isEmpty) return null;
      final first = cands.first;
      if (first is! Map) return null;
      final content = first['content'];
      if (content is! Map) return null;
      final parts = content['parts'];
      if (parts is! List) return null;
      final buf = StringBuffer();
      for (final p in parts) {
        if (p is Map && p['text'] != null) buf.write(p['text']);
      }
      var text = buf.toString().trim();
      if (text.startsWith('```')) {
        final nl = text.indexOf('\n');
        if (nl > 0) text = text.substring(nl + 1);
        if (text.endsWith('```')) {
          text = text.substring(0, text.length - 3);
        }
      }
      text = text.trim().replaceAll(RegExp(r'^["«]|["»]$'), '');
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }
}
