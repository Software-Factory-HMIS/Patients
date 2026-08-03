import 'dart:convert';

/// Extracts human-readable note text from API clinicalNotes / notes payloads.
List<String> extractClinicalNoteTexts(
  dynamic raw, {
  List<dynamic>? fallbackNotes,
}) {
  final texts = <String>[];

  void addFromList(dynamic list) {
    if (list is! List) return;
    for (final item in list) {
      if (item is Map) {
        final desc = (item['description'] ??
                item['Description'] ??
                item['note'] ??
                item['Note'] ??
                item['clinicalNote'] ??
                item['ClinicalNote'] ??
                '')
            .toString()
            .trim();
        if (desc.isNotEmpty && desc != 'null') texts.add(desc);
      } else if (item != null) {
        final s = item.toString().trim();
        if (s.isNotEmpty && s != 'null') texts.add(s);
      }
    }
  }

  if (raw is List) {
    addFromList(raw);
  } else if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty ||
        trimmed == '[]' ||
        trimmed == '{}' ||
        trimmed == 'null') {
      // no-op
    } else if (trimmed.startsWith('[')) {
      try {
        addFromList(jsonDecode(trimmed));
      } catch (_) {
        final descRegex = RegExp(
          r'description:\s*([^,}\]]+)',
          caseSensitive: false,
        );
        for (final match in descRegex.allMatches(trimmed)) {
          final desc = match.group(1)?.trim();
          if (desc != null && desc.isNotEmpty && desc != 'null') texts.add(desc);
        }
        if (texts.isEmpty) texts.add(trimmed);
      }
    } else {
      texts.add(trimmed);
    }
  } else if (raw is Map) {
    final desc = (raw['description'] ?? raw['Description'] ?? '')
        .toString()
        .trim();
    if (desc.isNotEmpty) texts.add(desc);
  }

  if (texts.isEmpty && fallbackNotes != null) {
    addFromList(fallbackNotes);
  }

  return texts;
}

String formatClinicalNotesDisplay(
  dynamic raw, {
  List<dynamic>? fallbackNotes,
}) {
  return extractClinicalNoteTexts(raw, fallbackNotes: fallbackNotes).join('\n');
}
