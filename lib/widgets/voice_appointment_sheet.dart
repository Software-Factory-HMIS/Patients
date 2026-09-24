import 'package:flutter/material.dart';

import '../l10n/app_localizations_ur.dart';
import '../screens/appointment_success_screen.dart';
import '../screens/settings_screen.dart';
import '../services/voice_appointment_service.dart';

class VoiceAppointmentSheet extends StatefulWidget {
  final int patientId;
  final Map<String, dynamic> patient;
  final Map<String, dynamic>? savedUserData;
  final VoidCallback? onGoHome;
  final VoidCallback? onTypeInstead;

  const VoiceAppointmentSheet({
    super.key,
    required this.patientId,
    required this.patient,
    this.savedUserData,
    this.onGoHome,
    this.onTypeInstead,
  });

  static Future<void> show(
    BuildContext context, {
    required int patientId,
    required Map<String, dynamic> patient,
    Map<String, dynamic>? savedUserData,
    VoidCallback? onGoHome,
    VoidCallback? onTypeInstead,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: VoiceAppointmentSheet(
          patientId: patientId,
          patient: patient,
          savedUserData: savedUserData,
          onGoHome: onGoHome,
          onTypeInstead: onTypeInstead,
        ),
      ),
    );
  }

  @override
  State<VoiceAppointmentSheet> createState() => _VoiceAppointmentSheetState();
}

class _VoiceAppointmentSheetState extends State<VoiceAppointmentSheet> {
  late final VoiceAppointmentService _svc;
  bool _openedSuccess = false;

  @override
  void initState() {
    super.initState();
    _svc = VoiceAppointmentService(
      patientId: widget.patientId,
      patient: widget.patient,
      savedUserData: widget.savedUserData,
    )..addListener(_onSvc);
    _svc.start();
  }

  void _onSvc() {
    if (!mounted) return;
    setState(() {});
    // Wait for the session to close, not just for the booking to land: the
    // token is still being read out while the step is already done.
    if (_openedSuccess || _svc.step != VoiceBookStep.done || _svc.isLive) {
      return;
    }
    final booked = _svc.booked;
    if (booked == null) {
      if ((_svc.existingToken ?? '').isNotEmpty) {
        _openedSuccess = true;
        Navigator.of(context).pop();
      }
      return;
    }
    _openedSuccess = true;
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(
      MaterialPageRoute(
        builder: (_) => AppointmentSuccessScreen(
          appointment: booked,
          onGoHome: widget.onGoHome,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _svc.removeListener(_onSvc);
    _svc.dispose();
    super.dispose();
  }

  bool get _needsApiKey => _svc.missingVoiceKey;

  Future<void> _typeInstead() async {
    await _svc.stop();
    if (!mounted) return;
    Navigator.pop(context);
    widget.onTypeInstead?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizationsUr();
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Icon(
              _svc.isSpeaking
                  ? Icons.volume_up
                  : _svc.isListening
                      ? Icons.mic
                      : Icons.mic_none,
              size: 40,
              color: _svc.isLive ? cs.primary : cs.outline,
            ),
            const SizedBox(height: 8),
            Text(
              l.speakToBookTitle,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_svc.status.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _svc.status,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
              ),
            ],
            if (_svc.step == VoiceBookStep.existingToken &&
                (_svc.existingToken ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _svc.existingToken!,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _svc.keepExisting,
                      child: Text(l.voiceUseThisToken),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _svc.bookAnother,
                      child: Text(l.voiceBookAnother),
                    ),
                  ),
                ],
              ),
            ],
            if (_svc.nearby.isNotEmpty &&
                _svc.step != VoiceBookStep.done &&
                _svc.step != VoiceBookStep.booking) ...[
              const SizedBox(height: 12),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final h in _svc.nearby)
                      ActionChip(
                        label: Text(
                          h.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _svc.tapHospital(h),
                      ),
                  ],
                ),
              ),
            ],
            if (_svc.hospital != null &&
                _svc.step != VoiceBookStep.done &&
                _svc.step != VoiceBookStep.failed) ...[
              const SizedBox(height: 8),
              _FixLine(label: _svc.hospital!.name, onTap: _svc.fixHospital),
              if (_svc.complaint.isNotEmpty)
                _FixLine(label: _svc.complaint, onTap: _svc.fixComplaint),
              if (_svc.department != null)
                _FixLine(
                  label: _svc.department!.departmentName,
                  onTap: _svc.fixDepartment,
                ),
            ],
            if (_svc.bookedToken != null &&
                _svc.bookedToken!.isNotEmpty &&
                _svc.bookedToken != 'N/A') ...[
              const SizedBox(height: 12),
              Text(
                _svc.bookedToken!,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
              ),
            ],
            if (_svc.error != null) ...[
              const SizedBox(height: 10),
              Text(
                _svc.error!,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            if (_needsApiKey)
              FilledButton(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  await _svc.stop();
                  nav.pop();
                  nav.push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                child: Text(l.voiceBookingOpenSettings),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await _svc.stop();
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text(l.voiceBookingStop),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: _typeInstead,
                      child: Text(l.voiceTypeInstead),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _FixLine extends StatelessWidget {
  const _FixLine({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      trailing: const Icon(Icons.edit_outlined, size: 16),
      onTap: onTap,
    );
  }
}
