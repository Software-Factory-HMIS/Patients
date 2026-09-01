import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/portal_models.dart';

Future<void> downloadLabReportPdf({
  required LabReport report,
  String? patientName,
  String? patientMrn,
}) async {
  final bytes = await _buildLabPdf(
    report,
    patientName: patientName,
    patientMrn: patientMrn,
  );
  await Printing.layoutPdf(
    onLayout: (_) async => bytes,
    name: _safeFileName('Lab-${report.test}'),
  );
}

Future<void> downloadRadiologyReportPdf({
  required RadiologyReport report,
  String? patientName,
  String? patientMrn,
}) async {
  final bytes = await _buildRadiologyPdf(
    report,
    patientName: patientName,
    patientMrn: patientMrn,
  );
  await Printing.layoutPdf(
    onLayout: (_) async => bytes,
    name: _safeFileName('Radiology-${report.testName}'),
  );
}

String _safeFileName(String raw) {
  return raw
      .replaceAll(RegExp(r'[^\w\-.]+'), '_')
      .replaceAll(RegExp(r'_+'), '_');
}

Future<Uint8List> _buildLabPdf(
  LabReport report, {
  String? patientName,
  String? patientMrn,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        _header('Laboratory Report', patientName, patientMrn),
        pw.SizedBox(height: 20),
        _row('Test', report.test),
        if (report.date != null) _row('Date', report.date!),
        if (report.result != null) _row('Result', report.result!),
        if (report.normalRange != null)
          _row('Normal Range', report.normalRange!),
        if (report.status != null) _row('Status', report.status!),
        if (report.abnormalFlags != null && report.abnormalFlags!.isNotEmpty)
          _row('Flags', report.abnormalFlags!),
        if (report.orderedBy != null) _row('Ordered By', report.orderedBy!),
        if (report.sampleId != null)
          _row('Sample ID', report.sampleId.toString()),
        if (report.resultId != null)
          _row('Result ID', report.resultId.toString()),
        pw.SizedBox(height: 24),
        pw.Text(
          'Generated from My Health Record',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ],
    ),
  );
  return doc.save();
}

Future<Uint8List> _buildRadiologyPdf(
  RadiologyReport report, {
  String? patientName,
  String? patientMrn,
}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        _header('Radiology Report', patientName, patientMrn),
        pw.SizedBox(height: 20),
        _row('Study', report.testName),
        if (report.orderNumber != null)
          _row('Order Number', report.orderNumber!),
        if (report.displayDate != null)
          _row('Report Date', report.displayDate!),
        if (report.orderDate != null && report.orderDate != report.displayDate)
          _row('Order Date', report.orderDate!),
        if (report.radiologist != null)
          _row('Radiologist', report.radiologist!),
        if (report.findings != null && report.findings!.trim().isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            'Findings',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(report.findings!, style: const pw.TextStyle(fontSize: 11)),
        ],
        if (report.impression != null &&
            report.impression!.trim().isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            'Impression',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(report.impression!, style: const pw.TextStyle(fontSize: 11)),
        ],
        if (report.recommendations != null &&
            report.recommendations!.trim().isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            'Recommendations',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            report.recommendations!,
            style: const pw.TextStyle(fontSize: 11),
          ),
        ],
        pw.SizedBox(height: 24),
        pw.Text(
          'Generated from My Health Record',
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ],
    ),
  );
  return doc.save();
}

pw.Widget _header(String title, String? patientName, String? patientMrn) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'Punjab Health',
        style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        title,
        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
      ),
      if (patientName != null && patientName.isNotEmpty) ...[
        pw.SizedBox(height: 8),
        pw.Text(
          'Patient: $patientName',
          style: const pw.TextStyle(fontSize: 11),
        ),
      ],
      if (patientMrn != null && patientMrn.isNotEmpty)
        pw.Text('MRN: $patientMrn', style: const pw.TextStyle(fontSize: 11)),
      pw.Divider(thickness: 1),
    ],
  );
}

pw.Widget _row(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 10),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 110,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
        ),
        pw.Expanded(
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
        ),
      ],
    ),
  );
}
