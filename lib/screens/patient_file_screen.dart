import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:convert';
import '../utils/app_date_format.dart';
import '../utils/app_localizations_ext.dart';
import '../widgets/punjab_ui.dart';
import '../utils/emr_api_client.dart';
import '../utils/app_snackbar.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/clinical_notes_format.dart';
import '../utils/clinical_history_assembler.dart';
import '../utils/lab_order_presenter.dart';
import 'patient_file_print_helper.dart';

class PatientFileScreen extends StatefulWidget {
  final Map<String, dynamic> patient;
  final int? admissionId;
  final bool embedded;
  final bool autoLoad;

  const PatientFileScreen({
    Key? key,
    required this.patient,
    this.admissionId,
    this.embedded = false,
    this.autoLoad = false,
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
  List<Map<String, dynamic>> _medicinesGiven = [];
  List<Map<String, dynamic>> _vaccines = [];
  List<Map<String, dynamic>> _transfusions = [];

  // Date filters
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 15));
  DateTime _endDate = DateTime.now();
  bool _dataLoaded = false;
  bool _loadingFile = false; // true while Show fetch is in progress (disables button, shows progress)

  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      _startDate = DateTime.now().subtract(const Duration(days: 30));
      _endDate = DateTime.now();
    }
    _initializeApi().then((_) {
      _loadHeaderSummary();
      if (widget.autoLoad && mounted) {
        _loadDataWithFilters();
      }
    });
  }

  Future<void> _initializeApi() async {
    try {
      _api = EmrApiClient();
    } catch (e) {
      // ignore
    }
  }

  bool _isDateInRange(DateTime? d, DateTime from, DateTime to) {
    if (d == null) return false;
    final day = DateTime(d.year, d.month, d.day);
    final f = DateTime(from.year, from.month, from.day);
    final t = DateTime(to.year, to.month, to.day);
    return !day.isBefore(f) && !day.isAfter(t);
  }

  Future<List<Map<String, dynamic>>> _loadSurgeriesInRange(int patientId, DateTime from, DateTime to) async {
    if (_api == null) return [];
    try {
      final surgeries = await _api!.getPatientSurgeries(patientId);
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

    void addExtra(String type, List<Map<String, dynamic>> rows) {
      for (final row in rows) {
        final raw = row['givenAt'] ?? row['GivenAt'];
        final parsed = raw is DateTime ? raw : DateTime.tryParse(raw?.toString() ?? '');
        timeline.add({'type': type, 'date': parsed, 'data': row});
      }
    }

    addExtra('medicine_given', _medicinesGiven);
    addExtra('vaccine', _vaccines);
    addExtra('transfusion', _transfusions);

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
        _api!.getPatientSafeExtras(parsedPatientId).catchError((_) => <String, dynamic>{}),
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
          final extras = results[4] as Map<String, dynamic>;
          final vax = extras['vaccines'];
          if (vax is List) {
            _vaccines = vax.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          }
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

  Future<void> _loadDataWithFilters() async {
    if (_api == null) {
      await _initializeApi();
    }
    if (_api == null) {
      setState(() {
        _error = 'API not ready. Please retry.';
        _loading = false;
      });
      return;
    }
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
      _loadingFile = true;
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
      setState(() {
        _loading = false;
        _loadingFile = false;
      });
      return;
    }

    final parsedPatientId = patientId is int ? patientId : int.tryParse(patientId.toString());
    if (parsedPatientId == null) {
      setState(() {
        _loading = false;
        _loadingFile = false;
      });
      return;
    }

    try {
      final endDate = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      final startDate = DateTime(_startDate.year, _startDate.month, _startDate.day, 0, 0, 0);

      final results = await Future.wait([
        _api!.getPatientClinicalHistory(
          parsedPatientId,
          fromDate: startDate,
          toDate: endDate,
        ),
        _loadSurgeriesInRange(parsedPatientId, startDate, endDate),
        _api!.getPatientSafeExtras(
          parsedPatientId,
          fromDate: startDate,
          toDate: endDate,
        ).catchError((_) => <String, dynamic>{}),
      ]);

      final history = results[0] as Map<String, dynamic>;
      final surgeries = results[1] as List<Map<String, dynamic>>;
      final extras = results[2] as Map<String, dynamic>;
      final encounterDataList = ClinicalHistoryAssembler.fromHistory(history);
      final encounters = encounterDataList
          .map((e) => Map<String, dynamic>.from(e['encounter'] as Map))
          .toList();
      final vitals = List<dynamic>.from(history['vitals'] as List? ?? const []);

      List<Map<String, dynamic>> extraList(String key) {
        final raw = extras[key];
        if (raw is! List) return [];
        return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }

      if (!mounted) return;
      setState(() {
        _encounters = encounters;
        _encounterDataList = encounterDataList;
        _allVitals = vitals;
        _surgeries = surgeries;
        _medicinesGiven = extraList('medicinesGiven');
        _vaccines = extraList('vaccines');
        _transfusions = extraList('transfusions');
        _combinedTimeline = _computeCombinedTimeline();
        _dataLoaded = true;
        _loading = false;
        _loadingFile = false;
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
          _loadingFile = false;
          _dataLoaded = true;
        });
      }
    }
  }

  Widget _buildDateFilterSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.fromLTRB(
        widget.embedded ? 16.0 : 12.0,
        widget.embedded ? 0.0 : 8.0,
        widget.embedded ? 16.0 : 12.0,
        8.0,
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.date_range, color: colorScheme.primary, size: 18),
              const SizedBox(width: 6),
              Text(
                'From',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
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
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppDateFormat.formatDate(_startDate),
                          style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
                        ),
                        Icon(Icons.calendar_today, size: 14, color: colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'To',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: InkWell(
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
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outline),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppDateFormat.formatDate(_endDate),
                          style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
                        ),
                        Icon(Icons.calendar_today, size: 14, color: colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: (_loading || _loadingDetails) ? null : _loadDataWithFilters,
            icon: (_loading || _loadingDetails)
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                    ),
                  )
                : const Icon(Icons.search, size: 16),
            label: Text(widget.autoLoad ? 'Refresh records' : 'Show Records'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _dataLoaded && !_loading ? _exportHistory : null,
            icon: const Icon(Icons.ios_share, size: 16),
            label: const Text('Export FHIR + PDF'),
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

    final vaccinesText = joinWithComma(
      _vaccines.map((v) {
        final name = (v['vaccineName'] ?? v['VaccineName'] ?? '').toString();
        return name;
      }).where((s) => s.isNotEmpty),
      max: 4,
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
                                    _pill(icon: Icons.vaccines, label: 'Vaccines', value: vaccinesText),
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

  Widget _buildBody(ColorScheme colorScheme) {
    return Column(
        children: [
          if (!widget.embedded) _buildPatientInfoCard(),
          _buildDateFilterSection(),
          const SizedBox(height: 8),
          Expanded(
            child: !_dataLoaded && !_loading && !_loadingDetails && !widget.autoLoad
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
                              context.l10n.fetchingPatientData,
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
                        : _combinedTimeline.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.folder_open, size: 48, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                                    const SizedBox(height: 16),
                                    Text(
                                      context.l10n.noEncountersFound,
                                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  12,
                                  widget.embedded ? PunjabBottomNav.navBarHeight : 12,
                                ),
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
                                  if (type == 'medicine_given' ||
                                      type == 'vaccine' ||
                                      type == 'transfusion') {
                                    return _buildSafeExtraCard(
                                      type,
                                      item['data'] as Map<String, dynamic>,
                                      item['date'] as DateTime?,
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
          ),
        ],
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final body = _buildBody(colorScheme);
    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Patient File', style: theme.appBarTheme.titleTextStyle),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: _exportHistory,
            tooltip: 'Export FHIR + PDF',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _generateAndPrintAllEncounters,
            tooltip: 'Print All Encounters',
          ),
        ],
      ),
      body: body,
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

    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        AppSnackBar.showInfo(context, 'Encounter #$encounterId - view only');
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        encounterType.toString().isNotEmpty 
                            ? '$encounterType Checkup'
                            : 'Checkup',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (parsedDate != null) ...[
                      Icon(Icons.calendar_today, size: 12, color: cs.onPrimary.withValues(alpha: 0.85)),
                      const SizedBox(width: 4),
                      Text(
                        AppDateFormat.formatDateTime(parsedDate),
                        style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.9), fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Icon(Icons.person_outline, size: 12, color: cs.onPrimary.withValues(alpha: 0.85)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        doctorName.toString(),
                        style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.9), fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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

                // Complaints, Symptoms, Diagnosis - Stacked for reliable mobile layout
                _buildCompactDetailSection(
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
                const SizedBox(height: 8),
                _buildCompactDetailSection(
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
                const SizedBox(height: 8),
                _buildCompactDetailSection(
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

                const SizedBox(height: 8),

                // Lab Tests, Radiology, Medicines - Full-width stacked sections
                _buildLabResultsSection(labOrders),
                const SizedBox(height: 8),
                _buildRadiologyReportsSection(radiologyOrders),
                const SizedBox(height: 8),
                _buildCompactDetailSection(
                  'Medicines',
                  Icons.medication,
                  cs.primary,
                  medicines.map<String>((med) {
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
                      medText += ' — $dosage $dosageUnit';
                    }
                    if (frequency != null && frequency.toString().isNotEmpty) {
                      medText += ' · $frequency';
                    }
                    if (duration != null && durationUnit != null && duration.toString().isNotEmpty) {
                      medText += ' · $duration $durationUnit';
                    }
                    if (endDate != null) {
                      try {
                        final end = endDate is DateTime ? endDate : DateTime.tryParse(endDate.toString());
                        if (end != null) {
                          medText += ' (until ${AppDateFormat.formatDate(end)})';
                        }
                      } catch (e) {}
                    }
                    if (discontinuedDate != null) {
                      medText += ' ✕ DISCONTINUED';
                    }
                    return medText;
                  }).toList(),
                ),

                // Clinical Notes - shown at bottom
                if (clinicalNoteTexts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: cs.primaryContainer.withValues(alpha: 0.2),
                      border: Border.all(color: cs.primary.withValues(alpha: 0.2), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.description_outlined, color: cs.primary, size: 15),
                            const SizedBox(width: 6),
                            Text(
                              'Clinical Notes',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...clinicalNoteTexts.map(
                          (note) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '• $note',
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
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
                              AppDateFormat.formatDate(parsedDate),
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
    final resultsWithData = labOrders.where(LabOrderPresenter.hasResult).toList();
    final pendingLabels = LabOrderPresenter.pendingLabels(
      labOrders.where((lab) => !LabOrderPresenter.hasResult(lab)).toList(),
    );

    if (resultsWithData.isEmpty) {
      if (pendingLabels.isEmpty) {
        return const SizedBox.shrink();
      }
      return _buildCompactDetailSection(
        'Lab Tests',
        Icons.science,
        cs.primary,
        pendingLabels,
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
    
    final resultsSection = Container(
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
            // Table rows grouped by package
            for (final group in LabOrderPresenter.groupResultsByPackage(resultsWithData)) ...[
              if (group.key.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 2),
                  child: Text(
                    group.key,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
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
              }),
            ],
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

    if (pendingLabels.isEmpty) return resultsSection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCompactDetailSection(
          'Lab Tests',
          Icons.science,
          cs.primary,
          pendingLabels,
        ),
        const SizedBox(height: 8),
        resultsSection,
      ],
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

  Widget _buildCompactVitalsBlock(
    Map<dynamic, dynamic> v, {
    DateTime? recordedDate,
    String? recordedBy,
  }) {
    final cs = Theme.of(context).colorScheme;
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
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant, width: 1),
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
                  Icon(Icons.favorite, color: cs.onSurfaceVariant, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Vitals',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  if (recordedDate != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      AppDateFormat.formatDateTime(recordedDate),
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (recordedBy != null && recordedBy.trim().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        recordedBy.trim(),
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
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
                Icon(Icons.favorite, color: cs.onSurfaceVariant, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Vitals',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
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

  Widget _buildVitalChip(
    String label,
    String value,
    bool isOutOfRange, {
    bool isHeader = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final display = value.trim().isEmpty ? '—' : value;
    final bg = isOutOfRange ? cs.errorContainer : cs.surfaceContainerHighest;
    final fg = isOutOfRange ? cs.onErrorContainer : cs.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: isOutOfRange
            ? Border.all(color: cs.error.withValues(alpha: 0.6), width: 1)
            : Border.all(color: cs.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isHeader ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: PunjabColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            display,
            style: TextStyle(
              fontSize: isHeader ? 12 : 14,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: isOutOfRange ? cs.error : fg,
            ),
          ),
        ],
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
    String bsr, {
    bool isHeader = false,
  }) {
    double? bpSystolic, bpDiastolic;
    if (bp.contains('/')) {
      final parts = bp.split('/');
      if (parts.length == 2) {
        bpSystolic = double.tryParse(parts[0].trim());
        bpDiastolic = double.tryParse(parts[1].trim());
      }
    }

    final bmi = _calculateBMI(weight, height);
    final bmiStr = bmi != null ? bmi.toStringAsFixed(1) : '';

    final bpSystolicOutOfRange =
        bpSystolic != null && !_isSystolicNormal(bpSystolic);
    final bpDiastolicOutOfRange =
        bpDiastolic != null && !_isDiastolicNormal(bpDiastolic);
    final bpOutOfRange = bpSystolicOutOfRange || bpDiastolicOutOfRange;
    final hrValue = double.tryParse(hr);
    final hrOutOfRange = hrValue != null && !_isPulseNormal(hrValue);
    final tempValue = double.tryParse(temp);
    final tempOutOfRange =
        tempValue != null && !_isTemperatureNormal(tempValue);
    final spo2Value = double.tryParse(spo2);
    final spo2OutOfRange =
        spo2Value != null && !_isO2SaturationNormal(spo2Value);
    final rrValue = double.tryParse(rr);
    final rrOutOfRange = rrValue != null && !_isRespiratoryRateNormal(rrValue);
    final bmiOutOfRange = bmi != null && !_isBMINormal(bmi);
    final bsrValue = double.tryParse(bsr);
    final bsrOutOfRange = bsrValue != null && !_isBSRNormal(bsrValue);

    final l = context.l10n;
    final tiles = <Widget>[
      if (bp.isNotEmpty)
        _buildVitalChip(l.vitalBp, bp, bpOutOfRange, isHeader: isHeader),
      if (hr.isNotEmpty)
        _buildVitalChip(l.vitalHr, hr, hrOutOfRange, isHeader: isHeader),
      if (temp.isNotEmpty)
        _buildVitalChip(l.vitalTemp, temp, tempOutOfRange, isHeader: isHeader),
      if (spo2.isNotEmpty)
        _buildVitalChip(l.vitalSpo2, spo2, spo2OutOfRange, isHeader: isHeader),
      if (rr.isNotEmpty)
        _buildVitalChip(l.vitalRr, rr, rrOutOfRange, isHeader: isHeader),
      if (weight.isNotEmpty)
        _buildVitalChip(l.vitalWt, weight, false, isHeader: isHeader),
      if (height.isNotEmpty)
        _buildVitalChip(l.vitalHt, height, false, isHeader: isHeader),
      if (bmiStr.isNotEmpty)
        _buildVitalChip(l.vitalBmi, bmiStr, bmiOutOfRange, isHeader: isHeader),
      if (bsr.isNotEmpty)
        _buildVitalChip(l.vitalBsr, bsr, bsrOutOfRange, isHeader: isHeader),
    ];

    if (tiles.isEmpty) {
      return Text(
        'No vitals recorded',
        style: TextStyle(
          fontSize: 12,
          color: PunjabColors.textSecondary.withValues(alpha: 0.9),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 340 ? 4 : 2;
        const gap = 8.0;
        final tileWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles) SizedBox(width: tileWidth, child: tile),
          ],
        );
      },
    );
  }

  Widget _buildSafeExtraCard(String type, Map<String, dynamic> row, DateTime? date) {
    final cs = Theme.of(context).colorScheme;
    late final String title;
    late final String detail;
    late final IconData icon;
    if (type == 'vaccine') {
      title = 'Vaccine';
      detail = (row['vaccineName'] ?? row['VaccineName'] ?? 'Vaccine').toString();
      icon = Icons.vaccines;
    } else if (type == 'transfusion') {
      title = 'Blood given';
      final product = (row['productType'] ?? '').toString();
      final bg = (row['bloodGroup'] ?? '').toString();
      detail = [product, bg].where((e) => e.isNotEmpty).join(' · ');
      icon = Icons.bloodtype;
    } else {
      title = 'Medicine given';
      final name = (row['medicineName'] ?? '').toString();
      final slot = (row['timeSlot'] ?? '').toString();
      detail = [name, slot].where((e) => e.isNotEmpty).join(' · ');
      icon = Icons.medication;
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: cs.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [
            if (date != null) AppDateFormat.formatDateTime(date),
            if (detail.isNotEmpty) detail,
          ].join(' — '),
        ),
      ),
    );
  }

  Future<void> _exportHistory() async {
    final patientId = widget.patient['patientId'] ?? widget.patient['PatientID'];
    final parsed = patientId is int ? patientId : int.tryParse(patientId?.toString() ?? '');
    if (_api == null || parsed == null) {
      AppSnackBar.showError(context, 'Cannot export yet.');
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final fhir = await _api!.getPatientIpsFhir(
        parsed,
        fromDate: _startDate,
        toDate: _endDate,
      );
      final dir = await getTemporaryDirectory();
      final fhirFile = File(
        '${dir.path}/hmis-ips-$parsed-${_startDate.toIso8601String().substring(0, 10)}.json',
      );
      await fhirFile.writeAsString(fhir);
      final pdfBytes = await PatientFilePrintHelper.buildPdfBytes(
        encounterDataList: _encounterDataList,
        patient: widget.patient,
      );
      if (mounted) Navigator.pop(context);
      final files = <XFile>[XFile(fhirFile.path, mimeType: 'application/fhir+json')];
      if (pdfBytes != null) {
        final pdfFile = File('${dir.path}/hmis-history-$parsed.pdf');
        await pdfFile.writeAsBytes(pdfBytes);
        files.add(XFile(pdfFile.path, mimeType: 'application/pdf'));
      }
      await Share.shareXFiles(
        files,
        text: 'My HMIS medical history (FHIR + PDF)',
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.showError(context, 'Export failed: $e');
      }
    }
  }

  Future<void> _generateAndPrintAllEncounters() async {
    if (_encounterDataList.isEmpty) {
      AppSnackBar.showInfo(context, 'No encounters to print. Load data first.');
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

