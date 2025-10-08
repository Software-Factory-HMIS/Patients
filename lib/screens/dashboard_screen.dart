import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../utils/keyboard_inset_padding.dart';
import '../utils/emr_api_client.dart';

class DashboardScreen extends StatefulWidget {
  final String cnic;
  
  const DashboardScreen({super.key, required this.cnic});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  late final EmrApiClient _api;
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
  bool _isTabSectionExpanded = false;
  
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
    _tabController = TabController(length: 7, vsync: this);
    _initializeApi();
  }

  Future<void> _initializeApi() async {
    _api = await EmrApiClient.create();
    _loadData();
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
    try {
      final mrn = widget.cnic; // using CNIC as MRN placeholder
      final results = await Future.wait([
        _api.fetchPatient(mrn),
        _api.fetchVitals(mrn),
        _api.fetchMedications(mrn),
        _api.fetchOPD(mrn),
        _api.fetchIPD(mrn),
        _api.fetchLabs(mrn),
        _api.fetchRadiology(mrn),
        _api.fetchSurgery(mrn),
      ]);
      setState(() {
        _patient = results[0] as Map<String, dynamic>;
        _vitals = results[1] as List<dynamic>;
        _medications = results[2] as List<dynamic>;
        _opd = results[3] as List<dynamic>;
        _ipd = results[4] as List<dynamic>;
        _labs = results[5] as List<dynamic>;
        _radiology = results[6] as List<dynamic>;
        _surgery = results[7] as List<dynamic>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
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
                      _buildDebugSection('API Base URL', _api.baseUrl),
                      _buildDebugSection('MRN', widget.cnic),
                      _buildDebugSection('Patient Data', _patient),
                      _buildDebugSection('Vitals Data', _vitals),
                      _buildDebugSection('Medications Data', _medications),
                      _buildDebugSection('OPD Data', _opd),
                      _buildDebugSection('IPD Data', _ipd),
                      _buildDebugSection('Labs Data', _labs),
                      _buildDebugSection('Radiology Data', _radiology),
                      _buildDebugSection('Surgery Data', _surgery),
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
        title: const Text('Patient Dashboard'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _showDebugDialog,
            tooltip: 'Debug API Data',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
          ),
        ],
      ),
      body: Stack(
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
                            
                            // Collapsible Tab Section
                            _buildCollapsibleTabSection(),
                          ],
                        ),
                      ),
                    ),
          // Overlay for section details
          if (_showOverlay) _buildSectionOverlay(),
          
          // Pinned toggle button (only when expanded)
          if (_isTabSectionExpanded) _buildPinnedToggleButton(),
        ],
      ),
    );
  }

  Widget _buildPatientHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // First Row - Patient Profile and Current Medications
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Profile - Bento Card
              Expanded(
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, color: Colors.blue.shade600),
                            const Gap(8),
                            Text(
                              'Patient Profile',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                        const Gap(12),
                        Text(
                          _patient?['name'] as String? ?? 'Loading...',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        const Gap(8),
                        Text(
                          'MRN: ${_patient?['mrn'] ?? 'Loading...'}',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Gap(4),
                        Text(
                          _patient != null 
                            ? '${_patient!['gender']}, ${_patient!['age']} years old • Blood Type: ${_patient!['bloodType']}'
                            : 'Loading patient details...',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const Gap(4),
                        Text(
                          'Last Visit: ${_patient?['lastVisit'] ?? 'Loading...'}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Gap(16),
              // Current Medications - Bento Card
              Expanded(
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.medication, color: Colors.green.shade600),
                            const Gap(8),
                            Text(
                              'Current Medications',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.shade600,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _medications != null
                                    ? '${_medications!.where((med) => (med['status'] ?? '').toString().toLowerCase() == 'active').length} meds'
                                    : 'Loading...',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const Gap(12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _medications != null
                              ? (() {
                                  if (_medications!.isEmpty) {
                                    return [
                                      Chip(
                                        label: const Text('No current medications'),
                                        backgroundColor: Colors.grey.shade100,
                                        labelStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                        side: BorderSide(color: Colors.grey.shade300),
                                      ),
                                    ];
                                  }
                                  return _medications!.map<Widget>((med) {
                                    final medication = (med['medication'] ?? '').toString();
                                    final dosage = (med['dosage'] ?? '').toString();
                                    final status = (med['status'] ?? '').toString();
                                    
                                    // Only show active medications
                                    if (status.toLowerCase() != 'active') {
                                      return const SizedBox.shrink();
                                    }
                                    
                                    return Chip(
                                      label: Text('$medication $dosage'),
                                      backgroundColor: Colors.green.shade50,
                                      labelStyle: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600),
                                      side: BorderSide(color: Colors.green.shade100),
                                    );
                                  }).where((chip) => chip is! SizedBox).toList();
                                })()
                              : [
                                  Chip(
                                    label: const Text('Loading medications...'),
                                    backgroundColor: Colors.grey.shade100,
                                    labelStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                    side: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Gap(16),
          // Second Row - Other Medical Sections
          Row(
            children: [
              Expanded(child: _buildSectionCard('Vitals', Icons.favorite, Colors.red, _vitals?.length ?? 0, 'vitals')),
              const Gap(12),
              Expanded(child: _buildSectionCard('OPD Visits', Icons.meeting_room_outlined, Colors.indigo, _opd?.length ?? 0, 'opd')),
              const Gap(12),
              Expanded(child: _buildSectionCard('IPD Admissions', Icons.local_hospital_outlined, Colors.teal, _ipd?.length ?? 0, 'ipd')),
            ],
          ),
          const Gap(12),
          Row(
            children: [
              Expanded(child: _buildSectionCard('Lab Results', Icons.biotech_outlined, Colors.orange, _labs?.length ?? 0, 'labs')),
              const Gap(12),
              Expanded(child: _buildSectionCard('Radiology', Icons.image_search_outlined, Colors.cyan, _radiology?.length ?? 0, 'radiology')),
              const Gap(12),
              Expanded(child: _buildSectionCard('Surgery', Icons.health_and_safety_outlined, Colors.red, _surgery?.length ?? 0, 'surgery')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, Color color, int count, String sectionKey) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showSectionOverlay(sectionKey),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(8),
              Text(
                'Tap to view details',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
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
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
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
          columnSpacing: 20,
          horizontalMargin: 16,
          headingRowHeight: 64,
          dataRowMinHeight: 56,
          dataRowMaxHeight: 80,
          headingRowColor: MaterialStateProperty.all(Colors.white),
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
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Text(
                    cell.isEmpty ? '-' : cell,
                    style: TextStyle(
                      fontSize: 15,
                      color: cell.isEmpty ? Colors.grey.shade400 : Colors.grey.shade800,
                      fontWeight: cell.isEmpty ? FontWeight.normal : FontWeight.w600,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _isTabSectionExpanded ? MediaQuery.of(context).size.height * 0.6 : 180,
      child: Container(
        color: Colors.white,
        child: _isTabSectionExpanded 
          ? Column(
              children: [
                // Navigation Tabs
                _buildTabBar(),
                // Content Area
                Expanded(child: _buildTabBarView()),
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
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
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
              const Gap(12),
              Text(
                'Access comprehensive medical records including vitals, medications, lab results, and more.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.green.shade700,
                  height: 1.4,
                ),
              ),
              const Gap(12),
              Row(
                children: [
                  _buildSummaryItem('Vitals', _vitals?.length ?? 0, Icons.favorite, Colors.red),
                  const Gap(16),
                  _buildSummaryItem('Labs', _labs?.length ?? 0, Icons.biotech_outlined, Colors.orange),
                  const Gap(16),
                  _buildSummaryItem('OPD', _opd?.length ?? 0, Icons.meeting_room_outlined, Colors.indigo),
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
        Icon(icon, color: color, size: 14),
        const Gap(4),
        Text(
          '$count $title',
          style: TextStyle(
            color: Colors.green.shade700,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.green,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: Colors.green,
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
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleTabSection,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Icon(
              _isTabSectionExpanded 
                  ? Icons.keyboard_arrow_up_rounded 
                  : Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 28,
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
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: _vitalsSearchController,
              onChanged: (value) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search vitals by date, BP, HR, temperature, or location...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _vitalsSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _vitalsSearchController.clear();
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
          
          // Vitals Results Card
          Expanded(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            color: Colors.red.shade600,
                            size: 24,
                          ),
                          const Gap(8),
                          Text(
                            'Vital Signs',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
            ),
          ),
          
          // Vitals Table
          Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const int columnCount = 9;
                          const double approxMinColWidth = 80; // px
                          final double dynamicSpacing = ((constraints.maxWidth - (approxMinColWidth * columnCount)) / (columnCount - 1)).clamp(24, 96);
                          return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                                columnSpacing: dynamicSpacing,
                                horizontalMargin: 0,
                  columns: const [
                                  DataColumn(
                                    label: Text(
                                      'Date/Time',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'BP',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'HR',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Temp',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'RR',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'SpO2',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Weight',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'BMI',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Location',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: () {
                                  final filteredVitals = _filterVitals(_vitalsSearchController.text);
                                  if (_vitals == null) {
                                    return [
                                      _buildVitalRow('Loading vitals...', '-', '-', '-', '-', '-', '-', '-', '-',
                                          [Colors.grey, Colors.grey, Colors.grey, Colors.grey, Colors.grey, Colors.grey, Colors.grey, Colors.grey])
                                    ];
                                  } else if (filteredVitals.isEmpty) {
                                    return [
                                      _buildVitalRow(
                                        _vitalsSearchController.text.isNotEmpty 
                                            ? 'No vitals found matching "${_vitalsSearchController.text}"'
                                            : 'No vitals data available', 
                                        '-', '-', '-', '-', '-', '-', '-', '-',
                                        [Colors.grey, Colors.grey, Colors.grey, Colors.grey, Colors.grey, Colors.grey, Colors.grey, Colors.grey])
                                    ];
                                  } else {
                                    return filteredVitals.map((v) {
                                        final dateTime = (v['dateTime'] ?? '').toString();
                                        final bp = (v['bloodPressure'] ?? '-').toString();
                                        final hr = (v['heartRate'] ?? '-').toString();
                                        final temp = (v['temperature'] ?? '-').toString();
                                        final rr = (v['respiratoryRate'] ?? '-').toString();
                                        final spo2 = (v['spO2'] ?? '-').toString();
                                        final weight = (v['weight'] ?? '-').toString();
                                        final bmi = (v['bmi'] ?? '-').toString();
                                        final location = (v['location'] ?? '-').toString();
                                        // Simple color mapping
                                        Color _status(String? s) {
                                          switch (s) {
                                            case 'warning':
                                              return Colors.orange;
                                            case 'danger':
                                              return Colors.red;
                                            default:
                                              return Colors.green;
                                          }
                                        }
                                        final status = v['status'] as Map<String, dynamic>?;
                                        final colors = [
                                          _status(status?['bp'] as String?),
                                          _status(status?['hr'] as String?),
                                          _status(status?['temp'] as String?),
                                          _status(status?['rr'] as String?),
                                          _status(status?['spO2'] as String?),
                                          _status(status?['bmi'] as String?),
                                          Colors.green,
                                          Colors.green,
                                        ];
                                        return _buildVitalRow(dateTime, bp, hr, temp, rr, spo2, weight, bmi, location, colors);
                                      }).toList();
                                  }
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

  DataRow _buildVitalRow(String dateTime, String bp, String hr, String temp, String rr, String spo2, String weight, String bmi, String location, List<Color> colors) {
    return DataRow(
      cells: [
        DataCell(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              dateTime,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        DataCell(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              bp,
              style: TextStyle(
                color: colors[0],
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        DataCell(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              hr,
              style: TextStyle(
                color: colors[1],
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        DataCell(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              temp,
              style: TextStyle(
                color: colors[2],
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        DataCell(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              rr,
              style: TextStyle(
                color: colors[3],
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        DataCell(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              spo2,
              style: TextStyle(
                color: colors[4],
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        DataCell(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              weight,
              style: TextStyle(
                color: colors[5],
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        DataCell(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              bmi,
              style: TextStyle(
                color: colors[6],
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        DataCell(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              location,
              style: TextStyle(
                color: colors[7],
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
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
    required List<DataRow> rows,
    TextEditingController? searchController,
    List<dynamic>? data,
    List<dynamic> Function(String)? filterFunction,
    String? noDataMessage,
  }) {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
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
                                horizontalMargin: 0,
                                columns: columns,
                                rows: () {
                                  if (filterFunction != null && searchController != null && data != null) {
                                    final filteredData = filterFunction(searchController.text);
                                    if (data.isEmpty) {
                                      return [
                                        _dataRow([noDataMessage ?? 'No data available', '-', '-', '-', '-', '-', '-']),
                                      ];
                                    } else if (filteredData.isEmpty && searchController.text.isNotEmpty) {
                                      return [
                                        _dataRow(['No results found matching "${searchController.text}"', '-', '-', '-', '-', '-', '-']),
                                      ];
                                    } else {
                                      return filteredData.map((item) {
                                        // Extract data based on the section type
                                        if (title == 'Medications') {
                                          final medication = (item['medication'] ?? '').toString();
                                          final dosage = (item['dosage'] ?? '').toString();
                                          final frequency = (item['frequency'] ?? '').toString();
                                          final status = (item['status'] ?? '').toString();
                                          final prescriber = (item['prescriber'] ?? '').toString();
                                          final startDate = (item['startDate'] ?? '').toString();
                                          final indication = (item['indication'] ?? '').toString();
                                          
                                          return _dataRow([
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
                                          
                                          return _dataRow([
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
                                          
                                          return _dataRow([
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
                                          
                                          return _dataRow([
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
                                          
                                          return _dataRow([
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
                                          
                                          return _dataRow([
                                            date,
                                            procedure,
                                            surgeon,
                                            outcome,
                                            complications,
                                          ]);
                                        }
                                        return _dataRow(['Unknown data type', '-', '-', '-', '-', '-', '-']);
                                      }).toList();
                                    }
                                  }
                                  return rows;
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
}
