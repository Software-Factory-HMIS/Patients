import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import '../../../services/encounter_service.dart';
import '../../../services/user_session_service.dart';
import '../../../services/system_info_service.dart';
import '../../../services/hospital_setup_service.dart';
import '../../../config/api_config.dart';

class ConsultationSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> patient;
  final int? encounterId;

  const ConsultationSummaryScreen({
    Key? key,
    required this.patient,
    this.encounterId,
  }) : super(key: key);

  @override
  State<ConsultationSummaryScreen> createState() => _ConsultationSummaryScreenState();
}

class _ConsultationSummaryScreenState extends State<ConsultationSummaryScreen> {
  final EncounterService _encounterService = EncounterService();
  bool _isLoading = true;
  Map<String, dynamic>? _consultationData;
  List<Map<String, dynamic>> _vitals = [];
  String? _error;
  int? _userId;
  int? _hospitalId;
  String? _hospitalName;
  String? _departmentName;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<List<Map<String, dynamic>>> _fetchVitalsList(
    int encounterId,
    Object? patientId,
    String? token,
  ) async {
    final vitals = <Map<String, dynamic>>[];
    if (token == null || patientId == null) return vitals;
    try {
      final vitalsUri = Uri.parse('${ApiConfig.baseUrl}/patient-queue/nurse-vitals').replace(
        queryParameters: {
          'encounterId': encounterId.toString(),
          'patientId': patientId.toString(),
        },
      );
      final vitalsResponse = await http.get(
        vitalsUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (vitalsResponse.statusCode == 200) {
        final vitalsData = json.decode(vitalsResponse.body);
        if (vitalsData is List) {
          vitals.addAll(List<Map<String, dynamic>>.from(vitalsData));
        } else if (vitalsData is Map && vitalsData['data'] != null) {
          vitals.addAll(List<Map<String, dynamic>>.from(vitalsData['data']));
        }
      }
      if (vitals.isEmpty) {
        final allVitalsUri = Uri.parse('${ApiConfig.baseUrl}/patient-queue/patient-vitals/$patientId')
            .replace(queryParameters: {'limit': '200'});
        final allVitalsResponse = await http.get(
          allVitalsUri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        if (allVitalsResponse.statusCode == 200) {
          final allVitalsData = json.decode(allVitalsResponse.body);
          List<Map<String, dynamic>> allVitals = [];
          if (allVitalsData is List) {
            allVitals = List<Map<String, dynamic>>.from(allVitalsData);
          } else if (allVitalsData is Map && allVitalsData['data'] != null) {
            allVitals = List<Map<String, dynamic>>.from(allVitalsData['data']);
          }
          vitals.addAll(allVitals.where((v) {
            final vEncounterId = v['encounterId'] ?? v['EncounterID'] ?? v['encounterID'];
            if (vEncounterId == null) return false;
            final parsed = vEncounterId is int ? vEncounterId : int.tryParse(vEncounterId.toString());
            return parsed == encounterId;
          }));
        }
      }
    } catch (e) {
      print('Error loading vitals: $e');
    }
    return vitals;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _userId = await UserSessionService.getUserId();
      _hospitalId = await UserSessionService.getHospitalId();

      // Load hospital and department info
      if (_hospitalId != null) {
        final hospitalInfo = await SystemInfoService.getHospitalInfo(_hospitalId!);
        _hospitalName = hospitalInfo?['name']?.toString() ?? 
                       hospitalInfo?['Name']?.toString() ?? 
                       'Hospital';
        
        final deptId = await UserSessionService.getHospitalDepartmentId();
        if (deptId != null) {
          final departments = await HospitalSetupService.getHospitalDepartments(_hospitalId!);
          final dept = departments.firstWhere(
            (d) => (d['hospitalDepartmentId'] ?? d['hospitalDepartmentID'] ?? d['id']) == deptId,
            orElse: () => {},
          );
          _departmentName = dept['departmentName']?.toString() ?? 
                           dept['DepartmentName']?.toString() ?? 
                           dept['name']?.toString() ?? 
                           'Department';
        }
      }

      int? encounterId = widget.encounterId;
      final patientId = widget.patient['patientId'] ?? widget.patient['PatientID'];

      if (encounterId == null && patientId != null) {
        // First, check if queueId exists and try to get encounter by queueId
        final queueId = widget.patient['queueId'] ?? widget.patient['QueueId'] ?? widget.patient['QueueID'];
        if (queueId != null) {
          int? parsedQueueId;
          if (queueId is int) {
            parsedQueueId = queueId;
          } else {
            parsedQueueId = int.tryParse(queueId.toString());
          }
          
          if (parsedQueueId != null) {
            final encounterByQueue = await _encounterService.getEncounterByQueueId(parsedQueueId);
            if (encounterByQueue != null) {
              encounterId = encounterByQueue['encounterId'] ??
                  encounterByQueue['EncounterID'] ??
                  encounterByQueue['encounterID'];
              if (encounterId != null && encounterId is! int) {
                encounterId = int.tryParse(encounterId.toString());
              }
            }
          }
        }
        
        // If no encounter found by queueId, fall back to the original method
        if (encounterId == null) {
          // Try to find the most recent completed encounter
          final encounters = await _encounterService.getPatientEncounterHistory(
            patientId,
            doctorId: _userId ?? 1,
            hospitalId: _hospitalId ?? 1,
          );
          
          if (encounters.isNotEmpty) {
            // Find completed/checked out encounter
            final completedEncounter = encounters.firstWhere(
              (enc) {
                final status = (enc['encounterStatus'] ?? enc['EncounterStatus'] ?? '').toString().toLowerCase();
                return status == 'checked out' || status == 'checked_out' || status == 'completed';
              },
              orElse: () => encounters.first,
            );
            
            encounterId = completedEncounter['encounterId'] ?? 
                         completedEncounter['EncounterID'] ?? 
                         completedEncounter['encounterID'];
            if (encounterId != null && encounterId is! int) {
              encounterId = int.tryParse(encounterId.toString());
            }
          }
        }
      }

      if (encounterId == null) {
        throw Exception('No encounter found for this patient');
      }

      final token = await UserSessionService.getToken();
      final eid = encounterId!;
      final results = await Future.wait([
        _encounterService.getEncounterConsultationData(eid, patientId: patientId),
        _fetchVitalsList(eid, patientId, token),
      ]);
      final data = results[0] as Map<String, dynamic>;
      final vitals = results[1] as List<Map<String, dynamic>>;

      setState(() {
        _consultationData = data;
        _vitals = vitals;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _generateAndPrintPDF() async {
    if (_consultationData == null) return;

    try {
      final pdf = await _buildPDF();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf,
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

  String _buildQRCodeData() {
    final encounterInfo = _consultationData!['encounter'] ?? {};
    final complaints = List<Map<String, dynamic>>.from(_consultationData!['complaints'] ?? []);
    final symptoms = List<Map<String, dynamic>>.from(_consultationData!['symptoms'] ?? []);
    final diagnoses = List<Map<String, dynamic>>.from(_consultationData!['diagnoses'] ?? []);
    final clinicalNotes = List<Map<String, dynamic>>.from(_consultationData!['clinicalNotes'] ?? []);
    final labOrders = List<Map<String, dynamic>>.from(_consultationData!['labOrders'] ?? []);
    final radiologyOrders = List<Map<String, dynamic>>.from(_consultationData!['radiologyOrders'] ?? []);
    final physioOrders = List<Map<String, dynamic>>.from(_consultationData!['physioOrders'] ?? []);
    final medicinesRaw = List<Map<String, dynamic>>.from(_consultationData!['medicines'] ?? []);
    // Filter out discontinued medicines
    final medicines = medicinesRaw.where((m) {
      final discontinuedDate = m['DiscontinuedDate'] ?? m['DiscountinuedDate'] ?? m['discontinuedDate'];
      final isDiscontinued = discontinuedDate != null && 
                             discontinuedDate.toString().isNotEmpty && 
                             discontinuedDate.toString() != '{}';
      return !isDiscontinued;
    }).toList();

    final patientName = widget.patient['fullName'] ?? widget.patient['name'] ?? 'Unknown';
    final mrn = widget.patient['mrn']?.toString() ?? 'N/A';
    final contactNo = widget.patient['contactNumber']?.toString() ?? 'N/A';
    final age = widget.patient['age']?.toString() ?? 'N/A';
    final doctorName = encounterInfo['doctorName']?.toString() ?? 'N/A';
    final departmentName = _departmentName ?? encounterInfo['departmentName']?.toString() ?? widget.patient['departmentName']?.toString() ?? 'N/A';
    final hospitalName = _hospitalName ?? 'Hospital';
    final printDate = DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.now());
    final createdDate = encounterInfo['checkInTime'] != null
        ? DateFormat('dd-MMM-yyyy hh:mm a').format(DateTime.parse(encounterInfo['checkInTime'].toString()))
        : printDate;
    final encounterId = widget.encounterId ?? encounterInfo['encounterId'] ?? encounterInfo['EncounterID'] ?? encounterInfo['encounterID'];

    // Get unique package names for lab orders
    final packageNames = _getUniquePackageNames(labOrders);
    
    // Build human-readable QR code content
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('═══════════════════════════');
    buffer.writeln('   CONSULTATION SUMMARY');
    buffer.writeln('═══════════════════════════');
    buffer.writeln();
    
    // Hospital Info
    buffer.writeln('📍 $hospitalName');
    buffer.writeln('   $departmentName');
    buffer.writeln();
    
    // Patient Info
    buffer.writeln('━━━ PATIENT INFO ━━━');
    buffer.writeln('Name:\t$patientName');
    buffer.writeln('MRN:\t$mrn');
    buffer.writeln('Age:\t$age years');
    buffer.writeln('Contact:\t$contactNo');
    buffer.writeln();
    
    // Encounter Info
    buffer.writeln('━━━ ENCOUNTER ━━━');
    buffer.writeln('ID:\t$encounterId');
    buffer.writeln('Doctor:\t$doctorName');
    buffer.writeln('Date:\t$createdDate');
    buffer.writeln('Printed:\t$printDate');
    buffer.writeln();
    
    // Complaints
    if (complaints.isNotEmpty) {
      buffer.writeln('━━━ COMPLAINTS ━━━');
      for (int i = 0; i < complaints.take(10).length; i++) {
        final c = complaints[i];
        final desc = (c['diagnosisName'] ?? c['icd10Description'] ?? '').toString();
        if (desc.isNotEmpty) {
          buffer.writeln('${i + 1}. $desc');
        }
      }
      buffer.writeln();
    }
    
    // Symptoms
    if (symptoms.isNotEmpty) {
      buffer.writeln('━━━ SYMPTOMS ━━━');
      for (int i = 0; i < symptoms.take(10).length; i++) {
        final s = symptoms[i];
        final desc = (s['diagnosisName'] ?? s['icd10Description'] ?? '').toString();
        if (desc.isNotEmpty) {
          buffer.writeln('${i + 1}. $desc');
        }
      }
      buffer.writeln();
    }
    
    // Diagnoses
    if (diagnoses.isNotEmpty) {
      buffer.writeln('━━━ DIAGNOSIS ━━━');
      for (int i = 0; i < diagnoses.take(10).length; i++) {
        final d = diagnoses[i];
        final desc = (d['diagnosisName'] ?? d['icd10Description'] ?? '').toString();
        final confirmed = d['isConfirmed'] == true ? '✓' : '○';
        if (desc.isNotEmpty) {
          buffer.writeln('$confirmed $desc');
        }
      }
      buffer.writeln();
    }
    
    // Lab Orders
    if (packageNames.isNotEmpty) {
      buffer.writeln('━━━ LAB TESTS ━━━');
      for (int i = 0; i < packageNames.take(10).length; i++) {
        buffer.writeln('• ${packageNames[i]}');
      }
      buffer.writeln();
    }
    
    // Radiology Orders
    if (radiologyOrders.isNotEmpty) {
      buffer.writeln('━━━ RADIOLOGY ━━━');
      for (int i = 0; i < radiologyOrders.take(10).length; i++) {
        final r = radiologyOrders[i];
        final name = (r['testName'] ?? '').toString();
        if (name.isNotEmpty) {
          buffer.writeln('• $name');
        }
      }
      buffer.writeln();
    }
    
    // Physio Orders
    if (physioOrders.isNotEmpty) {
      buffer.writeln('━━━ PHYSIO ━━━');
      for (int i = 0; i < physioOrders.take(10).length; i++) {
        final p = physioOrders[i];
        final name = (p['modalityName'] ?? p['ModalityName'] ?? '').toString();
        final duration = p['durationMinutes'] ?? p['DurationMinutes'] ?? 0;
        final period = (p['treatmentPeriod'] ?? p['TreatmentPeriod'] ?? '').toString();
        final frequency = (p['frequency'] ?? p['Frequency'] ?? '').toString();
        if (name.isNotEmpty) {
          buffer.writeln('• $name | ${duration}min | $period | $frequency');
        }
      }
      buffer.writeln();
    }
    
    // Medicines
    if (medicines.isNotEmpty) {
      buffer.writeln('━━━ MEDICATIONS ━━━');
      for (int i = 0; i < medicines.take(15).length; i++) {
        final m = medicines[i];
        final name = (m['medicineName'] ?? '').toString();
        final dosage = (m['dosage'] ?? '').toString();
        final route = (m['route'] ?? m['Route'] ?? '').toString();
        final freq = (m['frequency'] ?? '').toString();
        final qty = m['quantityOrdered'] ?? m['quantity'] ?? 0;
        if (name.isNotEmpty) {
          buffer.writeln('${i + 1}. $name');
          final parts = <String>[];
          if (dosage.isNotEmpty) parts.add('Dose: $dosage');
          if (route.isNotEmpty) parts.add('Route: $route');
          if (freq.isNotEmpty) parts.add('$freq');
          parts.add('Qty: $qty');
          if (parts.isNotEmpty) buffer.writeln('   ${parts.join(' | ')}');
        }
      }
      buffer.writeln();
    }
    
    // Clinical Notes (shortened)
    if (clinicalNotes.isNotEmpty) {
      buffer.writeln('━━━ NOTES ━━━');
      for (int i = 0; i < clinicalNotes.take(3).length; i++) {
        final note = clinicalNotes[i];
        var desc = (note['description'] ?? '').toString();
        // Truncate long notes
        if (desc.length > 100) {
          desc = '${desc.substring(0, 100)}...';
        }
        if (desc.isNotEmpty) {
          buffer.writeln(desc);
        }
      }
      buffer.writeln();
    }
    
    // Footer
    buffer.writeln('═══════════════════════════');
    buffer.writeln('Helpline: 1033');
    buffer.writeln('═══════════════════════════');
    
    String result = buffer.toString();
    
    // Truncate if too long for QR code (max ~2500 chars for reliable scanning)
    if (result.length > 2500) {
      result = result.substring(0, 2450);
      result += '\n...(truncated)';
    }
    
    return result;
  }

  List<String> _getUniquePackageNames(List<Map<String, dynamic>> labOrders) {
    final packageNames = <String>{};
    for (var order in labOrders) {
      final packageName = (order['packageName'] ?? '').toString().trim();
      if (packageName.isNotEmpty) {
        packageNames.add(packageName);
      }
    }
    return packageNames.toList()..sort();
  }

  Future<Uint8List> _buildPDF() async {
    final pdf = pw.Document();
    // Use full A4 portrait format
    final pageFormat = PdfPageFormat.a4;

    // Load Punjab logo image
    final ByteData logoData = await rootBundle.load('assets/images/punjab.png');
    final Uint8List logoBytes = logoData.buffer.asUint8List();
    final pw.ImageProvider logoImage = pw.MemoryImage(logoBytes);

    final encounterInfo = _consultationData!['encounter'] ?? {};
    final complaints = List<Map<String, dynamic>>.from(_consultationData!['complaints'] ?? []);
    final symptoms = List<Map<String, dynamic>>.from(_consultationData!['symptoms'] ?? []);
    final diagnoses = List<Map<String, dynamic>>.from(_consultationData!['diagnoses'] ?? []);
    final clinicalNotes = List<Map<String, dynamic>>.from(_consultationData!['clinicalNotes'] ?? []);
    final labOrders = List<Map<String, dynamic>>.from(_consultationData!['labOrders'] ?? []);
    final radiologyOrders = List<Map<String, dynamic>>.from(_consultationData!['radiologyOrders'] ?? []);
    final dentalProcedures = List<Map<String, dynamic>>.from(_consultationData!['dentalProcedures'] ?? []);
    final physioOrders = List<Map<String, dynamic>>.from(_consultationData!['physioOrders'] ?? []);
    final medicinesRaw = List<Map<String, dynamic>>.from(_consultationData!['medicines'] ?? []);
    // Filter out discontinued medicines
    final medicines = medicinesRaw.where((m) {
      final discontinuedDate = m['DiscontinuedDate'] ?? m['DiscountinuedDate'] ?? m['discontinuedDate'];
      final isDiscontinued = discontinuedDate != null && 
                             discontinuedDate.toString().isNotEmpty && 
                             discontinuedDate.toString() != '{}';
      return !isDiscontinued;
    }).toList();
    final packageNames = _getUniquePackageNames(labOrders);

    final patientName = widget.patient['fullName'] ?? widget.patient['name'] ?? 'Unknown';
    final mrn = widget.patient['mrn']?.toString() ?? 'N/A';
    final contactNo = widget.patient['contactNumber']?.toString() ?? 'N/A';
    final age = widget.patient['age']?.toString() ?? 'N/A';
    final doctorName = encounterInfo['doctorName']?.toString() ?? 'N/A';
    final departmentName = _departmentName ?? encounterInfo['departmentName']?.toString() ?? widget.patient['departmentName']?.toString() ?? 'N/A';
    final hospitalName = _hospitalName ?? 'Hospital';
    final printDate = DateFormat('MMM dd, yyyy, hh:mm:ss a').format(DateTime.now());
    DateTime? createdDateTime;
    String createdDate;
    if (encounterInfo['checkInTime'] != null) {
      try {
        createdDateTime = DateTime.parse(encounterInfo['checkInTime'].toString());
        createdDate = DateFormat('MMM dd, yyyy, hh:mm:ss a').format(createdDateTime);
      } catch (e) {
        createdDate = printDate;
        createdDateTime = DateTime.now();
      }
    } else {
      createdDate = printDate;
      createdDateTime = DateTime.now();
    }

    final qrCodeData = _buildQRCodeData();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        build: (pw.Context context) {
          return [
            // Elegant Header with Logo, Department, Hospital, QR Code
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 12),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.blue700, width: 2),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left: Logo and Department
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Image(
                        logoImage,
                        width: 50,
                        height: 50,
                        fit: pw.BoxFit.contain,
                      ),
                      pw.SizedBox(width: 10),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'HEALTH & POPULATION',
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
                          ),
                          pw.Text(
                            'DEPARTMENT',
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Center: Hospital Name
                  pw.Expanded(
                    child: pw.Center(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            hospitalName.toUpperCase(),
                            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
                            textAlign: pw.TextAlign.center,
                          ),
                          if (departmentName.isNotEmpty)
                            pw.Text(
                              '$departmentName, OPD',
                              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                              textAlign: pw.TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Right: QR Code
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: qrCodeData,
                    width: 50,
                    height: 50,
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 15),
            
            // Patient and Doctor Info Section
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(5),
                border: pw.Border.all(color: PdfColors.blue200, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Patient Information',
                              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'Name: $patientName',
                              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Row(
                              children: [
                                pw.Text('MR No.: $mrn', style: pw.TextStyle(fontSize: 9)),
                                pw.SizedBox(width: 15),
                                pw.Text('Age: $age Y', style: pw.TextStyle(fontSize: 9)),
                                pw.SizedBox(width: 15),
                                pw.Text('Contact: $contactNo', style: pw.TextStyle(fontSize: 9)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Doctor Information',
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            doctorName,
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Created: ${createdDateTime != null ? DateFormat('MMM dd, yyyy').format(createdDateTime) : createdDate.split(',').first}',
                            style: pw.TextStyle(fontSize: 9),
                          ),
                          pw.Text(
                            'Printed: ${DateFormat('MMM dd, yyyy, hh:mm a').format(DateTime.now())}',
                            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 15),
            
            // Vitals Section (if available)
            if (_vitals.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(5),
                  border: pw.Border.all(color: PdfColors.grey300, width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Vital Signs',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(1.5),
                        1: const pw.FlexColumnWidth(1),
                        2: const pw.FlexColumnWidth(1),
                        3: const pw.FlexColumnWidth(1),
                        4: const pw.FlexColumnWidth(1),
                        5: const pw.FlexColumnWidth(1),
                      },
                      children: [
                        // Header
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                          children: [
                            _buildPdfVitalHeader('BP (mmHg)'),
                            _buildPdfVitalHeader('HR (bpm)'),
                            _buildPdfVitalHeader('Temp (°F)'),
                            _buildPdfVitalHeader('RR (bpm)'),
                            _buildPdfVitalHeader('SpO2 (%)'),
                            _buildPdfVitalHeader('Weight (kg)'),
                          ],
                        ),
                        // Vitals Row
                        pw.TableRow(
                          children: [
                            _buildPdfVitalCell(_formatBP(_vitals.first)),
                            _buildPdfVitalCell(_formatValue(_vitals.first['pulse'] ?? _vitals.first['Pulse'] ?? _vitals.first['heartRate'] ?? _vitals.first['HeartRate'])),
                            _buildPdfVitalCell(_formatValue(_vitals.first['temperature'] ?? _vitals.first['Temperature'])),
                            _buildPdfVitalCell(_formatValue(_vitals.first['respiratoryRate'] ?? _vitals.first['RespiratoryRate'])),
                            _buildPdfVitalCell(_formatValue(_vitals.first['oxygenSaturation'] ?? _vitals.first['OxygenSaturation'])),
                            _buildPdfVitalCell(_formatValue(_vitals.first['weight'] ?? _vitals.first['Weight'])),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),
            ],
            
            // Two Column Table Layout
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(1),
              },
              children: [
                // Header Row
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Clinical Information',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Tests Advised',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
                // Content Row
                pw.TableRow(
                  children: [
                    // Left Column: Complaints, Symptoms, Diagnosis
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Complaints
                          if (complaints.isNotEmpty) ...[
                            pw.Container(
                              padding: const pw.EdgeInsets.only(bottom: 4),
                              child: pw.Text(
                                'Chief Complaints:',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.orange700),
                              ),
                            ),
                            ...complaints.map((c) {
                              final desc = (c['diagnosisName'] ?? c['icd10Description'] ?? '').toString();
                              return pw.Padding(
                                padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
                                child: pw.Text(
                                  '• $desc',
                                  style: pw.TextStyle(fontSize: 8),
                                ),
                              );
                            }),
                            pw.SizedBox(height: 6),
                          ],
                          
                          // Symptoms
                          if (symptoms.isNotEmpty) ...[
                            pw.Container(
                              padding: const pw.EdgeInsets.only(bottom: 4),
                              child: pw.Text(
                                'Symptoms:',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red700),
                              ),
                            ),
                            ...symptoms.map((s) {
                              final desc = (s['diagnosisName'] ?? s['icd10Description'] ?? '').toString();
                              return pw.Padding(
                                padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
                                child: pw.Text(
                                  '• $desc',
                                  style: pw.TextStyle(fontSize: 8),
                                ),
                              );
                            }),
                            pw.SizedBox(height: 6),
                          ],
                          
                          // Diagnosis
                          if (diagnoses.isNotEmpty) ...[
                            pw.Container(
                              padding: const pw.EdgeInsets.only(bottom: 4),
                              child: pw.Text(
                                'Diagnosis:',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green700),
                              ),
                            ),
                            ...diagnoses.map((d) {
                              final desc = (d['diagnosisName'] ?? d['icd10Description'] ?? '').toString();
                              final isConfirmed = d['isConfirmed'] == true;
                              return pw.Padding(
                                padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
                                child: pw.Row(
                                  children: [
                                    pw.Text(
                                      isConfirmed ? '✓' : '○',
                                      style: pw.TextStyle(fontSize: 8, color: isConfirmed ? PdfColors.green700 : PdfColors.grey600),
                                    ),
                                    pw.SizedBox(width: 4),
                                    pw.Expanded(
                                      child: pw.Text(
                                        desc,
                                        style: pw.TextStyle(fontSize: 8, fontStyle: isConfirmed ? pw.FontStyle.normal : pw.FontStyle.italic),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            pw.SizedBox(height: 6),
                          ],
                          
                          // Clinical Notes
                          if (clinicalNotes.isNotEmpty) ...[
                            pw.Container(
                              padding: const pw.EdgeInsets.only(bottom: 4),
                              child: pw.Text(
                                'Clinical Notes:',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700),
                              ),
                            ),
                            ...clinicalNotes.map((note) {
                              final desc = (note['description'] ?? '').toString();
                              return pw.Padding(
                                padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
                                child: pw.Text(
                                  desc,
                                  style: pw.TextStyle(fontSize: 8),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                    
                    // Right Column: Lab Tests, Radiology Tests
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Lab Tests
                          if (packageNames.isNotEmpty) ...[
                            pw.Container(
                              padding: const pw.EdgeInsets.only(bottom: 4),
                              child: pw.Text(
                                'Laboratory Tests:',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700),
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Wrap(
                              spacing: 4,
                              runSpacing: 2,
                              children: packageNames.map((name) {
                                return pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.blue50,
                                    borderRadius: pw.BorderRadius.circular(3),
                                    border: pw.Border.all(color: PdfColors.blue200, width: 0.5),
                                  ),
                                  child: pw.Text(
                                    name,
                                    style: pw.TextStyle(fontSize: 7),
                                  ),
                                );
                              }).toList(),
                            ),
                            pw.SizedBox(height: 8),
                          ],
                          
                          // Radiology Tests
                          if (radiologyOrders.isNotEmpty) ...[
                            pw.Container(
                              padding: const pw.EdgeInsets.only(bottom: 4),
                              child: pw.Text(
                                'Radiology Tests:',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.orange700),
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            ...radiologyOrders.take(10).map((r) {
                              final name = (r['testName'] ?? '').toString();
                              return pw.Padding(
                                padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
                                child: pw.Text(
                                  '• $name',
                                  style: pw.TextStyle(fontSize: 8),
                                ),
                              );
                            }),
                            if (radiologyOrders.length > 10)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(left: 8, top: 2),
                                child: pw.Text(
                                  '...and ${radiologyOrders.length - 10} more',
                                  style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
                                ),
                              ),
                          ],
                          
                          // Dental Procedures
                          if (dentalProcedures.isNotEmpty) ...[
                            pw.SizedBox(height: 8),
                            pw.Container(
                              padding: const pw.EdgeInsets.only(bottom: 4),
                              child: pw.Text(
                                'Dental Procedures:',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.teal700),
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            ...dentalProcedures.take(10).map((d) {
                              final name = (d['procedureName'] ?? '').toString();
                              final fee = d['fee'] ?? 0;
                              return pw.Padding(
                                padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
                                child: pw.Row(
                                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Expanded(
                                      child: pw.Text(
                                        '• $name',
                                        style: pw.TextStyle(fontSize: 8),
                                      ),
                                    ),
                                    pw.Text(
                                      'Rs ${fee.toString()}',
                                      style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            if (dentalProcedures.length > 10)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(left: 8, top: 2),
                                child: pw.Text(
                                  '...and ${dentalProcedures.length - 10} more',
                                  style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
                                ),
                              ),
                          ],
                          
                          // Physio Orders
                          if (physioOrders.isNotEmpty) ...[
                            pw.SizedBox(height: 8),
                            pw.Container(
                              padding: const pw.EdgeInsets.only(bottom: 4),
                              child: pw.Text(
                                'Physio Modalities:',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700),
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            ...physioOrders.take(10).map((p) {
                              final name = (p['modalityName'] ?? p['ModalityName'] ?? '').toString();
                              final duration = p['durationMinutes'] ?? p['DurationMinutes'] ?? 0;
                              final period = (p['treatmentPeriod'] ?? p['TreatmentPeriod'] ?? '').toString();
                              final frequency = (p['frequency'] ?? p['Frequency'] ?? 'Once a day').toString();
                              final totalSessions = p['totalSessions'] ?? p['TotalSessions'];
                              final endDateStr = (p['endDate'] ?? p['EndDate'] ?? '').toString();
                              String formattedEndDate = '';
                              if (endDateStr.isNotEmpty) {
                                try {
                                  final date = DateTime.parse(endDateStr);
                                  formattedEndDate = '${date.day}/${date.month}/${date.year}';
                                } catch (e) {
                                  formattedEndDate = endDateStr;
                                }
                              }
                              final sessionInfo = totalSessions != null ? ' ($totalSessions sessions)' : '';
                              return pw.Padding(
                                padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      '• $name',
                                      style: pw.TextStyle(fontSize: 8),
                                    ),
                                    pw.Padding(
                                      padding: const pw.EdgeInsets.only(left: 8),
                                      child: pw.Text(
                                        '${duration}min | $period | $frequency$sessionInfo | Till: $formattedEndDate',
                                        style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            if (physioOrders.length > 10)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(left: 8, top: 2),
                                child: pw.Text(
                                  '...and ${physioOrders.length - 10} more',
                                  style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            pw.SizedBox(height: 15),
            
            // Medicine Grid - header and table as separate widgets so table can break across pages
            if (medicines.isNotEmpty) ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.purple50,
                  borderRadius: pw.BorderRadius.circular(5),
                  border: pw.Border.all(color: PdfColors.purple200, width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text(
                      'Prescribed Medications',
                      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'آپ کو ہسپتال کی فارمیسی سے درج ذیل ادویات تجویز کی گئی ہیں۔ آپ سے گزارش ہے کہ ہسپتال کی فارمیسی سے یہ ادویات مفت حاصل کریں۔',
                      style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2.2),
                        1: const pw.FlexColumnWidth(1.2),
                        2: const pw.FlexColumnWidth(1.0),
                        3: const pw.FlexColumnWidth(1.5),
                        4: const pw.FlexColumnWidth(0.6),
                        5: const pw.FlexColumnWidth(0.8),
                      },
                      children: [
                        // Header
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: PdfColors.purple100),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                'Medicine',
                                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                'Dosage',
                                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                'Route',
                                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                'Frequency',
                                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                'Qty',
                                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(
                                'Pharmacy',
                                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                  // Medicine Rows
                  ...medicines.asMap().entries.map((entry) {
                    final index = entry.key;
                    final m = entry.value;
                    final medicineName = (m['medicineName'] ?? '').toString();
                    final quantity = m['quantityOrdered'] ?? m['quantity'] ?? 0;
                    final frequency = (m['frequency'] ?? '').toString();
                    final dosage = (m['dosage'] ?? '').toString();
                    final route = (m['route'] ?? m['Route'] ?? '').toString();
                    
                    // Extract pharmacy type
                    final pharmacyType = (m['orderType'] ?? 
                                        m['order_type'] ?? 
                                        m['PharmacyType'] ?? 
                                        m['pharmacyType'] ?? 
                                        m['pharmacy_type'] ?? 
                                        'OPD').toString().toUpperCase();
                    
                    String frequencyText = frequency.isNotEmpty ? frequency : '-';
                    String dosageText = dosage.isNotEmpty ? dosage : '-';
                    String routeText = route.isNotEmpty ? route : '-';
                    
                    // Get color for pharmacy type
                    PdfColor getPharmacyTypeColor(String type) {
                      switch (type.toUpperCase()) {
                        case 'OPD':
                          return PdfColors.blue700;
                        case 'IPD':
                          return PdfColors.purple700;
                        case 'EMERGENCY':
                          return PdfColors.red700;
                        case 'OT':
                          return PdfColors.orange700;
                        case 'LABOURROOM':
                          return PdfColors.pink700;
                        default:
                          return PdfColors.grey700;
                      }
                    }
                    
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: index.isEven ? PdfColors.white : PdfColors.grey50,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            medicineName,
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.normal),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            dosageText,
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            routeText,
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            frequencyText,
                            style: const pw.TextStyle(fontSize: 8),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            quantity.toString(),
                            style: const pw.TextStyle(fontSize: 9),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: _getPharmacyTypeLightColor(pharmacyType),
                              borderRadius: pw.BorderRadius.circular(3),
                              border: pw.Border.all(color: getPharmacyTypeColor(pharmacyType), width: 0.5),
                            ),
                            child: pw.Text(
                              pharmacyType == 'EMERGENCY' ? 'ER' : pharmacyType,
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: getPharmacyTypeColor(pharmacyType),
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                      ],
                    ),
            ],
            
            pw.SizedBox(height: 20),
            
            // Footer with Urdu text
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border(
                  top: pw.BorderSide(color: PdfColors.blue700, width: 2),
                ),
              ),
              child: pw.Center(
                child: pw.Text(
                  'کسی بھی رہنمائی کی صورت میں ہیلپ لائن 1033 پر رابطہ کریں۔ شکریہ۔',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Helper methods for vitals formatting (PDF)
  pw.Widget _buildPdfVitalHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildPdfVitalCell(String? value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        value ?? '-',
        style: const pw.TextStyle(fontSize: 8),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  PdfColor _getPharmacyTypeLightColor(String type) {
    switch (type.toUpperCase()) {
      case 'OPD':
        return PdfColors.blue100;
      case 'IPD':
        return PdfColors.purple100;
      case 'EMERGENCY':
        return PdfColors.red100;
      case 'OT':
        return PdfColors.orange100;
      case 'LABOURROOM':
        return PdfColors.pink100;
      default:
        return PdfColors.grey100;
    }
  }

  String _formatBP(Map<String, dynamic> vital) {
    final systolic = vital['bpSystolic'] ?? vital['BPSystolic'] ?? vital['bloodPressureSystolic'] ?? vital['BloodPressureSystolic'] ?? vital['systolic'];
    final diastolic = vital['bpDiastolic'] ?? vital['BPDiastolic'] ?? vital['bloodPressureDiastolic'] ?? vital['BloodPressureDiastolic'] ?? vital['diastolic'];
    if (systolic != null && diastolic != null) {
      return '$systolic/$diastolic';
    }
    return '-';
  }

  String? _formatValue(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      return value.toStringAsFixed(value is double && value % 1 != 0 ? 1 : 0);
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultation Summary'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_consultationData != null)
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: _generateAndPrintPDF,
              tooltip: 'Print PDF',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading consultation data',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _consultationData == null
                  ? const Center(child: Text('No consultation data available'))
                  : _buildSummaryView(),
    );
  }

  Widget _buildSummaryView() {
    final encounterInfo = _consultationData!['encounter'] ?? {};
    final complaints = List<Map<String, dynamic>>.from(_consultationData!['complaints'] ?? []);
    final symptoms = List<Map<String, dynamic>>.from(_consultationData!['symptoms'] ?? []);
    final diagnoses = List<Map<String, dynamic>>.from(_consultationData!['diagnoses'] ?? []);
    final clinicalNotes = List<Map<String, dynamic>>.from(_consultationData!['clinicalNotes'] ?? []);
    final labOrders = List<Map<String, dynamic>>.from(_consultationData!['labOrders'] ?? []);
    final radiologyOrders = List<Map<String, dynamic>>.from(_consultationData!['radiologyOrders'] ?? []);
    final dentalProcedures = List<Map<String, dynamic>>.from(_consultationData!['dentalProcedures'] ?? []);
    final physioOrders = List<Map<String, dynamic>>.from(_consultationData!['physioOrders'] ?? []);
    final medicinesRaw = List<Map<String, dynamic>>.from(_consultationData!['medicines'] ?? []);
    // Filter out discontinued medicines
    final medicines = medicinesRaw.where((m) {
      final discontinuedDate = m['DiscontinuedDate'] ?? m['DiscountinuedDate'] ?? m['discontinuedDate'];
      final isDiscontinued = discontinuedDate != null && 
                             discontinuedDate.toString().isNotEmpty && 
                             discontinuedDate.toString() != '{}';
      return !isDiscontinued;
    }).toList();
    final packageNames = _getUniquePackageNames(labOrders);
    
    // Helper to format vitals
    String _formatBP(Map<String, dynamic> vital) {
      final systolic = vital['bpSystolic'] ?? vital['BPSystolic'] ?? vital['bloodPressureSystolic'] ?? vital['BloodPressureSystolic'] ?? vital['systolic'];
      final diastolic = vital['bpDiastolic'] ?? vital['BPDiastolic'] ?? vital['bloodPressureDiastolic'] ?? vital['BloodPressureDiastolic'] ?? vital['diastolic'];
      if (systolic != null && diastolic != null) {
        return '$systolic/$diastolic';
      }
      return '-';
    }
    
    String? _formatVitalValue(dynamic value) {
      if (value == null) return null;
      if (value is num) {
        return value.toStringAsFixed(value is double && value % 1 != 0 ? 1 : 0);
      }
      return value.toString();
    }

    final patientName = widget.patient['fullName'] ?? widget.patient['name'] ?? 'Unknown';
    final mrn = widget.patient['mrn']?.toString() ?? 'N/A';
    final contactNo = widget.patient['contactNumber']?.toString() ?? 'N/A';
    final age = widget.patient['age']?.toString() ?? 'N/A';
    final doctorName = encounterInfo['doctorName']?.toString() ?? 'N/A';
    final departmentName = _departmentName ?? encounterInfo['departmentName']?.toString() ?? widget.patient['departmentName']?.toString() ?? 'N/A';
    final hospitalName = _hospitalName ?? 'Hospital';
    final printDate = DateFormat('MMM dd, yyyy, hh:mm:ss a').format(DateTime.now());
    DateTime? createdDateTime;
    String createdDate;
    if (encounterInfo['checkInTime'] != null) {
      try {
        createdDateTime = DateTime.parse(encounterInfo['checkInTime'].toString());
        createdDate = DateFormat('MMM dd, yyyy, hh:mm:ss a').format(createdDateTime);
      } catch (e) {
        createdDate = printDate;
        createdDateTime = DateTime.now();
      }
    } else {
      createdDate = printDate;
      createdDateTime = DateTime.now();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Logo, Department, Hospital, QR Code
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Logo and Department
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'assets/images/punjab.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 8),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HEALTH & POPULATION',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'DEPARTMENT',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Center: Hospital Name
                Expanded(
                  child: Center(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          hospitalName,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        if (departmentName.isNotEmpty)
                          Text(
                            '$departmentName, OPD',
                            style: TextStyle(fontSize: 9, color: Colors.grey.shade700),
                            textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ),
                
                // Right: QR Code placeholder (using icon)
                Icon(
                  Icons.qr_code,
                  size: 40,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            Divider(color: Colors.blue.shade700, height: 2),
            const SizedBox(height: 12),
            
            // Patient and Doctor Info Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Patient Information',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Name: $patientName',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 15,
                          children: [
                            Text('MR No.: $mrn', style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                            Text('Age: $age Y', style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                            Text('Contact: $contactNo', style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Doctor Information',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        doctorName,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Created: ${createdDateTime != null ? DateFormat('MMM dd, yyyy').format(createdDateTime) : createdDate.split(',').first}',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                      ),
                      Text(
                        'Printed: ${DateFormat('MMM dd, yyyy, hh:mm a').format(DateTime.now())}',
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 15),
            
            // Vitals Section (if available)
            if (_vitals.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vital Signs',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                    ),
                    const SizedBox(height: 10),
                    Table(
                      border: TableBorder.all(color: Colors.grey.shade300, width: 1),
                      columnWidths: const {
                        0: FlexColumnWidth(1.5),
                        1: FlexColumnWidth(1),
                        2: FlexColumnWidth(1),
                        3: FlexColumnWidth(1),
                        4: FlexColumnWidth(1),
                        5: FlexColumnWidth(1),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade200),
                          children: [
                            _buildVitalHeader('BP (mmHg)'),
                            _buildVitalHeader('HR (bpm)'),
                            _buildVitalHeader('Temp (°F)'),
                            _buildVitalHeader('RR (bpm)'),
                            _buildVitalHeader('SpO2 (%)'),
                            _buildVitalHeader('Weight (kg)'),
                          ],
                        ),
                        TableRow(
                          children: [
                            _buildVitalCell(_formatBP(_vitals.first)),
                            _buildVitalCell(_formatVitalValue(_vitals.first['pulse'] ?? _vitals.first['Pulse'] ?? _vitals.first['heartRate'] ?? _vitals.first['HeartRate'])),
                            _buildVitalCell(_formatVitalValue(_vitals.first['temperature'] ?? _vitals.first['Temperature'])),
                            _buildVitalCell(_formatVitalValue(_vitals.first['respiratoryRate'] ?? _vitals.first['RespiratoryRate'])),
                            _buildVitalCell(_formatVitalValue(_vitals.first['oxygenSaturation'] ?? _vitals.first['OxygenSaturation'])),
                            _buildVitalCell(_formatVitalValue(_vitals.first['weight'] ?? _vitals.first['Weight'])),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
            ],
            
            // Two Column Table Layout
            Table(
              border: TableBorder.all(color: Colors.grey.shade300, width: 1),
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1),
              },
              children: [
                // Header Row
                TableRow(
                  decoration: BoxDecoration(color: Colors.blue.shade100),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        'Clinical Information',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        'Tests Advised',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                // Content Row
                TableRow(
                  children: [
                    // Left Column: Complaints, Symptoms, Diagnosis
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Complaints
                          if (complaints.isNotEmpty) ...[
                            Text(
                              'Chief Complaints:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                            ),
                            const SizedBox(height: 6),
                            ...complaints.map((c) {
                              final desc = (c['diagnosisName'] ?? c['icd10Description'] ?? '').toString();
                              return Padding(
                                padding: const EdgeInsets.only(left: 12, bottom: 3),
                                child: Text(
                                  '• $desc',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            }),
                            const SizedBox(height: 10),
                          ],
                          
                          // Symptoms
                          if (symptoms.isNotEmpty) ...[
                            Text(
                              'Symptoms:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                            ),
                            const SizedBox(height: 6),
                            ...symptoms.map((s) {
                              final desc = (s['diagnosisName'] ?? s['icd10Description'] ?? '').toString();
                              return Padding(
                                padding: const EdgeInsets.only(left: 12, bottom: 3),
                                child: Text(
                                  '• $desc',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            }),
                            const SizedBox(height: 10),
                          ],
                          
                          // Diagnosis
                          if (diagnoses.isNotEmpty) ...[
                            Text(
                              'Diagnosis:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                            ),
                            const SizedBox(height: 6),
                            ...diagnoses.map((d) {
                              final desc = (d['diagnosisName'] ?? d['icd10Description'] ?? '').toString();
                              final isConfirmed = d['isConfirmed'] == true;
                              return Padding(
                                padding: const EdgeInsets.only(left: 12, bottom: 3),
                                child: Row(
                                  children: [
                                    Icon(
                                      isConfirmed ? Icons.check_circle : Icons.radio_button_unchecked,
                                      size: 14,
                                      color: isConfirmed ? Colors.green.shade700 : Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        desc,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontStyle: isConfirmed ? FontStyle.normal : FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 10),
                          ],
                          
                          // Clinical Notes
                          if (clinicalNotes.isNotEmpty) ...[
                            Text(
                              'Clinical Notes:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo.shade700),
                            ),
                            const SizedBox(height: 6),
                            ...clinicalNotes.map((note) {
                              final desc = (note['description'] ?? '').toString();
                              return Padding(
                                padding: const EdgeInsets.only(left: 12, bottom: 3),
                                child: Text(
                                  desc,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                    
                    // Right Column: Lab Tests, Radiology Tests
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Lab Tests
                          if (packageNames.isNotEmpty) ...[
                            Text(
                              'Laboratory Tests:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: packageNames.map((name) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.blue.shade200, width: 1),
                                  ),
                                  child: Text(
                                    name,
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                          ],
                          
                          // Radiology Tests
                          if (radiologyOrders.isNotEmpty) ...[
                            Text(
                              'Radiology Tests:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                            ),
                            const SizedBox(height: 6),
                            ...radiologyOrders.take(10).map((r) {
                              final name = (r['testName'] ?? '').toString();
                              return Padding(
                                padding: const EdgeInsets.only(left: 12, bottom: 3),
                                child: Text(
                                  '• $name',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            }),
                            if (radiologyOrders.length > 10)
                              Padding(
                                padding: const EdgeInsets.only(left: 12, top: 2),
                                child: Text(
                                  '...and ${radiologyOrders.length - 10} more',
                                  style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                                ),
                              ),
                          ],
                          
                          // Dental Procedures
                          if (dentalProcedures.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Dental Procedures:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                            ),
                            const SizedBox(height: 6),
                            ...dentalProcedures.take(10).map((d) {
                              final name = (d['procedureName'] ?? '').toString();
                              final fee = d['fee'] ?? 0;
                              return Padding(
                                padding: const EdgeInsets.only(left: 12, bottom: 3),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '• $name',
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                    Text(
                                      'Rs $fee',
                                      style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            if (dentalProcedures.length > 10)
                              Padding(
                                padding: const EdgeInsets.only(left: 12, top: 2),
                                child: Text(
                                  '...and ${dentalProcedures.length - 10} more',
                                  style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                                ),
                              ),
                          ],
                          
                          // Physio Orders
                          if (physioOrders.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Physio Modalities:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                            ),
                            const SizedBox(height: 6),
                            ...physioOrders.take(10).map((p) {
                              final name = (p['modalityName'] ?? p['ModalityName'] ?? '').toString();
                              final duration = p['durationMinutes'] ?? p['DurationMinutes'] ?? 0;
                              final period = (p['treatmentPeriod'] ?? p['TreatmentPeriod'] ?? '').toString();
                              final frequency = (p['frequency'] ?? p['Frequency'] ?? 'Once a day').toString();
                              final totalSessions = p['totalSessions'] ?? p['TotalSessions'];
                              final endDateStr = (p['endDate'] ?? p['EndDate'] ?? '').toString();
                              String formattedEndDate = '';
                              if (endDateStr.isNotEmpty) {
                                try {
                                  final date = DateTime.parse(endDateStr);
                                  formattedEndDate = '${date.day}/${date.month}/${date.year}';
                                } catch (e) {
                                  formattedEndDate = endDateStr;
                                }
                              }
                              final sessionInfo = totalSessions != null ? ' ($totalSessions sessions)' : '';
                              return Padding(
                                padding: const EdgeInsets.only(left: 12, bottom: 3),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '• $name',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 10),
                                      child: Text(
                                        '${duration}min | $period | $frequency$sessionInfo | Till: $formattedEndDate',
                                        style: TextStyle(fontSize: 9, color: Colors.purple.shade600),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            if (physioOrders.length > 10)
                              Padding(
                                padding: const EdgeInsets.only(left: 12, top: 2),
                                child: Text(
                                  '...and ${physioOrders.length - 10} more',
                                  style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Medicine Grid
            if (medicines.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prescribed Medications',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'آپ کو ہسپتال کی فارمیسی سے درج ذیل ادویات تجویز کی گئی ہیں۔ آپ سے گزارش ہے کہ ہسپتال کی فارمیسی سے یہ ادویات مفت حاصل کریں۔',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 10),
                    Table(
                      border: TableBorder.all(color: Colors.grey.shade300, width: 1),
                      columnWidths: const {
                        0: FlexColumnWidth(2.2),
                        1: FlexColumnWidth(1.2),
                        2: FlexColumnWidth(1.0),
                        3: FlexColumnWidth(1.5),
                        4: FlexColumnWidth(0.6),
                        5: FlexColumnWidth(0.8),
                      },
                      children: [
                        // Header
                        TableRow(
                          decoration: BoxDecoration(color: Colors.purple.shade100),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                'Medicine',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                'Dosage',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                'Route',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                'Frequency',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                'Qty',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                'Pharmacy',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        // Medicine Rows
                        ...medicines.asMap().entries.map((entry) {
                          final index = entry.key;
                          final m = entry.value;
                          final medicineName = (m['medicineName'] ?? '').toString();
                          final quantity = m['quantityOrdered'] ?? m['quantity'] ?? 0;
                          final frequency = (m['frequency'] ?? '').toString();
                          final dosage = (m['dosage'] ?? '').toString();
                          final route = (m['route'] ?? m['Route'] ?? '').toString();
                          
                          // Extract pharmacy type
                          final pharmacyType = (m['orderType'] ?? 
                                              m['order_type'] ?? 
                                              m['PharmacyType'] ?? 
                                              m['pharmacyType'] ?? 
                                              m['pharmacy_type'] ?? 
                                              'OPD').toString().toUpperCase();
                          
                          // Get color for pharmacy type
                          Color getPharmacyTypeColor(String type) {
                            switch (type.toUpperCase()) {
                              case 'OPD':
                                return Colors.blue;
                              case 'IPD':
                                return Colors.purple;
                              case 'EMERGENCY':
                                return Colors.red;
                              case 'OT':
                                return Colors.orange;
                              case 'LABOURROOM':
                                return Colors.pink;
                              default:
                                return Colors.grey;
                            }
                          }
                          
                          String frequencyText = frequency.isNotEmpty ? frequency : '-';
                          String dosageText = dosage.isNotEmpty ? dosage : '-';
                          String routeText = route.isNotEmpty ? route : '-';
                          
                          return TableRow(
                            decoration: BoxDecoration(
                              color: index.isEven ? Colors.white : Colors.grey.shade50,
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(7),
                                child: Text(
                                  medicineName,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(7),
                                child: Text(
                                  dosageText,
                                  style: const TextStyle(fontSize: 10),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(7),
                                child: Text(
                                  routeText,
                                  style: const TextStyle(fontSize: 10),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(7),
                                child: Text(
                                  frequencyText,
                                  style: const TextStyle(fontSize: 10),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(7),
                                child: Text(
                                  quantity.toString(),
                                  style: const TextStyle(fontSize: 11),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(7),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: getPharmacyTypeColor(pharmacyType).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: getPharmacyTypeColor(pharmacyType),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      pharmacyType == 'EMERGENCY' ? 'ER' : pharmacyType,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: getPharmacyTypeColor(pharmacyType),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Footer with Urdu text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  top: BorderSide(color: Colors.blue.shade700, width: 2),
                ),
              ),
              child: Center(
                child: Text(
                  'کسی بھی رہنمائی کی صورت میں ہیلپ لائن 1033 پر رابطہ کریں۔ شکریہ۔',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildVitalCell(String? value) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        value ?? '-',
        style: const TextStyle(fontSize: 10),
        textAlign: TextAlign.center,
      ),
    );
  }
}

