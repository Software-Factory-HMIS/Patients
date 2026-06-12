import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../shell/patient_shell.dart';
import '../utils/app_date_format.dart';
import '../utils/user_storage.dart';
import '../utils/app_snackbar.dart';
import '../services/inactivity_service.dart';

class PatientSelectionScreen extends StatefulWidget {
  final List<Map<String, dynamic>> patients;
  final String phoneNumber;

  const PatientSelectionScreen({
    super.key,
    required this.patients,
    required this.phoneNumber,
  });

  @override
  State<PatientSelectionScreen> createState() => _PatientSelectionScreenState();
}

class _PatientSelectionScreenState extends State<PatientSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primaryContainer.withOpacity(0.2),
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppBar(
                title: const Text('Select Patient'),
                elevation: 0,
                backgroundColor: Colors.transparent,
                centerTitle: true,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.people_outline, color: colorScheme.primary, size: 24),
                            ),
                            const Gap(14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Multiple accounts found',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const Gap(4),
                                  Text(
                                    'Select the account you want to use for appointments',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Gap(20),
                      Text(
                        'CNIC: ${widget.phoneNumber}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Gap(16),
                      ...widget.patients.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildPatientCard(p),
                      )),
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

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final fullName = patient['FullName'] ?? patient['fullName'] ?? 'Unknown';
    final mrn = patient['MRN'] ?? patient['mrn'] ?? 'N/A';
    final cnic = patient['CNIC'] ?? patient['cnic'] ?? 'N/A';
    final dateOfBirth = patient['DateOfBirth'] ?? patient['dateOfBirth'];
    final gender = patient['Gender'] ?? patient['gender'] ?? 'N/A';
    
    final dobString = dateOfBirth != null
        ? AppDateFormat.formatDate(dateOfBirth, fallback: 'N/A')
        : null;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: Colors.black.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: () => _selectPatient(patient),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.secondary],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 24),
                  ),
                  const Gap(14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const Gap(4),
                        Text(
                          'MRN: $mrn',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: colorScheme.outline,
                  ),
                ],
              ),
              const Gap(14),
              Divider(height: 1, color: colorScheme.outline.withOpacity(0.2)),
              const Gap(12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildDetailItem(Icons.credit_card, 'CNIC',
                      cnic.length > 13 ? '${cnic.substring(0, 13)}...' : cnic),
                  _buildDetailItem(Icons.calendar_today, 'DOB', dobString ?? 'N/A'),
                  _buildDetailItem(Icons.person_outline, 'Gender', gender),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.outline.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const Gap(6),
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _selectPatient(Map<String, dynamic> patient) async {
    try {
      // Save selected patient data
      await UserStorage.saveUserData(patient);
      
      // Get MRN or CNIC for navigation
      final mrn = patient['MRN'] ?? patient['mrn'] ?? '';
      final cnic = patient['CNIC'] ?? patient['cnic'] ?? '';
      final identifier = mrn.isNotEmpty ? mrn : cnic;
      
      if (!mounted) return;
      
      // Reset inactivity timer on successful patient selection
      InactivityService.instance.resetActivity();
      
      // Navigate to dashboard
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PatientShell(patientIdentifier: identifier),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      AppSnackBar.showError(context, 'Error saving patient data: $e');
    }
  }
}


