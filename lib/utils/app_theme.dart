import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/punjab_ui.dart';

/// Punjab Health Department theme — Light and Dark.
class AppTheme {
  AppTheme._();

  static ColorScheme get _lightScheme => const ColorScheme.light(
        primary: PunjabColors.primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFD8EDE3),
        onPrimaryContainer: PunjabColors.primaryDark,
        secondary: PunjabColors.accent,
        onSecondary: Colors.white,
        tertiary: PunjabColors.labBlue,
        surface: PunjabColors.background,
        onSurface: PunjabColors.textPrimary,
        onSurfaceVariant: PunjabColors.textSecondary,
        outline: PunjabColors.border,
        error: PunjabColors.danger,
        surfaceContainerHighest: Color(0xFFE8EDEA),
      );

  static ColorScheme get _darkScheme => const ColorScheme.dark(
        primary: Color(0xFF4CAF7A),
        onPrimary: Color(0xFF0A1F14),
        primaryContainer: Color(0xFF1B3D2B),
        onPrimaryContainer: Color(0xFFB8E6CC),
        secondary: Color(0xFF5CB896),
        surface: Color(0xFF111714),
        onSurface: Color(0xFFE8EDE9),
        onSurfaceVariant: Color(0xFF9CA89F),
        outline: Color(0xFF2D3B32),
        error: Color(0xFFFF6B6B),
        surfaceContainerHighest: Color(0xFF1A231E),
      );

  static ThemeData get lightTheme => _buildTheme(_lightScheme, Brightness.light);
  static ThemeData get darkTheme => _buildTheme(_darkScheme, Brightness.dark);

  static ThemeData _buildTheme(ColorScheme scheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1A231E) : Colors.white;

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardColor,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        dividerColor: scheme.outline.withValues(alpha: 0.35),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(fontSize: 13, color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(64, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF232D28) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline.withValues(alpha: 0.4)),
      textTheme: TextTheme(
        headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: scheme.onSurface),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface),
        titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: scheme.onSurface),
        titleSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface),
        bodyLarge: TextStyle(fontSize: 16, color: scheme.onSurface, height: 1.45),
        bodyMedium: TextStyle(fontSize: 15, color: scheme.onSurface, height: 1.4),
        bodySmall: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.35),
      ),
    );
  }

  static bool isDark(BuildContext context) =>
      Theme.of(context).colorScheme.brightness == Brightness.dark;

  static Color cardColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.cardTheme.color ??
        theme.colorScheme.surfaceContainerHighest;
  }

  static Color inputFillColor(BuildContext context) {
    final fill = Theme.of(context).inputDecorationTheme.fillColor;
    if (fill != null) return fill;
    return cardColor(context);
  }

  static BoxDecoration cardDecoration(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = isDark(context);
    return BoxDecoration(
      color: cardColor(context),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: scheme.outline.withValues(alpha: dark ? 0.45 : 0.8)),
      boxShadow: dark
          ? null
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
    );
  }

  static BoxDecoration pageBackground(BuildContext context) {
    return BoxDecoration(color: Theme.of(context).colorScheme.surface);
  }

  static BoxDecoration screenGradient(BuildContext context) => pageBackground(context);

  static BoxDecoration elevatedCard(BuildContext context, {Color? accent}) =>
      cardDecoration(context);

  static BoxDecoration formCardDecoration(BuildContext context) => elevatedCard(context);

  static BoxDecoration drawerHeaderDecoration(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [scheme.primary, scheme.primary.withValues(alpha: 0.85)],
      ),
      borderRadius: const BorderRadius.only(bottomRight: Radius.circular(24)),
    );
  }

  static Widget heroIcon(BuildContext context, {required IconData icon, double size = 64, double containerSize = 96}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: size, color: scheme.primary),
    );
  }
}
