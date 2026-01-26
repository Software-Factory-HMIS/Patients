import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserStorage {
  static const String _userDataKey = 'registered_user_data';
  static const String _phoneKey = 'last_phone_number';

  static const String _recentAppointmentsKey = 'recent_appointments';
  static const String _lastHospitalIdKey = 'last_hospital_id';
  static const String _lastDepartmentIdKey = 'last_department_id';
  static const String _lastHospitalDepartmentIdKey = 'last_hospital_department_id';

  // Save registered user data (for self registration only)
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert DateTime to ISO string for storage
      final dataToSave = Map<String, dynamic>.from(userData);
      if (dataToSave['dateOfBirth'] != null && dataToSave['dateOfBirth'] is DateTime) {
        dataToSave['dateOfBirth'] = (dataToSave['dateOfBirth'] as DateTime).toIso8601String();
      }

      // Save user data as JSON string
      await prefs.setString(_userDataKey, json.encode(dataToSave));

      // Also save phone number separately for quick access
      if (userData['phone'] != null) {
        await prefs.setString(_phoneKey, userData['phone'] as String);
      }
    } catch (e) {
      // ignore
    }
  }

  // Get saved user data
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString(_userDataKey);

      if (userDataString == null) {
        return null;
      }

      final userData = json.decode(userDataString) as Map<String, dynamic>;

      // Convert ISO string back to DateTime
      if (userData['dateOfBirth'] != null && userData['dateOfBirth'] is String) {
        userData['dateOfBirth'] = DateTime.parse(userData['dateOfBirth'] as String);
      }

      return userData;
    } catch (e) {
      return null;
    }
  }

  // Get saved phone number
  static Future<String?> getPhoneNumber() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_phoneKey);
    } catch (e) {
      return null;
    }
  }

  // Clear saved user data
  static Future<void> clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userDataKey);
      await prefs.remove(_phoneKey);
    } catch (e) {
      // ignore
    }
  }

  // Check if user data exists
  static Future<bool> hasUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_userDataKey);
    } catch (e) {
      return false;
    }
  }

  // Save recent appointments
  static Future<void> saveRecentAppointments(List<Map<String, dynamic>> appointments) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_recentAppointmentsKey, json.encode(appointments));
    } catch (e) {
      // ignore
    }
  }

  // Get saved recent appointments
  static Future<List<Map<String, dynamic>>?> getRecentAppointments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final appointmentsString = prefs.getString(_recentAppointmentsKey);

      if (appointmentsString == null) {
        return null;
      }

      final appointmentsList = json.decode(appointmentsString) as List;
      return appointmentsList.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearRecentAppointments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentAppointmentsKey);
    } catch (e) {
      // ignore
    }
  }

  static Future<void> saveLastHospitalSelection({
    int? hospitalId,
    int? departmentId,
    int? hospitalDepartmentId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (hospitalId != null) await prefs.setInt(_lastHospitalIdKey, hospitalId);
      if (departmentId != null) await prefs.setInt(_lastDepartmentIdKey, departmentId);
      if (hospitalDepartmentId != null) await prefs.setInt(_lastHospitalDepartmentIdKey, hospitalDepartmentId);
    } catch (e) {
      // ignore
    }
  }

  static Future<int?> getLastHospitalId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_lastHospitalIdKey);
    } catch (e) {
      return null;
    }
  }

  static Future<int?> getLastDepartmentId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_lastDepartmentIdKey);
    } catch (e) {
      return null;
    }
  }

  static Future<int?> getLastHospitalDepartmentId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_lastHospitalDepartmentIdKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearAllLocalData() async {
    await clearUserData();
    await clearRecentAppointments();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastHospitalIdKey);
      await prefs.remove(_lastDepartmentIdKey);
      await prefs.remove(_lastHospitalDepartmentIdKey);
    } catch (e) {
      // ignore
    }
  }
}
