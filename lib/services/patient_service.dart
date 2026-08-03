// File: lib/services/patient_service.dart
// Location: lib/services/

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'user_session_service.dart';

class PatientService {

  // API: Create Patient
  // Purpose: Registers a new patient in the system
  // Input: Patient data including fullName, CNIC, dateOfBirth, gender, etc.
  // Output: Created patient data with patientID and MRN
  Future<Map<String, dynamic>?> createPatient(Map<String, dynamic> patientData) async {
    try {
      // Remove dashes from CNIC for API
      final cleanedCnic = (patientData['cnic'] as String).replaceAll(RegExp(r'[^0-9]'), '');
      patientData['cnic'] = cleanedCnic;

      // Add source field to identify the registration source
      patientData['source'] = 'Flutter';

      // Get auth token for authorization
      final token = await UserSessionService.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(
        Uri.parse(ApiConfig.minPatientsEndpoint),
        headers: headers,
        body: json.encode(patientData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Handle ApiResponse wrapper format
        if (data.containsKey('data')) {
          return data['data'] as Map<String, dynamic>?;
        }
        return data as Map<String, dynamic>?;
      } else if (response.statusCode == 409) {
        // Conflict - patient already exists
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Patient with this CNIC already exists');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to create patient');
      }
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  // API: Search Female Patients
  // Purpose: Searches for female patients aged 15-50 years using MRN, CNIC, or Contact Number
  // to allow pregnancy registration. Only returns eligible female patients.
  // Output: List of matching female patients with their details
  Future<List<Map<String, dynamic>>> searchFemalePatients({
    required String searchType,
    required String searchValue,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.patientsEndpoint}${ApiConfig.searchFemalePath}?type=$searchType&value=$searchValue'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['patients'] ?? []);
      } else if (response.statusCode == 404) {
        return [];
      }
      throw Exception('Failed to search patients');
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  // API: Get Patient Details
  // Purpose: Retrieves complete patient information by patient ID for displaying
  // in the pregnancy registration form.
  // Output: Patient details including demographics and contact information
  Future<Map<String, dynamic>?> getPatientById(int patientId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.minPatientsEndpoint}/$patientId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // MinimalPatientsController returns data directly (not wrapped in ApiResponse)
        return data as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  // API: Get Patient Details (Alias for compatibility)
  // Purpose: Retrieves comprehensive patient information for history dashboard
  // Output: Complete patient details including demographics, contact info, etc.
  Future<Map<String, dynamic>?> getPatientDetails(int patientId) async {
    return await getPatientById(patientId);
  }

  // API: Get Patient History Summary
  // Purpose: Retrieves summary of all patient medical records
  // Output: Summary counts and basic information for all medical record types
  Future<Map<String, dynamic>> getPatientHistorySummary(int patientId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.patientsEndpoint}/$patientId${ApiConfig.historySummaryPath}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {};
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  // API: Get Patient Demographics
  // Purpose: Retrieves detailed patient demographic information
  // Output: Complete demographic data including blood type, last visit, etc.
  Future<Map<String, dynamic>?> getPatientDemographics(int patientId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.patientsEndpoint}/$patientId${ApiConfig.demographicsPath}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  // API: Get Patient Vitals
  // Purpose: Retrieves all vital signs recorded for a patient
  // Output: List of vitals with date, blood pressure, heart rate, temperature, etc.
  Future<List<Map<String, dynamic>>> getPatientVitals(int patientId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.patientsEndpoint}/$patientId/vitals'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['vitals'] ?? []);
      }
      return [];
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  // API: Get Patient Medications
  // Purpose: Retrieves all prescribed medications for a patient
  // Output: List of medications with dosage, frequency, indication, prescriber, etc.
  Future<List<Map<String, dynamic>>> getPatientMedications(int patientId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/pharmacy/patient/$patientId/medications'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['medications'] ?? []);
      }
      return [];
    } catch (e) {
      throw Exception('API Error: $e');
    }
  }

  // API: Update Patient
  // Purpose: Updates an existing patient's information
  // Input: Patient ID and updated patient data
  // Output: Updated patient data
  Future<Map<String, dynamic>?> updatePatient(int patientId, Map<String, dynamic> patientData) async {
    try {
      // Validate patient ID
      if (patientId <= 0) {
        throw Exception('Invalid patient ID: $patientId');
      }
      
      // Map to camelCase format expected by MinimalPatientsController.Save()
      final updateDto = <String, dynamic>{
        'patientID': patientId, // Required for update
      };
      
      // Map fields to camelCase as expected by MinimalPatientsController
      if (patientData.containsKey('fullName')) {
        updateDto['fullName'] = patientData['fullName'];
      }
      if (patientData.containsKey('dateOfBirth')) {
        updateDto['dateOfBirth'] = patientData['dateOfBirth'];
      }
      if (patientData.containsKey('gender')) {
        updateDto['gender'] = patientData['gender'];
      }
      if (patientData.containsKey('contactNumber')) {
        updateDto['contactNumber'] = patientData['contactNumber'];
      }
      if (patientData.containsKey('email')) {
        updateDto['email'] = patientData['email'];
      }
      if (patientData.containsKey('address')) {
        updateDto['address'] = patientData['address'];
      }
      if (patientData.containsKey('emergencyContactNumber')) {
        updateDto['emergencyContactNumber'] = patientData['emergencyContactNumber'];
      }
      if (patientData.containsKey('emergencyContactRelation')) {
        updateDto['emergencyContactRelation'] = patientData['emergencyContactRelation'];
      }
      if (patientData.containsKey('bloodGroup')) {
        updateDto['bloodGroup'] = patientData['bloodGroup'];
      }
      if (patientData.containsKey('notes')) {
        updateDto['notes'] = patientData['notes'];
      }
      if (patientData.containsKey('isActive')) {
        updateDto['isActive'] = patientData['isActive'];
      }
      
      // Include registrationType and parentType for updates
      // This is critical - backend needs to know if patient is Self or Dependent to validate correctly
      if (patientData.containsKey('registrationType')) {
        updateDto['registrationType'] = patientData['registrationType'];
      }
      if (patientData.containsKey('parentType')) {
        updateDto['parentType'] = patientData['parentType'];
      }
      
      // Include Source for updates (required field, cannot be NULL)
      if (patientData.containsKey('source')) {
        updateDto['source'] = patientData['source'];
      }
      
      // Include CNIC for Self patient updates (required by trigger validation)
      // For dependents, CNIC is not included (preserved by trigger)
      if (patientData.containsKey('cnic')) {
        final cnicValue = patientData['cnic'].toString().replaceAll(RegExp(r'[^0-9]'), '');
        if (cnicValue.length == 13) {
          updateDto['cnic'] = cnicValue;
        }
      }

      // Get auth token for authorization
      final token = await UserSessionService.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      // Use POST to /api/min-patients (MinimalPatientsController.Save handles both insert and update)
      final response = await http.post(
        Uri.parse(ApiConfig.minPatientsEndpoint),
        headers: headers,
        body: json.encode(updateDto),
      );

      if (response.statusCode == 200) {
        final responseBody = response.body.trim();
        if (responseBody.isEmpty) {
          throw Exception('Empty response from server');
        }
        
        try {
          final data = json.decode(responseBody);
          // MinimalPatientsController returns data directly (not wrapped in ApiResponse)
          return data as Map<String, dynamic>?;
        } catch (e) {
          throw Exception('Failed to parse response: $e');
        }
      } else {
        // Handle error responses
        final responseBody = response.body.trim();
        String errorMessage = 'Failed to update patient (Status: ${response.statusCode})';
        
        if (responseBody.isNotEmpty) {
          try {
            final errorData = json.decode(responseBody);
            if (errorData is Map<String, dynamic>) {
              errorMessage = errorData['message'] ?? 
                           errorData['error'] ?? 
                           errorMessage;
            }
          } catch (e) {
            // If JSON parsing fails, use the raw response body if available
            if (responseBody.length < 200) {
              errorMessage = responseBody;
            }
          }
        }
        
        throw Exception(errorMessage);
      }
    } catch (e) {
      // Re-throw if it's already an Exception, otherwise wrap it
      if (e is Exception) {
        rethrow;
      }
      throw Exception('API Error: $e');
    }
  }
}

/* 
API DOCUMENTATION FOR PATIENT SEARCH

API 1: Search Female Patients for Pregnancy Registration
========================================================
Endpoint: GET /api/patients/search-female?type={searchType}&value={searchValue}

Purpose: 
Searches for female patients aged 15-50 years eligible for pregnancy registration.
Filters by MRN, CNIC, or Contact Number. Returns only female patients within 
reproductive age range (15-50 years) and IsActive = true.

Parameters:
- type: String (required) - One of: "MRN", "CNIC", "Contact"
- value: String (required) - The search value to match

Request Example:
GET /api/patients/search-female?type=MRN&value=MRN001234
GET /api/patients/search-female?type=CNIC&value=3520212345678
GET /api/patients/search-female?type=Contact&value=03001234567

Response Format (Success - 200 OK):
{
  "patients": [
    {
      "patientId": 456,
      "mrn": "MRN001234",
      "fullName": "Ayesha Khan",
      "cnic": "3520212345678",
      "dateOfBirth": "1995-03-15",
      "age": 29,
      "gender": "Female",
      "contactNumber": "03001234567",
      "email": "ayesha@example.com",
      "address": "House 123, Street 5, Lahore",
      "bloodGroup": "B+",
      "isActive": true,
      "hasActivePregnancy": false
    }
  ],
  "totalCount": 1
}

Response Format (No Results - 200 OK):
{
  "patients": [],
  "totalCount": 0,
  "message": "No matching female patients found"
}

Response Format (Error - 400 Bad Request):
{
  "error": "Invalid search type. Must be MRN, CNIC, or Contact",
  "success": false
}

Response Format (Error - 500 Internal Server Error):
{
  "error": "Internal server error",
  "message": "Error details...",
  "success": false
}

SQL Query Example (Backend Implementation):
-------------------------------------------
SELECT 
    p.PatientID,
    p.MRN,
    p.FullName,
    p.CNIC,
    p.DateOfBirth,
    DATEDIFF(YEAR, p.DateOfBirth, GETDATE()) AS Age,
    p.Gender,
    p.ContactNumber,
    p.Email,
    p.Address,
    p.BloodGroup,
    p.IsActive,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM Pregnancy.Pregnancy_Records pr 
            WHERE pr.PatientID = p.PatientID 
            AND pr.Pregnancy_status = 'ongoing' 
            AND pr.IsActive = 1
        ) THEN 1 
        ELSE 0 
    END AS HasActivePregnancy
FROM dbo.Patients p
WHERE 
    p.Gender = 'Female'
    AND p.IsActive = 1
    AND DATEDIFF(YEAR, p.DateOfBirth, GETDATE()) BETWEEN 15 AND 50
    AND (
        (@SearchType = 'MRN' AND p.MRN = @SearchValue)
        OR (@SearchType = 'CNIC' AND p.CNIC = @SearchValue)
        OR (@SearchType = 'Contact' AND p.ContactNumber LIKE '%' + @SearchValue + '%')
    )

Business Rules:
--------------
1. Only female patients can be returned
2. Patient age must be between 15-50 years (calculated from DateOfBirth)
3. Patient must be active (IsActive = 1)
4. Search is case-insensitive for MRN
5. CNIC must match exactly (13 digits)
6. Contact number can be partial match
7. Include flag if patient already has an active pregnancy
8. Results should be ordered by: HasActivePregnancy ASC, FullName ASC

API 2: Get Patient Details by ID
================================
Endpoint: GET /api/patients/{patientId}

Purpose:
Retrieves complete patient information by patient ID for displaying in forms
and confirming patient identity before pregnancy registration.

API 3: Get Patient Vitals
=========================
Endpoint: GET /api/patients/{patientId}/vitals

Purpose:
Retrieves all vital signs recorded for a patient including blood pressure,
heart rate, temperature, weight, height, and other vital measurements.

Request Example:
GET /api/patients/456/vitals

Response Format (Success - 200 OK):
{
  "vitals": [
    {
      "vitalId": 123,
      "recordedDate": "2024-10-20T10:30:00",
      "bloodPressureSystolic": 120,
      "bloodPressureDiastolic": 80,
      "heartRate": 72,
      "temperature": 98.6,
      "weight": 65.5,
      "height": 165,
      "bmi": 24.1,
      "oxygenSaturation": 98,
      "respiratoryRate": 16,
      "location": "OPD",
      "recordedBy": "Dr. Smith",
      "notes": "Patient appears stable"
    }
  ],
  "totalCount": 1
}

Response Format (No Results - 200 OK):
{
  "vitals": [],
  "totalCount": 0,
  "message": "No vitals recorded for this patient"
}

Request Example:
GET /api/patients/456

Response Format (Success - 200 OK):
{
  "patientId": 456,
  "mrn": "MRN001234",
  "fullName": "Ayesha Khan",
  "cnic": "3520212345678",
  "dateOfBirth": "1995-03-15",
  "age": 29,
  "gender": "Female",
  "contactNumber": "03001234567",
  "email": "ayesha@example.com",
  "address": "House 123, Street 5, Lahore",
  "emergencyContact": "03009876543",
  "emergencyContactRelation": "Husband",
  "bloodGroup": "B+",
  "isActive": true,
  "createdAt": "2024-01-15T10:30:00",
  "updatedAt": "2024-10-01T14:20:00"
}

Response Format (Not Found - 404):
{
  "error": "Patient not found",
  "success": false
}

Notes for Frontend Developer:
-----------------------------
1. Always validate age on frontend before showing patient (15-50 years)
2. Show warning icon if patient already has active pregnancy
3. Display patient photo if available (future enhancement)
4. Cache search results locally for 5 minutes to reduce API calls
5. Implement debouncing for Contact Number search (500ms delay)
6. Show loading indicator during search
7. Handle network errors gracefully with retry option
8. Validate CNIC format (13 digits) before making API call
9. Format phone numbers with country code display
10. Highlight matching search terms in results

Error Handling Best Practices:
------------------------------
- 200: Success with results
- 200: Success with empty array (no results found)
- 400: Bad request (invalid search parameters)
- 401: Unauthorized (user not authenticated)
- 403: Forbidden (user doesn't have permission)
- 404: Patient not found
- 500: Server error
- Network error: Show "Unable to connect" message

Performance Considerations:
--------------------------
- Add database indexes on: MRN, CNIC, ContactNumber
- Consider pagination for Contact Number searches (can return many results)
- Cache frequent searches on server side
- Use connection pooling for database connections
- Implement query timeout of 30 seconds
*/