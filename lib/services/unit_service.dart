import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UnitService {
  static const String _url =
      'https://test.smartcarehis.com:8443/smartcaremain/priscriptionmaster/strengthlist';

  static Future<List<String>> fetchUnits() async {
    final prefs = await SharedPreferences.getInstance();

    String getPrefAsString(String key) =>
        prefs.get(key)?.toString() ?? '';

    final token = getPrefAsString('auth_token');
    final clinicId = getPrefAsString('clinicId');
    final branchId = getPrefAsString('branchId');
    final userId = getPrefAsString('userId');
    final zoneid = getPrefAsString('zoneid');

    final headers = {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Authorization': token.startsWith('SmartCare')
          ? token
          : 'SmartCare $token',
      'clinicid': clinicId,
      'zoneid': zoneid,
      'userid': userId,
      'branchId': branchId,
    };

    final response = await http.get(
      Uri.parse(_url),
      headers: headers,
    );

    debugPrint('Unit API status: ${response.statusCode}');
    debugPrint('Unit API body: ${response.body}');

    if (response.statusCode == 200) {
      final List decoded = jsonDecode(response.body);
      debugPrint('Decoded unit data: $decoded');

      // Extract only names
      final units = decoded
          .map((e) => (e['name'] ?? '') as String)
          .where((name) => name.isNotEmpty)
          .toList();

      // Save for offline use
      await prefs.setStringList('cached_units', units);

      return units;
    } else {
      throw Exception('Failed to load units. Code: ${response.statusCode}');
    }
  }

  static Future<List<String>> getCachedUnits() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('cached_units') ?? <String>[];
  }

  static Future<void> cacheUnits(List<String> fetchedUnits) async {}
}
