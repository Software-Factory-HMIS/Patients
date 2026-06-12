import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/appointment_models.dart';
import '../utils/app_date_format.dart';
import '../utils/appointment_pdf_generator.dart';
import '../utils/app_snackbar.dart';
import '../utils/emr_api_client.dart';
import '../widgets/punjab_ui.dart';

class AppointmentSuccessScreen extends StatefulWidget {
  final AppointmentDetails appointment;
  final VoidCallback? onGoHome;

  const AppointmentSuccessScreen({
    super.key,
    required this.appointment,
    this.onGoHome,
  });

  @override
  State<AppointmentSuccessScreen> createState() => _AppointmentSuccessScreenState();
}

class _AppointmentSuccessScreenState extends State<AppointmentSuccessScreen> {
  static const _pageBg = Color(0xFFF4F1F8);
  static const _instructionBg = Color(0xFFE8EFFA);

  late String _token;
  late DateTime _appointmentDate;
  Map<String, dynamic>? _liveReceipt;
  bool _refreshingLive = true;

  @override
  void initState() {
    super.initState();
    _token = widget.appointment.queueResponse.tokenNumber;
    _appointmentDate = widget.appointment.appointmentDate;
    _refreshLiveDetails();
  }

  Future<void> _refreshLiveDetails() async {
    try {
      final api = EmrApiClient();
      final receipt = await api.printQueueReceipt(
        queueId: widget.appointment.queueResponse.queueId,
      );

      if (!mounted) return;

      final liveToken = _pickReceiptField(receipt, const [
        'tokenNumber',
        'TokenNumber',
        'token',
        'Token',
        'queueToken',
        'QueueToken',
      ]);

      final liveDate = _parseReceiptDate(receipt);

      setState(() {
        _liveReceipt = receipt.isNotEmpty ? receipt : widget.appointment.receiptData;
        if (liveToken != null && liveToken.isNotEmpty) {
          _token = liveToken;
        }
        if (liveDate != null) {
          _appointmentDate = liveDate;
        }
        _refreshingLive = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liveReceipt = widget.appointment.receiptData;
        _refreshingLive = false;
      });
    }
  }

  AppointmentDetails get _pdfAppointment {
    return AppointmentDetails(
      queueResponse: QueueResponse(
        queueId: widget.appointment.queueResponse.queueId,
        tokenNumber: _token,
      ),
      hospital: widget.appointment.hospital,
      department: widget.appointment.department,
      patientName: widget.appointment.patientName,
      patientMRN: widget.appointment.patientMRN,
      appointmentDate: _appointmentDate,
      receiptData: _liveReceipt ?? widget.appointment.receiptData,
    );
  }

  String _generateQrCodeData() {
    final qrData = {
      'queueId': widget.appointment.queueResponse.queueId,
      'tokenNumber': _token,
      'patientName': widget.appointment.patientName,
      'patientMRN': widget.appointment.patientMRN,
      'hospitalName': widget.appointment.hospital.name,
      'departmentName': widget.appointment.department.name,
      'appointmentDate': _appointmentDate.toIso8601String(),
      'hospitalId': widget.appointment.hospital.hospitalID,
      'departmentId': widget.appointment.department.departmentID,
    };
    return json.encode(qrData);
  }

  void _handleBackToHome() {
    Navigator.of(context).pop();
    widget.onGoHome?.call();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? Theme.of(context).colorScheme.surface : _pageBg;
    final dateLabel = AppDateFormat.formatDate(_appointmentDate);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            if (!dark) ..._confetti(),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Punjab Health',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: dark ? Theme.of(context).colorScheme.onSurface : PunjabColors.primaryDark,
                    ),
                  ),
                  const Gap(28),
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: PunjabColors.primaryDark,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
                    ),
                  ),
                  const Gap(18),
                  Text(
                    'Appointment Confirmed!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: dark ? Theme.of(context).colorScheme.onSurface : PunjabColors.primaryDark,
                      height: 1.15,
                    ),
                  ),
                  const Gap(8),
                  Text(
                    'Your visit has been successfully scheduled.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Gap(28),
                  _QueueTokenCard(
                    token: _token,
                    refreshing: _refreshingLive,
                    dark: dark,
                  ),
                  const Gap(20),
                  _QrCheckInCard(
                    qrData: _generateQrCodeData(),
                    dark: dark,
                  ),
                  const Gap(20),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.35,
                    children: [
                      _DetailTile(
                        icon: Icons.local_hospital_rounded,
                        label: 'Hospital',
                        value: widget.appointment.hospital.name,
                        dark: dark,
                      ),
                      _DetailTile(
                        icon: Icons.medical_services_rounded,
                        label: 'Department',
                        value: widget.appointment.department.name,
                        dark: dark,
                      ),
                      _DetailTile(
                        icon: Icons.calendar_month_rounded,
                        label: 'Date',
                        value: dateLabel,
                        dark: dark,
                      ),
                      _DetailTile(
                        icon: Icons.person_rounded,
                        label: 'Patient',
                        value: widget.appointment.patientName,
                        subValue: 'MRN: ${widget.appointment.patientMRN}',
                        dark: dark,
                      ),
                    ],
                  ),
                  const Gap(20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: dark
                          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35)
                          : _instructionBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: dark ? Theme.of(context).colorScheme.primary : PunjabColors.primaryDark,
                          size: 22,
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pre-visit Instruction',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: dark
                                      ? Theme.of(context).colorScheme.onSurface
                                      : PunjabColors.primaryDark,
                                ),
                              ),
                              const Gap(4),
                              Text(
                                'Please arrive 15 minutes before your time slot with your original CNIC.',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: dark
                                      ? Theme.of(context).colorScheme.onSurfaceVariant
                                      : PunjabColors.primaryDark.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(24),
                  PunjabPrimaryButton(
                    label: 'Download PDF Receipt',
                    icon: Icons.download_rounded,
                    onPressed: () async {
                      try {
                        await generateAndPrintAppointmentPDF(_pdfAppointment);
                      } catch (e) {
                        if (context.mounted) {
                          AppSnackBar.showError(context, 'Error generating PDF: $e');
                        }
                      }
                    },
                  ),
                  const Gap(12),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: _handleBackToHome,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PunjabColors.primaryDark,
                        side: const BorderSide(color: PunjabColors.primaryDark, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('Back to Home'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _confetti() {
    const pieces = [
      (left: 24.0, top: 420.0, color: Color(0xFF3B82F6), size: 10.0),
      (left: 48.0, top: 520.0, color: Color(0xFF22C55E), size: 8.0),
      (left: 310.0, top: 390.0, color: Color(0xFF22C55E), size: 9.0),
      (left: 330.0, top: 500.0, color: Color(0xFF3B82F6), size: 7.0),
    ];

    return pieces
        .map(
          (p) => Positioned(
            left: p.left,
            top: p.top,
            child: Transform.rotate(
              angle: 0.4,
              child: Container(
                width: p.size,
                height: p.size,
                decoration: BoxDecoration(
                  color: p.color.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  static String? _pickReceiptField(Map<String, dynamic> receipt, List<String> keys) {
    for (final key in keys) {
      final value = receipt[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    final nested = receipt['data'];
    if (nested is Map<String, dynamic>) {
      return _pickReceiptField(nested, keys);
    }
    return null;
  }

  static DateTime? _parseReceiptDate(Map<String, dynamic> receipt) {
    for (final key in const [
      'appointmentDate',
      'AppointmentDate',
      'queueDate',
      'QueueDate',
      'addedToQueueAt',
      'AddedToQueueAt',
      'visitDate',
      'VisitDate',
    ]) {
      final raw = receipt[key];
      if (raw is String) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}

class _QueueTokenCard extends StatelessWidget {
  final String token;
  final bool refreshing;
  final bool dark;

  const _QueueTokenCard({
    required this.token,
    required this.refreshing,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final cardFill = dark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.35)),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: PunjabColors.primaryDark),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(
                            'QUEUE TOKEN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: PunjabColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: PunjabColors.primary.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: PunjabColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const Gap(6),
                                const Text(
                                  'LIVE QUEUE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: PunjabColors.primaryDark,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Gap(18),
                      if (refreshing)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          ),
                        )
                      else
                        Text(
                          token,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: PunjabColors.primaryDark,
                            letterSpacing: 0.5,
                            height: 1.1,
                          ),
                        ),
                      const Gap(16),
                      Text(
                        'Please present this token at the reception desk.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrCheckInCard extends StatelessWidget {
  final String qrData;
  final bool dark;

  const _QrCheckInCard({required this.qrData, required this.dark});

  @override
  Widget build(BuildContext context) {
    final cardFill = dark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: cardFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.35)),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PunjabColors.primaryDark, width: 2.5),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  PunjabColors.primary.withValues(alpha: 0.12),
                  PunjabColors.primary.withValues(alpha: 0.04),
                ],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 168,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
          ),
          const Gap(16),
          const Text(
            'Scan at Reception',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: PunjabColors.primaryDark,
            ),
          ),
          const Gap(4),
          Text(
            'Digital Check-in Enabled',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subValue;
  final bool dark;

  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.subValue,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final cardFill = dark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: PunjabColors.primaryDark, size: 22),
          const Spacer(),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap(2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: PunjabColors.primaryDark,
              height: 1.2,
            ),
          ),
          if (subValue != null) ...[
            const Gap(2),
            Text(
              subValue!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
