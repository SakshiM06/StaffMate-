import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RepeatPrescriptionService {
  static const String _baseUrl = 'https://test.smartcarehis.com:8443/smartcaremain/priscription/repeatpriscriptionList';

  /// Get repeat prescriptions list for a client
  static Future<List<Map<String, dynamic>>> getRepeatPrescriptions({
    required String clientId,
    required String practitionerId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Build headers similar to IpdService
      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }

      final token = getPrefAsString('auth_token');
      final clinicId = getPrefAsString('clinicId');
      final userId = getPrefAsString('userId');

      if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) {
        debugPrint('⚠️ Missing session values. Token: $token, ClinicId: $clinicId, UserId: $userId');
        return [];
      }

      // Headers based on IpdService pattern
      final headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        'origin': 'https://test.smartcarehis.com:8443',
        'referer': 'https://test.smartcarehis.com:8443/',
      };

      // Prepare request body - Based on your example payload
      final body = {
        'clientid': clientId,
        'practid': practitionerId,
      };

      debugPrint('=== REPEAT PRESCRIPTION API CALL ===');
      debugPrint('URL: $_baseUrl');
      debugPrint('Headers keys: ${headers.keys}');
      debugPrint('Body: ${jsonEncode(body)}');
      debugPrint('Client ID: $clientId');
      debugPrint('Practitioner ID: $practitionerId');
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: jsonEncode(body),
      );

      debugPrint('=== API RESPONSE ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Headers: ${response.headers}');
      
      if (response.statusCode == 200) {
        debugPrint('Response Body Length: ${response.body.length}');
        
        if (response.body.isEmpty) {
          debugPrint('API returned empty response body');
          return [];
        }
        
        try {
          final Map<String, dynamic> decodedJson = jsonDecode(response.body);
          debugPrint('Response JSON Type: ${decodedJson.runtimeType}');
          debugPrint('Response JSON Keys: ${decodedJson.keys}');
          
          // Check if the response has an error
          if (decodedJson.containsKey('error') || decodedJson.containsKey('Error')) {
            debugPrint('API returned error: $decodedJson');
            return [];
          }
          
          // Extract repeat prescriptions list
          // Expected format: {"repeatPriscriptionListByClientid": [...]}
          final List<dynamic> repeatList = decodedJson['repeatPriscriptionListByClientid'] ?? [];
          debugPrint('Found ${repeatList.length} prescriptions in response');
          
          // Debug first item if available
          if (repeatList.isNotEmpty) {
            debugPrint('First prescription item: ${repeatList.first}');
          }
          
          // Convert to list of maps
          final List<Map<String, dynamic>> prescriptions = [];
          for (var item in repeatList) {
            if (item is Map<String, dynamic>) {
              prescriptions.add({
                'id': item['id']?.toString() ?? '',
                'lastmodified': item['lastmodified']?.toString() ?? '',
                'datetime': item['datetime']?.toString(),
                'prescription_no': item['prescription_no']?.toString(),
                'prescriptiondate': item['prescriptiondate']?.toString(),
                'practitionername': item['practitionername']?.toString(),
                // Add all available fields for debugging
                ...item.map((key, value) => MapEntry(key, value?.toString())),
              });
            }
          }

          debugPrint('Successfully processed ${prescriptions.length} prescriptions');
          
          // Cache the prescriptions for offline use
          await cacheRepeatPrescriptions(prescriptions);
          
          return prescriptions;
        } catch (e) {
          debugPrint('❌ Error parsing JSON response: $e');
          debugPrint('Raw response (first 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) + '...' : response.body}');
          
          // Try to get cached data
          final cached = await getCachedRepeatPrescriptions();
          if (cached.isNotEmpty) {
            debugPrint('Using ${cached.length} cached prescriptions as fallback');
            return cached;
          }
          
          return [];
        }
      } else if (response.statusCode == 404) {
        debugPrint('❌ API endpoint not found (404)');
        return [];
      } else if (response.statusCode == 401) {
        debugPrint('❌ Unauthorized (401) - Token may be invalid or expired');
        return [];
      } else if (response.statusCode == 403) {
        debugPrint('❌ Forbidden (403) - No permission to access this resource');
        return [];
      } else if (response.statusCode == 500) {
        debugPrint('❌ Server error (500) - Internal server error');
        debugPrint('Error response: ${response.body}');
        return [];
      } else {
        debugPrint('❌ API Error Status: ${response.statusCode}');
        debugPrint('Error Response (first 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) + '...' : response.body}');
        
        // Try to get cached data if API fails
        final cached = await getCachedRepeatPrescriptions();
        if (cached.isNotEmpty) {
          debugPrint('Using ${cached.length} cached prescriptions as fallback');
          return cached;
        }
        
        return [];
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Exception in getRepeatPrescriptions: $e');
      debugPrint('Stack Trace: $stackTrace');
      
      // Try to get cached data
      final cached = await getCachedRepeatPrescriptions();
      if (cached.isNotEmpty) {
        debugPrint('Using ${cached.length} cached prescriptions after exception');
        return cached;
      }
      
      return [];
    }
  }

  /// Get cached IPD data for a specific client
  /// Based on your debug output, data is stored as "cached_ipd_40638"
  static Future<Map<String, dynamic>?> getCachedIpdData(String clientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_ipd_$clientId');
      
      if (cachedData != null && cachedData.isNotEmpty) {
        debugPrint('Found cached IPD data for client $clientId');
        return jsonDecode(cachedData);
      } else {
        // Try alternative key patterns
        final allKeys = prefs.getKeys();
        final ipdKeys = allKeys.where((key) => key.contains('cached_ipd')).toList();
        
        debugPrint('Available cached IPD keys: $ipdKeys');
        
        if (ipdKeys.isNotEmpty) {
          // Get the first cached IPD data (fallback)
          final firstKey = ipdKeys.first;
          final firstData = prefs.getString(firstKey);
          if (firstData != null) {
            debugPrint('Using cached data from key: $firstKey');
            return jsonDecode(firstData);
          }
        }
        
        debugPrint('No cached IPD data found for client $clientId');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting cached IPD data: $e');
      return null;
    }
  }

  /// Get cached repeat prescriptions
  static Future<List<Map<String, dynamic>>> getCachedRepeatPrescriptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_repeat_prescriptions');
      
      if (cachedData != null && cachedData.isNotEmpty) {
        final List<dynamic> parsed = jsonDecode(cachedData);
        debugPrint('Retrieved ${parsed.length} prescriptions from cache');
        return parsed.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      debugPrint('Error parsing cached prescriptions: $e');
    }
    
    debugPrint('No cached prescriptions found');
    return [];
  }

  /// Cache repeat prescriptions for offline use
  static Future<void> cacheRepeatPrescriptions(List<Map<String, dynamic>> prescriptions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(prescriptions);
      await prefs.setString('cached_repeat_prescriptions', jsonString);
      debugPrint('Cached ${prescriptions.length} prescriptions');
    } catch (e) {
      debugPrint('Error caching prescriptions: $e');
    }
  }
  
  /// Clear cached prescriptions
  static Future<void> clearCachedPrescriptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_repeat_prescriptions');
      debugPrint('Cleared cached prescriptions');
    } catch (e) {
      debugPrint('Error clearing cached prescriptions: $e');
    }
  }

  /// Extract clientId and practitionerId from cached IPD data
  static Future<Map<String, String>> extractIdsFromCachedData(String clientId) async {
    try {
      final cachedData = await getCachedIpdData(clientId);
      
      if (cachedData != null) {
        final extractedClientId = cachedData['clientId']?.toString() ?? clientId;
        final practitionerId = cachedData['practitionerId']?.toString() ?? '';
        
        debugPrint('Extracted from cached data:');
        debugPrint('  Client ID: $extractedClientId');
        debugPrint('  Practitioner ID: $practitionerId');
        
        return {
          'clientId': extractedClientId,
          'practitionerId': practitionerId,
        };
      }
    } catch (e) {
      debugPrint('Error extracting IDs from cached data: $e');
    }
    
    return {
      'clientId': clientId,
      'practitionerId': '',
    };
  }
}