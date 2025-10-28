import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SavePrescriptionService {
  static const String _apiUrl =
      'https://test.smartcarehis.com:8443/smartcaremain/priscription/save';

  /// POST prescription data
  static Future<Map<String, dynamic>> savePrescription(
    Map<String, dynamic> body,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('auth_token') ?? '';
      final clinicId = prefs.getString('clinicId') ?? '';
      final branchId = prefs.getString('branchId') ?? '';
      final userId = prefs.getString('userId') ?? '';
      final admissionid = prefs.getString('admissionid') ?? '';
      
      // Try multiple possible keys for the IDs
      final patientId = prefs.getString('patientId') ?? 
                        prefs.getString('clientId') ?? 
                        prefs.getString('patientid') ?? '';
      
      final practitionerId = prefs.getString('practitionerId') ?? 
                             prefs.getString('practitionerid') ?? '';

      debugPrint('╔═══════════════════════════════════════════════════════╗');
      debugPrint('║     SAVE PRESCRIPTION SERVICE - IDs CHECK             ║');
      debugPrint('╠═══════════════════════════════════════════════════════╣');
      debugPrint('║ admissionid from prefs: $admissionid');
      debugPrint('║ patientId from prefs: $patientId');
      debugPrint('║ practitionerId from prefs: $practitionerId');
      debugPrint('╚═══════════════════════════════════════════════════════╝');

      if (token.isEmpty) {
        throw Exception('Authentication token missing');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Authorization': token.startsWith('SmartCare')
            ? token
            : 'SmartCare $token',
        'clinicid': clinicId,
        'zoneid': 'Asia/Kolkata',
        'userid': userId,
        if (branchId.isNotEmpty) 'branchId': branchId,
      };

      final Map<String, dynamic> finalBody = Map<String, dynamic>.from(body);

      debugPrint('BEFORE PROCESSING:');
      debugPrint('admission_id: ${finalBody['admission_id']}');
      debugPrint('patientid: ${finalBody['patientid']}');
      debugPrint('practitionerid: ${finalBody['practitionerid']}');
      debugPrint('clientId: ${finalBody['clientId']}');
      
      // Process admission_id
      if (finalBody['admission_id'] == null || 
          finalBody['admission_id'] == '' || 
          finalBody['admission_id'] == 0) {
        finalBody['admission_id'] = int.tryParse(admissionid) ?? 0;
      } else if (finalBody['admission_id'] is String) {
        finalBody['admission_id'] = int.tryParse(finalBody['admission_id']) ?? 0;
      }

      // Process patientid - PRIORITY: body > SharedPreferences
      int finalPatientId = 0;
      
      // First try to get from body
      if (finalBody['patientid'] != null && 
          finalBody['patientid'] != '' && 
          finalBody['patientid'] != 0) {
        if (finalBody['patientid'] is String) {
          finalPatientId = int.tryParse(finalBody['patientid']) ?? 0;
        } else if (finalBody['patientid'] is int) {
          finalPatientId = finalBody['patientid'];
        }
      }
      
      // If still 0, try clientId from body
      if (finalPatientId == 0 && finalBody['clientId'] != null && 
          finalBody['clientId'] != '' && finalBody['clientId'] != 0) {
        if (finalBody['clientId'] is String) {
          finalPatientId = int.tryParse(finalBody['clientId']) ?? 0;
        } else if (finalBody['clientId'] is int) {
          finalPatientId = finalBody['clientId'];
        }
      }
      
      // If still 0, use SharedPreferences
      if (finalPatientId == 0 && patientId.isNotEmpty) {
        finalPatientId = int.tryParse(patientId) ?? 0;
      }
      
      finalBody['patientid'] = finalPatientId;

      // Process practitionerid - PRIORITY: body > SharedPreferences
      int finalPractitionerId = 0;
      
      // First try to get from body
      if (finalBody['practitionerid'] != null && 
          finalBody['practitionerid'] != '' && 
          finalBody['practitionerid'] != 0) {
        if (finalBody['practitionerid'] is String) {
          finalPractitionerId = int.tryParse(finalBody['practitionerid']) ?? 0;
        } else if (finalBody['practitionerid'] is int) {
          finalPractitionerId = finalBody['practitionerid'];
        }
      }
      
      // If still 0, use SharedPreferences
      if (finalPractitionerId == 0 && practitionerId.isNotEmpty) {
        finalPractitionerId = int.tryParse(practitionerId) ?? 0;
      }
      
      finalBody['practitionerid'] = finalPractitionerId;

      // Ensure clientId matches patientid
      if (finalBody['clientId'] == null || 
          finalBody['clientId'] == '' || 
          finalBody['clientId'] == 0) {
        finalBody['clientId'] = finalPatientId;
      } else if (finalBody['clientId'] is String) {
        finalBody['clientId'] = int.tryParse(finalBody['clientId']) ?? finalPatientId;
      }

      // Update medicine list with correct IDs
      if (finalBody['priscriptionmedicinelist'] != null && 
          finalBody['priscriptionmedicinelist'] is List) {
        for (var medicine in finalBody['priscriptionmedicinelist']) {
          if (medicine is Map<String, dynamic>) {
            // Ensure each medicine has the correct patient and practitioner IDs
            if (medicine['patientid'] == null || 
                medicine['patientid'] == '' || 
                medicine['patientid'] == 0) {
              medicine['patientid'] = finalPatientId;
            }
            if (medicine['practitionerid'] == null || 
                medicine['practitionerid'] == '' || 
                medicine['practitionerid'] == 0) {
              medicine['practitionerid'] = finalPractitionerId;
            }
          }
        }
      }

      // Always ensure userid is set
      finalBody['userid'] = userId;

      debugPrint('╔═══════════════════════════════════════════════════════╗');
      debugPrint('║     FINAL BODY IDs AFTER PROCESSING                   ║');
      debugPrint('╠═══════════════════════════════════════════════════════╣');
      debugPrint('║ admission_id: ${finalBody['admission_id']}');
      debugPrint('║ patientid: ${finalBody['patientid']}');
      debugPrint('║ practitionerid: ${finalBody['practitionerid']}');
      debugPrint('║ clientId: ${finalBody['clientId']}');
      debugPrint('╚═══════════════════════════════════════════════════════╝');

      debugPrint('Headers: ${_sanitizeHeaders(headers)}');
      debugPrint('Body: ${jsonEncode(finalBody)}');

      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: headers,
            body: jsonEncode(finalBody),
          )
          .timeout(const Duration(seconds: 30));
      
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        await prefs.setString('last_saved_prescription', jsonEncode(finalBody));
        return decoded;
      } else {
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
      debugPrint('SavePrescriptionService Error: $e');
      rethrow;
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

  /// Get cached last saved prescription body
  static Future<Map<String, dynamic>?> getCachedPrescription() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('last_saved_prescription');
    if (cached == null || cached.isEmpty) return null;
    return jsonDecode(cached) as Map<String, dynamic>;
  }
}