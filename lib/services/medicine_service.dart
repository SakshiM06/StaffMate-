import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MedicineService {
  static const String _listUrl =
      'https://test.smartcarehis.com:8443/smartcaremain/priscriptionmaster/medicinelist';
  static const String _detailsUrl =
      'https://test.smartcarehis.com:8443/smartcaremain/priscriptionmaster/medicinedetails';

  /// Fetch medicine list from API & cache it
  static Future<List<String>> fetchMedicines({required String query}) async {
    final prefs = await SharedPreferences.getInstance();

    String getPrefAsString(String key) {
      final val = prefs.get(key);
      return val?.toString() ?? '';
    }

    final token = getPrefAsString('auth_token');
    final clinicId = getPrefAsString('clinicId');
    final branchId = getPrefAsString('branchId');
    final userId = getPrefAsString('userId');
    final zoneid = getPrefAsString('zoneid');

    final headers = {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Authorization': token.startsWith('SmartCare') ? token : 'SmartCare $token',
      'clinicid': clinicId,
      'zoneid': zoneid,
      'userid': userId,
      'branchId': branchId,
    };

    final listBody = jsonEncode({
      "text": query,
      "flag": false,
      "fromNewInventory": true,
    });

    final listResponse = await http.post(
      Uri.parse(_listUrl),
      headers: headers,
      body: listBody,
    );

    debugPrint('Medicine List Response status: ${listResponse.statusCode}');
    debugPrint('Medicine List Response body: ${listResponse.body}');

    if (listResponse.statusCode != 200) {
      throw Exception('Failed to load medicines. Status code: ${listResponse.statusCode}');
    }

    final decoded = jsonDecode(listResponse.body);
    final List data = decoded is List ? decoded : decoded['data'] ?? [];

    final medicines = data
        .map((e) => (e['medicine_name'] ?? '') as String)
        .where((name) => name.isNotEmpty)
        .toList();

    // Cache fetched medicines
    await prefs.setStringList('cached_medicines', medicines);

    return medicines;
  }

  /// Read cached medicines from SharedPreferences
  static Future<List<String>> getCachedMedicines() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('cached_medicines') ?? <String>[];
  }

  /// Fetch details of a single medicine
  static Future<Map<String, dynamic>?> fetchMedicineDetails(String medicineName) async {
    final prefs = await SharedPreferences.getInstance();

    String getPrefAsString(String key) {
      final val = prefs.get(key);
      return val?.toString() ?? '';
    }

    final token = getPrefAsString('auth_token');
    final clinicId = getPrefAsString('clinicId');
    final branchId = getPrefAsString('branchId');
    final userId = getPrefAsString('userId');
    final zoneid = getPrefAsString('zoneid');

    final headers = {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Authorization': token.startsWith('SmartCare') ? token : 'SmartCare $token',
      'clinicid': clinicId,
      'zoneid': zoneid,
      'userid': userId,
      'branchId': branchId,
    };

    if (medicineName.isEmpty) {
      return null;
    }

    try {
      // Fetch medicine list to get ID
      final listBody = jsonEncode({
        "text": medicineName,
        "flag": false,
        "fromNewInventory": true,
      });

      final listResponse = await http.post(
        Uri.parse(_listUrl),
        headers: headers,
        body: listBody,
      );

      debugPrint('Medicine List Response status: ${listResponse.statusCode}');
      debugPrint('Medicine List Response body: ${listResponse.body}');

      if (listResponse.statusCode != 200) {
        throw Exception(
            'Failed to load medicines. Status code: ${listResponse.statusCode}');
      }

      final listData = jsonDecode(listResponse.body);
      
      // Handle both direct list and nested data structure
      final medicinesList = listData is List 
          ? listData 
          : (listData['data'] as List? ?? []);

      if (medicinesList.isEmpty) {
        throw Exception('No medicine found for "$medicineName"');
      }

      // ✅ FIX: Access the first item in the list, THEN get its properties
      final firstMedicine = medicinesList[0] as Map<String, dynamic>;
      final medicineId = firstMedicine['medicine_id'];
      final weight = firstMedicine['weight'] ?? "0";

      debugPrint('Selected Medicine ID: $medicineId');
      debugPrint('Selected Medicine Weight: $weight');

      // Create detail request body
      final detailBody = jsonEncode({
        "id": [medicineId],
        "weight": weight,
        "flag": false,
        "medicine_name": [medicineName],
        "fromNewInventory": true,
      });

      final detailsResponse = await http.post(
        Uri.parse(_detailsUrl),
        headers: headers,
        body: detailBody,
      );

      debugPrint('Medicine Details Response status: ${detailsResponse.statusCode}');
      debugPrint('Medicine Details Response body: ${detailsResponse.body}');

      if (detailsResponse.statusCode != 200) {
        throw Exception(
            'Failed to fetch medicine details. Status code: ${detailsResponse.statusCode}');
      }

      final detailsData = jsonDecode(detailsResponse.body);
      
      // Return the details data
      // Handle if response is a list or object
      if (detailsData is List && detailsData.isNotEmpty) {
        return detailsData[0] as Map<String, dynamic>;
      } else if (detailsData is Map<String, dynamic>) {
        return detailsData;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error in fetchMedicineDetails: $e');
      rethrow;
    }
  }
}