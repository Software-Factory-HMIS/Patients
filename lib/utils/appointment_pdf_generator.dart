import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/appointment_models.dart';

Future<void> generateAndPrintAppointmentPDF(AppointmentDetails appointment) async {
  final pdf = await generateAppointmentPDF(appointment);
  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => pdf,
  );
}

Future<Uint8List> generateAppointmentPDF(AppointmentDetails appointment) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'APPOINTMENT CONFIRMATION',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Divider(thickness: 2, color: PdfColors.blue900),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // Token Number - Prominently displayed
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                border: pw.Border.all(color: PdfColors.blue900, width: 2),
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'TOKEN NUMBER',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      appointment.queueResponse.tokenNumber,
                      style: pw.TextStyle(
                        fontSize: 36,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(height: 30),

            // Patient Information Section
            pw.Text(
              'PATIENT INFORMATION',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Name:', appointment.patientName),
                  pw.SizedBox(height: 8),
                  _buildInfoRow('MRN:', appointment.patientMRN),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Appointment Details Section
            pw.Text(
              'APPOINTMENT DETAILS',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    'Date:',
                    '${appointment.appointmentDate.day}/${appointment.appointmentDate.month}/${appointment.appointmentDate.year}',
                  ),
                  pw.SizedBox(height: 8),
                  _buildInfoRow(
                    'Time:',
                    '${appointment.appointmentDate.hour.toString().padLeft(2, '0')}:${appointment.appointmentDate.minute.toString().padLeft(2, '0')}',
                  ),
                  pw.SizedBox(height: 8),
                  _buildInfoRow('Queue ID:', appointment.queueResponse.queueId.toString()),
                  if (appointment.queuePosition != null) ...[
                    pw.SizedBox(height: 8),
                    _buildInfoRow('Queue Position:', appointment.queuePosition.toString()),
                  ],
                  if (appointment.estimatedWaitTime != null) ...[
                    pw.SizedBox(height: 8),
                    _buildInfoRow('Estimated Wait Time:', appointment.estimatedWaitTime!),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Hospital Information Section
            pw.Text(
              'HOSPITAL INFORMATION',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Name:', appointment.hospital.name),
                  if (appointment.hospital.type != null) ...[
                    pw.SizedBox(height: 8),
                    _buildInfoRow('Type:', appointment.hospital.type!),
                  ],
                  pw.SizedBox(height: 8),
                  _buildInfoRow('Location:', appointment.hospital.location),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Department Information Section
            pw.Text(
              'DEPARTMENT INFORMATION',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Name:', appointment.department.name),
                  if (appointment.department.description != null &&
                      appointment.department.description!.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    _buildInfoRow('Description:', appointment.department.description!),
                  ],
                ],
              ),
            ),
            pw.Spacer(),

            // Footer
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'Generated on: ${DateTime.now().toString().substring(0, 19)}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'Please bring this confirmation to your appointment.',
                style: pw.TextStyle(
                  fontSize: 10,
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

