import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../services/locale_service.dart';
import '../services/theme_service.dart';
import '../services/llm/patient_ai_settings.dart';
import '../utils/app_localizations_ext.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.settings),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SettingsCard(
                      icon: Icons.language_rounded,
                      title: l.language,
                      subtitle: l.languageDescription,
                      child: ValueListenableBuilder<Locale>(
                        valueListenable: LocaleService.instance.localeNotifier,
                        builder: (context, current, _) {
                          final selected =
                              LocaleService.instance.currentLanguage;
                          return Row(
                            children: [
                              Expanded(
                                child: _OptionCard(
                                  icon: Icons.translate_rounded,
                                  label: l.languageEnglish,
                                  isSelected: selected == AppLanguage.english,
                                  onTap: () => LocaleService.instance
                                      .setLanguage(AppLanguage.english),
                                ),
                              ),
                              const Gap(12),
                              Expanded(
                                child: _OptionCard(
                                  icon: Icons.menu_book_rounded,
                                  label: l.languageUrdu,
                                  isSelected: selected == AppLanguage.urdu,
                                  onTap: () => LocaleService.instance
                                      .setLanguage(AppLanguage.urdu),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const Gap(16),
                    _SettingsCard(
                      icon: Icons.palette_rounded,
                      title: l.appearance,
                      subtitle: l.appearanceDescription,
                      child: ValueListenableBuilder<AppThemeMode>(
                        valueListenable: ThemeService.instance.themeNotifier,
                        builder: (context, current, _) {
                          return Row(
                            children: [
                              Expanded(
                                child: _OptionCard(
                                  icon: Icons.light_mode_rounded,
                                  label: l.themeLight,
                                  isSelected: current == AppThemeMode.light,
                                  previewColor: const Color(0xFFFFF8E7),
                                  previewBorder: const Color(0xFFFFE082),
                                  iconColor: const Color(0xFFF59E0B),
                                  onTap: () => ThemeService.instance
                                      .setThemeMode(AppThemeMode.light),
                                ),
                              ),
                              const Gap(12),
                              Expanded(
                                child: _OptionCard(
                                  icon: Icons.dark_mode_rounded,
                                  label: l.themeDark,
                                  isSelected: current == AppThemeMode.dark,
                                  previewColor: const Color(0xFF1E293B),
                                  previewBorder: const Color(0xFF334155),
                                  iconColor: const Color(0xFF93C5FD),
                                  onTap: () => ThemeService.instance
                                      .setThemeMode(AppThemeMode.dark),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const Gap(16),
                    const _VoiceAiSettingsCard(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.55 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colorScheme.primary),
              const Gap(10),
              Text(title, style: theme.textTheme.titleMedium),
            ],
          ),
          const Gap(8),
          Text(subtitle, style: theme.textTheme.bodySmall),
          const Gap(20),
          child,
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? previewColor;
  final Color? previewBorder;
  final Color? iconColor;

  const _OptionCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.previewColor,
    this.previewBorder,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.12)
                : colorScheme.surface.withValues(alpha: 0.6),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.35),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              if (previewColor != null) ...[
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: previewColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: previewBorder ?? colorScheme.outline,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: iconColor ?? colorScheme.primary,
                  ),
                ),
                const Gap(12),
              ] else ...[
                Icon(
                  icon,
                  size: 32,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const Gap(12),
              ],
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
              ),
              const Gap(8),
              // Reserve checkmark space so selected/unselected stay equal height.
              SizedBox(
                height: 20,
                child: isSelected
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: colorScheme.primary,
                        size: 20,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceAiSettingsCard extends StatefulWidget {
  const _VoiceAiSettingsCard();

  @override
  State<_VoiceAiSettingsCard> createState() => _VoiceAiSettingsCardState();
}

class _VoiceAiSettingsCardState extends State<_VoiceAiSettingsCard> {
  final _keyCtrl = TextEditingController();
  String _provider = PatientAiSettings.defaultProvider;
  String _model = PatientAiSettings.defaultModel;
  bool _loading = true;
  bool _saving = false;
  bool _obscure = true;
  String? _savedNote;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await PatientAiSettings.load();
    if (!mounted) return;
    setState(() {
      _provider = s.provider;
      _model = PatientAiSettings.liveModels.contains(s.model)
          ? s.model
          : PatientAiSettings.defaultModel;
      _keyCtrl.text = s.apiKey;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _savedNote = null;
    });
    await PatientAiSettings.save(
      provider: _provider,
      model: _model,
      apiKey: _keyCtrl.text,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _savedNote = 'Saved on this phone. Later this will come from HMIS.';
    });
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _SettingsCard(
        icon: Icons.mic_rounded,
        title: 'Voice booking (Gemini)',
        subtitle: 'Loading…',
        child: LinearProgressIndicator(),
      );
    }

    return _SettingsCard(
      icon: Icons.mic_rounded,
      title: 'Voice booking (Gemini)',
      subtitle:
          'Used when the patient taps Speak. Same idea as hospital AI keys. Later this comes from the database.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _provider,
            decoration: const InputDecoration(
              labelText: 'Provider',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'gemini', child: Text('Google Gemini')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _provider = v);
            },
          ),
          const Gap(12),
          DropdownButtonFormField<String>(
            value: PatientAiSettings.liveModels.contains(_model)
                ? _model
                : PatientAiSettings.defaultModel,
            decoration: const InputDecoration(
              labelText: 'Live model',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final m in PatientAiSettings.liveModels)
                DropdownMenuItem(value: m, child: Text(m)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _model = v);
            },
          ),
          const Gap(12),
          TextField(
            controller: _keyCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Gemini API key',
              border: const OutlineInputBorder(),
              hintText: 'AIza…',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const Gap(12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save voice settings'),
          ),
          if (_savedNote != null) ...[
            const Gap(8),
            Text(_savedNote!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
