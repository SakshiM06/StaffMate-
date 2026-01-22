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

      // Get authentication and user data
      final token = prefs.getString('auth_token') ?? '';
      final clinicId = prefs.getString('clinicId') ?? '';
      final branchId = prefs.getString('branchId') ?? '';
      final userId = prefs.getString('userId') ?? '';
      
      // Try multiple keys for patient ID
      final patientId = prefs.getString('patientId') ?? 
                        prefs.getString('clientId') ?? 
                        prefs.getString('patientid') ?? '';
      
      // Try multiple keys for practitioner ID
      final practitionerId = prefs.getString('practitionerId') ?? 
                             prefs.getString('practitionerid') ?? '';

      debugPrint('╔═══════════════════════════════════════════════════════╗');
      debugPrint('║     SAVE PRESCRIPTION SERVICE - IDs CHECK             ║');
      debugPrint('╠═══════════════════════════════════════════════════════╣');
      debugPrint('║ Token: ${token.isNotEmpty ? "Present" : "Missing"}');
      debugPrint('║ clinicId: $clinicId');
      debugPrint('║ branchId: $branchId');
      debugPrint('║ userId: $userId');
      debugPrint('║ patientId from prefs: $patientId');
      debugPrint('║ practitionerId from prefs: $practitionerId');
      debugPrint('╚═══════════════════════════════════════════════════════╝');

      if (token.isEmpty) {
        throw Exception('Authentication token missing');
      }

      // Prepare headers
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': token.startsWith('SmartCare')
            ? token
            : 'SmartCare $token',
        'clinicid': clinicId,
        'zoneid': 'Asia/Kolkata',
        'userid': userId,
        if (branchId.isNotEmpty) 'branchId': branchId,
      };

      // Create a copy of the body to avoid modifying the original
      Map<String, dynamic> finalBody = Map<String, dynamic>.from(body);

      debugPrint('╔═══════════════════════════════════════════════════════╗');
      debugPrint('║          ORIGINAL BODY FROM CALLER                    ║');
      debugPrint('╠═══════════════════════════════════════════════════════╣');
      debugPrint('║ admission_id: ${finalBody['admission_id']}');
      debugPrint('║ patientid: ${finalBody['patientid']}');
      debugPrint('║ practitionerid: ${finalBody['practitionerid']}');
      debugPrint('╚═══════════════════════════════════════════════════════╝');

      // CRITICAL FIX: Ensure all required fields are present
      // Based on your API response, these are the required fields
      
      // 1. Ensure patientid is integer
      if (finalBody['patientid'] != null) {
        if (finalBody['patientid'] is String) {
          finalBody['patientid'] = int.tryParse(finalBody['patientid']) ?? 0;
        }
      } else {
        // Get from SharedPreferences if not in body
        finalBody['patientid'] = int.tryParse(patientId) ?? 0;
      }

      // 2. Ensure practitionerid is integer
      if (finalBody['practitionerid'] != null) {
        if (finalBody['practitionerid'] is String) {
          finalBody['practitionerid'] = int.tryParse(finalBody['practitionerid']) ?? 0;
        }
      } else {
        // Get from SharedPreferences if not in body
        finalBody['practitionerid'] = int.tryParse(practitionerId) ?? 0;
      }

      // 3. Ensure admission_id is integer
      if (finalBody['admission_id'] != null) {
        if (finalBody['admission_id'] is String) {
          finalBody['admission_id'] = int.tryParse(finalBody['admission_id']) ?? 0;
        }
      }

      // 4. Ensure userid is set
      if (finalBody['userid'] == null || finalBody['userid'] == '') {
        finalBody['userid'] = userId;
      }

      // 5. Ensure datetime is set
      if (finalBody['datetime'] == null || finalBody['datetime'] == '') {
        final now = DateTime.now();
        finalBody['datetime'] = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      }

      // 6. Ensure lastmodified is set
      if (finalBody['lastmodified'] == null || finalBody['lastmodified'] == '') {
        final now = DateTime.now();
        finalBody['lastmodified'] = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      }

      // 7. CRITICAL FIX: Update medicine list with correct structure
      if (finalBody['priscriptionmedicinelist'] != null && 
          finalBody['priscriptionmedicinelist'] is List) {
        final List<dynamic> medicineList = finalBody['priscriptionmedicinelist'];
        
        // Fix each medicine item
        for (int i = 0; i < medicineList.length; i++) {
          if (medicineList[i] is Map<String, dynamic>) {
            Map<String, dynamic> medicine = Map<String, dynamic>.from(medicineList[i]);
            
            // Convert string IDs to integers
            if (medicine['patientid'] is String) {
              medicine['patientid'] = int.tryParse(medicine['patientid']) ?? finalBody['patientid'];
            }
            
            if (medicine['practitionerid'] is String) {
              medicine['practitionerid'] = int.tryParse(medicine['practitionerid']) ?? finalBody['practitionerid'];
            }
            
            // Ensure days is integer
            if (medicine['days'] is String) {
              medicine['days'] = int.tryParse(medicine['days']) ?? 1;
            }
            
            // Ensure dr_qty is double (based on your response)
            if (medicine['dr_qty'] is String) {
              medicine['dr_qty'] = double.tryParse(medicine['dr_qty']) ?? 1.0;
            }
            
            // Ensure nurse_qty is double
            if (medicine['nurse_qty'] is String) {
              medicine['nurse_qty'] = double.tryParse(medicine['nurse_qty']) ?? 1.0;
            }
            
            // Ensure datetime for medicine
            if (medicine['datetime'] == null || medicine['datetime'] == '') {
              medicine['datetime'] = finalBody['datetime'];
            }
            
            // Update the medicine in the list
            medicineList[i] = medicine;
          }
        }
        finalBody['priscriptionmedicinelist'] = medicineList;
      }

      // 8. Add missing fields from the API response
      final defaultValues = {
        'specializationid': 0,
        'dosenotes': '',
        'followupcount': 0,
        'followupstype': '',
        'remark': '',
        'english': 0,
        'regional': 0,
        'hindi': 0,
        'prepay': 0,
        'postpay': 0,
        'other': 0,
        'followupdate': '',
        'discharge': 0,
        'dstatus': 0,
        'department': 0,
        'billno': 0,
        'opd_appointmentid': 0,
        'prisc_status': 0,
        'pending_userid': '',
        'pending_datetime': '',
        'admission': '',
        'request_from': 0,
        'locationid': 0,
        'prisc_delete': 0,
        'prisc_print_taken': '0',
        'fromtreatmentgiven': 0,
        'patient_request': '0',
        'order_type': '0',
        'order_status': 0,
        'order_status_text': 'REQUESTED',
        'delivery_paymode': '0',
        'delivery_mode': '0',
        'hd_payment_status': 0,
        'paidorunpaid': 0,
        'surgeonId': '0',
        'tpId': 0,
        'wardId': 0,
        'bedId': 0,
        'icdCode': '0',
        'allergyId': '0',
      };

      // Add default values for any missing fields
      defaultValues.forEach((key, value) {
        if (!finalBody.containsKey(key)) {
          finalBody[key] = value;
        }
      });

      // 9. Ensure surgeonList is a list of strings (not ints)
      if (finalBody['surgeonList'] == null) {
        finalBody['surgeonList'] = ['0'];
      } else if (finalBody['surgeonList'] is List && finalBody['surgeonList'].isNotEmpty) {
        // Convert any integers to strings
        final List<dynamic> surgeonList = finalBody['surgeonList'];
        finalBody['surgeonList'] = surgeonList.map((e) => e.toString()).toList();
      }

      debugPrint('╔═══════════════════════════════════════════════════════╗');
      debugPrint('║          FINAL BODY FOR API CALL                      ║');
      debugPrint('╠═══════════════════════════════════════════════════════╣');
      debugPrint('║ admission_id: ${finalBody['admission_id']} (${finalBody['admission_id'].runtimeType})');
      debugPrint('║ patientid: ${finalBody['patientid']} (${finalBody['patientid'].runtimeType})');
      debugPrint('║ practitionerid: ${finalBody['practitionerid']} (${finalBody['practitionerid'].runtimeType})');
      debugPrint('║ userid: ${finalBody['userid']}');
      debugPrint('║ datetime: ${finalBody['datetime']}');
      debugPrint('║ lastmodified: ${finalBody['lastmodified']}');
      debugPrint('║ Medicine count: ${(finalBody['priscriptionmedicinelist'] as List?)?.length ?? 0}');
      debugPrint('╚═══════════════════════════════════════════════════════╝');

      // Log sanitized headers
      debugPrint('Headers: ${_sanitizeHeaders(headers)}');
      
      // Log body (truncated for readability)
      final logBody = Map<String, dynamic>.from(finalBody);
      if (logBody['priscriptionmedicinelist'] != null && logBody['priscriptionmedicinelist'] is List) {
        final medList = logBody['priscriptionmedicinelist'] as List;
        if (medList.isNotEmpty) {
          logBody['priscriptionmedicinelist'] = 'List with ${medList.length} items (first: ${medList.first['medicinename']})';
        }
      }
      debugPrint('Body Preview: ${jsonEncode(logBody).substring(0, 300)}...');

      // Make API call with longer timeout
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: headers,
            body: jsonEncode(finalBody),
          )
          .timeout(const Duration(seconds: 45));
      
      debugPrint('╔═══════════════════════════════════════════════════════╗');
      debugPrint('║               API RESPONSE                            ║');
      debugPrint('╠═══════════════════════════════════════════════════════╣');
      debugPrint('║ Status Code: ${response.statusCode}');
      debugPrint('║ Response: ${response.body.length > 500 ? response.body.substring(0, 500) + '...' : response.body}');
      debugPrint('╚═══════════════════════════════════════════════════════╝');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Validate response has required fields
        if (decoded.containsKey('id') && decoded['id'] != null) {
          // Cache the prescription
          await prefs.setString('last_saved_prescription', jsonEncode({
            'id': decoded['id'],
            'patientid': finalBody['patientid'],
            'practitionerid': finalBody['practitionerid'],
            'admission_id': finalBody['admission_id'],
            'datetime': finalBody['datetime'],
            'medicines_count': (finalBody['priscriptionmedicinelist'] as List?)?.length ?? 0,
          }));
          
          return decoded;
        } else {
          throw Exception('API response missing prescription ID');
        }
      } else {
        String errorMessage = 'Error ${response.statusCode}';
        try {
          final err = jsonDecode(response.body);
          if (err is Map && err['message'] != null) {
            errorMessage = err['message'].toString();
          } else if (err is Map && err['error'] != null) {
            errorMessage = err['error'].toString();
          } else if (err is String) {
            errorMessage = err;
          }
        } catch (_) {
          errorMessage = 'Failed to parse error response: ${response.body}';
        }
        
        // Log detailed error
        debugPrint('API Error Details:');
        debugPrint('Request Body: ${jsonEncode(finalBody)}');
        debugPrint('Response Headers: ${response.headers}');
        debugPrint('Full Error: $errorMessage');
        
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('╔═══════════════════════════════════════════════════════╗');
      debugPrint('║                 SAVE PRESCRIPTION ERROR               ║');
      debugPrint('╠═══════════════════════════════════════════════════════╣');
      debugPrint('║ Error: $e');
      debugPrint('║ StackTrace: ${StackTrace.current}');
      debugPrint('╚═══════════════════════════════════════════════════════╝');
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

  /// Get cached last saved prescription
  static Future<Map<String, dynamic>?> getCachedPrescription() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('last_saved_prescription');
    if (cached == null || cached.isEmpty) return null;
    return jsonDecode(cached) as Map<String, dynamic>;
  }

  /// Clear cached prescription
  static Future<void> clearCachedPrescription() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_saved_prescription');
  }
}