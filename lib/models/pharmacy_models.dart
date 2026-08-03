class Patient {
  final int patientId;
  final String mrn;
  final String firstName;
  final String lastName;
  final String cnic;
  final String contactNumber;
  final String dateOfBirth;
  final String gender;
  final String address;
  final int pendingOrdersCount;
  final String lastOrderDate;
  final String tokenNumber;

  Patient({
    required this.patientId,
    required this.mrn,
    required this.firstName,
    required this.lastName,
    required this.cnic,
    required this.contactNumber,
    required this.dateOfBirth,
    required this.gender,
    required this.address,
    required this.pendingOrdersCount,
    required this.lastOrderDate,
    required this.tokenNumber,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    String safeString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      if (value is Map && value.isEmpty) return '';
      return value.toString();
    }
    int safeInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is Map && value.isEmpty) return 0;
      if (value is String && value.isNotEmpty) return int.tryParse(value) ?? 0;
      return 0;
    }

    String fullNameStr = safeString(json['FullName'] ?? json['fullName'] ?? json['full_name']);
    String firstNameStr = safeString(json['FirstName'] ?? json['firstName'] ?? json['first_name'] ?? json['name']);
    String lastNameStr = safeString(json['LastName'] ?? json['lastName'] ?? json['last_name'] ?? '');
    String finalFirstName = firstNameStr;
    String finalLastName = lastNameStr;
    if (fullNameStr.isNotEmpty && firstNameStr.isEmpty && lastNameStr.isEmpty) {
      final parts = fullNameStr.trim().split(' ');
      finalFirstName = parts.isNotEmpty ? parts.first : '';
      finalLastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    } else if (fullNameStr.isEmpty && firstNameStr.isEmpty && lastNameStr.isEmpty) {
      final nameStr = safeString(json['name'] ?? json['Name']);
      if (nameStr.isNotEmpty) {
        final parts = nameStr.trim().split(' ');
        finalFirstName = parts.isNotEmpty ? parts.first : '';
        finalLastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }
    }

    return Patient(
      patientId: safeInt(json['PatientID'] ?? json['patientId'] ?? json['patient_id']),
      mrn: safeString(json['MRN'] ?? json['mrn']),
      firstName: finalFirstName,
      lastName: finalLastName,
      cnic: safeString(json['CNIC'] ?? json['cnic']),
      contactNumber: safeString(json['ContactNumber'] ?? json['contactNumber'] ?? json['contact_number'] ?? json['phone']),
      dateOfBirth: safeString(json['DateOfBirth'] ?? json['dateOfBirth'] ?? json['date_of_birth'] ?? json['dob']),
      gender: safeString(json['Gender'] ?? json['gender']),
      address: safeString(json['Address'] ?? json['address']),
      pendingOrdersCount: safeInt(json['PendingOrdersCount'] ?? json['pendingOrdersCount'] ?? json['pending_orders_count']),
      lastOrderDate: safeString(json['LastOrderDate'] ?? json['lastOrderDate'] ?? json['last_order_date']),
      tokenNumber: safeString(json['TokenNumber'] ?? json['tokenNumber'] ?? json['token_number']),
    );
  }

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isNotEmpty ? name : 'Unknown Patient';
  }

  int get age {
    if (dateOfBirth.isEmpty) return 0;
    try {
      final birthDate = DateTime.parse(dateOfBirth);
      final now = DateTime.now();
      int a = now.year - birthDate.year;
      if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) a--;
      return a;
    } catch (_) {
      return 0;
    }
  }
}

class Order {
  final int orderId;
  final String orderNumber;
  final String orderDate;
  final String status;
  final String priority;
  final String orderType;
  final String notes;
  final String prescribedByDoctor;
  final int totalItems;
  final int totalQuantityOrdered;
  final int totalQuantityDispensed;
  final String dispensingStatus;
  final String? dispensedTime;
  final String? dispensedByUser;
  final String? diagnosisSummary;
  final int? encounterId;

  Order({
    required this.orderId,
    required this.orderNumber,
    required this.orderDate,
    required this.status,
    required this.priority,
    required this.orderType,
    required this.notes,
    required this.prescribedByDoctor,
    required this.totalItems,
    required this.totalQuantityOrdered,
    required this.totalQuantityDispensed,
    required this.dispensingStatus,
    this.dispensedTime,
    this.dispensedByUser,
    this.diagnosisSummary,
    this.encounterId,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    String safeString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      if (value is Map && value.isEmpty) return '';
      return value.toString();
    }
    int safeInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is Map && value.isEmpty) return 0;
      if (value is String && value.isNotEmpty) return int.tryParse(value) ?? 0;
      return 0;
    }
    int? parsedEncounterId;
    final encIdRaw = json['EncounterID'] ?? json['encounterId'] ?? json['encounter_id'] ?? json['encounterID'];
    if (encIdRaw != null) {
      parsedEncounterId = encIdRaw is int ? encIdRaw : int.tryParse(encIdRaw.toString());
    }
    return Order(
      orderId: safeInt(json['order_id']),
      orderNumber: safeString(json['order_number']),
      orderDate: safeString(json['order_date']),
      status: safeString(json['status']),
      priority: safeString(json['priority']),
      orderType: safeString(json['order_type']),
      notes: safeString(json['notes']),
      prescribedByDoctor: safeString(json['PrescribedByDoctor']),
      totalItems: safeInt(json['TotalItems']),
      totalQuantityOrdered: safeInt(json['TotalQuantityOrdered']),
      totalQuantityDispensed: safeInt(json['TotalQuantityDispensed']),
      dispensingStatus: safeString(json['DispensingStatus']),
      dispensedTime: json['DispensedTime'] != null && json['DispensedTime'].toString().isNotEmpty ? safeString(json['DispensedTime']) : null,
      dispensedByUser: json['DispensedByUser'] != null && json['DispensedByUser'].toString().isNotEmpty ? safeString(json['DispensedByUser']) : null,
      diagnosisSummary: json['DiagnosisSummary'] != null && json['DiagnosisSummary'].toString().isNotEmpty ? safeString(json['DiagnosisSummary']) : (json['diagnosis_summary'] != null && json['diagnosis_summary'].toString().isNotEmpty ? safeString(json['diagnosis_summary']) : null),
      encounterId: parsedEncounterId,
    );
  }
}

class OrderItem {
  final int orderItemId;
  final int orderId;
  final int medicineId;
  final int saltId;
  final int quantityOrdered;
  final int quantityDispensed;
  final double? dosage;
  final int duration;
  final String instructions;
  final String dosageUnit;
  final int timesPerDay;
  final String mealTiming;
  final String route;
  final String durationUnit;
  final int totalQuantityToDispense;
  final String dispensingUnit;
  final int medicineItemId;
  final String medicineName;
  final String medicineForm;
  final String medicineStrength;
  final String packSize;
  final double unitPrice;
  final String manufacturer;
  final String saltName;
  final double availableQuantity;
  final String batchNumber;
  final int remainingToDispense;
  final String stockStatus;

  OrderItem({
    required this.orderItemId,
    required this.orderId,
    required this.medicineId,
    required this.saltId,
    required this.quantityOrdered,
    required this.quantityDispensed,
    required this.dosage,
    required this.duration,
    required this.instructions,
    required this.dosageUnit,
    required this.timesPerDay,
    required this.mealTiming,
    required this.route,
    required this.durationUnit,
    required this.totalQuantityToDispense,
    required this.dispensingUnit,
    required this.medicineItemId,
    required this.medicineName,
    required this.medicineForm,
    required this.medicineStrength,
    required this.packSize,
    required this.unitPrice,
    required this.manufacturer,
    required this.saltName,
    required this.availableQuantity,
    required this.batchNumber,
    required this.remainingToDispense,
    required this.stockStatus,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    String safeString(dynamic value) {
      if (value == null) return '';
      if (value is String) return value;
      if (value is Map && value.isEmpty) return '';
      return value.toString();
    }
    int safeInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is Map && value.isEmpty) return 0;
      if (value is String && value.isNotEmpty) return int.tryParse(value) ?? 0;
      return 0;
    }
    double safeDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is Map && value.isEmpty) return 0.0;
      if (value is String && value.isNotEmpty) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }
    return OrderItem(
      orderItemId: safeInt(json['order_item_id']),
      orderId: safeInt(json['order_id']),
      medicineId: safeInt(json['medicine_id']),
      saltId: safeInt(json['salt_id']),
      quantityOrdered: safeInt(json['quantity_ordered']),
      quantityDispensed: safeInt(json['quantity_dispensed']),
      dosage: json['dosage'] != null ? safeDouble(json['dosage']) : null,
      duration: safeInt(json['duration']),
      instructions: safeString(json['instructions']),
      dosageUnit: safeString(json['DosageUnit']),
      timesPerDay: safeInt(json['TimesPerDay']),
      mealTiming: safeString(json['MealTiming']),
      route: safeString(json['Route']),
      durationUnit: safeString(json['DurationUnit']),
      totalQuantityToDispense: safeInt(json['total_quantity_to_dispense']),
      dispensingUnit: safeString(json['dispensing_unit']),
      medicineItemId: safeInt(json['MedicineItemID']),
      medicineName: safeString(json['MedicineName']),
      medicineForm: safeString(json['MedicineForm']),
      medicineStrength: safeString(json['MedicineStrength']),
      packSize: safeString(json['PackSize']),
      unitPrice: safeDouble(json['UnitPrice']),
      manufacturer: safeString(json['Manufacturer']),
      saltName: safeString(json['SaltName']),
      availableQuantity: safeDouble(json['AvailableQuantity']),
      batchNumber: safeString(json['BatchNumber']),
      remainingToDispense: safeInt(json['RemainingToDispense']),
      stockStatus: safeString(json['StockStatus']),
    );
  }
}

class DispensingItem {
  final int orderItemId;
  final int itemId;
  final String batchNumber;
  final double quantityDispensed;
  final double unitPrice;
  final double dosageAmount;
  final int frequencyId;
  final int duration;
  final String durationUnit;
  final String instructions;
  final bool isSubstitute;
  final String substituteReason;

  DispensingItem({
    required this.orderItemId,
    required this.itemId,
    required this.batchNumber,
    required this.quantityDispensed,
    required this.unitPrice,
    required this.dosageAmount,
    required this.frequencyId,
    required this.duration,
    required this.durationUnit,
    required this.instructions,
    required this.isSubstitute,
    required this.substituteReason,
  });

  Map<String, dynamic> toJson() {
    return {
      'orderItemId': orderItemId,
      'itemId': itemId,
      'batchNumber': batchNumber,
      'quantityDispensed': quantityDispensed,
      'unitPrice': unitPrice,
      'dosageAmount': dosageAmount,
      'frequencyId': frequencyId,
      'duration': duration,
      'durationUnit': durationUnit,
      'instructions': instructions,
      'isSubstitute': isSubstitute,
      'substituteReason': substituteReason,
    };
  }
}

class PharmacyLocation {
  final int locationId;
  final String locationName;
  final String locationCode;
  final String locationType;
  final bool isActive;
  final int totalItems;
  final double totalStock;

  PharmacyLocation({
    required this.locationId,
    required this.locationName,
    required this.locationCode,
    required this.locationType,
    required this.isActive,
    required this.totalItems,
    required this.totalStock,
  });

  factory PharmacyLocation.fromJson(Map<String, dynamic> json) {
    return PharmacyLocation(
      locationId: json['LocationID'] ?? 0,
      locationName: json['LocationName'] ?? '',
      locationCode: json['LocationCode'] ?? '',
      locationType: json['LocationType'] ?? '',
      isActive: json['IsActive'] ?? false,
      totalItems: json['TotalItems'] ?? 0,
      totalStock: (json['TotalStock'] ?? 0).toDouble(),
    );
  }
}
