import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../services/auth_service.dart';
import '../../services/patient_photo_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/patient_fields.dart';
import '../../widgets/patient_avatar.dart';
import '../../utils/app_localizations_ext.dart';
import '../../widgets/punjab_ui.dart';
import '../settings_screen.dart';
import '../signin_screen.dart';

class ProfileScreen extends StatefulWidget {
  final int patientId;
  final Map<String, dynamic> patient;
  final Map<String, dynamic>? savedUserData;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.patientId,
    required this.patient,
    this.savedUserData,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _hasPhoto = false;
  bool _photoBusy = false;

  @override
  void initState() {
    super.initState();
    _refreshPhotoState();
    PatientPhotoService.instance.revision.addListener(_refreshPhotoState);
  }

  @override
  void dispose() {
    PatientPhotoService.instance.revision.removeListener(_refreshPhotoState);
    super.dispose();
  }

  Future<void> _refreshPhotoState() async {
    final photo = await PatientPhotoService.instance.load(widget.patientId);
    if (!mounted) return;
    setState(() => _hasPhoto = photo != null);
  }

  String? _field(String key, [String? alt]) {
    final p = widget.patient[key];
    if (p != null && p.toString().isNotEmpty) return p.toString();
    if (alt != null) {
      final altP = widget.patient[alt];
      if (altP != null && altP.toString().isNotEmpty) return altP.toString();
    }
    if (widget.savedUserData == null) return null;
    final s = widget.savedUserData![key];
    if (s != null && s.toString().isNotEmpty) return s.toString();
    if (alt != null) {
      final altS = widget.savedUserData![alt];
      if (altS != null && altS.toString().isNotEmpty) return altS.toString();
    }
    return null;
  }

  Future<void> _pickPhoto() async {
    if (_photoBusy) return;
    setState(() => _photoBusy = true);
    try {
      await PatientPhotoService.instance.pickAndSave(widget.patientId);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    if (_photoBusy) return;
    setState(() => _photoBusy = true);
    try {
      await PatientPhotoService.instance.remove(widget.patientId);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final name = PatientFields.displayName(widget.patient, widget.savedUserData);
    final mrn = _field('mrn', 'MRN');
    final cnic = _field('cnic', 'CNIC');
    final phone = _field('phone', 'ContactNumber');
    final email = _field('email', 'Email');

    return ListView(
      padding: EdgeInsets.fromLTRB(
        PunjabPageHeader.screenInsets.left,
        PunjabPageHeader.screenInsets.top,
        PunjabPageHeader.screenInsets.right,
        PunjabBottomNav.navBarHeight,
      ),
      children: [
        PunjabPageHeader(
          title: l.tabProfile,
          subtitle: l.profileSubtitle,
        ),
        PunjabCard(
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  PatientAvatar(
                    patientId: widget.patientId,
                    name: name,
                    radius: 48,
                  ),
                  if (_photoBusy)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ),
                      ),
                    )
                  else
                    Material(
                      color: Theme.of(context).colorScheme.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _pickPhoto,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                ],
              ),
              const Gap(12),
              Text(name, style: Theme.of(context).textTheme.titleMedium),
              if (mrn != null) Text(l.mrnLabel(mrn), style: Theme.of(context).textTheme.bodySmall),
              if (cnic != null) Text(l.cnicLabel(cnic), style: Theme.of(context).textTheme.bodySmall),
              const Gap(12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _photoBusy ? null : _pickPhoto,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(_hasPhoto ? l.changePhoto : l.uploadPhoto),
                  ),
                  if (_hasPhoto) ...[
                    const Gap(8),
                    TextButton(
                      onPressed: _photoBusy ? null : _removePhoto,
                      child: Text(l.remove),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const Gap(16),
        if (phone != null || email != null)
          PunjabCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PunjabSectionTitle(title: l.contact),
                if (phone != null) _InfoRow(Icons.phone_outlined, phone),
                if (email != null) _InfoRow(Icons.email_outlined, email),
              ],
            ),
          ),
        const Gap(16),
        PunjabCard(
          child: Column(
            children: [
              _MenuRow(
                icon: Icons.settings_rounded,
                label: l.settingsMenu,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              const Divider(height: 1),
              _MenuRow(
                icon: Icons.help_outline_rounded,
                label: l.helpAndSupport,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l.help),
                      content: Text(l.helpDialogContent),
                      actions: [
                        FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(l.ok)),
                      ],
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              _MenuRow(
                icon: Icons.logout_rounded,
                label: l.logout,
                color: PunjabColors.danger,
                onTap: () async {
                  await AuthService.instance.logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                    (_) => false,
                  );
                },
              ),
            ],
          ),
        ),
        const Gap(24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.elevatedCard(context),
          child: Column(
            children: [
              Icon(Icons.verified_user_rounded, color: Theme.of(context).colorScheme.primary, size: 32),
              const Gap(8),
              Text(
                l.trustedGovernmentApp,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Gap(4),
              Text(
                l.trustedGovernmentSubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String value;
  const _InfoRow(this.icon, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const Gap(12),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: c),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: c)),
      trailing: Icon(Icons.chevron_right, color: c.withValues(alpha: 0.5)),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
