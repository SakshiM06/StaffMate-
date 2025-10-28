import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FrequencyService {
  static const String _url =
      'https://test.smartcarehis.com:8443/smartcaremain/priscriptionmaster/datalist';

  /// Fetch frequencies, routes, and dosage times from API
  static Future<Map<String, List<String>>> fetchFrequencies() async {
    final prefs = await SharedPreferences.getInstance();

    String getPrefAsString(String key) => prefs.getString(key) ?? '';

    // 🔹 Dynamically fetched values
    final token = getPrefAsString('auth_token');
    final clinicId = getPrefAsString('clinicId');
    final branchId = getPrefAsString('branchId');
    final userId = getPrefAsString('userId');
    final zoneid = getPrefAsString('zoneid');

    // 🔹 Build headers dynamically
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

    // 🔹 API call
    final response = await http.get(
      Uri.parse(_url),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> decodedJson = jsonDecode(response.body);

      // Ensure lists exist
      final List dosagelist = decodedJson['dosagelist'] ?? [];
      final List routelist = decodedJson['routelist'] ?? [];
      final List dosagetimelist = decodedJson['dosagetimelist'] ?? [];

      // 🔹 Extract string names safely
      final frequencies = dosagelist
          .map((e) => (e['name'] ?? '') as String)
          .where((name) => name.isNotEmpty)
          .toList();

      final routes = routelist
          .map((e) => (e['name'] ?? '') as String)
          .where((name) => name.isNotEmpty)
          .toList();

      final dosageTimes = dosagetimelist
          .map((e) => (e['name'] ?? '') as String)
          .where((name) => name.isNotEmpty)
          .toList();

      // 🔹 Save to SharedPreferences for offline use
      await cacheData(frequencies, routes, dosageTimes);

      return {
        'frequencies': frequencies,
        'routes': routes,
        'dosageTimes': dosageTimes,
 };
    } else {
      throw Exception(
          'Failed to load data. Code: ${response.statusCode}');
    }
  }

  /// Returns cached frequencies, routes, and dosage times if available
  static Future<Map<String, List<String>>> getCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'frequencies': prefs.getStringList('cached_frequencies') ?? <String>[],
      'routes': prefs.getStringList('cached_routes') ?? <String>[],
      'dosageTimes':
          prefs.getStringList('cached_dosagetimes') ?? <String>[],
    };
  }

  /// Caches fetched data
  static Future<void> cacheData(
      List<String> frequencies, List<String> routes, List<String> dosageTimes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('cached_frequencies', frequencies);
    await prefs.setStringList('cached_routes', routes);
    await prefs.setStringList('cached_dosagetimes', dosageTimes);
  }
}
