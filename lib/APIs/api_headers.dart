// lib/core/api/api_headers.dart

import 'package:shared_preferences/shared_preferences.dart';

class ApiHeaders {
  /// Get headers for API requests - Exactly like your React apiHeaders function
  static Future<Map<String, String>> getHeaders({
    String? patientId,
    bool isClinicAdmin = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    final authToken = prefs.getString('auth_token') ?? '';
    final authorizationToken = 'SmartCare $authToken';
    final zoneId = prefs.getString('ZONEID') ?? 'Asia/Kolkata';
    final userId = prefs.getString('userId') ?? '';
    final branchId = prefs.getString('branchId') ?? '1';
    final clinicId = prefs.getString('clinicId') ?? 'hr_staging';
    final empid = prefs.getString('empId') ?? '';
    
    // Exactly like your React apiHeaders function
    return {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'clinicid': isClinicAdmin ? 'admin' : clinicId,
      // 'Authorization': authorizationToken, // You can uncomment if needed
      // 'zoneid': zoneId, // You can uncomment if needed
      // 'userid': userId, // You can uncomment if needed
      // 'branchId': branchId, // You can uncomment if needed
      // 'patientid': patientId ?? '', // You can uncomment if needed
      'empid': empid,
    };
  }
  
  /// Get auth token for specific APIs
  static Future<String> getAuthHeader() async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token') ?? '';
    return authToken.startsWith('SmartCare') 
        ? authToken 
        : 'SmartCare $authToken';
  }
}