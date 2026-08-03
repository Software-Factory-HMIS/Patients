import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class SystemInfoService {
  
  // Get complete system info (hospital + user) for current user
  static Future<Map<String, dynamic>?> getSystemInfo(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.systemEndpoint}${ApiConfig.systemInfoPath}/$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Error fetching system info: $e');
      return null;
    }
  }

  // Get hospital details by hospital ID
  static Future<Map<String, dynamic>?> getHospitalInfo(int hospitalId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.systemEndpoint}${ApiConfig.hospitalPath}/$hospitalId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Error fetching hospital info: $e');
      return null;
    }
  }

  // Get user details by user ID
  static Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.systemEndpoint}${ApiConfig.userPath}/$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print('Error fetching user info: $e');
      return null;
    }
  }

  // Get user's hospital ID
  static Future<int?> getUserHospitalId(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.systemEndpoint}${ApiConfig.userHospitalPath}/$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data']['hospitalId'];
        }
      }
      return null;
    } catch (e) {
      print('Error fetching user hospital ID: $e');
      return null;
    }
  }
}
