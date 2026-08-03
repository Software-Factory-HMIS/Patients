import 'dart:convert';
import 'package:flutter/services.dart';
import '../utils/api_config.dart' show resolveEmrBaseUrl;

class ApiConfig {
  // Centralized API configuration for all services
  static String? _baseUrl;
  static const String _configPath = 'assets/config/app_config.json';

  // Load configuration from external file; falls back to resolveEmrBaseUrl when file missing
  static Future<void> loadConfig() async {
    try {
      final String jsonString = await rootBundle.loadString(_configPath);
      final Map<String, dynamic> config = json.decode(jsonString);
      _baseUrl = config['baseUrl'] as String?;
    } catch (e) {
      _baseUrl = '${resolveEmrBaseUrl()}/api';
    }
  }

  // Get baseUrl, with fallback to resolveEmrBaseUrl if not loaded
  static String get baseUrl {
    if (_baseUrl != null) return _baseUrl!;
    return '${resolveEmrBaseUrl()}/api';
  }

  // API Endpoints
  static String get encountersEndpoint => '$baseUrl/encounters';
  static String get patientsEndpoint => '$baseUrl/patients';
  static String get minPatientsEndpoint => '$baseUrl/min-patients';
  static String get consultationEndpoint => '$baseUrl/consultation';
  static String get pregnancyEndpoint => baseUrl;
  static String get limsEndpoint => '$baseUrl/lims';
  static String get systemEndpoint => '$baseUrl/system';
  static String get chronicConditionsEndpoint => '$baseUrl/chronic-conditions';
  static String get emrEndpoint => '$baseUrl/emr';

  // Specific endpoint paths
  static const String todayPatientsPath = '/today-patients';
  static const String searchPatientPath = '/search-patient';
  static const String searchFemalePath = '/search-female';
  static const String demographicsPath = '/demographics';
  static const String vitalsPath = '/vitals';
  static const String medicationsPath = '/medications';
  static const String opdPath = '/opd';
  static const String ipdPath = '/ipd';
  static const String labsPath = '/labs';
  static const String radiologyPath = '/radiology';
  static const String surgeryPath = '/surgery';
  static const String chronicConditionsPath = '/chronic-conditions';
  static const String historySummaryPath = '/history/summary';
  static const String ancVitalsPath = '/anc/vitals';
  static const String ancUltrasoundPath = '/pregnancy/anc/ultrasound';
  static const String ancSupplementsPath = '/pregnancy/anc/supplements';
  static const String ordersPendingPath = '/orders/pending';
  static const String ordersPath = '/orders';
  static const String samplesPath = '/samples';
  static const String createMultiplePath = '/create-multiple';
  static const String barcodePath = '/barcode';
  static const String receivePath = '/receive';
  static const String rejectPath = '/reject';
  static const String generateBarcodePath = '/generate-barcode';
  static const String systemInfoPath = '/info';
  static const String hospitalPath = '/hospital';
  static const String userPath = '/user';
  static const String userHospitalPath = '/user-hospital';
  static const String categoriesPath = '/categories';
  static const String byCategoryPath = '/by-category';
  static const String patientDemographicsPath = '/patient-demographics';
  static const String patientVitalsPath = '/patient-vitals';
  static const String patientChronicConditionsPath = '/patient-chronic-conditions';
  static const String byCnicPath = '/by-cnic';

  static String get physioEndpoint => '$baseUrl/physio';
  static const String modalitiesPath = '/modalities';
  static const String physioOrdersPath = '/orders';
  static const String physioActivePath = '/active';
  static const String physioHistoryPath = '/history';
  static const String physioDiscontinuePath = '/discontinue';

  static String get familyPlanningEndpoint => '$baseUrl/family-planning';
  static const String methodsAllPath = '/methods/all';
  static const String currentMethodPath = '/patient';
  static const String eligibilityCheckPath = '/eligibility/check';
  static const String mecCategoriesPath = '/mec-categories';
  static const String methodAdoptionPath = '/method/adoption';
  static const String prescriptionPath = '/prescription';
  static const String followupPath = '/followup';
  static const String visitCompletePath = '/visit/complete';
  static const String patientVisitsPath = '/patient';
  static const String conditionCategoriesPath = '/condition-categories';
  static const String medicalConditionsPath = '/medical-conditions';
  static const String patientConditionsPath = '/patient-conditions';

  static String get vaccinationBaseUrl => baseUrl;
  static String get vaccinationEndpoint => vaccinationBaseUrl;
  static String get vaccinationPatientsEndpoint => '$vaccinationEndpoint/patients';
  static String get vaccinationImmunizationRecordsEndpoint =>
      '$vaccinationEndpoint/immunization-records';
  static String get vaccinationVaccinesEndpoint => '$vaccinationEndpoint/vaccines';
  static String get vaccinationSyncEndpoint => '$vaccinationEndpoint/sync';
  static String get vaccinationHealthEndpoint => '$vaccinationEndpoint/health';

  static String buildUrl(String endpoint, String path) => '$endpoint$path';

  static String buildUrlWithParams(
      String endpoint, String path, Map<String, String> params) {
    final uri = Uri.parse('$endpoint$path');
    return uri.replace(queryParameters: params).toString();
  }
}
