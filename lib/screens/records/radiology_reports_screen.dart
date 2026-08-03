import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../models/portal_models.dart';
import '../../services/patient_portal_service.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/health/health_report_ui.dart';
import '../../widgets/punjab_ui.dart';
import '../health/radiology_report_detail_screen.dart';

class RadiologyReportsScreen extends StatefulWidget {
  final int patientId;
  final String? patientName;
  final String? patientMrn;

  const RadiologyReportsScreen({
    super.key,
    required this.patientId,
    this.patientName,
    this.patientMrn,
  });

  @override
  State<RadiologyReportsScreen> createState() => _RadiologyReportsScreenState();
}

class _RadiologyReportsScreenState extends State<RadiologyReportsScreen> {
  final _portal = PatientPortalService();
  List<RadiologyReport> _reports = [];
  RadiologySummary _summary = const RadiologySummary();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _portal.loadRadiologyReports(widget.patientId),
        _portal.loadRadiologySummary(widget.patientId),
      ]);
      if (!mounted) return;
      setState(() {
        _reports = results[0] as List<RadiologyReport>;
        _summary = results[1] as RadiologySummary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _openDetail(RadiologyReport report) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RadiologyReportDetailScreen(
          report: report,
          patientName: widget.patientName,
          patientMrn: widget.patientMrn,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final theme = HealthReportTheme.radiology(context, dark: dark);

    return Scaffold(
      appBar: AppBar(title: const Text('Radiology Reports')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: PunjabColors.primary),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!),
                  const Gap(16),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : RefreshIndicator(
              color: PunjabColors.primary,
              onRefresh: _load,
              child: _reports.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 80),
                        EmptyStateWidget(
                          icon: Icons.radar_outlined,
                          title: 'No radiology reports yet',
                          message:
                              'Imaging reports will appear here after your scans.',
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        HealthSummaryPanel(
                          theme: theme,
                          icon: Icons.radar_rounded,
                          title: 'Radiology Reports',
                          subtitle: _summary.lastDate != null
                              ? 'Latest: ${_summary.lastDate}'
                              : null,
                          metrics: [
                            HealthMetricPill(
                              label: 'Total',
                              value: '${_summary.total}',
                              accent: theme.onAccent,
                              emphasize: true,
                            ),
                            HealthMetricPill(
                              label: 'Final',
                              value: '${_summary.finalReports}',
                              accent: PunjabColors.success,
                            ),
                            HealthMetricPill(
                              label: 'Pending',
                              value: '${_summary.pending}',
                              accent: PunjabColors.warning,
                            ),
                          ],
                        ),
                        const Gap(14),
                        ..._reports.map((report) {
                          final hasReport = report.hasReportText;
                          final preview = report.impression ?? report.findings;
                          return HealthReportListCard(
                            theme: theme,
                            icon: Icons.radar_rounded,
                            title: report.testName,
                            subtitle: report.radiologist != null
                                ? 'Radiologist: ${report.radiologist}'
                                : null,
                            preview: preview,
                            meta: [
                              if (report.orderNumber != null)
                                'Order ${report.orderNumber}',
                              if (report.displayDate != null)
                                report.displayDate!,
                            ].join(' · '),
                            statusLabel: hasReport ? 'Final' : 'Pending',
                            statusColor: hasReport
                                ? PunjabColors.success
                                : PunjabColors.warning,
                            onTap: () => _openDetail(report),
                          );
                        }),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
    );
  }
}
