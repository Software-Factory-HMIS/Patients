import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../models/portal_models.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/medical_report_pdf_generator.dart';
import '../../widgets/health/health_report_ui.dart';
import '../../widgets/punjab_ui.dart';

class RadiologyReportDetailScreen extends StatelessWidget {
  final RadiologyReport report;
  final String? patientName;
  final String? patientMrn;

  const RadiologyReportDetailScreen({
    super.key,
    required this.report,
    this.patientName,
    this.patientMrn,
  });

  Future<void> _download(BuildContext context) async {
    try {
      await downloadRadiologyReportPdf(
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
    final theme = HealthReportTheme.radiology(context, dark: dark);
    final isFinal = report.hasReportText;
    final meta = <HealthMetaItem>[
      if (report.displayDate != null) HealthMetaItem(label: 'Report Date', value: report.displayDate!),
      if (report.orderNumber != null) HealthMetaItem(label: 'Order No.', value: report.orderNumber!),
      if (report.radiologist != null) HealthMetaItem(label: 'Radiologist', value: report.radiologist!),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Radiology Report')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          HealthDetailHero(
            theme: theme,
            icon: Icons.radar_rounded,
            title: report.testName,
            subtitle: patientName,
            statusLabel: isFinal ? 'Final' : 'Pending',
            statusColor: isFinal ? PunjabColors.success : PunjabColors.warning,
            metaItems: meta,
          ),
          if (report.findings != null && report.findings!.trim().isNotEmpty) ...[
            const Gap(14),
            HealthDetailSection(theme: theme, title: 'Findings', body: report.findings!),
          ],
          if (report.impression != null && report.impression!.trim().isNotEmpty) ...[
            const Gap(12),
            HealthDetailSection(theme: theme, title: 'Impression', body: report.impression!),
          ],
          if (report.recommendations != null && report.recommendations!.trim().isNotEmpty) ...[
            const Gap(12),
            HealthDetailSection(theme: theme, title: 'Recommendations', body: report.recommendations!),
          ],
          if (!isFinal) ...[
            const Gap(14),
            HealthPendingBanner(
              theme: theme,
              message:
                  'Your imaging report is not finalized yet. You can download the complete report once the radiologist signs it.',
            ),
          ],
          const Gap(24),
          PunjabPrimaryButton(
            label: 'Download PDF Report',
            icon: Icons.download_rounded,
            onPressed: isFinal ? () => _download(context) : null,
          ),
        ],
      ),
    );
  }
}
