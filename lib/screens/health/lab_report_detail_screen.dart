import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../models/portal_models.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/medical_report_pdf_generator.dart';
import '../../widgets/health/health_report_ui.dart';
import '../../widgets/punjab_ui.dart';

class LabReportDetailScreen extends StatelessWidget {
  final LabReport report;
  final String? patientName;
  final String? patientMrn;

  const LabReportDetailScreen({
    super.key,
    required this.report,
    this.patientName,
    this.patientMrn,
  });

  Future<void> _download(BuildContext context) async {
    try {
      await downloadLabReportPdf(
        report: report,
        patientName: patientName,
        patientMrn: patientMrn,
      );
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.showError(context, 'Could not generate PDF: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final theme = HealthReportTheme.lab(context, dark: dark);
    final statusColor = labStatusColor(report);
    final meta = <HealthMetaItem>[
      if (report.date != null)
        HealthMetaItem(label: 'Sample Date', value: report.date!),
      if (report.orderedBy != null)
        HealthMetaItem(label: 'Ordered By', value: report.orderedBy!),
      if (report.normalRange != null)
        HealthMetaItem(label: 'Reference Range', value: report.normalRange!),
      if (report.abnormalFlags != null && report.abnormalFlags!.isNotEmpty)
        HealthMetaItem(label: 'Flags', value: report.abnormalFlags!),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Lab Report')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          HealthDetailHero(
            theme: theme,
            icon: Icons.biotech_rounded,
            title: report.test,
            subtitle: patientName,
            statusLabel: labStatusLabel(report),
            statusColor: statusColor,
            metaItems: meta,
          ),
          if (report.result != null) ...[
            const Gap(14),
            HealthDetailSection(
              theme: theme,
              title: 'Result Value',
              body: report.result!,
              highlight: report.isCritical,
            ),
          ],
          if (report.status != null) ...[
            const Gap(12),
            HealthDetailSection(
              theme: theme,
              title: 'Interpretation',
              body: report.status!,
              highlight:
                  report.isCritical ||
                  (report.status ?? '').toLowerCase().contains('abnormal'),
            ),
          ],
          if (!report.hasResult) ...[
            const Gap(14),
            HealthPendingBanner(
              theme: theme,
              message:
                  'Result is pending. Check back once the laboratory has validated and published your report.',
            ),
          ],
          const Gap(24),
          PunjabPrimaryButton(
            label: 'Download PDF Report',
            icon: Icons.download_rounded,
            onPressed: report.hasResult ? () => _download(context) : null,
          ),
        ],
      ),
    );
  }
}
