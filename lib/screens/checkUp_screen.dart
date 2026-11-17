import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../utils/app_date_format.dart';
import '../utils/app_localizations_ext.dart';
import '../utils/patient_vital_check.dart';
import '../utils/visit_detail.dart';

/// Read-only hospital visit. The patient cannot change the record.
class CheckUpScreen extends StatelessWidget {
  final Map<String, dynamic> patient;
  final VisitDetail? visit;

  const CheckUpScreen({super.key, required this.patient, this.visit});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final detail = visit;
    return Scaffold(
      appBar: AppBar(title: Text(l.visitDetails)),
      body: detail == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l.openVisitFromList,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  detail.title.isEmpty ? l.visitDetails : detail.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const Gap(4),
                if (detail.when != null &&
                    DateTime.tryParse(detail.when!) != null)
                  Text(AppDateFormat.formatDateTime(
                    DateTime.parse(detail.when!),
                  )),
                if (detail.doctor.isNotEmpty) Text(detail.doctor),
                const Gap(16),
                _VitalSection(
                  title: l.vitals,
                  patient: patient,
                  rows: detail.vitalRows,
                  empty: l.nothingRecorded,
                ),
                _Section(title: l.complaints, lines: detail.complaints),
                _Section(title: l.symptoms, lines: detail.symptoms),
                _Section(title: l.diagnosis, lines: detail.diagnoses),
                _LabSection(title: l.labs, lines: detail.labLines),
                _Section(title: l.radiology, lines: detail.radiology),
                _Section(title: l.medicines, lines: detail.medicines),
                _Section(title: l.clinicalNotes, lines: detail.notes),
              ],
            ),
    );
  }
}

class _VitalSection extends StatelessWidget {
  final String title;
  final Map<String, dynamic> patient;
  final List<Map<String, dynamic>> rows;
  final String empty;

  const _VitalSection({
    required this.title,
    required this.patient,
    required this.rows,
    required this.empty,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final chips = rows
        .expand((row) => PatientVitalCheck.chipsFromRow(patient, row, l))
        .toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const Gap(6),
            if (chips.isEmpty)
              Text(empty, style: TextStyle(color: scheme.onSurfaceVariant))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final chip in chips)
                    Text(
                      '${chip.label} ${chip.value}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: chip.outOfRange ? scheme.error : scheme.onSurface,
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

class _LabSection extends StatelessWidget {
  final String title;
  final List<VisitLabLine> lines;

  const _LabSection({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const Gap(6),
            if (lines.isEmpty)
              Text(
                context.l10n.nothingRecorded,
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            else
              ...lines.map((line) {
                if (line.value.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(line.name),
                  );
                }
                final unit = line.units.isEmpty ? '' : ' ${line.units}';
                final band = line.range.isEmpty ? '' : ' (${line.range})';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${line.name}: '),
                        TextSpan(
                          text: line.value,
                          style: TextStyle(
                            color: line.abnormal ? scheme.error : scheme.onSurface,
                            fontWeight: line.abnormal
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: '$unit$band'),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<String> lines;

  const _Section({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const Gap(6),
            if (lines.isEmpty)
              Text(
                context.l10n.nothingRecorded,
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            else
              ...lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
