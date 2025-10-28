// lib/services/add_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AddMedicineService {
  static const String _apiUrl =
      'https://test.smartcarehis.com:8443/smartcaremain/priscriptionmaster/medicinedetails/saveorupdate';

  /// POST medicine details to API
  static Future<Map<String, dynamic>> postMedicineDetails(
      Map<String, dynamic> body) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('auth_token') ?? '';
      final clinicId = prefs.getString('clinicId') ?? '';
      final branchId = prefs.getString('branchId') ?? '';
      final userId = prefs.getString('userId') ?? '';

      if (token.isEmpty) {
        throw Exception('Authentication token missing');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Authorization':
            token.startsWith('SmartCare') ? token : token,
        'clinicid': clinicId,
        'zoneid': 'Asia/Kolkata',
        'userid': userId,
        if (branchId.isNotEmpty) 'branchId': branchId,
      };

      // 🔹 Don't force defaults. Send exactly what caller provided.
      final Map<String, dynamic> finalBody = Map<String, dynamic>.from(body);

      // 🔹 Store remark in SharedPreferences if present
      if (finalBody['remark'] != null && finalBody['remark'].toString().isNotEmpty) {
        await _saveRemarkToPrefs(finalBody['remark'].toString());
      }

      debugPrint('=== API REQUEST DEBUG ===');
      debugPrint('URL: $_apiUrl');
      debugPrint('Headers: ${_sanitizeHeaders(headers)}');
      debugPrint('Body: ${jsonEncode(finalBody)}');

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: headers,
        body: jsonEncode(finalBody),
      ).timeout(const Duration(seconds: 30));

      debugPrint('=== API RESPONSE DEBUG ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        await prefs.setString('last_posted_medicine', jsonEncode(finalBody));
        return decoded;
      } else {
        // Try to extract server error message
        String errorMessage = 'Error ${response.statusCode}';
        try {
          final err = jsonDecode(response.body);
          if (err is Map && err['message'] != null) {
            errorMessage = err['message'].toString();
          } else if (err is Map && err['error'] != null) {
            errorMessage = err['error'].toString();
          }
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('AddMedicineService Error: $e');
      rethrow;
    }
  }

  /// Save remark to SharedPreferences array
  static Future<void> _saveRemarkToPrefs(String remark) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing remarks array
      List<String> remarks = await getRemarks();
      
      // Add new remark if it's not already present (avoid duplicates)
      if (!remarks.contains(remark)) {
        remarks.add(remark);
        
        // Save back to SharedPreferences
        await prefs.setStringList('medicine_remarks', remarks);
        debugPrint('Remark saved: $remark');
      }
    } catch (e) {
      debugPrint('Error saving remark: $e');
    }
  }

  /// Get all saved remarks from SharedPreferences
  static Future<List<String>> getRemarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('medicine_remarks') ?? [];
    } catch (e) {
      debugPrint('Error getting remarks: $e');
      return [];
    }
  }

  /// Clear all saved remarks
  static Future<void> clearRemarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('medicine_remarks');
      debugPrint('All remarks cleared');
    } catch (e) {
      debugPrint('Error clearing remarks: $e');
    }
  }

  /// Remove a specific remark
  static Future<void> removeRemark(String remark) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> remarks = await getRemarks();
      
      remarks.remove(remark);
      await prefs.setStringList('medicine_remarks', remarks);
      debugPrint('Remark removed: $remark');
    } catch (e) {
      debugPrint('Error removing remark: $e');
    }
  }

  /// Hide token in debug logs
  static Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    final sanitized = Map<String, String>.from(headers);
    if (sanitized['Authorization'] != null) {
      sanitized['Authorization'] = 'SmartCare ***';
    }
    return sanitized;
  }

  /// Get cached last posted medicine if needed
  static Future<Map<String, dynamic>?> getCachedMedicineBody() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('last_posted_medicine');
    if (cached == null || cached.isEmpty) return null;
    return jsonDecode(cached) as Map<String, dynamic>;
  }
}