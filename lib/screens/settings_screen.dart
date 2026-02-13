import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../services/theme_service.dart';

/// Settings screen with theme selection. Accessible from dashboard (logged in)
/// and signin (logged out) for theme preference before/without login.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Go back',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Semantics(
          label: 'Settings',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Appearance',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const Gap(12),
              Semantics(
                label: 'Theme selection',
                hint: 'Choose light, dark, system, or high contrast theme',
                child: ValueListenableBuilder<AppThemeMode>(
                  valueListenable: ThemeService.instance.themeNotifier,
                  builder: (context, current, _) {
                    return Column(
                      children: [
                        _ThemeOption(
                          mode: AppThemeMode.light,
                          icon: Icons.light_mode_outlined,
                          label: 'Light',
                          hint: 'Light background theme',
                          isSelected: current == AppThemeMode.light,
                        ),
                        _ThemeOption(
                          mode: AppThemeMode.dark,
                          icon: Icons.dark_mode_outlined,
                          label: 'Dark',
                          hint: 'Dark background theme',
                          isSelected: current == AppThemeMode.dark,
                        ),
                        _ThemeOption(
                          mode: AppThemeMode.system,
                          icon: Icons.brightness_auto_outlined,
                          label: 'Normal (System)',
                          hint: 'Follow device light or dark setting',
                          isSelected: current == AppThemeMode.system,
                        ),
                        _ThemeOption(
                          mode: AppThemeMode.highContrastLight,
                          icon: Icons.accessibility_new,
                          label: 'High Contrast Light',
                          hint: 'Accessibility theme for low vision',
                          isSelected: current == AppThemeMode.highContrastLight,
                        ),
                        _ThemeOption(
                          mode: AppThemeMode.highContrastDark,
                          icon: Icons.accessibility_new,
                          label: 'High Contrast Dark',
                          hint: 'Accessibility theme for low vision',
                          isSelected: current == AppThemeMode.highContrastDark,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final AppThemeMode mode;
  final IconData icon;
  final String label;
  final String hint;
  final bool isSelected;

  const _ThemeOption({
    required this.mode,
    required this.icon,
    required this.label,
    required this.hint,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: '$label theme',
      hint: hint,
      selected: isSelected,
      child: InkWell(
        onTap: () => ThemeService.instance.setThemeMode(mode),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withOpacity(0.5)
                : colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              const Gap(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      hint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: colorScheme.primary,
                  size: 24,
                  semanticLabel: 'Selected',
                ),
            ],
          ),
        ),
      ),
    );
  }
}
