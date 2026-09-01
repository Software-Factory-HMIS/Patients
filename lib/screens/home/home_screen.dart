import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../models/appointment_models.dart';
import '../../models/portal_models.dart';
import '../../screens/appointment_success_screen.dart';
import '../../services/patient_portal_service.dart';
import '../../utils/app_date_format.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/patient_fields.dart';
import '../../widgets/patient_avatar.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/app_localizations_ext.dart';
import '../../widgets/punjab_ui.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> patient;
  final int patientId;
  final String patientIdentifier;
  final Map<String, dynamic>? savedUserData;
  final VoidCallback onBookVisit;
  final VoidCallback onOpenVisits;
  final VoidCallback onOpenHealth;
  final VoidCallback? onOpenProfile;

  const HomeScreen({
    super.key,
    required this.patient,
    required this.patientId,
    required this.patientIdentifier,
    this.savedUserData,
    required this.onBookVisit,
    required this.onOpenVisits,
    required this.onOpenHealth,
    this.onOpenProfile,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _portal = PatientPortalService();
  HomeStats? _stats;
  Map<String, dynamic>? _upcoming;
  bool _loading = true;

  static const _headerGreen = Color(0xFF0F3D24);
  static const _timeBoxBlue = Color(0xFFE8F2FC);
  static const _tokenBoxBlue = Color(0xFFEEF5FC);
  static const _visitFooterGreen = Color(0xFFE8F5EE);

  @override
  void initState() {
    super.initState();
    _load();
    PatientPortalService.visitRevision.addListener(_onVisitsChanged);
  }

  @override
  void dispose() {
    PatientPortalService.visitRevision.removeListener(_onVisitsChanged);
    super.dispose();
  }

  void _onVisitsChanged() => _load();

  String _patientMrn() {
    final mrn = _mrn();
    if (mrn != null && mrn.isNotEmpty) return mrn;
    final cnic = _formatCnic(_cnic()).replaceAll('-', '');
    if (cnic.isNotEmpty) return cnic;
    return widget.patientIdentifier;
  }

  Future<void> _openUpcomingBooking() async {
    final visit = _upcoming;
    if (visit == null) {
      widget.onBookVisit();
      return;
    }
    final details = AppointmentDetails.tryFromVisit(
      visit,
      patientName: _patientName(),
      patientMRN: _patientMrn(),
    );
    if (details == null) {
      if (!mounted) return;
      AppSnackBar.showError(context, context.l10n.couldNotBookVisit);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AppointmentSuccessScreen(appointment: details),
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cnic = _portal.patientCnic(widget.patient).isNotEmpty
          ? _portal.patientCnic(widget.patient)
          : widget.patientIdentifier;
      final results = await Future.wait([
        _portal.loadHomeStats(widget.patientId),
        _portal.loadUpcomingVisit(
          patientId: widget.patientId,
          patientCnic: cnic,
          patient: widget.patient,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as HomeStats;
        _upcoming = results[1] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _patientName() {
    return PatientFields.displayName(widget.patient, widget.savedUserData);
  }

  String? _cnic() =>
      widget.patient['cnic']?.toString() ?? widget.patient['CNIC']?.toString();

  String? _mrn() =>
      widget.patient['mrn']?.toString() ?? widget.patient['MRN']?.toString();

  String? _age() {
    final raw =
        widget.patient['age'] ??
        widget.patient['Age'] ??
        widget.savedUserData?['Age'] ??
        widget.savedUserData?['age'];
    if (raw != null) {
      final text = raw.toString().trim();
      if (text.isNotEmpty) {
        if (text.toLowerCase().contains('yr')) return text;
        final years = int.tryParse(text.replaceAll(RegExp(r'\D'), ''));
        if (years != null) return '$years yrs';
        return text;
      }
    }

    final dobRaw =
        widget.patient['dateOfBirth'] ??
        widget.patient['DateOfBirth'] ??
        widget.savedUserData?['dateOfBirth'];
    if (dobRaw == null) return null;
    final dob = dobRaw is DateTime
        ? dobRaw
        : DateTime.tryParse(dobRaw.toString());
    if (dob == null) return null;

    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years >= 0 ? '$years yrs' : null;
  }

  String? _gender() {
    final raw =
        widget.patient['gender'] ??
        widget.patient['Gender'] ??
        widget.savedUserData?['Gender'] ??
        widget.savedUserData?['gender'];
    if (raw == null) return null;
    final text = raw.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? _visitsBadge(int count, AppLocalizations l) {
    if (count <= 0) return null;
    if (count >= 10) return l.months12;
    return '+$count';
  }

  String? _labGlanceBadge(HomeStats? stats, AppLocalizations l) {
    if (stats == null || stats.labResults <= 0) return null;
    if (stats.labSummary.critical > 0)
      return '${stats.labSummary.critical} ${l.critical}';
    if (stats.labSummary.hasAbnormal) return l.review;
    if (stats.labSummary.pending > 0)
      return '${stats.labSummary.pending} ${l.pending}';
    return l.onFile;
  }

  _GlanceBadgeStyle _labGlanceBadgeStyle(HomeStats? stats) {
    if (stats == null) return _GlanceBadgeStyle.muted;
    if (stats.labSummary.critical > 0) return _GlanceBadgeStyle.alert;
    if (stats.labSummary.hasAbnormal) return _GlanceBadgeStyle.alert;
    if (stats.labSummary.pending > 0) return _GlanceBadgeStyle.neutral;
    return _GlanceBadgeStyle.success;
  }

  String? _radGlanceBadge(HomeStats? stats, AppLocalizations l) {
    if (stats == null || stats.radiologyReports <= 0) return null;
    if (stats.radiologySummary.pending > 0) {
      return '${stats.radiologySummary.pending} ${l.pending}';
    }
    return '${stats.radiologySummary.finalReports} ${l.finalReports}';
  }

  _GlanceBadgeStyle _radGlanceBadgeStyle(HomeStats? stats) {
    if (stats == null) return _GlanceBadgeStyle.muted;
    if (stats.radiologySummary.pending > 0) return _GlanceBadgeStyle.neutral;
    return _GlanceBadgeStyle.success;
  }

  static String _formatCnic(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length != 13) return raw;
    return '${d.substring(0, 5)}-${d.substring(5, 12)}-${d.substring(12)}';
  }

  List<Widget> _glanceGridChildren(
    bool dark,
    AppLocalizations l, {
    bool compact = false,
  }) {
    return [
      _GlanceStatCard(
        icon: Icons.how_to_reg_rounded,
        iconColor: PunjabColors.primary,
        iconBg: PunjabColors.primary.withValues(alpha: 0.12),
        value: '${_stats?.visitCount ?? 0}',
        label: l.visits,
        badge: _visitsBadge(_stats?.visitCount ?? 0, l),
        badgeStyle: _GlanceBadgeStyle.neutral,
        onTap: widget.onOpenVisits,
        dark: dark,
        compact: compact,
      ),
      _GlanceStatCard(
        icon: Icons.medication_liquid_rounded,
        iconColor: PunjabColors.labBlue,
        iconBg: PunjabColors.labBlue.withValues(alpha: 0.12),
        value: '${_stats?.activePrescriptions ?? 0}',
        label: l.activeMeds,
        badge: (_stats?.activePrescriptions ?? 0) > 0 ? l.stable : l.none,
        badgeStyle: (_stats?.activePrescriptions ?? 0) > 0
            ? _GlanceBadgeStyle.success
            : _GlanceBadgeStyle.muted,
        onTap: widget.onOpenHealth,
        dark: dark,
        compact: compact,
      ),
      _GlanceStatCard(
        icon: Icons.biotech_rounded,
        iconColor: const Color(0xFF0891B2),
        iconBg: const Color(0xFF0891B2).withValues(alpha: 0.12),
        value: '${_stats?.labResults ?? 0}',
        label: l.labs,
        badge: _labGlanceBadge(_stats, l),
        badgeStyle: _labGlanceBadgeStyle(_stats),
        onTap: widget.onOpenHealth,
        dark: dark,
        compact: compact,
      ),
      _GlanceStatCard(
        icon: Icons.radar_rounded,
        iconColor: const Color(0xFF4F46E5),
        iconBg: const Color(0xFF4F46E5).withValues(alpha: 0.12),
        value: '${_stats?.radiologyReports ?? 0}',
        label: l.radiology,
        badge: _radGlanceBadge(_stats, l),
        badgeStyle: _radGlanceBadgeStyle(_stats),
        onTap: widget.onOpenHealth,
        dark: dark,
        compact: compact,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    final l = context.l10n;
    final metrics = _HomeMetrics.of(context);

    final bottomNavSpace = PunjabBottomNav.navBarHeight;

    return SafeArea(
      top: true,
      bottom: false,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.25,
        child: RefreshIndicator(
          color: PunjabColors.primary,
          onRefresh: _load,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _HomeMetrics.maxContentWidth,
              ),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      metrics.horizontalPadding,
                      8,
                      metrics.horizontalPadding,
                      0,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const PunjabAppBrandRow(),
                        Gap(metrics.isCompact ? 12 : 16),
                        _ProfileHeaderCard(
                          patientId: widget.patientId,
                          name: _patientName(),
                          age: _age(),
                          gender: _gender(),
                          cnic: _formatCnic(_cnic()),
                          mrn: _mrn(),
                          onEdit: widget.onOpenProfile,
                          dark: dark,
                          compact: metrics.isCompact,
                        ),
                        Gap(metrics.isCompact ? 10 : 14),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickActionTile(
                                icon: Icons.event_available_rounded,
                                label: l.bookVisit,
                                iconColor: PunjabColors.primary,
                                onTap: widget.onBookVisit,
                                dark: dark,
                                compact: metrics.isCompact,
                              ),
                            ),
                            Gap(metrics.isCompact ? 8 : 12),
                            Expanded(
                              child: _QuickActionTile(
                                icon: Icons.folder_shared_rounded,
                                label: l.healthRecords,
                                iconColor: PunjabColors.labBlue,
                                onTap: widget.onOpenHealth,
                                dark: dark,
                                compact: metrics.isCompact,
                              ),
                            ),
                          ],
                        ),
                        Gap(metrics.isCompact ? 18 : 22),
                        _SectionHeader(
                          title: l.upcomingVisit,
                          action: l.viewAll,
                          onAction: widget.onOpenVisits,
                        ),
                        const Gap(10),
                        _UpcomingVisitCard(
                          appointment: _upcoming,
                          onBook: widget.onBookVisit,
                          onJoinQueue: _openUpcomingBooking,
                          dark: dark,
                          compact: metrics.isCompact,
                          veryCompact: metrics.isVeryCompact,
                        ),
                        Gap(metrics.isCompact ? 18 : 24),
                        _HealthGlanceHeader(
                          title: l.healthAtAGlance,
                          dark: dark,
                        ),
                        const Gap(14),
                      ]),
                    ),
                  ),
                  if (_loading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: metrics.horizontalPadding,
                      ),
                      sliver: SliverGrid(
                        delegate: SliverChildListDelegate(
                          _glanceGridChildren(
                            dark,
                            l,
                            compact: metrics.isCompact,
                          ),
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: metrics.gridMainAxisExtent,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(child: SizedBox(height: bottomNavSpace)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Width-based sizing for the home dashboard.
class _HomeMetrics {
  static const maxContentWidth = 560.0;

  final double horizontalPadding;
  final bool isCompact;
  final bool isVeryCompact;
  final double gridMainAxisExtent;

  const _HomeMetrics({
    required this.horizontalPadding,
    required this.isCompact,
    required this.isVeryCompact,
    required this.gridMainAxisExtent,
  });

  factory _HomeMetrics.of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final veryCompact = width < 340;
    final compact = width < 380;

    return _HomeMetrics(
      horizontalPadding: veryCompact
          ? 10
          : compact
          ? 12
          : 16,
      isCompact: compact,
      isVeryCompact: veryCompact,
      gridMainAxisExtent: veryCompact
          ? 98
          : compact
          ? 104
          : 112,
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final int patientId;
  final String name;
  final String? age;
  final String? gender;
  final String cnic;
  final String? mrn;
  final VoidCallback? onEdit;
  final bool dark;
  final bool compact;

  const _ProfileHeaderCard({
    required this.patientId,
    required this.name,
    this.age,
    this.gender,
    required this.cnic,
    this.mrn,
    this.onEdit,
    required this.dark,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF1A2E24) : _HomeScreenState._headerGreen;
    final meta = [
      if (age != null && age!.isNotEmpty) age!,
      if (gender != null && gender!.isNotEmpty) gender!,
    ].join(' · ');
    final avatarRadius = compact ? 28.0 : 34.0;
    final nameSize = compact ? 19.0 : 22.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 20,
        compact ? 16 : 20,
        16,
        compact ? 14 : 18,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: bg.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 44),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PatientAvatar(
                  patientId: patientId,
                  name: name,
                  radius: avatarRadius,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  foregroundColor: Colors.white,
                  borderColor: Colors.white.withValues(alpha: 0.45),
                  borderWidth: 2,
                ),
                Gap(compact ? 10 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: nameSize,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const Gap(6),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 13 : 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                      ],
                      if (cnic.isNotEmpty) ...[
                        const Gap(8),
                        Text(
                          'CNIC: $cnic',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 12 : 13,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (mrn != null && mrn!.isNotEmpty) ...[
                        Gap(compact ? 8 : 12),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 10 : 12,
                            vertical: compact ? 5 : 6,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          child: Text(
                            'MRN: $mrn',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 11 : 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Material(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.edit_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;
  final bool dark;
  final bool compact;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
    required this.dark,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = dark ? scheme.surfaceContainerHighest : Colors.white;

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(14),
      elevation: dark ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 12 : 16,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outline.withValues(alpha: dark ? 0.4 : 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: compact ? 22 : 26),
              Gap(compact ? 8 : 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const Gap(2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: PunjabColors.primary,
            ),
            child: Text(
              action!,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
      ],
    );
  }
}

class _UpcomingVisitCard extends StatelessWidget {
  final Map<String, dynamic>? appointment;
  final VoidCallback onBook;
  final VoidCallback onJoinQueue;
  final bool dark;
  final bool compact;
  final bool veryCompact;

  const _UpcomingVisitCard({
    this.appointment,
    required this.onBook,
    required this.onJoinQueue,
    required this.dark,
    this.compact = false,
    this.veryCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardFill = dark ? scheme.surfaceContainerHighest : Colors.white;

    if (appointment == null) {
      return Container(
        padding: EdgeInsets.fromLTRB(
          compact ? 16 : 20,
          compact ? 16 : 20,
          compact ? 16 : 20,
          compact ? 18 : 22,
        ),
        decoration: BoxDecoration(
          color: cardFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: compact ? 30 : 34,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
            Gap(compact ? 6 : 8),
            Text(
              context.l10n.noUpcomingVisit,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Gap(4),
            Text(
              context.l10n.noUpcomingVisitMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Gap(14),
            FilledButton(
              onPressed: onBook,
              child: Text(context.l10n.bookVisit),
            ),
          ],
        ),
      );
    }

    final hospital = appointment!['hospitalName']?.toString().trim();
    final dept = appointment!['departmentName']?.toString().trim();
    final l = context.l10n;
    final hospitalLabel = (hospital != null && hospital.isNotEmpty)
        ? hospital
        : l.hospital;
    final deptLabel = (dept != null && dept.isNotEmpty) ? dept : l.department;
    final token = appointment!['tokenNumber']?.toString() ?? '—';
    final room =
        appointment!['room']?.toString() ??
        appointment!['roomNumber']?.toString();
    final dateStr =
        appointment!['appointmentDate'] ??
        appointment!['queueDate'] ??
        appointment!['addedToQueueAt'] ??
        appointment!['AddedToQueueAt'];
    var apptDate = DateTime.now();
    if (dateStr != null) {
      apptDate = DateTime.tryParse(dateStr.toString()) ?? apptDate;
    }
    final tokenDateLabel = AppDateFormat.formatDate(apptDate);
    final tokenTimeLabel = AppDateFormat.formatTime(apptDate);

    final iconBoxColor = dark
        ? scheme.primaryContainer.withValues(alpha: 0.35)
        : _HomeScreenState._timeBoxBlue;
    final tokenBoxColor = dark
        ? scheme.primaryContainer.withValues(alpha: 0.25)
        : _HomeScreenState._tokenBoxBlue;
    final footerColor = dark
        ? PunjabColors.primary.withValues(alpha: 0.15)
        : _HomeScreenState._visitFooterGreen;
    final iconBox = veryCompact
        ? 44.0
        : compact
        ? 48.0
        : 52.0;
    final hospitalIcon = veryCompact
        ? 24.0
        : compact
        ? 26.0
        : 28.0;
    final sectionPadding = veryCompact
        ? 10.0
        : compact
        ? 12.0
        : 14.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onJoinQueue,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: cardFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.45)),
            boxShadow: dark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  sectionPadding,
                  sectionPadding,
                  sectionPadding,
                  compact ? 10 : 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: iconBox,
                      height: iconBox,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: iconBoxColor,
                        borderRadius: BorderRadius.circular(compact ? 10 : 12),
                      ),
                      child: Icon(
                        Icons.local_hospital_rounded,
                        color: PunjabColors.primary,
                        size: hospitalIcon,
                      ),
                    ),
                    Gap(compact ? 10 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hospitalLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: veryCompact
                                  ? 14
                                  : compact
                                  ? 15
                                  : 16,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                              height: 1.25,
                            ),
                          ),
                          const Gap(4),
                          Text(
                            deptLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: veryCompact
                                  ? 12
                                  : compact
                                  ? 13
                                  : 14,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const Gap(6),
                          Row(
                            children: [
                              Icon(
                                Icons.event_rounded,
                                size: compact ? 13 : 14,
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.85,
                                ),
                              ),
                              const Gap(5),
                              Expanded(
                                child: Text(
                                  '$tokenDateLabel · $tokenTimeLabel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: compact ? 11 : 12,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!veryCompact)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 6 : 8,
                          vertical: compact ? 4 : 5,
                        ),
                        decoration: BoxDecoration(
                          color: PunjabColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: PunjabColors.danger.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: PunjabColors.danger,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const Gap(5),
                            Text(
                              l.liveQueue,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: PunjabColors.danger,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: sectionPadding),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 10 : 12,
                    vertical: compact ? 10 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: tokenBoxColor,
                    borderRadius: BorderRadius.circular(compact ? 10 : 12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.confirmation_number_outlined,
                        color: PunjabColors.primary,
                        size: veryCompact
                            ? 24
                            : compact
                            ? 26
                            : 28,
                      ),
                      Gap(compact ? 8 : 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.tokenNumber,
                              style: TextStyle(
                                fontSize: compact ? 10 : 11,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              token,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: veryCompact
                                    ? 15
                                    : compact
                                    ? 16
                                    : 17,
                                fontWeight: FontWeight.w900,
                                color: PunjabColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: onJoinQueue,
                        style: FilledButton.styleFrom(
                          backgroundColor: PunjabColors.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 12 : 16,
                            vertical: compact ? 8 : 10,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: TextStyle(
                            fontSize: compact ? 12 : 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(l.joinQueue),
                      ),
                    ],
                  ),
                ),
              ),
              Gap(compact ? 10 : 12),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: sectionPadding,
                  vertical: compact ? 8 : 10,
                ),
                decoration: BoxDecoration(
                  color: footerColor,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(13),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: compact ? 14 : 16,
                      color: PunjabColors.primary,
                    ),
                    Gap(compact ? 6 : 8),
                    Expanded(
                      child: Text(
                        room != null && room.isNotEmpty
                            ? l.reportToRoom(room)
                            : l.reportToReception,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          color: PunjabColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _GlanceBadgeStyle { neutral, success, alert, muted }

class _HealthGlanceHeader extends StatelessWidget {
  final String title;
  final bool dark;

  const _HealthGlanceHeader({required this.title, required this.dark});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 44,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: PunjabColors.primary,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: scheme.onSurface,
                  height: 1.2,
                ),
              ),
              const Gap(4),
              Row(
                children: [
                  Text(
                    l.last12MonthsSummary,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Gap(8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: dark
                          ? scheme.primaryContainer.withValues(alpha: 0.45)
                          : PunjabColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: PunjabColors.primary.withValues(
                          alpha: dark ? 0.35 : 0.15,
                        ),
                      ),
                    ),
                    child: Text(
                      l.rolling,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: PunjabColors.primary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlanceStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;
  final String? badge;
  final _GlanceBadgeStyle badgeStyle;
  final VoidCallback? onTap;
  final bool dark;
  final bool compact;

  const _GlanceStatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
    this.badge,
    this.badgeStyle = _GlanceBadgeStyle.neutral,
    this.onTap,
    required this.dark,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fill = dark ? scheme.surfaceContainerHighest : Colors.white;
    final iconBox = compact ? 28.0 : 32.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: dark
                  ? scheme.outline.withValues(alpha: 0.4)
                  : const Color(0xFFE2E8E4),
            ),
            boxShadow: dark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 8 : 10,
              compact ? 8 : 10,
              compact ? 8 : 10,
              compact ? 8 : 9,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: iconBox,
                      height: iconBox,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: compact ? 16 : 18,
                      ),
                    ),
                    const Spacer(),
                    if (badge != null)
                      _GlanceBadge(
                        label: badge!,
                        style: badgeStyle,
                        dark: dark,
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 22 : 24,
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                    height: 1,
                    letterSpacing: -0.4,
                  ),
                ),
                const Gap(1),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlanceBadge extends StatelessWidget {
  final String label;
  final _GlanceBadgeStyle style;
  final bool dark;

  const _GlanceBadge({
    required this.label,
    required this.style,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (style) {
      _GlanceBadgeStyle.success => (
        PunjabColors.primary.withValues(alpha: dark ? 0.2 : 0.1),
        PunjabColors.primary,
        PunjabColors.primary.withValues(alpha: 0.2),
      ),
      _GlanceBadgeStyle.alert => (
        PunjabColors.danger.withValues(alpha: dark ? 0.2 : 0.1),
        PunjabColors.danger,
        PunjabColors.danger.withValues(alpha: 0.25),
      ),
      _GlanceBadgeStyle.muted => (
        Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.12),
        Theme.of(context).colorScheme.onSurfaceVariant,
        Theme.of(context).colorScheme.outline.withValues(alpha: 0.35),
      ),
      _GlanceBadgeStyle.neutral => (
        Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
        Theme.of(context).colorScheme.onSurfaceVariant,
        Colors.transparent,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: border != Colors.transparent ? Border.all(color: border) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}
