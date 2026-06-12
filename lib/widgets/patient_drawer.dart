import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../screens/settings_screen.dart';
import '../utils/app_theme.dart';

class PatientDrawer extends StatelessWidget {
  final String patientName;
  final Map<String, dynamic>? patient;
  final Map<String, dynamic>? savedUserData;
  final int selectedTabIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onLogout;

  const PatientDrawer({
    super.key,
    required this.patientName,
    this.patient,
    this.savedUserData,
    required this.selectedTabIndex,
    required this.onTabSelected,
    required this.onLogout,
  });

  String? _field(String key, [String? altKey]) {
    final fromPatient = patient?[key];
    if (fromPatient != null && fromPatient.toString().isNotEmpty) return fromPatient.toString();
    if (altKey != null) {
      final altPatient = patient?[altKey];
      if (altPatient != null && altPatient.toString().isNotEmpty) return altPatient.toString();
    }
    final fromSaved = savedUserData?[key];
    if (fromSaved != null && fromSaved.toString().isNotEmpty) return fromSaved.toString();
    if (altKey != null) {
      final altSaved = savedUserData?[altKey];
      if (altSaved != null && altSaved.toString().isNotEmpty) return altSaved.toString();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mrn = _field('mrn', 'MRN');
    final cnic = _field('cnic', 'CNIC');
    final phone = _field('contactNumber', 'ContactNumber') ?? _field('phone');
    final email = _field('email', 'Email');
    final initial = patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P';

    return Drawer(
      width: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: AppTheme.drawerHeaderDecoration(context),
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const Gap(14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patientName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (mrn != null)
                            Text(
                              'MRN $mrn',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (cnic != null || phone != null || email != null) ...[
                  const Gap(18),
                  if (cnic != null) _InfoChip(icon: Icons.badge_outlined, label: cnic),
                  if (phone != null) ...[
                    const Gap(8),
                    _InfoChip(icon: Icons.phone_outlined, label: phone),
                  ],
                  if (email != null) ...[
                    const Gap(8),
                    _InfoChip(icon: Icons.email_outlined, label: email),
                  ],
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              children: [
                Text(
                  'MENU',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 1.1,
                  ),
                ).paddingSymmetric(horizontal: 8, vertical: 4),
                _DrawerNavTile(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: selectedTabIndex == 0,
                  onTap: () => _select(context, 0),
                ),
                _DrawerNavTile(
                  icon: Icons.event_available_rounded,
                  label: 'Book Visit',
                  selected: selectedTabIndex == 1,
                  onTap: () => _select(context, 1),
                ),
                _DrawerNavTile(
                  icon: Icons.folder_open_rounded,
                  label: 'My Visits',
                  selected: selectedTabIndex == 2,
                  onTap: () => _select(context, 2),
                ),
                _DrawerNavTile(
                  icon: Icons.favorite_rounded,
                  label: 'Health Records',
                  selected: selectedTabIndex == 3,
                  onTap: () => _select(context, 3),
                ),
                const Gap(8),
                Divider(color: colorScheme.outline.withValues(alpha: 0.2)),
                const Gap(8),
                _DrawerNavTile(
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
                _DrawerNavTile(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & Support',
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        icon: Icon(Icons.support_agent_rounded, color: colorScheme.primary, size: 36),
                        title: const Text('Need help?'),
                        content: const Text(
                          'Use Book Visit to get a hospital token.\n\n'
                          'My Visits shows your medical records.\n\n'
                          'Health has your labs, radiology, and prescriptions.',
                        ),
                        actions: [
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Got it'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Material(
              color: colorScheme.errorContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  onLogout();
                },
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, color: colorScheme.error),
                      const Gap(12),
                      Text(
                        'Logout',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _select(BuildContext context, int index) {
    Navigator.pop(context);
    onTabSelected(index);
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
        const Gap(8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _DrawerNavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerNavTile({
    required this.icon,
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = selected ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.55)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected
                        ? colorScheme.primary.withValues(alpha: 0.15)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: selected ? colorScheme.primary : accent, size: 22),
                ),
                const Gap(14),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? colorScheme.primary : colorScheme.onSurface,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: colorScheme.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on Widget {
  Widget paddingSymmetric({double horizontal = 0, double vertical = 0}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      child: this,
    );
  }
}
