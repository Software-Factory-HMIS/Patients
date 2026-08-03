// File: lib/services/pregnancy_service.dart
// Location: lib/services/

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class PregnancyService {

  // Helper method for API calls that return Maps
  Future<Map<String, dynamic>?> _get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.pregnancyEndpoint}$endpoint'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        // Check if response body is empty before parsing
        if (response.body.trim().isEmpty) {
          return null;
        }
        final decoded = json.decode(response.body);
        return decoded is Map<String, dynamic> ? decoded : null;
      }
      return null;
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  // Helper method for API calls that return Lists
  Future<List<dynamic>?> _getList(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.pregnancyEndpoint}$endpoint'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        // Check if response body is empty before parsing
        if (response.body.trim().isEmpty) {
          return [];
        }
        final decoded = json.decode(response.body);
        return decoded is List ? decoded : [];
      }
      return [];
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.pregnancyEndpoint}$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      }
      throw Exception('Failed to save data');
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  Future<Map<String, dynamic>> _put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.pregnancyEndpoint}$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to update data');
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  // API 1: Get Active Pregnancy
  // Purpose: Retrieves active pregnancy record for a patient to check if already pregnant
  // and populate form with existing data. Returns null if no active pregnancy exists.
  // Output: { "pregnancyId": 123, "lmpDate": "2024-10-01", "eddDate": "2025-07-08",
  //           "gravida": 2, "para": 1, "husbandName": "John Doe", ... }
  Future<Map<String, dynamic>?> getActivePregnancy(int patientId) async {
    return await _get('/pregnancy/active/$patientId');
  }

  // API 2: Get Recent Delivery
  // Purpose: Checks if patient had a delivery within last 25 days to show warning
  // before registering new pregnancy. Returns delivery date or null.
  // Output: { "deliveryDate": "2024-09-25", "daysSince": 21 }
  Future<DateTime?> getRecentDelivery(int patientId) async {
    final response = await _get('/pregnancy/recent-delivery/$patientId');
    if (response != null && response['deliveryDate'] != null) {
      return DateTime.parse(response['deliveryDate']);
    }
    return null;
  }

  // API 3: Get Patient by CNIC
  // Purpose: Fetches patient details when husband CNIC is entered to auto-populate
  // husband name if he exists as a patient in system.
  // Output: { "patientId": 456, "fullName": "Ali Ahmed", "cnic": "3520212345678" }
  Future<Map<String, dynamic>?> getPatientByCNIC(String cnic) async {
    return await _get('/patients/by-cnic/$cnic');
  }

  // API 4: Save Pregnancy Record
  // Purpose: Creates new pregnancy record or updates existing one with basic info,
  // obstetric history, and husband details. Returns pregnancyId for subsequent saves.
  // Output: { "pregnancyId": 123, "success": true, "message": "Pregnancy record saved" }
  Future<Map<String, dynamic>> savePregnancyRecord(
    Map<String, dynamic> data,
  ) async {
    if (data.containsKey('pregnancyId') && data['pregnancyId'] != null) {
      return await _put('/${data['pregnancyId']}', data);
    }
    return await _post('/pregnancy', data);
  }

  // API 4.1: Update Pregnancy Record (for delivery completion)
  // Purpose: Updates pregnancy record after delivery completion to mark as completed
  // and set outcome, delivery date, and IsActive flag
  // Output: { "success": true, "message": "Pregnancy record updated" }
  Future<Map<String, dynamic>> updatePregnancyRecord(
    Map<String, dynamic> data,
  ) async {
    return await _put('/pregnancy/outcome/${data['PregnancyID']}', data);
  }

  // API 4.2: Get Pregnancy Outcome
  // Purpose: Retrieves pregnancy outcome information for a specific pregnancy
  // Output: { "pregnancyId": 123, "pregnancyStatus": "completed", "pregnancyOutcome": "live_birth", ... }
  Future<Map<String, dynamic>?> getPregnancyOutcome(int pregnancyId) async {
    return await _get('/pregnancy/outcome/$pregnancyId');
  }

  // API 4.3: Get Pregnancy Outcomes by Patient
  // Purpose: Retrieves all pregnancy outcomes for a specific patient
  // Output: [{ "pregnancyId": 123, "pregnancyOutcome": "live_birth", ... }, ...]
  Future<List<Map<String, dynamic>>> getPregnancyOutcomesByPatient(int patientId) async {
    final result = await _get('/pregnancy/outcomes/patient/$patientId');
    if (result != null && result is List) {
      return List<Map<String, dynamic>>.from(result as List);
    }
    return [];
  }

  // API 5: Save Patient Demographics
  // Purpose: Saves or updates patient demographic information including education,
  // socioeconomic status, employment details for the pregnancy registration.
  // Output: { "demographicsId": 789, "success": true }
  Future<Map<String, dynamic>> savePatientDemographics(
    Map<String, dynamic> data,
  ) async {
    return await _post('/patient-demographics', data);
  }

  // API 6: Get Chronic Conditions List
  // Purpose: Retrieves list of all available chronic conditions from master table
  // to populate dropdown for adding new conditions.
  // Output: { "conditions": [{"conditionId": 1, "conditionName": "Diabetes",
  //           "icd11Code": "5A10", "canBePregnancyRelated": true}, ...] }
  Future<List<Map<String, dynamic>>> getChronicConditionsList() async {
    final response = await _get('/chronic-conditions/list');
    return List<Map<String, dynamic>>.from(response?['conditions'] ?? []);
  }

  // API 7: Get Patient Chronic Conditions
  // Purpose: Retrieves all chronic conditions already recorded for this patient
  // to display in the grid on chronic conditions tab.
  // Output: { "conditions": [{"patientConditionId": 10, "conditionName": "Hypertension",
  //           "severity": "Moderate", "diagnosedDate": "2023-05-15", ...}, ...] }
  Future<List<Map<String, dynamic>>> getPatientChronicConditions(
    int patientId,
  ) async {
    final response = await _get('/patient-chronic-conditions/$patientId');
    return List<Map<String, dynamic>>.from(response?['conditions'] ?? []);
  }

  // API 8: Save Patient Chronic Condition
  // Purpose: Adds new chronic condition for patient with severity, diagnosis date,
  // pregnancy relation flag and other clinical details.
  // Output: { "patientConditionId": 25, "success": true }
  Future<Map<String, dynamic>> savePatientChronicCondition(
    Map<String, dynamic> data,
  ) async {
    if (data.containsKey('patientConditionId') &&
        data['patientConditionId'] != null) {
      return await _put(
        '/patient-chronic-conditions/${data['patientConditionId']}',
        data,
      );
    }
    return await _post('/patient-chronic-conditions', data);
  }

  // API 9: Get Surgery Types List
  // Purpose: Retrieves master list of all surgery types to populate dropdown
  // when adding previous surgery history for the patient.
  // Output: { "surgeries": [{"surgeryId": 5, "surgeryName": "Cesarean Section",
  //           "surgeryCategory": "Obstetric", "department": "Gynecology"}, ...] }
  Future<List<Map<String, dynamic>>> getSurgeryTypesList() async {
    final response = await _get('/surgery-types/list');
    return List<Map<String, dynamic>>.from(response?['surgeries'] ?? []);
  }

  // API 10: Get Patient Surgeries
  // Purpose: Retrieves all previous surgeries recorded for patient to display
  // in data table on surgeries tab.
  // Output: { "surgeries": [{"patientSurgeryId": 15, "surgeryName": "Appendectomy",
  //           "surgeryCategory": "General", "surgeryDate": "2020-03-12",
  //           "procedureOutcome": "Successful"}, ...] }
  Future<List<Map<String, dynamic>>> getPatientSurgeries(int patientId) async {
    final response = await _get('/patient-surgeries/$patientId');
    return List<Map<String, dynamic>>.from(response?['surgeries'] ?? []);
  }

  // API 11: Save Patient Surgery
  // Purpose: Records new previous surgery for patient with date and outcome details.
  // Output: { "patientSurgeryId": 30, "success": true }
  Future<Map<String, dynamic>> savePatientSurgery(
    Map<String, dynamic> data,
  ) async {
    return await _post('/patient-surgeries', data);
  }

  // API 12: Get Allergy Types List
  // Purpose: Retrieves master list of allergy types to populate dropdown
  // when adding new allergy for patient.
  // Output: { "allergyTypes": ["Drug Allergy", "Food Allergy", "Environmental", ...] }
  Future<List<String>> getAllergyTypesList() async {
    final response = await _get('/allergy-types/list');
    return List<String>.from(response?['allergyTypes'] ?? []);
  }

  // API 13: Get Patient Allergies
  // Purpose: Retrieves all allergies recorded for patient to display on allergies tab.
  // Output: { "allergies": [{"patientAllergyId": 8, "allergyName": "Penicillin",
  //           "allergyType": "Drug Allergy", "severity": "Severe",
  //           "reactionDescription": "Rash and swelling"}, ...] }
  Future<List<Map<String, dynamic>>> getPatientAllergies(int patientId) async {
    final response = await _get('/patient-allergies/$patientId');
    return List<Map<String, dynamic>>.from(response?['allergies'] ?? []);
  }

  // API 14: Save Patient Allergy
  // Purpose: Adds new allergy record for patient with type, name, severity details.
  // Output: { "patientAllergyId": 12, "success": true }
  Future<Map<String, dynamic>> savePatientAllergy(
    Map<String, dynamic> data,
  ) async {
    return await _post('/patient-allergies', data);
  }

  // API 15: Get Pregnancy History
  // Purpose: Retrieves all previous pregnancy outcomes for patient to display
  // on pregnancy history tab. Validates max 15 total outcomes per patient.
  // Output: { "history": [{"id": 45, "pregnancyNumber": 1, "weeksOfGestation": 38,
  //           "modeOfDelivery": "Normal_Vaginal", "laborOnsetType": "Spontaneous",
  //           "complications": "ANC", "stillAlive": "Yes"}, ...] }
  Future<List<Map<String, dynamic>>> getPregnancyHistory(int patientId) async {
    final response = await _get('/pregnancy-history/$patientId');
    return List<Map<String, dynamic>>.from(response?['history'] ?? []);
  }

  /// Get pregnancy records from Pregnancy.Pregnancy_Records (LMP, EDD, Gravida, Para, status, outcome, etc.)
  Future<List<Map<String, dynamic>>> getPregnancyRecordsByPatient(int patientId) async {
    try {
      final response = await _get('/PregnancyRecords/getPregnancyRecordsByPatient/$patientId');
      final data = response?['data'];
      if (data == null || data is! List) return [];
      return List<Map<String, dynamic>>.from(data.map((e) => Map<String, dynamic>.from(e as Map)));
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  // API 16: Save Pregnancy History
  // Purpose: Records previous pregnancy outcome with year, gestation weeks, delivery mode,
  // anesthesia type and complications. Validates not more than 2 births per year.
  // Output: { "historyId": 50, "success": true, "message": "Pregnancy history saved" }
  Future<Map<String, dynamic>> savePregnancyHistory(
    Map<String, dynamic> data,
  ) async {
    return await _post('/pregnancy-history', data);
  }

  // API 17: Get Risk Factor Types
  // Purpose: Retrieves pregnancy-related risk factors only (where is_pregnancy_related=1)
  // to populate dropdown on risk factors tab.
  // Output: { "riskFactors": [{"riskFactorId": 3, "riskFactorName": "Advanced Maternal Age",
  //           "riskFactorCategory": "Demographic", "isPregnancyRelated": true}, ...] }
  Future<List<Map<String, dynamic>>> getPregnancyRiskFactorTypes() async {
    final response = await _get('/risk-factors/pregnancy-related');
    return List<Map<String, dynamic>>.from(response?['riskFactors'] ?? []);
  }

  // API 18: Get Patient Risk Factors
  // Purpose: Retrieves all risk factors recorded for patient to display on risk factors tab.
  // Output: { "riskFactors": [{"patientRiskFactorId": 20, "riskFactorName": "Smoking",
  //           "isPresent": true, "severityLevel": "Moderate", "notes": "10 cigs/day"}, ...] }
  Future<List<Map<String, dynamic>>> getPatientRiskFactors(
    int patientId,
  ) async {
    final response = await _get('/patient-risk-factors/$patientId');
    return List<Map<String, dynamic>>.from(response?['riskFactors'] ?? []);
  }

  // API 19: Save Patient Risk Factor
  // Purpose: Records or updates risk factor for patient with presence flag, severity level,
  // frequency, duration and pregnancy relation details.
  // Output: { "patientRiskFactorId": 25, "success": true }
  Future<Map<String, dynamic>> savePatientRiskFactor(
    Map<String, dynamic> data,
  ) async {
    if (data.containsKey('patientRiskFactorId') &&
        data['patientRiskFactorId'] != null) {
      return await _put(
        '/patient-risk-factors/${data['patientRiskFactorId']}',
        data,
      );
    }
    return await _post('/patient-risk-factors', data);
  }

  // API 20: Check Pregnancy Outcome (for pregnancies > 270 days)
  // Purpose: When LMP is more than 270 days old, check if pregnancy was concluded
  // and trigger outcome form if needed. Returns pregnancy status.
  // Output: { "needsOutcome": true, "daysSinceLMP": 285, "pregnancyStatus": "ongoing" }
  Future<Map<String, dynamic>?> checkPregnancyOutcome(int patientId) async {
    return await _get('/check-outcome/$patientId');
  }

  // API 21: Save Pregnancy Outcome
  // Purpose: Records final pregnancy outcome when delivery occurs or pregnancy concludes
  // with outcome type, actual delivery date and notes.
  // Output: { "success": true, "message": "Pregnancy outcome recorded successfully" }
  Future<Map<String, dynamic>> savePregnancyOutcome(
    Map<String, dynamic> data,
  ) async {
    return await _put('/outcome/${data['pregnancyId']}', data);
  }

  // ANC Visit APIs

  // API 22: Get ANC Vitals History
  // Purpose: Retrieves previous vitals recorded for current pregnancy to display in grid
  // Output: List of vitals with recordedDate, height, weight, BP, temperature, etc.
  Future<List<Map<String, dynamic>>> getANCVitals(int patientId) async {
    final uri = Uri.parse('${ApiConfig.pregnancyEndpoint}${ApiConfig.ancVitalsPath}')
        .replace(queryParameters: {'patientId': patientId.toString()});
    final response = await http.get(uri, headers: {'Content-Type': 'application/json'});
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    return [];
  }

  // API 23: Save ANC Vitals & Antenatal Visit
  // Purpose: Saves patient vitals and creates antenatal visit record linked together
  // Output: { "success": true, "antenatalVisitId": 123 }
  Future<Map<String, dynamic>> saveANCVitals(Map<String, dynamic> data) async {
    return await _post('/vitals', data);
  }

  // API 24: Get ANC Ultrasound History
  // Purpose: Retrieves previous ultrasound records for current pregnancy
  // Output: List of ultrasounds with scanDate, presentation, placenta, liquor, FHR
  Future<List<Map<String, dynamic>>> getANCUltrasounds(int patientId) async {
    final uri = Uri.parse('${ApiConfig.pregnancyEndpoint}${ApiConfig.ancUltrasoundPath}')
        .replace(queryParameters: {'patientId': patientId.toString()});
    final response = await http.get(uri, headers: {'Content-Type': 'application/json'});
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    return [];
  }

  // API 25: Save ANC Ultrasound Record
  // Purpose: Saves ultrasound record for current pregnancy visit
  // Output: { "success": true, "message": "Ultrasound record saved successfully" }
  Future<Map<String, dynamic>> saveANCUltrasound(Map<String, dynamic> data) async {
    return await _post('/pregnancy/anc/ultrasound', data);
  }

  // API 26: Get Available Supplements (LHV prescribable inventory items)
  // Purpose: Retrieves inventory items that LHV can prescribe (IsPrimary=true, Can_Lhv_Prescibe=true)
  // Output: List of supplements with itemId, itemName, medicineId, unitOfMeasure
  Future<List<Map<String, dynamic>>> getANCSupplements(int hospitalId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.pregnancyEndpoint}${ApiConfig.ancSupplementsPath}/$hospitalId'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    return [];
  }

  // API 27: Save ANC Supplement Order (Pharmacy Order)
  // Purpose: Creates pharmacy order with type='LHV', status='Pending' for supplements
  // Output: { "success": true, "orderId": 456, "orderNumber": "LHV-20241020-123" }
  Future<Map<String, dynamic>> saveANCSupplements(Map<String, dynamic> data) async {
    return await _post('/pregnancy/anc/supplements', data);
  }

  // DELIVERY AND NEWBORN APIs
  // API 28: Create Delivery Record
  // Purpose: Creates a new delivery record for a pregnancy
  // Output: { "deliveryId": 123, "success": true, "message": "Delivery record created" }
  Future<Map<String, dynamic>> createDeliveryRecord(Map<String, dynamic> data) async {
    return await _post('/pregnancy/delivery', data);
  }

  // API 29: Get Delivery Record
  // Purpose: Retrieves delivery record for a pregnancy
  // Output: Delivery record with all details
  Future<Map<String, dynamic>?> getDeliveryRecord(int patientId) async {
    return await _get('/delivery/$patientId');
  }

  // API 30: Save Initial Assessment
  // Purpose: Saves initial assessment data for delivery
  // Output: { "assessmentId": 456, "success": true }
  Future<Map<String, dynamic>> saveInitialAssessment(Map<String, dynamic> data) async {
    if (data.containsKey('assessmentId') && data['assessmentId'] != null) {
      return await _put('/pregnancy/delivery/initial-assessment/${data['assessmentId']}', data);
    }
    return await _post('/pregnancy/delivery/initial-assessment', data);
  }

  // API 31: Get Initial Assessment
  // Purpose: Retrieves initial assessment for a delivery
  // Output: Initial assessment data
  Future<Map<String, dynamic>?> getInitialAssessment(int deliveryId) async {
    return await _get('/pregnancy/delivery/initial-assessment/$deliveryId');
  }

  // API 32: Save Delivery Assessment
  // Purpose: Saves delivery assessment data including mother's condition
  // Output: { "assessmentId": 789, "success": true }
  Future<Map<String, dynamic>> saveDeliveryAssessment(Map<String, dynamic> data) async {
    if (data.containsKey('assessmentId') && data['assessmentId'] != null) {
      return await _put('/pregnancy/delivery/delivery-assessment/${data['assessmentId']}', data);
    }
    return await _post('/pregnancy/delivery/delivery-assessment', data);
  }

  // API 33: Get Delivery Assessment
  // Purpose: Retrieves delivery assessment for a delivery
  // Output: Delivery assessment data
  Future<Map<String, dynamic>?> getDeliveryAssessment(int deliveryId) async {
    return await _get('/pregnancy/delivery/delivery-assessment/$deliveryId');
  }

  // API 34: Save Newborn Record
  // Purpose: Saves newborn information for a delivery
  // Output: { "newbornId": 101, "success": true }
  Future<Map<String, dynamic>> saveNewbornRecord(Map<String, dynamic> data) async {
    if (data.containsKey('newbornId') && data['newbornId'] != null) {
      return await _put('/pregnancy/delivery/newborn/${data['newbornId']}', data);
    }
    return await _post('/pregnancy/delivery/newborn', data);
  }

  // API 35: Get Newborn Records
  // Purpose: Retrieves all newborn records for a delivery
  // Output: List of newborn records
  Future<List<Map<String, dynamic>>> getNewbornRecords(int deliveryId) async {
    final response = await _get('/pregnancy/delivery/newborn/$deliveryId');
    return List<Map<String, dynamic>>.from(response?['newborns'] ?? []);
  }

  // API 36: Save Discharge and Referral
  // Purpose: Saves discharge and referral information
  // Output: { "dischargeId": 202, "success": true }
  Future<Map<String, dynamic>> saveDischargeReferral(Map<String, dynamic> data) async {
    if (data.containsKey('dischargeId') && data['dischargeId'] != null) {
      return await _put('/pregnancy/delivery/discharge/${data['dischargeId']}', data);
    }
    return await _post('/pregnancy/delivery/discharge', data);
  }

  // API 37: Get Discharge and Referral
  // Purpose: Retrieves discharge and referral information for a delivery
  // Output: Discharge and referral data
  Future<Map<String, dynamic>?> getDischargeReferral(int deliveryId) async {
    return await _get('/pregnancy/delivery/discharge/$deliveryId');
  }

  // API 38: Get Causes of Death List
  // Purpose: Retrieves master list of causes of death
  // Output: List of causes of death
  Future<List<String>> getCausesOfDeath() async {
    final response = await _get('/pregnancy/delivery/causes-of-death');
    return List<String>.from(response?['causes'] ?? []);
  }

  // API 39: Get Newborn Symptoms List
  // Purpose: Retrieves master list of newborn symptoms
  // Output: List of newborn symptoms
  Future<List<String>> getNewbornSymptoms() async {
    final response = await _get('/pregnancy/delivery/newborn-symptoms');
    return List<String>.from(response?['symptoms'] ?? []);
  }

  // API 40: Get Newborn Medications List
  // Purpose: Retrieves master list of newborn medications/vaccines
  // Output: List of newborn medications
  Future<List<String>> getNewbornMedications() async {
    final response = await _get('/pregnancy/delivery/newborn-medications');
    return List<String>.from(response?['medications'] ?? []);
  }

  // API 41: Get Patient Pregnancy Records
  // Purpose: Retrieves all pregnancy records for a patient
  // Output: List of pregnancy records with registration details and status
  Future<List<dynamic>> getPatientPregnancyRecords(int patientId) async {
    final response = await _get('/patient/$patientId/records');
    return List<dynamic>.from(response?['pregnancyRecords'] ?? []);
  }

  // =============================================
  // DELIVERY FORM PHC APIs
  // =============================================

  // API 42: Create Delivery Record (PHC)
  // Purpose: Creates a new delivery record for PHC delivery form
  // Output: { "deliveryId": 123, "success": true, "message": "Delivery record created" }
  Future<Map<String, dynamic>> createDeliveryRecordPHC(Map<String, dynamic> data) async {
    return await _post('/delivery', data);
  }

  // API 43: Get Delivery Record by ID (PHC)
  // Purpose: Retrieves a specific delivery record
  // Output: Complete delivery record with all details
  Future<Map<String, dynamic>?> getDeliveryRecordById(int deliveryId) async {
    return await _get('/delivery/$deliveryId');
  }

  // API 44: Update Delivery Record
  // Purpose: Updates an existing delivery record
  // Output: { "deliveryId": 123, "success": true, "message": "Delivery record updated" }
  Future<Map<String, dynamic>> updateDeliveryRecord(int deliveryId, Map<String, dynamic> data) async {
    return await _put('/delivery/$deliveryId', data);
  }

  // API 45: Delete Delivery Record
  // Purpose: Soft deletes a delivery record
  // Output: Success/failure status
  Future<bool> deleteDeliveryRecord(int deliveryId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.pregnancyEndpoint}/delivery/$deliveryId'),
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // API 46: Get Delivery Records by Patient
  // Purpose: Retrieves all delivery records for a patient
  // Output: List of delivery records
  Future<List<Map<String, dynamic>>> getDeliveryRecordsByPatient(int patientId) async {
    final response = await _get('/delivery/patient/$patientId');
    return response != null && response is List ? List<Map<String, dynamic>>.from(response as List) : [];
  }

  // API 47: Get Delivery Records by Pregnancy
  // Purpose: Retrieves all delivery records for a pregnancy
  // Output: List of delivery records
  Future<List<Map<String, dynamic>>> getDeliveryRecordsByPregnancy(int pregnancyId) async {
    final response = await _get('/delivery/pregnancy/$pregnancyId');
    return response != null && response is List ? List<Map<String, dynamic>>.from(response as List) : [];
  }

  // API 48: Save Delivery Draft
  // Purpose: Saves a draft of the delivery form
  // Output: { "draftId": 123, "success": true, "message": "Draft saved" }
  Future<Map<String, dynamic>> saveDeliveryDraft(Map<String, dynamic> data) async {
    return await _post('/draft', data);
  }

  // API 49: Get Delivery Draft by ID
  // Purpose: Retrieves a specific draft
  // Output: Draft data with form content
  Future<Map<String, dynamic>?> getDeliveryDraft(int draftId) async {
    return await _get('/draft/$draftId');
  }

  // API 50: Get Delivery Drafts by Pregnancy
  // Purpose: Retrieves all drafts for a pregnancy
  // Output: List of drafts
  Future<List<Map<String, dynamic>>> getDeliveryDraftsByPregnancy(int pregnancyId) async {
    final response = await _get('/draft/pregnancy/$pregnancyId');
    return response != null && response is List ? List<Map<String, dynamic>>.from(response as List) : [];
  }

  // API 51: Delete Delivery Draft
  // Purpose: Deletes a draft
  // Output: Success/failure status
  Future<bool> deleteDeliveryDraft(int draftId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.pregnancyEndpoint}/draft/$draftId'),
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // API 52: Get Lady Health Visitors (LHVs)
  // Purpose: Retrieves list of LHVs for dropdown
  // Output: List of LHV records
  Future<List<Map<String, dynamic>>> getLHVs({int? hospitalId}) async {
    final endpoint = hospitalId != null ? '/lookup/lhvs?hospitalId=$hospitalId' : '/lookup/lhvs';
    final response = await _getList(endpoint);
    return response != null ? List<Map<String, dynamic>>.from(response) : [];
  }

  // API 53: Get Doctors
  // Purpose: Retrieves list of doctors for dropdown
  // Output: List of doctor records
  Future<List<Map<String, dynamic>>> getDoctors({int? hospitalId, int? departmentId}) async {
    String endpoint = '/lookup/doctors';
    List<String> params = [];
    if (hospitalId != null) params.add('hospitalId=$hospitalId');
    if (departmentId != null) params.add('departmentId=$departmentId');
    if (params.isNotEmpty) endpoint += '?${params.join('&')}';
    
    final response = await _getList(endpoint);
    return response != null ? List<Map<String, dynamic>>.from(response) : [];
  }

  // API 54: Get Hospitals/Facilities
  // Purpose: Retrieves list of hospitals for referral dropdown
  // Output: List of hospital records
  Future<List<Map<String, dynamic>>> getHospitals({String? hospitalType, int? districtId, int? tehsilId}) async {
    String endpoint = '/lookup/hospitals';
    List<String> params = [];
    if (hospitalType != null) params.add('hospitalType=$hospitalType');
    if (districtId != null) params.add('districtId=$districtId');
    if (tehsilId != null) params.add('tehsilId=$tehsilId');
    if (params.isNotEmpty) endpoint += '?${params.join('&')}';
    
    final response = await _getList(endpoint);
    return response != null ? List<Map<String, dynamic>>.from(response) : [];
  }

  // API 55: Get Referral Reasons
  // Purpose: Retrieves predefined referral reasons
  // Output: List of referral reason options
  Future<List<Map<String, dynamic>>> getReferralReasons() async {
    final response = await _getList('/lookup/referral-reasons');
    return response != null ? List<Map<String, dynamic>>.from(response) : [];
  }

  // API 56: Get Delivery Modes
  // Purpose: Retrieves available delivery modes
  // Output: List of delivery mode options
  Future<List<Map<String, dynamic>>> getDeliveryModes() async {
    final response = await _getList('/lookup/delivery-modes');
    return response != null ? List<Map<String, dynamic>>.from(response) : [];
  }

  // API 57: Get Labor Onset Types
  // Purpose: Retrieves labor onset type options
  // Output: List of labor onset types
  Future<List<Map<String, dynamic>>> getLaborOnsetTypes() async {
    final response = await _getList('/lookup/labor-onset-types');
    return response != null ? List<Map<String, dynamic>>.from(response) : [];
  }

  // API 58: Get Pregnancy Types
  // Purpose: Retrieves pregnancy type options (Singleton, Twins, etc.)
  // Output: List of pregnancy types with baby counts
  Future<List<Map<String, dynamic>>> getPregnancyTypes() async {
    final response = await _getList('/lookup/pregnancy-types');
    return response != null ? List<Map<String, dynamic>>.from(response) : [];
  }

  // API 59: Create Referral
  // Purpose: Creates a new referral for patient
  // Output: { "referralId": 123, "success": true, "message": "Referral created" }
  Future<Map<String, dynamic>> createReferral(Map<String, dynamic> data) async {
    return await _post('/referral', data);
  }

  // API 60: Get Referrals by Patient
  // Purpose: Retrieves all referrals for a patient
  // Output: List of referral records
  Future<List<Map<String, dynamic>>> getReferralsByPatient(int patientId) async {
    final response = await _get('/referral/patient/$patientId');
    return response != null && response is List ? List<Map<String, dynamic>>.from(response as List) : [];
  }

  // API 61: Update Referral Status
  // Purpose: Updates referral status (accepted, rejected, etc.)
  // Output: { "referralId": 123, "success": true, "message": "Status updated" }
  Future<Map<String, dynamic>> updateReferralStatus(int referralId, Map<String, dynamic> data) async {
    return await _put('/referral/$referralId/status', data);
  }

  // API 62: Get Incoming Referral
  // Purpose: Retrieves incoming referral details for a pregnancy
  // Output: Referral details if patient was referred to this facility
  Future<Map<String, dynamic>?> getIncomingReferral(int pregnancyId) async {
    return await _get('/referral/incoming/$pregnancyId');
  }

  // =============================================
  // NEWBORN RECORDS API METHODS
  // =============================================

  // API 63: Create Newborn Record
  // Purpose: Creates a new newborn record
  // Output: { "newbornId": 123, "success": true, "message": "Newborn record created" }
  Future<Map<String, dynamic>> createNewbornRecord(Map<String, dynamic> data) async {
    return await _post('/newborn', data);
  }

  // API 64: Get Newborn Record by ID
  // Purpose: Retrieves a specific newborn record
  // Output: Complete newborn record with mother and delivery information
  Future<Map<String, dynamic>?> getNewbornRecord(int newbornId) async {
    return await _get('/newborn/$newbornId');
  }

  // API 65: Get Newborn Records by Delivery
  // Purpose: Retrieves all newborn records for a delivery
  // Output: List of newborn records for the delivery
  Future<List<Map<String, dynamic>>> getNewbornRecordsByDelivery(int deliveryId) async {
    final response = await _get('/newborn/delivery/$deliveryId');
    return response != null && response is List ? List<Map<String, dynamic>>.from(response as List) : [];
  }

  // API 66: Get Newborn Records by Mother
  // Purpose: Retrieves all newborn records for a mother
  // Output: List of newborn records for the mother
  Future<List<Map<String, dynamic>>> getNewbornRecordsByMother(int motherPatientId) async {
    final response = await _get('/newborn/mother/$motherPatientId');
    return response != null && response is List ? List<Map<String, dynamic>>.from(response as List) : [];
  }

  // API 67: Update Newborn Record
  // Purpose: Updates an existing newborn record
  // Output: { "newbornId": 123, "success": true, "message": "Newborn record updated" }
  Future<Map<String, dynamic>> updateNewbornRecord(int newbornId, Map<String, dynamic> data) async {
    return await _put('/newborn/$newbornId', data);
  }

  // API 68: Delete Newborn Record
  // Purpose: Soft deletes a newborn record
  // Output: { "newbornId": 123, "success": true, "message": "Newborn record deleted" }
  Future<Map<String, dynamic>> deleteNewbornRecord(int newbornId, Map<String, dynamic> data) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.pregnancyEndpoint}/newborn/$newbornId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to delete newborn record');
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  // API 69: Get Recent Delivery Info
  // Purpose: Retrieves recent delivery information for newborn form
  // Output: Delivery information including number of babies and delivery date
  Future<Map<String, dynamic>?> getRecentDeliveryInfo(int patientId) async {
    return await _get('/delivery/recent/$patientId');
  }

  // API 62: Get Pregnancy Details
  // Purpose: Retrieves detailed pregnancy information for info card
  // Output: Complete pregnancy record with calculated gestational age
  Future<Map<String, dynamic>?> getPregnancyDetails(int pregnancyId) async {
    return await _get('/pregnancy-info/$pregnancyId');
  }

  // API 63: Get Pregnancy Summary
  // Purpose: Retrieves pregnancy summary with history and recent visits
  // Output: Current pregnancy, history summary, and recent visits
  Future<Map<String, dynamic>?> getPregnancySummary(int patientId) async {
    return await _get('/pregnancy-info/patient/$patientId/summary');
  }

  // API 64: Get Patient Pregnancy History
  // Purpose: Retrieves complete pregnancy history for patient
  // Output: List of all pregnancy records
  Future<List<Map<String, dynamic>>> getPatientPregnancyHistory(int patientId) async {
    try {
      final response = await _getList('/pregnancy-info/patient/$patientId/history');
      return response != null && response is List ? List<Map<String, dynamic>>.from(response) : [];
    } catch (e) {
      print('Error getting pregnancy history: $e');
      return [];
    }
  }

  // API 65: Get Patient Delivery History
  // Purpose: Retrieves all delivery records for patient
  // Output: List of delivery records with outcomes
  Future<List<Map<String, dynamic>>> getPatientDeliveryHistory(int patientId) async {
    final response = await _get('/pregnancy-info/patient/$patientId/delivery-history');
    return response != null && response is List ? List<Map<String, dynamic>>.from(response as List) : [];
  }

  // Get PNC visits by delivery or pregnancy
  Future<List<Map<String, dynamic>>> getPNCVisits({int? deliveryId, int? pregnancyId}) async {
    if (deliveryId != null) {
      final r = await _getList('/pnc/visits/delivery/$deliveryId');
      return r != null && r is List ? List<Map<String, dynamic>>.from(r) : [];
    }
    if (pregnancyId != null) {
      final r = await _getList('/pnc/visits/pregnancy/$pregnancyId');
      return r != null && r is List ? List<Map<String, dynamic>>.from(r) : [];
    }
    return [];
  }

  // Save PNC visit
  Future<Map<String, dynamic>> savePNCVisit(Map<String, dynamic> data) async {
    return await _post('/pnc/visit', data);
  }
}
