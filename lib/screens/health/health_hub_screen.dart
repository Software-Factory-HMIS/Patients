import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../models/portal_models.dart';
import '../../utils/patient_fields.dart';
import '../../services/patient_portal_service.dart';
import '../../utils/app_localizations_ext.dart';
import '../../widgets/punjab_ui.dart';
import '../records/lab_reports_screen.dart';
import '../records/prescriptions_screen.dart';
import '../records/radiology_reports_screen.dart';

class HealthHubScreen extends StatefulWidget {
  final int patientId;
  final Map<String, dynamic>? patient;
  final Map<String, dynamic>? savedUserData;

  const HealthHubScreen({
    super.key,
    required this.patientId,
    this.patient,
    this.savedUserData,
  });

  @override
  State<HealthHubScreen> createState() => _HealthHubScreenState();
}

class _HealthHubScreenState extends State<HealthHubScreen> {
  final _portal = PatientPortalService();
  bool _loading = true;

  LabResultsSummary _labSummary = const LabResultsSummary();
  RadiologySummary _radSummary = const RadiologySummary();
  List<PrescriptionItem> _activeRx = [];

  static const _labTileBg = Color(0xFFE8F4FC);
  static const _labTileAccent = Color(0xFF2563EB);
  static const _radTileBg = Color(0xFFEDE9FE);
  static const _radTileAccent = Color(0xFF7C3AED);
  static const _rxBannerBg = Color(0xFFECFDF5);
  static const _rxBannerAccent = Color(0xFF059669);
  static const _cardBorder = Color(0xFFE2E8E4);
  static const _mutedText = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? get _patientName {
    if (widget.patient == null) return null;
    return PatientFields.displayName(widget.patient!, widget.savedUserData);
  }

  String? get _patientMrn {
    final p = widget.patient;
    if (p == null) return null;
    return p['mrn']?.toString() ?? p['MRN']?.toString();
  }

  String get _labCountLabel {
    if (_labSummary.pending > 0) return '${_labSummary.pending} New';
    if (_labSummary.total > 0) return '${_labSummary.total} Results';
    return '0';
  }

  String get _radCountLabel {
    if (_radSummary.finalReports > 0)
      return '${_radSummary.finalReports} Final';
    if (_radSummary.total > 0) return '${_radSummary.total} Reports';
    return '0';
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _portal.loadActivePrescriptions(widget.patientId),
        _portal.loadLabSummary(widget.patientId),
        _portal.loadRadiologySummary(widget.patientId),
      ]);
      if (!mounted) return;
      setState(() {
        _activeRx = results[0] as List<PrescriptionItem>;
        _labSummary = results[1] as LabResultsSummary;
        _radSummary = results[2] as RadiologySummary;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openLabList() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LabReportsScreen(
          patientId: widget.patientId,
          patientName: _patientName,
          patientMrn: _patientMrn,
        ),
      ),
    );
  }

  void _openRadList() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RadiologyReportsScreen(
          patientId: widget.patientId,
          patientName: _patientName,
          patientMrn: _patientMrn,
        ),
      ),
    );
  }

  void _openRxHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PrescriptionsScreen(patientId: widget.patientId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: PunjabColors.primary),
      );
    }

    final l = context.l10n;

    return RefreshIndicator(
      color: PunjabColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          PunjabPageHeader.screenInsets.left,
          PunjabPageHeader.screenInsets.top,
          PunjabPageHeader.screenInsets.right,
          PunjabBottomNav.navBarHeight,
        ),
        children: [
          PunjabPageHeader(title: l.healthHub, subtitle: l.healthHubSubtitle),
          const Gap(4),
          _PrescriptionsBanner(
            background: _rxBannerBg,
            accent: _rxBannerAccent,
            count: _activeRx.length,
            onTap: _openRxHistory,
          ),
          const Gap(12),
          Row(
            children: [
              Expanded(
                child: _HubSummaryTile(
                  background: _labTileBg,
                  accent: _labTileAccent,
                  icon: Icons.science_rounded,
                  label: l.labResults,
                  value: _labCountLabel,
                  onTap: _openLabList,
                ),
              ),
              const Gap(10),
              Expanded(
                child: _HubSummaryTile(
                  background: _radTileBg,
                  accent: _radTileAccent,
                  icon: Icons.radar_rounded,
                  label: l.radiologyReports,
                  value: _radCountLabel,
                  onTap: _openRadList,
                ),
              ),
            ],
          ),
          const Gap(22),
          _SectionHeader(
            title: _activeRx.length == 1
                ? l.activePrescription
                : l.activePrescriptions,
            action: l.refillHistory,
            onAction: _openRxHistory,
          ),
          const Gap(10),
          if (_activeRx.isEmpty)
            _HubEmptyCard(
              icon: Icons.medication_outlined,
              message: l.noActivePrescriptionsOnFile,
            )
          else
            ..._activeRx.map(
              (rx) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ActivePrescriptionCard(rx: rx),
              ),
            ),
        ],
      ),
    );
  }
}

class _HubSummaryTile extends StatelessWidget {
  final Color background;
  final Color accent;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _HubSummaryTile({
    required this.background,
    required this.accent,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const Gap(14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: accent.withValues(alpha: 0.85),
                ),
              ),
              const Gap(4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: accent,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrescriptionsBanner extends StatelessWidget {
  final Color background;
  final Color accent;
  final int count;
  final VoidCallback onTap;

  const _PrescriptionsBanner({
    required this.background,
    required this.accent,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = count == 1
        ? '1 Active Medication'
        : '$count Active Medications';

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.medication_liquid_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prescriptions',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: accent.withValues(alpha: 0.85),
                      ),
                    ),
                    const Gap(2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: accent, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: _HealthHubScreenState._mutedText,
            ),
          ),
        ),
        GestureDetector(
          onTap: onAction,
          child: Text(
            action,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: PunjabColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivePrescriptionCard extends StatelessWidget {
  final PrescriptionItem rx;

  const _ActivePrescriptionCard({required this.rx});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _HealthHubScreenState._cardBorder),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 10,
            top: 16,
            child: Icon(
              Icons.medication_outlined,
              size: 76,
              color: Colors.grey.withValues(alpha: 0.12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F4FC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.medication_rounded,
                    color: PunjabColors.primary,
                    size: 22,
                  ),
                ),
                const Gap(14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rx.medication,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const Gap(8),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          if (rx.frequency != null && rx.frequency!.isNotEmpty)
                            _RxMetaChip(
                              icon: Icons.schedule_rounded,
                              label: rx.frequency!,
                            ),
                          if (rx.startDate != null && rx.startDate!.isNotEmpty)
                            _RxMetaChip(
                              icon: Icons.event_rounded,
                              label: 'Start: ${rx.startDate}',
                            ),
                          if (rx.dosage != null && rx.dosage!.isNotEmpty)
                            _RxMetaChip(
                              icon: Icons.medication_outlined,
                              label: rx.dosage!,
                            ),
                        ],
                      ),
                      if (rx.indication != null &&
                          rx.indication!.trim().isNotEmpty) ...[
                        const Gap(8),
                        Text(
                          rx.indication!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _HealthHubScreenState._mutedText,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RxMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RxMetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: _HealthHubScreenState._mutedText),
        const Gap(4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: _HealthHubScreenState._mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _HubEmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _HubEmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _HealthHubScreenState._cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: _HealthHubScreenState._mutedText),
          const Gap(12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: _HealthHubScreenState._mutedText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
