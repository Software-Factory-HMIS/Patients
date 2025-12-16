import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/keyboard_inset_padding.dart';
import '../utils/emr_api_client.dart';
import '../utils/user_storage.dart';
import '../models/appointment_models.dart' show Hospital, Department, HospitalDepartment, QueueResponse, AppointmentDetails;
import 'appointment_success_screen.dart';

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
  List<dynamic>? _pregnancy;
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
    _tabController = TabController(length: 8, vsync: this);
    _initializeApi();
    _loadData();
    _loadSavedUserData();
    // Load appointments data since it's the default tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHospitals();
      _loadDepartments();
    });
  }

  Future<void> _loadSavedUserData() async {
    try {
      _savedUserData = await UserStorage.getUserData();
      if (_savedUserData != null) {
        print('✅ Loaded saved user data for appointment booking');
      }
    } catch (e) {
      print('❌ Error loading saved user data: $e');
    }
  }

  Future<void> _initializeApi() async {
    try {
      _api = await EmrApiClient.create();
    } catch (e) {
      print('❌ Failed to initialize API client: $e');
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
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    // Ensure saved user data is loaded
    if (_savedUserData == null) {
      await _loadSavedUserData();
    }
    
    // Simulate loading delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Load patient data from saved user data
    String patientName = 'Patient Name';
    String mrn = widget.cnic;
    String gender = 'N/A';
    String age = 'N/A';
    String bloodType = 'N/A';
    String lastVisit = 'N/A';
    
    if (_savedUserData != null) {
      // Get name from FullName or fullName
      patientName = _savedUserData!['FullName'] as String? ?? 
                   _savedUserData!['fullName'] as String? ?? 
                   'Patient Name';
      
      // Get MRN
      mrn = _savedUserData!['MRN'] as String? ?? 
            _savedUserData!['mrn'] as String? ?? 
            widget.cnic;
      
      // Get gender
      gender = _savedUserData!['Gender'] as String? ?? 
               _savedUserData!['gender'] as String? ?? 
               'N/A';
      
      // Calculate age from DateOfBirth
      final dateOfBirth = _savedUserData!['DateOfBirth'] ?? 
                          _savedUserData!['dateOfBirth'];
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
          print('Error calculating age: $e');
        }
      }
      
      // Get blood type
      bloodType = _savedUserData!['BloodGroup'] as String? ?? 
                  _savedUserData!['bloodGroup'] as String? ?? 
                  'N/A';
      
      // Get last visit from UpdatedDate or CreatedDate
      final updatedDate = _savedUserData!['UpdatedDate'] ?? 
                         _savedUserData!['updatedDate'];
      final createdDate = _savedUserData!['CreatedDate'] ?? 
                         _savedUserData!['createdDate'];
      if (updatedDate != null || createdDate != null) {
        try {
          DateTime? visitDate;
          if (updatedDate is DateTime) {
            visitDate = updatedDate;
          } else if (updatedDate is String) {
            visitDate = DateTime.parse(updatedDate);
          } else if (createdDate is DateTime) {
            visitDate = createdDate;
          } else if (createdDate is String) {
            visitDate = DateTime.parse(createdDate);
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
          print('Error formatting last visit: $e');
        }
      }
    }
    
    // Initialize with loaded patient data
    setState(() {
      _patient = {
        'name': patientName,
        'mrn': mrn,
        'gender': gender,
        'age': age,
        'bloodType': bloodType,
        'lastVisit': lastVisit,
      };
      _vitals = [];
      _medications = [];
      _opd = [];
      _ipd = [];
      _labs = [];
      _radiology = [];
      _surgery = [];
      _pregnancy = [];
      _loading = false;
    });
  }

  void _showDebugDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'API Debug Data',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDebugSection('MRN', widget.cnic),
                      _buildDebugSection('Patient Data', _patient),
                      _buildDebugSection('Vitals Data', _vitals),
                      _buildDebugSection('Medications Data', _medications),
                      _buildDebugSection('OPD Data', _opd),
                      _buildDebugSection('IPD Data', _ipd),
                      _buildDebugSection('Labs Data', _labs),
                      _buildDebugSection('Radiology Data', _radiology),
                      _buildDebugSection('Surgery Data', _surgery),
                      _buildDebugSection('Pregnancy Data', _pregnancy),
                      _buildDebugSection('Error', _error),
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

  Widget _buildDebugSection(String title, dynamic data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
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
          const Gap(8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              data == null
                  ? 'No data'
                  : data is String
                      ? data
                      : _formatJson(data),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatJson(dynamic data) {
    try {
      if (data is Map || data is List) {
        // Convert to pretty-printed JSON
        const encoder = JsonEncoder.withIndent('  ');
        return encoder.convert(data);
      }
      return data.toString();
    } catch (e) {
      return data.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(_currentNavIndex == 0 ? 'Appointments' : 'Patient Dashboard'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_currentNavIndex == 1) ...[
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: _showDebugDialog,
              tooltip: 'Debug API Data',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
          ),
        ],
      ),
      body: _currentNavIndex == 0
          ? _buildAppointmentsScreen()
          : Stack(
              children: [
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                                const Gap(16),
                                Text('Error loading patient data', style: Theme.of(context).textTheme.headlineSmall),
                                const Gap(8),
                                Text(_error!, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                                const Gap(16),
                                ElevatedButton(
                                  onPressed: _loadData,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : KeyboardInsetPadding(
                            child: SingleChildScrollView(
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              child: Column(
                                children: [
                                  // Patient Header Section
                                  _buildPatientHeader(),
                                  
                                  // Vertical spacing between sections (responsive)
                                  Gap(MediaQuery.of(context).size.width < 768 ? 8 : 6),
                                  
                                  // Chronic Conditions Section
                                  _buildChronicConditionsSection(),
                                  
                                  // Vertical spacing between sections (responsive)
                                  Gap(MediaQuery.of(context).size.width < 768 ? 12 : 12),
                                  
                                  // Collapsible Tab Section
                                  _buildCollapsibleTabSection(),
                                ],
                              ),
                            ),
                          ),
                // Overlay for section details
                if (_showOverlay) _buildSectionOverlay(),
                
                // Pinned toggle button (only when expanded)
                if (_isTabSectionExpanded && _currentNavIndex == 1) _buildPinnedToggleButton(),
              ],
            ),
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
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsScreen() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Text(
              'Book Appointment',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
            ),
            const Gap(8),
            Text(
              'Select a hospital and department to book your appointment',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const Gap(24),

            // Hospital Dropdown
            Text(
              'Hospital *',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Gap(8),
            _loadingHospitals
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<Hospital>(
                    value: _selectedHospital,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    hint: const Text('Select a hospital'),
                    items: _hospitals?.map((hospital) {
                      return DropdownMenuItem<Hospital>(
                        value: hospital,
                        child: Text(hospital.name),
                      );
                    }).toList(),
                    onChanged: (hospital) {
                      setState(() {
                        _selectedHospital = hospital;
                        _selectedHospitalDepartment = null; // Reset department when hospital changes
                        _hospitalDepartments = null; // Clear previous departments
                      });
                      // Load hospital departments when hospital is selected
                      if (hospital != null) {
                        _loadHospitalDepartments(hospital.hospitalID);
                      }
                    },
                  ),
            const Gap(24),

            // Department Dropdown
            Text(
              'Department *',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const Gap(8),
            _loadingHospitalDepartments
                ? const Center(child: CircularProgressIndicator())
                : IgnorePointer(
                    ignoring: _selectedHospital == null || _loadingHospitalDepartments,
                    child: Opacity(
                      opacity: _selectedHospital == null ? 0.6 : 1.0,
                      child: DropdownButtonFormField<HospitalDepartment>(
                        value: _selectedHospitalDepartment,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: _selectedHospital != null
                              ? Colors.white
                              : Colors.grey.shade100,
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
                            child: Text(hospitalDept.departmentName),
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
            const Gap(32),

            // Error Message
            if (_appointmentError != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        _appointmentError!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            if (_appointmentError != null) const Gap(16),

            // Submit Button
            ElevatedButton(
              onPressed: (_selectedHospital != null &&
                      _selectedHospitalDepartment != null &&
                      !_submittingAppointment)
                  ? _handleAppointmentSubmission
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: _submittingAppointment
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        Gap(12),
                        Text('Processing...'),
                      ],
                    )
                  : const Text(
                      'Book Appointment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const Gap(16),
          ],
        ),
      ),
    );
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
          print('⚠️ Error parsing department: $e');
          print('   Department data: $item');
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
      print('❌ Error loading departments: $e');
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
          print('⚠️ Error parsing hospital department: $e');
          print('   Hospital department data: $item');
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
      print('❌ Error loading hospital departments: $e');
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
          print('⚠️ Patient not found, attempting to register...');
          
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
          
          print('✅ Patient registered successfully with ID: $patientId');
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
      print('✅ Patient ID: $patientId');

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
      print('📋 Adding patient to queue...');
      print('   Patient ID: $patientId');
      print('   Hospital ID: ${_selectedHospital!.hospitalID}');
      print('   Hospital Department ID: ${_selectedHospitalDepartment!.hospitalDepartmentID}');
      
      final queueResponse = await _api!.addPatientToQueue(
        patientId: patientId,
        hospitalId: _selectedHospital!.hospitalID,
        hospitalDepartmentId: _selectedHospitalDepartment!.hospitalDepartmentID,
        createdBy: 1, // Default system user for patient self-registration
        priority: 'Normal',
        queueType: 'OPD',
        visitPurpose: 'Check-Up',
        patientSource: 'SELF_CHECKIN',
      );

      print('✅ Patient added to queue successfully');
      print('   Queue ID: ${queueResponse['queueId']}');
      print('   Token Number: ${queueResponse['tokenNumber']}');

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
        print('🖨️ Calling print API with queue ID: $queueId');
        receiptData = await _api!.printQueueReceipt(queueId: queueId);
        print('✅ Queue receipt data retrieved successfully');
        if (receiptData.isNotEmpty) {
          print('📄 Receipt data: $receiptData');
        }
      } catch (e) {
        print('⚠️ Failed to retrieve receipt data: $e');
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

      // Navigate to success screen with appointment details
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AppointmentSuccessScreen(
              appointment: appointmentDetails,
            ),
          ),
        );

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
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        children: [
          // Patient Profile - Full Width Card
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue.shade400, width: 2),
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
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Icon(
                                Icons.person,
                                size: 28,
                                color: Colors.blue.shade600,
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
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Icon(
                            Icons.person,
                            size: 30,
                            color: Colors.blue.shade600,
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
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade700),
          const Gap(6),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade900,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChronicConditionsSection() {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.red.shade300, width: 1),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20, vertical: isMobile ? 12 : 16),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.health_and_safety,
                            size: 20,
                            color: Colors.red.shade600,
                          ),
                          const Gap(8),
                          Text(
                            'Chronic Conditions:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const Gap(10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildSimpleConditionChip('Type 2 Diabetes', 'E11.9'),
                          _buildSimpleConditionChip('Hypertension', 'I10'),
                          _buildSimpleConditionChip('Hyperlipidemia', 'E78.2'),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Icon(
                        Icons.health_and_safety,
                        size: 20,
                        color: Colors.red.shade600,
                      ),
                      const Gap(8),
                      Text(
                        'Chronic Conditions:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                          fontSize: 15,
                        ),
                      ),
                      const Gap(8),
                      Expanded(
                        child: Row(
                          children: [
                            _buildSimpleConditionChip('Type 2 Diabetes', 'E11.9'),
                            const Gap(6),
                            _buildSimpleConditionChip('Hypertension', 'I10'),
                            const Gap(6),
                            _buildSimpleConditionChip('Hyperlipidemia', 'E78.2'),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleConditionChip(String condition, String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200, width: 1),
      ),
      child: Text(
        '$condition ($code)',
        style: TextStyle(
          color: Colors.red.shade800,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
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
      case 'pregnancy':
        return Icons.pregnant_woman;
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
      case 'pregnancy':
        return Colors.pink;
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
      case 'pregnancy':
        return 'Pregnancy Registration';
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
      case 'pregnancy':
        return _pregnancy?.length ?? 0;
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
      case 'pregnancy':
        data = _pregnancy;
        searchController = null;
        columns = ['Registration Date', 'LMP', 'EDD', 'Gravida', 'Para', 'Status'];
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
        case 'pregnancy':
          filteredData = data; // No filtering for now
          break;
      }
    }

    if (filteredData.isEmpty) {
      // Special handling for pregnancy registration
      if (section == 'pregnancy') {
        return _buildPregnancyRegistrationForm();
      }
      
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
                      _buildSummaryCard(),
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
                const Gap(12),
                _buildSectionCard('Pregnancy Registration', Icons.pregnant_woman, Colors.pink, _pregnancy?.length ?? 0, 'pregnancy'),
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
                const Gap(20),
                Row(
                  children: [
                    Expanded(child: _buildSectionCard('Pregnancy Registration', Icons.pregnant_woman, Colors.pink, _pregnancy?.length ?? 0, 'pregnancy')),
                    const Spacer(),
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
          Tab(text: 'Pregnancy'),
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
        _buildPregnancyTab(),
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

  Widget _buildPregnancyTab() {
    return _buildGenericTab(
      title: 'Pregnancy Registration',
      icon: Icons.pregnant_woman,
      heroColor: Colors.pink,
      searchController: null,
      searchHint: 'Search pregnancy records by date, LMP, EDD, or status...',
      approxMinColWidth: 120,
      columns: const [
        DataColumn(label: Text('Registration Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('LMP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('EDD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Gravida', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Para', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      ],
      data: _pregnancy,
      filterFunction: null,
      noDataMessage: 'No pregnancy records available',
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
                                    if (data.isEmpty) {
                                      return [
                                        _buildEnhancedDataRow([noDataMessage ?? 'No data available', '-', '-', '-', '-', '-', '-', '-', '-']),
                                      ];
                                    } else if (filteredData.isEmpty && searchController.text.isNotEmpty) {
                                      return [
                                        _buildEnhancedDataRow(['No results found matching "${searchController.text}"', '-', '-', '-', '-', '-', '-', '-', '-']),
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
                                        } else if (title == 'Pregnancy Registration') {
                                          final registrationDate = (item['registrationDate'] ?? '').toString();
                                          final lmp = (item['lmp'] ?? '').toString();
                                          final edd = (item['edd'] ?? '').toString();
                                          final gravida = (item['gravida'] ?? '').toString();
                                          final para = (item['para'] ?? '').toString();
                                          final status = (item['status'] ?? '').toString();
                                          
                                          return _buildEnhancedDataRow([
                                            registrationDate,
                                            lmp,
                                            edd,
                                            gravida,
                                            para,
                                            status,
                                          ]);
                                        }
                                        return _buildEnhancedDataRow(['Unknown data type', '-', '-', '-', '-', '-', '-', '-', '-']);
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

  Widget _buildPregnancyRegistrationForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.pregnant_woman,
                color: Colors.pink,
                size: 28,
              ),
              const Gap(12),
              Text(
                'Pregnancy Registration',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.pink.shade700,
                ),
              ),
            ],
          ),
          const Gap(24),
          
          // Form fields
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // LMP (Last Menstrual Period)
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Last Menstrual Period (LMP)',
                      hintText: 'DD/MM/YYYY',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const Gap(16),
                  
                  // EDD (Expected Due Date) - Auto-calculated
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Expected Due Date (EDD)',
                      hintText: 'Auto-calculated from LMP',
                      prefixIcon: const Icon(Icons.event),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    enabled: false,
                  ),
                  const Gap(16),
                  
                  // Gravida
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Gravida (Number of pregnancies)',
                      hintText: 'Enter number',
                      prefixIcon: const Icon(Icons.numbers),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const Gap(16),
                  
                  // Para
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Para (Number of births)',
                      hintText: 'Enter number',
                      prefixIcon: const Icon(Icons.child_care),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const Gap(16),
                  
                  // Pregnancy Status
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Pregnancy Status',
                      prefixIcon: const Icon(Icons.pregnant_woman),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Active')),
                      DropdownMenuItem(value: 'completed', child: Text('Completed')),
                      DropdownMenuItem(value: 'miscarriage', child: Text('Miscarriage')),
                      DropdownMenuItem(value: 'terminated', child: Text('Terminated')),
                    ],
                    onChanged: (value) {},
                  ),
                  const Gap(24),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Implement save functionality
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Pregnancy registration saved successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Register Pregnancy'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const Gap(12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // TODO: Implement clear functionality
                          },
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear Form'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.pink,
                            side: BorderSide(color: Colors.pink),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
