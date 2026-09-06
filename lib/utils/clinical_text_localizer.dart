import '../l10n/app_localizations.dart';

/// Localizes structured clinical phrases from EMR English before UI bind.
/// Free-text diagnoses / medicine names stay as returned by the API.
class ClinicalTextLocalizer {
  ClinicalTextLocalizer._();

  static final _immediatelyFor = RegExp(
    r'^Immediately for (\d+)\s*(days?|weeks?|months?)$',
    caseSensitive: false,
  );
  static final _durationOnly = RegExp(
    r'^(\d+)\s*(days?|weeks?|months?)$',
    caseSensitive: false,
  );

  static String phrase(AppLocalizations l, String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return text;

    final immediately = _immediatelyFor.firstMatch(text);
    if (immediately != null) {
      final count = int.tryParse(immediately.group(1) ?? '') ?? 0;
      final duration = _duration(l, count, immediately.group(2)!);
      return l.medImmediatelyFor(duration);
    }

    final durationOnly = _durationOnly.firstMatch(text);
    if (durationOnly != null) {
      final count = int.tryParse(durationOnly.group(1) ?? '') ?? 0;
      return _duration(l, count, durationOnly.group(2)!);
    }

    return text;
  }

  static String status(AppLocalizations l, String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return text;
    final lower = text.toLowerCase().replaceAll('_', ' ');
    if (lower.contains('checked in') || lower == 'checkedin') {
      return l.statusCheckedIn;
    }
    if (lower.contains('checked out') || lower == 'checkedout') {
      return l.statusCheckedOut;
    }
    if (lower.contains('complet')) return l.statusCompleted;
    if (lower.contains('discontinu') ||
        lower.contains('stopped') ||
        lower.contains('cancel')) {
      return l.statusStopped;
    }
    return text;
  }

  static String checkupTitle(AppLocalizations l, String? encounterType) {
    final type = (encounterType ?? '').trim();
    if (type.isEmpty) return l.checkupGeneric;
    return l.checkupTitle(type);
  }

  static String _duration(AppLocalizations l, int count, String unit) {
    final u = unit.toLowerCase();
    if (u.startsWith('week')) return l.medDurationWeeks(count);
    if (u.startsWith('month')) return l.medDurationMonths(count);
    return l.medDurationDays(count);
  }
}
