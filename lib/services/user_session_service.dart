import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserSessionService {
  static const String _keyUserData = 'logged_in_user_data';
  static const String _keyHospitalId = 'hospital_id';
  static const String _keyUserId = 'user_id';
  static const String _keyToken = 'auth_token';

  static Future<void> storeUserData(Map<String, dynamic> loginData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserData, jsonEncode(loginData));
      final user = loginData['user'];
      if (user != null && user['assignments'] != null && user['assignments'].isNotEmpty) {
        final firstAssignment = user['assignments'][0];
        final hospitalId = firstAssignment['HospitalID'] ?? firstAssignment['hospitalID'] ?? firstAssignment['hospitalId'] ?? firstAssignment['HospitalId'];
        if (hospitalId != null) {
          await prefs.setInt(_keyHospitalId, hospitalId is int ? hospitalId : int.parse(hospitalId.toString()));
        }
      }
      final userId = user?['Id'] ?? user?['id'];
      if (userId != null) {
        await prefs.setInt(_keyUserId, userId is int ? userId : int.parse(userId.toString()));
      }
      final token = loginData['token'];
      if (token != null) {
        await prefs.setString(_keyToken, token.toString());
      }
    } catch (e) {
      print('Error storing user data: $e');
    }
  }

  static Future<int?> getHospitalId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyHospitalId);
    } catch (e) {
      return null;
    }
  }

  static Future<int?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyUserId);
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataJson = prefs.getString(_keyUserData);
      if (userDataJson != null) return jsonDecode(userDataJson);
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyToken);
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUserData);
      await prefs.remove(_keyHospitalId);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyToken);
    } catch (e) {}
  }

  static Future<int?> getHospitalDepartmentId() async {
    try {
      final userData = await getUserData();
      if (userData != null && userData['user'] != null) {
        final user = userData['user'];
        final assignments = user['assignments'] as List?;
        if (assignments != null && assignments.isNotEmpty) {
          final firstAssignment = assignments[0];
          final deptId = firstAssignment['hospitalDepartmentID'] ?? firstAssignment['hospitalDepartmentId'] ?? firstAssignment['departmentID'] ?? firstAssignment['departmentId'];
          if (deptId != null) return deptId is int ? deptId : int.tryParse(deptId.toString());
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> isLoggedIn() async {
    final hospitalId = await getHospitalId();
    final userId = await getUserId();
    return hospitalId != null && userId != null;
  }
}
