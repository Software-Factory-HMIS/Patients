import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart' as material;
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/appointment_models.dart';

Future<void> generateAndPrintAppointmentPDF(AppointmentDetails appointment) async {
  final pdf = await generateAppointmentPDF(appointment);
  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => pdf,
  );
}

// Generate QR code data from appointment details
String _generateQrCodeData(AppointmentDetails appointment) {
  final qrData = {
    'queueId': appointment.queueResponse.queueId,
    'tokenNumber': appointment.queueResponse.tokenNumber,
    'patientName': appointment.patientName,
    'patientMRN': appointment.patientMRN,
    'hospitalName': appointment.hospital.name,
    'departmentName': appointment.department.name,
    'appointmentDate': appointment.appointmentDate.toIso8601String(),
    'hospitalId': appointment.hospital.hospitalID,
    'departmentId': appointment.department.departmentID,
  };
  return json.encode(qrData);
}

// Convert QR code to PDF image
Future<pw.Image> _generateQrCodeImage(String data, {double size = 120.0}) async {
  final qrValidationResult = QrValidator.validate(
    data: data,
    version: QrVersions.auto,
    errorCorrectionLevel: QrErrorCorrectLevel.M,
  );

  if (qrValidationResult.status == QrValidationStatus.valid) {
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      color: material.Colors.black,
      emptyColor: material.Colors.white,
    );

    final picRecorder = ui.PictureRecorder();
    final canvas = ui.Canvas(picRecorder);
    
    painter.paint(canvas, ui.Size(size, size));
    final picture = picRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    return pw.Image(pw.MemoryImage(pngBytes));
  } else {
    // Fallback: return a placeholder image or throw error
    throw Exception('Invalid QR code data');
  }
}

Future<Uint8List> generateAppointmentPDF(AppointmentDetails appointment) async {
  final pdf = pw.Document();
  
  // Generate QR code image (smaller size for compact layout)
  final qrData = _generateQrCodeData(appointment);
  final qrImage = await _generateQrCodeImage(qrData, size: 100.0);

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(25), // Reduced margins
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Compact Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'APPOINTMENT CONFIRMATION',
                    style: pw.TextStyle(
                      fontSize: 18, // Reduced from 24
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 5), // Reduced from 10
                  pw.Divider(thickness: 1.5, color: PdfColors.blue900),
                ],
              ),
            ),
            pw.SizedBox(height: 12), // Reduced from 30

            // Token and QR Code in a Row
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Token Number - Left side
                pw.Expanded(
                  flex: 2,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(12), // Reduced from 20
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      border: pw.Border.all(color: PdfColors.blue900, width: 1.5),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Center(
                      child: pw.Column(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          pw.Text(
                            'TOKEN NUMBER',
                            style: pw.TextStyle(
                              fontSize: 11, // Reduced from 14
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                          pw.SizedBox(height: 6), // Reduced from 10
                          pw.Text(
                            appointment.queueResponse.tokenNumber,
                            style: pw.TextStyle(
                              fontSize: 28, // Reduced from 36
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                // QR Code - Right side
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        'QR CODE',
                        style: pw.TextStyle(
                          fontSize: 10, // Reduced from 14
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(8), // Reduced from 15
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: qrImage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12), // Reduced from 30

            // Information sections in two columns
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left column
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Patient Information
                      pw.Text(
                        'PATIENT INFO',
                        style: pw.TextStyle(
                          fontSize: 12, // Reduced from 16
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 5), // Reduced from 10
                      pw.Container(
                        padding: const pw.EdgeInsets.all(10), // Reduced from 15
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildInfoRowCompact('Name:', appointment.patientName),
                            pw.SizedBox(height: 5), // Reduced from 8
                            _buildInfoRowCompact('MRN:', appointment.patientMRN),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 10), // Reduced from 20

                      // Appointment Details
                      pw.Text(
                        'APPOINTMENT',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildInfoRowCompact(
                              'Date:',
                              '${appointment.appointmentDate.day}/${appointment.appointmentDate.month}/${appointment.appointmentDate.year}',
                            ),
                            pw.SizedBox(height: 5),
                            _buildInfoRowCompact(
                              'Time:',
                              '${appointment.appointmentDate.hour.toString().padLeft(2, '0')}:${appointment.appointmentDate.minute.toString().padLeft(2, '0')}',
                            ),
                            pw.SizedBox(height: 5),
                            _buildInfoRowCompact('Queue ID:', appointment.queueResponse.queueId.toString()),
                            if (appointment.queuePosition != null) ...[
                              pw.SizedBox(height: 5),
                              _buildInfoRowCompact('Position:', appointment.queuePosition.toString()),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 10),
                // Right column
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Hospital Information
                      pw.Text(
                        'HOSPITAL INFO',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildInfoRowCompact('Name:', appointment.hospital.name),
                            if (appointment.hospital.type != null) ...[
                              pw.SizedBox(height: 5),
                              _buildInfoRowCompact('Type:', appointment.hospital.type!),
                            ],
                            pw.SizedBox(height: 5),
                            _buildInfoRowCompact('Location:', appointment.hospital.location),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 10),

                      // Department Information
                      pw.Text(
                        'DEPARTMENT',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildInfoRowCompact('Name:', appointment.department.name),
                            if (appointment.department.description != null &&
                                appointment.department.description!.isNotEmpty) ...[
                              pw.SizedBox(height: 5),
                              _buildInfoRowCompact('Desc:', appointment.department.description!),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),

            // Compact Footer
            pw.Divider(thickness: 0.5, color: PdfColors.grey400),
            pw.SizedBox(height: 5),
            pw.Center(
              child: pw.Text(
                'Please bring this confirmation to your appointment.',
                style: pw.TextStyle(
                  fontSize: 9, // Reduced from 10
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey600,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  return pdf.save();
}

pw.Widget _buildInfoRow(String label, String value) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        width: 120,
        child: pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      pw.Expanded(
        child: pw.Text(
          value,
          style: const pw.TextStyle(fontSize: 12),
        ),
      ),
    ],
  );
}

pw.Widget _buildInfoRowCompact(String label, String value) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        width: 70, // Reduced from 120
        child: pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10, // Reduced from 12
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      pw.Expanded(
        child: pw.Text(
          value,
          style: const pw.TextStyle(fontSize: 10), // Reduced from 12
        ),
      ),
    ],
  );
}

