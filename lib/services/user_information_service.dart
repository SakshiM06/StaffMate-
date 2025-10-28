import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserInformationService {
  /// Fetch user information from the API and save it to SharedPreferences.
  Future<void> fetchAndSaveUserInformation({
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

    // Debug logs
    debugPrint('=== User Information API HEADERS ===');
    headers.forEach((k, v) => debugPrint('$k: $v'));

    final url = Uri.parse(
      'https://test.smartcarehis.com:8443/smartcaremain/userinformation',
    );

    // ✅ use GET instead of POST to avoid 405
    final response = await http.get(url, headers: headers);

    debugPrint('Status: ${response.statusCode}');
    try {
      final decoded = jsonDecode(response.body);
      final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
      debugPrint('Body_kkkkkkkkkk:\n$pretty');
    } catch (_) {
      debugPrint('Body: ${response.body}');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch user information: ${response.statusCode} ${response.body}',
      );
    }

    // Parse nested 'data' from response
    final Map<String, dynamic> json = jsonDecode(response.body);
    final Map<String, dynamic> data = json['data'] ?? {};

    final bearer = data['bearer']?.toString() ?? '';
    final newToken = data['token']?.toString() ?? '';
    final newClinicId = data['clinicUserid']?.toString() ?? '';
    final newUserId = data['userId']?.toString() ?? '';
    final newZoneId = data['zoneid']?.toString() ?? '';
    // final newBranchId = branchId.toString(); // still from parameter
    final expirytime = data['expirytime']?.toString() ?? '';
    final subDays = data['subscription_remaining_days']?.toString() ?? '';

    // Save to SharedPreferences
    await prefs.setString('bearer', bearer);
    await prefs.setString('token', newToken);
    await prefs.setString('clinicId', newClinicId);
    await prefs.setString('userId', newUserId);
    await prefs.setString('zoneid', newZoneId);
    // await prefs.setString('branchId', newBranchId);
    await prefs.setString('expirytime', expirytime);
    await prefs.setString('subscription_remaining_days', subDays);
  }

  /// Get all saved user information from SharedPreferences.
  static Future<Map<String, String>> getSavedUserInformation() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'bearer': prefs.getString('bearer') ?? '',
      'token': prefs.getString('token') ?? '',
      'clinicId': prefs.getString('clinicId') ?? '',
      'userId': prefs.getString('userId') ?? '',
      'zoneid': prefs.getString('zoneid') ?? '',
      'branchId': prefs.getString('branchId') ?? '',
      'expirytime': prefs.getString('expirytime') ?? '',
      'subscription_remaining_days':
          prefs.getString('subscription_remaining_days') ?? '',
    };
  }

  Future getUserInformation() async {}
}
