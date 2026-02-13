import 'package:flutter/material.dart';

/// Shared design tokens for consistent, professional UI across Patients app.
/// Supports Light, Dark, High Contrast (WCAG AAA) for accessibility.
class AppTheme {
  AppTheme._();

  static const Color _seedColor = Color(0xFF2563EB);
  static ColorScheme get _lightScheme => ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.light,
        primary: const Color(0xFF2563EB),
        secondary: const Color(0xFF10B981),
      );

  static ColorScheme get _darkScheme => ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
        primary: const Color(0xFF60A5FA),
        secondary: const Color(0xFF34D399),
      );

  /// WCAG AAA high contrast - black on white (7:1)
  static ColorScheme get _highContrastLightScheme => const ColorScheme.light(
        primary: Color(0xFF003366),
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF003366),
        onPrimaryContainer: Colors.white,
        secondary: Color(0xFF003366),
        onSecondary: Colors.white,
        surface: Color(0xFFFFFFFF),
        onSurface: Color(0xFF000000),
        onSurfaceVariant: Color(0xFF000000),
        outline: Color(0xFF000000),
        outlineVariant: Color(0xFF000000),
        error: Color(0xFFB00020),
        onError: Colors.white,
      );

  /// WCAG AAA high contrast - white on black (7:1)
  static ColorScheme get _highContrastDarkScheme => const ColorScheme.dark(
        primary: Color(0xFF66B3FF),
        onPrimary: Color(0xFF000000),
        primaryContainer: Color(0xFF66B3FF),
        onPrimaryContainer: Color(0xFF000000),
        secondary: Color(0xFF66B3FF),
        onSecondary: Color(0xFF000000),
        surface: Color(0xFF000000),
        onSurface: Color(0xFFFFFFFF),
        onSurfaceVariant: Color(0xFFFFFFFF),
        outline: Color(0xFFFFFFFF),
        outlineVariant: Color(0xFFFFFFFF),
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF000000),
      );

  static ThemeData get lightTheme => _buildBaseTheme(_lightScheme, Brightness.light);

  static ThemeData get darkTheme => _buildBaseTheme(_darkScheme, Brightness.dark);

  static ThemeData get highContrastLightTheme =>
      _buildHighContrastTheme(_highContrastLightScheme, Brightness.light);

  static ThemeData get highContrastDarkTheme =>
      _buildHighContrastTheme(_highContrastDarkScheme, Brightness.dark);

  static ThemeData _buildBaseTheme(ColorScheme scheme, Brightness brightness) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Roboto',
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: scheme.surface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          disabledForegroundColor: scheme.onSurface.withOpacity(0.6),
          disabledBackgroundColor: scheme.surfaceContainerHighest,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 16),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(fontSize: 16, color: scheme.onSurface),
        bodyMedium: TextStyle(fontSize: 16, color: scheme.onSurface),
        bodySmall: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
    );
  }

  static ThemeData _buildHighContrastTheme(ColorScheme scheme, Brightness brightness) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Roboto',
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outline, width: 3),
        ),
        color: scheme.surface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: scheme.outline, width: 2),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: scheme.outline, width: 2),
          ),
          disabledForegroundColor: scheme.onSurface.withOpacity(0.7),
          disabledBackgroundColor: scheme.surfaceContainerHighest,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: BorderSide(color: scheme.outline, width: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 17),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline, width: 3),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(fontSize: 17, color: scheme.onSurface),
        bodyMedium: TextStyle(fontSize: 17, color: scheme.onSurface),
        bodySmall: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
    );
  }

  /// Gradient background for auth/form screens.
  static BoxDecoration screenGradient(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          scheme.primaryContainer.withOpacity(0.25),
          scheme.surface,
          scheme.surfaceContainerHighest.withOpacity(0.8),
        ],
        stops: const [0.0, 0.45, 1.0],
      ),
    );
  }

  /// Card with subtle border for form sections.
  static BoxDecoration formCardDecoration(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: scheme.outline.withOpacity(0.12), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Icon container for hero sections (OTP, phone, etc.).
  static Widget heroIcon(
    BuildContext context, {
    required IconData icon,
    double size = 64,
    double containerSize = 96,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.6),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, size: size, color: scheme.primary),
    );
  }
}
