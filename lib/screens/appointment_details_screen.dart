import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';

class AppointmentDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> appointment;

  const AppointmentDetailsScreen({
    super.key,
    required this.appointment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Extract appointment data
    final hospitalName = appointment['hospitalName'] ?? 
                         appointment['HospitalName'] ?? 
                         appointment['hospital']?['name'] ??
                         'Hospital';
    final departmentName = appointment['departmentName'] ?? 
                           appointment['DepartmentName'] ?? 
                           appointment['department']?['name'] ??
                           'Department';
    final tokenNumber = appointment['tokenNumber'] ?? 
                       appointment['TokenNumber'] ??
                       'N/A';
    final queueId = appointment['queueId'] ?? 
                   appointment['QueueID'] ??
                   appointment['queueId'];
    
    // Parse date
    DateTime? appointmentDate;
    final queueDate = appointment['queueDate'] ?? 
                     appointment['QueueDate'] ?? 
                     appointment['createdAt'] ??
                     appointment['CreatedAt'] ??
                     appointment['appointmentDate'];
    
    if (queueDate != null) {
      try {
        if (queueDate is DateTime) {
          appointmentDate = queueDate;
        } else if (queueDate is String) {
          appointmentDate = DateTime.parse(queueDate);
        }
      } catch (e) {
        // Date parsing failed, use current date as fallback
        appointmentDate = DateTime.now();
      }
    } else {
      appointmentDate = DateTime.now();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Appointment Details',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Token Number Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.3),
                  border: Border.all(
                    color: colorScheme.primary,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'TOKEN NUMBER',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const Gap(12),
                    Text(
                      tokenNumber.toString(),
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(24),

              // QR Code Card
              if (queueId != null && tokenNumber != null)
                _buildQrCodeCard(context, queueId, tokenNumber, hospitalName, departmentName, appointmentDate!),

              const Gap(24),

              // Appointment Details Card
              _buildDetailsCard(
                context,
                colorScheme,
                theme,
                'Appointment Details',
                [
                  if (appointmentDate != null) ...[
                    _buildDetailRow(
                      context,
                      theme,
                      'Date',
                      '${appointmentDate!.day}/${appointmentDate!.month}/${appointmentDate!.year}',
                    ),
                    _buildDetailRow(
                      context,
                      theme,
                      'Time',
                      '${appointmentDate!.hour.toString().padLeft(2, '0')}:${appointmentDate!.minute.toString().padLeft(2, '0')}',
                    ),
                  ],
                  if (queueId != null)
                    _buildDetailRow(
                      context,
                      theme,
                      'Queue ID',
                      queueId.toString(),
                    ),
                  _buildDetailRow(
                    context,
                    theme,
                    'Token Number',
                    tokenNumber.toString(),
                  ),
                ],
              ),
              const Gap(16),

              // Hospital Information Card
              _buildDetailsCard(
                context,
                colorScheme,
                theme,
                'Hospital Information',
                [
                  _buildDetailRow(
                    context,
                    theme,
                    'Name',
                    hospitalName.toString(),
                  ),
                ],
              ),
              const Gap(16),

              // Department Information Card
              _buildDetailsCard(
                context,
                colorScheme,
                theme,
                'Department Information',
                [
                  _buildDetailRow(
                    context,
                    theme,
                    'Name',
                    departmentName.toString(),
                  ),
                ],
              ),
              const Gap(32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard(
    BuildContext context,
    ColorScheme colorScheme,
    ThemeData theme,
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
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const Gap(12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCodeCard(
    BuildContext context,
    dynamic queueId,
    dynamic tokenNumber,
    String hospitalName,
    String departmentName,
    DateTime appointmentDate,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Generate QR code data
    final qrData = {
      'queueId': queueId,
      'tokenNumber': tokenNumber.toString(),
      'hospitalName': hospitalName,
      'departmentName': departmentName,
      'appointmentDate': appointmentDate.toIso8601String(),
    };
    final qrDataString = json.encode(qrData);
    
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
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
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
                data: qrDataString,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
            const Gap(12),
            Text(
              'Scan to view appointment details',
              style: theme.textTheme.bodySmall?.copyWith(
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
