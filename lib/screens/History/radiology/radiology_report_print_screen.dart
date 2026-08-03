import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../services/user_session_service.dart';
import '../../../services/system_info_service.dart';

// Frontend RadiologyPDFReportGenerator colors (PDF)
final _headerBlue = PdfColor.fromHex('#2c5aa0');
final _labelGrey = PdfColor.fromHex('#555555');
final _textBlack = PdfColor.fromHex('#000000');
final _borderGrey = PdfColor.fromHex('#dddddd');
final _mutedGrey = PdfColor.fromHex('#666666');
final _criticalRed = PdfColor.fromHex('#c62828');
final _criticalBg = PdfColor.fromHex('#ffebee');

// Flutter equivalents for screen display
const _headerBlueFlutter = Color(0xFF2c5aa0);
const _labelGreyFlutter = Color(0xFF555555);
const _borderGreyFlutter = Color(0xFFdddddd);
const _mutedGreyFlutter = Color(0xFF666666);
const _criticalRedFlutter = Color(0xFFc62828);
const _criticalBgFlutter = Color(0xFFffebee);
const _secondaryBlueFlutter = Color(0xFF3668a3);

/// Screen to display and print a single radiology report (matches RadiologyPDFReportGenerator).
class RadiologyReportPrintScreen extends StatefulWidget {
  final Map<String, dynamic> patient;
  final Map<String, dynamic> radiologyOrder;

  const RadiologyReportPrintScreen({
    Key? key,
    required this.patient,
    required this.radiologyOrder,
  }) : super(key: key);

  @override
  State<RadiologyReportPrintScreen> createState() => _RadiologyReportPrintScreenState();
}

class _RadiologyReportPrintScreenState extends State<RadiologyReportPrintScreen> {
  String _hospitalName = 'Hospital';
  String _hospitalAddress = 'Address, City, State';
  String _hospitalPhone = '+92-XXX-XXXXXXX';
  String _hospitalEmail = 'radiology@hospital.gov.pk';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHospital();
  }

  Future<void> _loadHospital() async {
    try {
      final hospitalId = await UserSessionService.getHospitalId();
      if (hospitalId != null) {
        final info = await SystemInfoService.getHospitalInfo(hospitalId);
        if (info != null && mounted) {
          final addr = info['address'] ?? info['Address'] ?? '';
          final city = info['city'] ?? info['City'] ?? '';
          final state = info['state'] ?? info['State'] ?? '';
          final parts = [addr, city, state].where((e) => e.toString().trim().isNotEmpty);
          setState(() {
            _hospitalName = info['name']?.toString() ?? info['Name']?.toString() ?? 'Hospital';
            _hospitalAddress = parts.isEmpty ? 'Address, City, State' : parts.join(', ');
            _hospitalPhone = info['phone']?.toString() ?? info['Phone'] ?? '+92-XXX-XXXXXXX';
            _hospitalEmail = info['email']?.toString() ?? info['Email'] ?? 'radiology@hospital.gov.pk';
            _loading = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() { _loading = false; });
  }

  String _s(dynamic v) => (v?.toString() ?? '').trim();

  bool get _hasFindingsOrImpression {
    final findings = _s(widget.radiologyOrder['finalFindings'] ?? widget.radiologyOrder['findings'] ?? widget.radiologyOrder['preliminaryFindings']);
    final impression = _s(widget.radiologyOrder['impression']);
    return findings.isNotEmpty || impression.isNotEmpty;
  }

  Future<void> _printReport() async {
    if (!_hasFindingsOrImpression) return;
    try {
      final pdf = await _buildPDF();
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<Uint8List> _buildPDF() async {
    final pdf = pw.Document();
    final pageFormat = PdfPageFormat.a4;
    final r = widget.radiologyOrder;
    final p = widget.patient;

    final pn = _s(p['fullName'] ?? p['name'] ?? p['FullName'] ?? p['Name']);
    final patientName = pn.isEmpty ? 'Unknown' : pn;
    final mrn = _s(p['mrn'] ?? p['MRN'] ?? p['patientId']).isEmpty ? 'N/A' : _s(p['mrn'] ?? p['MRN'] ?? p['patientId']);
    final age = _s(p['age'] ?? p['Age']);
    final gender = _s(p['gender'] ?? p['Gender']);
    final contact = _s(p['contactNumber'] ?? p['phone'] ?? p['ContactNumber']).isEmpty ? 'N/A' : _s(p['contactNumber'] ?? p['phone'] ?? p['ContactNumber']);

    final testName = _s(r['testName'] ?? r['clinicalDisplayName'] ?? r['procedure']);
    final orderDate = r['orderDate'] ?? r['date'] ?? r['OrderDate'];
    final orderNumber = _s(r['orderNumber'] ?? r['orderId']).isEmpty ? 'ORD-${r['orderDetailId'] ?? r['orderDetailID'] ?? ''}' : _s(r['orderNumber'] ?? r['orderId']);
    final modalityName = _s(r['modalityName'] ?? r['modality']);
    final priority = _s(r['priority'] ?? r['Priority']).isEmpty ? 'ROUTINE' : _s(r['priority'] ?? r['Priority']);
    final reportStatus = _s(r['reportStatus'] ?? r['status']);
    final reportId = r['reportId'] ?? r['reportID'];
    final reportNumber = reportId != null ? 'RAD-$reportId' : 'RAD-N/A';

    final findings = _s(r['finalFindings'] ?? r['findings'] ?? r['preliminaryFindings']);
    final impression = _s(r['impression']);
    final recommendations = _s(r['recommendations']);
    final technique = _s(r['technique']);
    final comparison = _s(r['comparison']);
    final clinicalHistory = _s(r['clinicalHistory']);
    final criticalFindings = _s(r['criticalFindings']);
    final radiologistName = _s(r['radiologist_Name'] ?? r['radiologistName'] ?? r['radiologist']).isEmpty ? 'Unknown' : _s(r['radiologist_Name'] ?? r['radiologistName'] ?? r['radiologist']);
    final reportDate = r['finalReportDate'] ?? r['preliminaryReportDate'] ?? r['orderDate'] ?? DateTime.now().toIso8601String();
    final reportDateFormatted = DateFormat('MM/dd/yyyy HH:mm:ss').format(DateTime.tryParse(reportDate.toString()) ?? DateTime.now());
    final examDateFormatted = DateFormat('MM/dd/yyyy').format(DateTime.tryParse(orderDate.toString()) ?? DateTime.now());

    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/punjab.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    pw.Widget _sectionHeader(String title) => pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 3),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _headerBlue, width: 1)),
      ),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _headerBlue)),
    );

    pw.Widget _contentSection(String title, String content) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderGrey),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: pw.BoxDecoration(color: _headerBlue, borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(2))),
            child: pw.Text(title.toUpperCase(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text(content, style: pw.TextStyle(fontSize: 9, color: _textBlack)),
          ),
        ],
      ),
    );

    pw.Widget _infoRow(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(width: 110, child: pw.Text('$label:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _labelGrey))),
          pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 9, color: _textBlack))),
        ],
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.symmetric(horizontal: 25, vertical: 20),
        build: (pw.Context context) {
          final children = <pw.Widget>[
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _headerBlue, width: 2)),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logoImage != null) pw.Image(logoImage!, width: 60, height: 60, fit: pw.BoxFit.contain),
                      if (logoImage != null) pw.SizedBox(width: 15),
                      pw.Expanded(
                        child: pw.Column(
                          children: [
                            pw.Text(_hospitalName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _headerBlue), textAlign: pw.TextAlign.center),
                            pw.SizedBox(height: 2),
                            pw.Text(_hospitalAddress, style: pw.TextStyle(fontSize: 8, color: _labelGrey), textAlign: pw.TextAlign.center),
                            pw.Text('Phone: $_hospitalPhone | Email: $_hospitalEmail', style: pw.TextStyle(fontSize: 8, color: _labelGrey), textAlign: pw.TextAlign.center),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    decoration: pw.BoxDecoration(color: _headerBlue),
                    child: pw.Text('RADIOLOGY DEPARTMENT', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.center),
                  ),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#3668a3')),
                    child: pw.Text('DIAGNOSTIC IMAGING REPORT', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white), textAlign: pw.TextAlign.center),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text('Report Date: $reportDateFormatted', style: pw.TextStyle(fontSize: 9, color: _mutedGrey)),
                  pw.Text('Report Number: $reportNumber', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _textBlack)),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _borderGrey),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _sectionHeader('Patient Information'),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _infoRow('Patient Name', patientName),
                          _infoRow('MRN', mrn),
                        ],
                      )),
                      pw.Expanded(child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _infoRow('Contact No', contact),
                          _infoRow('Age/Gender', '$age Years / $gender'),
                        ],
                      )),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _borderGrey),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _sectionHeader('Study Information'),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _infoRow('Test Name', testName),
                          _infoRow('Order Number', orderNumber),
                          _infoRow('Examination Date', examDateFormatted),
                        ],
                      )),
                      pw.Expanded(child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _infoRow('Modality', modalityName),
                          _infoRow('Priority', priority),
                          _infoRow('Status', reportStatus),
                        ],
                      )),
                    ],
                  ),
                ],
              ),
            ),
          ];

          if (clinicalHistory.isNotEmpty) {
            children.add(_contentSection('Clinical History', clinicalHistory));
          }
          if (technique.isNotEmpty) {
            children.add(_contentSection('Technique', technique));
          }
          if (comparison.isNotEmpty) {
            children.add(_contentSection('Comparison', comparison));
          }
          if (findings.isNotEmpty) {
            children.add(_contentSection('Findings', findings));
          }
          if (impression.isNotEmpty) {
            children.add(_contentSection('Impression', impression));
          }
          if (recommendations.isNotEmpty) {
            children.add(_contentSection('Recommendations', recommendations));
          }
          if (criticalFindings.isNotEmpty) {
            children.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _criticalRed, width: 2),
                  borderRadius: pw.BorderRadius.circular(3),
                  color: _criticalBg,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: pw.BoxDecoration(color: _criticalRed, borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(2))),
                      child: pw.Text('🔴 CRITICAL FINDINGS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(criticalFindings, style: pw.TextStyle(fontSize: 9, color: _criticalRed, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          }

          children.add(pw.Container(
            margin: const pw.EdgeInsets.only(top: 12),
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _borderGrey)),
            ),
            child: pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text('Reported By:', style: pw.TextStyle(fontSize: 8, color: _mutedGrey)),
                        pw.Container(
                          margin: const pw.EdgeInsets.only(top: 15),
                          padding: const pw.EdgeInsets.only(top: 2),
                          decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _textBlack))),
                          child: pw.Text(radiologistName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Text(DateFormat('MMM dd, yyyy HH:mm').format(DateTime.tryParse(reportDate.toString()) ?? DateTime.now()), style: pw.TextStyle(fontSize: 8, color: _mutedGrey)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Text('*** End of Report ***', style: pw.TextStyle(fontSize: 8, color: _mutedGrey), textAlign: pw.TextAlign.center),
                pw.Text('This is a computer-generated report and does not require a signature.', style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic, color: _mutedGrey), textAlign: pw.TextAlign.center),
              ],
            ),
          ));

          return children;
        },
      ),
    );

    return pdf.save();
  }

  Widget _buildReportPreview() {
    final r = widget.radiologyOrder;
    final p = widget.patient;

    final pn = _s(p['fullName'] ?? p['name'] ?? p['FullName'] ?? p['Name']);
    final patientName = pn.isEmpty ? 'Unknown' : pn;
    final mrn = _s(p['mrn'] ?? p['MRN'] ?? p['patientId']).isEmpty ? 'N/A' : _s(p['mrn'] ?? p['MRN'] ?? p['patientId']);
    final age = _s(p['age'] ?? p['Age']);
    final gender = _s(p['gender'] ?? p['Gender']);
    final contact = _s(p['contactNumber'] ?? p['phone'] ?? p['ContactNumber']).isEmpty ? 'N/A' : _s(p['contactNumber'] ?? p['phone'] ?? p['ContactNumber']);

    final testName = _s(r['testName'] ?? r['clinicalDisplayName'] ?? r['procedure']);
    final orderDate = r['orderDate'] ?? r['date'] ?? r['OrderDate'];
    final orderNumber = _s(r['orderNumber'] ?? r['orderId']).isEmpty ? 'ORD-${r['orderDetailId'] ?? r['orderDetailID'] ?? ''}' : _s(r['orderNumber'] ?? r['orderId']);
    final modalityName = _s(r['modalityName'] ?? r['modality']);
    final priority = _s(r['priority'] ?? r['Priority']).isEmpty ? 'ROUTINE' : _s(r['priority'] ?? r['Priority']);
    final reportStatus = _s(r['reportStatus'] ?? r['status']);
    final reportId = r['reportId'] ?? r['reportID'];
    final reportNumber = reportId != null ? 'RAD-$reportId' : 'RAD-N/A';

    final findings = _s(r['finalFindings'] ?? r['findings'] ?? r['preliminaryFindings']);
    final impression = _s(r['impression']);
    final recommendations = _s(r['recommendations']);
    final technique = _s(r['technique']);
    final comparison = _s(r['comparison']);
    final clinicalHistory = _s(r['clinicalHistory']);
    final criticalFindings = _s(r['criticalFindings']);
    final radiologistName = _s(r['radiologist_Name'] ?? r['radiologistName'] ?? r['radiologist']).isEmpty ? 'Unknown' : _s(r['radiologist_Name'] ?? r['radiologistName'] ?? r['radiologist']);
    final reportDate = r['finalReportDate'] ?? r['preliminaryReportDate'] ?? r['orderDate'] ?? DateTime.now().toIso8601String();
    final reportDateFormatted = DateFormat('MM/dd/yyyy HH:mm:ss').format(DateTime.tryParse(reportDate.toString()) ?? DateTime.now());
    final examDateFormatted = DateFormat('MM/dd/yyyy').format(DateTime.tryParse(orderDate.toString()) ?? DateTime.now());

    Widget infoRow(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text('$label:', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _labelGreyFlutter))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 9, color: Colors.black))),
        ],
      ),
    );

    Widget sectionBox(String title, List<Widget> children) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border.all(color: _borderGreyFlutter),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 3),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _headerBlueFlutter, width: 1)),
            ),
            child: Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _headerBlueFlutter)),
          ),
          const SizedBox(height: 5),
          ...children,
        ],
      ),
    );

    Widget contentSection(String title, String content) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: _borderGreyFlutter),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: const BoxDecoration(
              color: _headerBlueFlutter,
              borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
            ),
            child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          Padding(
            padding: const EdgeInsets.all(5),
            child: Text(content, style: const TextStyle(fontSize: 9, color: Colors.black)),
          ),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _headerBlueFlutter, width: 2)),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/punjab.png', width: 60, height: 60, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox(width: 60, height: 60)),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          children: [
                            Text(_hospitalName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _headerBlueFlutter), textAlign: TextAlign.center),
                            const SizedBox(height: 2),
                            Text(_hospitalAddress, style: const TextStyle(fontSize: 8, color: _labelGreyFlutter), textAlign: TextAlign.center),
                            Text('Phone: $_hospitalPhone | Email: $_hospitalEmail', style: const TextStyle(fontSize: 8, color: _labelGreyFlutter), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    color: _headerBlueFlutter,
                    child: const Text('RADIOLOGY DEPARTMENT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    color: _secondaryBlueFlutter,
                    child: const Text('DIAGNOSTIC IMAGING REPORT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 5),
                  Text('Report Date: $reportDateFormatted', style: const TextStyle(fontSize: 9, color: _mutedGreyFlutter)),
                  Text('Report Number: $reportNumber', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            sectionBox('Patient Information', [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [infoRow('Patient Name', patientName), infoRow('MRN', mrn)])),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [infoRow('Contact No', contact), infoRow('Age/Gender', '$age Years / $gender')])),
                ],
              ),
            ]),
            sectionBox('Study Information', [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [infoRow('Test Name', testName), infoRow('Order Number', orderNumber), infoRow('Examination Date', examDateFormatted)])),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [infoRow('Modality', modalityName), infoRow('Priority', priority), infoRow('Status', reportStatus)])),
                ],
              ),
            ]),
            if (clinicalHistory.isNotEmpty) contentSection('Clinical History', clinicalHistory),
            if (technique.isNotEmpty) contentSection('Technique', technique),
            if (comparison.isNotEmpty) contentSection('Comparison', comparison),
            if (findings.isNotEmpty) contentSection('Findings', findings),
            if (impression.isNotEmpty) contentSection('Impression', impression),
            if (recommendations.isNotEmpty) contentSection('Recommendations', recommendations),
            if (criticalFindings.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: _criticalRedFlutter, width: 2),
                  borderRadius: BorderRadius.circular(3),
                  color: _criticalBgFlutter,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: const BoxDecoration(color: _criticalRedFlutter, borderRadius: BorderRadius.vertical(top: Radius.circular(2))),
                      child: const Text('🔴 CRITICAL FINDINGS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(5),
                      child: Text(criticalFindings, style: const TextStyle(fontSize: 9, color: _criticalRedFlutter, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.only(top: 6),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: _borderGreyFlutter))),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('Reported By:', style: TextStyle(fontSize: 8, color: _mutedGreyFlutter)),
                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.only(top: 2),
                            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.black))),
                            child: Text(radiologistName, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                          Text(DateFormat('MMM dd, yyyy HH:mm').format(DateTime.tryParse(reportDate.toString()) ?? DateTime.now()), style: const TextStyle(fontSize: 8, color: _mutedGreyFlutter)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('*** End of Report ***', style: TextStyle(fontSize: 8, color: _mutedGreyFlutter), textAlign: TextAlign.center),
                  const Text('This is a computer-generated report and does not require a signature.', style: TextStyle(fontSize: 7, fontStyle: FontStyle.italic, color: _mutedGreyFlutter), textAlign: TextAlign.center),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Radiology Report')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final r = widget.radiologyOrder;
    final testName = _s(r['testName'] ?? r['clinicalDisplayName'] ?? r['procedure']);

    return Scaffold(
      appBar: AppBar(
        title: Text(testName.isEmpty ? 'Radiology Report' : testName),
        actions: [
          if (_hasFindingsOrImpression)
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: _printReport,
              tooltip: 'Print report',
            ),
        ],
      ),
      body: _buildReportPreview(),
    );
  }
}
