import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'user_session_service.dart';

class HospitalSetupService {
  static String get baseUrl => ApiConfig.baseUrl;

  static Future<Map<String, String>> _headers() async {
    final token = await UserSessionService.getToken();
    final h = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  // ========== DEPARTMENTS ==========
  static Future<List<Map<String, dynamic>>> getDepartments() async {
    final response = await http.get(
      Uri.parse('$baseUrl/hospital-setup/departments'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load departments: ${response.statusCode}');
  }

  static Future<Map<String, dynamic>> createDepartment(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/hospital-setup/departments'),
      headers: await _headers(),
      body: json.encode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception('Failed to create department: ${response.statusCode}');
  }

  static Future<Map<String, dynamic>> updateDepartment(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/hospital-setup/departments/$id'),
      headers: await _headers(),
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to update department: ${response.statusCode}');
  }

  static Future<void> deleteDepartment(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/hospital-setup/departments/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete department: ${response.statusCode}');
    }
  }

  // ========== HOSPITAL DEPARTMENTS ==========
  static Future<List<Map<String, dynamic>>> getHospitalDepartments(int hospitalId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/hospital-setup/hospital-departments?hospitalId=$hospitalId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load hospital departments: ${response.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> getHospitals() async {
    final response = await http.get(
      Uri.parse('$baseUrl/hospital-setup/hospitals'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load hospitals: ${response.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> getRoles() async {
    final response = await http.get(
      Uri.parse('$baseUrl/hospital-setup/roles'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load roles: ${response.statusCode}');
  }

  // ========== USERS ==========
  static Future<List<Map<String, dynamic>>> searchUsers({
    String? searchTerm,
    int? hospitalId,
    int? hospitalDepartmentId,
    int? top,
  }) async {
    final queryParameters = <String, String>{};
    if (searchTerm != null && searchTerm.isNotEmpty) queryParameters['searchTerm'] = searchTerm;
    if (hospitalId != null) queryParameters['hospitalId'] = hospitalId.toString();
    if (hospitalDepartmentId != null) {
      queryParameters['hospitalDepartmentId'] = hospitalDepartmentId.toString();
    }
    if (top != null) queryParameters['top'] = top.toString();

    final uri = Uri.parse('$baseUrl/hospital-setup/users/search').replace(queryParameters: queryParameters);
    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to search users: ${response.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> getHospitalUsers(int hospitalId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/hospital-setup/hospital-users?hospitalId=$hospitalId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load hospital users: ${response.statusCode}');
  }

  static Future<Map<String, dynamic>> attachUserToHospital(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/hospital-setup/hospital-users'),
      headers: await _headers(),
      body: json.encode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception('Failed to attach user to hospital: ${response.statusCode}');
  }

  static Future<void> detachUserFromHospital(int assignmentId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/hospital-setup/hospital-users/$assignmentId'),
      headers: await _headers(),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to detach user from hospital: ${response.statusCode}');
    }
  }

  static Future<List<Map<String, dynamic>>> getHospitalDepartmentUsers(int hospitalDepartmentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/hospital-setup/hospital-department-users?hospitalDepartmentId=$hospitalDepartmentId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load hospital department users: ${response.statusCode}');
  }

  static Future<Map<String, dynamic>> attachUserToHospitalDepartment(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/hospital-setup/hospital-department-users'),
      headers: await _headers(),
      body: json.encode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception('Failed to attach user to hospital department: ${response.statusCode}');
  }

  static Future<void> detachUserFromHospitalDepartment(int assignmentId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/hospital-setup/hospital-department-users/$assignmentId'),
      headers: await _headers(),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to detach user from hospital department: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> createHospitalDepartment(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/hospital-setup/hospital-departments'),
      headers: await _headers(),
      body: json.encode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception('Failed to create hospital department: ${response.statusCode}');
  }

  static Future<Map<String, dynamic>> updateHospitalDepartment(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/hospital-setup/hospital-departments/$id'),
      headers: await _headers(),
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to update hospital department: ${response.statusCode}');
  }

  static Future<void> deleteHospitalDepartment(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/hospital-setup/hospital-departments/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete hospital department: ${response.statusCode}');
    }
  }

  // ========== OPDs ==========
  static Future<List<Map<String, dynamic>>> getOPDs(int hospitalDepartmentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/hospital-setup/opds?hospitalDepartmentId=$hospitalDepartmentId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load OPDs: ${response.statusCode}');
  }

  // ========== DOCTOR SCHEDULES ==========
  static Future<List<Map<String, dynamic>>> getDoctorSchedules(
    int hospitalDepartmentId, {
    DateTime? startDate,
    DateTime? endDate,
    bool includeSummary = false,
  }) async {
    final queryParameters = <String, String>{
      'hospitalDepartmentId': hospitalDepartmentId.toString(),
      'includeSummary': includeSummary.toString(),
      if (startDate != null) 'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate.toIso8601String(),
    };

    final uri = Uri.parse('$baseUrl/hospital-setup/doctor-schedules')
        .replace(queryParameters: queryParameters);

    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load doctor schedules: ${response.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> getDoctorScheduleSummary(
    int hospitalDepartmentId,
    DateTime weekStart,
  ) async {
    final uri = Uri.parse('$baseUrl/hospital-setup/doctor-schedules/summary').replace(
      queryParameters: {
        'hospitalDepartmentId': hospitalDepartmentId.toString(),
        'weekStart': weekStart.toIso8601String(),
      },
    );

    final response = await http.get(uri, headers: await _headers());
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load doctor schedule summary: ${response.statusCode}');
  }

  static Future<List<Map<String, dynamic>>> createDoctorSchedule(
      Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/hospital-setup/doctor-schedules'),
      headers: await _headers(),
      body: json.encode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = json.decode(response.body);
      if (decoded is List) {
        return List<Map<String, dynamic>>.from(decoded);
      }
      if (decoded is Map<String, dynamic>) {
        return [decoded];
      }
      return [];
    }
    if (response.statusCode == 409) {
      final message = _extractErrorMessage(response.body);
      throw Exception(message);
    }
    throw Exception('Failed to create doctor schedule: ${response.statusCode}');
  }

  static Future<void> updateDoctorSchedule(int scheduleId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/hospital-setup/doctor-schedules/$scheduleId'),
      headers: await _headers(),
      body: json.encode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    if (response.statusCode == 409) {
      final message = _extractErrorMessage(response.body);
      throw Exception(message);
    }
    if (response.statusCode == 404) {
      throw Exception('Schedule not found');
    }
    throw Exception('Failed to update doctor schedule: ${response.statusCode}');
  }

  static Future<void> deleteDoctorSchedule(int scheduleId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/hospital-setup/doctor-schedules/$scheduleId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }
    if (response.statusCode == 404) {
      throw Exception('Schedule not found');
    }
    throw Exception('Failed to delete doctor schedule: ${response.statusCode}');
  }

  static String _extractErrorMessage(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded['message']?.toString() ?? body;
      }
      if (decoded is String) {
        return decoded;
      }
    } catch (_) {
      // ignore and return raw body
    }
    return body;
  }

  static Future<Map<String, dynamic>> createOPD(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/hospital-setup/opds'),
      headers: await _headers(),
      body: json.encode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception('Failed to create OPD: ${response.statusCode}');
  }

  static Future<Map<String, dynamic>> updateOPD(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/hospital-setup/opds/$id'),
      headers: await _headers(),
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to update OPD: ${response.statusCode}');
  }

  static Future<void> deleteOPD(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/hospital-setup/opds/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete OPD: ${response.statusCode}');
    }
  }

  // ========== THEATRES ==========
  static Future<List<Map<String, dynamic>>> getTheatres(int hospitalDepartmentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/hospital-setup/theatres?hospitalDepartmentId=$hospitalDepartmentId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load theatres: ${response.statusCode}');
  }

  static Future<Map<String, dynamic>> createTheatre(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/hospital-setup/theatres'),
      headers: await _headers(),
      body: json.encode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception('Failed to create theatre: ${response.statusCode}');
  }

  static Future<Map<String, dynamic>> updateTheatre(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/hospital-setup/theatres/$id'),
      headers: await _headers(),
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to update theatre: ${response.statusCode}');
  }

  static Future<void> deleteTheatre(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/hospital-setup/theatres/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete theatre: ${response.statusCode}');
    }
  }

  // ========== WARDS ==========
  static Future<List<Map<String, dynamic>>> getWards(int hospitalDepartmentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/hospital-setup/wards?hospitalDepartmentId=$hospitalDepartmentId'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    throw Exception('Failed to load wards: ${response.statusCode}');
  }

  static Future<Map<String, dynamic>> createWard(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/hospital-setup/wards'),
      headers: await _headers(),
      body: json.encode(data),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body);
    }
    throw Exception('Failed to create ward: ${response.statusCode}');
  }

  static Future<Map<String, dynamic>> updateWard(int id, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/hospital-setup/wards/$id'),
      headers: await _headers(),
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to update ward: ${response.statusCode}');
  }

  static Future<void> deleteWard(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/hospital-setup/wards/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete ward: ${response.statusCode}');
    }
  }
}

