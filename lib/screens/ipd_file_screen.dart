import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:convert';
import '../services/encounter_service.dart';
import '../utils/app_date_format.dart';
import '../services/pregnancy_service.dart';
import '../services/pharmacy_service.dart';
import '../services/user_session_service.dart';
import '../utils/app_snackbar.dart';
import '../utils/clinical_notes_format.dart';
import '../services/surgery_service.dart';
import 'checkUp_screen.dart';
import 'patient_file_print_helper.dart';

class IpdFileScreen extends StatefulWidget {
  final Map<String, dynamic> patient;
  final int? admissionId;

  const IpdFileScreen({
    Key? key,
    required this.patient,
    this.admissionId,
  }) : super(key: key);

  @override
  State<IpdFileScreen> createState() => _IpdFileScreenState();
}

class _IpdFileScreenState extends State<IpdFileScreen> {
  final EncounterService _encounterService = EncounterService();
  final PregnancyService _pregnancyService = PregnancyService();
  
  List<Map<String, dynamic>> _encounters = [];
  List<Map<String, dynamic>> _encounterDataList = []; // Full encounter data with all details
  List<Map<String, dynamic>> _surgeries = []; // Patient surgeries
  List<dynamic> _allVitals = []; // All patient vitals
  List<Map<String, dynamic>> _combinedTimeline = []; // Combined vitals, encounters and surgeries in chronological order
  bool _loading = false;
  bool _loadingDetails = false;
  String? _error;
  
  // Header summary data
  List<dynamic> _headerChronic = [];
  List<dynamic> _headerAllergies = [];
  List<dynamic> _headerRiskFactors = [];
  List<Map<String, dynamic>> _headerMedications = [];

  // Date filters
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 15));
  DateTime _endDate = DateTime.now();
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    try {
      
      _loadHeaderSummary();
      // Don't load data automatically - wait for Show button
    } catch (e, stackTrace) {
    }
  }

  int? _parseId(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  Map<int, List<dynamic>> _groupByEncounterId(List<dynamic>? rows) {
    final map = <int, List<dynamic>>{};
    if (rows == null) return map;
    for (final row in rows) {
      if (row is! Map) continue;
      final id = _parseId(row['encounterId'] ?? row['EncounterId'] ?? row['EncounterID']);
      if (id == null) continue;
      map.putIfAbsent(id, () => []).add(Map<String, dynamic>.from(row));
    }
    return map;
  }

  List<Map<String, dynamic>> _buildEncounterDataListFromHistory(Map<String, dynamic> history) {
    final encounters = List<Map<String, dynamic>>.from(
      (history['encounters'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? const [],
    );
    final modules = (history['encounterModules'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final vitalsBy = _groupByEncounterId(history['vitals'] as List?);
    final complaintsBy = _groupByEncounterId(modules['complaints'] as List?);
    final symptomsBy = _groupByEncounterId(modules['symptoms'] as List?);
    final diagnosesBy = _groupByEncounterId(modules['diagnoses'] as List?);
    final labBy = _groupByEncounterId(modules['labOrders'] as List?);
    final radBy = _groupByEncounterId(modules['radiologyOrders'] as List?);
    final medsBy = _groupByEncounterId(modules['medicines'] as List?);
    final notesBy = _groupByEncounterId(modules['notes'] as List?);

    final out = <Map<String, dynamic>>[];
    for (final encounter in encounters) {
      final id = _parseId(encounter['encounterId'] ?? encounter['EncounterID']);
      if (id == null) continue;
      final notes = notesBy[id] ?? const [];
      out.add({
        'encounter': encounter,
        'vitals': vitalsBy[id] ?? const [],
        'complaints': complaintsBy[id] ?? const [],
        'symptoms': symptomsBy[id] ?? const [],
        'diagnoses': diagnosesBy[id] ?? const [],
        'labOrders': labBy[id] ?? const [],
        'radiologyOrders': radBy[id] ?? const [],
        'medicines': medsBy[id] ?? const [],
        'notes': notes,
        'clinicalNotes': notes,
      });
    }
    return out;
  }

  bool _isDateInRange(DateTime? d, DateTime from, DateTime to) {
    if (d == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    final f = DateTime(from.year, from.month, from.day);
    final t = DateTime(to.year, to.month, to.day);
    return !day.isBefore(f) && !day.isAfter(t);
  }

  Future<List<Map<String, dynamic>>> _loadSurgeriesInRange(int patientId, DateTime from, DateTime to) async {
    try {
      final surgeries = await SurgeryService.getPatientSurgeries(patientId);
      return surgeries.where((s) {
        final raw = s['surgeryDate'] ?? s['SurgeryDate'];
        if (raw == null) return false;
        final d = raw is DateTime ? raw : DateTime.tryParse(raw.toString());
        return _isDateInRange(d, from, to);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  List<Map<String, dynamic>> _computeCombinedTimeline() {
    final timeline = <Map<String, dynamic>>[];

    for (final vital in _allVitals) {
      if (vital is! Map) continue;
      final encounterId = vital['encounterId'] ?? vital['EncounterID'] ?? vital['encounterID'];
      if (encounterId != null) continue;
      final recordedDate = vital['recordedDate'] ?? vital['RecordedDate'] ?? vital['recordedAt'] ?? vital['createdAt'];
      DateTime? parsedDate;
      if (recordedDate != null) {
        parsedDate = recordedDate is DateTime ? recordedDate : DateTime.tryParse(recordedDate.toString());
      }
      timeline.add({'type': 'vitals', 'date': parsedDate, 'data': Map<String, dynamic>.from(vital)});
    }

    for (final encounterData in _encounterDataList) {
      final encounter = encounterData['encounter'] as Map<String, dynamic>;
      final encounterDate = encounter['encounterDate'] ??
          encounter['EncounterDate'] ??
          encounter['checkInTime'] ??
          encounter['CheckInTime'];
      DateTime? parsedDate;
      if (encounterDate != null) {
        parsedDate = encounterDate is DateTime ? encounterDate : DateTime.tryParse(encounterDate.toString());
      }
      timeline.add({'type': 'encounter', 'date': parsedDate, 'data': encounterData});
    }

    for (final surgery in _surgeries) {
      final surgeryDate = surgery['surgeryDate'] ?? surgery['SurgeryDate'];
      DateTime? parsedDate;
      if (surgeryDate != null) {
        parsedDate = surgeryDate is DateTime ? surgeryDate : DateTime.tryParse(surgeryDate.toString());
      }
      timeline.add({'type': 'surgery', 'date': parsedDate, 'data': surgery});
    }

    timeline.sort((a, b) {
      final dateA = a['date'] as DateTime?;
      final dateB = b['date'] as DateTime?;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    var encNum = 0;
    for (final item in timeline) {
      if (item['type'] == 'encounter') {
        encNum++;
        item['encounterNumber'] = encNum;
      }
    }
    return timeline;
  }

  void _buildCombinedTimeline() {
    _combinedTimeline = _computeCombinedTimeline();
  }

  Future<void> _loadHeaderSummary() async {
    try {
      final patientId = widget.patient['patientId'] ?? widget.patient['PatientID'];
      if (patientId == null) {
        return;
      }

      final parsedPatientId = patientId is int ? patientId : int.tryParse(patientId.toString());
      if (parsedPatientId == null) {
        return;
      }

      final results = await Future.wait([
        _encounterService.getPatientChronicConditions(parsedPatientId),
        _pregnancyService.getPatientAllergies(parsedPatientId),
        _pregnancyService.getPatientRiskFactors(parsedPatientId),
        PharmacyService.getActivePatientMedicines(patientId: parsedPatientId),
      ]);

      setState(() {
        try {
          _headerChronic = results[0] as List<dynamic>;
          _headerAllergies = results[1] as List<dynamic>;
          _headerRiskFactors = results[2] as List<dynamic>;
          
          // Extract unique salt names from active medicines for header display
          final activeMedicines = results[3] as List<Map<String, dynamic>>;
          final Set<String> uniqueSaltNames = {};
          for (final item in activeMedicines) {
            try {
              final saltName = item['SaltName'] ?? item['saltName'] ?? item['Salt'] ?? item['salt'];
              if (saltName != null && saltName.toString().trim().isNotEmpty) {
                uniqueSaltNames.add(saltName.toString().trim());
              }
            } catch (e) {
            }
          }
          
          // Update header medications with salt names
          _headerMedications = uniqueSaltNames.map((saltName) => {
            'name': saltName,
            'saltName': saltName,
          }).toList();
        } catch (e, stackTrace) {
        }
      });
    } catch (e, stackTrace) {
      // Non-blocking: keep UI usable even if header fails
    }
  }

  Future<void> _loadDataWithFilters() async {
    if (_startDate.isAfter(_endDate)) {
      AppSnackBar.showInfo(context, 'From date must be less than or equal to To date');
      return;
    }
    final days = _endDate.difference(_startDate).inDays;
    if (days > 90) {
      AppSnackBar.showInfo(
        context,
        'Large range ($days days). Results capped (50 encounters).',
      );
    }

    setState(() {
      _loading = true;
      _loadingDetails = false;
      _dataLoaded = false;
      _error = null;
      _encounters = [];
      _encounterDataList = [];
      _allVitals = [];
      _surgeries = [];
      _combinedTimeline = [];
    });

    final patientId = widget.patient['patientId'] ?? widget.patient['PatientID'];
    if (patientId == null) {
      setState(() => _loading = false);
      return;
    }

    final parsedPatientId = patientId is int ? patientId : int.tryParse(patientId.toString());
    if (parsedPatientId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final endDate = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      final startDate = DateTime(_startDate.year, _startDate.month, _startDate.day, 0, 0, 0);

      final results = await Future.wait([
        _encounterService.getPatientClinicalHistory(
          parsedPatientId,
          fromDate: startDate,
          toDate: endDate,
        ),
        _loadSurgeriesInRange(parsedPatientId, startDate, endDate),
      ]);

      final history = results[0] as Map<String, dynamic>;
      final surgeries = results[1] as List<Map<String, dynamic>>;
      final encounterDataList = _buildEncounterDataListFromHistory(history);
      final encounters = encounterDataList
          .map((e) => Map<String, dynamic>.from(e['encounter'] as Map))
          .toList();
      final vitals = List<dynamic>.from(history['vitals'] as List? ?? const []);

      if (!mounted) return;
      setState(() {
        _encounters = encounters;
        _encounterDataList = encounterDataList;
        _allVitals = vitals;
        _surgeries = surgeries;
        _combinedTimeline = _computeCombinedTimeline();
        _dataLoaded = true;
        _loading = false;
        _error = null;
      });

      final caps = history['caps'];
      final returned = caps is Map ? (caps['encounterCountReturned'] ?? encounters.length) : encounters.length;
      final maxEnc = caps is Map ? (caps['encounters'] ?? 50) : 50;
      if (returned is num && maxEnc is num && returned >= maxEnc && mounted) {
        AppSnackBar.showInfo(context, 'Showing latest $maxEnc encounters (cap). Narrow dates for older visits.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load patient file. Please retry.';
          _loading = false;
          _dataLoaded = true;
        });
      }
    }
  }

  Widget _buildDateFilterSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 2),
            spreadRadius: 1,
          ),
        ],
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.date_range, color: Colors.blue[700], size: 20),
          const SizedBox(width: 8),
          Text(
            'From:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _startDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  _startDate = picked;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppDateFormat.formatDate(_startDate),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'To:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _endDate,
                firstDate: _startDate,
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() {
                  _endDate = picked;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppDateFormat.formatDate(_endDate),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _loadDataWithFilters,
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Show'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientInfoCard() {
    try {
      
      // Safely extract and convert name
      final nameValue = widget.patient['fullName'] ?? widget.patient['name'];
      final String name = nameValue?.toString() ?? 'Unknown';
      
      // Safely extract and convert MRN
      final mrnValue = widget.patient['mrn'];
      final String mrn = mrnValue?.toString() ?? 'N/A';
      
      // Safely extract and convert gender
      final genderValue = widget.patient['gender'];
      final String gender = genderValue?.toString() ?? '';
      
      // Safely extract and convert age
      final ageValue = widget.patient['age'];
      final String age = (ageValue != null) ? '${ageValue.toString()}y' : '';
      
      // Safely extract and convert blood group
      final bloodValue = widget.patient['bloodGroup'];
      final String blood = bloodValue?.toString() ?? '';
      

    String joinWithComma(Iterable<String> items, {int max = 6}) {
      try {
        final list = items.where((e) {
          try {
            return e.trim().isNotEmpty;
          } catch (ex) {
            return false;
          }
        }).toList();
        if (list.length > max) {
          return list.sublist(0, max).join(', ') + ' +' + (list.length - max).toString();
        }
        return list.join(', ');
      } catch (e) {
        return '';
      }
    }

    final allergiesText = joinWithComma(
      _headerAllergies.map((a) {
        try {
          final m = a as Map<String, dynamic>;
          final nameValue = m['allergyName'] ?? m['AllergyName'];
          final name = nameValue?.toString() ?? '';
          final severityValue = m['severity'] ?? m['Severity'];
          final severity = severityValue?.toString() ?? '';
          final result = severity.isNotEmpty ? '$name (${severity.length >= 3 ? severity.substring(0, 3) : severity})' : name;
          return result;
        } catch (e) {
          return '';
        }
      }).where((s) => s.isNotEmpty),
    );

    final chronicText = joinWithComma(
      _headerChronic.map((c) {
        try {
          final m = c as Map<String, dynamic>;
          final nameValue = m['conditionName'] ?? m['ConditionName'];
          final name = nameValue?.toString() ?? '';
          final codeValue = m['icd11Code'] ?? m['ICD11Code'];
          final code = codeValue?.toString() ?? '';
          final result = code.isNotEmpty ? '$name ($code)' : name;
          return result;
        } catch (e) {
          return '';
        }
      }).where((s) => s.isNotEmpty),
    );

    final medsText = joinWithComma(
      _headerMedications.map((m) {
        try {
          final nameValue = m['name'] ?? m['medicineName'];
          final result = nameValue?.toString() ?? '';
          return result;
        } catch (e) {
          return '';
        }
      }).where((s) => s.isNotEmpty),
      max: 4,
    );

    final risksText = joinWithComma(
      _headerRiskFactors
          .where((r) {
            try {
              final isPresent = r['isPresent'] ?? r['is_present'] ?? true;
              return isPresent == true || isPresent == 1;
            } catch (e) {
              return false;
            }
          })
          .map((r) {
            try {
              final nameValue = r['riskFactorName'] ?? r['risk_factor_name'];
              final result = nameValue?.toString() ?? '';
              return result;
            } catch (e) {
              return '';
            }
          }).where((s) => s.isNotEmpty),
      max: 6,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        try {
          final screenWidth = MediaQuery.of(context).size.width;
          return Transform.translate(
          offset: Offset(-12.0, 0),
          child: SizedBox(
            width: screenWidth,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6366F1), // Indigo-500
                    Color(0xFF8B5CF6), // Purple-500
                    Color(0xFFA855F7), // Purple-400
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'MRN: $mrn',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Builder(
                          builder: (context) {
                            try {
                              final genderAgeText = '$gender, $age';
                              return Text(
                                genderAgeText,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.95),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
                                ),
                              );
                            } catch (e) {
                              return Text(
                                '${gender.toString()}, ${age.toString()}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.95),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 20),
                        Builder(
                          builder: (context) {
                            try {
                              return Row(
                                children: [
                                  _pill(icon: Icons.warning_amber_rounded, label: 'Allergies', value: allergiesText, color: Colors.orangeAccent),
                                  const SizedBox(width: 14),
                                  _pill(icon: Icons.healing, label: 'Chronic', value: chronicText, color: Colors.lightBlueAccent),
                                  const SizedBox(width: 14),
                                  _pill(icon: Icons.local_pharmacy, label: 'Current Meds', value: medsText, color: Colors.pinkAccent),
                                  const SizedBox(width: 14),
                                  _pill(icon: Icons.report_problem, label: 'Risk Factors', value: risksText, color: Colors.redAccent),
                                ],
                              );
                            } catch (e) {
                              return const SizedBox.shrink();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        } catch (e, stackTrace) {
          return Container(
            padding: EdgeInsets.all(16),
            child: Text('Error displaying patient info: $e', style: TextStyle(color: Colors.red)),
          );
        }
      },
    );
    } catch (e, stackTrace) {
      return Container(
        padding: EdgeInsets.all(16),
        child: Text('Error: $e', style: TextStyle(color: Colors.red)),
      );
    }
  }

  Widget _pill({required IconData icon, required String label, required String value, required Color color}) {
    try {
      final text = value.isNotEmpty ? value : 'None';
      return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(
            '$label:',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      );
    } catch (e) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text('Error: $label', style: TextStyle(color: Colors.white, fontSize: 12)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient File'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _generateAndPrintAllEncounters,
            tooltip: 'Print All Encounters',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPatientInfoCard(),
          _buildDateFilterSection(),
          const SizedBox(height: 8),
          Expanded(
            child: !_dataLoaded
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_alt, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Select date range and click Show to load data',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : _loading || _loadingDetails
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                                const SizedBox(height: 16),
                                Text(
                                  _error!,
                                  style: TextStyle(color: Colors.red[700]),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadDataWithFilters,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _combinedTimeline.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.folder_open, size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No timeline data for selected dates',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12.0),
                                itemCount: _combinedTimeline.length,
                                itemBuilder: (context, index) {
                                  final item = _combinedTimeline[index];
                                  final type = item['type'] as String;
                                  if (type == 'vitals') {
                                    return _buildVitalsCard(item['data'] as Map<String, dynamic>);
                                  }
                                  if (type == 'encounter') {
                                    final data = item['data'] as Map<String, dynamic>;
                                    final encounterNumber = (item['encounterNumber'] as int?) ?? (index + 1);
                                    return _buildDetailedEncounterCard(data, encounterNumber);
                                  }
                                  if (type == 'surgery') {
                                    return _buildSurgeryCard(item['data'] as Map<String, dynamic>);
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedEncounterCard(Map<String, dynamic> data, int encounterNumber) {
    final encounter = data['encounter'] as Map<String, dynamic>;
    final encounterId = encounter['encounterId'] ?? 
                       encounter['EncounterID'] ?? 
                       encounter['encounterID'];
    final encounterDate = encounter['encounterDate'] ?? 
                          encounter['EncounterDate'] ?? 
                          encounter['checkInTime'] ?? 
                          encounter['CheckInTime'];
    final status = encounter['encounterStatus'] ?? 
                   encounter['EncounterStatus'] ?? 
                   '';
    final doctorName = encounter['doctorName'] ?? 
                      encounter['DoctorName'] ?? 
                      encounter['doctor'] ?? 
                      'N/A';
    final encounterType = encounter['encounterType'] ?? 
                         encounter['EncounterType'] ?? 
                         '';
    
    DateTime? parsedDate;
    if (encounterDate != null) {
      if (encounterDate is DateTime) {
        parsedDate = encounterDate;
      } else {
        parsedDate = DateTime.tryParse(encounterDate.toString());
      }
    }

    final vitals = data['vitals'] as List<dynamic>;
    final complaints = data['complaints'] as List<dynamic>;
    final symptoms = data['symptoms'] as List<dynamic>;
    final diagnoses = data['diagnoses'] as List<dynamic>;
    final labOrdersRaw = data['labOrders'] as List<dynamic>;
    
    // Group lab orders: collect all tests per package, individual tests as-is
    final Map<String, Map<String, dynamic>> packageMap = {};
    final List<Map<String, dynamic>> testItems = [];
    
    for (final order in labOrdersRaw) {
      final packageId = order['packageId'];
      final bool isPackage = packageId != null;
      
      if (isPackage) {
        final packageKey = 'package_${packageId}_${order['orderId'] ?? ''}';
        if (!packageMap.containsKey(packageKey)) {
          final rateValue = order['rate'];
          final double rate = rateValue is num
              ? rateValue.toDouble()
              : double.tryParse(rateValue?.toString() ?? '') ?? 0;
          packageMap[packageKey] = {
            'type': 'package',
            'packageId': packageId,
            'packageName': order['packageName'] ?? order['testName'] ?? 'N/A',
            'packageCost': rate,
            'orderId': order['orderId'],
            'orderNumber': order['orderNumber'],
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
          'validationStatus': order['validationStatus'],
          'isCritical': order['isCritical'],
          'resultStatus': order['resultStatus'],
          'resultInterpretation': order['resultInterpretation'],
          'entryDate': order['entryDate'],
          'validationDate': order['validationDate'],
          'sampleTestId': order['sampleTestId'],
          'sampleBarcode': order['sampleBarcode'],
        });
      } else {
        // Individual test - add to list with all result data
        final rateValue = order['rate'];
        final double rate = rateValue is num
            ? rateValue.toDouble()
            : double.tryParse(rateValue?.toString() ?? '') ?? 0;
        testItems.add({
          'type': 'test',
          'testId': order['testId'],
          'testName': order['testName'] ?? 'N/A',
          'testCost': rate,
          'orderId': order['orderId'],
          'orderNumber': order['orderNumber'],
          // Include result data
          'resultId': order['resultId'],
          'resultValue': order['resultValue'],
          'resultNumeric': order['resultNumeric'],
          'units': order['units'],
          'referenceRange': order['referenceRange'],
          'abnormalFlags': order['abnormalFlags'],
          'validationStatus': order['validationStatus'],
          'isCritical': order['isCritical'],
          'resultStatus': order['resultStatus'],
          'resultInterpretation': order['resultInterpretation'],
          'entryDate': order['entryDate'],
          'validationDate': order['validationDate'],
          'sampleTestId': order['sampleTestId'],
          'sampleBarcode': order['sampleBarcode'],
        });
      }
    }
    
    // Expand packages: one row per test (for results). List view collapses to package names.
    final List<Map<String, dynamic>> labOrders = [];
    for (final pkg in packageMap.values) {
      final tests = pkg['tests'] as List<dynamic>;
      for (final t in tests) {
        labOrders.add({
          'type': 'package_test',
          'packageId': pkg['packageId'],
          'orderId': pkg['orderId'],
          'packageName': pkg['packageName'],
          'testName': t['testName'],
          'resultId': t['resultId'],
          'resultValue': t['resultValue'],
          'resultNumeric': t['resultNumeric'],
          'units': t['units'],
          'referenceRange': t['referenceRange'],
          'abnormalFlags': t['abnormalFlags'],
          'validationStatus': t['validationStatus'],
          'isCritical': t['isCritical'],
          'resultStatus': t['resultStatus'],
          'resultInterpretation': t['resultInterpretation'],
          'entryDate': t['entryDate'],
          'validationDate': t['validationDate'],
          'sampleTestId': t['sampleTestId'],
          'sampleBarcode': t['sampleBarcode'],
        });
      }
    }
    labOrders.addAll(testItems);
    final radiologyOrders = data['radiologyOrders'] as List<dynamic>;
    final medicines = data['medicines'] as List<dynamic>;
    final clinicalNoteTexts = extractClinicalNoteTexts(
      data['clinicalNotes'],
      fallbackNotes: data['notes'] as List<dynamic>?,
    );

    return InkWell(
      onTap: () {
        // Navigate to checkUp screen with this encounter
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CheckUpScreen(
              patient: {
                ...widget.patient,
                'encounterId': encounterId,
                'EncounterID': encounterId,
              },
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              offset: Offset(0, 4),
              spreadRadius: 2,
            ),
          ],
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encounter Header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[700]!, Colors.blue[600]!],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        encounterType.toString().isNotEmpty 
                            ? '$encounterType Checkup'
                            : 'Checkup',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (parsedDate != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today, size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          AppDateFormat.formatDateTime(parsedDate),
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                      const SizedBox(width: 16),
                      Icon(Icons.person, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          doctorName,
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getStatusColor(status), width: 1),
                  ),
                  child: Text(
                    status.toString().toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Encounter Details
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vitals
                if (vitals.isNotEmpty) ...[
                  ...vitals.map((v) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _buildCompactVitalsBlock(v as Map<dynamic, dynamic>),
                      )),
                  const SizedBox(height: 8),
                ],

                // Complaints, Symptoms, Diagnosis - Adjacent to each other
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildCompactDetailSection(
                        'Complaints',
                        Icons.comment,
                        Colors.orange,
                        complaints.map<String>((c) => 
                          (c['diagnosisName'] ?? 
                          c['icd10Description'] ?? 
                          c['ICD10Description'] ?? 
                          'N/A').toString()
                        ).toList(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCompactDetailSection(
                        'Symptoms',
                        Icons.sick,
                        Colors.red,
                        symptoms.map<String>((s) => 
                          (s['diagnosisName'] ?? 
                          s['icd10Description'] ?? 
                          s['ICD10Description'] ?? 
                          'N/A').toString()
                        ).toList(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCompactDetailSection(
                        'Diagnosis',
                        Icons.medical_information,
                        Colors.green,
                        diagnoses.map<String>((d) {
                          final name = (d['diagnosisName'] ?? 
                                      d['icd10Description'] ?? 
                                      d['ICD10Description'] ?? 
                                      'N/A').toString();
                          final isConfirmed = d['isConfirmed'] ?? d['IsConfirmed'] ?? false;
                          return isConfirmed ? '$name (Confirmed)' : name;
                        }).toList(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Clinical Notes
                if (clinicalNoteTexts.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.indigo[50]!,
                          Colors.blue[50]!,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.indigo.withOpacity(0.08),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.indigo[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.note_alt, color: Colors.indigo[700], size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Clinical Notes',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.indigo[800],
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...clinicalNoteTexts.map(
                          (note) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '• $note',
                              style: const TextStyle(fontSize: 13, height: 1.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Lab Tests, Radiology Tests, Medicines - Adjacent to each other
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildLabResultsSection(labOrders),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildRadiologyReportsSection(radiologyOrders),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCompactDetailSection(
                        'Medicines',
                        Icons.medication,
                        Colors.purple,
                        medicines.map<String>((med) {
                          // Medicine name can be directly in med object or nested
                          final name = (med['medicineName'] ?? 
                                       med['MedicineName'] ?? 
                                       med['medicine']?['name'] ?? 
                                       med['Medicine']?['name'] ?? 
                                       med['medicine']?['Name'] ?? 
                                       med['Medicine']?['Name'] ?? 
                                       'N/A').toString();
                          final dosage = med['dosageAmount'] ?? med['dosageValue'] ?? med['dosage'] ?? '';
                          final dosageUnit = med['dosageUnit'] ?? med['DosageUnit'] ?? '';
                          final frequency = med['frequency'] ?? med['Frequency'] ?? med['instructions'] ?? '';
                          final duration = med['duration'] ?? med['durationValue'] ?? med['DurationValue'] ?? '';
                          final durationUnit = med['durationUnit'] ?? med['DurationUnit'] ?? med['DurationUnitValue'] ?? '';
                          final endDate = med['endDate'];
                          final discontinuedDate = med['discontinuedDate'] ?? med['DiscontinuedDate'];
                          
                          String medText = name;
                          if (dosage != null && dosageUnit != null && dosage.toString().isNotEmpty) {
                            medText += ' - $dosage $dosageUnit';
                          }
                          if (frequency != null && frequency.toString().isNotEmpty) {
                            medText += ' - $frequency';
                          }
                          if (duration != null && durationUnit != null && duration.toString().isNotEmpty) {
                            medText += ' - $duration $durationUnit';
                          }
                          if (endDate != null) {
                            try {
                              final end = endDate is DateTime ? endDate : DateTime.tryParse(endDate.toString());
                              if (end != null) {
                                medText += ' - End Date: ${AppDateFormat.formatDate(end)}';
                              }
                            } catch (e) {}
                          }
                          if (discontinuedDate != null) {
                            medText += ' (DISCONTINUED)';
                          }
                          return medText;
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildVitalsCard(Map<String, dynamic> vital) {
    final recordedDate = vital['recordedDate'] ??
        vital['RecordedDate'] ??
        vital['recordedAt'] ??
        vital['createdAt'];

    DateTime? parsedDate;
    if (recordedDate != null) {
      parsedDate = recordedDate is DateTime
          ? recordedDate
          : DateTime.tryParse(recordedDate.toString());
    }

    final createdByName = vital['createdByName'] ??
        vital['CreatedByName'] ??
        vital['recordedBy'] ??
        vital['RecordedBy'] ??
        '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: _buildCompactVitalsBlock(
        vital,
        recordedDate: parsedDate,
        recordedBy: createdByName.toString(),
      ),
    );
  }

  Widget _buildSurgeryCard(Map<String, dynamic> surgery) {
    final surgeryId = surgery['patientSurgeryID'] ?? 
                     surgery['PatientSurgeryID'] ?? 
                     surgery['patientSurgeryId'];
    final surgeryName = surgery['surgeryName'] ?? 
                       surgery['SurgeryName'] ?? 
                       'N/A';
    final surgeryDate = surgery['surgeryDate'] ?? 
                       surgery['SurgeryDate'];
    final surgeryStartTime = surgery['surgeryStartTime'] ?? 
                            surgery['SurgeryStartTime'] ?? 
                            '';
    final surgeryEndTime = surgery['surgeryEndTime'] ?? 
                          surgery['SurgeryEndTime'] ?? 
                          '';
    final surgeonName = surgery['surgeonName'] ?? 
                       surgery['SurgeonName'] ?? 
                       surgery['surgeon'] ?? 
                       'N/A';
    final assistantSurgeonName = surgery['assistantSurgeonName'] ?? 
                                surgery['AssistantSurgeonName'] ?? 
                                '';
    final anesthesiaType = surgery['anesthesiaType'] ?? 
                          surgery['AnesthesiaType'] ?? 
                          '';
    final procedureOutcome = surgery['procedureOutcome'] ?? 
                            surgery['ProcedureOutcome'] ?? 
                            '';
    final procedureNote = surgery['procedureNote'] ?? 
                         surgery['ProcedureNote'] ?? 
                         '';
    final complication = surgery['complication'] ?? 
                       surgery['Complication'] ?? 
                       '';
    final surgeryStatus = surgery['surgeryStatus'] ?? 
                        surgery['SurgeryStatus'] ?? 
                        'Completed';
    
    DateTime? parsedDate;
    if (surgeryDate != null) {
      parsedDate = surgeryDate is DateTime 
          ? surgeryDate 
          : DateTime.tryParse(surgeryDate.toString());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: Colors.amber[300]!, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Surgery Header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber[700]!, Colors.amber[600]!],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.healing, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              surgeryName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (parsedDate != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.calendar_today, size: 14, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              AppDateFormat.formatDate(parsedDate),
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            if (surgeryStartTime.toString().isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.access_time, size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                '${surgeryStartTime}${surgeryEndTime.toString().isNotEmpty ? ' - $surgeryEndTime' : ''}',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    surgeryStatus.toString().toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Surgery Details
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Surgeon Information
                if (surgeonName.toString().isNotEmpty) ...[
                  _buildInfoRow(Icons.person, 'Surgeon', surgeonName.toString()),
                ],
                if (assistantSurgeonName.toString().isNotEmpty) ...[
                  _buildInfoRow(Icons.person_outline, 'Assistant Surgeon', assistantSurgeonName.toString()),
                ],
                if (anesthesiaType.toString().isNotEmpty) ...[
                  _buildInfoRow(Icons.medication_liquid, 'Anesthesia Type', anesthesiaType.toString()),
                ],
                if (procedureOutcome.toString().isNotEmpty) ...[
                  _buildInfoRow(Icons.check_circle, 'Outcome', procedureOutcome.toString()),
                ],
                
                // Procedure Note
                if (procedureNote.toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber[200]!, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.note, color: Colors.amber[800], size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Procedure Note',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          procedureNote.toString(),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],

                // Complications
                if (complication.toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red[800], size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Complications',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          complication.toString(),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, IconData icon, Color color, List<String> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _getColorShade(color, 700),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: color.withOpacity(0.3)),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('â€¢ ', style: TextStyle(color: _getColorShade(color, 700), fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _labOrderListLabels(List<dynamic> labOrders) {
    final seen = <String>{};
    final labels = <String>[];
    for (final lab in labOrders) {
      final type = (lab['type'] ?? '').toString();
      final isPackage = type == 'package' ||
          type == 'package_test' ||
          lab['packageId'] != null;
      if (isPackage) {
        final pkgName = (lab['packageName'] ?? 'N/A').toString().trim();
        final key = 'pkg_${lab['packageId'] ?? pkgName}_${lab['orderId'] ?? ''}';
        if (seen.add(key)) {
          labels.add('$pkgName (Package)');
        }
      } else {
        final name = (lab['testName'] ?? 'N/A').toString();
        final key = 'test_${lab['testId'] ?? name}_${lab['orderId'] ?? ''}';
        if (seen.add(key)) {
          labels.add('$name (Test)');
        }
      }
    }
    return labels;
  }

  bool _labHasResult(dynamic lab) {
    final resultId = lab['resultId'];
    final resultValue = lab['resultValue'];
    return resultId != null || (resultValue != null && resultValue.toString().isNotEmpty);
  }

  List<MapEntry<String, List<dynamic>>> _groupLabResultsByPackage(List<dynamic> results) {
    final groups = <String, List<dynamic>>{};
    final order = <String>[];
    for (final lab in results) {
      final type = (lab['type'] ?? '').toString();
      final isPackage = type == 'package' ||
          type == 'package_test' ||
          lab['packageId'] != null;
      final key = isPackage
          ? 'pkg_${lab['packageId'] ?? lab['packageName']}_${lab['orderId'] ?? ''}'
          : 'standalone';
      if (!groups.containsKey(key)) {
        groups[key] = [];
        order.add(key);
      }
      groups[key]!.add(lab);
    }
    return [
      for (final key in order)
        MapEntry(
          key == 'standalone'
              ? (groups[key]!.length > 1 ? 'Tests' : '')
              : (groups[key]!.first['packageName'] ?? 'Package').toString(),
          groups[key]!,
        ),
    ];
  }

  Widget _buildLabResultsSection(List<dynamic> labOrders) {
    final resultsWithData = labOrders.where(_labHasResult).toList();
    final pendingLabels = _labOrderListLabels(
      labOrders.where((lab) => !_labHasResult(lab)).toList(),
    );

    if (resultsWithData.isEmpty) {
      if (pendingLabels.isEmpty) {
        return const SizedBox.shrink();
      }
      return _buildCompactDetailSection(
        'Lab Tests',
        Icons.science,
        Colors.blue,
        pendingLabels,
      );
    }

    final color = Colors.blue;
    final color50 = _getColorShade(color, 50);
    final color200 = _getColorShade(color, 200);
    
    // Determine status from abnormal flags and result status (matching PDF format)
    String _determineStatus(String abnormalFlags, String resultStatus, bool isCritical) {
      final flag = abnormalFlags.toUpperCase().trim();
      if (isCritical || flag == 'HH' || flag == 'LL') return 'CRITICAL';
      if (flag == 'H' || resultStatus.toUpperCase() == 'HIGH') return 'HIGH';
      if (flag == 'L' || resultStatus.toUpperCase() == 'LOW') return 'LOW';
      if (flag == 'A' || flag == 'AA') return 'ABNORMAL';
      return 'NORMAL';
    }
    
    bool _shouldHighlightResult(String status, bool isCritical) {
      return isCritical || status == 'HIGH' || status == 'LOW' || status == 'CRITICAL' || status == 'ABNORMAL';
    }
    
    final resultsSection = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            color50.withOpacity(0.3),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 10,
            offset: Offset(0, 4),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color200.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.science, color: _getColorShade(color, 700), size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Lab Results',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _getColorShade(color, 700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Table header
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('Test Name', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[800]))),
                  Expanded(flex: 2, child: Text('Result', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[800]))),
                  Expanded(flex: 1, child: Text('Unit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[800]))),
                  Expanded(flex: 2, child: Text('Ref Range', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[800]))),
                  Expanded(flex: 1, child: Text('Status', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[800]))),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Table rows grouped by package
            for (final group in _groupLabResultsByPackage(resultsWithData)) ...[
              if (group.key.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 2),
                  child: Text(
                    group.key,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getColorShade(color, 700),
                    ),
                  ),
                ),
              ...group.value.map((lab) {
              final testName = (lab['testName'] ?? lab['packageName'] ?? 'N/A').toString();
              final resultValue = (lab['resultValue'] ?? '').toString();
              final units = (lab['units'] ?? '').toString();
              final referenceRange = (lab['referenceRange'] ?? '').toString();
              final abnormalFlags = (lab['abnormalFlags'] ?? '').toString();
              final isCritical = lab['isCritical'] == true;
              final resultStatus = (lab['resultStatus'] ?? '').toString();
              final resultInterpretation = (lab['resultInterpretation'] ?? '').toString();
              
              final status = _determineStatus(abnormalFlags, resultStatus, isCritical);
              final shouldHighlight = _shouldHighlightResult(status, isCritical);
              
              // Background color matching PDF format
              Color? rowBgColor;
              if (isCritical) {
                rowBgColor = Colors.red[50];
              } else if (status == 'HIGH' || status == 'LOW') {
                rowBgColor = Colors.orange[50];
              }
              
              // Status badge colors matching PDF format
              Color statusBgColor;
              Color statusTextColor;
              if (status == 'NORMAL') {
                statusBgColor = Colors.green[100]!;
                statusTextColor = Colors.green[800]!;
              } else if (status == 'HIGH' || status == 'LOW') {
                statusBgColor = Colors.orange[100]!;
                statusTextColor = Colors.orange[800]!;
              } else if (status == 'CRITICAL') {
                statusBgColor = Colors.red[100]!;
                statusTextColor = Colors.red[800]!;
              } else {
                statusBgColor = Colors.grey[200]!;
                statusTextColor = Colors.grey[800]!;
              }
              
              return Container(
                decoration: BoxDecoration(
                  color: rowBgColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        testName,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          if (isCritical) ...[
                            Text('ðŸ”´ ', style: TextStyle(fontSize: 8)),
                          ],
                          Expanded(
                            child: Text(
                              resultValue,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: shouldHighlight ? FontWeight.bold : FontWeight.normal,
                                color: shouldHighlight ? Colors.red[700] : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        units,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        referenceRange,
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: shouldHighlight ? FontWeight.bold : FontWeight.w600,
                            color: statusTextColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              }),
            ],
            // Interpretation section (if any)
            if (resultsWithData.any((lab) => (lab['resultInterpretation'] ?? '').toString().isNotEmpty)) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                  border: Border(left: BorderSide(color: Colors.blue[700]!, width: 2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: resultsWithData
                      .where((lab) => (lab['resultInterpretation'] ?? '').toString().isNotEmpty)
                      .map((lab) {
                    final testName = (lab['testName'] ?? 'N/A').toString();
                    final interpretation = (lab['resultInterpretation'] ?? '').toString();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 10, color: Colors.black87),
                          children: [
                            TextSpan(
                              text: '$testName: ',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: interpretation),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (pendingLabels.isEmpty) return resultsSection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCompactDetailSection(
          'Lab Tests',
          Icons.science,
          Colors.blue,
          pendingLabels,
        ),
        const SizedBox(height: 8),
        resultsSection,
      ],
    );
  }

  Widget _buildRadiologyReportsSection(List<dynamic> radiologyOrders) {
    // Filter out orders without reports
    final reportsWithData = radiologyOrders.where((rad) {
      final reportId = rad['reportId'];
      final reportStatus = rad['reportStatus'];
      return reportId != null || reportStatus != null;
    }).toList();

    if (reportsWithData.isEmpty) {
      // If no reports, show just test names like before
      final testNames = radiologyOrders.map<String>((rad) => 
        (rad['testName'] ?? 
        rad['clinicalDisplayName'] ?? 
        'N/A').toString()
      ).toList();
      
      if (testNames.isEmpty) {
        return const SizedBox.shrink();
      }
      
      return _buildCompactDetailSection(
        'Radiology Tests',
        Icons.scanner,
        Colors.orange,
        testNames,
      );
    }

    final color = Colors.orange;
    final color50 = _getColorShade(color, 50);
    final color200 = _getColorShade(color, 200);
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            color50.withOpacity(0.3),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 10,
            offset: Offset(0, 4),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color200.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.scanner, color: _getColorShade(color, 700), size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Radiology Reports',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _getColorShade(color, 700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...reportsWithData.map((rad) {
              final testName = (rad['testName'] ?? rad['clinicalDisplayName'] ?? 'N/A').toString();
              final reportStatus = (rad['reportStatus'] ?? '').toString();
              final finalFindings = (rad['finalFindings'] ?? '').toString();
              final preliminaryFindings = (rad['preliminaryFindings'] ?? '').toString();
              final impression = (rad['impression'] ?? '').toString();
              final recommendations = (rad['recommendations'] ?? '').toString();
              final addendumNotes = (rad['addendumNotes'] ?? '').toString();
              
              final findings = finalFindings.isNotEmpty ? finalFindings : preliminaryFindings;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('â€¢ ', style: TextStyle(color: _getColorShade(color, 700), fontWeight: FontWeight.bold, fontSize: 12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                testName,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              if (reportStatus.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Status: $reportStatus',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                                ),
                              ],
                              if (findings.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Findings: $findings',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                              if (impression.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Impression: $impression',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                              if (recommendations.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Recommendations: $recommendations',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                              if (addendumNotes.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Addendum: $addendumNotes',
                                  style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactDetailSection(String title, IconData icon, Color color, List<String> items) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Get color shades using helper function
    final color50 = _getColorShade(color, 50);
    final color200 = _getColorShade(color, 200);
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            color50.withOpacity(0.3),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 10,
            offset: Offset(0, 4),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: color200.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: _getColorShade(color, 700), size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _getColorShade(color, 700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ...items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('â€¢ ', style: TextStyle(color: _getColorShade(color, 700), fontWeight: FontWeight.bold, fontSize: 12)),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }


  Color _getStatusColor(String status) {
    final statusLower = status.toString().toLowerCase();
    if (statusLower.contains('checked out') || statusLower == 'checked_out') {
      return Colors.grey;
    } else if (statusLower.contains('checked in') || statusLower == 'checked_in' || statusLower.contains('in progress')) {
      return Colors.green;
    } else {
      return Colors.blue;
    }
  }

  Color _getColorShade(Color color, int shade) {
    // Helper to get color shade - for Material colors
    if (color == Colors.orange) return Colors.orange[shade] ?? color;
    if (color == Colors.red) return Colors.red[shade] ?? color;
    if (color == Colors.green) return Colors.green[shade] ?? color;
    if (color == Colors.blue) return Colors.blue[shade] ?? color;
    if (color == Colors.purple) return Colors.purple[shade] ?? color;
    if (color == Colors.indigo) return Colors.indigo[shade] ?? color;
    return color;
  }

  // Safely turn any value into a string (empty when null)
  String _stringOrEmpty(dynamic value) {
    if (value == null) return '';
    try {
      return value.toString();
    } catch (_) {
      return '';
    }
  }

  double? _calculateBMI(String? weightStr, String? heightStr) {
    if (weightStr == null || heightStr == null) return null;
    final weight = double.tryParse(weightStr.toString());
    final height = double.tryParse(heightStr.toString());
    if (weight == null || height == null || weight <= 0 || height <= 0) return null;
    // Assume height is in cm, convert to meters
    final heightInMeters = height / 100.0;
    return weight / (heightInMeters * heightInMeters);
  }

  // Normal range checks matching nurse_vital.dart
  bool _isSystolicNormal(double systolic) {
    return systolic >= 90 && systolic <= 140;
  }

  bool _isDiastolicNormal(double diastolic) {
    return diastolic >= 60 && diastolic <= 90;
  }

  bool _isTemperatureNormal(double tempC) {
    // Convert Celsius to Fahrenheit for comparison (nurse_vital uses 97.0-99.5Â°F)
    final tempF = (tempC * 9 / 5) + 32;
    return tempF >= 97.0 && tempF <= 99.5;
  }

  bool _isPulseNormal(double pulse) {
    return pulse >= 60 && pulse <= 100;
  }

  bool _isRespiratoryRateNormal(double rr) {
    return rr >= 12 && rr <= 20;
  }

  bool _isO2SaturationNormal(double o2) {
    return o2 >= 95 && o2 <= 100;
  }

  bool _isBSRNormal(double bsr) {
    return bsr >= 70 && bsr <= 100;
  }

  bool _isBMINormal(double bmi) {
    return bmi >= 18.5 && bmi <= 24.9;
  }

  bool _isVitalOutOfRange(String vitalType, String? valueStr) {
    if (valueStr == null || valueStr.toString().trim().isEmpty) return false;
    final value = double.tryParse(valueStr.toString());
    if (value == null) return false;

    switch (vitalType) {
      case 'bpSystolic':
        return !_isSystolicNormal(value);
      case 'bpDiastolic':
        return !_isDiastolicNormal(value);
      case 'hr':
        return !_isPulseNormal(value);
      case 'temp':
        return !_isTemperatureNormal(value);
      case 'spo2':
        return !_isO2SaturationNormal(value);
      case 'bmi':
        return !_isBMINormal(value);
      case 'bsr':
        return !_isBSRNormal(value);
      default:
        return false;
    }
  }

  Widget _buildCompactVitalsBlock(
    Map<dynamic, dynamic> v, {
    DateTime? recordedDate,
    String? recordedBy,
  }) {
    final fields = _parseVitalFields(v);
    final chips = _buildVitalsContent(
      fields.bp,
      fields.hr,
      fields.temp,
      fields.spo2,
      fields.rr,
      fields.weight,
      fields.height,
      fields.bsr,
    );
    final hasMeta = recordedDate != null ||
        (recordedBy != null && recordedBy.trim().isNotEmpty);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasMeta)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.favorite, color: Colors.grey[700], size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Vitals',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                    ),
                  ),
                  if (recordedDate != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      AppDateFormat.formatDateTime(recordedDate),
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ],
                  if (recordedBy != null && recordedBy.trim().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        recordedBy.trim(),
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.favorite, color: Colors.grey[700], size: 14),
                const SizedBox(width: 6),
                Text(
                  'Vitals',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: chips),
              ],
            ),
          if (hasMeta) chips,
        ],
      ),
    );
  }

  ({
    String bp,
    String hr,
    String temp,
    String spo2,
    String rr,
    String weight,
    String height,
    String bsr,
  }) _parseVitalFields(Map<dynamic, dynamic> v) {
    final bpSystolic = _stringOrEmpty(
      v['bpSystolic'] ?? v['BPSystolic'] ?? v['bloodPressureSystolic'],
    );
    final bpDiastolic = _stringOrEmpty(
      v['bpDiastolic'] ?? v['BPDiastolic'] ?? v['bloodPressureDiastolic'],
    );
    final bp = bpSystolic.isNotEmpty && bpDiastolic.isNotEmpty
        ? '$bpSystolic/$bpDiastolic'
        : _stringOrEmpty(v['bloodPressure'] ?? v['BloodPressure']);

    return (
      bp: bp,
      hr: _stringOrEmpty(
        v['pulse'] ?? v['Pulse'] ?? v['heartRate'] ?? v['HeartRate'],
      ),
      temp: _stringOrEmpty(v['temperature'] ?? v['Temperature']),
      spo2: _stringOrEmpty(
        v['spo2'] ??
            v['SPO2'] ??
            v['oxygenSaturation'] ??
            v['OxygenSaturation'],
      ),
      rr: _stringOrEmpty(
        v['respiratoryRate'] ??
            v['RespiratoryRate'] ??
            v['respiratory_rate'],
      ),
      weight: _stringOrEmpty(v['weight'] ?? v['Weight']),
      height: _stringOrEmpty(v['height'] ?? v['Height']),
      bsr: _stringOrEmpty(
        v['bsr'] ?? v['BSR'] ?? v['bloodSugar'] ?? v['BloodSugar'],
      ),
    );
  }

  Widget _buildVitalChip(String label, String value, bool isOutOfRange) {
    final display = value.trim().isEmpty ? '-' : value;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOutOfRange ? Colors.red[100] : Colors.grey[200],
        borderRadius: BorderRadius.circular(6),
        border: isOutOfRange
            ? Border.all(color: Colors.red[400]!, width: 1)
            : null,
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87),
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            ),
            TextSpan(
              text: display,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isOutOfRange ? FontWeight.bold : FontWeight.w600,
                color: isOutOfRange ? Colors.red[800] : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalsContent(
    String bp,
    String hr,
    String temp,
    String spo2,
    String rr,
    String weight,
    String height,
    String bsr,
  ) {
    // Parse BP for out-of-range check
    double? bpSystolic, bpDiastolic;
    if (bp.contains('/')) {
      final parts = bp.split('/');
      if (parts.length == 2) {
        bpSystolic = double.tryParse(parts[0].trim());
        bpDiastolic = double.tryParse(parts[1].trim());
      }
    }

    // Calculate BMI
    final bmi = _calculateBMI(weight, height);
    final bmiStr = bmi != null ? bmi.toStringAsFixed(1) : '';

    // Check which vitals are out of range
    final bpSystolicOutOfRange = bpSystolic != null && !_isSystolicNormal(bpSystolic);
    final bpDiastolicOutOfRange = bpDiastolic != null && !_isDiastolicNormal(bpDiastolic);
    final bpOutOfRange = bpSystolicOutOfRange || bpDiastolicOutOfRange;
    
    final hrValue = double.tryParse(hr);
    final hrOutOfRange = hrValue != null && !_isPulseNormal(hrValue);
    
    final tempValue = double.tryParse(temp);
    final tempOutOfRange = tempValue != null && !_isTemperatureNormal(tempValue);
    
    final spo2Value = double.tryParse(spo2);
    final spo2OutOfRange = spo2Value != null && !_isO2SaturationNormal(spo2Value);
    
    final rrValue = double.tryParse(rr);
    final rrOutOfRange = rrValue != null && !_isRespiratoryRateNormal(rrValue);
    
    final bmiOutOfRange = bmi != null && !_isBMINormal(bmi);
    
    final bsrValue = double.tryParse(bsr);
    final bsrOutOfRange = bsrValue != null && !_isBSRNormal(bsrValue);

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (bp.isNotEmpty) _buildVitalChip('BP', bp, bpOutOfRange),
        if (hr.isNotEmpty) _buildVitalChip('HR', hr, hrOutOfRange),
        if (temp.isNotEmpty) _buildVitalChip('Temp', temp, tempOutOfRange),
        if (spo2.isNotEmpty) _buildVitalChip('SpO₂', spo2, spo2OutOfRange),
        if (rr.isNotEmpty) _buildVitalChip('RR', rr, rrOutOfRange),
        if (weight.isNotEmpty) _buildVitalChip('Wt', weight, false),
        if (height.isNotEmpty) _buildVitalChip('Ht', height, false),
        if (bmiStr.isNotEmpty) _buildVitalChip('BMI', bmiStr, bmiOutOfRange),
        if (bsr.isNotEmpty) _buildVitalChip('BSR', bsr, bsrOutOfRange),
      ],
    );
  }

  Future<void> _generateAndPrintAllEncounters() async {
    if (_encounterDataList.isEmpty) {
      AppSnackBar.showInfo(context, 'No encounters to print');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await PatientFilePrintHelper.printAllEncounters(
        encounterDataList: _encounterDataList,
        patient: widget.patient,
      );

      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.showSuccess(context, 'PDF generated successfully');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.showError(context, 'Error generating PDF: $e');
      }
    }
  }
}

