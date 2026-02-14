import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HomeService {
  static const String _baseUrl = 'https://test.smartcarehis.com:8443/smartcaremain/clinic';
  
  // static const String _dobEndpoint = '/clinic/dob';
  

static Future<Map<String, dynamic>> getStaffByDob(
  String dob, {
  Map<String, dynamic>? additionalParams,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    final token = prefs.getString('auth_token') ?? '';
    final clinicId = prefs.getString('clinicId') ?? '';
    final userId = prefs.getString('userId') ?? '';
    final branchId = prefs.getString('branchId') ?? '';

 
    if (token.isEmpty) {
      throw Exception('Authentication token missing');
    }
    if (clinicId.isEmpty) {
      throw Exception('Clinic ID missing');
    }
    if (userId.isEmpty) {
      throw Exception('User ID missing');
    }

    if (!_isValidDobFormat(dob)) {
      throw Exception('Invalid date format. Please use dd-MM-yyyy format');
    }

    // final url = 'https://test.smartcarehis.com:8443/smartcaremain/clinic/dob/$dob';
   
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Authorization': 'SmartCare $token',
      'clinicid': clinicId,
      'userid': userId,
      'ZONEID': 'Asia/Kolkata',
      if (branchId.isNotEmpty) 'branchId': branchId,
    };

    debugPrint('=== STAFF DOB API REQUEST DEBUG ===');
    debugPrint('URL: $_baseUrl/dob/$dob');
    debugPrint('Headers: ${_sanitizeHeaders(headers)}');
    debugPrint('Date of Birth: $dob');
    
    if (additionalParams != null && additionalParams.isNotEmpty) {
      debugPrint('Additional Params: $additionalParams');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/dob/$dob'),
      headers: headers,
    ).timeout(const Duration(seconds: 30));

    debugPrint('=== STAFF DOB API RESPONSE DEBUG ===');
    debugPrint('Status Code: ${response.statusCode}');
    debugPrint('Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      
    
      if (decoded['message'] == 'Staff DOB Fetched Successfully' || 
          decoded['data'] is List) {
        return decoded;
      }
      
      return {'data': [], 'message': 'No staff birthdays found', 'status_code': 200};
      
    } else if (response.statusCode == 404) {
      debugPrint('No staff found for date $dob, returning empty list');
      return {'data': [], 'message': 'No staff birthdays found', 'status_code': 200};
    } else if (response.statusCode == 401) {
      throw Exception('Authentication failed. Please login again.');
    } else if (response.statusCode == 403) {
      throw Exception('Access forbidden. Check your permissions.');
    } else {
      String errorMessage = 'Error ${response.statusCode}: Failed to fetch staff details';
      try {
        final err = jsonDecode(response.body);
        if (err is Map && err['message'] != null) {
          errorMessage = err['message'].toString();
        } else if (err is Map && err['error'] != null) {
          errorMessage = err['error'].toString();
        } else if (err is String) {
          errorMessage = err;
        }
      } catch (_) {
        errorMessage = 'Server error: ${response.reasonPhrase}';
      }
      throw Exception(errorMessage);
    }
  } catch (e) {
    debugPrint('HomeService Error (getStaffByDob): $e');
    rethrow;
  }
}

  static Future<Map<String, dynamic>> getPatientByDobWithQuery(
    String dob, {
    Map<String, String>? queryParams,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final token = prefs.getString('auth_token') ?? '';
      final clinicId = prefs.getString('clinicId') ?? '';
      final userId = prefs.getString('userId') ?? '';
      final branchId = prefs.getString('branchId') ?? '';

      if (token.isEmpty) {
        throw Exception('Authentication token missing');
      }

      if (!_isValidDobFormat(dob)) {
        throw Exception('Invalid date format. Please use dd-MM-yyyy format');
      }

      final uri = Uri.parse('$_baseUrl/$dob').replace(
        queryParameters: {
          'dob': dob,
          ...?queryParams,
        },
      );

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        if (branchId.isNotEmpty) 'branchId': branchId,
      };

      debugPrint('=== DOB QUERY API REQUEST ===');
      debugPrint('URL: ${uri.toString()}');
    debugPrint('Dob Headers: $headers');

      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      debugPrint('=== DOB QUERY API RESPONSE ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return decoded;
      } else {
        String errorMessage = 'Error ${response.statusCode}';
        try {
          final err = jsonDecode(response.body);
          if (err is Map && err['message'] != null) {
            errorMessage = err['message'].toString();
          }
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('HomeService Error (getPatientByDobWithQuery): $e');
      rethrow;
    }
  }

  static Future<void> _cacheDobResponse(String dob, Map<String, dynamic> response) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      

      final cachedResponsesJson = prefs.getString('cached_dob_responses') ?? '{}';
      final cachedResponses = jsonDecode(cachedResponsesJson) as Map<String, dynamic>;

      cachedResponses[dob] = {
        'response': response,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
   
      await prefs.setString(
        'cached_dob_responses',
        jsonEncode(cachedResponses),
      );
      
      debugPrint('Response cached for DOB: $dob');
    } catch (e) {
      debugPrint('Error caching DOB response: $e');
    }
  }

  static Future<Map<String, dynamic>?> getCachedDobResponse(String dob) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedResponsesJson = prefs.getString('cached_dob_responses') ?? '{}';
      final cachedResponses = jsonDecode(cachedResponsesJson) as Map<String, dynamic>;
      
      if (cachedResponses.containsKey(dob)) {
        final cachedData = cachedResponses[dob] as Map<String, dynamic>;
        final timestamp = DateTime.parse(cachedData['timestamp'] as String);
        final now = DateTime.now();
   
        if (now.difference(timestamp).inHours < 1) {
          return cachedData['response'] as Map<String, dynamic>;
        } else {
          cachedResponses.remove(dob);
          await prefs.setString(
            'cached_dob_responses',
            jsonEncode(cachedResponses),
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cached DOB response: $e');
      return null;
    }
  }
  static Future<void> clearDobCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_dob_responses');
      debugPrint('All DOB cache cleared');
    } catch (e) {
      debugPrint('Error clearing DOB cache: $e');
    }
  }

  static bool _isValidDobFormat(String dob) {
    final pattern = RegExp(r'^\d{2}-\d{2}-\d{4}$');
    if (!pattern.hasMatch(dob)) return false;
    
    try {
      final parts = dob.split('-');
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      
   
      if (day < 1 || day > 31) return false;
      if (month < 1 || month > 12) return false;
      if (year < 1900 || year > DateTime.now().year) return false;
      
      final date = DateTime(year, month, day);
      return date.day == day && date.month == month && date.year == year;
    } catch (e) {
      return false;
    }
  }

  static String formatDob(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day-$month-$year';
  }

 
  static DateTime? parseDob(String dateString) {
    try {
      if (dateString.contains('-')) {
        final parts = dateString.split('-');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          return DateTime(year, month, day);
        }
      }
      
      return DateTime.tryParse(dateString);
    } catch (e) {
      debugPrint('Error parsing date: $e');
      return null;
    }
  }

  static Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    final sanitized = Map<String, String>.from(headers);
    if (sanitized['Authorization'] != null) {
      sanitized['Authorization'] = 'SmartCare ***';
    }
    if (sanitized['clinicid'] != null) {
      sanitized['clinicid'] = '***';
    }
    if (sanitized['userid'] != null) {
      sanitized['userid'] = '***';
    }
    return sanitized;
  }

  static Future<bool> testConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      
      if (token.isEmpty) return false;
      
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {
          'Authorization': 'SmartCare $token',
        },
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return false;
    }
  }
}