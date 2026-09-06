import '../utils/app_date_format.dart';

class HomeStats {
  final int visitCount;
  final int activePrescriptions;
  final int labResults;
  final int radiologyReports;
  final LabResultsSummary labSummary;
  final RadiologySummary radiologySummary;

  const HomeStats({
    this.visitCount = 0,
    this.activePrescriptions = 0,
    this.labResults = 0,
    this.radiologyReports = 0,
    this.labSummary = const LabResultsSummary(),
    this.radiologySummary = const RadiologySummary(),
  });
}

class LabResultsSummary {
  final int total;
  final int normal;
  final int elevated;
  final int critical;
  final int pending;
  final String? lastDate;
  final String? firstDate;

  const LabResultsSummary({
    this.total = 0,
    this.normal = 0,
    this.elevated = 0,
    this.critical = 0,
    this.pending = 0,
    this.lastDate,
    this.firstDate,
  });

  factory LabResultsSummary.fromJson(Map<String, dynamic> json) {
    return LabResultsSummary(
      total: _asInt(json['totalResults']),
      normal: _asInt(json['normalResults']),
      elevated: _asInt(json['elevatedResults']),
      critical: _asInt(json['criticalResults']),
      pending: _asInt(json['pendingResults']),
      lastDate: AppDateFormat.formatDateOrNull(json['lastResultDate']),
      firstDate: AppDateFormat.formatDateOrNull(json['firstResultDate']),
    );
  }

  /// Client-side summary when the API summary is empty/missing.
  factory LabResultsSummary.fromReports(List<LabReport> reports) {
    var normal = 0, elevated = 0, critical = 0, pending = 0;
    String? lastDate;
    String? firstDate;
    for (final r in reports) {
      if (!r.hasResult) {
        pending++;
      } else if (r.isCritical) {
        critical++;
      } else {
        final status = (r.status ?? '').toLowerCase();
        final flags = (r.abnormalFlags ?? '').toLowerCase();
        if (status.contains('abnormal') ||
            status.contains('high') ||
            status.contains('low') ||
            status.contains('elevated') ||
            flags == 'h' ||
            flags == 'l' ||
            flags == 'a') {
          elevated++;
        } else {
          normal++;
        }
      }
      final d = r.date;
      if (d != null && d.isNotEmpty) {
        lastDate ??= d;
        firstDate = d;
      }
    }
    return LabResultsSummary(
      total: reports.length,
      normal: normal,
      elevated: elevated,
      critical: critical,
      pending: pending,
      lastDate: lastDate,
      firstDate: firstDate,
    );
  }

  bool get hasAbnormal => elevated > 0 || critical > 0;
}

class RadiologySummary {
  final int total;
  final int finalReports;
  final int pending;
  final String? lastDate;
  final String? firstDate;

  const RadiologySummary({
    this.total = 0,
    this.finalReports = 0,
    this.pending = 0,
    this.lastDate,
    this.firstDate,
  });

  factory RadiologySummary.fromJson(Map<String, dynamic> json) {
    return RadiologySummary(
      total: _asInt(json['totalReports']),
      finalReports: _asInt(json['finalReports']),
      pending: _asInt(json['pendingReports']),
      lastDate: AppDateFormat.formatDateOrNull(json['lastReportDate']),
      firstDate: AppDateFormat.formatDateOrNull(json['firstReportDate']),
    );
  }

  /// Client-side summary when the API summary is empty/missing.
  factory RadiologySummary.fromReports(List<RadiologyReport> reports) {
    var finals = 0;
    String? lastDate;
    String? firstDate;
    for (final r in reports) {
      if (r.hasReportText) finals++;
      final d = r.displayDate;
      if (d != null && d.isNotEmpty) {
        lastDate ??= d;
        firstDate = d;
      }
    }
    return RadiologySummary(
      total: reports.length,
      finalReports: finals,
      pending: reports.length - finals,
      lastDate: lastDate,
      firstDate: firstDate,
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class LabReport {
  final String test;
  final String? result;
  final String? normalRange;
  final String? status;
  final String? date;
  final String? orderedBy;
  final String? abnormalFlags;
  final int? resultId;
  final int? sampleId;
  final int? testId;
  final bool isCritical;

  LabReport({
    required this.test,
    this.result,
    this.normalRange,
    this.status,
    this.date,
    this.orderedBy,
    this.abnormalFlags,
    this.resultId,
    this.sampleId,
    this.testId,
    this.isCritical = false,
  });

  factory LabReport.fromJson(Map<String, dynamic> json) {
    return LabReport(
      test: json['test']?.toString() ?? 'Unknown test',
      result: json['result']?.toString(),
      normalRange:
          json['normalRange']?.toString() ?? json['Normal Range']?.toString(),
      status: json['status']?.toString(),
      date: AppDateFormat.formatDateOrNull(json['date'] ?? json['sampleDate']),
      orderedBy:
          json['orderedBy']?.toString() ?? json['Ordered By']?.toString(),
      abnormalFlags: json['abnormalFlags']?.toString(),
      resultId: _asIntOrNull(json['resultId']),
      sampleId: _asIntOrNull(json['sampleId']),
      testId: _asIntOrNull(json['testId']),
      isCritical: json['isCritical'] == true,
    );
  }

  bool get hasResult =>
      (result != null && result!.trim().isNotEmpty) || resultId != null;
}

class RadiologyReport {
  final String testName;
  final String? orderDate;
  final String? finalReportDate;
  final String? findings;
  final String? impression;
  final String? radiologist;
  final String? recommendations;
  final int? orderId;
  final int? orderDetailId;
  final int? reportId;
  final String? orderNumber;

  RadiologyReport({
    required this.testName,
    this.orderDate,
    this.finalReportDate,
    this.findings,
    this.impression,
    this.radiologist,
    this.recommendations,
    this.orderId,
    this.orderDetailId,
    this.reportId,
    this.orderNumber,
  });

  factory RadiologyReport.fromJson(Map<String, dynamic> json) {
    return RadiologyReport(
      testName:
          json['testName']?.toString() ??
          json['procedure']?.toString() ??
          'Radiology study',
      orderDate: AppDateFormat.formatDateOrNull(
        json['orderDate'] ?? json['date'],
      ),
      finalReportDate: AppDateFormat.formatDateOrNull(json['finalReportDate']),
      findings:
          json['finalFindings']?.toString() ?? json['findings']?.toString(),
      impression: json['impression']?.toString(),
      radiologist:
          json['radiologist_Name']?.toString() ??
          json['radiologist']?.toString(),
      recommendations: json['recommendations']?.toString(),
      orderId: _asIntOrNull(json['orderId']),
      orderDetailId: _asIntOrNull(json['orderDetailId']),
      reportId: _asIntOrNull(json['reportId']),
      orderNumber: json['orderNumber']?.toString(),
    );
  }

  bool get hasReportText =>
      (findings != null && findings!.trim().isNotEmpty) ||
      (impression != null && impression!.trim().isNotEmpty);

  String? get displayDate => finalReportDate ?? orderDate;
}

int? _asIntOrNull(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

class PrescriptionItem {
  final String medication;
  final String? salt;
  final String? dosage;
  final String? frequency;
  final String? duration;
  final String? indication;
  final String? prescriber;
  final String? status;
  final String? startDate;
  final String? endDate;
  final String? discontinuedDate;

  PrescriptionItem({
    required this.medication,
    this.salt,
    this.dosage,
    this.frequency,
    this.duration,
    this.indication,
    this.prescriber,
    this.status,
    this.startDate,
    this.endDate,
    this.discontinuedDate,
  });

  factory PrescriptionItem.fromJson(Map<String, dynamic> json) {
    final dosageAmount =
        json['dosageAmount'] ??
        json['dosageValue'] ??
        json['dosage'] ??
        json['Dosage'];
    final dosageUnit = json['dosageUnit'] ?? json['DosageUnit'];
    final dosageText = _formatDosage(dosageAmount, dosageUnit);

    return PrescriptionItem(
      medication:
          json['medication']?.toString() ??
          json['Medication']?.toString() ??
          json['medicineName']?.toString() ??
          json['MedicineName']?.toString() ??
          json['name']?.toString() ??
          'Medicine',
      salt:
          json['salt']?.toString() ??
          json['Salt']?.toString() ??
          json['SaltName']?.toString(),
      dosage: dosageText,
      frequency: json['frequency']?.toString() ?? json['Frequency']?.toString(),
      duration: json['duration']?.toString() ?? json['Duration']?.toString(),
      indication:
          json['indication']?.toString() ?? json['Indication']?.toString(),
      prescriber:
          json['prescriber']?.toString() ?? json['Prescriber']?.toString(),
      status: json['status']?.toString() ?? json['Status']?.toString(),
      startDate: AppDateFormat.formatDateOrNull(
        json['startDate'] ?? json['StartDate'],
      ),
      endDate: AppDateFormat.formatDateOrNull(
        json['endDate'] ?? json['EndDate'],
      ),
      discontinuedDate: AppDateFormat.formatDateOrNull(
        json['discontinuedDate'] ?? json['DiscontinuedDate'],
      ),
    );
  }

  bool get isDiscontinued {
    if (discontinuedDate != null && discontinuedDate!.isNotEmpty) return true;
    final s = (status ?? '').toLowerCase();
    return s.contains('discontinu') ||
        s.contains('stopped') ||
        s.contains('cancel') ||
        s.contains('inactive');
  }

  bool get isActive {
    if (isDiscontinued) return false;

    final s = (status ?? '').toLowerCase();
    if (s.contains('discontinu') ||
        s.contains('stopped') ||
        s.contains('cancel') ||
        s.contains('completed') ||
        s.contains('inactive')) {
      return false;
    }

    if (endDate != null && endDate!.isNotEmpty) {
      final end = DateTime.tryParse(endDate!) ?? _parseDdMmYyyy(endDate!);
      if (end != null) {
        final today = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
        );
        final endDay = DateTime(end.year, end.month, end.day);
        if (endDay.isBefore(today)) return false;
      }
    }

    if (s.contains('active') || s.contains('current')) return true;

    // Active-medicines API already filters server-side; treat as active when not discontinued/expired.
    return discontinuedDate == null || discontinuedDate!.isEmpty;
  }
}

String? _formatDosage(dynamic amount, dynamic unit) {
  var amountText = amount?.toString().trim() ?? '';
  if (amountText.isEmpty) return null;

  // Collapse "400mg mg" / "400 mg mg" style duplicates in preformatted values.
  amountText = amountText.replaceFirstMapped(
    RegExp(r'([a-zA-Z%µμ/]+)\s+\1$', caseSensitive: false),
    (m) => m.group(1)!,
  );

  final unitText = unit?.toString().trim() ?? '';
  if (unitText.isEmpty) return amountText;

  final lowerAmount = amountText.toLowerCase();
  final lowerUnit = unitText.toLowerCase();
  if (lowerAmount == lowerUnit ||
      lowerAmount.endsWith(lowerUnit) ||
      lowerAmount.endsWith(' $lowerUnit') ||
      lowerAmount.contains(lowerUnit)) {
    return amountText;
  }

  // Amount already has a unit suffix (e.g. "400mg", "5 ml").
  if (RegExp(r'\d\s*[a-zA-Z%µμ/]+$').hasMatch(amountText)) {
    return amountText;
  }

  return '$amountText $unitText';
}

DateTime? _parseDdMmYyyy(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}
