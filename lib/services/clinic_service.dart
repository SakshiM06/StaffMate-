import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClinicService {
  Future<void> fetchAndSaveClinicDetails({
    required String token,
    required String clinicId,
    required String userId,
    required String zoneid,
    required int branchId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'SmartCare $token',
      'clinicid': clinicId,
      'userid': userId,
      'zoneid': zoneid,
      'branchId': branchId.toString(),
      'Access-Control-Allow-Origin': '*',
    };

    final body = jsonEncode({
      'text': 's',
      'flag': false,
      'fromNewInventory': true,
    });

    debugPrint('=== Clinic API HEADERS ===');
    headers.forEach((k, v) => debugPrint('$k: $v'));
    debugPrint('=== Clinic API BODY ===');
    debugPrint(body);

    final url = Uri.parse(
      'https://test.smartcarehis.com:8443/smartcaremain/clinic/details/clinicid/$clinicId',
    );

    final response = await http.post(url, headers: headers, body: body);

    debugPrint('Status Charge: ${response.statusCode}');
    
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load clinic details: ${response.statusCode} ${response.body}',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      
      // Save the entire response
      await prefs.setString('clinic_response', response.body);
      
      // Extract and save excessLimit separately for easy access
      final excessLimit = decoded['excessLimit'] ?? "0";
      await prefs.setString('excessLimit', excessLimit.toString());
      
      debugPrint('Saved excessLimit: $excessLimit');
      
      final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
      debugPrint('Body:\n$pretty');
    } catch (e) {
      debugPrint('Error parsing clinic response: $e');
      debugPrint('Body: ${response.body}');
    }
  }

  // Method to get excess limit from SharedPreferences
  static Future<double> getExcessLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final excessLimitString = prefs.getString('excessLimit') ?? "0";
    
    try {
      return double.tryParse(excessLimitString) ?? 0.0;
    } catch (e) {
      debugPrint('Error parsing excess limit: $e');
      return 0.0;
    }
  }

  // Method to fetch excess limit directly (if needed)
  Future<double> fetchExcessLimitDirectly({
    required String token,
    required String clinicId,
    required String userId,
    required String zoneid,
    required int branchId,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'SmartCare $token',
      'clinicid': clinicId,
      'userid': userId,
      'zoneid': zoneid,
      'branchId': branchId.toString(),
    };

    final body = jsonEncode({
      'text': 's',
      'flag': false,
      'fromNewInventory': true,
    });

    final url = Uri.parse(
      'https://test.smartcarehis.com:8443/smartcaremain/clinic/details/clinicid/$clinicId',
    );

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final excessLimitString = decoded['excessLimit'] ?? "0";
      return double.tryParse(excessLimitString) ?? 0.0;
    }
    
    return 0.0;
  }
}