import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../../models/portal_models.dart';
import '../../services/patient_portal_service.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/health/health_report_ui.dart';
import '../../widgets/punjab_ui.dart';
import '../health/lab_report_detail_screen.dart';

class LabReportsScreen extends StatefulWidget {
  final int patientId;
  final String? patientName;
  final String? patientMrn;

  const LabReportsScreen({
    super.key,
    required this.patientId,
    this.patientName,
    this.patientMrn,
  });

  @override
  State<LabReportsScreen> createState() => _LabReportsScreenState();
}

class _LabReportsScreenState extends State<LabReportsScreen> {
  final _portal = PatientPortalService();
  List<LabReport> _reports = [];
  List<LabReport> _filtered = [];
  LabResultsSummary _summary = const LabResultsSummary();
  bool _loading = true;
  String? _error;
  String _statusFilter = 'All';

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
        _portal.loadLabReports(widget.patientId),
        _portal.loadLabSummary(widget.patientId),
      ]);
      if (!mounted) return;
      setState(() {
        _reports = results[0] as List<LabReport>;
        _summary = results[1] as LabResultsSummary;
        _applyFilter();
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

  void _applyFilter() {
    if (_statusFilter == 'All') {
      _filtered = List.of(_reports);
      return;
    }
    _filtered = _reports.where((r) {
      final label = labStatusLabel(r).toLowerCase();
      final filter = _statusFilter.toLowerCase();
      if (filter == 'pending') return !r.hasResult;
      return label.contains(filter);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final theme = HealthReportTheme.lab(context, dark: dark);

    return Scaffold(
      appBar: AppBar(title: const Text('Lab Results')),
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
                          icon: Icons.science_outlined,
                          title: 'No lab results yet',
                          message:
                              'Your lab test results will appear here after your visits.',
                        ),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        HealthSummaryPanel(
                          theme: theme,
                          icon: Icons.biotech_rounded,
                          title: 'Laboratory Results',
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
                              label: 'Normal',
                              value: '${_summary.normal}',
                              accent: PunjabColors.success,
                            ),
                            HealthMetricPill(
                              label: 'Elevated',
                              value: '${_summary.elevated}',
                              accent: PunjabColors.warning,
                            ),
                            HealthMetricPill(
                              label: 'Critical',
                              value: '${_summary.critical}',
                              accent: PunjabColors.danger,
                            ),
                          ],
                        ),
                        const Gap(14),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children:
                                [
                                  'All',
                                  'Normal',
                                  'Abnormal',
                                  'Critical',
                                  'Pending',
                                ].map((filter) {
                                  final selected = _statusFilter == filter;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: Text(filter),
                                      selected: selected,
                                      showCheckmark: false,
                                      onSelected: (_) {
                                        setState(() {
                                          _statusFilter = filter;
                                          _applyFilter();
                                        });
                                      },
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                        const Gap(12),
                        ..._filtered.map((report) {
                          final statusColor = labStatusColor(report);
                          return HealthReportListCard(
                            theme: theme,
                            icon: Icons.science_rounded,
                            title: report.test,
                            subtitle: report.result != null
                                ? 'Result: ${report.result}'
                                : null,
                            preview: report.normalRange != null
                                ? 'Reference: ${report.normalRange}'
                                : null,
                            meta: formatReportDate(report.date),
                            statusLabel: labStatusLabel(report),
                            statusColor: statusColor,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => LabReportDetailScreen(
                                  report: report,
                                  patientName: widget.patientName,
                                  patientMrn: widget.patientMrn,
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
    );
  }
}
