import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../services/patient_service.dart';
import '../services/encounter_service.dart';
import '../services/pregnancy_service.dart';
import '../services/pharmacy_service.dart';
import '../widgets/app_navigation_drawer.dart';
class PatientHistoryDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> patient;

  const PatientHistoryDashboardScreen({
    Key? key,
    required this.patient,
  }) : super(key: key);

  @override
  State<PatientHistoryDashboardScreen> createState() => _PatientHistoryDashboardScreenState();
}

class _PatientHistoryDashboardScreenState extends State<PatientHistoryDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PatientService _patientService = PatientService();
  final EncounterService _encounterService = EncounterService();
  final PregnancyService _pregnancyService = PregnancyService();
  
  // Data storage (encounter-driven: same as ipd_file_screen)
  Map<String, dynamic>? _patientDetails;
  List<Map<String, dynamic>> _encounterDataList = [];
  List<dynamic> _allVitals = [];
  List<Map<String, dynamic>> _activeMedicines = [];
  List<dynamic>? _surgery;
  List<dynamic>? _pregnancyRecords;
  List<dynamic>? _chronicConditions;
  List<dynamic>? _riskFactors;
  List<dynamic>? _allergies;
  Map<String, dynamic>? _activePregnancy;
  
  bool _loading = false;
  String? _error;
  bool _showOverlay = false;
  String? _selectedSection;
  bool _isMedicalCardsExpanded = false;
  
  // Search controllers for each section
  final TextEditingController _vitalsSearchController = TextEditingController();
  final TextEditingController _medicationsSearchController = TextEditingController();
  final TextEditingController _opdSearchController = TextEditingController();
  final TextEditingController _ipdSearchController = TextEditingController();
  final TextEditingController _labsSearchController = TextEditingController();
  final TextEditingController _radiologySearchController = TextEditingController();
  final TextEditingController _surgerySearchController = TextEditingController();
  final TextEditingController _pregnancySearchController = TextEditingController();

  bool get _isMale {
    final gender = (widget.patient['gender'] ?? widget.patient['Gender'] ?? '').toString().toLowerCase();
    return gender == 'male' || gender == 'm';
  }

  bool get _showPregnancy {
    if (_isMale) return false;
    final ageRaw = widget.patient['age'] ?? widget.patient['Age'];
    if (ageRaw == null) return false;
    final age = ageRaw is num ? ageRaw.toInt() : int.tryParse(ageRaw.toString().replaceAll(RegExp(r'[^\d]'), ''));
    return age != null && age >= 15;
  }

  /// OPD encounters from _encounterDataList (encounterType OPD)
  List<Map<String, dynamic>> get _opdEncounters {
    return _encounterDataList.where((e) {
      final t = (e['encounter'] as Map<String, dynamic>)['encounterType']?.toString() ?? (e['encounter'] as Map<String, dynamic>)['EncounterType']?.toString() ?? '';
      return t.toUpperCase() == 'OPD';
    }).toList();
  }

  /// IPD encounters from _encounterDataList (encounterType IPD)
  List<Map<String, dynamic>> get _ipdEncounters {
    return _encounterDataList.where((e) {
      final t = (e['encounter'] as Map<String, dynamic>)['encounterType']?.toString() ?? (e['encounter'] as Map<String, dynamic>)['EncounterType']?.toString() ?? '';
      return t.toUpperCase() == 'IPD';
    }).toList();
  }

  /// Flattened lab orders from all encounters (package/test expansion like ipd_file_screen)
  List<Map<String, dynamic>> get _aggregatedLabOrders {
    final List<Map<String, dynamic>> out = [];
    for (final data in _encounterDataList) {
      final encounter = data['encounter'] as Map<String, dynamic>? ?? {};
      final encounterDate = encounter['encounterDate'] ?? encounter['EncounterDate'] ?? encounter['checkInTime'] ?? '';
      final dateStr = _formatDateDDMMYYYY(encounterDate);
      final labOrdersRaw = data['labOrders'] as List<dynamic>? ?? [];
      final packageMap = <String, Map<String, dynamic>>{};
      final testItems = <Map<String, dynamic>>[];
      for (final order in labOrdersRaw) {
        final packageId = order['packageId'];
        final isPackage = packageId != null;
        if (isPackage) {
          final packageKey = 'package_${packageId}_${order['orderId'] ?? ''}';
          if (!packageMap.containsKey(packageKey)) {
            final rateValue = order['rate'];
            final rate = rateValue is num ? rateValue.toDouble() : double.tryParse(rateValue?.toString() ?? '') ?? 0;
            packageMap[packageKey] = {
              'type': 'package',
              'packageId': packageId,
              'packageName': order['packageName'] ?? order['testName'] ?? 'N/A',
              'tests': <Map<String, dynamic>>[],
            };
          }
          (packageMap[packageKey]!['tests'] as List<Map<String, dynamic>>).add({
            'testName': order['testName'] ?? 'N/A',
            'resultId': order['resultId'],
            'resultValue': order['resultValue'],
            'resultNumeric': order['resultNumeric'],
            'units': order['units'],
            'referenceRange': order['referenceRange'],
            'abnormalFlags': order['abnormalFlags'],
            'resultStatus': order['resultStatus'],
            'resultInterpretation': order['resultInterpretation'],
            'isCritical': order['isCritical'],
          });
        } else {
          testItems.add({
            'type': 'test',
            'packageName': null,
            'testName': order['testName'] ?? 'N/A',
            'resultId': order['resultId'],
            'resultValue': order['resultValue'],
            'resultNumeric': order['resultNumeric'],
            'units': order['units'],
            'referenceRange': order['referenceRange'],
            'abnormalFlags': order['abnormalFlags'],
            'resultStatus': order['resultStatus'],
            'resultInterpretation': order['resultInterpretation'],
            'isCritical': order['isCritical'],
          });
        }
      }
      for (final pkg in packageMap.values) {
        for (final t in (pkg['tests'] as List<dynamic>)) {
          final m = Map<String, dynamic>.from(t as Map);
          m['type'] = 'package_test';
          m['packageName'] = pkg['packageName'];
          m['testName'] = m['testName'] ?? 'N/A';
          m['encounterDate'] = dateStr;
          out.add(m);
        }
      }
      for (final t in testItems) {
        final m = Map<String, dynamic>.from(t);
        m['encounterDate'] = dateStr;
        out.add(m);
      }
    }
    return out;
  }

  /// Count of lab packages + standalone test orders (for tile display), not total test rows.
  int get _labPackageCount {
    int count = 0;
    for (final data in _encounterDataList) {
      final labOrdersRaw = data['labOrders'] as List<dynamic>? ?? [];
      final packageKeys = <String>{};
      int standalone = 0;
      for (final order in labOrdersRaw) {
        final packageId = order['packageId'];
        if (packageId != null) {
          final packageKey = 'package_${packageId}_${order['orderId'] ?? ''}';
          packageKeys.add(packageKey);
        } else {
          standalone++;
        }
      }
      count += packageKeys.length + standalone;
    }
    return count;
  }

  /// Flattened radiology orders from all encounters
  List<dynamic> get _aggregatedRadiologyOrders {
    final List<dynamic> out = [];
    for (final data in _encounterDataList) {
      out.addAll(data['radiologyOrders'] as List<dynamic>? ?? []);
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    // Use 7 tabs if no pregnancy (male or female < 15), 8 tabs if female 15+
    _tabController = TabController(length: _showPregnancy ? 8 : 7, vsync: this);
    _loadPatientHistory();
  }

  Widget _pill({required IconData icon, required String label, required String value, required Color color}) {
    final text = value.isNotEmpty ? value : 'None';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _vitalsSearchController.dispose();
    _medicationsSearchController.dispose();
    _opdSearchController.dispose();
    _ipdSearchController.dispose();
    _labsSearchController.dispose();
    _radiologySearchController.dispose();
    _surgerySearchController.dispose();
    _pregnancySearchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final patientId = widget.patient['patientId'];
      if (patientId == null) {
        setState(() => _loading = false);
        return;
      }
      final parsedPatientId = patientId is int ? patientId : int.parse(patientId.toString());

      // Phase 1: parallel load (same as ipd_file_screen + pharmacy active meds)
      final results = await Future.wait([
        _patientService.getPatientDetails(patientId).catchError((e) {
          print('Error loading patient details: $e');
          return null;
        }),
        _encounterService.getAllPatientEncounters(parsedPatientId).catchError((e) {
          print('Error loading encounters: $e');
          return <Map<String, dynamic>>[];
        }),
        _encounterService.getPatientVitals(parsedPatientId).catchError((e) {
          print('Error loading vitals: $e');
          return <dynamic>[];
        }),
        PharmacyService.getActivePatientMedicines(patientId: parsedPatientId).catchError((e) {
          print('Error loading active medicines: $e');
          return <Map<String, dynamic>>[];
        }),
        _pregnancyService.getPatientSurgeries(parsedPatientId).catchError((e) {
          print('Error loading surgeries: $e');
          return <Map<String, dynamic>>[];
        }),
        _pregnancyService.getPregnancyHistory(parsedPatientId).catchError((e) {
          print('Error loading pregnancy history: $e');
          return <Map<String, dynamic>>[];
        }),
        _encounterService.getPatientChronicConditions(patientId).catchError((e) {
          print('Error loading chronic conditions: $e');
          return <dynamic>[];
        }),
        _pregnancyService.getPatientRiskFactors(patientId).catchError((e) {
          print('Error loading risk factors: $e');
          return <Map<String, dynamic>>[];
        }),
        _pregnancyService.getPatientAllergies(patientId).catchError((e) {
          print('Error loading allergies: $e');
          return <Map<String, dynamic>>[];
        }),
        _pregnancyService.getActivePregnancy(parsedPatientId).catchError((e) {
          print('Error loading active pregnancy: $e');
          return null;
        }),
      ]);

      _patientDetails = results[0] as Map<String, dynamic>?;
      final encounters = results[1] as List<Map<String, dynamic>>;
      _allVitals = results[2] as List<dynamic>;
      _activeMedicines = (results[3] as List<Map<String, dynamic>>?) ?? [];
      _surgery = results[4] as List<dynamic>?;
      _pregnancyRecords = results[5] as List<dynamic>?;
      _chronicConditions = results[6] as List<dynamic>?;
      _riskFactors = results[7] as List<dynamic>?;
      _allergies = results[8] as List<dynamic>?;
      _activePregnancy = results[9] as Map<String, dynamic>?;

      // Phase 2: build _encounterDataList (getEncounterConsultationData per encounter, like ipd_file_screen)
      final Map<int, List<dynamic>> vitalsByEncounterId = {};
      for (final vital in _allVitals) {
        final encounterId = vital['encounterId'] ?? vital['EncounterID'] ?? vital['encounterID'];
        if (encounterId != null) {
          final id = encounterId is int ? encounterId : int.tryParse(encounterId.toString());
          if (id != null) {
            vitalsByEncounterId.putIfAbsent(id, () => []).add(vital);
          }
        }
      }

      final List<Map<String, dynamic>> encounterDataList = [];
      for (final encounter in encounters) {
        final encounterId = encounter['encounterId'] ?? encounter['EncounterID'] ?? encounter['encounterID'];
        if (encounterId == null) continue;
        final parsedEncounterId = encounterId is int ? encounterId : int.tryParse(encounterId.toString());
        if (parsedEncounterId == null) continue;
        try {
          final consultationData = await _encounterService.getEncounterConsultationData(
            parsedEncounterId,
            patientId: parsedPatientId,
          );
          encounterDataList.add({
            'encounter': encounter,
            'vitals': vitalsByEncounterId[parsedEncounterId] ?? [],
            'complaints': consultationData['complaints'] ?? [],
            'symptoms': consultationData['symptoms'] ?? [],
            'diagnoses': consultationData['diagnoses'] ?? [],
            'labOrders': consultationData['labOrders'] ?? [],
            'radiologyOrders': consultationData['radiologyOrders'] ?? [],
            'medicines': consultationData['medicines'] ?? [],
            'notes': consultationData['notes'] ?? consultationData['patientNotes'] ?? [],
            'clinicalNotes': consultationData['clinicalNotes'] ?? consultationData['clinicalNote'] ?? '',
          });
        } catch (e) {
          print('Error loading encounter data for $parsedEncounterId: $e');
          encounterDataList.add({
            'encounter': encounter,
            'vitals': vitalsByEncounterId[parsedEncounterId] ?? [],
            'complaints': [],
            'symptoms': [],
            'diagnoses': [],
            'labOrders': [],
            'radiologyOrders': [],
            'medicines': [],
            'notes': [],
            'clinicalNotes': '',
          });
        }
      }

      if (mounted) {
        setState(() {
          _encounterDataList = encounterDataList;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      print('Unexpected error loading patient history: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load patient history. Some data may be missing.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final height = media.size.height;
    final isTablet = width > 600;
    final isPortrait = media.orientation == Orientation.portrait;
    final isMobileLandscape = !isTablet && !isPortrait;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Stack(
          children: [
            _loading
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        const Gap(20),
                        Text(
                          'Loading patient history...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _error != null
                  ? Center(
                      child: Container(
                        margin: const EdgeInsets.all(32),
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline_rounded, size: 56, color: Colors.red.shade400),
                            const Gap(20),
                            Text(
                              'Error loading patient history',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const Gap(10),
                            Text(
                              _error!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const Gap(24),
                            ElevatedButton.icon(
                              onPressed: _loadPatientHistory,
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5B6B9E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : isTablet
                      ? _buildTabletLayout()
                      : _buildMobileLayout(isPortrait: isPortrait, isLandscape: isMobileLandscape),
          
            // Overlay for section details
            if (_showOverlay) _buildSectionOverlay(),
          ],
        ),
      ),
      drawer: AppNavigationDrawer(patient: widget.patient),
    );
  }

  // Tablet-optimized layout for landscape 7-inch tablets
  Widget _buildTabletLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildPatientHeader(),
          const Gap(20),
          _buildMedicalRecordCards(),
          const Gap(20),
          _buildDetailedTabSection(),
        ],
      ),
    );
  }

  // Mobile layout: adapts to portrait and landscape
  Widget _buildMobileLayout({required bool isPortrait, required bool isLandscape}) {
    final gap = isLandscape ? 10.0 : 16.0;
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildPatientHeader(isCompact: isLandscape),
          Gap(gap),
          _buildPregnancyStatusAlert(),
          Gap(gap),
          _buildMedicalRecordCards(),
          Gap(gap),
          _buildDetailedTabSection(),
        ],
      ),
    );
  }

  Widget _buildPatientHeader({bool isCompact = false}) {
    String joinWithComma(Iterable<String> items, {int max = 8}) {
      final list = items.where((e) => e.trim().isNotEmpty).toList();
      if (list.isEmpty) return 'None';
      if (list.length > max) {
        return list.sublist(0, max).join(', ') + ' +' + (list.length - max).toString();
      }
      return list.join(', ');
    }

    final String name = widget.patient['fullName'] ?? widget.patient['name'] ?? 'Unknown Patient';
    final String mrn = widget.patient['mrn']?.toString() ?? 'N/A';
    final String gender = widget.patient['gender']?.toString() ?? '';
    final String age = (widget.patient['age'] != null) ? '${widget.patient['age']}y' : '';
    final String blood = _patientDetails?['bloodType']?.toString() ?? '';

    final allergiesText = joinWithComma(
      (_allergies ?? [])
          .map((a) => '${a['allergyName'] ?? ''}${a['severity'] != null ? ' (${a['severity']})' : ''}')
          .cast<String>(),
    );
    final chronicText = joinWithComma(
      (_chronicConditions ?? [])
          .map((c) => '${c['conditionName'] ?? ''}${c['conditionCode'] != null ? ' (${c['conditionCode']})' : ''}')
          .cast<String>(),
    );
    final medsText = joinWithComma(
      _activeMedicines.map((m) => (m['medication'] ?? m['medicationName'] ?? m['name'] ?? '').toString()).cast<String>(),
      max: 6,
    );
    final risksText = joinWithComma(
      (_riskFactors ?? [])
          .where((r) => (r['isPresent'] ?? r['is_present'] ?? true) == true)
          .map((r) => (r['riskFactorName'] ?? '').toString())
          .cast<String>(),
      max: 8,
    );

    final vPad = isCompact ? 12.0 : 24.0;
    final hPad = isCompact ? 16.0 : 24.0;
    final topGap = isCompact ? 12.0 : 20.0;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: isCompact ? 6 : 12),
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF5B6B9E),
            const Color(0xFF4A5568),
          ],
        ),
        borderRadius: BorderRadius.circular(isCompact ? 14 : 20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isCompact ? 10 : 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(isCompact ? 10 : 14),
                ),
                child: Icon(Icons.person_rounded, color: Colors.white, size: isCompact ? 22 : 28),
              ),
              Gap(isCompact ? 12 : 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: isCompact ? 17 : 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Gap(isCompact ? 2 : 6),
                    Text(
                      'MRN: $mrn • $gender $age • $blood',
                      style: TextStyle(
                        fontSize: isCompact ? 12 : 13,
                        color: Colors.white.withOpacity(0.88),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap(topGap),
          Wrap(
            spacing: isCompact ? 6 : 10,
            runSpacing: isCompact ? 6 : 10,
            children: [
              _pill(icon: Icons.warning_amber_rounded, label: 'Allergies', value: allergiesText, color: Colors.orangeAccent),
              _pill(icon: Icons.healing, label: 'Chronic', value: chronicText, color: Colors.lightBlueAccent),
              _pill(icon: Icons.local_pharmacy, label: 'Current Meds', value: medsText, color: Colors.pinkAccent),
              _pill(icon: Icons.report_problem, label: 'Risk Factors', value: risksText, color: Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  // Quick stats cards for tablet sidebar
  Widget _buildQuickStatsCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Vitals',
                  Icons.favorite,
                  Colors.red,
                  _allVitals.length,
                ),
              ),
              const Gap(8),
              Expanded(
                child: _buildStatCard(
                  'Medications',
                  Icons.medication,
                  Colors.green,
                  _activeMedicines.length,
                ),
              ),
            ],
          ),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'OPD Visits',
                  Icons.meeting_room_outlined,
                  Colors.blue,
                  _opdEncounters.length,
                ),
              ),
              const Gap(8),
              Expanded(
                child: _buildStatCard(
                  'Lab Results',
                  Icons.biotech_outlined,
                  Colors.orange,
                  _labPackageCount,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, IconData icon, Color color, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const Gap(8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const Gap(4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPregnancyStatusAlert() {
    return const SizedBox.shrink(); // Removed: Patient has an active pregnancy banner
  }

  Widget _buildMedicalConditionsSection() {
    return Column(
      children: [
        // Allergies
        if (_allergies != null && _allergies!.isNotEmpty)
          _buildMedicalConditionRow(
            icon: Icons.warning,
            iconColor: Colors.red,
            label: 'Allergies:',
            items: _allergies!,
            getItemText: (item) => '${item['allergyName'] ?? 'Unknown'} (${item['severity'] ?? 'Unknown'})',
          ),
        // Chronic Conditions
        if (_chronicConditions != null && _chronicConditions!.isNotEmpty)
          _buildMedicalConditionRow(
            icon: Icons.health_and_safety,
            iconColor: Colors.purple,
            label: 'Chronic:',
            items: _chronicConditions!,
            getItemText: (item) => '${item['conditionName'] ?? 'Unknown'} (${item['conditionCode'] ?? ''})',
          ),
        // Current Medications
        if (_activeMedicines.isNotEmpty)
          _buildMedicalConditionRow(
            icon: Icons.medication,
            iconColor: Colors.red,
            label: 'Current Meds:',
            items: _activeMedicines,
            getItemText: (item) => '${item['medication'] ?? item['medicationName'] ?? item['name'] ?? 'Unknown'} ${item['dosage'] ?? item['strength'] ?? ''}',
          ),
      ],
    );
  }

  Widget _buildMedicalConditionRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required List<dynamic> items,
    required String Function(dynamic) getItemText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              items.map((item) => getItemText(item)).join(', '),
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMedicalInfoCardsRow() {
    return Row(
      children: [
        // Chronic Conditions
        Expanded(
          child: _buildCompactMedicalInfoCard(
            title: 'Chronic',
            icon: Icons.health_and_safety,
            color: Colors.red,
            data: _chronicConditions,
            getItemName: (item) => item['conditionName'] ?? item['name'] ?? 'Unknown Condition',
            getItemCode: (item) => item['conditionCode'] ?? item['code'] ?? '',
          ),
        ),
        const SizedBox(width: 4),
        // Risk Factors
        Expanded(
          child: _buildCompactMedicalInfoCard(
            title: 'Risk',
            icon: Icons.warning,
            color: Colors.orange,
            data: _riskFactors,
            getItemName: (item) => item['riskFactorName'] ?? 'Unknown Risk Factor',
            getItemCode: (item) => item['severityLevel'] ?? '',
          ),
        ),
        const SizedBox(width: 4),
        // Allergies
        Expanded(
          child: _buildCompactMedicalInfoCard(
            title: 'Allergies',
            icon: Icons.warning_amber,
            color: Colors.purple,
            data: _allergies,
            getItemName: (item) => item['allergyName'] ?? 'Unknown Allergy',
            getItemCode: (item) => item['severity'] ?? '',
          ),
        ),
      ],
    );
  }

  Widget _buildMedicalInfoCardsRow() {
    return Column(
      children: [
        // Chronic Conditions
        _buildCompactMedicalInfoCard(
          title: 'Chronic Conditions',
          icon: Icons.health_and_safety,
          color: Colors.red,
          data: _chronicConditions,
          getItemName: (item) => item['conditionName'] ?? item['name'] ?? 'Unknown Condition',
          getItemCode: (item) => item['conditionCode'] ?? item['code'] ?? '',
        ),
        const Gap(6),
        // Risk Factors
        _buildCompactMedicalInfoCard(
          title: 'Risk Factors',
          icon: Icons.warning,
          color: Colors.orange,
          data: _riskFactors,
          getItemName: (item) => item['riskFactorName'] ?? 'Unknown Risk Factor',
          getItemCode: (item) => item['severityLevel'] ?? '',
        ),
        const Gap(6),
        // Allergies
        _buildCompactMedicalInfoCard(
          title: 'Allergies',
          icon: Icons.warning_amber,
          color: Colors.purple,
          data: _allergies,
          getItemName: (item) => item['allergyName'] ?? 'Unknown Allergy',
          getItemCode: (item) => item['severity'] ?? '',
        ),
      ],
    );
  }

  Widget _buildChronicConditionsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Chronic Conditions
          _buildMedicalInfoCard(
            title: 'Chronic Conditions',
            icon: Icons.health_and_safety,
            color: Colors.red,
            data: _chronicConditions,
            getItemName: (item) => item['conditionName'] ?? item['name'] ?? 'Unknown Condition',
            getItemCode: (item) => item['conditionCode'] ?? item['code'] ?? '',
          ),
          const Gap(8),
          // Risk Factors
          _buildMedicalInfoCard(
            title: 'Risk Factors',
            icon: Icons.warning,
            color: Colors.orange,
            data: _riskFactors,
            getItemName: (item) => item['riskFactorName'] ?? 'Unknown Risk Factor',
            getItemCode: (item) => item['severityLevel'] ?? '',
          ),
          const Gap(8),
          // Allergies
          _buildMedicalInfoCard(
            title: 'Allergies',
            icon: Icons.warning_amber,
            color: Colors.purple,
            data: _allergies,
            getItemName: (item) => item['allergyName'] ?? 'Unknown Allergy',
            getItemCode: (item) => item['severity'] ?? '',
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMedicalInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    List<dynamic>? data,
    required String Function(dynamic) getItemName,
    required String Function(dynamic) getItemCode,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const Gap(6),
          Text(
            '$title:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 12,
            ),
          ),
          const Gap(6),
          Expanded(
            child: _buildCompactMedicalInfoList(data, getItemName, getItemCode, color),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    List<dynamic>? data,
    required String Function(dynamic) getItemName,
    required String Function(dynamic) getItemCode,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color.withOpacity(0.3), width: 1),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: color,
              ),
              const Gap(8),
              Text(
                '$title:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14,
                ),
              ),
              const Gap(8),
              Expanded(
                child: _buildMedicalInfoList(data, getItemName, getItemCode, color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMedicalInfoList(
    List<dynamic>? data,
    String Function(dynamic) getItemName,
    String Function(dynamic) getItemCode,
    Color color,
  ) {
    if (data == null || data.isEmpty) {
      return Text(
        'None',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontStyle: FontStyle.italic,
          fontSize: 10,
        ),
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: data.map((item) {
        return _buildCompactMedicalInfoChip(item, getItemName, getItemCode, color);
      }).toList(),
    );
  }

  Widget _buildMedicalInfoList(
    List<dynamic>? data,
    String Function(dynamic) getItemName,
    String Function(dynamic) getItemCode,
    Color color,
  ) {
    if (data == null || data.isEmpty) {
      return Text(
        'None recorded',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontStyle: FontStyle.italic,
          fontSize: 12,
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: data.map((item) {
        return _buildMedicalInfoChip(item, getItemName, getItemCode, color);
      }).toList(),
    );
  }

  Widget _buildCompactMedicalInfoChip(
    dynamic item,
    String Function(dynamic) getItemName,
    String Function(dynamic) getItemCode,
    Color color,
  ) {
    String itemName = getItemName(item);
    String itemCode = getItemCode(item);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        itemCode.isNotEmpty ? '$itemName ($itemCode)' : itemName,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 9,
        ),
      ),
    );
  }

  Widget _buildMedicalInfoChip(
    dynamic item,
    String Function(dynamic) getItemName,
    String Function(dynamic) getItemCode,
    Color color,
  ) {
    String itemName = getItemName(item);
    String itemCode = getItemCode(item);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        itemCode.isNotEmpty ? '$itemName ($itemCode)' : itemName,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildChronicConditionsList() {
    if (_chronicConditions == null || _chronicConditions!.isEmpty) {
      return Text(
        'No chronic conditions recorded',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontStyle: FontStyle.italic,
          fontSize: 12,
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: _chronicConditions!.map((condition) {
        return _buildConditionChip(condition);
      }).toList(),
    );
  }

  Widget _buildConditionChip(Map<String, dynamic> condition) {
    String conditionName = condition['conditionName'] ?? condition['name'] ?? 'Unknown Condition';
    String conditionCode = condition['conditionCode'] ?? condition['code'] ?? '';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200, width: 1),
      ),
      child: Text(
        conditionCode.isNotEmpty ? '$conditionName ($conditionCode)' : conditionName,
        style: TextStyle(
          color: Colors.red.shade800,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildMedicalRecordCards() {
    final media = MediaQuery.of(context);
    final isTablet = media.size.width > 600;
    final isMobileLandscape = media.size.width < 600 && media.orientation == Orientation.landscape;

    final sectionCards = [
      _buildAestheticSectionCard('Vitals', Icons.favorite, const Color(0xFFE53E3E), _allVitals.length, 'vitals'),
      _buildAestheticSectionCard('OPD', Icons.meeting_room_outlined, const Color(0xFF3182CE), _opdEncounters.length, 'opd'),
      _buildAestheticSectionCard('IPD', Icons.local_hospital_outlined, const Color(0xFF38B2AC), _ipdEncounters.length, 'ipd'),
      _buildAestheticSectionCard('Labs', Icons.biotech_outlined, const Color(0xFFDD6B20), _labPackageCount, 'labs'),
      _buildAestheticSectionCard('Radiology', Icons.medical_services, const Color(0xFF0BC5EA), _aggregatedRadiologyOrders.length, 'radiology'),
      _buildAestheticSectionCard('Surgery', Icons.content_cut, const Color(0xFFE53E3E), _surgery?.length ?? 0, 'surgery'),
      _buildAestheticSectionCard('Meds', Icons.medication, const Color(0xFF38A169), _activeMedicines.length, 'medications'),
      if (_showPregnancy) _buildAestheticSectionCard('Pregnancy', Icons.pregnant_woman, const Color(0xFFD53F8C), _pregnancyRecords?.length ?? 0, 'pregnancy'),
    ];

    Widget cardsContent;
    if (isTablet) {
      cardsContent = LayoutBuilder(
        builder: (context, constraints) {
          final crossCount = 4;
          final spacing = 16.0;
          final cellWidth = (constraints.maxWidth - spacing * (crossCount - 1)) / crossCount;
          final cellHeight = (cellWidth / 0.92).clamp(120.0, 200.0);
          return GridView.count(
            crossAxisCount: crossCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: cellWidth / cellHeight,
            children: sectionCards,
          );
        },
      );
    } else if (isMobileLandscape) {
      cardsContent = LayoutBuilder(
        builder: (context, constraints) {
          final crossCount = 4;
          final spacing = 10.0;
          final cellWidth = (constraints.maxWidth - spacing * (crossCount - 1)) / crossCount;
          final cellHeight = (cellWidth / 0.88).clamp(100.0, 180.0);
          return GridView.count(
            crossAxisCount: crossCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: cellWidth / cellHeight,
            children: sectionCards,
          );
        },
      );
    } else {
      cardsContent = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: sectionCards,
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobileLandscape ? 10 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobileLandscape ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(isMobileLandscape ? 16 : 24, isMobileLandscape ? 14 : 24, isMobileLandscape ? 16 : 24, isMobileLandscape ? 10 : 16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobileLandscape ? 8 : 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B6B9E).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(isMobileLandscape ? 10 : 12),
                  ),
                  child: Icon(Icons.folder_rounded, color: const Color(0xFF5B6B9E), size: isMobileLandscape ? 20 : 24),
                ),
                SizedBox(width: isMobileLandscape ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medical Records Overview',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: isMobileLandscape ? 15 : 18,
                          color: Colors.grey.shade800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        '${_allVitals.length + _opdEncounters.length + _ipdEncounters.length + _labPackageCount + _aggregatedRadiologyOrders.length + (_surgery?.length ?? 0) + _activeMedicines.length + (_showPregnancy ? (_pregnancyRecords?.length ?? 0) : 0)} records',
                        style: TextStyle(fontSize: isMobileLandscape ? 11 : 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(isMobileLandscape ? 10 : 16, 8, isMobileLandscape ? 10 : 16, isMobileLandscape ? 14 : 24),
            child: cardsContent,
          ),
        ],
      ),
    );
  }

  Widget _buildAestheticSectionCard(String title, IconData icon, Color color, int count, String sectionKey) {
    final media = MediaQuery.of(context);
    final isTablet = media.size.width > 600;
    final isCompactMobile = !isTablet && media.orientation == Orientation.landscape;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompactMobile ? 4 : 6, vertical: isCompactMobile ? 4 : 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showSectionOverlay(sectionKey),
          borderRadius: BorderRadius.circular(isCompactMobile ? 12 : 16),
          splashColor: color.withOpacity(0.15),
          highlightColor: color.withOpacity(0.08),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxH = constraints.maxHeight;
              final maxW = constraints.maxWidth;
              final isConstrained = maxH.isFinite && maxH < 160;
              final padding = isConstrained ? 6.0 : (isCompactMobile ? 10.0 : (isTablet ? 14.0 : 18.0));
              final iconSize = isConstrained ? 20.0 : (isCompactMobile ? 18.0 : (isTablet ? 26.0 : 22.0));
              final titleSize = isConstrained ? 11.0 : (isCompactMobile ? 11.0 : (isTablet ? 13.0 : 13.0));
              final countSize = isConstrained ? 16.0 : (isCompactMobile ? 14.0 : (isTablet ? 20.0 : 18.0));
              final gap = isConstrained ? 4.0 : (isCompactMobile ? 4.0 : (isTablet ? 8.0 : 8.0));
              return Container(
                padding: EdgeInsets.all(padding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isCompactMobile ? 12 : 16),
                  border: Border.all(color: color.withOpacity(0.22), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isConstrained || (isTablet && maxH.isFinite && maxH < 200)
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(isConstrained ? 4 : 6),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, color: color, size: iconSize),
                          ),
                          SizedBox(width: gap),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: titleSize,
                                    color: Colors.grey.shade800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: countSize,
                                    color: color,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : isTablet
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: EdgeInsets.all(iconSize * 0.5),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(icon, color: color, size: iconSize),
                              ),
                              Gap(gap),
                              Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: titleSize,
                                  color: Colors.grey.shade800,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Gap(gap * 0.5),
                              Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: countSize,
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: EdgeInsets.all(isCompactMobile ? 6 : 10),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(isCompactMobile ? 8 : 12),
                                ),
                                child: Icon(icon, color: color, size: iconSize),
                              ),
                              SizedBox(width: isCompactMobile ? 6 : 12),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: titleSize,
                                      color: Colors.grey.shade800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Gap(isCompactMobile ? 0 : 2),
                                  Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: countSize,
                                      color: color,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, Color color, int count, String sectionKey) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Reduced from 16 to 10 (40% reduction)
      child: InkWell(
        onTap: () => _showSectionOverlay(sectionKey),
        borderRadius: BorderRadius.circular(10), // Reduced from 16 to 10 (40% reduction)
        child: Padding(
          padding: const EdgeInsets.all(12), // Reduced from 20 to 12 (40% reduction)
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Centered Icon
              Container(
                padding: const EdgeInsets.all(10), // Reduced from 16 to 10 (40% reduction)
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12), // Reduced from 20 to 12 (40% reduction)
                ),
                child: Icon(
                  icon, 
                  color: color, 
                  size: 24, // Reduced from 40 to 24 (40% reduction)
                ),
              ),
              const Gap(10), // Reduced from 16 to 10 (40% reduction)
              // Centered Title
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 11, // Reduced from 18 to 11 (40% reduction)
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(5), // Reduced from 8 to 5 (40% reduction)
              // Centered Count Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), // Reduced from 12,6 to 7,4 (40% reduction)
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10), // Reduced from 16 to 10 (40% reduction)
                ),
                child: Text(
                  '$count records',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 8, // Reduced from 14 to 8 (40% reduction)
                  ),
                ),
              ),
              const Gap(7), // Reduced from 12 to 7 (40% reduction)
              // Centered Subtitle
              Text(
                'Tap to view details',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                  fontSize: 8, // Reduced from 13 to 8 (40% reduction)
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedTabSection() {
    final media = MediaQuery.of(context);
    final isTablet = media.size.width > 600;
    final isMobileLandscape = media.size.width < 600 && media.orientation == Orientation.landscape;
    final height = media.size.height;
    final tabBarHeight = 48.0;
    final searchBarHeight = 56.0;
    final rowHeight = 44.0;
    final minVisibleRows = 5.0;
    final minContentHeight = tabBarHeight + searchBarHeight + (rowHeight * minVisibleRows) + 24;
    final double sectionHeight;
    if (isTablet) {
      sectionHeight = (height * 0.55).clamp(minContentHeight, height * 0.7);
    } else if (isMobileLandscape) {
      sectionHeight = (height * 0.52).clamp(minContentHeight, height * 0.65);
    } else {
      sectionHeight = (height * 0.48).clamp(minContentHeight, 520.0);
    }
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobileLandscape ? 10 : 16),
      height: sectionHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Navigation Tabs
          _buildCompactTabBar(),
          // Content Area
          Expanded(child: _buildTabBarView()),
        ],
      ),
    );
  }

  Widget _buildCompactTabBar() {
    final media = MediaQuery.of(context);
    final isTablet = media.size.width > 600;
    final isMobileLandscape = media.size.width < 600 && media.orientation == Orientation.landscape;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isMobileLandscape ? 12 : 16),
          topRight: Radius.circular(isMobileLandscape ? 12 : 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: const Color(0xFF5B6B9E),
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: const Color(0xFF5B6B9E),
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(
          fontSize: isMobileLandscape ? 12 : (isTablet ? 13 : 14),
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: isMobileLandscape ? 12 : (isTablet ? 13 : 14),
          fontWeight: FontWeight.w500,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isMobileLandscape ? 6 : (isTablet ? 8 : 16),
          vertical: isMobileLandscape ? 6 : 8,
        ),
        tabs: [
          _buildTab('Vitals', Icons.favorite, Colors.red),
          _buildTab('Medications', Icons.medication, Colors.green),
          _buildTab('OPD', Icons.meeting_room_outlined, Colors.blue),
          _buildTab('IPD', Icons.local_hospital_outlined, Colors.teal),
          _buildTab('Labs', Icons.biotech_outlined, Colors.orange),
          _buildTab('Radiology', Icons.image_search_outlined, Colors.cyan),
          _buildTab('Surgery', Icons.content_cut, Colors.red),
          if (_showPregnancy) _buildTab('Pregnancy', Icons.pregnant_woman, Colors.pink),
        ],
      ),
    );
  }

  Widget _buildTab(String text, IconData icon, Color color) {
    final isMobileLandscape = MediaQuery.of(context).size.width < 600 &&
        MediaQuery.of(context).orientation == Orientation.landscape;
    final iconSize = isMobileLandscape ? 14.0 : 16.0;
    final gap = isMobileLandscape ? 4.0 : 6.0;
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          SizedBox(width: gap),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = <Tab>[
      const Tab(text: 'Vitals'),
      const Tab(text: 'Medications'),
      const Tab(text: 'OPD'),
      const Tab(text: 'IPD'),
      const Tab(text: 'Labs'),
      const Tab(text: 'Radiology'),
      const Tab(text: 'Surgery'),
      if (_showPregnancy) const Tab(text: 'Pregnancy'),
    ];
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: Colors.green,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: Colors.green,
        tabs: tabs,
      ),
    );
  }

  Widget _buildTabBarView() {
    final children = [
      _buildVitalsTab(),
      _buildMedicationsTab(),
      _buildOPDTab(),
      _buildIPDTab(),
      _buildLabsTab(),
      _buildRadiologyTab(),
      _buildSurgeryTab(),
    ];
    
    if (_showPregnancy) {
      children.add(_buildPregnancyTab());
    }
    
    return TabBarView(
      controller: _tabController,
      children: children,
    );
  }

  Widget _buildVitalsTab() {
    return _buildGenericTab(
      title: 'Vital Signs',
      icon: Icons.favorite,
      heroColor: Colors.red,
      searchController: _vitalsSearchController,
      searchHint: 'Search vitals by date, BP, HR, temperature, or location...',
      columns: const [
        DataColumn(label: Text('Date/Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Blood Pressure', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Heart Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Temperature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      ],
      data: _allVitals,
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
      columns: const [
        DataColumn(label: Text('Start Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Salt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Medication', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Dosage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Prescriber', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      ],
      data: _activeMedicines,
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
      searchHint: 'Search by date, complaint, symptoms, diagnosis...',
      columns: const [
        DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Presenting Complaint', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Symptoms', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Diagnosis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Clinical Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Medicines', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Lab / Radiology', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      ],
      data: _opdEncounters,
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
      searchHint: 'Search by date, complaint, symptoms, diagnosis...',
      columns: const [
        DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Presenting Complaint', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Symptoms', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Diagnosis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Clinical Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Medicines', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Lab / Radiology', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      ],
      data: _ipdEncounters,
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
      searchHint: 'Search labs by test name, result, package...',
      columns: const [
        DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Package Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Test Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Result', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Reference Range', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      ],
      data: _aggregatedLabOrders,
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
      searchHint: 'Search radiology by procedure, indication, findings, impression, or radiologist...',
      columns: const [
        DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Procedure', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Indication', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Findings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Impression', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Radiologist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      ],
      data: _aggregatedRadiologyOrders,
      filterFunction: _filterRadiology,
      noDataMessage: 'No radiology data available',
    );
  }

  Widget _buildSurgeryTab() {
    return _buildGenericTab(
      title: 'Previous Surgeries',
      icon: Icons.health_and_safety_outlined,
      heroColor: Colors.red,
      searchController: _surgerySearchController,
      searchHint: 'Search surgeries by name, category, date, or outcome...',
      columns: const [
        DataColumn(label: Text('Surgery Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Outcome', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      ],
      data: _surgery,
      filterFunction: _filterSurgery,
      noDataMessage: 'No surgery data available',
    );
  }

  Widget _buildPregnancyTab() {
    return _buildGenericTab(
      title: 'Pregnancy History',
      icon: Icons.pregnant_woman,
      heroColor: Colors.pink,
      searchController: _pregnancySearchController,
      searchHint: 'Search pregnancy history by number, delivery mode, or outcome...',
      columns: const [
        DataColumn(label: Text('Pregnancy #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Weeks Gestation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Delivery Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Labor Onset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Outcome', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      ],
      data: _pregnancyRecords,
      filterFunction: _filterPregnancy,
      noDataMessage: 'No pregnancy history available',
    );
  }

  // Generic tab builder
  Widget _buildGenericTab({
    required String title,
    required IconData icon,
    required Color heroColor,
    required String searchHint,
    required List<DataColumn> columns,
    TextEditingController? searchController,
    List<dynamic>? data,
    List<dynamic> Function(String)? filterFunction,
    String? noDataMessage,
  }) {
    final media = MediaQuery.of(context);
    final isTablet = media.size.width > 600;
    final isMobileLandscape = media.size.width < 600 && media.orientation == Orientation.landscape;
    return Container(
      color: const Color(0xFFF1F5F9),
      padding: EdgeInsets.all(isMobileLandscape ? 10 : (isTablet ? 20 : 16)),
      child: Column(
        children: [
          // Search bar
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: searchController,
              onChanged: (value) => setState(() {}),
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
              decoration: InputDecoration(
                hintText: searchHint,
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search_rounded, size: 22, color: Colors.grey.shade500),
                suffixIcon: searchController != null && searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 20, color: Colors.grey.shade500),
                        onPressed: () {
                          searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF5B6B9E), width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: isMobileLandscape ? 14 : 18, vertical: isMobileLandscape ? 12 : 14),
              ),
            ),
          ),
          // Data table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isMobileLandscape ? 12 : 14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: isMobileLandscape ? 14 : (isTablet ? 24 : 18),
                    horizontalMargin: isMobileLandscape ? 10 : (isTablet ? 20 : 16),
                    headingRowHeight: isMobileLandscape ? 44 : (isTablet ? 52 : 48),
                    dataRowMinHeight: isMobileLandscape ? 38 : (isTablet ? 46 : 42),
                    dataRowMaxHeight: isMobileLandscape ? 48 : (isTablet ? 56 : 52),
                    headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F5F9)),
                    columns: _buildOptimizedColumns(columns),
                    rows: _buildDataRows(data, filterFunction, searchController, noDataMessage, title),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DataRow> _buildDataRows(List<dynamic>? data, List<dynamic> Function(String)? filterFunction, TextEditingController? searchController, String? noDataMessage, String? title) {
    if (data == null || data.isEmpty) {
      // Get the correct number of columns based on the tab
      int columnCount = _getColumnCountForTab(title);
      List<DataCell> cells = [
        DataCell(Text(noDataMessage ?? 'No data available')),
      ];
      // Add empty cells to match column count
      for (int i = 1; i < columnCount; i++) {
        cells.add(const DataCell(Text('-')));
      }
      return [DataRow(cells: cells)];
    }

    List<dynamic> filteredData = data;
    if (filterFunction != null && searchController != null) {
      filteredData = filterFunction(searchController.text);
    }

    if (filteredData.isEmpty && searchController?.text.isNotEmpty == true) {
      // Get the correct number of columns based on the tab
      int columnCount = _getColumnCountForTab(title);
      List<DataCell> cells = [
        DataCell(Text('No results found matching "${searchController!.text}"')),
      ];
      // Add empty cells to match column count
      for (int i = 1; i < columnCount; i++) {
        cells.add(const DataCell(Text('-')));
      }
      return [DataRow(cells: cells)];
    }

    return filteredData.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      List<String> rowData = _getRowDataForTab(item, title);
      final isLabResultOutOfRange = title == 'Lab Results' && rowData.length >= 5 && _isResultOutOfReferenceRange(rowData[3], rowData[4]);
      return DataRow(
        color: MaterialStateProperty.all(
          index.isEven ? Colors.white : const Color(0xFFFAFBFC),
        ),
        cells: rowData.asMap().entries.map((entry) {
          int index = entry.key;
          String cell = entry.value;
          Color cellColor = _getCellColor(cell, title, index);
          final isResultCell = title == 'Lab Results' && index == 3;
          final outOfRange = isResultCell && isLabResultOutOfRange;
          return DataCell(
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              constraints: const BoxConstraints(minWidth: 100, maxWidth: 200),
              child: Text(
                cell.isEmpty ? '-' : cell,
                style: TextStyle(
                  fontSize: 12,
                  color: outOfRange ? Colors.red : cellColor,
                  fontWeight: outOfRange ? FontWeight.bold : FontWeight.w500,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }).toList(),
      );
    }).toList();
  }

  /// True if result value is outside the reference range (e.g. "4.5-11" or "12-16").
  bool _isResultOutOfReferenceRange(String resultStr, String refRangeStr) {
    if (resultStr.isEmpty || resultStr == '-' || refRangeStr.isEmpty || refRangeStr == '-') return false;
    final resultNum = double.tryParse(resultStr.trim().replaceAll(RegExp(r'[^\d.]'), ''));
    if (resultNum == null) return false;
    final rangeMatch = RegExp(r'([\d.]+)\s*-\s*([\d.]+)').firstMatch(refRangeStr);
    if (rangeMatch == null) return false;
    final low = double.tryParse(rangeMatch.group(1) ?? '');
    final high = double.tryParse(rangeMatch.group(2) ?? '');
    if (low == null || high == null) return false;
    return resultNum < low || resultNum > high;
  }

  List<String> _getRowDataForTab(dynamic item, String? title) {
    switch (title) {
      case 'Vital Signs':
        final recordedDate = item['recordedDate'] != null
            ? DateTime.tryParse(item['recordedDate'].toString())
            : null;
        final dateStr = _formatDateDDMMYYYY(item['recordedDate']);
        final timeStr = recordedDate != null && recordedDate.toString().length > 11
            ? recordedDate.toString().substring(11, 16)
            : '';
        final dateTimeStr = timeStr.isNotEmpty ? '$dateStr\n$timeStr' : dateStr;
        
        final systolic = item['bpSystolic'] != null
            ? (item['bpSystolic'] is num ? item['bpSystolic'].toInt() : int.tryParse(item['bpSystolic'].toString()))
            : null;
        final diastolic = item['bpDiastolic'] != null
            ? (item['bpDiastolic'] is num ? item['bpDiastolic'].toInt() : int.tryParse(item['bpDiastolic'].toString()))
            : null;
        final bpStr = (systolic != null && diastolic != null) ? '$systolic/$diastolic' : '-';
        
        final pulse = item['pulse'] != null
            ? (item['pulse'] is num ? item['pulse'].toInt() : int.tryParse(item['pulse'].toString()))
            : null;
        final pulseStr = pulse != null ? pulse.toString() : '-';
        
        final tempC = item['temperature'] != null
            ? (item['temperature'] is num ? item['temperature'].toDouble() : double.tryParse(item['temperature'].toString()))
            : null;
        final tempF = tempC != null ? ((tempC * 9 / 5) + 32).toStringAsFixed(1) : null;
        final tempStr = tempF != null ? '${tempF}°F' : '-';
        
        final location = (item['position'] ?? item['location'] ?? '').toString();
        
        return [dateTimeStr, bpStr, pulseStr, tempStr, location];
      case 'OPD Visits':
      case 'IPD Admissions':
        return _encounterRowData(Map<String, dynamic>.from(item as Map));
      case 'Radiology':
        return [
          _formatDateDDMMYYYY(item['orderDate'] ?? item['date']),
          (item['testName'] ?? item['procedure'] ?? '').toString(),
          (item['indication'] ?? '').toString(),
          (item['finalFindings'] ?? item['findings'] ?? '').toString(),
          (item['impression'] ?? '').toString(),
          (item['radiologist_Name'] ?? item['radiologist'] ?? '').toString(),
        ];
      case 'Previous Surgeries':
        return [
          (item['surgeryName'] ?? '').toString(),
          (item['surgeryCategory'] ?? '').toString(),
          _formatDateDDMMYYYY(item['surgeryDate']),
          (item['procedureOutcome'] ?? '').toString(),
          (item['department'] ?? '').toString(),
        ];
      case 'Pregnancy History':
        return [
          (item['pregnancyNumber'] ?? '').toString(),
          (item['weeksOfGestation'] ?? '').toString(),
          (item['modeOfDelivery'] ?? '').toString(),
          (item['laborOnsetType'] ?? '').toString(),
          (item['stillAlive'] ?? '').toString(),
        ];
      case 'Medications':
        return [
          _formatDateDDMMYYYY(item['startDate'] ?? item['start_date'] ?? item['orderDate']),
          (item['salt'] ?? item['saltName'] ?? '').toString(),
          (item['medication'] ?? item['medicationName'] ?? item['name'] ?? '').toString(),
          (item['dosage'] ?? item['strength'] ?? item['dose'] ?? '').toString(),
          (item['duration'] ?? item['frequency'] ?? '').toString(),
          (item['status'] ?? 'Active').toString(),
          (item['prescriber'] ?? item['doctorName'] ?? item['prescribedBy'] ?? '').toString(),
        ];
      case 'Lab Results':
        final resultVal = (item['resultValue'] ?? item['result'] ?? item['resultNumeric'] ?? '').toString();
        final refRange = (item['normalRange'] ?? item['referenceRange'] ?? '').toString();
        final pkgName = (item['packageName'] ?? '').toString();
        final dateVal = (item['encounterDate'] ?? _formatDateDDMMYYYY(item['date'] ?? item['sampleDate'])).toString();
        return [
          dateVal,
          pkgName,
          (item['test'] ?? item['testName'] ?? '').toString(),
          resultVal,
          refRange,
        ];
      default:
        // Return 5 cells for default case to match most tabs
        return [
          _formatDateDDMMYYYY(item['date']),
          (item['description'] ?? '').toString(),
          (item['status'] ?? '').toString(),
          (item['provider'] ?? '').toString(),
          (item['notes'] ?? '').toString(),
        ];
    }
  }

  List<DataColumn> _buildOptimizedColumns(List<DataColumn> originalColumns) {
    return originalColumns.map((column) {
      // Extract text from the original label widget
      String labelText = '';
      if (column.label is Text) {
        labelText = (column.label as Text).data ?? '';
      }
      
      return DataColumn(
        label: Container(
          constraints: const BoxConstraints(minWidth: 100, maxWidth: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            labelText,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.grey.shade700,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }).toList();
  }

  Color _getCellColor(String cell, String? title, int index) {
    if (cell.isEmpty || cell == '-') {
      return Colors.grey.shade400;
    }
    
    // Color coding for vitals
    if (title == 'Vitals') {
      switch (index) {
        case 1: // Blood Pressure
          return Colors.grey.shade700;
        case 2: // Heart Rate
          return _getVitalColor(cell, 60, 100);
        case 3: // Temperature
          return _getVitalColor(cell, 97.0, 99.0);
        case 4: // Respiratory Rate
          return _getVitalColor(cell, 12, 20);
        case 5: // SpO2
          return _getVitalColor(cell, 95, 100);
        case 6: // Weight
          return Colors.green.shade600;
        case 7: // BMI
          return _getVitalColor(cell, 18.5, 25.0);
        default:
          return Colors.grey.shade700;
      }
    }
    
    return Colors.grey.shade700;
  }
  
  Color _getVitalColor(String value, double min, double max) {
    try {
      double numValue = double.parse(value.replaceAll(RegExp(r'[^\d.]'), ''));
      if (numValue >= min && numValue <= max) {
        return Colors.green.shade600; // Normal range
      } else if (numValue < min * 0.9 || numValue > max * 1.1) {
        return Colors.red.shade600; // Critical
      } else {
        return Colors.orange.shade600; // Warning
      }
    } catch (e) {
      return Colors.grey.shade700; // Default
    }
  }

  int _getColumnCountForTab(String? title) {
    switch (title) {
      case 'Vital Signs':
        return 5;
      case 'OPD Visits':
      case 'IPD Admissions':
        return 7; // Date, Complaint, Symptoms, Diagnosis, Medicines, Lab/Radiology, Clinical Notes
      case 'Radiology':
        return 6;
      case 'Previous Surgeries':
        return 5;
      case 'Pregnancy History':
        return 5;
      case 'Medications':
        return 7;
      case 'Lab Results':
        return 5; // Test Name, Result, Unit, Ref Range, Status
      default:
        return 5;
    }
  }

  /// Format any date-like value as DD/MM/YYYY for display on this form.
  String _formatDateDDMMYYYY(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  /// Build [date, complaint, symptoms, diagnosis, commaMedicines, commaLabRadiology] from encounter data map.
  List<String> _encounterRowData(Map<String, dynamic> data) {
    final encounter = data['encounter'] as Map<String, dynamic>? ?? {};
    final encounterDate = encounter['encounterDate'] ?? encounter['EncounterDate'] ?? encounter['checkInTime'] ?? '';
    final dateStr = _formatDateDDMMYYYY(encounterDate);
    final complaints = (data['complaints'] as List<dynamic>?) ?? [];
    final complaintStr = complaints.map((c) => (c['diagnosisName'] ?? c['icd10Description'] ?? c['ICD10Description'] ?? 'N/A').toString()).join(', ');
    final symptoms = (data['symptoms'] as List<dynamic>?) ?? [];
    final symptomStr = symptoms.map((s) => (s['diagnosisName'] ?? s['icd10Description'] ?? s['ICD10Description'] ?? 'N/A').toString()).join(', ');
    final diagnoses = (data['diagnoses'] as List<dynamic>?) ?? [];
    final diagnosisStr = diagnoses.map((d) => (d['diagnosisName'] ?? d['icd10Description'] ?? d['ICD10Description'] ?? 'N/A').toString()).join(', ');
    final medicines = (data['medicines'] as List<dynamic>?) ?? [];
    final medStr = medicines.map((m) => (m['medicineName'] ?? m['medication'] ?? m['medicationName'] ?? m['name'] ?? 'N/A').toString()).join(', ');
    final labOrders = (data['labOrders'] as List<dynamic>?) ?? [];
    final radOrders = (data['radiologyOrders'] as List<dynamic>?) ?? [];
    final seenLab = <String>{};
    final labNames = <String>[];
    for (final l in labOrders) {
      final pkg = (l['packageName'] ?? '').toString();
      final name = pkg.isNotEmpty ? pkg : (l['testName'] ?? 'N/A').toString();
      if (name.isNotEmpty && name != 'N/A' && seenLab.add(name)) labNames.add(name);
    }
    final radNames = radOrders.map((r) => (r['testName'] ?? r['clinicalDisplayName'] ?? 'N/A').toString());
    final labRadStr = [...labNames, ...radNames].join(', ');
    final clinicalNotes = (data['clinicalNotes'] ?? '').toString().trim();
    return [dateStr, complaintStr, symptomStr, diagnosisStr, clinicalNotes, medStr, labRadStr];
  }

  List<String> _getRowData(dynamic item) {
    // This method should be overridden in each tab to provide specific row data
    return [
      _formatDateDDMMYYYY(item['date']),
      (item['description'] ?? '').toString(),
      (item['status'] ?? '').toString(),
      (item['provider'] ?? '').toString(),
      (item['notes'] ?? '').toString(),
    ];
  }

  // Search filtering methods
  List<dynamic> _filterVitals(String query) {
    if (query.isEmpty) return _allVitals;
    return _allVitals.where((vital) {
      final searchText = query.toLowerCase();
      final recordedDate = vital['recordedDate'] ?? '';
      final systolic = vital['bpSystolic'] ?? '';
      final diastolic = vital['bpDiastolic'] ?? '';
      final bp = '$systolic/$diastolic';
      final pulse = vital['pulse'] ?? '';
      final tempC = vital['temperature'] ?? '';
      final tempF = tempC != null && tempC is num ? ((tempC * 9 / 5) + 32).toStringAsFixed(1) : '';
      final position = vital['position'] ?? vital['location'] ?? '';
      
      return recordedDate.toString().toLowerCase().contains(searchText) ||
             bp.toLowerCase().contains(searchText) ||
             pulse.toString().toLowerCase().contains(searchText) ||
             tempF.toLowerCase().contains(searchText) ||
             tempC.toString().toLowerCase().contains(searchText) ||
             position.toString().toLowerCase().contains(searchText);
    }).toList();
  }

  List<dynamic> _filterMedications(String query) {
    if (query.isEmpty) return _activeMedicines;
    return _activeMedicines.where((med) {
      final searchText = query.toLowerCase();
      return (med['medication'] ?? med['medicationName'] ?? med['name'] ?? '').toString().toLowerCase().contains(searchText) ||
             (med['salt'] ?? med['saltName'] ?? '').toString().toLowerCase().contains(searchText) ||
             (med['dosage'] ?? med['strength'] ?? med['dose'] ?? '').toString().toLowerCase().contains(searchText) ||
             (med['duration'] ?? med['frequency'] ?? '').toString().toLowerCase().contains(searchText) ||
             (med['status'] ?? '').toString().toLowerCase().contains(searchText) ||
             (med['prescriber'] ?? med['doctorName'] ?? '').toString().toLowerCase().contains(searchText) ||
             (med['startDate'] ?? med['orderDate'] ?? '').toString().toLowerCase().contains(searchText);
    }).toList();
  }

  List<dynamic> _filterOPD(String query) {
    if (query.isEmpty) return _opdEncounters;
    final searchText = query.toLowerCase();
    return _opdEncounters.where((record) {
      final row = _encounterRowData(Map<String, dynamic>.from(record as Map));
      return row.any((cell) => cell.toLowerCase().contains(searchText));
    }).toList();
  }

  List<dynamic> _filterIPD(String query) {
    if (query.isEmpty) return _ipdEncounters;
    final searchText = query.toLowerCase();
    return _ipdEncounters.where((record) {
      final row = _encounterRowData(Map<String, dynamic>.from(record as Map));
      return row.any((cell) => cell.toLowerCase().contains(searchText));
    }).toList();
  }

  List<dynamic> _filterLabs(String query) {
    if (query.isEmpty) return _aggregatedLabOrders;
    return _aggregatedLabOrders.where((lab) {
      final searchText = query.toLowerCase();
      return (lab['testName'] ?? lab['test'] ?? '').toString().toLowerCase().contains(searchText) ||
             (lab['resultValue'] ?? lab['resultNumeric'] ?? lab['result'] ?? '').toString().toLowerCase().contains(searchText) ||
             (lab['referenceRange'] ?? lab['normalRange'] ?? '').toString().toLowerCase().contains(searchText) ||
             (lab['resultStatus'] ?? '').toString().toLowerCase().contains(searchText) ||
             (lab['units'] ?? '').toString().toLowerCase().contains(searchText);
    }).toList();
  }

  List<dynamic> _filterRadiology(String query) {
    if (query.isEmpty) return _aggregatedRadiologyOrders;
    return _aggregatedRadiologyOrders.where((record) {
      final searchText = query.toLowerCase();
      final r = record as Map<String, dynamic>? ?? {};
      return (r['testName'] ?? r['clinicalDisplayName'] ?? r['procedure'] ?? '').toString().toLowerCase().contains(searchText) ||
             (r['reportStatus'] ?? '').toString().toLowerCase().contains(searchText) ||
             (r['finalFindings'] ?? r['findings'] ?? r['preliminaryFindings'] ?? '').toString().toLowerCase().contains(searchText) ||
             (r['impression'] ?? '').toString().toLowerCase().contains(searchText) ||
             (r['recommendations'] ?? '').toString().toLowerCase().contains(searchText);
    }).toList();
  }

  List<dynamic> _filterSurgery(String query) {
    if (query.isEmpty) return _surgery ?? [];
    return (_surgery ?? []).where((record) {
      final searchText = query.toLowerCase();
      return (record['surgeryName'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['surgeryCategory'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['surgeryDate'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['procedureOutcome'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['department'] ?? '').toString().toLowerCase().contains(searchText);
    }).toList();
  }

  List<dynamic> _filterPregnancy(String query) {
    if (query.isEmpty) return _pregnancyRecords ?? [];
    return (_pregnancyRecords ?? []).where((record) {
      final searchText = query.toLowerCase();
      return (record['pregnancyNumber'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['weeksOfGestation'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['modeOfDelivery'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['laborOnsetType'] ?? '').toString().toLowerCase().contains(searchText) ||
             (record['stillAlive'] ?? '').toString().toLowerCase().contains(searchText);
    }).toList();
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

  Widget _buildSectionOverlay() {
    final media = MediaQuery.of(context);
    final sectionColor = _getSectionColor(_selectedSection!);
    final isMobile = media.size.width < 600;
    final isLandscape = media.orientation == Orientation.landscape;
    final width = isMobile ? media.size.width * (isLandscape ? 0.96 : 0.94) : media.size.width * 0.92;
    final height = isMobile ? media.size.height * (isLandscape ? 0.88 : 0.86) : media.size.height * 0.82;
    final margin = isMobile ? (isLandscape ? 8.0 : 12.0) : 24.0;
    return Container(
      color: Colors.black.withOpacity(0.4),
      child: SafeArea(
        child: Center(
          child: Container(
            width: width,
            height: height,
            margin: EdgeInsets.all(margin),
            decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: isMobile ? 14 : 20),
                decoration: BoxDecoration(
                  color: sectionColor.withOpacity(0.1),
                  border: Border(bottom: BorderSide(color: sectionColor.withOpacity(0.2), width: 1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: sectionColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: sectionColor.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _getSectionIcon(_selectedSection!),
                        color: Colors.white,
                        size: isMobile ? 22 : 26,
                      ),
                    ),
                    Gap(isMobile ? 12 : 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getSectionTitle(_selectedSection!),
                            style: TextStyle(
                              fontSize: isMobile ? 17 : 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade800,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Gap(4),
                          Text(
                            '${_getDataCount(_selectedSection!)} records found',
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _hideOverlay,
                      icon: Icon(Icons.close_rounded, size: isMobile ? 22 : 24),
                      tooltip: 'Close',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.grey.shade700,
                        padding: EdgeInsets.all(isMobile ? 8 : 12),
                      ),
                    ),
                  ],
                ),
              ),
              // Content - scrollable for all section panels
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      margin: EdgeInsets.all(isMobile ? 12 : 24),
                      child: _buildSectionContent(_selectedSection!),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildSectionContent(String section) {
    if (section == 'vitals') {
      if (_allVitals.isEmpty) {
        return Center(
          child: Text(
            'No vitals found',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            headingRowHeight: 48,
            dataRowMinHeight: 42,
            dataRowMaxHeight: 52,
            headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F5F9)),
            columns: const [
              DataColumn(label: Text('Date/Time', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              DataColumn(label: Text('Blood Pressure', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              DataColumn(label: Text('Heart Rate', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              DataColumn(label: Text('Temperature', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            ],
            rows: _allVitals.asMap().entries.map((entry) {
              final idx = entry.key;
              final v = entry.value;
              final cells = _getRowDataForTab(v, 'Vital Signs');
              return DataRow(
                color: MaterialStateProperty.all(idx.isEven ? Colors.white : const Color(0xFFFAFBFC)),
                cells: cells.map((cell) => DataCell(
                  Container(
                    constraints: const BoxConstraints(minWidth: 100, maxWidth: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    child: Text(
                      cell.isEmpty ? '-' : cell,
                      style: TextStyle(fontSize: 13, height: 1.25, color: Colors.grey.shade800),
                      maxLines: 2,
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

    if (section == 'labs') {
      if (_aggregatedLabOrders.isEmpty) {
        return Center(
          child: Text(
            'No lab results found',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 40,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 40,
            headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Package Name', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Test Name', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Result', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Reference Range', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _aggregatedLabOrders.map((lab) {
              final cells = _getRowDataForTab(lab, 'Lab Results');
              final outOfRange = cells.length >= 5 && _isResultOutOfReferenceRange(cells[3], cells[4]);
              return DataRow(
                cells: cells.asMap().entries.map((entry) {
                  final i = entry.key;
                  final cell = entry.value;
                  final isResultCell = i == 3;
                  return DataCell(
                    Container(
                      constraints: const BoxConstraints(minWidth: 90, maxWidth: 180),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: Text(
                        cell.isEmpty ? '-' : cell,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.1,
                          color: isResultCell && outOfRange ? Colors.red : null,
                          fontWeight: isResultCell && outOfRange ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      );
    }

    if (section == 'medications') {
      if (_activeMedicines.isEmpty) {
        return Center(
          child: Text(
            'No medications found',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 40,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 40,
            headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(label: Text('Start Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Salt', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Medication', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Dosage', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Duration', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Prescriber', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _activeMedicines.map((m) {
              final startDate = _formatDateDDMMYYYY(m['startDate'] ?? m['start_date'] ?? m['orderDate']);
              final salt = (m['salt'] ?? m['saltName'] ?? '').toString();
              final medName = (m['medication'] ?? m['medicationName'] ?? m['name'] ?? '').toString();
              final doseAmt = (m['dosage'] ?? m['strength'] ?? m['dose'] ?? '').toString();
              final doseUnit = (m['strength_unit'] ?? m['dosageUnit'] ?? '').toString();
              final dosage = [doseAmt, doseUnit].where((e) => e.toString().trim().isNotEmpty).join(' ');
              final duration = (m['duration'] ?? m['frequency'] ?? '').toString();
              final status = (m['status'] ?? 'Active').toString();
              final prescriber = (m['prescriber'] ?? m['doctorName'] ?? m['prescribedBy'] ?? '').toString();

              List<String> cells = [startDate, salt, medName, dosage, duration, status, prescriber];
              return DataRow(
                cells: cells.map((cell) {
                  return DataCell(
                    Container(
                      constraints: const BoxConstraints(minWidth: 90, maxWidth: 180),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: Text(
                        cell.isEmpty ? '-' : cell,
                        style: const TextStyle(fontSize: 12, height: 1.1),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      );
    }

    if (section == 'radiology') {
      if (_aggregatedRadiologyOrders.isEmpty) {
        return Center(
          child: Text(
            'No radiology records found',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 40,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 80,
            headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Procedure', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Indication', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Findings', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Impression', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Radiologist', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _aggregatedRadiologyOrders.map((r) {
              final rad = r as Map<String, dynamic>? ?? {};
              final date = _formatDateDDMMYYYY(rad['orderDate'] ?? rad['date']);
              final procedure = (rad['testName'] ?? rad['clinicalDisplayName'] ?? rad['procedure'] ?? '').toString();
              final indication = (rad['indication'] ?? '').toString();
              final findings = (rad['finalFindings'] ?? rad['findings'] ?? rad['preliminaryFindings'] ?? '').toString();
              final impression = (rad['impression'] ?? '').toString();
              final radiologist = (rad['radiologist_Name'] ?? rad['radiologist'] ?? '').toString();

              List<String> cells = [date, procedure, indication, findings, impression, radiologist];
              return DataRow(
                cells: cells.map((cell) {
                  return DataCell(
                    Container(
                      constraints: const BoxConstraints(minWidth: 100, maxWidth: 250),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: Text(
                        cell.isEmpty ? '-' : cell,
                        style: const TextStyle(fontSize: 12, height: 1.2),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      );
    }

    if (section == 'opd') {
      if (_opdEncounters.isEmpty) {
        return Center(child: Text('No OPD encounters found', style: Theme.of(context).textTheme.bodyLarge));
      }
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 40,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 80,
            headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Presenting Complaint', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Symptoms', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Diagnosis', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Clinical Notes', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Medicines', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Lab / Radiology', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _opdEncounters.map((e) {
              final cells = _encounterRowData(Map<String, dynamic>.from(e as Map));
              return DataRow(
                cells: cells.map((cell) => DataCell(Container(
                  constraints: const BoxConstraints(minWidth: 100, maxWidth: 220),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: Text(cell.isEmpty ? '-' : cell, style: const TextStyle(fontSize: 12, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                ))).toList(),
              );
            }).toList(),
          ),
        ),
      );
    }
    if (section == 'ipd') {
      if (_ipdEncounters.isEmpty) {
        return Center(child: Text('No IPD encounters found', style: Theme.of(context).textTheme.bodyLarge));
      }
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 40,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 80,
            headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Presenting Complaint', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Symptoms', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Diagnosis', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Clinical Notes', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Medicines', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Lab / Radiology', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _ipdEncounters.map((e) {
              final cells = _encounterRowData(Map<String, dynamic>.from(e as Map));
              return DataRow(
                cells: cells.map((cell) => DataCell(Container(
                  constraints: const BoxConstraints(minWidth: 100, maxWidth: 220),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: Text(cell.isEmpty ? '-' : cell, style: const TextStyle(fontSize: 12, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                ))).toList(),
              );
            }).toList(),
          ),
        ),
      );
    }
    if (section == 'surgery') {
      final surgeries = _surgery ?? [];
      if (surgeries.isEmpty) {
        return Center(
          child: Text(
            'No surgery records found',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 40,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 40,
            headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(label: Text('Surgery Name', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Outcome', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: surgeries.map((s) {
              final surgeryName = (s['surgeryName'] ?? s['name'] ?? '').toString();
              final category = (s['surgeryCategory'] ?? s['category'] ?? '').toString();
              final surgeryDate = _formatDateDDMMYYYY(s['surgeryDate'] ?? s['date']);
              final outcome = (s['procedureOutcome'] ?? s['outcome'] ?? '').toString();
              final department = (s['department'] ?? s['departmentName'] ?? '').toString();

              List<String> cells = [surgeryName, category, surgeryDate, outcome, department];
              return DataRow(
                cells: cells.map((cell) {
                  return DataCell(
                    Container(
                      constraints: const BoxConstraints(minWidth: 100, maxWidth: 200),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: Text(
                        cell.isEmpty ? '-' : cell,
                        style: const TextStyle(fontSize: 12, height: 1.1),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      );
    }

    // Default placeholder for other sections
    return Center(
      child: Text(
        'Detailed content for $section section',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }

  IconData _getSectionIcon(String section) {
    switch (section) {
      case 'vitals':
        return Icons.favorite;
      case 'medications':
        return Icons.medication;
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
      case 'medications':
        return Colors.green;
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
      case 'medications':
        return 'Medications';
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
        return 'Pregnancy Records';
      default:
        return 'Section Details';
    }
  }

  int _getDataCount(String section) {
    switch (section) {
      case 'vitals':
        return _allVitals.length;
      case 'medications':
        return _activeMedicines.length;
      case 'opd':
        return _opdEncounters.length;
      case 'ipd':
        return _ipdEncounters.length;
      case 'labs':
        return _labPackageCount;
      case 'radiology':
        return _aggregatedRadiologyOrders.length;
      case 'surgery':
        return _surgery?.length ?? 0;
      case 'pregnancy':
        return _pregnancyRecords?.length ?? 0;
      default:
        return 0;
    }
  }

  Future<void> _generateAndPrintPDF(String section) async {
    try {
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header with patient details
              pw.Text(
                'PATIENT MEDICAL RECORD',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Patient Name: ${widget.patient['fullName'] ?? 'N/A'}'),
              pw.Text('MRN: ${widget.patient['mrn'] ?? 'N/A'}'),
              pw.Text('Generated: ${DateTime.now().toString().split('.')[0]}'),
              pw.Divider(),
              pw.Text('Patient history data will be included here...'),
            ];
          },
        ),
      );

      // Print the PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: '${widget.patient['fullName'] ?? 'Patient'}_History_${DateTime.now().millisecondsSinceEpoch}.pdf',
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
}
