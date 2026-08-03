import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../services/ward_service.dart';

final _borderBlack = PdfColor.fromHex('#000000');
final _textBlack = PdfColor.fromHex('#000000');

/// Discharge slip print screen - matches discharge-slip.tsx layout.
class DischargeSlipPrintScreen extends StatefulWidget {
  final Map<String, dynamic> patient;
  final int admissionId;

  const DischargeSlipPrintScreen({
    Key? key,
    required this.patient,
    required this.admissionId,
  }) : super(key: key);

  @override
  State<DischargeSlipPrintScreen> createState() => _DischargeSlipPrintScreenState();
}

class _DischargeSlipPrintScreenState extends State<DischargeSlipPrintScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await WardService.getDischargeSlipData(widget.admissionId);
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
          _error = data == null ? 'Failed to load discharge slip data' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Error: $e';
        });
      }
    }
  }

  String _s(dynamic v) => (v?.toString() ?? '').trim();

  String _formatDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    return DateFormat('dd MMM yyyy').format(dt);
  }

  Future<void> _printReport() async {
    if (_data == null) return;
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
    final d = _data!;
    final hospital = d['hospitalInfo'] as Map<String, dynamic>? ?? {};
    final patientInfo = d['patientInfo'] as Map<String, dynamic>? ?? {};
    final admissionInfo = d['admissionInfo'] as Map<String, dynamic>? ?? {};
    final medicalInfo = d['medicalInfo'] as Map<String, dynamic>? ?? {};
    final treatmentInfo = d['treatmentInfo'] as Map<String, dynamic>? ?? {};

    final hospitalName = _s(hospital['name'] ?? hospital['Name']).isEmpty ? 'Hospital' : _s(hospital['name'] ?? hospital['Name']);
    final hospitalAddress = _s(hospital['address'] ?? hospital['Address']);
    final fullName = _s(patientInfo['fullName'] ?? patientInfo['FullName']);
    final relationName = _s(patientInfo['relationName'] ?? patientInfo['RelationName']);
    final age = _s(patientInfo['age'] ?? patientInfo['Age']);
    final gender = _s(patientInfo['gender'] ?? patientInfo['Gender']);
    final weight = _s(patientInfo['weight'] ?? patientInfo['Weight']);
    final regNo = _s(patientInfo['registrationNumber'] ?? patientInfo['RegistrationNumber']);
    final address = _s(patientInfo['address'] ?? patientInfo['Address']);
    final investigations = _s(admissionInfo['investigations'] ?? admissionInfo['Investigations']);
    final admDate = _formatDate(admissionInfo['admissionDate'] ?? admissionInfo['AdmissionDate']);
    final dischDate = _formatDate(admissionInfo['dischargeDate'] ?? admissionInfo['DischargeDate']);
    final statusAtDischarge = _s(medicalInfo['statusAtDischarge'] ?? medicalInfo['StatusAtDischarge']);
    final diagnosis = _s(admissionInfo['diagnosis'] ?? admissionInfo['Diagnosis']);
    final procedure = _s(admissionInfo['procedure'] ?? admissionInfo['Procedure']);
    final dischargeNotes = _s(treatmentInfo['dischargeNotes'] ?? treatmentInfo['DischargeNotes']);
    final followUp = _s(medicalInfo['followUp'] ?? medicalInfo['FollowUp']);

    pw.Widget _row(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 90,
                child: pw.Text('$label:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _textBlack)),
              ),
              pw.Expanded(
                child: pw.Container(
                  decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _borderBlack, width: 0.5))),
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(value.isEmpty ? ' ' : value, style: pw.TextStyle(fontSize: 10, color: _textBlack)),
                ),
              ),
            ],
          ),
        );

    pw.Widget _rowThird(String label, String value) => pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(right: 15, bottom: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('$label:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _textBlack)),
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 2),
                  decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _borderBlack, width: 0.5))),
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(value.isEmpty ? ' ' : value, style: pw.TextStyle(fontSize: 10, color: _textBlack)),
                ),
              ],
            ),
          ),
        );

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(25),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(hospitalName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    if (hospitalAddress.isNotEmpty) pw.Text(hospitalAddress, style: pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),
              pw.Center(
                child: pw.Text('DISCHARGE SLIP', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
              ),
              pw.SizedBox(height: 12),
              pw.Row(children: [_rowThird('Name', fullName), _rowThird('S/o, D/o, W/o', relationName)]),
              pw.Row(children: [
                _rowThird('Age/Sex', '$age / $gender'),
                _rowThird('Weight', weight.isEmpty ? '' : '$weight kg'),
                _rowThird('Reg. No', regNo),
              ]),
              pw.Row(
                children: [
                  pw.Expanded(child: _row('Address', address)),
                  pw.SizedBox(width: 20),
                  pw.Expanded(child: _row('Investigations', investigations)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(children: [
                _rowThird('Date Admission', admDate),
                _rowThird('Date of Discharge', dischDate),
                _rowThird('Status at Discharge', statusAtDischarge),
              ]),
              _row('Diagnosis', diagnosis),
              _row('Procedure', procedure),
              pw.SizedBox(height: 8),
              pw.Text('Notes:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 2, bottom: 6),
                decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _borderBlack, width: 0.5))),
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(dischargeNotes.isEmpty ? ' ' : dischargeNotes, style: pw.TextStyle(fontSize: 10)),
              ),
              _row('Follow up', followUp),
              pw.Spacer(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Medical Officer', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Discharge Slip')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Discharge Slip')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discharge Slip'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print',
            onPressed: _printReport,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: _printReport,
              icon: const Icon(Icons.print),
              label: const Text('Print'),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade800, width: 2),
                color: Colors.white,
              ),
              child: _buildPreviewContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewContent() {
    final d = _data!;
    final hospital = d['hospitalInfo'] as Map<String, dynamic>? ?? {};
    final patientInfo = d['patientInfo'] as Map<String, dynamic>? ?? {};
    final admissionInfo = d['admissionInfo'] as Map<String, dynamic>? ?? {};
    final medicalInfo = d['medicalInfo'] as Map<String, dynamic>? ?? {};
    final treatmentInfo = d['treatmentInfo'] as Map<String, dynamic>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Text(_s(hospital['name'] ?? hospital['Name']).isEmpty ? 'Hospital' : _s(hospital['name'] ?? hospital['Name']), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              if (_s(hospital['address'] ?? hospital['Address']).isNotEmpty) Text(_s(hospital['address'] ?? hospital['Address']), style: TextStyle(fontSize: 10, color: Colors.grey[700])),
            ],
          ),
        ),
        const SizedBox(height: 15),
        const Center(child: Text('DISCHARGE SLIP', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))),
        const SizedBox(height: 12),
        _previewRow('Name', _s(patientInfo['fullName'] ?? patientInfo['FullName'])),
        _previewRow('S/o, D/o, W/o', _s(patientInfo['relationName'] ?? patientInfo['RelationName'])),
        _previewRow('Age/Sex', '${_s(patientInfo['age'] ?? patientInfo['Age'])} / ${_s(patientInfo['gender'] ?? patientInfo['Gender'])}'),
        _previewRow('Weight', _s(patientInfo['weight'] ?? patientInfo['Weight']).isEmpty ? '' : '${_s(patientInfo['weight'] ?? patientInfo['Weight'])} kg'),
        _previewRow('Reg. No', _s(patientInfo['registrationNumber'] ?? patientInfo['RegistrationNumber'])),
        _previewRow('Address', _s(patientInfo['address'] ?? patientInfo['Address'])),
        _previewRow('Investigations', _s(admissionInfo['investigations'] ?? admissionInfo['Investigations'])),
        _previewRow('Date Admission', _formatDate(admissionInfo['admissionDate'] ?? admissionInfo['AdmissionDate'])),
        _previewRow('Date of Discharge', _formatDate(admissionInfo['dischargeDate'] ?? admissionInfo['DischargeDate'])),
        _previewRow('Status at Discharge', _s(medicalInfo['statusAtDischarge'] ?? medicalInfo['StatusAtDischarge'])),
        _previewRow('Diagnosis', _s(admissionInfo['diagnosis'] ?? admissionInfo['Diagnosis'])),
        _previewRow('Procedure', _s(admissionInfo['procedure'] ?? admissionInfo['Procedure'])),
        _previewRow('Notes', _s(treatmentInfo['dischargeNotes'] ?? treatmentInfo['DischargeNotes'])),
        _previewRow('Follow up', _s(medicalInfo['followUp'] ?? medicalInfo['FollowUp'])),
        const SizedBox(height: 20),
        const Align(alignment: Alignment.centerRight, child: Text('Medical Officer', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$label:', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
          Expanded(child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontSize: 10))),
        ],
      ),
    );
  }
}
