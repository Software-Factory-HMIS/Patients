import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/pharmacy_models.dart';

class PharmacyService {
  static String get baseUrl => ApiConfig.baseUrl;

  // Search patients for dispensing
  static Future<List<Patient>> searchPatients({
    required String searchTerm,
    String searchType = 'All',
    required int hospitalId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      String url = '$baseUrl/pharmacy/dispensing/search-patients?'
          'searchTerm=${Uri.encodeComponent(searchTerm)}'
          '&searchType=$searchType'
          '&hospitalId=$hospitalId';
      
      if (dateFrom != null) {
        final dateFromStr = '${dateFrom.year}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
        url += '&dateFrom=$dateFromStr';
      }
      
      if (dateTo != null) {
        final dateToStr = '${dateTo.year}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
        url += '&dateTo=$dateToStr';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('API Response for patient search: $data');
        return data.map((json) => Patient.fromJson(json)).toList();
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to search patients: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching patients: $e');
    }
  }

  // Search patients for order search (includes all order statuses: Pending, Partial, Complete)
  static Future<List<Patient>> searchPatientsForOrders({
    required String searchTerm,
    String searchType = 'All',
    required int hospitalId,
  }) async {
    try {
      String url = '$baseUrl/pharmacy/dispensing/search-patients-for-orders?'
          'searchTerm=${Uri.encodeComponent(searchTerm)}'
          '&searchType=$searchType'
          '&hospitalId=$hospitalId';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Patient.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search patients for orders: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching patients for orders: $e');
    }
  }

  // Get patient's pending orders
  static Future<List<Order>> getPatientOrders({
    required int patientId,
    required int hospitalId,
    int? pharmacyLocationId,
  }) async {
    try {
      String url = '$baseUrl/pharmacy/dispensing/patient-orders/$patientId?hospitalId=$hospitalId';
      if (pharmacyLocationId != null) {
        url += '&pharmacyLocationId=$pharmacyLocationId';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Order.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get patient orders: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting patient orders: $e');
    }
  }

  // Get order items with stock availability
  static Future<List<OrderItem>> getOrderItems({
    required int orderId,
    required int pharmacyLocationId,
    required int hospitalId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pharmacy/dispensing/order-items/$orderId?'
            'pharmacyLocationId=$pharmacyLocationId'
            '&hospitalId=$hospitalId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => OrderItem.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get order items: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting order items: $e');
    }
  }

  // Dispense medicines
  static Future<Map<String, dynamic>> dispenseMedicines({
    required int orderId,
    required int pharmacyLocationId,
    required int dispensingPharmacist,
    required List<DispensingItem> dispensingItems,
    required int hospitalId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/pharmacy/dispensing/dispense'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'orderId': orderId,
          'pharmacyLocationId': pharmacyLocationId,
          'dispensingPharmacist': dispensingPharmacist,
          'dispensingItems': dispensingItems.map((item) => item.toJson()).toList(),
          'hospitalId': hospitalId,
        }),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return {'success': true, 'message': result};
      } else {
        throw Exception('Failed to dispense medicines: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error dispensing medicines: $e');
    }
  }

  // Get dispensing history
  static Future<List<Map<String, dynamic>>> getDispensingHistory({
    required int patientId,
    required int hospitalId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      String url = '$baseUrl/pharmacy/dispensing/history/$patientId?hospitalId=$hospitalId';
      
      if (dateFrom != null) {
        url += '&dateFrom=${dateFrom.toIso8601String().split('T')[0]}';
      }
      if (dateTo != null) {
        url += '&dateTo=${dateTo.toIso8601String().split('T')[0]}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get dispensing history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting dispensing history: $e');
    }
  }

  // Get pharmacy locations
  static Future<List<PharmacyLocation>> getPharmacyLocations({
    required int hospitalId,
  }) async {
    try {
      final url = '$baseUrl/pharmacy/dispensing/locations?hospitalId=$hospitalId';
      print('🌐 [PharmacyService] Calling getPharmacyLocations with URL: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => PharmacyLocation.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get pharmacy locations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting pharmacy locations: $e');
    }
  }

  // Get pharmacy statistics
  static Future<Map<String, dynamic>> getPharmacyStats({
    required int hospitalId,
    int? pharmacyLocationId,
  }) async {
    try {
      String url = '$baseUrl/pharmacy/dispensing/stats?hospitalId=$hospitalId';
      if (pharmacyLocationId != null) {
        url += '&pharmacyLocationId=$pharmacyLocationId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('Failed to get pharmacy stats: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting pharmacy stats: $e');
    }
  }

  // Get pending orders with pagination
  static Future<Map<String, dynamic>> getPendingOrders({
    required int hospitalId,
    int? locationId,
    String? priority,
    int? patientId,
    int? maxAge,
    String? searchTerm,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      String url = '$baseUrl/pharmacy/orders/pending?hospitalId=$hospitalId&page=$page&pageSize=$pageSize';
      if (locationId != null) url += '&locationId=$locationId';
      if (priority != null) url += '&priority=$priority';
      if (patientId != null) url += '&patientId=$patientId';
      if (maxAge != null) url += '&maxAge=$maxAge';
      if (searchTerm != null && searchTerm.isNotEmpty) {
        url += '&searchTerm=${Uri.encodeComponent(searchTerm)}';
      }
      if (dateFrom != null) {
        final dateFromStr = '${dateFrom.year}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
        url += '&dateFrom=$dateFromStr';
      }
      if (dateTo != null) {
        final dateToStr = '${dateTo.year}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
        url += '&dateTo=$dateToStr';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'orders': (data['orders'] as List?)?.cast<Map<String, dynamic>>() ?? [],
          'total': data['total'] ?? 0,
          'page': data['page'] ?? page,
          'pageSize': data['pageSize'] ?? pageSize,
          'totalPages': data['totalPages'] ?? 1,
        };
      } else {
        throw Exception('Failed to get pending orders: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting pending orders: $e');
    }
  }

  // Get dispensed orders for today with pagination
  static Future<Map<String, dynamic>> getDispensedOrdersToday({
    required int hospitalId,
    int? locationId,
    DateTime? date,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? searchTerm,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      String url = '$baseUrl/pharmacy/dispensing/dispensed-today?hospitalId=$hospitalId&page=$page&pageSize=$pageSize';
      if (locationId != null) url += '&pharmacyLocationId=$locationId';
      if (date != null) {
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        url += '&dispensingDate=$dateStr';
      }
      if (dateFrom != null) {
        final dateFromStr = '${dateFrom.year}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
        url += '&dateFrom=$dateFromStr';
      }
      if (dateTo != null) {
        final dateToStr = '${dateTo.year}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
        url += '&dateTo=$dateToStr';
      }
      if (searchTerm != null && searchTerm.isNotEmpty) {
        url += '&searchTerm=${Uri.encodeComponent(searchTerm)}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'orders': (data['orders'] as List?)?.cast<Map<String, dynamic>>() ?? [],
          'total': data['total'] ?? 0,
          'page': data['page'] ?? page,
          'pageSize': data['pageSize'] ?? pageSize,
          'totalPages': data['totalPages'] ?? 1,
        };
      } else {
        throw Exception('Failed to get dispensed orders: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting dispensed orders: $e');
    }
  }

  // Get all dispensers in hospital
  static Future<List<Map<String, dynamic>>> getDispensers({
    required int hospitalId,
  }) async {
    try {
      final url = '$baseUrl/pharmacy/dispensing/dispensers?hospitalId=$hospitalId';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get dispensers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting dispensers: $e');
    }
  }

  // Get dispenser summary
  static Future<List<Map<String, dynamic>>> getDispenserSummary({
    required int hospitalId,
    int? dispenserId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    try {
      final dateFromStr = '${dateFrom.year}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
      final dateToStr = '${dateTo.year}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
      
      String url = '$baseUrl/pharmacy/dispensing/dispenser-summary?hospitalId=$hospitalId&dateFrom=$dateFromStr&dateTo=$dateToStr';
      if (dispenserId != null) url += '&dispenserId=$dispenserId';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get dispenser summary: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting dispenser summary: $e');
    }
  }

  // Get pharmacy location summary
  static Future<List<Map<String, dynamic>>> getPharmacyLocationSummary({
    required int hospitalId,
    int? pharmacyLocationId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    try {
      final dateFromStr = '${dateFrom.year}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
      final dateToStr = '${dateTo.year}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
      
      String url = '$baseUrl/pharmacy/dispensing/pharmacy-location-summary?hospitalId=$hospitalId&dateFrom=$dateFromStr&dateTo=$dateToStr';
      if (pharmacyLocationId != null) url += '&pharmacyLocationId=$pharmacyLocationId';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get pharmacy location summary: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting pharmacy location summary: $e');
    }
  }

  // Get daily consumption summary
  static Future<List<Map<String, dynamic>>> getDailyConsumptionSummary({
    required int hospitalId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    try {
      final dateFromStr = '${dateFrom.year}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
      final dateToStr = '${dateTo.year}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
      
      final url = '$baseUrl/pharmacy/dispensing/daily-consumption?hospitalId=$hospitalId&dateFrom=$dateFromStr&dateTo=$dateToStr';

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get daily consumption summary: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting daily consumption summary: $e');
    }
  }

  // Get consumption details for drill-down
  static Future<List<Map<String, dynamic>>> getConsumptionDetails({
    required int hospitalId,
    required DateTime date,
    String? medicineName,
    int? medicineId,
    int? pharmacyLocationId,
  }) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      final uri = Uri.parse('$baseUrl/pharmacy/dispensing/consumption-details').replace(
        queryParameters: {
          'hospitalId': hospitalId.toString(),
          'dispensingDate': dateStr,
          if (medicineId != null) 'medicineId': medicineId.toString(),
          // Prefer ID over name to avoid ItemName vs Medicines.name mismatch
          if (medicineId == null && medicineName != null && medicineName.isNotEmpty) 'medicineName': medicineName,
          if (pharmacyLocationId != null) 'pharmacyLocationId': pharmacyLocationId.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get consumption details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting consumption details: $e');
    }
  }

  // Search medicines
  static Future<List<Map<String, dynamic>>> searchMedicines({
    required String searchTerm,
    required int hospitalId,
    bool activeOnly = true,
    int pageSize = 7,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/pharmacy/medicines').replace(
        queryParameters: {
          'searchTerm': searchTerm,
          'hospitalId': hospitalId.toString(),
          'activeOnly': activeOnly.toString(),
          'pageSize': pageSize.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to search medicines: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching medicines: $e');
    }
  }

  // Get frequencies
  static Future<List<Map<String, dynamic>>> getFrequencies({
    bool activeOnly = true,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/pharmacy/medicines/frequencies').replace(
        queryParameters: {
          'activeOnly': activeOnly.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get frequencies: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting frequencies: $e');
    }
  }

  // Get active medicines for a patient (EndDate >= today AND DiscontinuedDate IS NULL)
  // If whichDate is provided, uses that date as reference instead of today
  static Future<List<Map<String, dynamic>>> getActivePatientMedicines({
    required int patientId,
    String? whichDate,
    bool getAllHistory = false,
  }) async {
    try {
      String url = '$baseUrl/pharmacy/patient/$patientId/active-medicines';
      List<String> params = [];
      if (whichDate != null && whichDate.isNotEmpty) {
        params.add('whichDate=$whichDate');
      }
      if (getAllHistory) {
        params.add('getAllHistory=true');
      }
      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get active medicines: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting active medicines: $e');
    }
  }

  // Discontinue a medicine (set DiscontinuedDate to today)
  static Future<Map<String, dynamic>> discontinueMedicine({
    required int orderItemId,
    required int hospitalId,
    required int updatedBy,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/pharmacy/order-items/$orderItemId/discontinue'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'hospitalId': hospitalId,
          'updatedBy': updatedBy,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return data is Map ? Map<String, dynamic>.from(data) : {'success': true};
      } else {
        throw Exception('Failed to discontinue medicine: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error discontinuing medicine: $e');
    }
  }

  // Get medicines by encounter type (for mobile app medicine order form)
  static Future<List<Map<String, dynamic>>> getMedicinesByEncounterType({
    required int hospitalId,
    required String encounterType, // comma list allowed
    int showZeroStock = -1, // -1 to show all, 0 to hide zero stock
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/pharmacy/medicines/by-encounter-type').replace(
        queryParameters: {
          'hospitalId': hospitalId.toString(),
          'encounterType': encounterType,
          'showZeroStock': showZeroStock.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get medicines: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting medicines: $e');
    }
  }

  // Create pharmacy order
  static Future<Map<String, dynamic>> createPharmacyOrder({
    required String orderNumber,
    required int patientId,
    required int hospitalId,
    required int prescribedBy,
    required String orderType,
    required DateTime orderDate,
    required String priority,
    String? diagnosis,
    String? notes,
    String? diagnosisSummary,
    required List<Map<String, dynamic>> orderItems,
    required int createdBy,
    int? encounterId,
    String? tokenNumber,
    String? mrn,
  }) async {
    try {
      final body = {
        'orderNumber': orderNumber,
        'patientId': patientId,
        'hospitalId': hospitalId,
        'prescribedBy': prescribedBy,
        'orderType': orderType,
        'orderDate': orderDate.toIso8601String().split('T')[0],
        'priority': priority,
        if (diagnosis != null) 'diagnosis': diagnosis,
        if (notes != null) 'notes': notes,
        if (diagnosisSummary != null && diagnosisSummary.isNotEmpty) 'diagnosisSummary': diagnosisSummary,
        'orderItems': orderItems, // Send as array, API will convert to JSON string
        'createdBy': createdBy,
        if (encounterId != null) 'encounterId': encounterId,
        if (tokenNumber != null && tokenNumber.isNotEmpty) 'tokenNumber': tokenNumber,
        if (mrn != null && mrn.isNotEmpty) 'mrn': mrn,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/pharmacy/orders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        dynamic result;
        try {
          result = jsonDecode(response.body);
          // If result is a string, try to decode it again (API might return JSON as string)
          if (result is String) {
            result = jsonDecode(result);
          }
        } catch (e) {
          // If parsing fails, check if response body is a plain string
          result = response.body;
        }
        
        // Check if the result indicates failure
        if (result is Map && result.containsKey('success') && result['success'] == false) {
          final errorMsg = result['error'] ?? 'Unknown error';
          throw Exception('Failed to create pharmacy order: $errorMsg');
        }
        
        return result is Map ? Map<String, dynamic>.from(result) : {'success': true, 'data': result};
      } else {
        dynamic errorBody;
        try {
          errorBody = response.body.isNotEmpty ? jsonDecode(response.body) : null;
        } catch (e) {
          errorBody = {'error': response.body};
        }
        
        final errorMsg = errorBody is Map && errorBody.containsKey('error') 
            ? errorBody['error'] 
            : 'HTTP ${response.statusCode}';
        throw Exception('Failed to create pharmacy order: $errorMsg');
      }
    } catch (e) {
      throw Exception('Error creating pharmacy order: $e');
    }
  }

  // Get patients for order history with search
  static Future<List<Patient>> getTopPatients({
    required int hospitalId,
    String? searchTerm,
    String searchType = 'All',
  }) async {
    try {
      String url = '$baseUrl/pharmacy/dispensing/top-patients?hospitalId=$hospitalId';
      if (searchTerm != null && searchTerm.isNotEmpty) {
        url += '&searchTerm=${Uri.encodeComponent(searchTerm)}';
        url += '&searchType=$searchType';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Patient.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get patients: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting patients: $e');
    }
  }

  // Get all patient orders (not just pending) for order history
  static Future<List<Order>> getPatientAllOrders({
    required int patientId,
    required int hospitalId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pharmacy/dispensing/patient-all-orders/$patientId?hospitalId=$hospitalId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Order.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get patient orders: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting patient orders: $e');
    }
  }

  // Get order items with dispensed quantities for order history
  static Future<List<OrderItem>> getOrderItemsHistory({
    required int orderId,
    required int hospitalId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pharmacy/dispensing/order-items-history/$orderId?hospitalId=$hospitalId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => OrderItem.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get order items history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting order items history: $e');
    }
  }
}
