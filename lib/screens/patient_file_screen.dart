import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../utils/emr_api_client.dart';
import 'patient_file_print_helper.dart';

class PatientFileScreen extends StatefulWidget {
  final Map<String, dynamic> patient;
  final int? admissionId;

  const PatientFileScreen({
    Key? key,
    required this.patient,
    this.admissionId,
  }) : super(key: key);

  @override
  State<PatientFileScreen> createState() => _PatientFileScreenState();
}

class _PatientFileScreenState extends State<PatientFileScreen> {
  EmrApiClient? _api;
  
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
  bool _loadingFile = false; // true while Show fetch is in progress (disables button, shows progress)

  @override
  void initState() {
    super.initState();
    _initializeApi();
    _loadHeaderSummary();
  }

  Future<void> _initializeApi() async {
    try {
      _api = EmrApiClient();
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadAllVitals(int patientId, {DateTime? fromDate, DateTime? toDate}) async {
    if (_api == null) return;
    try {
      final allVitals = await _api!.getPatientVitals(
        patientId,
        fromDate: fromDate,
        toDate: toDate,
      );
      setState(() {
        _allVitals = allVitals;
        if (_encounterDataList.isNotEmpty || _surgeries.isNotEmpty) {
          _buildCombinedTimeline();
        }
      });
    } catch (e) {
      print('Error loading all vitals: $e');
      // Non-blocking: don't fail if vitals can't be loaded
    }
  }

  Future<void> _loadAllEncounterDetails() async {
    setState(() {
      _loadingDetails = true;
    });

    try {
      final patientId = widget.patient['patientId'] ?? widget.patient['PatientID'];
      if (patientId == null) return;

      List<Map<String, dynamic>> encounterDataList = [];
      
      // Create a map of vitals by encounterId for quick lookup
      final Map<int, List<dynamic>> vitalsByEncounterId = {};
      for (final vital in _allVitals) {
        final encounterId = vital['encounterId'] ?? 
                           vital['EncounterID'] ?? 
                           vital['encounterID'];
        if (encounterId != null) {
          final parsedEncounterId = encounterId is int ? encounterId : int.tryParse(encounterId.toString());
          if (parsedEncounterId != null) {
            vitalsByEncounterId.putIfAbsent(parsedEncounterId, () => []).add(vital);
          }
        }
      }
      
      for (final encounter in _encounters) {
        final encounterId = encounter['encounterId'] ?? 
                           encounter['EncounterID'] ?? 
                           encounter['encounterID'];
        if (encounterId == null) continue;

        final parsedEncounterId = encounterId is int ? encounterId : int.tryParse(encounterId.toString());
        if (parsedEncounterId == null) continue;

        try {
          // Get consultation data
          final consultationData = await _api!.getEncounterConsultationData(
            parsedEncounterId,
            patientId: patientId is int ? patientId : int.parse(patientId.toString()),
          );

          // Get vitals for this encounter from the pre-loaded list
          final vitals = vitalsByEncounterId[parsedEncounterId] ?? [];

          encounterDataList.add({
            'encounter': encounter,
            'vitals': vitals,
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
          print('Error loading encounter data: $e');
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

      setState(() {
        _encounterDataList = encounterDataList;
        _loadingDetails = false;
        _buildCombinedTimeline();
      });
    } catch (e) {
      setState(() {
        _loadingDetails = false;
      });
      print('Error loading encounter details: $e');
    }
  }

  Future<void> _loadSurgeries() async {
    try {
      final patientId = widget.patient['patientId'] ?? widget.patient['PatientID'];
      if (patientId == null) return;

      final surgeries = await _api!.getPatientSurgeries(
        patientId is int ? patientId : int.parse(patientId.toString()),
      );

      setState(() {
        _surgeries = surgeries;
        _buildCombinedTimeline();
      });
    } catch (e) {
      print('Error loading surgeries: $e');
      // Non-blocking: don't fail if surgeries can't be loaded
    }
  }

  void _buildCombinedTimeline() {
    List<Map<String, dynamic>> timeline = [];

    // Add vitals with type marker (only vitals not associated with encounters)
    for (final vital in _allVitals) {
      final encounterId = vital['encounterId'] ?? 
                         vital['EncounterID'] ?? 
                         vital['encounterID'];
      
      // Only add vitals that are not part of an encounter
      if (encounterId == null) {
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

        timeline.add({
          'type': 'vitals',
          'date': parsedDate,
          'data': vital,
        });
      }
    }

    // Add encounters with type marker
    for (final encounterData in _encounterDataList) {
      final encounter = encounterData['encounter'] as Map<String, dynamic>;
      final encounterDate = encounter['encounterDate'] ?? 
                           encounter['EncounterDate'] ?? 
                           encounter['checkInTime'] ?? 
                           encounter['CheckInTime'];
      
      DateTime? parsedDate;
      if (encounterDate != null) {
        parsedDate = encounterDate is DateTime 
            ? encounterDate 
            : DateTime.tryParse(encounterDate.toString());
      }

      timeline.add({
        'type': 'encounter',
        'date': parsedDate,
        'data': encounterData,
      });
    }

    // Add surgeries with type marker
    for (final surgery in _surgeries) {
      final surgeryDate = surgery['surgeryDate'] ?? surgery['SurgeryDate'];
      
      DateTime? parsedDate;
      if (surgeryDate != null) {
        parsedDate = surgeryDate is DateTime 
            ? surgeryDate 
            : DateTime.tryParse(surgeryDate.toString());
      }

      timeline.add({
        'type': 'surgery',
        'date': parsedDate,
        'data': surgery,
      });
    }

    // Sort by date (newest first - reverse chronological)
    timeline.sort((a, b) {
      final dateA = a['date'] as DateTime?;
      final dateB = b['date'] as DateTime?;
      
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    setState(() {
      _combinedTimeline = timeline;
    });
  }

  Future<void> _loadHeaderSummary() async {
    try {
      print('[IPD File] _loadHeaderSummary called');
      final patientId = widget.patient['patientId'] ?? widget.patient['PatientID'];
      print('[IPD File] Patient ID for header: $patientId, type: ${patientId.runtimeType}');
      if (patientId == null) {
        print('[IPD File] Patient ID is null, returning');
        return;
      }

      final parsedPatientId = patientId is int ? patientId : int.tryParse(patientId.toString());
      if (parsedPatientId == null) {
        print('[IPD File] Could not parse patient ID: $patientId');
        return;
      }

      print('[IPD File] Parsed patient ID: $parsedPatientId');
      if (_api == null) return;
      final results = await Future.wait([
        _api!.getPatientChronicConditions(parsedPatientId),
        _api!.getPatientAllergies(parsedPatientId),
        _api!.getPatientRiskFactors(parsedPatientId),
        _api!.getActivePatientMedicines(patientId: parsedPatientId),
      ]);
      print('[IPD File] Header summary results loaded: ${results.length} items');

      setState(() {
        try {
          print('[IPD File] Setting header data in setState');
          _headerChronic = results[0] as List<dynamic>;
          print('[IPD File] Chronic conditions: ${_headerChronic.length}');
          _headerAllergies = results[1] as List<dynamic>;
          print('[IPD File] Allergies: ${_headerAllergies.length}');
          _headerRiskFactors = results[2] as List<dynamic>;
          print('[IPD File] Risk factors: ${_headerRiskFactors.length}');
          
          // Extract unique salt names from active medicines for header display
          final activeMedicines = results[3] as List<Map<String, dynamic>>;
          print('[IPD File] Active medicines: ${activeMedicines.length}');
          final Set<String> uniqueSaltNames = {};
          for (final item in activeMedicines) {
            try {
              final saltName = item['SaltName'] ?? item['saltName'] ?? item['Salt'] ?? item['salt'];
              if (saltName != null && saltName.toString().trim().isNotEmpty) {
                uniqueSaltNames.add(saltName.toString().trim());
              }
            } catch (e) {
              print('[IPD File] Error processing medicine item: $e, item: $item');
            }
          }
          
          // Update header medications with salt names
          _headerMedications = uniqueSaltNames.map((saltName) => {
            'name': saltName,
            'saltName': saltName,
          }).toList();
          print('[IPD File] Header medications: ${_headerMedications.length}');
        } catch (e, stackTrace) {
          print('[IPD File] Error in setState for header summary: $e');
          print('[IPD File] Stack trace: $stackTrace');
        }
      });
    } catch (e, stackTrace) {
      print('[IPD File] Error in _loadHeaderSummary: $e');
      print('[IPD File] Stack trace: $stackTrace');
      // Non-blocking: keep UI usable even if header fails
    }
  }

  Future<void> _loadEncounters({DateTime? fromDate, DateTime? toDate}) async {
    if (_api == null) {
      await _initializeApi();
      if (_api == null) {
        setState(() {
          _loading = false;
          _error = 'Failed to initialize API';
        });
        return;
      }
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final patientId = widget.patient['patientId'] ?? widget.patient['PatientID'];
      if (patientId == null) {
        throw Exception('Patient ID is required');
      }

      int? admissionId = widget.admissionId;
      
      // Try to get admissionId from patient data if not provided
      if (admissionId == null) {
        admissionId = widget.patient['admissionId'] ?? 
                     widget.patient['AdmissionId'] ?? 
                     widget.patient['admission_id'];
        if (admissionId != null && admissionId is! int) {
          admissionId = int.tryParse(admissionId.toString());
        }
      }

      // If still no admissionId, try to get from current encounter
      if (admissionId == null) {
        final encounterId = widget.patient['encounterId'] ?? 
                           widget.patient['EncounterID'] ?? 
                           widget.patient['encounterID'];
        if (encounterId != null) {
          final parsedEncounterId = encounterId is int ? encounterId : int.tryParse(encounterId.toString());
          if (parsedEncounterId != null) {
            try {
              final encounterDetails = await _api!.getEncounterDetails(parsedEncounterId);
              admissionId = encounterDetails['admissionId'] ?? 
                           encounterDetails['AdmissionId'] ?? 
                           encounterDetails['admission_id'];
              if (admissionId != null && admissionId is! int) {
                admissionId = int.tryParse(admissionId.toString());
              }
            } catch (e) {
              print('Error getting encounter details: $e');
            }
          }
        }
      }

      List<Map<String, dynamic>> encounters = [];

      // If we have admissionId, try to get encounters by admission ID
    if (admissionId != null) {
      try {
        encounters = await _api!.getEncountersByAdmissionId(admissionId);
        } catch (e) {
          print('Error getting encounters by admission ID: $e');
          // Fall through to get all IPD encounters
        }
      }

      // If no encounters found by admission ID, get all encounters for the patient
      if (encounters.isEmpty) {
        try {
          // Get all encounters (both OPD and IPD) without doctorId/hospitalId filters
          final allEncounters = await _api!.getAllPatientEncounters(
            patientId is int ? patientId : int.parse(patientId.toString()),
            fromDate: fromDate,
            toDate: toDate,
          );
          
          // Show all encounters (OPD and IPD), not just IPD
          encounters = allEncounters.toList();
          
          // If we have an admissionId, filter by it
          if (admissionId != null) {
            encounters = encounters.where((enc) {
              final encAdmissionId = enc['admissionId'] ?? 
                                   enc['AdmissionId'] ?? 
                                   enc['admission_id'];
              if (encAdmissionId == null) return false;
              final parsed = encAdmissionId is int ? encAdmissionId : int.tryParse(encAdmissionId.toString());
              return parsed == admissionId;
            }).toList();
          }
        } catch (e) {
          print('Error getting all patient encounters: $e');
          throw Exception('Failed to load encounters: $e');
        }
      }
      
      setState(() {
        _encounters = encounters;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadDataWithFilters() async {
    setState(() {
      _loading = true;
      _dataLoaded = false;
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
      // Set end date to end of day
      final endDate = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      // Set start date to start of day
      final startDate = DateTime(_startDate.year, _startDate.month, _startDate.day, 0, 0, 0);

      await Future.wait([
        _loadAllVitals(parsedPatientId, fromDate: startDate, toDate: endDate),
        _loadEncounters(fromDate: startDate, toDate: endDate),
        _loadSurgeries(),
      ]);

      if (_encounters.isNotEmpty) {
        await _loadAllEncounterDetails();
      }

      setState(() {
        _dataLoaded = true;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildDateFilterSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colorScheme.outline.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 1,
          ),
        ],
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.date_range, color: colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            'From:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
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
                border: Border.all(color: colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('dd/MM/yyyy').format(_startDate),
                    style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.calendar_today, size: 16, color: colorScheme.onSurfaceVariant),
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
              color: colorScheme.onSurfaceVariant,
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
                border: Border.all(color: colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('dd/MM/yyyy').format(_endDate),
                    style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.calendar_today, size: 16, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: (_loading || _loadingDetails) ? null : _loadDataWithFilters,
            icon: (_loading || _loadingDetails)
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                    ),
                  )
                : const Icon(Icons.search, size: 18),
            label: const Text('Show'),
            style: FilledButton.styleFrom(
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
      print('[IPD File] Building patient info card');
      print('[IPD File] Patient data keys: ${widget.patient.keys.toList()}');
      
      // Safely extract and convert name
      final nameValue = widget.patient['fullName'] ?? widget.patient['name'];
      print('[IPD File] Name value type: ${nameValue.runtimeType}, value: $nameValue');
      final String name = nameValue?.toString() ?? 'Unknown';
      
      // Safely extract and convert MRN
      final mrnValue = widget.patient['mrn'];
      print('[IPD File] MRN value type: ${mrnValue.runtimeType}, value: $mrnValue');
      final String mrn = mrnValue?.toString() ?? 'N/A';
      
      // Safely extract and convert gender
      final genderValue = widget.patient['gender'];
      print('[IPD File] Gender value type: ${genderValue.runtimeType}, value: $genderValue');
      final String gender = genderValue?.toString() ?? '';
      
      // Safely extract and convert age
      final ageValue = widget.patient['age'];
      print('[IPD File] Age value type: ${ageValue.runtimeType}, value: $ageValue');
      final String age = (ageValue != null) ? '${ageValue.toString()}y' : '';
      
      // Safely extract and convert blood group
      final bloodValue = widget.patient['bloodGroup'];
      print('[IPD File] Blood value type: ${bloodValue.runtimeType}, value: $bloodValue');
      final String blood = bloodValue?.toString() ?? '';
      
      print('[IPD File] Extracted values - name: $name, mrn: $mrn, gender: $gender, age: $age, blood: $blood');

    String joinWithComma(Iterable<String> items, {int max = 6}) {
      try {
        print('[IPD File] joinWithComma called with ${items.length} items');
        final list = items.where((e) {
          try {
            return e.trim().isNotEmpty;
          } catch (ex) {
            print('[IPD File] Error in joinWithComma filter: $ex, item type: ${e.runtimeType}, item: $e');
            return false;
          }
        }).toList();
        if (list.length > max) {
          return list.sublist(0, max).join(', ') + ' +' + (list.length - max).toString();
        }
        return list.join(', ');
      } catch (e) {
        print('[IPD File] Error in joinWithComma: $e');
        return '';
      }
    }

    final allergiesText = joinWithComma(
      _headerAllergies.map((a) {
        try {
          print('[IPD File] Processing allergy: $a, type: ${a.runtimeType}');
          final m = a as Map<String, dynamic>;
          final nameValue = m['allergyName'] ?? m['AllergyName'];
          final name = nameValue?.toString() ?? '';
          final severityValue = m['severity'] ?? m['Severity'];
          final severity = severityValue?.toString() ?? '';
          final result = severity.isNotEmpty ? '$name (${severity.length >= 3 ? severity.substring(0, 3) : severity})' : name;
          print('[IPD File] Allergy result: $result');
          return result;
        } catch (e) {
          print('[IPD File] Error processing allergy: $e');
          return '';
        }
      }).where((s) => s.isNotEmpty),
    );

    final chronicText = joinWithComma(
      _headerChronic.map((c) {
        try {
          print('[IPD File] Processing chronic condition: $c, type: ${c.runtimeType}');
          final m = c as Map<String, dynamic>;
          final nameValue = m['conditionName'] ?? m['ConditionName'];
          final name = nameValue?.toString() ?? '';
          final codeValue = m['icd11Code'] ?? m['ICD11Code'];
          final code = codeValue?.toString() ?? '';
          final result = code.isNotEmpty ? '$name ($code)' : name;
          print('[IPD File] Chronic result: $result');
          return result;
        } catch (e) {
          print('[IPD File] Error processing chronic condition: $e');
          return '';
        }
      }).where((s) => s.isNotEmpty),
    );

    final medsText = joinWithComma(
      _headerMedications.map((m) {
        try {
          print('[IPD File] Processing medication: $m, type: ${m.runtimeType}');
          final nameValue = m['name'] ?? m['medicineName'];
          final result = nameValue?.toString() ?? '';
          print('[IPD File] Medication result: $result');
          return result;
        } catch (e) {
          print('[IPD File] Error processing medication: $e');
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
              print('[IPD File] Error filtering risk factor: $e');
              return false;
            }
          })
          .map((r) {
            try {
              print('[IPD File] Processing risk factor: $r, type: ${r.runtimeType}');
              final nameValue = r['riskFactorName'] ?? r['risk_factor_name'];
              final result = nameValue?.toString() ?? '';
              print('[IPD File] Risk factor result: $result');
              return result;
            } catch (e) {
              print('[IPD File] Error processing risk factor: $e');
              return '';
            }
          }).where((s) => s.isNotEmpty),
      max: 6,
    );

    print('[IPD File] Starting LayoutBuilder for patient info card');
    return LayoutBuilder(
      builder: (context, constraints) {
        try {
          print('[IPD File] LayoutBuilder building');
          final screenWidth = MediaQuery.of(context).size.width;
          return Transform.translate(
          offset: Offset(-12.0, 0),
          child: SizedBox(
            width: screenWidth,
            child: Builder(
              builder: (context) {
                final cs = Theme.of(context).colorScheme;
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primary,
                        cs.secondary,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
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
                          cs.onPrimary.withValues(alpha: 0.1),
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
                        Builder(
                          builder: (context) {
                            final cs = Theme.of(context).colorScheme;
                            return Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: cs.onPrimary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: cs.onPrimary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'MRN: $mrn',
                                  style: TextStyle(
                                    color: cs.onPrimary.withValues(alpha: 0.95),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '$gender, $age',
                                  style: TextStyle(
                                    color: cs.onPrimary.withValues(alpha: 0.95),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Row(
                                  children: [
                                    _pill(icon: Icons.warning_amber_rounded, label: 'Allergies', value: allergiesText),
                                    const SizedBox(width: 14),
                                    _pill(icon: Icons.healing, label: 'Chronic', value: chronicText),
                                    const SizedBox(width: 14),
                                    _pill(icon: Icons.local_pharmacy, label: 'Current Meds', value: medsText),
                                    const SizedBox(width: 14),
                                    _pill(icon: Icons.report_problem, label: 'Risk Factors', value: risksText),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            },
          ),
        ),
        );
        } catch (e, stackTrace) {
          print('[IPD File] Error in LayoutBuilder: $e');
          print('[IPD File] Stack trace: $stackTrace');
          return Container(
            padding: const EdgeInsets.all(16),
            child: Text('Error displaying patient info: $e', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          );
        }
      },
    );
    } catch (e, stackTrace) {
      print('[IPD File] Error in _buildPatientInfoCard: $e');
      print('[IPD File] Stack trace: $stackTrace');
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text('Error: $e', style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
    }
  }

  Widget _pill({required IconData icon, required String label, required String value}) {
    final colorScheme = Theme.of(context).colorScheme;
    final text = value.isNotEmpty ? value : 'None';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.onPrimary.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.outline.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colorScheme.onPrimary, size: 13),
          const SizedBox(width: 4),
          Text(
            '$label:',
            style: TextStyle(
              color: colorScheme.onPrimary,
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
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Patient File', style: theme.appBarTheme.titleTextStyle),
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
            child: !_dataLoaded && !_loading && !_loadingDetails
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_alt, size: 48, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                        const SizedBox(height: 16),
                        Text(
                          'Select date range and click Show to load data',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : (_loading || _loadingDetails)
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              'Fetching patient data...',
                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, size: 48, color: colorScheme.errorContainer),
                                const SizedBox(height: 16),
                                Text(
                                  _error!,
                                  style: TextStyle(color: colorScheme.error),
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
                        : _encounterDataList.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.folder_open, size: 48, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No encounters found',
                                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _combinedTimeline.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final item = entry.value;
                                    final type = item['type'] as String;
                                    
                                    if (type == 'vitals') {
                                      final vital = item['data'] as Map<String, dynamic>;
                                      return _buildVitalsCard(vital);
                                    } else if (type == 'encounter') {
                                      final data = item['data'] as Map<String, dynamic>;
                                      // Count only encounters for numbering
                                      final encounterNumber = _combinedTimeline
                                          .where((i) => i['type'] == 'encounter')
                                          .toList()
                                          .indexOf(item) + 1;
                                      return _buildDetailedEncounterCard(data, encounterNumber);
                                    } else if (type == 'surgery') {
                                      final surgery = item['data'] as Map<String, dynamic>;
                                      return _buildSurgeryCard(surgery);
                                    }
                                    return const SizedBox.shrink();
                                  }).toList(),
                                ),
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
        // Group by packageId - accumulate all tests in the package
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
        // Add this test's result to the package
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
    
    // Expand packages: one row per test in each package
    final List<Map<String, dynamic>> labOrders = [];
    for (final pkg in packageMap.values) {
      final tests = pkg['tests'] as List<dynamic>;
      for (final t in tests) {
        labOrders.add({
          'type': 'package_test',
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
    final clinicalNotesRaw = data['clinicalNotes'];
    final clinicalNotes = (clinicalNotesRaw != null && clinicalNotesRaw.toString().trim().isNotEmpty) 
        ? clinicalNotesRaw.toString().trim() 
        : null;

    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Encounter #$encounterId - view only')),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24.0),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: cs.outline.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
              spreadRadius: 2,
            ),
          ],
          border: Border.all(color: cs.outline.withValues(alpha: 0.4), width: 1),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encounter Header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withValues(alpha: 0.9)],
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimary,
                        ),
                      ),
                      if (parsedDate != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today, size: 14, color: cs.onPrimary.withValues(alpha: 0.9)),
                        const SizedBox(width: 4),
                        Text(
                          '${parsedDate.day}/${parsedDate.month}/${parsedDate.year} ${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.9), fontSize: 12),
                        ),
                      ],
                      const SizedBox(width: 16),
                      Icon(Icons.person, size: 14, color: cs.onPrimary.withValues(alpha: 0.9)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          doctorName,
                          style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.9), fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(context, status).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getStatusColor(context, status), width: 1),
                  ),
                  child: Text(
                    status.toString().toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(context, status),
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
                  ...vitals.map((v) {
                    final bpSystolic = _stringOrEmpty(v['bpSystolic'] ?? v['BPSystolic'] ?? v['bloodPressureSystolic']);
                    final bpDiastolic = _stringOrEmpty(v['bpDiastolic'] ?? v['BPDiastolic'] ?? v['bloodPressureDiastolic']);
                    final bp = bpSystolic.toString().isNotEmpty && bpDiastolic.toString().isNotEmpty
                        ? '$bpSystolic/$bpDiastolic'
                        : _stringOrEmpty(v['bloodPressure'] ?? v['BloodPressure']);
                    final hr = _stringOrEmpty(v['pulse'] ?? v['Pulse'] ?? v['heartRate'] ?? v['HeartRate']);
                    final temp = _stringOrEmpty(v['temperature'] ?? v['Temperature']);
                    final spo2 = _stringOrEmpty(v['spo2'] ?? v['SPO2'] ?? v['oxygenSaturation'] ?? v['OxygenSaturation']);
                    final rr = _stringOrEmpty(v['respiratoryRate'] ?? v['RespiratoryRate'] ?? v['respiratory_rate']);
                    final weight = _stringOrEmpty(v['weight'] ?? v['Weight']);
                    final height = _stringOrEmpty(v['height'] ?? v['Height']);
                    final bsr = _stringOrEmpty(v['bsr'] ?? v['BSR'] ?? v['bloodSugar'] ?? v['BloodSugar']);
                    return _buildVitalsContent(bp, hr, temp, spo2, rr, weight, height, bsr);
                  }).toList(),
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
                        cs.tertiary,
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
                        cs.error,
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
                        cs.secondary,
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

                // Clinical Notes - Only show if not null or empty
                if (clinicalNotes != null && clinicalNotes.trim().isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cs.primaryContainer.withValues(alpha: 0.3),
                          cs.primaryContainer.withValues(alpha: 0.15),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.note_alt, color: cs.primary, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Clinical Notes',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: cs.primary,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            clinicalNotes,
                            style: const TextStyle(fontSize: 13, height: 1.4),
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
                        cs.primary,
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
                                medText += ' - End Date: ${end.day}/${end.month}/${end.year}';
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
    final cs = Theme.of(context).colorScheme;
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

    // Format vitals data
    final bpSystolic = _stringOrEmpty(vital['bpSystolic'] ?? vital['BPSystolic'] ?? vital['bloodPressureSystolic']);
    final bpDiastolic = _stringOrEmpty(vital['bpDiastolic'] ?? vital['BPDiastolic'] ?? vital['bloodPressureDiastolic']);
    final bp = bpSystolic.toString().isNotEmpty && bpDiastolic.toString().isNotEmpty
        ? '$bpSystolic/$bpDiastolic'
        : _stringOrEmpty(vital['bloodPressure'] ?? vital['BloodPressure']);
    final hr = _stringOrEmpty(vital['pulse'] ?? vital['Pulse'] ?? vital['heartRate'] ?? vital['HeartRate']);
    final temp = _stringOrEmpty(vital['temperature'] ?? vital['Temperature']);
    final spo2 = _stringOrEmpty(vital['spo2'] ?? vital['SPO2'] ?? vital['oxygenSaturation'] ?? vital['OxygenSaturation']);
    final rr = _stringOrEmpty(vital['respiratoryRate'] ?? vital['RespiratoryRate'] ?? vital['respiratory_rate']);
    final weight = _stringOrEmpty(vital['weight'] ?? vital['Weight']);
    final height = _stringOrEmpty(vital['height'] ?? vital['Height']);
    final bsr = _stringOrEmpty(vital['bsr'] ?? vital['BSR'] ?? vital['bloodSugar'] ?? vital['BloodSugar']);
    final createdByName = vital['createdByName'] ?? vital['CreatedByName'] ?? vital['recordedBy'] ?? vital['RecordedBy'] ?? '';

    // Parse values for range checking
    double? bpSystolicValue, bpDiastolicValue;
    // Try parsing from individual values first
    if (bpSystolic.toString().isNotEmpty) {
      bpSystolicValue = double.tryParse(bpSystolic);
    }
    if (bpDiastolic.toString().isNotEmpty) {
      bpDiastolicValue = double.tryParse(bpDiastolic);
    }
    // Fall back to parsing from combined BP string if individual values not available
    if ((bpSystolicValue == null || bpDiastolicValue == null) && bp.contains('/')) {
      final parts = bp.split('/');
      if (parts.length == 2) {
        bpSystolicValue ??= double.tryParse(parts[0].trim());
        bpDiastolicValue ??= double.tryParse(parts[1].trim());
      }
    }
    final hrValue = double.tryParse(hr);
    final tempValue = double.tryParse(temp);
    final spo2Value = double.tryParse(spo2);
    final bsrValue = double.tryParse(bsr);
    final bmi = _calculateBMI(weight, height);

    // Check for out-of-range values
    final bpOutOfRange = (bpSystolicValue != null && !_isSystolicNormal(bpSystolicValue)) ||
                         (bpDiastolicValue != null && !_isDiastolicNormal(bpDiastolicValue));
    final hrOutOfRange = hrValue != null && !_isPulseNormal(hrValue);
    final tempOutOfRange = tempValue != null && !_isTemperatureNormal(tempValue);
    final spo2OutOfRange = spo2Value != null && !_isO2SaturationNormal(spo2Value);
    final bsrOutOfRange = bsrValue != null && !_isBSRNormal(bsrValue);
    final bmiOutOfRange = bmi != null && !_isBMINormal(bmi);

    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: cs.outline.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: 1,
          ),
        ],
        border: Border.all(color: cs.outline.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vitals Header with vitals displayed inline
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.error, cs.error.withValues(alpha: 0.9)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.favorite, color: cs.onError, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Vitals',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onError,
                  ),
                ),
                if (parsedDate != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.calendar_today, size: 12, color: cs.onError.withValues(alpha: 0.9)),
                  const SizedBox(width: 4),
                  Text(
                    '${parsedDate.day}/${parsedDate.month}/${parsedDate.year} ${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: cs.onError.withValues(alpha: 0.9), fontSize: 11),
                  ),
                ],
                if (createdByName.toString().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.person, size: 12, color: cs.onError.withValues(alpha: 0.9)),
                  const SizedBox(width: 4),
                  Text(
                    createdByName.toString(),
                    style: TextStyle(color: cs.onError.withValues(alpha: 0.9), fontSize: 11),
                  ),
                ],
                const Spacer(),
                // Display vitals in header
                Flexible(
                  child: _buildVitalsContent(bp, hr, temp, spo2, rr, weight, height, bsr, isHeader: true),
                ),
              ],
            ),
          ),

          // Vitals Details (only show if not in header or for detailed view)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildVitalsContent(bp, hr, temp, spo2, rr, weight, height, bsr, isHeader: false),
          ),
        ],
      ),
    );
  }

  Widget _buildSurgeryCard(Map<String, dynamic> surgery) {
    final cs = Theme.of(context).colorScheme;
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
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: cs.tertiary.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: cs.tertiary.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Surgery Header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.tertiary, cs.tertiary.withValues(alpha: 0.9)],
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
                          Icon(Icons.healing, color: cs.onTertiary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              surgeryName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: cs.onTertiary,
                              ),
                            ),
                          ),
                          if (parsedDate != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.calendar_today, size: 14, color: cs.onTertiary.withValues(alpha: 0.9)),
                            const SizedBox(width: 4),
                            Text(
                              '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}',
                              style: TextStyle(color: cs.onTertiary.withValues(alpha: 0.9), fontSize: 12),
                            ),
                            if (surgeryStartTime.toString().isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.access_time, size: 14, color: cs.onTertiary.withValues(alpha: 0.9)),
                              const SizedBox(width: 4),
                              Text(
                                '${surgeryStartTime}${surgeryEndTime.toString().isNotEmpty ? ' - $surgeryEndTime' : ''}',
                                style: TextStyle(color: cs.onTertiary.withValues(alpha: 0.9), fontSize: 12),
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
                    color: cs.onTertiary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.onTertiary, width: 1),
                  ),
                  child: Text(
                    surgeryStatus.toString().toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.onTertiary,
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
                      color: cs.tertiaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cs.tertiary.withValues(alpha: 0.5), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.note, color: cs.tertiary, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Procedure Note',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: cs.tertiary,
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
                      color: cs.errorContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cs.error.withValues(alpha: 0.5), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning, color: cs.error, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'Complications',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: cs.error,
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
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: cs.onSurfaceVariant,
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
                    color: color,
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
                      Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
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

  Widget _buildLabResultsSection(List<dynamic> labOrders) {
    final cs = Theme.of(context).colorScheme;
    // Filter out orders without results
    final resultsWithData = labOrders.where((lab) {
      final resultId = lab['resultId'];
      final resultValue = lab['resultValue'];
      return resultId != null || (resultValue != null && resultValue.toString().isNotEmpty);
    }).toList();

    if (resultsWithData.isEmpty) {
      // If no results, show just test names like before
      final testNames = labOrders.map<String>((lab) {
        final isPackage = lab['type'] == 'package';
        final isPackageTest = lab['type'] == 'package_test';
        final name = isPackageTest
            ? (lab['testName'] ?? 'N/A')
            : (isPackage
                ? (lab['packageName'] ?? 'N/A')
                : (lab['testName'] ?? 'N/A'));
        final type = (isPackage || isPackageTest) ? 'Package' : 'Test';
        return '$name ($type)';
      }).toList();
      
      if (testNames.isEmpty) {
        return const SizedBox.shrink();
      }
      
      return _buildCompactDetailSection(
        'Lab Tests',
        Icons.science,
        cs.primary,
        testNames,
      );
    }

    final color = cs.primary;
    final colorLight = color.withValues(alpha: 0.15);
    final colorBorder = color.withValues(alpha: 0.5);
    
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
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surface,
            colorLight,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: cs.outline.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: colorBorder,
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
                Icon(Icons.science, color: color, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Lab Results',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Table header
            Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('Test Name', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurface))),
                  Expanded(flex: 2, child: Text('Result', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurface))),
                  Expanded(flex: 1, child: Text('Unit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurface))),
                  Expanded(flex: 2, child: Text('Ref Range', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurface))),
                  Expanded(flex: 1, child: Text('Status', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurface))),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Table rows
            ...resultsWithData.map((lab) {
              final isPackage = lab['type'] == 'package';
              final isPackageTest = lab['type'] == 'package_test';
              final testName = isPackageTest
                  ? (lab['testName'] ?? 'N/A')
                  : (isPackage
                      ? (lab['packageName'] ?? lab['testName'] ?? 'N/A')
                      : (lab['testName'] ?? 'N/A'));
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
                rowBgColor = cs.errorContainer.withValues(alpha: 0.5);
              } else if (status == 'HIGH' || status == 'LOW') {
                rowBgColor = cs.tertiaryContainer.withValues(alpha: 0.5);
              }
              
              // Status badge colors
              Color statusBgColor;
              Color statusTextColor;
              if (status == 'NORMAL') {
                statusBgColor = cs.secondaryContainer;
                statusTextColor = cs.onSecondaryContainer;
              } else if (status == 'HIGH' || status == 'LOW') {
                statusBgColor = cs.tertiaryContainer;
                statusTextColor = cs.onTertiaryContainer;
              } else if (status == 'CRITICAL') {
                statusBgColor = cs.errorContainer;
                statusTextColor = cs.onErrorContainer;
              } else {
                statusBgColor = cs.surfaceContainerHighest;
                statusTextColor = cs.onSurfaceVariant;
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
                            Text('🔴 ', style: TextStyle(fontSize: 8)),
                          ],
                          Expanded(
                            child: Text(
                              resultValue,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: shouldHighlight ? FontWeight.bold : FontWeight.normal,
                                color: shouldHighlight ? cs.error : cs.onSurface,
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
                        style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
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
            }).toList(),
            // Interpretation section (if any)
            if (resultsWithData.any((lab) => (lab['resultInterpretation'] ?? '').toString().isNotEmpty)) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                  border: Border(left: BorderSide(color: color, width: 2)),
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
                          style: TextStyle(fontSize: 10, color: cs.onSurface),
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
  }

  Widget _buildRadiologyReportsSection(List<dynamic> radiologyOrders) {
    final cs = Theme.of(context).colorScheme;
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
        cs.tertiary,
        testNames,
      );
    }

    final color = cs.tertiary;
    final colorLight = color.withValues(alpha: 0.15);
    final colorBorder = color.withValues(alpha: 0.5);
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surface,
            colorLight,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: cs.outline.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: colorBorder,
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
                Icon(Icons.scanner, color: color, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Radiology Reports',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
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
                        Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
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
                                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
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
                                  style: TextStyle(fontSize: 11, color: cs.primary),
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
    final cs = Theme.of(context).colorScheme;
    final colorLight = color.withValues(alpha: 0.15);
    final colorBorder = color.withValues(alpha: 0.5);
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surface,
            colorLight,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: cs.outline.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: colorBorder,
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
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: color,
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
                    Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
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


  Color _getStatusColor(BuildContext context, String status) {
    final cs = Theme.of(context).colorScheme;
    final statusLower = status.toString().toLowerCase();
    if (statusLower.contains('checked out') || statusLower == 'checked_out') {
      return cs.outline;
    } else if (statusLower.contains('checked in') || statusLower == 'checked_in' || statusLower.contains('in progress')) {
      return cs.secondary;
    } else {
      return cs.primary;
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
    // Convert Celsius to Fahrenheit for comparison (nurse_vital uses 97.0-99.5°F)
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

  Widget _buildVitalsContent(String bp, String hr, String temp, String spo2, String rr, String weight, String height, String bsr, {bool isHeader = false}) {
    final cs = Theme.of(context).colorScheme;
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

    final textColor = isHeader ? cs.onError : cs.onSurface;
    final fontSize = isHeader ? 11.0 : 13.0;

    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: fontSize, color: textColor),
        children: [
          _buildVitalTextSpan('BP', bp, bpOutOfRange, textColor: textColor, fontSize: fontSize),
          TextSpan(text: ' | ', style: TextStyle(color: textColor, fontSize: fontSize)),
          _buildVitalTextSpan('HR', hr, hrOutOfRange, textColor: textColor, fontSize: fontSize),
          TextSpan(text: ' | ', style: TextStyle(color: textColor, fontSize: fontSize)),
          _buildVitalTextSpan('Temp', temp, tempOutOfRange, textColor: textColor, fontSize: fontSize),
          TextSpan(text: ' | ', style: TextStyle(color: textColor, fontSize: fontSize)),
          _buildVitalTextSpan('SpO2', spo2, spo2OutOfRange, textColor: textColor, fontSize: fontSize),
          TextSpan(text: ' | ', style: TextStyle(color: textColor, fontSize: fontSize)),
          _buildVitalTextSpan('RR', rr, rrOutOfRange, textColor: textColor, fontSize: fontSize),
          if (!isHeader) ...[
            TextSpan(text: ' | ', style: TextStyle(color: textColor, fontSize: fontSize)),
            _buildVitalTextSpan('Weight', weight, false, textColor: textColor, fontSize: fontSize),
            TextSpan(text: ' | ', style: TextStyle(color: textColor, fontSize: fontSize)),
            _buildVitalTextSpan('Height', height, false, textColor: textColor, fontSize: fontSize),
            if (bmiStr.isNotEmpty) ...[
              TextSpan(text: ' | ', style: TextStyle(color: textColor, fontSize: fontSize)),
              _buildVitalTextSpan('BMI', bmiStr, bmiOutOfRange, textColor: textColor, fontSize: fontSize),
            ],
            if (bsr.toString().trim().isNotEmpty) ...[
              TextSpan(text: ' | ', style: TextStyle(color: textColor, fontSize: fontSize)),
              _buildVitalTextSpan('BSR', bsr, bsrOutOfRange, textColor: textColor, fontSize: fontSize),
            ],
          ],
        ],
      ),
    );
  }

  TextSpan _buildVitalTextSpan(String label, String value, bool isOutOfRange, {Color? textColor, double? fontSize}) {
    final cs = Theme.of(context).colorScheme;
    final displayValue = value.toString().trim().isEmpty ? '-' : value;
    final baseColor = textColor ?? cs.onSurface;
    final baseFontSize = fontSize ?? 13.0;
    
    return TextSpan(
      children: [
        TextSpan(
          text: '$label: ',
          style: TextStyle(color: baseColor, fontSize: baseFontSize),
        ),
        TextSpan(
          text: displayValue,
          style: TextStyle(
            fontWeight: isOutOfRange ? FontWeight.bold : FontWeight.normal,
            color: isOutOfRange ? cs.error : baseColor,
            fontSize: baseFontSize,
          ),
        ),
      ],
    );
  }

  Future<void> _generateAndPrintAllEncounters() async {
    if (_encounterDataList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No encounters to print. Load data first.')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF generated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }
}

