import 'package:flutter/material.dart';

/// Visual tokens for My Health Record sign-in flow.
class SignInAuthTheme {
  SignInAuthTheme._();

  static const primary = Color(0xFF0B4D35);
  static const primaryDark = Color(0xFF083D2A);
  static const titleGreen = Color(0xFF0A3F2C);
  static const brandLink = Color(0xFF009091);
  static const background = Color(0xFFF6F8F7);
  static const cardWhite = Colors.white;
  static const inputFill = Color(0xFFE9EEF5);
  static const infoFill = Color(0xFFE8EEF6);
  static const textBody = Color(0xFF374151);
  static const textMuted = Color(0xFF9CA3AF);
  static const textLabel = Color(0xFF111827);
  static const linkBlue = Color(0xFF1D4ED8);
  static const border = Color(0xFFDCE3EB);
  static const divider = Color(0xFFD1D5DB);
  static const danger = Color(0xFFDC2626);

  static const serif = TextStyle(
    fontFamily: 'serif',
    fontWeight: FontWeight.w700,
    color: titleGreen,
  );

  static BoxDecoration pageDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [const Color(0xFFDFEDE4), const Color(0xFFF0F5F2), background],
      stops: const [0.0, 0.28, 1.0],
    ),
  );

  static BoxDecoration cardDecoration = BoxDecoration(
    color: cardWhite,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: border.withValues(alpha: 0.6)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration inputDecoration = BoxDecoration(
    color: inputFill,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: border),
  );

  static BoxDecoration infoBoxDecoration = BoxDecoration(
    color: infoFill,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: border.withValues(alpha: 0.7)),
  );

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static ColorScheme _scheme(BuildContext context) =>
      Theme.of(context).colorScheme;

  static BoxDecoration pageDecorationFor(BuildContext context) {
    if (isDark(context)) {
      return BoxDecoration(color: _scheme(context).surface);
    }
    return pageDecoration;
  }

  static BoxDecoration cardDecorationFor(BuildContext context) {
    if (isDark(context)) {
      final scheme = _scheme(context);
      return BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.45)),
      );
    }
    return cardDecoration;
  }

  static BoxDecoration inputDecorationFor(BuildContext context) {
    if (isDark(context)) {
      final scheme = _scheme(context);
      return BoxDecoration(
        color: const Color(0xFF232D28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline),
      );
    }
    return inputDecoration;
  }

  static BoxDecoration infoBoxDecorationFor(BuildContext context) {
    if (isDark(context)) {
      final scheme = _scheme(context);
      return BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.45)),
      );
    }
    return infoBoxDecoration;
  }

  static TextStyle titleStyleFor(BuildContext context) {
    if (isDark(context)) {
      return TextStyle(
        fontFamily: 'serif',
        fontWeight: FontWeight.w700,
        color: _scheme(context).onSurface,
      );
    }
    return serif;
  }

  static Color bodyTextColor(BuildContext context) =>
      isDark(context) ? _scheme(context).onSurface : textBody;

  static Color mutedTextColor(BuildContext context) =>
      isDark(context) ? _scheme(context).onSurfaceVariant : textMuted;

  static Color labelTextColor(BuildContext context) =>
      isDark(context) ? _scheme(context).onSurface : textLabel;

  static Color dividerColor(BuildContext context) =>
      isDark(context) ? _scheme(context).outline : divider;
}
