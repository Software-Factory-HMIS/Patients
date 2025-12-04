class Hospital {
  final int hospitalID;
  final String name;
  final String? type;
  final String? subtype;
  final bool isActive;
  final String? division;
  final String? district;
  final String? tehsil;

  Hospital({
    required this.hospitalID,
    required this.name,
    this.type,
    this.subtype,
    required this.isActive,
    this.division,
    this.district,
    this.tehsil,
  });

  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(
      hospitalID: json['HospitalID'] as int? ?? json['hospitalID'] as int? ?? 0,
      name: json['Name'] as String? ?? json['name'] as String? ?? '',
      type: json['Type'] as String? ?? json['type'] as String?,
      subtype: json['Subtype'] as String? ?? json['subtype'] as String?,
      isActive: json['IsActive'] as bool? ?? json['isActive'] as bool? ?? true,
      division: json['Division'] as String? ?? json['division'] as String?,
      district: json['District'] as String? ?? json['district'] as String?,
      tehsil: json['Tehsil'] as String? ?? json['tehsil'] as String?,
    );
  }

  String get location {
    final parts = <String>[];
    if (division != null && division!.isNotEmpty) parts.add(division!);
    if (district != null && district!.isNotEmpty) parts.add(district!);
    if (tehsil != null && tehsil!.isNotEmpty) parts.add(tehsil!);
    return parts.isEmpty ? 'Location not specified' : parts.join(', ');
  }
}

class Department {
  final int departmentID;
  final String name;
  final String? description;
  final bool isActive;
  final int hospitalCount;

  Department({
    required this.departmentID,
    required this.name,
    this.description,
    required this.isActive,
    required this.hospitalCount,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      departmentID: json['DepartmentID'] as int? ?? json['departmentID'] as int? ?? 0,
      name: json['Name'] as String? ?? json['name'] as String? ?? '',
      description: json['Description'] as String? ?? json['description'] as String?,
      isActive: json['IsActive'] as bool? ?? json['isActive'] as bool? ?? true,
      hospitalCount: json['HospitalCount'] as int? ?? json['hospitalCount'] as int? ?? 0,
    );
  }
}

class QueueResponse {
  final int queueId;
  final String tokenNumber;

  QueueResponse({
    required this.queueId,
    required this.tokenNumber,
  });

  factory QueueResponse.fromJson(Map<String, dynamic> json) {
    return QueueResponse(
      queueId: json['queueId'] as int? ?? json['QueueID'] as int,
      tokenNumber: json['tokenNumber'] as String? ?? json['TokenNumber'] as String,
    );
  }
}

class AppointmentDetails {
  final QueueResponse queueResponse;
  final Hospital hospital;
  final Department department;
  final String patientName;
  final String patientMRN;
  final DateTime appointmentDate;
  final int? queuePosition;
  final String? estimatedWaitTime;
  final Map<String, dynamic>? receiptData; // Receipt data from print API

  AppointmentDetails({
    required this.queueResponse,
    required this.hospital,
    required this.department,
    required this.patientName,
    required this.patientMRN,
    required this.appointmentDate,
    this.queuePosition,
    this.estimatedWaitTime,
    this.receiptData,
  });
}

