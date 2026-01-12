import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/emr_api_client.dart';

class PatientFileScreen extends StatefulWidget {
  final Map<String, dynamic> patient;

  const PatientFileScreen({
    Key? key,
    required this.patient,
  }) : super(key: key);

  @override
  State<PatientFileScreen> createState() => _PatientFileScreenState();
}

class _PatientFileScreenState extends State<PatientFileScreen> {
  EmrApiClient? _api;
  
  List<dynamic> _opd = [];
  List<dynamic> _ipd = [];
  List<dynamic> _vitals = [];
  List<dynamic> _labs = [];
  List<dynamic> _radiology = [];
  List<dynamic> _surgery = [];
  List<dynamic> _medications = [];
  List<Map<String, dynamic>> _combinedTimeline = [];
  
  bool _loading = false;
  bool _loadingDetails = false;
  String? _error;

  // Date filters
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeApi();
  }

  Future<void> _initializeApi() async {
    try {
      _api = EmrApiClient();
    } catch (e) {
      print('❌ Failed to initialize API client: $e');
    }
  }

  String get _patientMrn {
    return (widget.patient['mrn'] ?? 
            widget.patient['MRN'] ?? 
            widget.patient['Mrn'] ?? 
            '').toString();
  }

  int? get _patientId {
    final id = widget.patient['patientId'] ?? 
               widget.patient['PatientID'] ?? 
               widget.patient['PatientId'];
    if (id == null) return null;
    return id is int ? id : int.tryParse(id.toString());
  }

  Future<void> _loadDataWithFilters() async {
    if (_api == null) {
      await _initializeApi();
      if (_api == null) {
        setState(() {
          _error = 'Failed to initialize API';
          _dataLoaded = true;
        });
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
      _dataLoaded = false;
      _opd = [];
      _ipd = [];
      _vitals = [];
      _labs = [];
      _radiology = [];
      _surgery = [];
      _medications = [];
      _combinedTimeline = [];
    });

    try {
      final mrn = _patientMrn;
      if (mrn.isEmpty) {
        throw Exception('Patient MRN is required');
      }

      // Load all data in parallel
      final results = await Future.wait([
        _api!.fetchOPD(mrn).catchError((e) => <dynamic>[]),
        _api!.fetchIPD(mrn).catchError((e) => <dynamic>[]),
        _api!.fetchVitals(mrn).catchError((e) => <dynamic>[]),
        _api!.fetchLabs(mrn).catchError((e) => <dynamic>[]),
        _api!.fetchRadiology(mrn).catchError((e) => <dynamic>[]),
        _api!.fetchSurgery(mrn).catchError((e) => <dynamic>[]),
        _api!.fetchMedications(mrn).catchError((e) => <dynamic>[]),
      ]);

      setState(() {
        _opd = results[0];
        _ipd = results[1];
        _vitals = results[2];
        _labs = results[3];
        _radiology = results[4];
        _surgery = results[5];
        _medications = results[6];
        _loading = false;
        _dataLoaded = true;
      });

      _buildCombinedTimeline();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
        _dataLoaded = true;
      });
    }
  }

  void _buildCombinedTimeline() {
    List<Map<String, dynamic>> timeline = [];

    // Add OPD encounters
    for (final opd in _opd) {
      final encounterDate = opd['encounterDate'] ?? 
                           opd['EncounterDate'] ?? 
                           opd['checkInTime'] ?? 
                           opd['CheckInTime'];
      
      DateTime? parsedDate;
      if (encounterDate != null) {
        parsedDate = encounterDate is DateTime 
            ? encounterDate 
            : DateTime.tryParse(encounterDate.toString());
      }

      // Filter by date range
      if (parsedDate != null) {
        if (parsedDate.isBefore(_startDate) || parsedDate.isAfter(_endDate.add(const Duration(days: 1)))) {
          continue;
        }
      }

      timeline.add({
        'type': 'opd',
        'date': parsedDate,
        'data': opd,
      });
    }

    // Add IPD encounters
    for (final ipd in _ipd) {
      final admissionDate = ipd['admissionDate'] ?? 
                           ipd['AdmissionDate'] ?? 
                           ipd['checkInTime'];
      
      DateTime? parsedDate;
      if (admissionDate != null) {
        parsedDate = admissionDate is DateTime 
            ? admissionDate 
            : DateTime.tryParse(admissionDate.toString());
      }

      // Filter by date range
      if (parsedDate != null) {
        if (parsedDate.isBefore(_startDate) || parsedDate.isAfter(_endDate.add(const Duration(days: 1)))) {
          continue;
        }
      }

      timeline.add({
        'type': 'ipd',
        'date': parsedDate,
        'data': ipd,
      });
    }

    // Add vitals
    for (final vital in _vitals) {
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

      // Filter by date range
      if (parsedDate != null) {
        if (parsedDate.isBefore(_startDate) || parsedDate.isAfter(_endDate.add(const Duration(days: 1)))) {
          continue;
        }
      }

      timeline.add({
        'type': 'vitals',
        'date': parsedDate,
        'data': vital,
      });
    }

    // Add surgeries
    for (final surgery in _surgery) {
      final surgeryDate = surgery['surgeryDate'] ?? surgery['SurgeryDate'];
      
      DateTime? parsedDate;
      if (surgeryDate != null) {
        parsedDate = surgeryDate is DateTime 
            ? surgeryDate 
            : DateTime.tryParse(surgeryDate.toString());
      }

      // Filter by date range
      if (parsedDate != null) {
        if (parsedDate.isBefore(_startDate) || parsedDate.isAfter(_endDate.add(const Duration(days: 1)))) {
          continue;
        }
      }

      timeline.add({
        'type': 'surgery',
        'date': parsedDate,
        'data': surgery,
      });
    }

    // Add labs
    for (final lab in _labs) {
      final orderDate = lab['orderDate'] ?? 
                       lab['OrderDate'] ?? 
                       lab['createdAt'];
      
      DateTime? parsedDate;
      if (orderDate != null) {
        parsedDate = orderDate is DateTime 
            ? orderDate 
            : DateTime.tryParse(orderDate.toString());
      }

      // Filter by date range
      if (parsedDate != null) {
        if (parsedDate.isBefore(_startDate) || parsedDate.isAfter(_endDate.add(const Duration(days: 1)))) {
          continue;
        }
      }

      timeline.add({
        'type': 'lab',
        'date': parsedDate,
        'data': lab,
      });
    }

    // Add radiology
    for (final rad in _radiology) {
      final orderDate = rad['orderDate'] ?? 
                       rad['OrderDate'] ?? 
                       rad['createdAt'];
      
      DateTime? parsedDate;
      if (orderDate != null) {
        parsedDate = orderDate is DateTime 
            ? orderDate 
            : DateTime.tryParse(orderDate.toString());
      }

      // Filter by date range
      if (parsedDate != null) {
        if (parsedDate.isBefore(_startDate) || parsedDate.isAfter(_endDate.add(const Duration(days: 1)))) {
          continue;
        }
      }

      timeline.add({
        'type': 'radiology',
        'date': parsedDate,
        'data': rad,
      });
    }

    // Sort by date (newest first)
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
            offset: const Offset(0, 2),
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
                    DateFormat('dd/MM/yyyy').format(_startDate),
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
                    DateFormat('dd/MM/yyyy').format(_endDate),
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
    final nameValue = widget.patient['fullName'] ?? 
                     widget.patient['FullName'] ?? 
                     widget.patient['name'];
    final String name = nameValue?.toString() ?? 'Unknown';
    
    final mrnValue = widget.patient['mrn'] ?? widget.patient['MRN'];
    final String mrn = mrnValue?.toString() ?? 'N/A';
    
    final genderValue = widget.patient['gender'] ?? widget.patient['Gender'];
    final String gender = genderValue?.toString() ?? '';
    
    final ageValue = widget.patient['age'] ?? widget.patient['Age'];
    final String age = (ageValue != null) ? '${ageValue.toString()}y' : '';
    
    final bloodValue = widget.patient['bloodGroup'] ?? widget.patient['BloodGroup'];
    final String blood = bloodValue?.toString() ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        return Transform.translate(
          offset: const Offset(-12.0, 0),
          child: SizedBox(
            width: screenWidth,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6366F1),
                    Color(0xFF8B5CF6),
                    Color(0xFFA855F7),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      Text(
                        '$gender, $age',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (blood.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red[400],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            blood,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOpdCard(Map<String, dynamic> opd) {
    final encounterDate = opd['encounterDate'] ?? 
                         opd['EncounterDate'] ?? 
                         opd['checkInTime'];
    final doctorName = opd['doctorName'] ?? 
                      opd['DoctorName'] ?? 
                      opd['doctor'] ?? 
                      'N/A';
    final departmentName = opd['departmentName'] ?? 
                          opd['DepartmentName'] ?? 
                          '';
    final status = opd['encounterStatus'] ?? 
                   opd['EncounterStatus'] ?? 
                   opd['status'] ?? 
                   '';
    final diagnosis = opd['diagnosis'] ?? 
                     opd['Diagnosis'] ?? 
                     opd['primaryDiagnosis'] ?? 
                     '';
    final complaints = opd['complaints'] ?? 
                      opd['Complaints'] ?? 
                      opd['chiefComplaint'] ?? 
                      '';

    DateTime? parsedDate;
    if (encounterDate != null) {
      parsedDate = encounterDate is DateTime 
          ? encounterDate 
          : DateTime.tryParse(encounterDate.toString());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: Colors.blue[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
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
                Row(
                  children: [
                    const Icon(Icons.local_hospital, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'OPD Visit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (parsedDate != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.calendar_today, size: 14, color: Colors.white.withOpacity(0.8)),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(parsedDate),
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                      ),
                    ],
                  ],
                ),
                if (status.toString().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status.toString()).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _getStatusColor(status.toString()), width: 1),
                    ),
                    child: Text(
                      status.toString().toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(status.toString()),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (doctorName.toString().isNotEmpty)
                  _buildInfoRow(Icons.person, 'Doctor', doctorName.toString()),
                if (departmentName.toString().isNotEmpty)
                  _buildInfoRow(Icons.business, 'Department', departmentName.toString()),
                if (complaints.toString().isNotEmpty)
                  _buildInfoRow(Icons.comment, 'Complaints', complaints.toString()),
                if (diagnosis.toString().isNotEmpty)
                  _buildInfoRow(Icons.medical_information, 'Diagnosis', diagnosis.toString()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIpdCard(Map<String, dynamic> ipd) {
    final admissionDate = ipd['admissionDate'] ?? ipd['AdmissionDate'];
    final dischargeDate = ipd['dischargeDate'] ?? ipd['DischargeDate'];
    final wardName = ipd['wardName'] ?? ipd['WardName'] ?? '';
    final bedNumber = ipd['bedNumber'] ?? ipd['BedNumber'] ?? '';
    final doctorName = ipd['doctorName'] ?? ipd['DoctorName'] ?? 'N/A';
    final status = ipd['admissionStatus'] ?? ipd['AdmissionStatus'] ?? ipd['status'] ?? '';
    final diagnosis = ipd['diagnosis'] ?? ipd['Diagnosis'] ?? '';

    DateTime? parsedAdmissionDate;
    if (admissionDate != null) {
      parsedAdmissionDate = admissionDate is DateTime 
          ? admissionDate 
          : DateTime.tryParse(admissionDate.toString());
    }

    DateTime? parsedDischargeDate;
    if (dischargeDate != null) {
      parsedDischargeDate = dischargeDate is DateTime 
          ? dischargeDate 
          : DateTime.tryParse(dischargeDate.toString());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: Colors.purple[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple[700]!, Colors.purple[600]!],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bed, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'IPD Admission',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (parsedAdmissionDate != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.calendar_today, size: 14, color: Colors.white.withOpacity(0.8)),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd/MM/yyyy').format(parsedAdmissionDate),
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                      ),
                    ],
                  ],
                ),
                if (status.toString().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.toString().toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (doctorName.toString().isNotEmpty)
                  _buildInfoRow(Icons.person, 'Doctor', doctorName.toString()),
                if (wardName.toString().isNotEmpty)
                  _buildInfoRow(Icons.meeting_room, 'Ward', wardName.toString()),
                if (bedNumber.toString().isNotEmpty)
                  _buildInfoRow(Icons.bed, 'Bed', bedNumber.toString()),
                if (parsedDischargeDate != null)
                  _buildInfoRow(Icons.exit_to_app, 'Discharged', DateFormat('dd/MM/yyyy').format(parsedDischargeDate)),
                if (diagnosis.toString().isNotEmpty)
                  _buildInfoRow(Icons.medical_information, 'Diagnosis', diagnosis.toString()),
              ],
            ),
          ),
        ],
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

    final bp = _formatBP(vital);
    final hr = _stringOrEmpty(vital['pulse'] ?? vital['Pulse'] ?? vital['heartRate']);
    final temp = _stringOrEmpty(vital['temperature'] ?? vital['Temperature']);
    final spo2 = _stringOrEmpty(vital['spo2'] ?? vital['SPO2'] ?? vital['oxygenSaturation']);
    final rr = _stringOrEmpty(vital['respiratoryRate'] ?? vital['RespiratoryRate']);
    final weight = _stringOrEmpty(vital['weight'] ?? vital['Weight']);
    final height = _stringOrEmpty(vital['height'] ?? vital['Height']);
    final bsr = _stringOrEmpty(vital['bsr'] ?? vital['BSR'] ?? vital['bloodSugar']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
            spreadRadius: 1,
          ),
        ],
        border: Border.all(color: Colors.red[200]!, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red[700]!, Colors.red[600]!],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Vitals',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (parsedDate != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.calendar_today, size: 12, color: Colors.white.withOpacity(0.8)),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(parsedDate),
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (bp.isNotEmpty) _buildVitalChip('BP', '$bp mmHg', _isBPOutOfRange(vital)),
                if (hr.isNotEmpty) _buildVitalChip('HR', '$hr bpm', _isPulseOutOfRange(hr)),
                if (temp.isNotEmpty) _buildVitalChip('Temp', '$temp°C', _isTempOutOfRange(temp)),
                if (spo2.isNotEmpty) _buildVitalChip('SpO2', '$spo2%', _isSpO2OutOfRange(spo2)),
                if (rr.isNotEmpty) _buildVitalChip('RR', '$rr/min', false),
                if (weight.isNotEmpty) _buildVitalChip('Weight', '$weight kg', false),
                if (height.isNotEmpty) _buildVitalChip('Height', '$height cm', false),
                if (bsr.isNotEmpty) _buildVitalChip('BSR', '$bsr mg/dL', _isBSROutOfRange(bsr)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalChip(String label, String value, bool isOutOfRange) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isOutOfRange ? Colors.red[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOutOfRange ? Colors.red[300]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isOutOfRange ? FontWeight.bold : FontWeight.w600,
              color: isOutOfRange ? Colors.red[700] : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurgeryCard(Map<String, dynamic> surgery) {
    final surgeryName = surgery['surgeryName'] ?? surgery['SurgeryName'] ?? 'N/A';
    final surgeryDate = surgery['surgeryDate'] ?? surgery['SurgeryDate'];
    final surgeonName = surgery['surgeonName'] ?? surgery['SurgeonName'] ?? 'N/A';
    final surgeryStatus = surgery['surgeryStatus'] ?? surgery['SurgeryStatus'] ?? 'Completed';
    final procedureNote = surgery['procedureNote'] ?? surgery['ProcedureNote'] ?? '';
    final anesthesiaType = surgery['anesthesiaType'] ?? surgery['AnesthesiaType'] ?? '';

    DateTime? parsedDate;
    if (surgeryDate != null) {
      parsedDate = surgeryDate is DateTime 
          ? surgeryDate 
          : DateTime.tryParse(surgeryDate.toString());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: Colors.amber[300]!, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
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
                  child: Row(
                    children: [
                      const Icon(Icons.healing, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          surgeryName.toString(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (parsedDate != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today, size: 14, color: Colors.white.withOpacity(0.8)),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd/MM/yyyy').format(parsedDate),
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    surgeryStatus.toString().toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.person, 'Surgeon', surgeonName.toString()),
                if (anesthesiaType.toString().isNotEmpty)
                  _buildInfoRow(Icons.medication_liquid, 'Anesthesia', anesthesiaType.toString()),
                if (procedureNote.toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
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
                            Icon(Icons.note, color: Colors.amber[800], size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Procedure Note',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          procedureNote.toString(),
                          style: const TextStyle(fontSize: 12),
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

  Widget _buildLabCard(Map<String, dynamic> lab) {
    final testName = lab['testName'] ?? lab['TestName'] ?? lab['packageName'] ?? 'N/A';
    final orderDate = lab['orderDate'] ?? lab['OrderDate'];
    final resultValue = lab['resultValue'] ?? lab['ResultValue'] ?? '';
    final resultStatus = lab['resultStatus'] ?? lab['ResultStatus'] ?? '';
    final units = lab['units'] ?? lab['Units'] ?? '';
    final referenceRange = lab['referenceRange'] ?? lab['ReferenceRange'] ?? '';

    DateTime? parsedDate;
    if (orderDate != null) {
      parsedDate = orderDate is DateTime 
          ? orderDate 
          : DateTime.tryParse(orderDate.toString());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.blue[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.science, color: Colors.blue[700], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    testName.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                ),
                if (parsedDate != null)
                  Text(
                    DateFormat('dd/MM/yyyy').format(parsedDate),
                    style: TextStyle(color: Colors.blue[600], fontSize: 11),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (resultValue.toString().isNotEmpty)
                  Row(
                    children: [
                      const Text('Result: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      Text(
                        '${resultValue.toString()}${units.toString().isNotEmpty ? ' $units' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _isLabResultAbnormal(resultStatus.toString()) ? Colors.red[700] : Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                if (referenceRange.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Ref: $referenceRange',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ),
                if (resultStatus.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isLabResultAbnormal(resultStatus.toString()) 
                            ? Colors.red[100] 
                            : Colors.green[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        resultStatus.toString().toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _isLabResultAbnormal(resultStatus.toString()) 
                              ? Colors.red[800] 
                              : Colors.green[800],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadiologyCard(Map<String, dynamic> rad) {
    final testName = rad['testName'] ?? rad['TestName'] ?? rad['clinicalDisplayName'] ?? 'N/A';
    final orderDate = rad['orderDate'] ?? rad['OrderDate'];
    final findings = rad['finalFindings'] ?? rad['preliminaryFindings'] ?? rad['findings'] ?? '';
    final impression = rad['impression'] ?? rad['Impression'] ?? '';
    final reportStatus = rad['reportStatus'] ?? rad['ReportStatus'] ?? '';

    DateTime? parsedDate;
    if (orderDate != null) {
      parsedDate = orderDate is DateTime 
          ? orderDate 
          : DateTime.tryParse(orderDate.toString());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.orange[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.scanner, color: Colors.orange[700], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    testName.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
                if (parsedDate != null)
                  Text(
                    DateFormat('dd/MM/yyyy').format(parsedDate),
                    style: TextStyle(color: Colors.orange[600], fontSize: 11),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reportStatus.toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Status: ${reportStatus.toString()}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ),
                if (findings.toString().isNotEmpty) ...[
                  Text(
                    'Findings:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    findings.toString(),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                if (impression.toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Impression:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    impression.toString(),
                    style: const TextStyle(fontSize: 12),
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

  // Helper methods
  String _stringOrEmpty(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  String _formatBP(Map<String, dynamic> vital) {
    final bpSystolic = _stringOrEmpty(vital['bpSystolic'] ?? vital['BPSystolic'] ?? vital['bloodPressureSystolic']);
    final bpDiastolic = _stringOrEmpty(vital['bpDiastolic'] ?? vital['BPDiastolic'] ?? vital['bloodPressureDiastolic']);
    if (bpSystolic.isNotEmpty && bpDiastolic.isNotEmpty) {
      return '$bpSystolic/$bpDiastolic';
    }
    return _stringOrEmpty(vital['bloodPressure'] ?? vital['BloodPressure']);
  }

  bool _isBPOutOfRange(Map<String, dynamic> vital) {
    final bpSystolic = double.tryParse(_stringOrEmpty(vital['bpSystolic'] ?? vital['BPSystolic']));
    final bpDiastolic = double.tryParse(_stringOrEmpty(vital['bpDiastolic'] ?? vital['BPDiastolic']));
    if (bpSystolic != null && (bpSystolic < 90 || bpSystolic > 140)) return true;
    if (bpDiastolic != null && (bpDiastolic < 60 || bpDiastolic > 90)) return true;
    return false;
  }

  bool _isPulseOutOfRange(String hr) {
    final value = double.tryParse(hr);
    if (value == null) return false;
    return value < 60 || value > 100;
  }

  bool _isTempOutOfRange(String temp) {
    final value = double.tryParse(temp);
    if (value == null) return false;
    final tempF = (value * 9 / 5) + 32;
    return tempF < 97.0 || tempF > 99.5;
  }

  bool _isSpO2OutOfRange(String spo2) {
    final value = double.tryParse(spo2);
    if (value == null) return false;
    return value < 95;
  }

  bool _isBSROutOfRange(String bsr) {
    final value = double.tryParse(bsr);
    if (value == null) return false;
    return value < 70 || value > 100;
  }

  bool _isLabResultAbnormal(String status) {
    final lower = status.toLowerCase();
    return lower.contains('high') || 
           lower.contains('low') || 
           lower.contains('abnormal') || 
           lower.contains('critical');
  }

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    if (statusLower.contains('checked out') || statusLower == 'checked_out' || statusLower == 'completed') {
      return Colors.grey;
    } else if (statusLower.contains('checked in') || statusLower == 'checked_in' || statusLower.contains('in progress')) {
      return Colors.green;
    } else if (statusLower.contains('pending') || statusLower.contains('waiting')) {
      return Colors.orange;
    } else if (statusLower.contains('cancelled') || statusLower.contains('canceled')) {
      return Colors.red;
    }
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Medical Records'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
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
                : _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(
                                    _error!,
                                    style: TextStyle(color: Colors.red[700]),
                                    textAlign: TextAlign.center,
                                  ),
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
                                      'No records found for the selected date range',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _combinedTimeline.map((item) {
                                    final type = item['type'] as String;
                                    final data = item['data'] as Map<String, dynamic>;
                                    
                                    switch (type) {
                                      case 'opd':
                                        return _buildOpdCard(data);
                                      case 'ipd':
                                        return _buildIpdCard(data);
                                      case 'vitals':
                                        return _buildVitalsCard(data);
                                      case 'surgery':
                                        return _buildSurgeryCard(data);
                                      case 'lab':
                                        return _buildLabCard(data);
                                      case 'radiology':
                                        return _buildRadiologyCard(data);
                                      default:
                                        return const SizedBox.shrink();
                                    }
                                  }).toList(),
                                ),
                              ),
          ),
        ],
      ),
    );
  }
}
