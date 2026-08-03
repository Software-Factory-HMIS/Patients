import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/patient_service.dart';
import '../../services/encounter_service.dart';
import '../../services/pregnancy_service.dart';
import '../../services/pharmacy_service.dart';
import '../../services/user_session_service.dart';
import '../../services/ward_service.dart';
import '../../config/api_config.dart';
import 'queues/consultation_summary_screen.dart';
import 'radiology/radiology_report_print_screen.dart';
import 'wards/discharge_slip_print_screen.dart';
import '../../models/patient_header_cache.dart';
import '../../models/patient_history_models.dart';
import '../../database/app_database.dart';
import '../../repository/patient_history_repository.dart';

/// Returns true if result is out of reference range. Supports: A-B, <C, >D, <=C, >=D, Negative, Positive, Non-reactive, Reactive, etc.
bool _isLabResultOutOfRef(String resultStr, String refRangeStr) {
  if (resultStr.isEmpty || resultStr == '-' || refRangeStr.isEmpty || refRangeStr == '-') return false;
  final result = resultStr.trim();
  final ref = refRangeStr.trim();

  // Try numeric comparison first
  final resultNum = double.tryParse(result.replaceAll(RegExp(r'[^\d.]'), ''));

  // A-B range (e.g. 4.5-11, 12-16, or with units: 4.5-11 x10^9/L)
  final rangeMatch = RegExp(r'([\d.]+)\s*-\s*([\d.]+)').firstMatch(ref);
  if (rangeMatch != null && resultNum != null) {
    final low = double.tryParse(rangeMatch.group(1) ?? '');
    final high = double.tryParse(rangeMatch.group(2) ?? '');
    if (low != null && high != null) return resultNum < low || resultNum > high;
  }

  // <C or <=C (normal: result < C; out if result >= C)
  final lessMatch = RegExp(r'[<≤]=\s*([\d.]+)').firstMatch(ref) ?? RegExp(r'<\s*([\d.]+)').firstMatch(ref);
  if (lessMatch != null && resultNum != null) {
    final c = double.tryParse(lessMatch.group(1) ?? '');
    if (c != null) return (ref.contains('=') || ref.contains('≤')) ? resultNum > c : resultNum >= c;
  }

  // >D or >=D (normal: result > D; out if result <= D)
  final greaterMatch = RegExp(r'[>≥]=\s*([\d.]+)').firstMatch(ref) ?? RegExp(r'>\s*([\d.]+)').firstMatch(ref);
  if (greaterMatch != null && resultNum != null) {
    final d = double.tryParse(greaterMatch.group(1) ?? '');
    if (d != null) return (ref.contains('=') || ref.contains('≥')) ? resultNum < d : resultNum <= d;
  }

  // Text/categorical: Negative, Positive, Non-reactive, Reactive, etc.
  final r = result.toLowerCase();
  final refLower = ref.toLowerCase();
  final isNeg = r.contains('neg') || r == 'negative' || r == 'nil' || r == 'none' || r == 'non-reactive' || r == 'non reactive';
  final isPos = r.contains('pos') || r == 'positive' || r == 'reactive';
  if (refLower.contains('negative') || refLower == 'neg' || refLower == 'nil' || refLower == 'none' || refLower.contains('non-reactive')) {
    return isPos; // positive result when ref expects negative = out of range
  }
  if (refLower.contains('positive') || refLower == 'pos' || refLower == 'reactive') {
    return isNeg; // negative result when ref expects positive = out of range
  }

  return false;
}

class _LabsPivotWidget extends StatefulWidget {
  final List<Map<String, dynamic>> pivotData;
  final TextEditingController searchController;
  final bool shrinkWrap;

  const _LabsPivotWidget({required this.pivotData, required this.searchController, this.shrinkWrap = false});

  @override
  State<_LabsPivotWidget> createState() => _LabsPivotWidgetState();
}

class _LabsPivotWidgetState extends State<_LabsPivotWidget> {
  late Set<String> _collapsed;
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _collapsed = widget.pivotData.map((p) => (p['packageName'] ?? '').toString()).where((s) => s.isNotEmpty).toSet();
  }

  void _onSearchDebounced() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _query = widget.searchController.text.toLowerCase().trim());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Widget _buildPackageList(List<Map<String, dynamic>> packages) {
    Widget list = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView.builder(
        primary: false,
        shrinkWrap: widget.shrinkWrap,
        physics: widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        itemCount: packages.length,
        itemBuilder: (_, i) => RepaintBoundary(
          child: _LabPackageCard(
            pkg: packages[i] as Map<String, dynamic>,
            isCollapsed: _collapsed.contains((packages[i]['packageName'] ?? '').toString()),
            onToggle: () {
              final key = (packages[i]['packageName'] ?? '').toString();
              setState(() {
                if (_collapsed.contains(key)) {
                  _collapsed.remove(key);
                } else {
                  _collapsed.add(key);
                }
              });
            },
            isOutOfRange: _isLabResultOutOfRef,
          ),
        ),
      ),
    );
    return widget.shrinkWrap ? list : Expanded(child: list);
  }

  @override
  Widget build(BuildContext context) {
    var packages = widget.pivotData;
    if (_query.isNotEmpty) {
      packages = widget.pivotData.where((p) {
        final name = (p['packageName'] ?? '').toString().toLowerCase();
        if (name.contains(_query)) return true;
        for (final t in (p['tests'] as List<dynamic>)) {
          if ((t['testName'] ?? '').toString().toLowerCase().contains(_query)) return true;
        }
        return false;
      }).toList();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.searchController,
          onChanged: (_) => _onSearchDebounced(),
          decoration: InputDecoration(
            hintText: 'Search labs by package or test name...',
            prefixIcon: const Icon(Icons.search_rounded, size: 22),
            suffixIcon: widget.searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    onPressed: () {
                      widget.searchController.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        packages.isEmpty
            ? Center(
                child: Text(_query.isNotEmpty ? 'No results found' : 'No lab data available', style: Theme.of(context).textTheme.bodyLarge),
              )
            : _buildPackageList(packages),
      ],
    );
  }
}

class _LabPackageCard extends StatelessWidget {
  final Map<String, dynamic> pkg;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final bool Function(String, String) isOutOfRange;

  const _LabPackageCard({required this.pkg, required this.isCollapsed, required this.onToggle, required this.isOutOfRange});

  @override
  Widget build(BuildContext context) {
    final packageName = (pkg['packageName'] ?? 'N/A').toString();
    final dates = (pkg['dates'] as List<dynamic>).map((e) => e.toString()).toList();
    final tests = (pkg['tests'] as List<dynamic>).cast<Map<String, dynamic>>();
    final isExpanded = !isCollapsed;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 1))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(isExpanded ? Icons.remove_circle_outline : Icons.add_circle_outline, size: 20, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(packageName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded && tests.isNotEmpty)
            SingleChildScrollView(
              primary: false,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 10,
                headingRowHeight: 32,
                dataRowMinHeight: 28,
                headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
                columns: [
                  const DataColumn(label: Text('Test Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                  ...dates.map((d) => DataColumn(label: Text(d, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10)))),
                  const DataColumn(label: Text('Ref Range', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                ],
                rows: tests.map((t) {
                  final testName = (t['testName'] ?? 'N/A').toString();
                  final refRange = (t['referenceRange'] ?? '').toString();
                  final resultsByDate = (t['resultsByDate'] as Map<String, dynamic>? ?? {}) as Map<String, String>;
                  final cells = <DataCell>[
                    DataCell(SizedBox(width: 110, child: Text(testName, style: const TextStyle(fontSize: 11)))),
                    ...dates.map((d) {
                      final val = resultsByDate[d] ?? '';
                      final outOfRange = val.isNotEmpty && refRange.isNotEmpty && isOutOfRange(val, refRange);
                      return DataCell(
                        SizedBox(
                          width: 60,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                            child: Text(val.isEmpty ? '-' : val, style: TextStyle(fontSize: 11, color: outOfRange ? Colors.red : null, fontWeight: outOfRange ? FontWeight.bold : FontWeight.normal)),
                          ),
                        ),
                      );
                    }),
                    DataCell(SizedBox(width: 90, child: Text(refRange.isEmpty ? '-' : refRange, style: const TextStyle(fontSize: 11)))),
                  ];
                  return DataRow(cells: cells);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class PatientHistoryDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> patient;
  final PatientHeaderCache? patientHeaderCache;

  const PatientHistoryDashboardScreen({
    Key? key,
    required this.patient,
    this.patientHeaderCache,
  }) : super(key: key);

  @override
  State<PatientHistoryDashboardScreen> createState() => _PatientHistoryDashboardScreenState();
}

class _PatientHistoryDashboardScreenState extends State<PatientHistoryDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PatientService _patientService = PatientService();
  final EncounterService _encounterService = EncounterService();
  final PregnancyService _pregnancyService = PregnancyService();
  final PatientHistoryRepository _historyRepo = PatientHistoryRepository(EncounterService(), AppDatabase.instance);
  StreamSubscription<List<PatientHistoryDay>>? _historySubscription;

  // Data storage (encounter-driven: same as ipd_file_screen)
  Map<String, dynamic>? _patientDetails;
  List<Map<String, dynamic>> _encounterDataList = [];
  List<dynamic> _allVitals = [];
  List<Map<String, dynamic>> _activeMedicines = [];
  List<dynamic>? _surgery;
  List<Map<String, dynamic>> _ipdAdmissions = [];
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
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 15));
  DateTime _toDate = DateTime.now();
  bool _hasLoadedOnce = false;

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

  /// IPD encounters from _encounterDataList (encounterType IPD) - kept for backwards compat
  List<Map<String, dynamic>> get _ipdEncounters {
    return _encounterDataList.where((e) {
      final t = (e['encounter'] as Map<String, dynamic>)['encounterType']?.toString() ?? (e['encounter'] as Map<String, dynamic>)['EncounterType']?.toString() ?? '';
      return t.toUpperCase() == 'IPD';
    }).toList();
  }

  /// Number of unique ward admissions (for IPD tile)
  int get _ipdAdmissionCount => _ipdAdmissions.map((a) => a['admissionId'] ?? a['admissionID'] ?? a['AdmissionID']).whereType<dynamic>().toSet().length;

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

  /// Lab pivot: package -> dates (desc) -> tests with results per date
  List<Map<String, dynamic>> get _labPivotData {
    final orders = _aggregatedLabOrders;
    final packageMap = <String, Map<String, dynamic>>{};
    for (final item in orders) {
      final pkgName = (item['packageName'] ?? 'Single Tests').toString();
      if (pkgName.isEmpty) continue;
      final key = pkgName;
      if (!packageMap.containsKey(key)) {
        packageMap[key] = {
          'packageName': pkgName,
          'dates': <String>[],
          'tests': <String, Map<String, dynamic>>{},
        };
      }
      final pkg = packageMap[key]!;
      final dateStr = (item['encounterDate'] ?? '').toString();
      if (dateStr.isNotEmpty && !(pkg['dates'] as List<String>).contains(dateStr)) {
        (pkg['dates'] as List<String>).add(dateStr);
      }
      final testName = (item['testName'] ?? item['test'] ?? 'N/A').toString();
      final resultVal = (item['resultValue'] ?? item['resultNumeric'] ?? item['result'] ?? '').toString();
      final refRange = (item['referenceRange'] ?? item['normalRange'] ?? '').toString();
      final tests = pkg['tests'] as Map<String, Map<String, dynamic>>;
      if (!tests.containsKey(testName)) {
        tests[testName] = {'referenceRange': refRange, 'resultsByDate': <String, String>{}};
      }
      final t = tests[testName]!;
      if (dateStr.isNotEmpty) {
        (t['resultsByDate'] as Map<String, String>)[dateStr] = resultVal;
      }
      if ((t['referenceRange'] as String).isEmpty && refRange.isNotEmpty) {
        t['referenceRange'] = refRange;
      }
    }
    final out = <Map<String, dynamic>>[];
    for (final pkg in packageMap.values) {
      final dates = (pkg['dates'] as List<String>).toList();
      dates.sort((a, b) {
        final pa = a.split('/');
        final pb = b.split('/');
        if (pa.length != 3 || pb.length != 3) return 0;
        final dy = int.tryParse(pa[2]);
        final dm = int.tryParse(pa[1]);
        final dd = int.tryParse(pa[0]);
        final by = int.tryParse(pb[2]);
        final bm = int.tryParse(pb[1]);
        final bd = int.tryParse(pb[0]);
        if (dy == null || dm == null || dd == null || by == null || bm == null || bd == null) return 0;
        final da = DateTime(dy, dm, dd);
        final db = DateTime(by, bm, bd);
        return db.compareTo(da);
      });
      pkg['dates'] = dates;
      final testsList = <Map<String, dynamic>>[];
      for (final e in (pkg['tests'] as Map<String, Map<String, dynamic>>).entries) {
        testsList.add({
          'testName': e.key,
          'referenceRange': e.value['referenceRange'] ?? '',
          'resultsByDate': Map<String, String>.from(e.value['resultsByDate'] ?? {}),
        });
      }
      testsList.sort((a, b) => (a['testName'] as String).compareTo(b['testName'] as String));
      pkg['tests'] = testsList;
      out.add(pkg);
    }
    out.sort((a, b) => (a['packageName'] as String).compareTo(b['packageName'] as String));
    return out;
  }

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    _toDate = DateTime(_toDate.year, _toDate.month, _toDate.day);
    _tabController = TabController(length: _showPregnancy ? 8 : 7, vsync: this);
    // No data load by default; user presses Show to load for selected date range
  }

  Widget _pill({required IconData icon, required String label, required String value, required Color color, bool compact = false}) {
    final text = value.isNotEmpty ? value : 'None';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 12, vertical: compact ? 4 : 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(compact ? 12 : 20),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: compact ? 12 : 14),
          SizedBox(width: compact ? 3 : 6),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: compact ? 10 : 12),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 80 : 200),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white, fontSize: compact ? 10 : 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
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

  static DateTime _encounterDateFrom(Map<String, dynamic> encounterData) {
    final enc = encounterData['encounter'] as Map<String, dynamic>? ?? {};
    final v = enc['encounterDate'] ?? enc['EncounterDate'] ?? enc['checkInTime'];
    if (v == null) return DateTime(1970);
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ?? DateTime(1970);
  }

  static List<Map<String, dynamic>> _encounterDataListFromDays(List<PatientHistoryDay> days) {
    final list = <Map<String, dynamic>>[];
    for (final day in days) {
      list.addAll(day.encounterDataList);
    }
    list.sort((a, b) => _encounterDateFrom(a).compareTo(_encounterDateFrom(b)));
    return list;
  }

  static List<dynamic> _allVitalsFromDays(List<PatientHistoryDay> days) {
    return days
        .expand((d) => d.encounterDataList)
        .expand((e) => (e['vitals'] as List<dynamic>? ?? []))
        .toList();
  }

  Future<void> _loadPatientHistory({DateTime? fromDate, DateTime? toDate}) async {
    final from = fromDate ?? _fromDate;
    final to = toDate ?? _toDate;
    setState(() {
      _loading = true;
      _error = null;
    });

    final patientId = widget.patient['patientId'] ?? widget.patient['PatientID'];
    if (patientId == null) {
      setState(() => _loading = false);
      return;
    }
    final parsedPatientId = patientId is int ? patientId : int.parse(patientId.toString());

    try {
      // Phase 1: patient-level data only (no date-range history from API)
      final cache = widget.patientHeaderCache;
      if (cache != null) {
        final results = await Future.wait([
          _patientService.getPatientDetails(patientId).catchError((e) {
            print('Error loading patient details: $e');
            return null;
          }),
          PharmacyService.getActivePatientMedicines(patientId: parsedPatientId).catchError((e) {
            print('Error loading active medicines: $e');
            return <Map<String, dynamic>>[];
          }),
          _pregnancyService.getPatientSurgeries(parsedPatientId).catchError((e) {
            print('Error loading surgeries: $e');
            return <Map<String, dynamic>>[];
          }),
          WardService.getPatientAdmissionHistory(parsedPatientId).catchError((e) {
            print('Error loading IPD admissions: $e');
            return <Map<String, dynamic>>[];
          }),
          _pregnancyService.getPregnancyRecordsByPatient(parsedPatientId).catchError((e) {
            print('Error loading pregnancy records: $e');
            return <Map<String, dynamic>>[];
          }),
          _pregnancyService.getActivePregnancy(parsedPatientId).catchError((e) {
            print('Error loading active pregnancy: $e');
            return null;
          }),
        ]);
        if (mounted) {
          setState(() {
            _patientDetails = results[0] as Map<String, dynamic>?;
            _activeMedicines = (results[1] as List<Map<String, dynamic>>?) ?? [];
            _surgery = results[2] as List<dynamic>?;
            _ipdAdmissions = (results[3] as List<Map<String, dynamic>>?) ?? [];
            _pregnancyRecords = results[4] as List<dynamic>?;
            _activePregnancy = results[5] as Map<String, dynamic>?;
            _chronicConditions = List<dynamic>.from(cache.chronicConditions);
            _riskFactors = List<dynamic>.from(cache.riskFactors);
            _allergies = List<dynamic>.from(cache.allergies);
          });
        }
      } else {
        final results = await Future.wait([
          _patientService.getPatientDetails(patientId).catchError((e) {
            print('Error loading patient details: $e');
            return null;
          }),
          PharmacyService.getActivePatientMedicines(patientId: parsedPatientId).catchError((e) {
            print('Error loading active medicines: $e');
            return <Map<String, dynamic>>[];
          }),
          _pregnancyService.getPatientSurgeries(parsedPatientId).catchError((e) {
            print('Error loading surgeries: $e');
            return <Map<String, dynamic>>[];
          }),
          WardService.getPatientAdmissionHistory(parsedPatientId).catchError((e) {
            print('Error loading IPD admissions: $e');
            return <Map<String, dynamic>>[];
          }),
          _pregnancyService.getPregnancyRecordsByPatient(parsedPatientId).catchError((e) {
            print('Error loading pregnancy records: $e');
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
        if (mounted) {
          setState(() {
            _patientDetails = results[0] as Map<String, dynamic>?;
            _activeMedicines = (results[1] as List<Map<String, dynamic>>?) ?? [];
            _surgery = results[2] as List<dynamic>?;
            _ipdAdmissions = (results[3] as List<Map<String, dynamic>>?) ?? [];
            _pregnancyRecords = results[4] as List<dynamic>?;
            _chronicConditions = results[5] as List<dynamic>?;
            _riskFactors = results[6] as List<dynamic>?;
            _allergies = results[7] as List<dynamic>?;
            _activePregnancy = results[8] as Map<String, dynamic>?;
          });
        }
      }

      // Phase 2: history from local DB stream (gap-fill sync runs in background)
      _historySubscription?.cancel();
      _historySubscription = _historyRepo.getHistory(parsedPatientId, from, to).listen(
        (days) {
          if (!mounted) return;
          setState(() {
            _encounterDataList = _encounterDataListFromDays(days);
            _allVitals = _allVitalsFromDays(days);
            _loading = false;
            _error = null;
            _hasLoadedOnce = true;
          });
        },
        onError: (e) {
          print('History stream error: $e');
          if (mounted) {
            setState(() {
              _error = 'Failed to load history. You can try again.';
              _loading = false;
            });
          }
        },
      );
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('History - ${widget.patient['fullName'] ?? widget.patient['FullName'] ?? 'Patient'}'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            _error != null
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
                              onPressed: () => _loadPatientHistory(fromDate: _fromDate, toDate: _toDate),
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
          
            // Loading overlay: blocks interaction and shows progress when fetching
            if (_loading) _buildLoadingOverlay(),
            // Overlay for section details
            if (_showOverlay) _buildSectionOverlay(),
          ],
        ),
      ),
      drawer: null,
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.35),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
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
                  'Fetching patient history...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(8),
                Text(
                  'Please wait',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Tablet-optimized layout for landscape 7-inch tablets
  Widget _buildTabletLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildPatientHeader(),
          const Gap(16),
          _buildMedicalRecordCards(),
        ],
      ),
    );
  }

  // Mobile layout: adapts to portrait and landscape (optimized for 5" screens)
  Widget _buildMobileLayout({required bool isPortrait, required bool isLandscape}) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final height = media.size.height;
    final isNarrow = width < 400 || height < 600; // 5" screen ~360x640
    final gap = isLandscape ? 10.0 : 16.0;
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildPatientHeader(isCompact: isLandscape || isNarrow, isNarrow: isNarrow && isPortrait),
          Gap(gap),
          _buildPregnancyStatusAlert(),
          Gap(gap),
          _buildMedicalRecordCards(),
        ],
      ),
    );
  }

  String _formatDateTimeForDisplay(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final normalized = DateTime(picked.year, picked.month, picked.day);
      setState(() {
        _fromDate = normalized;
        if (_fromDate.isAfter(_toDate)) _toDate = _fromDate;
      });
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _toDate = DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _onShowPressed() {
    if (_fromDate.isAfter(_toDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('From date must be less than or equal to To date')),
      );
      return;
    }
    _loadPatientHistory(fromDate: _fromDate, toDate: _toDate);
  }

  /// Date filter for use inside the patient header (top right). White/light panel.
  Widget _buildDateFilterInline({bool compact = false}) {
    final fz = compact ? 11.0 : 13.0;
    final pad = compact ? 6.0 : 8.0;
    final row = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today_outlined, size: compact ? 14 : 16, color: Colors.grey.shade700),
          SizedBox(width: compact ? 4 : 6),
          Text('From:', style: TextStyle(fontSize: fz, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          SizedBox(width: compact ? 2 : 4),
          InkWell(
            onTap: _pickFromDate,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: compact ? 4 : 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_formatDateTimeForDisplay(_fromDate), style: TextStyle(fontSize: fz, color: Colors.grey.shade800)),
            ),
          ),
          SizedBox(width: compact ? 6 : 10),
          Text('To:', style: TextStyle(fontSize: fz, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          SizedBox(width: compact ? 2 : 4),
          InkWell(
            onTap: _pickToDate,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: compact ? 4 : 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_formatDateTimeForDisplay(_toDate), style: TextStyle(fontSize: fz, color: Colors.grey.shade800)),
            ),
          ),
          SizedBox(width: compact ? 6 : 10),
          ElevatedButton.icon(
            onPressed: _loading ? null : _onShowPressed,
            icon: _loading
                ? SizedBox(
                    width: compact ? 14 : 18,
                    height: compact ? 14 : 18,
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(Icons.search, size: compact ? 16 : 20),
            label: Text(_loading ? '...' : 'Show', style: TextStyle(fontSize: compact ? 11 : 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B6B9E),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF5B6B9E).withOpacity(0.6),
              disabledForegroundColor: Colors.white70,
              padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: compact ? 6 : 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
          ),
        ],
      );
    return Container(
      padding: EdgeInsets.all(compact ? 6 : 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
      ),
      child: compact
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: row,
            )
          : row,
    );
  }

  Widget _buildPatientHeader({bool isCompact = false, bool isNarrow = false}) {
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
      _activeMedicines
          .map(
            (m) => (m['medicineName'] ?? m['MedicineName'] ?? m['medication'] ?? m['medicationName'] ?? m['name'] ?? '')
                .toString(),
          )
          .cast<String>(),
      max: 6,
    );
    final risksText = joinWithComma(
      (_riskFactors ?? [])
          .where((r) => (r['isPresent'] ?? r['is_present'] ?? true) == true)
          .map((r) => (r['riskFactorName'] ?? '').toString())
          .cast<String>(),
      max: 8,
    );

    final vPad = isCompact ? 8.0 : 24.0;
    final hPad = isCompact ? 12.0 : 24.0;
    final pills = [
      _pill(icon: Icons.warning_amber_rounded, label: 'Allergies', value: allergiesText, color: Colors.orangeAccent, compact: isCompact),
      _pill(icon: Icons.healing, label: 'Chronic', value: chronicText, color: Colors.lightBlueAccent, compact: isCompact),
      _pill(icon: Icons.local_pharmacy, label: 'Current Meds', value: medsText, color: Colors.pinkAccent, compact: isCompact),
      _pill(icon: Icons.report_problem, label: 'Risk Factors', value: risksText, color: Colors.redAccent, compact: isCompact),
    ];
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
        borderRadius: BorderRadius.circular(isCompact ? 12 : 20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: isCompact
          ? isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'MRN: $mrn • $gender $age • $blood',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.9),
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
                    const Gap(8),
                    SizedBox(
                      width: double.infinity,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildDateFilterInline(compact: true),
                      ),
                    ),
                    const Gap(8),
                    Wrap(spacing: 4, runSpacing: 4, children: pills),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.person_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'MRN: $mrn • $gender $age • $blood',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              alignment: WrapAlignment.end,
                              children: pills,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildDateFilterInline(compact: true),
                  ],
                )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (_, constraints) {
                    final useScroll = constraints.maxWidth < 450;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                              ),
                              const Gap(20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const Gap(6),
                                    Text(
                                      'MRN: $mrn • $gender $age • $blood',
                                      style: TextStyle(
                                        fontSize: 13,
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
                        ),
                        if (useScroll)
                          Flexible(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: _buildDateFilterInline(compact: true),
                            ),
                          )
                        else
                          _buildDateFilterInline(compact: false),
                      ],
                    );
                  },
                ),
                const Gap(20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: pills,
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
            getItemText: (item) =>
                '${item['medicineName'] ?? item['MedicineName'] ?? item['medication'] ?? item['medicationName'] ?? item['name'] ?? 'Unknown'} ${item['dosage'] ?? item['strength'] ?? ''}',
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
      _buildAestheticSectionCard('IPD', Icons.local_hospital_outlined, const Color(0xFF38B2AC), _ipdAdmissionCount, 'ipd'),
      _buildAestheticSectionCard('Labs', Icons.biotech_outlined, const Color(0xFFDD6B20), _labPackageCount, 'labs'),
      _buildAestheticSectionCard('Radiology', Icons.medical_services, const Color(0xFF0BC5EA), _aggregatedRadiologyOrders.length, 'radiology'),
      _buildAestheticSectionCard('Surgery', Icons.content_cut, const Color(0xFFE53E3E), _surgery?.length ?? 0, 'surgery'),
      _buildAestheticSectionCard('Meds', Icons.medication, const Color(0xFF38A169), _activeMedicines.length, 'medications'),
      if (_showPregnancy) _buildAestheticSectionCard('Pregnancy', Icons.pregnant_woman, const Color(0xFFD53F8C), _pregnancyRecords?.length ?? 0, 'pregnancy'),
    ];

    Widget cardsContent;
    if (isTablet) {
      cardsContent = GridView.count(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.5,
        children: sectionCards,
      );
    } else if (isMobileLandscape) {
      // Mobile landscape: single horizontal row of small tiles, scrollable
      cardsContent = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: sectionCards,
        ),
      );
    } else {
      // Mobile portrait: 4-column grid, aspect ratio adapts for 5" screens to prevent overflow
      final screenW = media.size.width;
      final screenH = media.size.height;
      final isSmallScreen = screenW < 400 || screenH < 640;
      final aspectRatio = isSmallScreen ? 1.0 : 1.25; // taller cells on 5" to fit content
      cardsContent = GridView.count(
        crossAxisCount: 4,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: aspectRatio,
        children: sectionCards,
      );
    }

    final isMobile = !isTablet;
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
            padding: EdgeInsets.fromLTRB(
              isMobile ? (isMobileLandscape ? 10 : 12) : 20,
              isMobile ? (isMobileLandscape ? 8 : 10) : 16,
              isMobile ? (isMobileLandscape ? 10 : 12) : 20,
              isMobile ? (isMobileLandscape ? 6 : 8) : 12,
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? (isMobileLandscape ? 6 : 8) : 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B6B9E).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(isMobileLandscape ? 8 : 12),
                  ),
                  child: Icon(Icons.folder_rounded, color: const Color(0xFF5B6B9E), size: isMobile ? (isMobileLandscape ? 18 : 20) : 24),
                ),
                SizedBox(width: isMobile ? 10 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medical Records Overview',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: isMobile ? 16 : 18,
                          color: Colors.grey.shade800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        '${_allVitals.length + _opdEncounters.length + _ipdAdmissionCount + _labPackageCount + _aggregatedRadiologyOrders.length + (_surgery?.length ?? 0) + _activeMedicines.length + (_showPregnancy ? (_pregnancyRecords?.length ?? 0) : 0)} records',
                        style: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
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
            padding: EdgeInsets.fromLTRB(isMobileLandscape ? 6 : (isMobile ? 8 : 12), 4, isMobileLandscape ? 6 : (isMobile ? 8 : 12), isMobile ? (isMobileLandscape ? 8 : 10) : 16),
            child: cardsContent,
          ),
        ],
      ),
    );
  }

  Widget _buildAestheticSectionCard(String title, IconData icon, Color color, int count, String sectionKey) {
    final media = MediaQuery.of(context);
    final isTablet = media.size.width > 600;
    final isMobileLandscape = !isTablet && media.orientation == Orientation.landscape;
    final isSmallScreen = media.size.width < 400 || media.size.height < 640;
    return Semantics(
      label: '$title, $count records',
      button: true,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isTablet ? 6 : 2, vertical: isTablet ? 6 : 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showSectionOverlay(sectionKey),
            borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
            splashColor: color.withOpacity(0.15),
            highlightColor: color.withOpacity(0.08),
            child: Container(
              constraints: isTablet
                  ? null
                  : BoxConstraints(
                      minWidth: isMobileLandscape ? 56 : 0,
                      maxWidth: isMobileLandscape ? 56 : double.infinity,
                      minHeight: 44,
                    ),
              padding: EdgeInsets.all(isTablet ? 18 : (isSmallScreen ? 4 : 6)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                border: Border.all(color: color.withOpacity(0.22), width: isTablet ? 1.2 : 1.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isTablet
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: color, size: 24),
                        ),
                        const Gap(8),
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Gap(4),
                        Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 18,
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 4 : 6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: isSmallScreen ? 16 : 18),
                        ),
                        Gap(isSmallScreen ? 1 : 2),
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isSmallScreen ? 8 : 9,
                            color: Colors.grey.shade800,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$count',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 9 : 10,
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
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
    final double sectionHeight;
    if (isTablet) {
      sectionHeight = height * 0.6;
    } else if (isMobileLandscape) {
      sectionHeight = height * 0.55;
    } else {
      sectionHeight = (height * 0.48).clamp(280.0, 500.0);
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
    return _buildVitalsPivotTab(_vitalsSearchController, _filterVitals);
  }

  Widget _buildVitalsPivotTab(TextEditingController? searchController, List<dynamic> Function(String)? filterFunction) {
    final filtered = (searchController != null && searchController.text.isNotEmpty && filterFunction != null)
        ? filterFunction(searchController.text) : _allVitals;
    final media = MediaQuery.of(context);
    final isMobileLandscape = media.size.width < 600 && media.orientation == Orientation.landscape;
    if (filtered.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text('No vitals data available', style: TextStyle(fontSize: 14, color: Colors.grey.shade600))));
    }
    return Container(
      color: const Color(0xFFF1F5F9),
      padding: EdgeInsets.all(isMobileLandscape ? 10 : 16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: _vitalsSearchController,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
              decoration: InputDecoration(
                hintText: 'Search vitals by date, BP, HR, temperature, or location...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search_rounded, size: 22, color: Colors.grey.shade500),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                filled: true, fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 2))]),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(child: _buildVitalsPivotDataTable(filtered)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataTable _buildVitalsPivotDataTable(List<dynamic> vitals) {
    final media = MediaQuery.of(context);
    final isMobileLandscape = media.size.width < 600 && media.orientation == Orientation.landscape;

    String _bp(dynamic v) {
      final s = v['bpSystolic'] != null ? (v['bpSystolic'] is num ? v['bpSystolic'].toInt() : int.tryParse(v['bpSystolic'].toString())) : null;
      final d = v['bpDiastolic'] != null ? (v['bpDiastolic'] is num ? v['bpDiastolic'].toInt() : int.tryParse(v['bpDiastolic'].toString())) : null;
      return (s != null && d != null) ? '$s/$d' : '-';
    }
    String _pulse(dynamic v) {
      final p = v['pulse'] != null ? (v['pulse'] is num ? v['pulse'].toInt() : int.tryParse(v['pulse'].toString())) : null;
      return p != null ? p.toString() : '-';
    }
    String _temp(dynamic v) {
      final tc = v['temperature'] != null ? (v['temperature'] is num ? v['temperature'].toDouble() : double.tryParse(v['temperature'].toString())) : null;
      final tf = tc != null ? ((tc * 9 / 5) + 32).toStringAsFixed(1) : null;
      return tf != null ? '${tf}°F' : '-';
    }
    String _rr(dynamic v) {
      final r = v['respiratoryRate'] != null ? (v['respiratoryRate'] is num ? v['respiratoryRate'].toInt() : int.tryParse(v['respiratoryRate'].toString())) : null;
      return r != null ? r.toString() : '-';
    }
    String _spo2(dynamic v) {
      final o = v['oxygenSaturation'] != null ? (v['oxygenSaturation'] is num ? v['oxygenSaturation'].toDouble() : double.tryParse(v['oxygenSaturation'].toString())) : null;
      return o != null ? o.toStringAsFixed(0) : '-';
    }
    String _weight(dynamic v) {
      final w = v['weight'] != null ? (v['weight'] is num ? v['weight'].toDouble() : double.tryParse(v['weight'].toString())) : null;
      return w != null ? w.toString() : '-';
    }
    String _bmi(dynamic v) {
      final b = v['bmi'] != null ? (v['bmi'] is num ? v['bmi'].toDouble() : double.tryParse(v['bmi'].toString())) : null;
      return b != null ? b.toStringAsFixed(1) : '-';
    }
    String _bsr(dynamic v) {
      final b = v['bsr'] != null ? (v['bsr'] is num ? v['bsr'].toDouble() : double.tryParse(v['bsr'].toString())) : null;
      return b != null ? b.toString() : '-';
    }
    String _loc(dynamic v) => (v['position'] ?? v['location'] ?? '').toString().trim().isEmpty ? '-' : (v['position'] ?? v['location'] ?? '').toString();

    // Sort by recordedDate descending (most recent on top)
    final sorted = List<dynamic>.from(vitals);
    sorted.sort((a, b) {
      final da = DateTime.tryParse((a['recordedDate'] ?? '').toString());
      final db = DateTime.tryParse((b['recordedDate'] ?? '').toString());
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    const colHeaders = ['Date/Time', 'BP', 'HR', 'Temp', 'RR', 'SpO2', 'Weight', 'BMI', 'BSR', 'Location'];
    return DataTable(
      columnSpacing: isMobileLandscape ? 12 : 16,
      horizontalMargin: isMobileLandscape ? 10 : 16,
      headingRowHeight: 48,
      dataRowMinHeight: 42,
      headingRowColor: MaterialStateProperty.all(const Color(0xFFF1F5F9)),
      columns: colHeaders.map((h) => DataColumn(label: Text(h, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)))).toList(),
      rows: sorted.asMap().entries.map((entry) {
        final idx = entry.key;
        final v = entry.value;
        final rd = v['recordedDate'];
        final dt = rd != null ? DateTime.tryParse(rd.toString()) : null;
        final dateStr = _formatDateDDMMYYYY(rd);
        final timeStr = dt != null ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}' : '';
        final dateTimeStr = timeStr.isNotEmpty ? '$dateStr $timeStr' : dateStr;
        final cells = [dateTimeStr, _bp(v), _pulse(v), _temp(v), _rr(v), _spo2(v), _weight(v), _bmi(v), _bsr(v), _loc(v)];
        return DataRow(
          color: MaterialStateProperty.all(idx.isEven ? Colors.white : const Color(0xFFFAFBFC)),
          cells: cells.map((c) => DataCell(
            Container(
              constraints: const BoxConstraints(minWidth: 72, maxWidth: 120),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Text(c.isEmpty ? '-' : c, style: TextStyle(fontSize: 12, color: Colors.grey.shade800), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          )).toList(),
        );
      }).toList(),
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
        DataColumn(label: Text('Print', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      ],
      data: _opdEncounters,
      filterFunction: _filterOPD,
      noDataMessage: 'No OPD data available',
      trailingCellBuilder: _buildEncounterPrintButton,
    );
  }

  Widget _buildIPDTab() {
    return _buildGenericTab(
      title: 'IPD Admissions',
      icon: Icons.local_hospital_outlined,
      heroColor: Colors.teal,
      searchController: _ipdSearchController,
      searchHint: 'Search by surgery, surgeon, ward, discharge...',
      columns: const [
        DataColumn(label: Text('Admission Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Ward', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Surgery Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Surgery Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Surgery Outcome', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Surgeon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Anesthesia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Anesthesia Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Discharge Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Discharge Outcome', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Print', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      ],
      data: _ipdAdmissions,
      filterFunction: _filterIPD,
      noDataMessage: 'No IPD admissions',
      trailingCellBuilder: _buildIPDPrintButton,
    );
  }

  Widget _buildIPDPrintButton(dynamic item) {
    final a = item as Map<String, dynamic>;
    final admId = a['admissionId'] ?? a['admissionID'] ?? a['AdmissionID'];
    if (admId == null) return const SizedBox.shrink();
    final id = admId is int ? admId : int.tryParse(admId.toString());
    if (id == null) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.print),
      tooltip: 'Print discharge slip',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DischargeSlipPrintScreen(
              patient: widget.patient,
              admissionId: id,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabsTab() {
    return _buildLabsPivotContent();
  }

  Widget _buildLabsPivotContent() {
    final pivotData = _labPivotData;
    return Container(
      color: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.all(16),
      child: _LabsPivotWidget(pivotData: pivotData, searchController: _labsSearchController),
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
        DataColumn(label: Text('Print', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      ],
      data: _aggregatedRadiologyOrders,
      filterFunction: _filterRadiology,
      noDataMessage: 'No radiology data available',
      trailingCellBuilder: _buildRadiologyPrintButton,
    );
  }

  Widget _buildRadiologyPrintButton(dynamic item) {
    final r = item as Map<String, dynamic>;
    final findings = (r['finalFindings'] ?? r['findings'] ?? r['preliminaryFindings'] ?? '').toString().trim();
    final impression = (r['impression'] ?? '').toString().trim();
    if (findings.isEmpty && impression.isEmpty) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.print),
      tooltip: 'Print radiology report',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RadiologyReportPrintScreen(
              patient: widget.patient,
              radiologyOrder: r,
            ),
          ),
        );
      },
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
      searchHint: 'Search by LMP, EDD, status, outcome, delivery type, husband...',
      columns: const [
        DataColumn(label: Text('LMP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('EDD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Gravida', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Para', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Term', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('PreTerm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Living', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Boys', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Girls', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Outcome', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Delivery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('High Risk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        DataColumn(label: Text('Husband', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      ],
      data: _pregnancyRecords,
      filterFunction: _filterPregnancy,
      noDataMessage: 'No pregnancy records available',
    );
  }

  Widget _buildEncounterPrintButton(dynamic item) {
    final enc = (item as Map<String, dynamic>)['encounter'] as Map<String, dynamic>? ?? {};
    final encounterIdRaw = enc['encounterId'] ?? enc['EncounterID'] ?? enc['encounterID'];
    final encounterId = encounterIdRaw is int ? encounterIdRaw : int.tryParse(encounterIdRaw?.toString() ?? '');
    if (encounterId == null) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.print),
      tooltip: 'Print consultation summary',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConsultationSummaryScreen(
              patient: widget.patient,
              encounterId: encounterId,
            ),
          ),
        );
      },
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
    Widget Function(dynamic item)? trailingCellBuilder,
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
                    rows: _buildDataRows(data, filterFunction, searchController, noDataMessage, title, trailingCellBuilder),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DataRow> _buildDataRows(List<dynamic>? data, List<dynamic> Function(String)? filterFunction, TextEditingController? searchController, String? noDataMessage, String? title, [Widget Function(dynamic item)? trailingCellBuilder]) {
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
      final cells = rowData.asMap().entries.map((entry) {
        int idx = entry.key;
        String cell = entry.value;
        Color cellColor = _getCellColor(cell, title, idx);
        final isResultCell = title == 'Lab Results' && idx == 3;
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
      }).toList();
      if (trailingCellBuilder != null) {
        cells.add(DataCell(trailingCellBuilder(item)));
      }
      return DataRow(
        color: MaterialStateProperty.all(
          index.isEven ? Colors.white : const Color(0xFFFAFBFC),
        ),
        cells: cells,
      );
    }).toList();
  }

  /// True if result value is outside the reference range (e.g. "4.5-11" or "12-16").
  bool _isResultOutOfReferenceRange(String resultStr, String refRangeStr) => _isLabResultOutOfRef(resultStr, refRangeStr);

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
        return _encounterRowData(Map<String, dynamic>.from(item as Map));
      case 'IPD Admissions':
        final a = item as Map<String, dynamic>;
        return [
          _formatDateTimeDDMMYYYYHHmm(a['admissionDatetime']),
          (a['wardName'] ?? '').toString(),
          (a['surgeryName'] ?? '').toString(),
          _formatDateTimeDDMMYYYYHHmm(a['surgeryDate']),
          (a['surgeryOutcome'] ?? '').toString(),
          (a['surgeonName'] ?? '').toString(),
          (a['isAnesthesiaGiven'] == true ? 'Yes' : 'No'),
          (a['anesthesiaType'] ?? '').toString(),
          _formatDateTimeDDMMYYYYHHmm(a['dischargeDatetime']),
          (a['dischargeOutcome'] ?? '').toString(),
        ];
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
        final lmp = item['lmpDate'] ?? item['LMPDate'] ?? item['lmp'];
        final edd = item['edDate'] ?? item['EDDate'] ?? item['edd'];
        final status = item['pregnancy_status'] ?? item['Pregnancy_status'] ?? item['status'] ?? '';
        final gravida = item['gravida'] ?? item['Gravida'];
        final para = item['para'] ?? item['Para'];
        final term = item['term'] ?? item['Term'];
        final preTerm = item['preTerm'] ?? item['PreTerm'];
        final living = item['livingChildren'] ?? item['LivingChildren'];
        final boys = item['numberofBoys'] ?? item['NumberofBoys'];
        final girls = item['numberofGirls'] ?? item['NumberofGirls'];
        final outcome = item['pregnancyOutcome'] ?? item['PregnancyOutcome'] ?? item['outcome'] ?? '';
        final delDate = item['actualDeliveryDate'] ?? item['ActualDeliveryDate'];
        final delType = item['deliveryType'] ?? item['DeliveryType'] ?? '';
        final highRisk = item['highRisk'] ?? item['HighRisk'];
        final husband = item['husbandName'] ?? item['HusbandName'] ?? '';
        return [
          _formatDateDDMMYYYY(lmp),
          _formatDateDDMMYYYY(edd),
          status.toString(),
          (gravida ?? '-').toString(),
          (para ?? '-').toString(),
          (term ?? '-').toString(),
          (preTerm ?? '-').toString(),
          (living ?? '-').toString(),
          (boys ?? '-').toString(),
          (girls ?? '-').toString(),
          outcome.toString(),
          delDate != null ? '${_formatDateDDMMYYYY(delDate)}${delType.toString().isNotEmpty ? ' (${delType})' : ''}' : (delType.toString().isNotEmpty ? delType : '-'),
          highRisk == true ? 'Yes' : (highRisk == false ? 'No' : '-'),
          husband.toString(),
        ];
      case 'Medications':
        return [
          _formatDateDDMMYYYY(
            item['startDate'] ??
                item['StartDate'] ??
                item['start_date'] ??
                item['orderDate'] ??
                item['OrderDate'],
          ),
          (item['salt'] ?? item['Salt'] ?? item['saltName'] ?? item['SaltName'] ?? '').toString(),
          (item['medicineName'] ??
                  item['MedicineName'] ??
                  item['medication'] ??
                  item['medicationName'] ??
                  item['name'] ??
                  '')
              .toString(),
          (item['dosage'] ??
                  item['Dosage'] ??
                  item['strength'] ??
                  item['MedicineStrength'] ??
                  item['dose'] ??
                  '')
              .toString(),
          (item['duration'] ??
                  item['Duration'] ??
                  item['frequency'] ??
                  item['FrequencyName'] ??
                  item['Frequency'] ??
                  '')
              .toString(),
          (item['status'] ?? item['Status'] ?? 'Active').toString(),
          (item['prescriber'] ??
                  item['Prescriber'] ??
                  item['doctorName'] ??
                  item['prescribedBy'] ??
                  '')
              .toString(),
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
        return 11; // Admission Date, Ward, Surgery Name, Surgery Date, Surgery Outcome, Surgeon, Anesthesia, Anesthesia Type, Discharge Date, Outcome, Print
      case 'Radiology':
        return 7; // Date, Procedure, Indication, Findings, Impression, Radiologist, Print
      case 'Previous Surgeries':
        return 5;
      case 'Pregnancy History':
        return 14;
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

  String _formatDateTimeDDMMYYYYHHmm(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return '';
    final dt = DateTime.tryParse(value.toString());
    if (dt == null) return value.toString();
    final d = _formatDateDDMMYYYY(value);
    if (dt.hour == 0 && dt.minute == 0) return d;
    return '$d ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
      return (med['medicineName'] ??
                  med['MedicineName'] ??
                  med['medication'] ??
                  med['medicationName'] ??
                  med['name'] ??
                  '')
              .toString()
              .toLowerCase()
              .contains(searchText) ||
             (med['salt'] ??
                     med['Salt'] ??
                     med['saltName'] ??
                     med['SaltName'] ??
                     '')
                 .toString()
                 .toLowerCase()
                 .contains(searchText) ||
             (med['dosage'] ??
                     med['Dosage'] ??
                     med['strength'] ??
                     med['MedicineStrength'] ??
                     med['dose'] ??
                     '')
                 .toString()
                 .toLowerCase()
                 .contains(searchText) ||
             (med['duration'] ??
                     med['Duration'] ??
                     med['frequency'] ??
                     med['FrequencyName'] ??
                     med['Frequency'] ??
                     '')
                 .toString()
                 .toLowerCase()
                 .contains(searchText) ||
             (med['status'] ?? med['Status'] ?? '')
                 .toString()
                 .toLowerCase()
                 .contains(searchText) ||
             (med['prescriber'] ??
                     med['Prescriber'] ??
                     med['doctorName'] ??
                     med['prescribedBy'] ??
                     '')
                 .toString()
                 .toLowerCase()
                 .contains(searchText) ||
             (med['startDate'] ??
                     med['StartDate'] ??
                     med['orderDate'] ??
                     med['OrderDate'] ??
                     '')
                 .toString()
                 .toLowerCase()
                 .contains(searchText);
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
    if (query.isEmpty) return _ipdAdmissions;
    final searchText = query.toLowerCase();
    return _ipdAdmissions.where((record) {
      final a = record as Map<String, dynamic>;
      return (a['surgeryName'] ?? '').toString().toLowerCase().contains(searchText) ||
          (a['surgeryOutcome'] ?? '').toString().toLowerCase().contains(searchText) ||
          (a['surgeonName'] ?? '').toString().toLowerCase().contains(searchText) ||
          (a['wardName'] ?? '').toString().toLowerCase().contains(searchText) ||
          (a['anesthesiaType'] ?? '').toString().toLowerCase().contains(searchText) ||
          (a['dischargeOutcome'] ?? '').toString().toLowerCase().contains(searchText) ||
          _formatDateDDMMYYYY(a['admissionDatetime']).toLowerCase().contains(searchText) ||
          _formatDateDDMMYYYY(a['surgeryDate']).toLowerCase().contains(searchText) ||
          _formatDateDDMMYYYY(a['dischargeDatetime']).toLowerCase().contains(searchText);
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
    final q = query.toLowerCase();
    return (_pregnancyRecords ?? []).where((record) {
      final r = record is Map<String, dynamic> ? record : {};
      final status = (r['pregnancy_status'] ?? r['Pregnancy_status'] ?? '').toString().toLowerCase();
      final outcome = (r['pregnancyOutcome'] ?? r['PregnancyOutcome'] ?? '').toString().toLowerCase();
      final delType = (r['deliveryType'] ?? r['DeliveryType'] ?? '').toString().toLowerCase();
      final husband = (r['husbandName'] ?? r['HusbandName'] ?? '').toString().toLowerCase();
      final risk = (r['riskFactors'] ?? r['RiskFactors'] ?? '').toString().toLowerCase();
      final lmp = _formatDateDDMMYYYY(r['lmpDate'] ?? r['LMPDate']).toLowerCase();
      final edd = _formatDateDDMMYYYY(r['edDate'] ?? r['EDDate']).toLowerCase();
      return status.contains(q) || outcome.contains(q) || delType.contains(q) || husband.contains(q) || risk.contains(q) || lmp.contains(q) || edd.contains(q);
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
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: Builder(
                    builder: (ctx) {
                      final maxW = MediaQuery.of(ctx).size.width - 48;
                      if (_selectedSection == 'labs') {
                        return SingleChildScrollView(
                          primary: false,
                          child: Container(
                            width: maxW,
                            margin: EdgeInsets.all(isMobile ? 12 : 24),
                            child: _buildSectionContent(_selectedSection!),
                          ),
                        );
                      }
                      return SingleChildScrollView(
                        primary: false,
                        child: SingleChildScrollView(
                          primary: false,
                          scrollDirection: Axis.horizontal,
                          child: Container(
                            margin: EdgeInsets.all(isMobile ? 12 : 24),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: maxW),
                              child: _buildSectionContent(_selectedSection!),
                            ),
                          ),
                        ),
                      );
                    },
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
          child: _buildVitalsPivotDataTable(_allVitals),
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
        child: _LabsPivotWidget(
          pivotData: _labPivotData,
          searchController: _labsSearchController,
          shrinkWrap: true,
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
              final startDate = _formatDateDDMMYYYY(
                m['startDate'] ??
                    m['StartDate'] ??
                    m['start_date'] ??
                    m['orderDate'] ??
                    m['OrderDate'],
              );
              final salt = (m['salt'] ??
                      m['Salt'] ??
                      m['saltName'] ??
                      m['SaltName'] ??
                      '')
                  .toString();
              final medName = (m['medicineName'] ??
                      m['MedicineName'] ??
                      m['medication'] ??
                      m['Medication'] ??
                      m['medicationName'] ??
                      m['name'] ??
                      '')
                  .toString();
              final doseAmt = (m['dosage'] ??
                      m['Dosage'] ??
                      m['strength'] ??
                      m['MedicineStrength'] ??
                      m['dose'] ??
                      '')
                  .toString();
              final doseUnit =
                  (m['strength_unit'] ?? m['dosageUnit'] ?? m['DosageUnit'] ?? '').toString();
              final dosage = [doseAmt, doseUnit].where((e) => e.toString().trim().isNotEmpty).join(' ');
              final duration = (m['duration'] ??
                      m['Duration'] ??
                      m['frequency'] ??
                      m['FrequencyName'] ??
                      m['Frequency'] ??
                      '')
                  .toString();
              final status = (m['status'] ?? m['Status'] ?? 'Active').toString();
              final prescriber = (m['prescriber'] ??
                      m['Prescriber'] ??
                      m['doctorName'] ??
                      m['prescribedBy'] ??
                      '')
                  .toString();

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
              DataColumn(label: Text('Print', style: TextStyle(fontWeight: FontWeight.bold))),
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
              final dataCells = cells.map((cell) => DataCell(
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
              )).toList();
              if (findings.trim().isNotEmpty || impression.trim().isNotEmpty) {
                dataCells.add(DataCell(_buildRadiologyPrintButton(rad)));
              } else {
                dataCells.add(const DataCell(SizedBox.shrink()));
              }
              return DataRow(cells: dataCells);
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
              DataColumn(label: Text('Print', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _opdEncounters.map((e) {
              final enc = e as Map<String, dynamic>;
              final cells = _encounterRowData(Map<String, dynamic>.from(enc));
              final dataCells = cells.map((cell) => DataCell(Container(
                constraints: const BoxConstraints(minWidth: 100, maxWidth: 220),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Text(cell.isEmpty ? '-' : cell, style: const TextStyle(fontSize: 12, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
              ))).toList();
              dataCells.add(DataCell(_buildEncounterPrintButton(enc)));
              return DataRow(cells: dataCells);
            }).toList(),
          ),
        ),
      );
    }
    if (section == 'ipd') {
      if (_ipdAdmissions.isEmpty) {
        return Center(child: Text('No IPD admissions found', style: Theme.of(context).textTheme.bodyLarge));
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
              DataColumn(label: Text('Admission Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Ward', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Surgery Name', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Surgery Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Surgery Outcome', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Surgeon', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Anesthesia', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Anesthesia Type', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Discharge Date', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Discharge Outcome', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Print', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _ipdAdmissions.map((a) {
              final admissionDate = _formatDateTimeDDMMYYYYHHmm(a['admissionDatetime']);
              final wardName = (a['wardName'] ?? '').toString();
              final surgeryName = (a['surgeryName'] ?? '').toString();
              final surgeryDate = _formatDateTimeDDMMYYYYHHmm(a['surgeryDate']);
              final surgeryOutcome = (a['surgeryOutcome'] ?? '').toString();
              final surgeonName = (a['surgeonName'] ?? '').toString();
              final anesthesia = (a['isAnesthesiaGiven'] == true ? 'Yes' : 'No');
              final anesthesiaType = (a['anesthesiaType'] ?? '').toString();
              final dischargeDate = _formatDateTimeDDMMYYYYHHmm(a['dischargeDatetime']);
              final dischargeOutcome = (a['dischargeOutcome'] ?? '').toString();
              final cells = [admissionDate, wardName, surgeryName, surgeryDate, surgeryOutcome, surgeonName, anesthesia, anesthesiaType, dischargeDate, dischargeOutcome];
              final dataCells = cells.map((cell) => DataCell(Container(
                constraints: const BoxConstraints(minWidth: 100, maxWidth: 220),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Text(cell.isEmpty ? '-' : cell, style: const TextStyle(fontSize: 12, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
              ))).toList();
              dataCells.add(DataCell(_buildIPDPrintButton(a)));
              return DataRow(cells: dataCells);
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

    if (section == 'pregnancy') {
      final records = _pregnancyRecords ?? [];
      if (records.isEmpty) {
        return Center(
          child: Text(
            'No pregnancy records found',
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
              DataColumn(label: Text('LMP', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('EDD', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Gravida', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Para', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Term', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('PreTerm', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Living', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Boys', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Girls', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Outcome', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Delivery', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('High Risk', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Husband', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: records.map((item) {
              final cells = _getRowDataForTab(item, 'Pregnancy History');
              return DataRow(
                cells: cells.map((cell) => DataCell(
                  Container(
                    constraints: const BoxConstraints(minWidth: 90, maxWidth: 180),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: Text(
                      cell.isEmpty ? '-' : cell,
                      style: const TextStyle(fontSize: 12, height: 1.2),
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
        return _ipdAdmissionCount;
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
