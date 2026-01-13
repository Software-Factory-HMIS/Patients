import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import '../models/appointment_models.dart';
import '../utils/appointment_pdf_generator.dart';

class AppointmentSuccessScreen extends StatelessWidget {
  final AppointmentDetails appointment;

  const AppointmentSuccessScreen({
    super.key,
    required this.appointment,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Appointment Confirmed',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success Icon
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 80,
              ),
              const Gap(16),
              
              // Success Message
              Text(
                'Your appointment has been confirmed!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                textAlign: TextAlign.center,
              ),
              const Gap(32),

              // Token Number Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade700, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'TOKEN NUMBER',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                    ),
                    const Gap(12),
                    Text(
                      appointment.queueResponse.tokenNumber,
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                    ),
                  ],
                ),
              ),
              const Gap(24),

              // QR Code Card
              _buildQrCodeCard(context),

              const Gap(24),

              // Appointment Details Card
              _buildDetailsCard(
                context,
                'Appointment Details',
                [
                  _buildDetailRow(
                    context,
                    'Date',
                    '${appointment.appointmentDate.day}/${appointment.appointmentDate.month}/${appointment.appointmentDate.year}',
                  ),
                  _buildDetailRow(
                    context,
                    'Time',
                    '${appointment.appointmentDate.hour.toString().padLeft(2, '0')}:${appointment.appointmentDate.minute.toString().padLeft(2, '0')}',
                  ),
                  _buildDetailRow(
                    context,
                    'Queue ID',
                    appointment.queueResponse.queueId.toString(),
                  ),
                  if (appointment.queuePosition != null)
                    _buildDetailRow(
                      context,
                      'Queue Position',
                      appointment.queuePosition.toString(),
                    ),
                  if (appointment.estimatedWaitTime != null)
                    _buildDetailRow(
                      context,
                      'Estimated Wait Time',
                      appointment.estimatedWaitTime!,
                    ),
                ],
              ),
              const Gap(16),

              // Patient Information Card
              _buildDetailsCard(
                context,
                'Patient Information',
                [
                  _buildDetailRow(context, 'Name', appointment.patientName),
                  _buildDetailRow(context, 'MRN', appointment.patientMRN),
                ],
              ),
              const Gap(16),

              // Hospital Information Card
              _buildDetailsCard(
                context,
                'Hospital Information',
                [
                  _buildDetailRow(context, 'Name', appointment.hospital.name),
                  if (appointment.hospital.type != null)
                    _buildDetailRow(context, 'Type', appointment.hospital.type!),
                  _buildDetailRow(context, 'Location', appointment.hospital.location),
                ],
              ),
              const Gap(16),

              // Department Information Card
              _buildDetailsCard(
                context,
                'Department Information',
                [
                  _buildDetailRow(context, 'Name', appointment.department.name),
                  if (appointment.department.description != null &&
                      appointment.department.description!.isNotEmpty)
                    _buildDetailRow(
                      context,
                      'Description',
                      appointment.department.description!,
                    ),
                ],
              ),
              // Receipt Data from Print API (if available)
              if (appointment.receiptData != null && appointment.receiptData!.isNotEmpty) ...[
                const Gap(16),
                _buildDetailsCard(
                  context,
                  'Receipt Details',
                  _buildReceiptDetails(context, appointment.receiptData!),
                ),
              ],
              const Gap(32),

              // Download PDF Button
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await generateAndPrintAppointmentPDF(appointment);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error generating PDF: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('Download PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const Gap(16),

              // Back to Appointments Button
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Back to Appointments'),
              ),
              const Gap(16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
            ),
            const Gap(12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildReceiptDetails(BuildContext context, Map<String, dynamic> receiptData) {
    final details = <Widget>[];
    
    // Display all receipt data fields from the print API
    receiptData.forEach((key, value) {
      if (value != null) {
        String displayValue;
        if (value is Map) {
          displayValue = value.toString();
        } else if (value is List) {
          displayValue = value.join(', ');
        } else {
          displayValue = value.toString();
        }
        
        // Format key name (convert camelCase to Title Case)
        String formattedKey = key
            .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
            .trim();
        formattedKey = formattedKey[0].toUpperCase() + formattedKey.substring(1);
        
        details.add(
          _buildDetailRow(context, formattedKey, displayValue),
        );
      }
    });
    
    if (details.isEmpty) {
      details.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'No receipt details available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                ),
          ),
        ),
      );
    }
    
    return details;
  }

  // Generate QR code data from appointment details
  String _generateQrCodeData() {
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

  Widget _buildQrCodeCard(BuildContext context) {
    final qrData = _generateQrCodeData();
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Appointment QR Code',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
            ),
            const Gap(16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
            const Gap(12),
            Text(
              'Scan to view appointment details',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

