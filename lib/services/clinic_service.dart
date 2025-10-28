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
      'Access-Control-Allow-Origin': '*', // optional
    };

    final body = jsonEncode({
      'text': 's',
      'flag': false,
      'fromNewInventory': true,
    });

    // print request details
    debugPrint('=== Clinic API HEADERS ===');
    headers.forEach((k, v) => debugPrint('$k: $v'));
    debugPrint('=== Clinic API BODY ===');
    debugPrint(body);

    final url = Uri.parse(
      'https://test.smartcarehis.com:8443/smartcaremain/clinic/details/clinicid/$clinicId',
    );

    final response = await http.post(url, headers: headers, body: body);

    // print response status and body
    debugPrint('Status: ${response.statusCode}');
    // if you want pretty JSON:
    try {
      final decoded = jsonDecode(response.body);
      final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
      debugPrint('Body:\n$pretty');
    } catch (_) {
      debugPrint('Body: ${response.body}');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load clinic details: ${response.statusCode} ${response.body}',
      );
    }

    // store if needed
    await prefs.setString('clinic_response', response.body);
  }
}
