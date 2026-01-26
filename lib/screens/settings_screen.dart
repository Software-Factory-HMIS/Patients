import 'package:flutter/material.dart';
import '../services/app_settings.dart';
import '../services/auth_service.dart';
import '../utils/user_storage.dart';
import 'signin_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmAndClearCache(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear cached data?'),
        content: const Text(
          'This will clear locally saved data on this device (saved user info, recent appointments, and tokens).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );

    if (ok != true) return;

    await AuthService.instance.clearSession();
    await UserStorage.clearAllLocalData();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local data cleared')),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService.instance.logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Appearance', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ValueListenableBuilder(
            valueListenable: settings.themeMode,
            builder: (context, themeMode, _) {
              return Card(
                child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      groupValue: themeMode,
                      title: const Text('System'),
                      onChanged: (v) => settings.setThemeMode(v!),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      groupValue: themeMode,
                      title: const Text('Light'),
                      onChanged: (v) => settings.setThemeMode(v!),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      groupValue: themeMode,
                      title: const Text('Dark'),
                      onChanged: (v) => settings.setThemeMode(v!),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text('Language', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ValueListenableBuilder(
            valueListenable: settings.languageCode,
            builder: (context, code, _) {
              return Card(
                child: ListTile(
                  title: const Text('Preferred language'),
                  subtitle: Text(code == 'ur' ? 'Urdu' : 'English'),
                  trailing: DropdownButton<String>(
                    value: code,
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'ur', child: Text('Urdu')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      settings.setLanguageCode(v);
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text('Account', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Clear cached data'),
                  subtitle: const Text('Removes saved user info, appointments, and tokens from this device'),
                  onTap: () => _confirmAndClearCache(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_outlined),
                  title: const Text('Logout'),
                  onTap: () => _logout(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('About', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Patients App'),
              subtitle: Text('Healthcare Management System (Patient Portal)'),
            ),
          ),
        ],
      ),
    );
  }
}
