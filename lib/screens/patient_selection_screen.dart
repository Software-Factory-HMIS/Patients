import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'dashboard_screen.dart';
import '../utils/user_storage.dart';
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Select Patient'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Multiple accounts found',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                              fontSize: 16,
                            ),
                          ),
                          const Gap(4),
                          Text(
                            'Please select the account you want to use for appointments',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const Gap(24),
              
              // CNIC/Identifier display
              Text(
                'CNIC: ${widget.phoneNumber}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              const Gap(16),
              
              // Patients list
              Expanded(
                child: ListView.builder(
                  itemCount: widget.patients.length,
                  itemBuilder: (context, index) {
                    final patient = widget.patients[index];
                    return _buildPatientCard(patient);
                  },
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
    
    String? dobString;
    if (dateOfBirth != null) {
      try {
        if (dateOfBirth is String) {
          dobString = dateOfBirth.split('T').first; // Extract date part from ISO string
        } else {
          dobString = dateOfBirth.toString();
        }
      } catch (e) {
        dobString = 'N/A';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _selectPatient(patient),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name and MRN
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const Gap(4),
                        Text(
                          'MRN: $mrn',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 20,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
              
              const Gap(12),
              
              // Divider
              Divider(height: 1, color: Colors.grey.shade300),
              
              const Gap(12),
              
              // Details
              Row(
                children: [
                  Expanded(
                    child: _buildDetailItem(
                      Icons.credit_card,
                      'CNIC',
                      cnic.length > 13 ? '${cnic.substring(0, 13)}...' : cnic,
                    ),
                  ),
                  Expanded(
                    child: _buildDetailItem(
                      Icons.calendar_today,
                      'DOB',
                      dobString ?? 'N/A',
                    ),
                  ),
                  Expanded(
                    child: _buildDetailItem(
                      Icons.person,
                      'Gender',
                      gender,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const Gap(4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const Gap(4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
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
          builder: (context) => DashboardScreen(cnic: identifier),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving patient data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


