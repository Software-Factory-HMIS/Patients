import 'package:flutter/material.dart';

import '../screens/appointment_success_screen.dart';
import '../services/voice_appointment_service.dart';

class VoiceAppointmentSheet extends StatefulWidget {
  final int patientId;
  final Map<String, dynamic> patient;
  final Map<String, dynamic>? savedUserData;
  final VoidCallback? onGoHome;

  const VoiceAppointmentSheet({
    super.key,
    required this.patientId,
    required this.patient,
    this.savedUserData,
    this.onGoHome,
  });

  static Future<void> show(
    BuildContext context, {
    required int patientId,
    required Map<String, dynamic> patient,
    Map<String, dynamic>? savedUserData,
    VoidCallback? onGoHome,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => VoiceAppointmentSheet(
        patientId: patientId,
        patient: patient,
        savedUserData: savedUserData,
        onGoHome: onGoHome,
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
    final booked = _svc.booked;
    if (_openedSuccess || _svc.step != VoiceBookStep.done || booked == null) {
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
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
            _svc.isLive ? Icons.mic : Icons.mic_none,
            size: 40,
            color: _svc.isLive ? cs.primary : cs.outline,
          ),
          const SizedBox(height: 8),
          Text(
            'Speak to book a visit',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _svc.status,
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          if (_svc.lastHeard.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('You: ${_svc.lastHeard}',
                  style: const TextStyle(fontSize: 13)),
            ),
          ],
          if (_svc.lastSaid.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Assistant: ${_svc.lastSaid}',
                  style: TextStyle(fontSize: 13, color: cs.primary)),
            ),
          ],
          if (_svc.error != null) ...[
            const SizedBox(height: 10),
            Text(_svc.error!, style: TextStyle(color: cs.error, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await _svc.stop();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Stop'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
