import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/keyboard_inset_padding.dart';
import '../utils/emr_api_client.dart';
import '../utils/user_storage.dart';
import '../services/auth_service.dart';
import '../services/inactivity_service.dart';
import '../models/appointment_models.dart' show Hospital, Department, HospitalDepartment, QueueResponse, AppointmentDetails;
import 'appointment_success_screen.dart';
import 'patient_file_screen.dart';
import 'signin_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String cnic;
  
  const DashboardScreen({super.key, required this.cnic});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _patient;
  List<dynamic>? _vitals;
  List<dynamic>? _medications;
  List<dynamic>? _opd;
  List<dynamic>? _ipd;
  List<dynamic>? _labs;
  List<dynamic>? _radiology;
  List<dynamic>? _surgery;
  bool _loading = false;
  String? _error;
  bool _showOverlay = false;
  String? _selectedSection;
  bool _isTabSectionExpanded = true;
  int _currentNavIndex = 0;
  
  // Appointments state
  EmrApiClient? _api;
  List<Hospital>? _hospitals;
  List<Department>? _departments;
  List<HospitalDepartment>? _hospitalDepartments; // Hospital-specific departments with hospitalDepartmentId
  Hospital? _selectedHospital;
  HospitalDepartment? _selectedHospitalDepartment;
  bool _loadingHospitals = false;
  bool _loadingDepartments = false;
  bool _loadingHospitalDepartments = false;
  bool _submittingAppointment = false;
  String? _appointmentError;
  int? _patientId;
  Map<String, dynamic>? _savedUserData; // Saved user data from registration
  final TextEditingController _hospitalSearchController = TextEditingController();
  List<Map<String, dynamic>>? _recentAppointments;
  bool _loadingRecentAppointments = false;
  
  // Search controllers for each section
  final TextEditingController _vitalsSearchController = TextEditingController();
  final TextEditingController _medicationsSearchController = TextEditingController();
  final TextEditingController _opdSearchController = TextEditingController();
  final TextEditingController _ipdSearchController = TextEditingController();
  final TextEditingController _labsSearchController = TextEditingController();
  final TextEditingController _radiologySearchController = TextEditingController();
  final TextEditingController _surgerySearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this); // Removed pregnancy tab
    _initializeApi();
    _loadData();
    _loadSavedUserData();
    // Reset inactivity timer when dashboard loads
    InactivityService.instance.resetActivity();
    // Load appointments data since it's the default tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHospitals();
      _loadDepartments();
      _loadRecentAppointments();
    });
  }

  Future<void> _loadSavedUserData() async {
    try {
      _savedUserData = await UserStorage.getUserData();
      if (_savedUserData != null) {
      }
    } catch (e) {
    }
  }

  Future<void> _initializeApi() async {
    try {
      _api = EmrApiClient();
    } catch (e) {
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _vitalsSearchController.dispose();
    _medicationsSearchController.dispose();
    _opdSearchController.dispose();
    _ipdSearchController.dispose();
    _labsSearchController.dispose();
    _radiologySearchController.dispose();
    _surgerySearchController.dispose();
    _hospitalSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    // Ensure API is initialized
    if (_api == null) {
      await _initializeApi();
    }
    
    if (_api == null) {
      setState(() {
        _loading = false;
        _error = 'Failed to initialize API client';
      });
      return;
    }
    
    try {
      // Fetch patient data from backend using CNIC
      final patientData = await _api!.fetchPatient(widget.cnic);
      
      if (!mounted) return;
      
      // Extract patient information from API response
      String patientName = patientData['FullName'] as String? ?? 
                          patientData['fullName'] as String? ?? 
                          patientData['Name'] as String? ??
                          'Patient Name';
      
      String mrn = patientData['MRN'] as String? ?? 
                  patientData['mrn'] as String? ?? 
                  widget.cnic;
      
      String gender = patientData['Gender'] as String? ?? 
                     patientData['gender'] as String? ?? 
                     'N/A';
      
      String age = 'N/A';
      // Try to get age directly from API response first
      if (patientData['Age'] != null) {
        age = patientData['Age'].toString();
      } else {
        // Calculate age from DateOfBirth if Age is not available
        final dateOfBirth = patientData['DateOfBirth'] ?? 
                           patientData['dateOfBirth'];
        if (dateOfBirth != null) {
          try {
            DateTime? dob;
            if (dateOfBirth is DateTime) {
              dob = dateOfBirth;
            } else if (dateOfBirth is String) {
              dob = DateTime.parse(dateOfBirth);
            }
            if (dob != null) {
              final now = DateTime.now();
              int years = now.year - dob.year;
              if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
                years--;
              }
              age = years.toString();
            }
          } catch (e) {
          }
        }
      }
      
      String bloodType = patientData['BloodGroup'] as String? ?? 
                        patientData['bloodGroup'] as String? ?? 
                        'N/A';
      
      String lastVisit = 'N/A';
      // Get last visit from UpdatedAt, UpdatedDate, CreatedAt, or CreatedDate
      final updatedAt = patientData['UpdatedAt'] ?? 
                       patientData['updatedAt'] ??
                       patientData['UpdatedDate'] ?? 
                       patientData['updatedDate'];
      final createdAt = patientData['CreatedAt'] ?? 
                        patientData['createdAt'] ??
                        patientData['CreatedDate'] ?? 
                        patientData['createdDate'];
      if (updatedAt != null || createdAt != null) {
        try {
          DateTime? visitDate;
          if (updatedAt is DateTime) {
            visitDate = updatedAt;
          } else if (updatedAt is String) {
            visitDate = DateTime.parse(updatedAt);
          } else if (createdAt is DateTime) {
            visitDate = createdAt;
          } else if (createdAt is String) {
            visitDate = DateTime.parse(createdAt);
          }
          if (visitDate != null) {
            final now = DateTime.now();
            final difference = now.difference(visitDate);
            if (difference.inDays == 0) {
              lastVisit = 'Today';
            } else if (difference.inDays == 1) {
              lastVisit = 'Yesterday';
            } else if (difference.inDays < 30) {
              lastVisit = '${difference.inDays} days ago';
            } else {
              lastVisit = '${visitDate.day}/${visitDate.month}/${visitDate.year}';
            }
          }
        } catch (e) {
        }
      }
      
      // Get patient ID
      final patientId = patientData['PatientID'] as int? ?? 
                       patientData['patientId'] as int? ?? 
                       patientData['PatientId'] as int?;
      
      // Store full patient data for later use
      _savedUserData = patientData;
      
      // Initialize with loaded patient data
      setState(() {
        _patient = {
          'name': patientName,
          'fullName': patientName,
          'mrn': mrn,
          'gender': gender,
          'age': age,
          'bloodType': bloodType,
          'bloodGroup': bloodType,
          'lastVisit': lastVisit,
          'patientId': patientId,
        };
        _vitals = [];
        _medications = [];
        _opd = [];
        _ipd = [];
        _labs = [];
        _radiology = [];
        _surgery = [];
        _loading = false;
      });
      
      
      // Load medical records data after patient data is loaded
      if (mounted && mrn.isNotEmpty) {
        await _loadMedicalRecordsData();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load patient data: ${e.toString()}';
        });
      }
    }
  }

  /// Loads all medical records data using the same endpoints as Medical Records section
  Future<void> _loadMedicalRecordsData() async {
    if (_api == null) {
      await _initializeApi();
      if (_api == null) {
        return;
      }
    }

    final mrn = _patient?['mrn'] as String?;
    if (mrn == null || mrn.isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      // Load all medical records data in parallel using the same endpoints as Medical Records section
      final results = await Future.wait([
        _api!.fetchVitals(mrn).catchError((e) {
          return <dynamic>[];
        }),
        _api!.fetchMedications(mrn).catchError((e) {
          return <dynamic>[];
        }),
        _api!.fetchOPD(mrn).catchError((e) {
          return <dynamic>[];
        }),
        _api!.fetchIPD(mrn).catchError((e) {
          return <dynamic>[];
        }),
        _api!.fetchLabs(mrn).catchError((e) {
          return <dynamic>[];
        }),
        _api!.fetchRadiology(mrn).catchError((e) {
          return <dynamic>[];
        }),
        _api!.fetchSurgery(mrn).catchError((e) {
          return <dynamic>[];
        }),
      ]);

      if (mounted) {
        setState(() {
          _vitals = results[0];
          _medications = results[1];
          _opd = results[2];
          _ipd = results[3];
          _labs = results[4];
          _radiology = results[5];
          _surgery = results[6];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey.shade50,
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: Text(
          _currentNavIndex == 0 
              ? 'Appointments' 
              : 'My Medical Records',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () async {
              // Logout and navigate to sign in screen
              await AuthService.instance.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const SignInScreen(),
                  ),
                  (route) => false,
                );
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _currentNavIndex == 0
          ? _buildAppointmentsScreen()
          : _buildFileScreen(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: BottomNavigationBar(
          currentIndex: _currentNavIndex,
          onTap: (index) {
            setState(() {
              _currentNavIndex = index;
            });
            // Load appointments data when switching to appointments tab
            if (index == 0) {
              if (_hospitals == null) {
                _loadHospitals();
              }
              if (_departments == null) {
                _loadDepartments();
              }
              // Reload recent appointments when switching to appointments tab
              _loadRecentAppointments();
            }
            // Load medical records data when switching to medical records tab (index 1)
            if (index == 1) {
              // Medical records are loaded via PatientFileScreen
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue.shade700,
          unselectedItemColor: Colors.grey.shade600,
          selectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Appointment',
            ),
            // BottomNavigationBarItem(
            //   icon: Icon(Icons.dashboard_outlined),
            //   activeIcon: Icon(Icons.dashboard),
            //   label: 'Dashboard',
            // ),
            BottomNavigationBarItem(
              icon: Icon(Icons.medical_information_outlined),
              activeIcon: Icon(Icons.medical_information),
              label: 'Medical Records',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileScreen() {
    if (_patient == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return PatientFileScreen(patient: _patient!);
  }

  Widget _buildAppointmentsScreen() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filteredHospitals = _getFilteredHospitals();
    
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Header Card
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary,
                      colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.calendar_today,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const Gap(16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Book Appointment',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Gap(4),
                              Text(
                                'Select hospital and department',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Gap(24),

            // Hospital Selection Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.local_hospital_outlined,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        const Gap(8),
                        Text(
                          'Hospital',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                        const Gap(4),
                        Text(
                          '*',
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ],
                    ),
                    const Gap(12),
                    // Hospital Search Field
                    if (_hospitals != null && _hospitals!.length > 5)
                      TextField(
                        controller: _hospitalSearchController,
                        decoration: InputDecoration(
                          hintText: 'Search hospitals...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _hospitalSearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() {
                                      _hospitalSearchController.clear();
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            // Clear selection if it's filtered out
                            final filtered = _getFilteredHospitals();
                            if (_selectedHospital != null && 
                                filtered != null && 
                                !filtered.contains(_selectedHospital)) {
                              _selectedHospital = null;
                              _selectedHospitalDepartment = null;
                              _hospitalDepartments = null;
                            }
                          });
                        },
                      ),
                    if (_hospitals != null && _hospitals!.length > 5) const Gap(12),
                    _loadingHospitals
                        ? _buildSkeletonLoader()
                        : (filteredHospitals == null || filteredHospitals.isEmpty)
                            ? Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colorScheme.outline.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: colorScheme.onSurfaceVariant,
                                      size: 20,
                                    ),
                                    const Gap(12),
                                    Expanded(
                                      child: Text(
                                        _hospitals == null
                                            ? 'Loading hospitals...'
                                            : 'No hospitals found',
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : SizedBox(
                                width: double.infinity,
                                child: DropdownButtonFormField<Hospital>(
                                  value: filteredHospitals.contains(_selectedHospital) 
                                      ? _selectedHospital 
                                      : null,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: colorScheme.surfaceContainerHighest,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  hint: const Text('Select a hospital'),
                                  items: filteredHospitals.map((hospital) {
                                    return DropdownMenuItem<Hospital>(
                                      value: hospital,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.local_hospital,
                                            size: 18,
                                            color: colorScheme.primary,
                                          ),
                                          const Gap(8),
                                          Expanded(
                                            child: Text(
                                              hospital.name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (hospital) {
                                    setState(() {
                                      _selectedHospital = hospital;
                                      _selectedHospitalDepartment = null;
                                      _hospitalDepartments = null;
                                    });
                                    if (hospital != null) {
                                      _loadHospitalDepartments(hospital.hospitalID);
                                    }
                                  },
                                ),
                              ),
                    // Hospital Details Expansion
                    if (_selectedHospital != null) ...[
                      const Gap(12),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 8),
                        leading: Icon(
                          Icons.info_outline,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        title: Text(
                          'Hospital Details',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        children: [
                          _buildHospitalDetails(_selectedHospital!, colorScheme),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Gap(16),

            // Department Selection Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.medical_services_outlined,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        const Gap(8),
                        Text(
                          'Department',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                        const Gap(4),
                        Text(
                          '*',
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ],
                    ),
                    const Gap(12),
                    _loadingHospitalDepartments
                        ? _buildSkeletonLoader()
                        : IgnorePointer(
                            ignoring: _selectedHospital == null || _loadingHospitalDepartments,
                            child: Opacity(
                              opacity: _selectedHospital == null ? 0.6 : 1.0,
                              child: SizedBox(
                                width: double.infinity,
                                child: DropdownButtonFormField<HospitalDepartment>(
                                  value: _selectedHospitalDepartment,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: _selectedHospital != null
                                        ? colorScheme.surfaceContainerHighest
                                        : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  hint: Text(
                                    _selectedHospital == null
                                        ? 'Please select a hospital first'
                                        : _loadingHospitalDepartments
                                            ? 'Loading departments...'
                                            : 'Select a department',
                                  ),
                                  items: _hospitalDepartments?.map((hospitalDept) {
                                    return DropdownMenuItem<HospitalDepartment>(
                                      value: hospitalDept,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.medical_services,
                                            size: 18,
                                            color: colorScheme.primary,
                                          ),
                                          const Gap(8),
                                          Expanded(
                                            child: Text(
                                              hospitalDept.departmentName,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: _selectedHospital == null || _loadingHospitalDepartments
                                      ? null
                                      : (hospitalDept) {
                                          setState(() {
                                            _selectedHospitalDepartment = hospitalDept;
                                          });
                                        },
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
            const Gap(16),

            // Selection Summary Card
            if (_selectedHospital != null && _selectedHospitalDepartment != null)
              Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.primaryContainer.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer.withOpacity(0.3),
                        colorScheme.secondaryContainer.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          const Gap(8),
                          Text(
                            'Selected',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const Gap(12),
                      _buildSummaryRow(
                        Icons.local_hospital,
                        'Hospital',
                        _selectedHospital!.name,
                        colorScheme,
                      ),
                      const Gap(8),
                      _buildSummaryRow(
                        Icons.medical_services,
                        'Department',
                        _selectedHospitalDepartment!.departmentName,
                        colorScheme,
                      ),
                    ],
                  ),
                ),
              ),
            if (_selectedHospital != null && _selectedHospitalDepartment != null) const Gap(16),

            // Error Message
            if (_appointmentError != null)
              Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.errorContainer,
                    width: 1,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.error_outline_rounded,
                          color: colorScheme.onErrorContainer,
                          size: 20,
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: Text(
                          _appointmentError!,
                          style: TextStyle(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_appointmentError != null) const Gap(16),

            // Submit Button
            FilledButton.icon(
              onPressed: (_selectedHospital != null &&
                      _selectedHospitalDepartment != null &&
                      !_submittingAppointment)
                  ? _handleAppointmentSubmission
                  : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                minimumSize: const Size(double.infinity, 56),
              ),
              icon: _submittingAppointment
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : const Icon(Icons.calendar_today, size: 20),
              label: _submittingAppointment
                  ? const Text('Processing...')
                  : const Text(
                      'Book Appointment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            const Gap(24),

            // Recent Appointments Section
            _buildRecentAppointmentsSection(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  // Helper methods for appointments screen
  List<Hospital>? _getFilteredHospitals() {
    if (_hospitals == null) return null;
    final searchText = _hospitalSearchController.text.toLowerCase().trim();
    if (searchText.isEmpty) return _hospitals;
    final filtered = _hospitals!.where((hospital) {
      return hospital.name.toLowerCase().contains(searchText);
    }).toList();
    return filtered.isEmpty ? [] : filtered;
  }

  Widget _buildSkeletonLoader() {
    return Card(
      elevation: 0,
      child: Container(
        height: 60,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Gap(12),
            Expanded(
              child: Container(
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHospitalDetails(Hospital hospital, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hospital.location.isNotEmpty && hospital.location != 'Location not specified')
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const Gap(8),
                Expanded(
                  child: Text(
                    hospital.location,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (hospital.type != null && hospital.type!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const Gap(8),
                Text(
                  hospital.type!,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryRow(
    IconData icon,
    String label,
    String value,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        const Gap(8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentAppointmentsSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.history,
              color: colorScheme.primary,
              size: 20,
            ),
            const Gap(8),
            Text(
              'Recent Appointments',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const Gap(16),
        _loadingRecentAppointments
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            : _recentAppointments == null || _recentAppointments!.isEmpty
                ? _buildEmptyAppointmentsState(colorScheme)
                : Column(
                    children: _recentAppointments!.take(3).map((appointment) {
                      return _buildAppointmentCard(appointment, colorScheme, theme);
                    }).toList(),
                  ),
      ],
    );
  }

  Widget _buildEmptyAppointmentsState(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 48,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const Gap(16),
            Text(
              'No recent appointments',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Gap(4),
            Text(
              'Your appointment history will appear here',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(
    Map<String, dynamic> appointment,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final hospitalName = appointment['hospitalName'] ?? 
                         appointment['HospitalName'] ?? 
                         appointment['hospital']?['name'] ??
                         'Hospital';
    final departmentName = appointment['departmentName'] ?? 
                           appointment['DepartmentName'] ?? 
                           appointment['department']?['name'] ??
                           'Department';
    final queueDate = appointment['queueDate'] ?? 
                     appointment['QueueDate'] ?? 
                     appointment['createdAt'] ??
                     appointment['CreatedAt'];
    
    DateTime? appointmentDate;
    if (queueDate != null) {
      try {
        if (queueDate is DateTime) {
          appointmentDate = queueDate;
        } else if (queueDate is String) {
          appointmentDate = DateTime.parse(queueDate);
        }
      } catch (e) {
      }
    }
    
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Could navigate to appointment details
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_today,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              const Gap(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hospitalName.toString(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      departmentName.toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (appointmentDate != null) ...[
                      const Gap(4),
                      Text(
                        _formatAppointmentDate(appointmentDate!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAppointmentDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays == -1) {
      return 'Yesterday';
    } else if (difference.inDays > 0 && difference.inDays < 7) {
      return 'In ${difference.inDays} days';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _loadRecentAppointments() async {
    if (_api == null) {
      await _initializeApi();
    }
    if (_api == null) {
      setState(() {
        _loadingRecentAppointments = false;
        _recentAppointments = _recentAppointments ?? [];
      });
      return;
    }

    setState(() {
      _loadingRecentAppointments = true;
    });

    try {
      // Try to load from local storage first
      final savedAppointments = await UserStorage.getRecentAppointments();
      if (savedAppointments != null && savedAppointments.isNotEmpty) {
        // Filter appointments by current patient's CNIC
        // Only show appointments that have a matching CNIC (ignore old appointments without patientCnic)
        final patientAppointments = savedAppointments
            .where((appointment) => 
                appointment['patientCnic'] != null && 
                appointment['patientCnic'] == widget.cnic)
            .toList();
        
        if (mounted) {
          setState(() {
            _recentAppointments = patientAppointments;
            _loadingRecentAppointments = false;
          });
        }
        return;
      }

      // If no saved appointments, use in-memory list
      if (mounted) {
        setState(() {
          _loadingRecentAppointments = false;
          _recentAppointments = _recentAppointments ?? [];
        });
      }
    } catch (e) {
      // Silently fail - recent appointments are optional
      if (mounted) {
        setState(() {
          _loadingRecentAppointments = false;
          _recentAppointments = _recentAppointments ?? [];
        });
      }
    }
  }

  Future<void> _loadHospitals() async {
    if (_api == null) {
      await _initializeApi();
    }
    if (_api == null) {
      setState(() {
        _appointmentError = 'Failed to initialize API client';
      });
      return;
    }

    setState(() {
      _loadingHospitals = true;
      _appointmentError = null;
    });

    try {
      final hospitalsData = await _api!.fetchHospitals();
      final hospitals = (hospitalsData as List)
          .map((json) => Hospital.fromJson(json as Map<String, dynamic>))
          .where((h) => h.isActive)
          .toList();

      setState(() {
        _hospitals = hospitals;
        _loadingHospitals = false;
      });
    } catch (e) {
      setState(() {
        _loadingHospitals = false;
        _appointmentError = 'Failed to load hospitals: $e';
      });
    }
  }

  Future<void> _loadDepartments() async {
    if (_api == null) {
      await _initializeApi();
    }
    if (_api == null) {
      setState(() {
        _appointmentError = 'Failed to initialize API client';
      });
      return;
    }

    setState(() {
      _loadingDepartments = true;
      _appointmentError = null;
    });

    try {
      final departmentsData = await _api!.fetchDepartments();
      final departments = <Department>[];
      
      for (var item in departmentsData) {
        try {
          final json = item as Map<String, dynamic>;
          final department = Department.fromJson(json);
          if (department.isActive && department.departmentID > 0) {
            departments.add(department);
          }
        } catch (e) {
          // Skip invalid departments but continue processing others
        }
      }

      setState(() {
        _departments = departments;
        _loadingDepartments = false;
      });
    } catch (e) {
      setState(() {
        _loadingDepartments = false;
        _appointmentError = 'Failed to load departments: $e';
      });
    }
  }

  Future<void> _loadHospitalDepartments(int hospitalId) async {
    if (_api == null) {
      await _initializeApi();
    }
    if (_api == null) {
      setState(() {
        _appointmentError = 'Failed to initialize API client';
      });
      return;
    }

    setState(() {
      _loadingHospitalDepartments = true;
      _appointmentError = null;
    });

    try {
      final hospitalDepartmentsData = await _api!.fetchHospitalDepartments(hospitalId);
      final hospitalDepartments = <HospitalDepartment>[];
      
      for (var item in hospitalDepartmentsData) {
        try {
          final json = item as Map<String, dynamic>;
          final hospitalDept = HospitalDepartment.fromJson(json);
          if (hospitalDept.hospitalDepartmentID > 0) {
            hospitalDepartments.add(hospitalDept);
          }
        } catch (e) {
          // Skip invalid departments but continue processing others
        }
      }

      setState(() {
        _hospitalDepartments = hospitalDepartments;
        _loadingHospitalDepartments = false;
      });
    } catch (e) {
      setState(() {
        _loadingHospitalDepartments = false;
        _appointmentError = 'Failed to load hospital departments: $e';
      });
    }
  }

  Future<int> _fetchPatientId() async {
    if (_api == null) {
      await _initializeApi();
    }
    if (_api == null) {
      throw Exception('Failed to initialize API client');
    }

    try {
      // Try to fetch patient by CNIC/phone
      String searchIdentifier = widget.cnic;
      
      // If we have saved user data, try using CNIC first, then phone
      if (_savedUserData != null) {
        final cnic = _savedUserData!['cnic'] as String?;
        if (cnic != null && cnic.isNotEmpty) {
          searchIdentifier = cnic;
        } else {
          final phone = _savedUserData!['phone'] as String?;
          if (phone != null && phone.isNotEmpty) {
            searchIdentifier = phone;
          }
        }
      }
      
      try {
        final patient = await _api!.fetchPatient(searchIdentifier);
        final patientId = patient['patientId'] as int? ?? patient['PatientID'] as int?;
        if (patientId == null) {
          throw Exception('Patient ID not found in patient data');
        }
        return patientId;
      } catch (fetchError) {
        // If patient not found (400 or 404), try to register the patient
        if (_savedUserData != null && fetchError.toString().contains('400') || fetchError.toString().contains('404')) {
          
          final fullName = _savedUserData!['fullName'] as String? ?? 'Unknown';
          final cnic = _savedUserData!['cnic'] as String? ?? '';
          final phone = _savedUserData!['phone'] as String? ?? '';
          final email = _savedUserData!['email'] as String? ?? '';
          final dateOfBirth = _savedUserData!['dateOfBirth'] as DateTime? ?? DateTime(1990, 1, 1);
          final gender = _savedUserData!['gender'] as String? ?? 'Male';
          final address = _savedUserData!['address'] as String? ?? '';
          final bloodGroup = _savedUserData!['bloodGroup'] as String?;
          
          if (cnic.isEmpty && phone.isEmpty) {
            throw Exception('Cannot register patient: CNIC or phone number is required');
          }
          
          // Register the patient
          // For patient self-registration, use default system user ID (1)
          const int defaultSystemUserId = 1;
          
          final registeredPatient = await _api!.registerPatient(
            fullName: fullName,
            cnic: cnic.isNotEmpty ? cnic : phone,
            phone: phone.isNotEmpty ? phone : cnic,
            email: email,
            dateOfBirth: dateOfBirth,
            gender: gender,
            address: address,
            bloodGroup: bloodGroup,
            createdBy: defaultSystemUserId, // Required by database
          );
          
          final patientId = registeredPatient['patientId'] as int? ?? 
                           registeredPatient['PatientID'] as int?;
          
          if (patientId == null) {
            throw Exception('Patient registered but ID not found in response');
          }
          
          return patientId;
        }
        // Re-throw if it's not a 400/404 error
        throw fetchError;
      }
    } catch (e) {
      // If patient not found, throw error with helpful message
      throw Exception('Failed to fetch/register patient: $e');
    }
  }

  Future<void> _handleAppointmentSubmission() async {
    if (_selectedHospital == null || _selectedHospitalDepartment == null) {
      return;
    }

    setState(() {
      _submittingAppointment = true;
      _appointmentError = null;
    });

    try {
      if (_api == null) {
        await _initializeApi();
      }
      
      if (_api == null) {
        throw Exception('API client not initialized');
      }

      // Fetch or register patient to get patient ID
      final patientId = await _fetchPatientId();

      // Use saved user data for appointment details
      final patientName = _savedUserData?['FullName'] as String? ?? 
                          _savedUserData?['fullName'] as String? ?? 
                          _patient?['name'] as String? ?? 
                          'Unknown';
      final patientMRN = _savedUserData?['MRN'] as String? ?? 
                         _savedUserData?['mrn'] as String? ?? 
                         _savedUserData?['cnic'] as String? ?? 
                         _savedUserData?['phone'] as String? ?? 
                         widget.cnic;

      // Add patient to queue using the real API

      final deptName = (_selectedHospitalDepartment!.departmentName ?? '').toLowerCase().trim();
      final isEmergencyDept = deptName.contains('emergency');

      final queueResponse = await _api!.addPatientToQueue(
        patientId: patientId,
        hospitalId: _selectedHospital!.hospitalID,
        hospitalDepartmentId: _selectedHospitalDepartment!.hospitalDepartmentID,
        createdBy: 1, // Default system user for patient self-registration
        priority: 'Normal',
        queueType: isEmergencyDept ? 'Emergency' : 'OPD',
        visitPurpose: 'Check-Up',
        patientSource: 'SELF_CHECKIN',
      );


      final queueId = queueResponse['queueId'] as int?;
      final tokenNumber = queueResponse['tokenNumber'] as String? ?? 'N/A';

      if (queueId == null) {
        throw Exception('Queue ID not returned from API');
      }

      // Create queue response object
      final queueResponseObj = QueueResponse(
        queueId: queueId,
        tokenNumber: tokenNumber,
      );

      // Print queue receipt using the real queue ID
      Map<String, dynamic> receiptData = {};
      try {
        receiptData = await _api!.printQueueReceipt(queueId: queueId);
        if (receiptData.isNotEmpty) {
        }
      } catch (e) {
        // Continue anyway - will show appointment details
      }

      // Create a Department object from HospitalDepartment for compatibility
      final department = Department(
        departmentID: _selectedHospitalDepartment!.departmentID,
        name: _selectedHospitalDepartment!.departmentName,
        isActive: true,
        hospitalCount: 0,
      );

      // Create appointment details with real queue data and receipt data from print API
      final appointmentDetails = AppointmentDetails(
        queueResponse: queueResponseObj,
        hospital: _selectedHospital!,
        department: department,
        patientName: patientName,
        patientMRN: patientMRN,
        appointmentDate: DateTime.now(),
        queuePosition: null,
        estimatedWaitTime: null,
        receiptData: receiptData.isNotEmpty ? receiptData : null, // Include receipt data from print API
      );

      // Add to recent appointments before navigation
      final appointmentMap = {
        'hospitalName': _selectedHospital!.name,
        'departmentName': _selectedHospitalDepartment!.departmentName,
        'queueDate': appointmentDetails.appointmentDate.toIso8601String(),
        'tokenNumber': tokenNumber,
        'queueId': queueId,
        'appointmentDate': appointmentDetails.appointmentDate.toIso8601String(),
        'patientCnic': widget.cnic, // Include patient CNIC for filtering
      };
      
      // Update in-memory list for current patient
      _recentAppointments ??= [];
      _recentAppointments!.insert(0, appointmentMap); // Add to beginning
      // Keep only last 5 appointments for current patient
      if (_recentAppointments!.length > 5) {
        _recentAppointments = _recentAppointments!.take(5).toList();
      }
      
      // Save to local storage - merge with existing appointments from all patients
      final allSavedAppointments = await UserStorage.getRecentAppointments() ?? [];
      // Remove any existing appointments for this patient (to avoid duplicates)
      final otherPatientsAppointments = allSavedAppointments
          .where((apt) => apt['patientCnic'] != widget.cnic)
          .toList();
      // Combine: current patient's appointments + other patients' appointments
      final appointmentsToSave = [..._recentAppointments!, ...otherPatientsAppointments];
      await UserStorage.saveRecentAppointments(appointmentsToSave);
      
      setState(() {
        // State already updated above
      });

      // Navigate to success screen with appointment details
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AppointmentSuccessScreen(
              appointment: appointmentDetails,
            ),
          ),
        ).then((_) {
          // Reload recent appointments when returning from success screen
          if (mounted) {
            _loadRecentAppointments();
          }
        });

        // Reset form after navigation
        setState(() {
          _selectedHospital = null;
          _selectedHospitalDepartment = null;
          _submittingAppointment = false;
        });
      }
    } catch (e) {
      setState(() {
        _submittingAppointment = false;
        _appointmentError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Widget _buildPatientHeader() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      color: Colors.grey.shade50,
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        children: [
          // Patient Profile - Full Width Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.surface,
                    colorScheme.surfaceContainerHighest,
                  ],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      colorScheme.primary,
                                      colorScheme.secondary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.person,
                                  size: 28,
                                  color: Colors.white,
                                ),
                              ),
                            const Gap(12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _patient?['name'] as String? ?? 'Loading...',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  const Gap(4),
                                  Text(
                                    'MRN: ${_patient?['mrn'] ?? 'N/A'}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Gap(12),
                        Divider(height: 1, color: Colors.grey.shade300),
                        const Gap(12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _buildInfoChip(Icons.person_outline, 'Gender', _patient?['gender'] ?? 'N/A'),
                            _buildInfoChip(Icons.cake_outlined, 'Age', '${_patient?['age'] ?? 'N/A'} years'),
                            _buildInfoChip(Icons.bloodtype, 'Blood Type', _patient?['bloodType'] ?? 'N/A'),
                            _buildInfoChip(Icons.calendar_today, 'Last Visit', _patient?['lastVisit'] ?? 'N/A'),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colorScheme.primary,
                                colorScheme.secondary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.person,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        const Gap(16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _patient?['name'] as String? ?? 'Loading...',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const Gap(8),
                              Text(
                                'MRN: ${_patient?['mrn'] ?? 'N/A'} • ${_patient?['gender'] ?? 'N/A'} • ${_patient?['age'] ?? 'N/A'} years • ${_patient?['bloodType'] ?? 'N/A'} • Last Visit: ${_patient?['lastVisit'] ?? 'N/A'}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Drawer(
      child: Column(
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 24,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary,
                  colorScheme.primaryContainer,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Healthcare',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Management System',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          
          // Patient Details Card
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Patient Details Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.surface,
                          colorScheme.surfaceContainerHighest,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    colorScheme.primary,
                                    colorScheme.secondary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.person,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                            const Gap(16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _patient?['name'] as String? ?? 'Loading...',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Gap(4),
                                  Text(
                                    'MRN: ${_patient?['mrn'] ?? 'N/A'}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Gap(20),
                        Divider(color: colorScheme.outline.withOpacity(0.2)),
                        const Gap(16),
                        _buildDrawerInfoRow(
                          Icons.person_outline,
                          'Gender',
                          _patient?['gender'] ?? 'N/A',
                          colorScheme,
                        ),
                        const Gap(12),
                        _buildDrawerInfoRow(
                          Icons.cake_outlined,
                          'Age',
                          '${_patient?['age'] ?? 'N/A'} years',
                          colorScheme,
                        ),
                        const Gap(12),
                        _buildDrawerInfoRow(
                          Icons.bloodtype,
                          'Blood Type',
                          _patient?['bloodType'] ?? 'N/A',
                          colorScheme,
                        ),
                        const Gap(12),
                        _buildDrawerInfoRow(
                          Icons.calendar_today_outlined,
                          'Last Visit',
                          _patient?['lastVisit'] ?? 'N/A',
                          colorScheme,
                        ),
                        if (_savedUserData != null) ...[
                          const Gap(12),
                          if (_savedUserData!['CNIC'] != null || _savedUserData!['cnic'] != null)
                            _buildDrawerInfoRow(
                              Icons.badge_outlined,
                              'CNIC',
                              _savedUserData!['CNIC'] ?? _savedUserData!['cnic'] ?? 'N/A',
                              colorScheme,
                            ),
                          if (_savedUserData!['ContactNumber'] != null || _savedUserData!['contactNumber'] != null) ...[
                            const Gap(12),
                            _buildDrawerInfoRow(
                              Icons.phone_outlined,
                              'Contact',
                              _savedUserData!['ContactNumber'] ?? _savedUserData!['contactNumber'] ?? 'N/A',
                              colorScheme,
                            ),
                          ],
                          if (_savedUserData!['Email'] != null || _savedUserData!['email'] != null) ...[
                            const Gap(12),
                            _buildDrawerInfoRow(
                              Icons.email_outlined,
                              'Email',
                              _savedUserData!['Email'] ?? _savedUserData!['email'] ?? 'N/A',
                              colorScheme,
                            ),
                          ],
                          if (_savedUserData!['Address'] != null || _savedUserData!['address'] != null) ...[
                            const Gap(12),
                            _buildDrawerInfoRow(
                              Icons.location_on_outlined,
                              'Address',
                              _savedUserData!['Address'] ?? _savedUserData!['address'] ?? 'N/A',
                              colorScheme,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                const Gap(16),
                
                // Navigation Items
                _buildDrawerTile(
                  context,
                  Icons.calendar_today_outlined,
                  'Appointments',
                  _currentNavIndex == 0,
                  () {
                    setState(() => _currentNavIndex = 0);
                    Navigator.pop(context);
                  },
                  colorScheme,
                ),
                _buildDrawerTile(
                  context,
                  Icons.medical_information_outlined,
                  'Medical Records',
                  _currentNavIndex == 1,
                  () {
                    setState(() => _currentNavIndex = 1);
                    Navigator.pop(context);
                  },
                  colorScheme,
                ),
                const Divider(height: 32),
                _buildDrawerTile(
                  context,
                  Icons.settings_outlined,
                  'Settings',
                  false,
                  () {
                    Navigator.pop(context);
                    // TODO: Navigate to settings
                  },
                  colorScheme,
                ),
                _buildDrawerTile(
                  context,
                  Icons.help_outline,
                  'Help & Support',
                  false,
                  () {
                    Navigator.pop(context);
                    // TODO: Navigate to help
                  },
                  colorScheme,
                ),
                _buildDrawerTile(
                  context,
                  Icons.logout_outlined,
                  'Logout',
                  false,
                  () async {
                    Navigator.pop(context);
                    await AuthService.instance.logout();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const SignInScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  },
                  colorScheme,
                  isDestructive: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerInfoRow(IconData icon, String label, String value, ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Gap(2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerTile(
    BuildContext context,
    IconData icon,
    String title,
    bool isSelected,
    VoidCallback onTap,
    ColorScheme colorScheme, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected
              ? colorScheme.onPrimaryContainer
              : isDestructive
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isDestructive
              ? colorScheme.error
              : isSelected
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant,
        ),
      ),
      selected: isSelected,
      selectedTileColor: colorScheme.primaryContainer.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onTap: onTap,
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: colorScheme.onPrimaryContainer,
          ),
          const Gap(6),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, Color color, int count, String sectionKey) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showSectionOverlay(sectionKey),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 18 : 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: isMobile ? 28 : 24),
              ),
              const Gap(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: isMobile ? 16 : 14,
                      ),
                    ),
                    const Gap(4),
                    Text(
                      '$count records',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: isMobile ? 13 : 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 8, vertical: isMobile ? 6 : 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSectionOverlay(String sectionKey) {
    setState(() {
      _selectedSection = sectionKey;
      _showOverlay = true;
    });
  }

  void _hideOverlay() {
    setState(() {
      _showOverlay = false;
      _selectedSection = null;
    });
  }

  void _toggleTabSection() {
    setState(() {
      _isTabSectionExpanded = !_isTabSectionExpanded;
    });
  }

  Future<void> _generateAndPrintPDF(String section) async {
    try {
      final pdf = pw.Document();
      
      // Get filtered data for the section
      List<dynamic> sectionData = [];
      switch (section) {
        case 'vitals':
          sectionData = _filterVitals(_vitalsSearchController.text);
          break;
        case 'opd':
          sectionData = _filterOPD(_opdSearchController.text);
          break;
        case 'ipd':
          sectionData = _filterIPD(_ipdSearchController.text);
          break;
        case 'labs':
          sectionData = _filterLabs(_labsSearchController.text);
          break;
        case 'radiology':
          sectionData = _filterRadiology(_radiologySearchController.text);
          break;
        case 'surgery':
          sectionData = _filterSurgery(_surgerySearchController.text);
          break;
      }

      // Build PDF content
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header with patient details
              _buildPDFHeader(),
              pw.SizedBox(height: 20),
              
              // Section title
              pw.Text(
                _getSectionTitle(section),
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              
              // Section data table
              _buildPDFTable(section, sectionData),
            ];
          },
        ),
      );

      // Print the PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: '${_patient?['name'] ?? 'Patient'}_${_getSectionTitle(section)}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Widget _buildPDFHeader() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
        pw.Text(
          'PATIENT MEDICAL RECORD',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Patient Name: ${_patient?['name'] ?? 'N/A'}'),
                  pw.Text('MRN: ${_patient?['mrn'] ?? 'N/A'}'),
                  pw.Text('Gender: ${_patient?['gender'] ?? 'N/A'}'),
                  pw.Text('Age: ${_patient?['age'] ?? 'N/A'} years'),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Blood Type: ${_patient?['bloodType'] ?? 'N/A'}'),
                  pw.Text('Last Visit: ${_patient?['lastVisit'] ?? 'N/A'}'),
                  pw.Text('Generated: ${DateTime.now().toString().split('.')[0]}'),
                ],
              ),
            ),
          ],
        ),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _buildPDFTable(String section, List<dynamic> data) {
    if (data.isEmpty) {
      return pw.Text('No data available for this section.');
    }

    // Define columns based on section
    List<String> columns = [];
    switch (section) {
      case 'vitals':
        columns = ['Date/Time', 'Blood Pressure', 'Heart Rate', 'Temperature', 'Location'];
        break;
      case 'opd':
        columns = ['Date', 'Department', 'Chief Complaint', 'Physician', 'Treatment'];
        break;
      case 'ipd':
        columns = ['Admit Date', 'Discharge Date', 'Diagnosis', 'Physician', 'Outcome'];
        break;
      case 'labs':
        columns = ['Date', 'Test Name', 'Result', 'Status', 'Ordered By'];
        break;
      case 'radiology':
        columns = ['Date', 'Procedure', 'Findings', 'Impression', 'Radiologist'];
        break;
      case 'surgery':
        columns = ['Date', 'Procedure', 'Surgeon', 'Outcome', 'Complications'];
        break;
    }

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        for (int i = 0; i < columns.length; i++)
          i: const pw.FlexColumnWidth(1),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: columns.map((col) => pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(
              col,
              style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          )).toList(),
        ),
        // Data rows
        ...data.map((item) => pw.TableRow(
          children: _getPDFRowData(section, item).map((cell) => pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Text(cell, style: const pw.TextStyle(fontSize: 10)),
          )).toList(),
        )).toList(),
      ],
    );
  }

  List<String> _getPDFRowData(String section, dynamic item) {
    switch (section) {
      case 'vitals':
        return [
          (item['dateTime'] ?? '').toString(),
          (item['bloodPressure'] ?? '').toString(),
          (item['heartRate'] ?? '').toString(),
          (item['temperature'] ?? '').toString(),
          (item['location'] ?? '').toString(),
        ];
      case 'opd':
        return [
          (item['date'] ?? '').toString(),
          (item['department'] ?? '').toString(),
          (item['chiefComplaint'] ?? '').toString(),
          (item['provider'] ?? '').toString(),
          (item['treatment'] ?? '').toString(),
        ];
      case 'ipd':
        return [
          (item['admissionDate'] ?? '').toString(),
          (item['dischargeDate'] ?? '').toString(),
          (item['diagnosis'] ?? '').toString(),
          (item['physician'] ?? '').toString(),
          (item['outcome'] ?? '').toString(),
        ];
      case 'labs':
        return [
          (item['date'] ?? '').toString(),
          (item['test'] ?? '').toString(),
          (item['result'] ?? '').toString(),
          (item['status'] ?? '').toString(),
          (item['orderedBy'] ?? '').toString(),
        ];
      case 'radiology':
        return [
          (item['date'] ?? '').toString(),
          (item['procedure'] ?? '').toString(),
          (item['findings'] ?? '').toString(),
          (item['impression'] ?? '').toString(),
          (item['radiologist'] ?? '').toString(),
        ];
      case 'surgery':
        return [
          (item['date'] ?? '').toString(),
          (item['procedure'] ?? '').toString(),
          (item['surgeon'] ?? '').toString(),
          (item['outcome'] ?? '').toString(),
          (item['complications'] ?? '').toString(),
        ];
      default:
        return ['Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown'];
    }
  }

  // Search filtering helper methods
  List<dynamic> _filterVitals(String query) {
    if (query.isEmpty) return _vitals ?? [];
    return (_vitals ?? []).where((vital) {
      final searchText = query.toLowerCase();
      return (vital['dateTime'] ?? '').toString().toLowerCase().contains(searchText) ||
             (vital['bloodPressure'] ?? '').toString().toLowerCase().contains(searchText) ||
             (vital['heartRate'] ?? '').toString().toLowerCase().contains(searchText) ||
             (vital['temperature'] ?? '').toString().toLowerCase().contains(searchText) ||
             (vital['location'] ?? '').toString().toLowerCase().contains(searchText);
    }).toList();
  }

  List<dynamic> _filterMedications(String query) {
    if (query.isEmpty) return _medications ?? [];
    return (_medications ?? []).where((med) {
      final searchText = query.toLowerCase();
      return (med['medication'] ?? '').toString().toLowerCase().contains(searchText) ||
             (med['dosage'] ?? '').toString().toLowerCase().contains(searchText) ||
             (med['indication'] ?? '').toString().toLowerCase().contains(searchText) ||
             (med['prescriber'] ?? '').toString().toLowerCase().contains(searchText);
    }).toList();
  }

  List<dynamic> _filterOPD(String query) {
    if (query.isEmpty) return _opd ?? [];
    return (_opd ?? []).where((record) {
      final searchText = query.toLowerCase();
      return (record['date'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['department'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['chiefComplaint'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['diagnosis'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['provider'] ?? '').toString().toLowerCase().contains(searchText);
    }).toList();
  }

  List<dynamic> _filterIPD(String query) {
    if (query.isEmpty) return _ipd ?? [];
    return (_ipd ?? []).where((record) {
      final searchText = query.toLowerCase();
      return (record['admissionDate'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['dischargeDate'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['diagnosis'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['physician'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['reason'] ?? '').toString().toLowerCase().contains(searchText);
    }).toList();
  }

  List<dynamic> _filterLabs(String query) {
    if (query.isEmpty) return _labs ?? [];
    return (_labs ?? []).where((lab) {
      final searchText = query.toLowerCase();
      return (lab['date'] ?? '').toString().toLowerCase().contains(searchText) ||
             (lab['test'] ?? '').toString().toLowerCase().contains(searchText) ||
             (lab['result'] ?? '').toString().toLowerCase().contains(searchText) ||
             (lab['status'] ?? '').toString().toLowerCase().contains(searchText) ||
             (lab['orderedBy'] ?? '').toString().toLowerCase().contains(searchText);
    }).toList();
  }

  List<dynamic> _filterRadiology(String query) {
    if (query.isEmpty) return _radiology ?? [];
    return (_radiology ?? []).where((record) {
      final searchText = query.toLowerCase();
      return (record['date'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['procedure'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['findings'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['impression'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['radiologist'] ?? '').toString().toLowerCase().contains(searchText);
    }).toList();
  }

  List<dynamic> _filterSurgery(String query) {
    if (query.isEmpty) return _surgery ?? [];
    return (_surgery ?? []).where((record) {
      final searchText = query.toLowerCase();
      return (record['date'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['procedure'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['surgeon'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['outcome'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['complications'] ?? '').toString().toLowerCase().contains(searchText);
    }).toList();
  }

  Widget _buildSectionOverlay() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: isMobile
          ? Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.white,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _getSectionColor(_selectedSection!).withValues(alpha: 0.1),
                          _getSectionColor(_selectedSection!).withValues(alpha: 0.05),
                        ],
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: _getSectionColor(_selectedSection!).withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _getSectionColor(_selectedSection!),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getSectionIcon(_selectedSection!),
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getSectionTitle(_selectedSection!),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const Gap(2),
                              Text(
                                '${_getDataCount(_selectedSection!)} records',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _generateAndPrintPDF(_selectedSection!),
                              icon: const Icon(Icons.print_rounded),
                              tooltip: 'Print PDF',
                              color: Colors.green.shade600,
                            ),
                            IconButton(
                              onPressed: _hideOverlay,
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Close',
                              color: Colors.grey.shade600,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          children: [
                            // Search bar for modal
                            Container(
                              padding: const EdgeInsets.all(12),
                              child: TextField(
                                controller: _getSearchController(_selectedSection!),
                                onChanged: (value) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'Search ${_getSectionTitle(_selectedSection!).toLowerCase()}...',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _getSearchController(_selectedSection!)?.text.isNotEmpty == true
                                      ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _getSearchController(_selectedSection!)?.clear();
                                            setState(() {});
                                          },
                                        )
                                      : null,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ),
                            // Content area
                            Expanded(
                              child: _buildSectionContent(_selectedSection!),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.8,
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _getSectionColor(_selectedSection!).withValues(alpha: 0.1),
                            _getSectionColor(_selectedSection!).withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: _getSectionColor(_selectedSection!).withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _getSectionColor(_selectedSection!),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: _getSectionColor(_selectedSection!).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              _getSectionIcon(_selectedSection!),
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const Gap(16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getSectionTitle(_selectedSection!),
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const Gap(4),
                                Text(
                                  '${_getDataCount(_selectedSection!)} records found',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.green.shade600,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  onPressed: () => _generateAndPrintPDF(_selectedSection!),
                                  icon: const Icon(Icons.print_rounded),
                                  tooltip: 'Print PDF',
                                  color: Colors.white,
                                ),
                              ),
                              const Gap(8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  onPressed: _hideOverlay,
                                  icon: const Icon(Icons.close_rounded),
                                  tooltip: 'Close',
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            children: [
                              // Search bar for modal
                              Container(
                                padding: const EdgeInsets.all(16),
                                child: TextField(
                                  controller: _getSearchController(_selectedSection!),
                                  onChanged: (value) => setState(() {}),
                                  decoration: InputDecoration(
                                    hintText: 'Search ${_getSectionTitle(_selectedSection!).toLowerCase()}...',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: _getSearchController(_selectedSection!)?.text.isNotEmpty == true
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              _getSearchController(_selectedSection!)?.clear();
                                              setState(() {});
                                            },
                                          )
                                        : null,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                              ),
                              // Content area
                              Expanded(
                                child: _buildSectionContent(_selectedSection!),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  IconData _getSectionIcon(String section) {
    switch (section) {
      case 'vitals':
        return Icons.favorite;
      case 'opd':
        return Icons.meeting_room_outlined;
      case 'ipd':
        return Icons.local_hospital_outlined;
      case 'labs':
        return Icons.biotech_outlined;
      case 'radiology':
        return Icons.image_search_outlined;
      case 'surgery':
        return Icons.health_and_safety_outlined;
      default:
        return Icons.info;
    }
  }

  Color _getSectionColor(String section) {
    switch (section) {
      case 'vitals':
        return Colors.red;
      case 'opd':
        return Colors.indigo;
      case 'ipd':
        return Colors.teal;
      case 'labs':
        return Colors.orange;
      case 'radiology':
        return Colors.cyan;
      case 'surgery':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  String _getSectionTitle(String section) {
    switch (section) {
      case 'vitals':
        return 'Vital Signs';
      case 'opd':
        return 'OPD Visits';
      case 'ipd':
        return 'IPD Admissions';
      case 'labs':
        return 'Lab Results';
      case 'radiology':
        return 'Radiology';
      case 'surgery':
        return 'Surgery';
      default:
        return 'Section Details';
    }
  }

  int _getDataCount(String section) {
    switch (section) {
      case 'vitals':
        return _vitals?.length ?? 0;
      case 'opd':
        return _opd?.length ?? 0;
      case 'ipd':
        return _ipd?.length ?? 0;
      case 'labs':
        return _labs?.length ?? 0;
      case 'radiology':
        return _radiology?.length ?? 0;
      case 'surgery':
        return _surgery?.length ?? 0;
      default:
        return 0;
    }
  }

  TextEditingController? _getSearchController(String section) {
    switch (section) {
      case 'vitals':
        return _vitalsSearchController;
      case 'opd':
        return _opdSearchController;
      case 'ipd':
        return _ipdSearchController;
      case 'labs':
        return _labsSearchController;
      case 'radiology':
        return _radiologySearchController;
      case 'surgery':
        return _surgerySearchController;
      default:
        return null;
    }
  }

  Widget _buildSectionContent(String section) {
    List<dynamic>? data;
    List<String> columns = [];
    List<DataColumn> dataColumns = [];
    TextEditingController? searchController;

    switch (section) {
      case 'vitals':
        data = _vitals;
        searchController = _vitalsSearchController;
        columns = ['Date/Time', 'Blood Pressure', 'Heart Rate', 'Temperature', 'Respiratory Rate', 'SpO2', 'Weight', 'BMI', 'Location'];
        dataColumns = columns.map((col) => DataColumn(
          label: Text(col, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        )).toList();
        break;
      case 'medications':
        data = _medications;
        searchController = _medicationsSearchController;
        columns = ['Start Date', 'Medication', 'Dosage', 'Frequency', 'Indication', 'Status', 'Prescriber'];
        dataColumns = columns.map((col) => DataColumn(
          label: Text(col, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        )).toList();
        break;
      case 'opd':
        data = _opd;
        searchController = _opdSearchController;
        columns = ['Date', 'Department', 'Chief Complaint', 'Physician', 'Treatment'];
        dataColumns = columns.map((col) => DataColumn(
          label: Text(col, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        )).toList();
        break;
      case 'ipd':
        data = _ipd;
        searchController = _ipdSearchController;
        columns = ['Admit Date', 'Discharge Date', 'Length of Stay', 'Diagnosis', 'Attending Physician', 'Outcome'];
        dataColumns = columns.map((col) => DataColumn(
          label: Text(col, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        )).toList();
        break;
      case 'labs':
        data = _labs;
        searchController = _labsSearchController;
        columns = ['Date', 'Test Name', 'Result', 'Reference Range', 'Status', 'Ordered By'];
        dataColumns = columns.map((col) => DataColumn(
          label: Text(col, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        )).toList();
        break;
      case 'radiology':
        data = _radiology;
        searchController = _radiologySearchController;
        columns = ['Date', 'Procedure', 'Findings', 'Impression', 'Radiologist'];
        dataColumns = columns.map((col) => DataColumn(
          label: Text(col, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        )).toList();
        break;
      case 'surgery':
        data = _surgery;
        searchController = _surgerySearchController;
        columns = ['Date', 'Procedure', 'Surgeon', 'Outcome', 'Complications'];
        dataColumns = columns.map((col) => DataColumn(
          label: Text(col, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        )).toList();
        break;
    }

    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Apply search filter if available
    List<dynamic> filteredData = data;
    if (searchController != null) {
      switch (section) {
        case 'vitals':
          filteredData = _filterVitals(searchController.text);
          break;
        case 'medications':
          filteredData = _filterMedications(searchController.text);
          break;
        case 'opd':
          filteredData = _filterOPD(searchController.text);
          break;
        case 'ipd':
          filteredData = _filterIPD(searchController.text);
          break;
        case 'labs':
          filteredData = _filterLabs(searchController.text);
          break;
        case 'radiology':
          filteredData = _filterRadiology(searchController.text);
          break;
        case 'surgery':
          filteredData = _filterSurgery(searchController.text);
          break;
      }
    }

    if (filteredData.isEmpty) {
      
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _getSectionColor(section).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _getSectionIcon(section),
                  size: 48,
                  color: _getSectionColor(section).withValues(alpha: 0.6),
                ),
              ),
              const Gap(24),
              Text(
                searchController?.text.isNotEmpty == true
                    ? 'No ${_getSectionTitle(section).toLowerCase()} found matching "${searchController!.text}"'
                    : 'No ${_getSectionTitle(section).toLowerCase()} found',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(12),
              Text(
                searchController?.text.isNotEmpty == true
                    ? 'Try adjusting your search terms or clear the search to see all records.'
                    : 'There are currently no records available for this section.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey.shade500,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
      ),
    );
  }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 24,
          horizontalMargin: 20,
          headingRowHeight: 60,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 72,
          headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
          columns: dataColumns,
          rows: filteredData.asMap().entries.map((entry) {
            int index = entry.key;
            dynamic item = entry.value;
            List<String> rowData = _getRowData(section, item);
            
    return DataRow(
              color: MaterialStateProperty.all(
                index % 2 == 0 ? Colors.white : Colors.grey.shade50,
              ),
              cells: rowData.map((cell) => DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Text(
                    cell.isEmpty ? '-' : cell,
                    style: TextStyle(
                      fontSize: 14,
                      color: cell.isEmpty ? Colors.grey.shade400 : Colors.grey.shade900,
                      fontWeight: cell.isEmpty ? FontWeight.normal : FontWeight.w500,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )).toList(),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<String> _getRowData(String section, dynamic item) {
    switch (section) {
      case 'vitals':
        return [
          (item['dateTime'] ?? '').toString(),
          (item['bloodPressure'] ?? '').toString(),
          (item['heartRate'] ?? '').toString(),
          (item['temperature'] ?? '').toString(),
          (item['respiratoryRate'] ?? '').toString(),
          (item['spO2'] ?? '').toString(),
          (item['weight'] ?? '').toString(),
          (item['bmi'] ?? '').toString(),
          (item['location'] ?? '').toString(),
        ];
      case 'medications':
        return [
          (item['startDate'] ?? '').toString(),
          (item['medication'] ?? '').toString(),
          (item['dosage'] ?? '').toString(),
          (item['frequency'] ?? '').toString(),
          (item['indication'] ?? '').toString(),
          (item['status'] ?? '').toString(),
          (item['prescriber'] ?? '').toString(),
        ];
      case 'opd':
        return [
          (item['date'] ?? '').toString(),
          (item['department'] ?? '').toString(),
          (item['chiefComplaint'] ?? '').toString(),
          (item['provider'] ?? '').toString(),
          (item['treatment'] ?? '').toString(),
        ];
      case 'ipd':
        return [
          (item['admissionDate'] ?? '').toString(),
          (item['dischargeDate'] ?? '').toString(),
          (item['lengthOfStay'] ?? '').toString(),
          (item['diagnosis'] ?? '').toString(),
          (item['physician'] ?? '').toString(),
          (item['outcome'] ?? '').toString(),
        ];
      case 'labs':
        return [
          (item['date'] ?? '').toString(),
          (item['test'] ?? '').toString(),
          (item['result'] ?? '').toString(),
          (item['normalRange'] ?? '').toString(),
          (item['status'] ?? '').toString(),
          (item['orderedBy'] ?? '').toString(),
        ];
      case 'radiology':
        return [
          (item['date'] ?? '').toString(),
          (item['procedure'] ?? '').toString(),
          (item['findings'] ?? '').toString(),
          (item['impression'] ?? '').toString(),
          (item['radiologist'] ?? '').toString(),
        ];
      case 'surgery':
        return [
          (item['date'] ?? '').toString(),
          (item['procedure'] ?? '').toString(),
          (item['surgeon'] ?? '').toString(),
          (item['outcome'] ?? '').toString(),
          (item['complications'] ?? '').toString(),
        ];
      default:
        return [];
    }
  }

  Widget _buildAlertCard(String title, String content, Color color, IconData icon, String count) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const Gap(8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title: $content',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleTabSection() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
      child: Column(
        children: [
          // Collapsible Tab Section
          Container(
            height: _isTabSectionExpanded 
                ? (isMobile ? MediaQuery.of(context).size.height * 0.75 : MediaQuery.of(context).size.height * 0.7)
                : (isMobile ? 200 : 220),
            child: Container(
              color: Colors.white,
              child: _isTabSectionExpanded 
                ? Column(
                    children: [
                      // Navigation Tabs
                      _buildTabBar(),
                      // Content Area
                      Expanded(child: _buildTabBarView()),
                      // Space for toggle button
                      SizedBox(height: isMobile ? 50 : 40),
                    ],
                  )
                : Stack(
                    children: [
                      // Make the card scrollable to prevent overflow
                      SingleChildScrollView(
                        child: _buildSummaryCard(),
                      ),
                      // Button positioned at bottom of collapsed section
                      Positioned(
                        bottom: 10,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: _buildToggleButton(),
                        ),
                      ),
                    ],
                  ),
            ),
          ),
          
          // Medical Record Section Cards (shown only when collapsed)
          if (!_isTabSectionExpanded) ...[
            Gap(isMobile ? 12 : 16),
            _buildMedicalRecordCards(),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicalRecordCards() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: isMobile
          ? Column(
              children: [
                _buildSectionCard('Vitals', Icons.favorite, Colors.red, _vitals?.length ?? 0, 'vitals'),
                const Gap(12),
                _buildSectionCard('OPD Visits', Icons.meeting_room_outlined, Colors.indigo, _opd?.length ?? 0, 'opd'),
                const Gap(12),
                _buildSectionCard('IPD Admissions', Icons.local_hospital_outlined, Colors.teal, _ipd?.length ?? 0, 'ipd'),
                const Gap(12),
                _buildSectionCard('Lab Results', Icons.biotech_outlined, Colors.orange, _labs?.length ?? 0, 'labs'),
                const Gap(12),
                _buildSectionCard('Radiology', Icons.image_search_outlined, Colors.cyan, _radiology?.length ?? 0, 'radiology'),
                const Gap(12),
                _buildSectionCard('Surgery', Icons.health_and_safety_outlined, Colors.red, _surgery?.length ?? 0, 'surgery'),
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSectionCard('Vitals', Icons.favorite, Colors.red, _vitals?.length ?? 0, 'vitals')),
                    const Gap(16),
                    Expanded(child: _buildSectionCard('OPD Visits', Icons.meeting_room_outlined, Colors.indigo, _opd?.length ?? 0, 'opd')),
                    const Gap(16),
                    Expanded(child: _buildSectionCard('IPD Admissions', Icons.local_hospital_outlined, Colors.teal, _ipd?.length ?? 0, 'ipd')),
                  ],
                ),
                const Gap(20),
                Row(
                  children: [
                    Expanded(child: _buildSectionCard('Lab Results', Icons.biotech_outlined, Colors.orange, _labs?.length ?? 0, 'labs')),
                    const Gap(16),
                    Expanded(child: _buildSectionCard('Radiology', Icons.image_search_outlined, Colors.cyan, _radiology?.length ?? 0, 'radiology')),
                    const Gap(16),
                    Expanded(child: _buildSectionCard('Surgery', Icons.health_and_safety_outlined, Colors.red, _surgery?.length ?? 0, 'surgery')),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.medical_services_rounded,
                    color: Colors.green.shade700,
                    size: 28,
                  ),
                  const Gap(12),
                  Expanded(
                    child: Text(
                      'Detailed Records',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(8),
              Text(
                'Access comprehensive medical records including vitals, medications, lab results, and more.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.green.shade700,
                  height: 1.4,
                ),
              ),
              const Gap(8),
              // First row of summary items
              Row(
                children: [
                  _buildSummaryItem('Vitals', _vitals?.length ?? 0, Icons.favorite, Colors.red),
                  const Gap(12),
                  _buildSummaryItem('Medications', _medications?.length ?? 0, Icons.medication, Colors.green),
                  const Gap(12),
                  _buildSummaryItem('OPD', _opd?.length ?? 0, Icons.meeting_room_outlined, Colors.indigo),
                ],
              ),
              const Gap(6),
              // Second row of summary items
              Row(
                children: [
                  _buildSummaryItem('IPD', _ipd?.length ?? 0, Icons.local_hospital_outlined, Colors.teal),
                  const Gap(12),
                  _buildSummaryItem('Labs', _labs?.length ?? 0, Icons.biotech_outlined, Colors.orange),
                  const Gap(12),
                  _buildSummaryItem('Radiology', _radiology?.length ?? 0, Icons.image_search_outlined, Colors.cyan),
                ],
              ),
              const Gap(6),
              // Third row of summary items
              Row(
                children: [
                  _buildSummaryItem('Surgery', _surgery?.length ?? 0, Icons.health_and_safety_outlined, Colors.red),
                  const Spacer(),
                ],
              ),
              // Add bottom padding to ensure content doesn't get cut off
              const Gap(8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, int count, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const Gap(3),
        Text(
          '$count $title',
              style: TextStyle(
            color: Colors.green.shade700,
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.green,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: Colors.green,
        labelPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 12),
        labelStyle: TextStyle(
          fontSize: isMobile ? 14 : 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: isMobile ? 14 : 13,
        ),
        tabAlignment: isMobile ? TabAlignment.start : TabAlignment.center,
        tabs: const [
          Tab(text: 'Vitals'),
          Tab(text: 'Medications'),
          Tab(text: 'OPD'),
          Tab(text: 'IPD'),
          Tab(text: 'Labs'),
          Tab(text: 'Radiology'),
          Tab(text: 'Surgery'),
        ],
      ),
    );
  }


  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildVitalsTab(),
        _buildMedicationsTab(),
        _buildOPDTab(),
        _buildIPDTab(),
        _buildLabsTab(),
        _buildRadiologyTab(),
        _buildSurgeryTab(),
      ],
    );
  }

  Widget _buildToggleButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleTabSection,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              _isTabSectionExpanded 
                  ? Icons.keyboard_arrow_up_rounded 
                  : Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinnedToggleButton() {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: _buildToggleButton(),
      ),
    );
  }

  Widget _buildVitalsTab() {
    return _buildGenericTab(
      title: 'Vital Signs',
      icon: Icons.favorite,
      heroColor: Colors.red,
      searchController: _vitalsSearchController,
      searchHint: 'Search vitals by date, BP, HR, temperature, or location...',
      approxMinColWidth: 100,
      columns: const [
        DataColumn(label: Text('Date/Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Blood Pressure', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Heart Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Temperature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Respiratory Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('SpO2', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Weight', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('BMI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      ],
      data: _vitals,
      filterFunction: _filterVitals,
      noDataMessage: 'No vitals data available',
    );
  }


  Widget _buildMedicationsTab() {
    return _buildGenericTab(
      title: 'Medications',
      icon: Icons.medication,
      heroColor: Colors.green,
      searchController: _medicationsSearchController,
      searchHint: 'Search medications by name, dosage, indication, or prescriber...',
      approxMinColWidth: 100,
      columns: const [
        DataColumn(label: Text('Start Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Medication', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Dosage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Frequency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Indication', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Prescriber', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      ],
      data: _medications,
      filterFunction: _filterMedications,
      noDataMessage: 'No medications data available',
    );
  }

  Widget _buildOPDTab() {
    return _buildGenericTab(
      title: 'OPD Visits',
      icon: Icons.meeting_room_outlined,
      heroColor: Colors.indigo,
      searchController: _opdSearchController,
      searchHint: 'Search OPD visits by date, department, complaint, or physician...',
      approxMinColWidth: 120,
      columns: const [
        DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Chief Complaint', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Physician', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Treatment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      ],
      data: _opd,
      filterFunction: _filterOPD,
      noDataMessage: 'No OPD data available',
    );
  }

  Widget _buildIPDTab() {
    return _buildGenericTab(
      title: 'IPD Admissions',
      icon: Icons.local_hospital_outlined,
      heroColor: Colors.teal,
      searchController: _ipdSearchController,
      searchHint: 'Search IPD admissions by date, diagnosis, or physician...',
      approxMinColWidth: 120,
      columns: const [
        DataColumn(label: Text('Admit Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Discharge Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Length of Stay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Diagnosis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Attending Physician', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Outcome', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      ],
      data: _ipd,
      filterFunction: _filterIPD,
      noDataMessage: 'No IPD data available',
    );
  }

  Widget _buildLabsTab() {
    return _buildGenericTab(
      title: 'Lab Results',
      icon: Icons.biotech_outlined,
      heroColor: Colors.orange,
      searchController: _labsSearchController,
      searchHint: 'Search labs by test name, result, status, or ordered by...',
      approxMinColWidth: 110,
      columns: const [
        DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Test Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Result', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Reference Range', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Ordered By', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      ],
      data: _labs,
      filterFunction: _filterLabs,
      noDataMessage: 'No lab data available',
    );
  }

  Widget _buildRadiologyTab() {
    return _buildGenericTab(
      title: 'Radiology',
      icon: Icons.image_search_outlined,
      heroColor: Colors.cyan,
      searchController: _radiologySearchController,
      searchHint: 'Search radiology by procedure, findings, impression, or radiologist...',
      approxMinColWidth: 120,
      columns: const [
        DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Procedure', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Findings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Impression', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Radiologist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      ],
      data: _radiology,
      filterFunction: _filterRadiology,
      noDataMessage: 'No radiology data available',
    );
  }

  Widget _buildSurgeryTab() {
    return _buildGenericTab(
      title: 'Surgery',
      icon: Icons.health_and_safety_outlined,
      heroColor: Colors.red,
      searchController: _surgerySearchController,
      searchHint: 'Search surgeries by procedure, surgeon, outcome, or complications...',
      approxMinColWidth: 120,
      columns: const [
        DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Procedure', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Surgeon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Outcome', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Complications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      ],
      data: _surgery,
      filterFunction: _filterSurgery,
      noDataMessage: 'No surgery data available',
    );
  }

  // Generic builder to copy Vital Signs style
  Widget _buildGenericTab({
    required String title,
    required IconData icon,
    required Color heroColor,
    required String searchHint,
    required double approxMinColWidth,
    required List<DataColumn> columns,
    List<DataRow>? rows,
    TextEditingController? searchController,
    List<dynamic>? data,
    List<dynamic> Function(String)? filterFunction,
    String? noDataMessage,
  }) {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: searchController,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText: searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController != null && searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: double.infinity,
      padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Icon(icon, color: heroColor),
                          const Gap(8),
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final int columnCount = columns.length;
                          final double dynamicSpacing = ((constraints.maxWidth - (approxMinColWidth * columnCount)) / (columnCount - 1)).clamp(24, 120);
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                                columnSpacing: dynamicSpacing,
                                horizontalMargin: 16,
                                headingRowHeight: 56,
                                dataRowMinHeight: 48,
                                dataRowMaxHeight: 64,
                                headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                                columns: columns,
                                rows: () {
                                  if (filterFunction != null && searchController != null && data != null) {
                                    final filteredData = filterFunction(searchController.text);
                                    // Create empty cells to match the number of columns
                                    final emptyCells = List.filled(columns.length - 1, '-');
                                    if (data.isEmpty) {
                                      return [
                                        _buildEnhancedDataRow([noDataMessage ?? 'No data available', ...emptyCells]),
                                      ];
                                    } else if (filteredData.isEmpty && searchController.text.isNotEmpty) {
                                      return [
                                        _buildEnhancedDataRow(['No results found matching "${searchController.text}"', ...emptyCells]),
                                      ];
                                    } else {
                                      return filteredData.map((item) {
                                        // Extract data based on the section type
                                        if (title == 'Vital Signs') {
                                          final dateTime = (item['dateTime'] ?? '').toString();
                                          final bp = (item['bloodPressure'] ?? '').toString();
                                          final hr = (item['heartRate'] ?? '').toString();
                                          final temp = (item['temperature'] ?? '').toString();
                                          final rr = (item['respiratoryRate'] ?? '').toString();
                                          final spo2 = (item['spO2'] ?? '').toString();
                                          final weight = (item['weight'] ?? '').toString();
                                          final bmi = (item['bmi'] ?? '').toString();
                                          final location = (item['location'] ?? '').toString();
                                          
                                          // Ensure exactly 9 cells to match the 9 header columns
                                          return _buildEnhancedDataRow([
                                            dateTime,
                                            bp,
                                            hr,
                                            temp,
                                            rr,
                                            spo2,
                                            weight,
                                            bmi,
                                            location,
                                          ]);
                                        } else if (title == 'Medications') {
                                          final medication = (item['medication'] ?? '').toString();
                                          final dosage = (item['dosage'] ?? '').toString();
                                          final frequency = (item['frequency'] ?? '').toString();
                                          final status = (item['status'] ?? '').toString();
                                          final prescriber = (item['prescriber'] ?? '').toString();
                                          final startDate = (item['startDate'] ?? '').toString();
                                          final indication = (item['indication'] ?? '').toString();
                                          
                                        return _buildEnhancedDataRow([
                                          startDate,
                                          medication,
                                          dosage,
                                          frequency,
                                          indication,
                                          status,
                                          prescriber,
                                        ]);
                                        } else if (title == 'OPD Visits') {
                                          final date = (item['date'] ?? '').toString();
                                          final department = (item['department'] ?? '').toString();
                                          final chiefComplaint = (item['chiefComplaint'] ?? '').toString();
                                          final provider = (item['provider'] ?? '').toString();
                                          final treatment = (item['treatment'] ?? '').toString();
                                          
                                          return _buildEnhancedDataRow([
                                            date,
                                            department,
                                            chiefComplaint,
                                            provider,
                                            treatment,
                                          ]);
                                        } else if (title == 'IPD Admissions') {
                                          final admissionDate = (item['admissionDate'] ?? '').toString();
                                          final dischargeDate = (item['dischargeDate'] ?? '').toString();
                                          final lengthOfStay = (item['lengthOfStay'] ?? '').toString();
                                          final diagnosis = (item['diagnosis'] ?? '').toString();
                                          final physician = (item['physician'] ?? '').toString();
                                          final outcome = (item['outcome'] ?? '').toString();
                                          
                                          return _buildEnhancedDataRow([
                                            admissionDate,
                                            dischargeDate,
                                            lengthOfStay,
                                            diagnosis,
                                            physician,
                                            outcome,
                                          ]);
                                        } else if (title == 'Lab Results') {
                                          final date = (item['date'] ?? '').toString();
                                          final test = (item['test'] ?? '').toString();
                                          final result = (item['result'] ?? '').toString();
                                          final normalRange = (item['normalRange'] ?? '').toString();
                                          final status = (item['status'] ?? '').toString();
                                          final orderedBy = (item['orderedBy'] ?? '').toString();
                                          
                                          return _buildEnhancedDataRow([
                                            date,
                                            test,
                                            result,
                                            normalRange,
                                            status,
                                            orderedBy,
                                          ]);
                                        } else if (title == 'Radiology') {
                                          final date = (item['date'] ?? '').toString();
                                          final procedure = (item['procedure'] ?? '').toString();
                                          final findings = (item['findings'] ?? '').toString();
                                          final impression = (item['impression'] ?? '').toString();
                                          final radiologist = (item['radiologist'] ?? '').toString();
                                          
                                          return _buildEnhancedDataRow([
                                            date,
                                            procedure,
                                            findings,
                                            impression,
                                            radiologist,
                                          ]);
                                        } else if (title == 'Surgery') {
                                          final date = (item['date'] ?? '').toString();
                                          final procedure = (item['procedure'] ?? '').toString();
                                          final surgeon = (item['surgeon'] ?? '').toString();
                                          final outcome = (item['outcome'] ?? '').toString();
                                          final complications = (item['complications'] ?? '').toString();
                                          
                                          return _buildEnhancedDataRow([
                                            date,
                                            procedure,
                                            surgeon,
                                            outcome,
                                            complications,
                                          ]);
                                        }
                                        // Create empty cells to match the number of columns
                                        final emptyCells = List.filled(columns.length - 1, '-');
                                        return _buildEnhancedDataRow(['Unknown data type', ...emptyCells]);
                                      }).toList();
                                    }
                                  }
                                  return rows ?? [];
                                }(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _dataRow(List<String> texts) {
    return DataRow(
      cells: [
        for (final t in texts)
          DataCell(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                t,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
      ],
    );
  }

  DataRow _buildEnhancedDataRow(List<String> texts) {
    return DataRow(
      cells: [
        for (final t in texts)
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              child: Text(
                t.isEmpty ? '-' : t,
                style: TextStyle(
                  fontSize: 13,
                  color: t.isEmpty ? Colors.grey.shade400 : Colors.grey.shade800,
                  fontWeight: t.isEmpty ? FontWeight.normal : FontWeight.w500,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
  }

}
