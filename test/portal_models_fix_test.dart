import 'package:flutter_test/flutter_test.dart';
import 'package:patients/models/portal_models.dart';

void main() {
  test('formats dosage without duplicating unit', () {
    expect(
      PrescriptionItem.fromJson({
        'medication': 'Metronidazole',
        'dosageAmount': '400mg',
        'dosageUnit': 'mg',
      }).dosage,
      '400mg',
    );
    expect(
      PrescriptionItem.fromJson({
        'medication': 'Metronidazole',
        'dosage': '400mg mg',
      }).dosage,
      '400mg',
    );
    expect(
      PrescriptionItem.fromJson({
        'medication': 'Paracetamol',
        'dosageAmount': '500',
        'dosageUnit': 'mg',
      }).dosage,
      '500 mg',
    );
  });

  test('radiology summary from reports matches list', () {
    final reports = [
      RadiologyReport(testName: 'XR', findings: 'normal'),
      RadiologyReport(testName: 'US', impression: 'ok'),
      RadiologyReport(testName: 'CT'),
    ];
    final summary = RadiologySummary.fromReports(reports);
    expect(summary.total, 3);
    expect(summary.finalReports, 2);
    expect(summary.pending, 1);
  });
}
