import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PatientFilePrintHelper {
  /// Uses pre-loaded encounter data from the screen (no API calls).
  static Future<void> printAllEncounters({
    required List<Map<String, dynamic>> encounterDataList,
    required Map<String, dynamic> patient,
  }) async {
    final pdf = await _buildEncounterPdf(encounterDataList, patient);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf);
  }

  static Future<Uint8List> _buildEncounterPdf(
    List<Map<String, dynamic>> encounterDataList,
    Map<String, dynamic> patient,
  ) async {
    final pdf = pw.Document();
    final patientName = patient['fullName'] ?? patient['name'] ?? 'Unknown';
    final mrn = patient['mrn']?.toString() ?? 'N/A';
    final gender = patient['gender']?.toString() ?? '';
    final age = patient['age']?.toString() ?? '';
    final contactNo = patient['contactNumber'] ?? patient['phone'] ?? patient['contactNo'] ?? '';

    final printDate = _formatDate(DateTime.now());

    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/punjab.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      logoImage = null;
    }

    final totalEncounters = encounterDataList.length;
    final pageFormat = PdfPageFormat.a4;
    const margin = pw.EdgeInsets.symmetric(horizontal: 36, vertical: 28);

    for (var i = 0; i < encounterDataList.length; i++) {
      final data = encounterDataList[i];
      final encounterNum = i + 1;
      final isFirst = i == 0;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: pageFormat,
          margin: margin,
          header: (pw.Context context) => _buildPageHeader(
            logoImage: logoImage,
            patientName: patientName,
            mrn: mrn,
            printDate: printDate,
            encounterNum: encounterNum,
            totalEncounters: totalEncounters,
          ),
          footer: (pw.Context context) => pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Center(
              child: pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount} • Encounter $encounterNum of $totalEncounters • Confidential',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ),
          ),
          build: (pw.Context context) {
            return [
              if (isFirst)
                _buildPatientSummary(
                  patientName: patientName,
                  mrn: mrn,
                  age: age,
                  gender: gender,
                  contactNo: contactNo.toString(),
                  totalEncounters: totalEncounters,
                ),
              if (isFirst) pw.SizedBox(height: 16),
              _buildEncounterSection(data, patient, encounterNum),
            ];
          },
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildPageHeader({
    required pw.ImageProvider? logoImage,
    required String patientName,
    required String mrn,
    required String printDate,
    required int encounterNum,
    required int totalEncounters,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blue700, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logoImage != null)
            pw.Image(logoImage, width: 44, height: 44, fit: pw.BoxFit.contain)
          else
            pw.Container(
              width: 44,
              height: 44,
              decoration: pw.BoxDecoration(
                color: PdfColors.blue100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Center(
                child: pw.Text(
                  'EMR',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                ),
              ),
            ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PATIENT MEDICAL RECORD',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Encounter $encounterNum of $totalEncounters • $printDate',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                patientName,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
                textAlign: pw.TextAlign.right,
              ),
              pw.Text(
                'MRN: $mrn',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                textAlign: pw.TextAlign.right,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPatientSummary({
    required String patientName,
    required String mrn,
    required String age,
    required String gender,
    required String contactNo,
    required int totalEncounters,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.blue200, width: 1),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                patientName,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                children: [
                  pw.Text('MRN: $mrn', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.SizedBox(width: 16),
                  pw.Text('Age: ${age}y', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  pw.SizedBox(width: 16),
                  pw.Text('Gender: $gender', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  if (contactNo.isNotEmpty) ...[
                    pw.SizedBox(width: 16),
                    pw.Text('Contact: $contactNo', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ],
              ),
            ],
          ),
          pw.Text(
            '$totalEncounters Encounter${totalEncounters != 1 ? 's' : ''}',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildEncounterSection(
    Map<String, dynamic> data,
    Map<String, dynamic> patient,
    int encounterNum,
  ) {
    final encounter = data['encounter'] as Map<String, dynamic>;
    final encounterId =
        encounter['encounterId'] ?? encounter['EncounterID'] ?? 'N/A';
    final encounterDate = encounter['encounterDate'] ??
        encounter['EncounterDate'] ??
        encounter['checkInTime'] ??
        encounter['CheckInTime'];
    final doctorName =
        encounter['doctorName'] ?? encounter['DoctorName'] ?? 'N/A';
    final encounterType =
        encounter['encounterType'] ?? encounter['EncounterType'] ?? '';
    final encounterStatus =
        encounter['encounterStatus'] ?? encounter['EncounterStatus'] ?? '';

    DateTime? parsedDate;
    if (encounterDate != null) {
      parsedDate = encounterDate is DateTime
          ? encounterDate
          : DateTime.tryParse(encounterDate.toString());
    }
    final dateStr = parsedDate != null ? _formatDate(parsedDate) : 'N/A';

    final vitals = data['vitals'] as List<dynamic>? ?? [];
    final complaints = data['complaints'] as List<dynamic>? ?? [];
    final symptoms = data['symptoms'] as List<dynamic>? ?? [];
    final diagnoses = data['diagnoses'] as List<dynamic>? ?? [];
    final labOrders = data['labOrders'] as List<dynamic>? ?? [];
    final radiologyOrders = data['radiologyOrders'] as List<dynamic>? ?? [];
    final medicines = data['medicines'] as List<dynamic>? ?? [];
    final clinicalNotes = (data['clinicalNotes']?.toString() ?? '').trim();

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 24),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Encounter header bar
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const pw.BoxDecoration(
              color: PdfColors.blue700,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(7),
                topRight: pw.Radius.circular(7),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Text(
                      'Encounter #$encounterNum',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Text(
                      dateStr,
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.white,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Text(
                      '• $doctorName',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.white),
                    ),
                    if (encounterType.isNotEmpty) ...[
                      pw.SizedBox(width: 8),
                      pw.Text(
                        '($encounterType)',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.white,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    encounterStatus.toString().toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Vitals table
                if (vitals.isNotEmpty) ...[
                  _buildVitalsTable(vitals),
                  pw.SizedBox(height: 14),
                ],
                // Two-column: Clinical | Tests
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(1),
                    1: pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        _sectionHeader('Clinical Information'),
                        _sectionHeader('Tests Advised'),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildListSection(
                                'Chief Complaints',
                                complaints,
                                (c) =>
                                    c['diagnosisName'] ??
                                    c['icd10Description'] ??
                                    c['ICD10Description'] ??
                                    'N/A',
                                PdfColors.orange700,
                              ),
                              _buildListSection(
                                'Symptoms',
                                symptoms,
                                (s) =>
                                    s['diagnosisName'] ??
                                    s['icd10Description'] ??
                                    s['ICD10Description'] ??
                                    'N/A',
                                PdfColors.red700,
                              ),
                              _buildListSection(
                                'Diagnosis',
                                diagnoses,
                                (d) {
                                  final name = d['diagnosisName'] ??
                                      d['icd10Description'] ??
                                      d['ICD10Description'] ??
                                      'N/A';
                                  final isConfirmed =
                                      d['isConfirmed'] ?? d['IsConfirmed'] ?? false;
                                  return isConfirmed ? '✓ $name' : '○ $name';
                                },
                                PdfColors.green700,
                              ),
                              if (clinicalNotes.isNotEmpty)
                                _buildNotesSection(clinicalNotes),
                            ],
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildLabSection(labOrders),
                              pw.SizedBox(height: 8),
                              _buildRadiologySection(radiologyOrders),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 14),
                // Medicines prescription table
                if (medicines.isNotEmpty) _buildMedicinesTable(medicines),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue700,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildVitalsTable(List<dynamic> vitals) {
    final v = vitals.first;
    final bp = _formatBP(v);
    final hr = _formatVital(v['pulse'] ?? v['Pulse'] ?? v['heartRate'] ?? v['HeartRate']);
    final temp = _formatVital(v['temperature'] ?? v['Temperature']);
    final rr = _formatVital(v['respiratoryRate'] ?? v['RespiratoryRate']);
    final spo2 = _formatVital(v['spo2'] ?? v['SPO2'] ?? v['oxygenSaturation']);
    final weight = _formatVital(v['weight'] ?? v['Weight']);
    final height = _formatVital(v['height'] ?? v['Height']);

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(5),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Vital Signs',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue700,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(1),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(1),
              5: pw.FlexColumnWidth(1),
              6: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _th('BP'),
                  _th('HR'),
                  _th('Temp'),
                  _th('RR'),
                  _th('SpO2'),
                  _th('Weight'),
                  _th('Height'),
                ],
              ),
              pw.TableRow(
                children: [
                  _td(bp),
                  _td(hr),
                  _td(temp),
                  _td(rr),
                  _td(spo2),
                  _td(weight),
                  _td(height),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _th(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(
          t,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
          textAlign: pw.TextAlign.center,
        ),
      );
  static pw.Widget _td(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(
          t,
          style: const pw.TextStyle(fontSize: 9),
          textAlign: pw.TextAlign.center,
        ),
      );

  static String _formatBP(dynamic v) {
    final sys = v['bpSystolic'] ?? v['BPSystolic'] ?? v['bloodPressureSystolic'];
    final dia = v['bpDiastolic'] ?? v['BPDiastolic'] ?? v['bloodPressureDiastolic'];
    if (sys != null && dia != null) return '${_formatVital(sys)}/${_formatVital(dia)}';
    return _formatVital(v['bloodPressure'] ?? v['BloodPressure']);
  }

  static String _formatVital(dynamic val) {
    if (val == null) return '-';
    final s = val.toString().trim();
    return s.isEmpty ? '-' : s;
  }

  static pw.Widget _buildListSection(
    String title,
    List<dynamic> items,
    String Function(dynamic) formatter,
    PdfColor color,
  ) {
    if (items.isEmpty) return pw.SizedBox.shrink();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '$title:',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color),
        ),
        pw.SizedBox(height: 4),
        ...items.map((item) => pw.Padding(
              padding: const pw.EdgeInsets.only(left: 6, bottom: 2),
              child: pw.Text(
                '• ${formatter(item)}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            )),
        pw.SizedBox(height: 6),
      ],
    );
  }

  static pw.Widget _buildNotesSection(String notes) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Clinical Notes:',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.indigo700,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.indigo50,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColors.indigo200, width: 0.5),
          ),
          child: pw.Text(
            notes,
            style: const pw.TextStyle(fontSize: 8, height: 1.3),
          ),
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  static pw.Widget _buildLabSection(List<dynamic> labOrders) {
    if (labOrders.isEmpty) return pw.SizedBox.shrink();
    final hasResults = labOrders.any((l) =>
        (l['resultValue'] ?? l['resultId']) != null ||
        ((l['resultValue'] ?? '').toString().isNotEmpty));

    if (hasResults) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Laboratory Results:',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(0.8),
              3: pw.FlexColumnWidth(1.5),
              4: pw.FlexColumnWidth(0.8),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Test', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Result', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Unit', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Ref Range', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text('Status', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              ...labOrders.where((l) {
                final rv = l['resultValue'] ?? l['resultId'];
                return rv != null || (l['resultValue']?.toString() ?? '').isNotEmpty;
              }).take(15).map((lab) {
                final name = (lab['testName'] ?? lab['packageName'] ?? 'N/A').toString();
                final result = (lab['resultValue'] ?? '').toString();
                final units = (lab['units'] ?? '').toString();
                final ref = (lab['referenceRange'] ?? '').toString();
                final status = (lab['resultStatus'] ?? lab['abnormalFlags'] ?? 'N/A').toString();
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(name, style: const pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(result, style: const pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(units, style: const pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(ref, style: const pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(status, style: const pw.TextStyle(fontSize: 8)),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Lab Tests:',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
        ),
        pw.SizedBox(height: 4),
        pw.Wrap(
          spacing: 4,
          runSpacing: 2,
          children: labOrders.map((lab) {
            final name = (lab['testName'] ?? lab['packageName'] ?? 'N/A').toString();
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(3),
                border: pw.Border.all(color: PdfColors.blue200, width: 0.5),
              ),
              child: pw.Text(name, style: const pw.TextStyle(fontSize: 7)),
            );
          }).toList(),
        ),
      ],
    );
  }

  static pw.Widget _buildRadiologySection(List<dynamic> radiologyOrders) {
    if (radiologyOrders.isEmpty) return pw.SizedBox.shrink();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Radiology:',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.orange700),
        ),
        pw.SizedBox(height: 4),
        ...radiologyOrders.take(10).map((r) {
          final name = (r['testName'] ?? r['clinicalDisplayName'] ?? 'N/A').toString();
          return pw.Padding(
            padding: const pw.EdgeInsets.only(left: 6, bottom: 2),
            child: pw.Text('• $name', style: const pw.TextStyle(fontSize: 8)),
          );
        }),
      ],
    );
  }

  static pw.Widget _buildMedicinesTable(List<dynamic> medicines) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.purple50,
        borderRadius: pw.BorderRadius.circular(5),
        border: pw.Border.all(color: PdfColors.purple200, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Prescribed Medications',
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.purple700,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.5),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1.2),
              3: pw.FlexColumnWidth(0.6),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.purple100),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Medicine',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Dosage',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Frequency',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      'Duration',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
              ),
              ...medicines.map((m) {
                final name = (m['medicineName'] ?? m['MedicineName'] ?? m['medicine']?['name'] ?? 'N/A').toString();
                final dosage = (m['dosageAmount'] ?? m['dosageValue'] ?? m['dosage'] ?? '').toString();
                final unit = (m['dosageUnit'] ?? m['DosageUnit'] ?? '').toString();
                final freq = (m['frequency'] ?? m['Frequency'] ?? m['instructions'] ?? '').toString();
                final dur = (m['duration'] ?? m['durationValue'] ?? m['DurationValue'] ?? '').toString();
                final durUnit = (m['durationUnit'] ?? m['DurationUnit'] ?? '').toString();
                final discontinued = m['discontinuedDate'] ?? m['DiscontinuedDate'];
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        discontinued != null ? '$name (D/C)' : name,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontStyle: discontinued != null ? pw.FontStyle.italic : pw.FontStyle.normal,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        dosage.isNotEmpty ? '$dosage $unit' : '-',
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        freq.isNotEmpty ? freq : '-',
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        dur.isNotEmpty ? '$dur $durUnit' : '-',
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime d) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
