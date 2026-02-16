import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:staff_mate/models/dashboard_data.dart';
import 'package:staff_mate/models/patient.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_mate/services/investigation_service.dart';

class IpdService {
  static const String _baseUrl =
      "https://test.smartcarehis.com:8443/ipd/patient/all";
  static const String _practitionerUrl =
      "https://test.smartcarehis.com:8443/smartcaremain/practitionerlist";
  static const String _specializationUrl =
      "https://test.smartcarehis.com:8443/smartcaremain/clinic/specializationlist";
  static const String _wardListUrl =
      "https://test.smartcarehis.com:8443/smartcaremain/clinic/branchwisewardlist/";
  static const String _availableBedsUrl =
       "https://test.smartcarehis.com:8443/smartcaremain/clinic/availablebedinward/";
  static const String _vitalsMasterUrl =
      "https://test.smartcarehis.com:8443/ipd/common/get/vitals";
  static const String _saveVitalsUrl =
      "https://test.smartcarehis.com:8443/ipd/common/save/timewise/vitals";
  static const String _prescriptionNotificationUrl =
      "https://test.smartcarehis.com:8443/ipd/patient/getNotification/priscription/";
  static const String _investigationNotificationUrl =
      "https://test.smartcarehis.com:8443/ipd/patient/getNotification/investigation/";
  static const String _dayToDayNotesUrl =
      "https://test.smartcarehis.com:8443/ipd/patient/daytodaynotes/fetch";
  static const String _saveDayToDayNotesUrl =
      "https://test.smartcarehis.com:8443/ipd/patient/daytodaynotes/save";
  static const String _uploadDocumentUrl =
      "https://test.smartcarehis.com:8443/smartcaremain/patient/uploadDocuments";
  static const String _shiftBedUrl =
      "https://test.smartcarehis.com:8443/ipd/common/shiftbed";
  static const String _addStdChargesUrl =
      "https://test.smartcarehis.com:8443/ipd/patient/addstdcharges"; 

  Future<Map<String, dynamic>> fetchPrescriptionNotifications(String admissionId) async {
    debugPrint('Fetching prescription notifications for admission ID: $admissionId');

    try {
      final prefs = await SharedPreferences.getInstance();

      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }

      final token = getPrefAsString('auth_token');
      final clinicId = getPrefAsString('clinicId');
      final userId = getPrefAsString('userId');
      final branchId = getPrefAsString('branchId') ?? '1';

      if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) {
        throw Exception('⚠️ Missing session values. Please login again.');
      }

      final fullUrl = '$_prescriptionNotificationUrl$admissionId';
      debugPrint('Prescription Notification URL: $fullUrl');

      final headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        'branchId': branchId,
        'Access-Control-Allow-Origin': '*',
      };

      debugPrint('Prescription Notification Headers: $headers');

      final response = await http.get(
        Uri.parse(fullUrl),
        headers: headers,
      );

      debugPrint('Prescription API Status Code: ${response.statusCode}');
      debugPrint('Prescription API Response: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          return {
            'success': true,
            'statusCode': decoded['status_code'] ?? 200,
            'message': decoded['message'] ?? 'Success',
            'timestamp': decoded['timestamp'] ?? '',
            'data': decoded['data'] ?? [],
            'error': decoded['error'],
          };
        } else {
          throw Exception('Unexpected API response format. Expected a map but got: ${decoded.runtimeType}');
        }
      } else {
        throw Exception(
          'Failed to load prescription notifications (Status ${response.statusCode}). Body: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching prescription notifications: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchInvestigationNotifications(String admissionId) async {
    debugPrint('Fetching investigation notifications for admission ID: $admissionId');

    try {
      final prefs = await SharedPreferences.getInstance();

      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }

      final token = getPrefAsString('auth_token');
      final clinicId = getPrefAsString('clinicId');
      final userId = getPrefAsString('userId');
      final branchId = getPrefAsString('branchId') ?? '1';

      if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) {
        throw Exception('⚠️ Missing session values. Please login again.');
      }

      final fullUrl = '$_investigationNotificationUrl$admissionId';
      debugPrint('Investigation Notification URL: $fullUrl');

      final headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        'branchId': branchId,
        'Access-Control-Allow-Origin': '*',
      };

      debugPrint('Investigation Notification Headers: $headers');

      final response = await http.get(
        Uri.parse(fullUrl),
        headers: headers,
      );

      debugPrint('Investigation API Status Code: ${response.statusCode}');
      debugPrint('Investigation API Response: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          return {
            'success': true,
            'statusCode': decoded['status_code'] ?? 200,
            'message': decoded['message'] ?? 'Success',
            'timestamp': decoded['timestamp'] ?? '',
            'data': decoded['data'] ?? [],
            'error': decoded['error'],
          };
        } else {
          throw Exception('Unexpected API response format. Expected a map but got: ${decoded.runtimeType}');
        }
      } else {
        throw Exception(
          'Failed to load investigation notifications (Status ${response.statusCode}). Body: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching investigation notifications: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<IpdDashboardData> fetchDashboardData({required String wardId}) async {
    debugPrint('Fetching IPD dashboard data...');
    try {
      final prefs = await SharedPreferences.getInstance();

      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }

      final token = getPrefAsString('auth_token');
      final clinicId = getPrefAsString('clinicId');
      final userId = getPrefAsString('userId');

      if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) {
        throw Exception('⚠️ Missing session values. Please login again.');
      }

      final headers = {
        'Content-Type': 'application/json',
        "Access-Control-Allow-Origin": "*",
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': "Asia/Kolkata",
        'branchId': '1',
      };

      debugPrint('Headerss $headers');
      debugPrint('Patient All: $_baseUrl');
      debugPrint('Dataa $headers');

      final body = {
        "branchid": 1,
        "filterWardId": "0",
        "searchText": "",
        "patientFrom": 0,
        "showTpPatient": false,
      };
      debugPrint('--IPDDASHBOARD-- $body , $headers ');

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: headers.map((k, v) => MapEntry(k, v.toString())),
        body: jsonEncode(body),
      );

      debugPrint('IPD API Status Code: ${response.statusCode}');
      debugPrint('IPD API Body: ${response.body}');
      debugPrint('Response: $response');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is List) {
          final patientList = decoded
              .map((json) => Patient.fromJson(json as Map<String, dynamic>))
              .toList();

          if (patientList.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('admissionid', patientList.first.admissionId);
            debugPrint("Admission ID saved: ${patientList.first.admissionId}");
          }

          return IpdDashboardData(
            patients: patientList,
          );
        } else {
          throw Exception(
            'Unexpected API format. Expected a list of patients but got: ${decoded.runtimeType}',
          );
        }
      } else {
        throw Exception(
          'Failed to load IPD data (Status ${response.statusCode}). Body: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching dashboard data: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// [branchId] - Branch ID (default: "1")
  /// [specializationId] - Specialization filter (default: 0 for all)
  /// [isVisitingConsultant] - Filter for visiting consultants (1 = yes, 0 = no)
  Future<List<dynamic>> fetchPractitionerList({
    String branchId = "1",
    int specializationId = 0,
    int isVisitingConsultant = 1,
  }) async {
    debugPrint('Fetching practitioner list...');
    try {
      final prefs = await SharedPreferences.getInstance();

      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }

      final token = getPrefAsString('auth_token');
      final clinicId = getPrefAsString('clinicId');
      final userId = getPrefAsString('userId');

      if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) {
        throw Exception('⚠️ Missing session values. Please login again.');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        'branchId': branchId,
      };

      final body = {
        "branchid": branchId,
        "specializationid": specializationId,
        "isVisitingConsultant": isVisitingConsultant,
      };

      debugPrint('--PRACTITIONER API-- Body: $body, Headers: $headers');

      final response = await http.post(
        Uri.parse(_practitionerUrl),
        headers: headers.map((k, v) => MapEntry(k, v.toString())),
        body: jsonEncode(body),
      );

      debugPrint('Practitioner API Status Code: ${response.statusCode}');
      debugPrint('Practitioner API Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('practitionerList')) {
            final practitionerList = decoded['practitionerList'];

            if (practitionerList is List) {
              debugPrint('Successfully fetched ${practitionerList.length} practitioners');
              return practitionerList;
            } else {
              throw Exception(
                'practitionerList is not a list. Got: ${practitionerList.runtimeType}',
              );
            }
          } else {
            throw Exception(
              'API response missing "practitionerList" key. Response keys: ${decoded.keys}',
            );
          }
        } else if (decoded is List) {
          debugPrint('Successfully fetched ${decoded.length} practitioners (direct list format)');
          return decoded;
        } else {
          throw Exception(
            'Unexpected API format. Expected a map with "practitionerList" key or a list but got: ${decoded.runtimeType}',
          );
        }
      } else {
        throw Exception(
          'Failed to load practitioner data (Status ${response.statusCode}). Body: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching practitioner list: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// [branchId] - Branch ID (default: "1")
  Future<List<dynamic>> fetchSpecializationList({
    String branchId = "1",
  }) async {
    debugPrint('Fetching specialization list...');
    try {
      final prefs = await SharedPreferences.getInstance();

      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }

      final token = getPrefAsString('auth_token');
      final clinicId = getPrefAsString('clinicId');
      final userId = getPrefAsString('userId');

      if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) {
        throw Exception('⚠️ Missing session values. Please login again.');
      }

      final headers = {
        'Accept': '*/*',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        'branchId': branchId,
      };

      debugPrint('--SPECIALIZATION API-- Headers: $headers');

      final response = await http.get(
        Uri.parse(_specializationUrl),
        headers: headers,
      );

      debugPrint('Specialization API Status Code: ${response.statusCode}');
      debugPrint('Specialization API Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('Specialization API Response Type: ${decoded.runtimeType}');
        debugPrint('Specialization API Response: $decoded');

        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('specializationList')) {
            final specializationList = decoded['specializationList'];

            if (specializationList is List) {
              debugPrint('Successfully fetched ${specializationList.length} specializations');
              return specializationList;
            } else {
              throw Exception(
                'specializationList is not a list. Got: ${specializationList.runtimeType}',
              );
            }
          } else {
            throw Exception(
              'API response missing "specializationList" key. Response keys: ${decoded.keys}',
            );
          }
        } else if (decoded is List) {
          debugPrint('Successfully fetched ${decoded.length} specializations (direct list format)');
          return decoded;
        } else {
          throw Exception(
            'Unexpected API format. Expected a map with "specializationList" key or a list but got: ${decoded.runtimeType}',
          );
        }
      } else {
        throw Exception(
          'Failed to load specialization data (Status ${response.statusCode}). Body: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching specialization list: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// [branchId]
  Future<List<dynamic>> fetchBranchWardList({
    String branchId = "1",
  }) async {
    debugPrint('Fetching branch-wise ward list for branch: $branchId');
    try {
      final prefs = await SharedPreferences.getInstance();

      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }

      final token = getPrefAsString('auth_token');
      final clinicId = getPrefAsString('clinicId');
      final userId = getPrefAsString('userId');

      if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) {
        throw Exception('⚠️ Missing session values. Please login again.');
      }

      final url = '$_wardListUrl$branchId';
      debugPrint('Ward list URL: $url');

      final headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        'branchId': branchId,
        'Access-Control-Allow-Origin': '*',
      };

      debugPrint('--WARD LIST API-- Headers: $headers');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      debugPrint('Ward List API Status Code: ${response.statusCode}');
      debugPrint('Ward List API Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('Ward List API Response Type: ${decoded.runtimeType}');
        debugPrint('Ward List API Response: $decoded');

        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('wardList')) {
            final wardList = decoded['wardList'];
            if (wardList is List) {
              debugPrint('Successfully fetched ${wardList.length} wards (from wardList key)');
              return wardList;
            }
          } else if (decoded.containsKey('wards')) {
            final wardList = decoded['wards'];
            if (wardList is List) {
              debugPrint('Successfully fetched ${wardList.length} wards (from wards key)');
              return wardList;
            }
          } else if (decoded.containsKey('data')) {
            final data = decoded['data'];
            if (data is List) {
              debugPrint('Successfully fetched ${data.length} wards (from data key)');
              return data;
            }
          } else {
            for (final entry in decoded.entries) {
              if (entry.value is List) {
                debugPrint('Successfully fetched ${(entry.value as List).length} wards (from ${entry.key} key)');
                return entry.value as List;
              }
            }

            throw Exception(
              'API response does not contain a list of wards. Response keys: ${decoded.keys}',
            );
          }
        } else if (decoded is List) {
          debugPrint('Successfully fetched ${decoded.length} wards (direct list format)');
          return decoded;
        } else {
          throw Exception(
            'Unexpected API format. Expected a map with ward list or a list but got: ${decoded.runtimeType}',
          );
        }
      } else {
        throw Exception(
          'Failed to load ward list data (Status ${response.statusCode}). Body: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching ward list: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }

    return [];
  }

  /// Fetch available beds in a specific ward
  /// [wardId] - Ward ID (required)
  Future<List<dynamic>> fetchAvailableBedsInWard({
    required String wardId,
  }) async {
    debugPrint('Fetching available beds for ward: $wardId');
    try {
      final prefs = await SharedPreferences.getInstance();

      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }

      final token = getPrefAsString('auth_token');
      final clinicId = getPrefAsString('clinicId');
      final userId = getPrefAsString('userId');
      final branchId = getPrefAsString('branchId') ?? '1';

      if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) {
        throw Exception('⚠️ Missing session values. Please login again.');
      }

      final url = '$_availableBedsUrl$wardId';
      debugPrint('Available beds URL: $url');

      final headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        'branchId': branchId,
        'Access-Control-Allow-Origin': '*',
      };

      debugPrint('--AVAILABLE BEDS API-- Headers: $headers');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      debugPrint('Available Beds API Status Code: ${response.statusCode}');
      debugPrint('Available Beds API Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('Available Beds API Response Type: ${decoded.runtimeType}');
        debugPrint('Available Beds API Response: $decoded');

        // Handle response format: {"bedlist": [{bedid: 1, bedname: "01"}, ...]}
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('bedlist')) {
            final bedList = decoded['bedlist'];
            if (bedList is List) {
              debugPrint('Successfully fetched ${bedList.length} beds (from bedlist key)');
              return bedList;
            }
          } else if (decoded.containsKey('beds')) {
            final bedList = decoded['beds'];
            if (bedList is List) {
              debugPrint('Successfully fetched ${bedList.length} beds (from beds key)');
              return bedList;
            }
          } else if (decoded.containsKey('data')) {
            final data = decoded['data'];
            if (data is List) {
              debugPrint('Successfully fetched ${data.length} beds (from data key)');
              return data;
            }
          } else {
            // Check if any value in the map is a list
            for (final entry in decoded.entries) {
              if (entry.value is List) {
                debugPrint('Successfully fetched ${(entry.value as List).length} beds (from ${entry.key} key)');
                return entry.value as List;
              }
            }

            debugPrint('No list found in response, returning empty list');
            return [];
          }
        } else if (decoded is List) {
          debugPrint('Successfully fetched ${decoded.length} beds (direct list format)');
          return decoded;
        } else {
          debugPrint('Unexpected response format: ${decoded.runtimeType}');
          return [];
        }
      } else {
        throw Exception(
          'Failed to load available beds data (Status ${response.statusCode}). Body: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching available beds: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }

    return [];
  }

  /// Shift patient bed
  /// Shifts a patient to a different bed/ward
  Future<Map<String, dynamic>> shiftPatientBed({
    required String patientId,
    required String admissionId,
    required String wardId,
    required String wardName,
    required String bedId,
    required String bedName,
    required String shiftingTime,
    required String branchId,
    required String patientName,
    bool smsOnBedChange = false,
    bool whatsappOnBedChange = false,
  }) async {
    debugPrint('Shifting patient bed...');
    debugPrint('Patient ID: $patientId, Admission ID: $admissionId');
    debugPrint('From: Current Bed, To: Ward: $wardName ($wardId), Bed: $bedName ($bedId)');

    try {
      final prefs = await SharedPreferences.getInstance();

      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }

      final token = getPrefAsString('auth_token');
      final clinicId = getPrefAsString('clinicId');
      final userId = getPrefAsString('userId');
      final defaultBranchId = getPrefAsString('branchId') ?? '1';

      if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) {
        return {
          'success': false,
          'message': 'Missing session values. Please login again.',
        };
      }

      final headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        'branchId': branchId.isNotEmpty ? branchId : defaultBranchId,
        'Access-Control-Allow-Origin': '*',
      };

      debugPrint('Shift Bed Headers: $headers');

      // Parse integers where needed
      int admissionIdInt;
      try {
        admissionIdInt = int.parse(admissionId);
      } catch (e) {
        admissionIdInt = 0;
        debugPrint('⚠️ Error parsing admissionId: $e, using 0');
      }

      int wardIdInt;
      try {
        wardIdInt = int.parse(wardId);
      } catch (e) {
        wardIdInt = 0;
        debugPrint('⚠️ Error parsing wardId: $e, using 0');
      }

      int bedIdInt;
      try {
        bedIdInt = int.parse(bedId);
      } catch (e) {
        bedIdInt = 0;
        debugPrint('⚠️ Error parsing bedId: $e, using 0');
      }

      final requestBody = {
        "patientid": patientId,
        "addmissionid": admissionIdInt,
        "wardid": wardIdInt,
        "wardname": wardName,
        "bedid": bedIdInt,
        "bedname": bedName,
        "branch_id": branchId.isNotEmpty ? branchId : defaultBranchId,
        "patientname": patientName,
        "shiftingTime": shiftingTime,
        "sms_on_bedchange": smsOnBedChange,
        "whatsapp_on_bedchange": whatsappOnBedChange,
        "userid": userId,
      };

      debugPrint('Shift Bed Request Body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse(_shiftBedUrl),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      debugPrint('Shift Bed API Status Code: ${response.statusCode}');
      debugPrint('Shift Bed API Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          debugPrint('Patient bed shifted successfully');
          
          return {
            'success': true,
            'data': decoded['data'] ?? decoded,
            'message': decoded['message'] ?? 'Patient shifted successfully',
            'response': decoded,
          };
        } else {
          return {
            'success': true,
            'message': 'Patient shifted successfully',
            'data': decoded,
          };
        }
      } else {
        String errorMessage = 'Failed with status ${response.statusCode}';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody is Map<String, dynamic>) {
            errorMessage = errorBody['message'] ?? 
                          errorBody['error'] ?? 
                          errorMessage;
          }
        } catch (e) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }

        debugPrint('Shift Bed API Error: $errorMessage');

        return {
          'success': false,
          'message': 'Failed to shift patient: $errorMessage',
          'statusCode': response.statusCode,
          'error': response.body,
        };
      }
    } catch (e, stackTrace) {
      debugPrint('Exception shifting patient bed: $e');
      debugPrint('StackTrace: $stackTrace');
      return {
        'success': false,
        'message': 'Exception: $e',
      };
    }
  }

  /// Add Standard Charges
  /// Adds standard charges for a patient in a new ward
  Future<Map<String, dynamic>> addStandardCharges({
    required String patientId,
    required String admissionId,
    required String wardId,
    required String branchId,
    required String patientName,
    required String practitionerId,
    required String practitionerName,
    int thirdpartyId = 0,
    bool appliedNewStandardCharges = false,
    String whopay = "Client",
  }) async {
    debugPrint('Adding standard charges...');
    debugPrint('Patient ID: $patientId, Admission ID: $admissionId, Ward ID: $wardId');

    try {
      final prefs = await SharedPreferences.getInstance();

      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }

      final token = getPrefAsString('auth_token');
      final clinicId = getPrefAsString('clinicId');
      final userId = getPrefAsString('userId');
      final defaultBranchId = getPrefAsString('branchId') ?? '1';

      if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) {
        return {
          'success': false,
          'message': 'Missing session values. Please login again.',
        };
      }

      final headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        'branchId': branchId.isNotEmpty ? branchId : defaultBranchId,
        'Access-Control-Allow-Origin': '*',
      };

      debugPrint('Add Standard Charges Headers: $headers');

      // Parse integers where needed
      int admissionIdInt;
      try {
        admissionIdInt = int.parse(admissionId);
      } catch (e) {
        admissionIdInt = 0;
        debugPrint('⚠️ Error parsing admissionId: $e, using 0');
      }

      int wardIdInt;
      try {
        wardIdInt = int.parse(wardId);
      } catch (e) {
        wardIdInt = 0;
        debugPrint('⚠️ Error parsing wardId: $e, using 0');
      }

      final requestBody = {
        "admission_id": admissionIdInt,
        "appliedNewStandardCharges": appliedNewStandardCharges,
        "branch_id": branchId.isNotEmpty ? branchId : defaultBranchId,
        "patientid": patientId,
        "patientname": patientName,
        "practitionerid": practitionerId,
        "practitionername": practitionerName,
        "thirdparty_id": thirdpartyId,
        "wardid": wardIdInt,
        "whopay": whopay,
      };

      debugPrint('Add Standard Charges Request Body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse(_addStdChargesUrl),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      debugPrint('Add Standard Charges API Status Code: ${response.statusCode}');
      debugPrint('Add Standard Charges API Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          debugPrint('Standard charges added successfully');
          
          return {
            'success': true,
            'data': decoded['data'] ?? decoded,
            'message': decoded['message'] ?? 'Standard charges added successfully',
            'response': decoded,
          };
        } else {
          return {
            'success': true,
            'message': 'Standard charges added successfully',
            'data': decoded,
          };
        }
      } else {
        String errorMessage = 'Failed with status ${response.statusCode}';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody is Map<String, dynamic>) {
            errorMessage = errorBody['message'] ?? 
                          errorBody['error'] ?? 
                          errorMessage;
          }
        } catch (e) {
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }

        debugPrint('Add Standard Charges API Error: $errorMessage');

        return {
          'success': false,
          'message': 'Failed to add standard charges: $errorMessage',
          'statusCode': response.statusCode,
          'error': response.body,
        };
      }
    } catch (e, stackTrace) {
      debugPrint('Exception adding standard charges: $e');
      debugPrint('StackTrace: $stackTrace');
      return {
        'success': false,
        'message': 'Exception: $e',
      };
    }
  }

  Future<Map<String, dynamic>> fetchVitalsMasterData() async {
    debugPrint('Fetching vitals master data...');
    try {
      final prefs = await SharedPreferences.getInstance();

      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }

      final token = getPrefAsString('auth_token');
      final clinicId = getPrefAsString('clinicId');
      final userId = getPrefAsString('userId');

      if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) {
        throw Exception('⚠️ Missing session values. Please login again.');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        'branchId': '1',
        'Access-Control-Allow-Origin': '*',
      };

      debugPrint('--VITALS MASTER API-- Headers: $headers');

      final response = await http.get(
        Uri.parse(_vitalsMasterUrl),
        headers: headers,
      );

      debugPrint('Vitals Master API Status Code: ${response.statusCode}');
      debugPrint('Vitals Master API Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('data') && decoded['data'] is List) {
            debugPrint('Successfully fetched vitals master data');
            return {
              'success': true,
              'data': decoded['data'],
              'message': 'Vitals master data fetched successfully',
            };
          } else {
            throw Exception('API response missing "data" key or data is not a list');
          }
        } else {
          throw Exception('Unexpected API format. Expected a map but got: ${decoded.runtimeType}');
        }
      } else {
        return {
          'success': false,
          'message': 'Failed to load vitals master data (Status ${response.statusCode})',
          'error': response.body,
        };
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching vitals master data: $e');
      debugPrint('StackTrace: $stackTrace');
      return {
        'success': false,
        'message': 'Error fetching vitals master data: $e',
      };
    }
  }

  Future<Map<String, dynamic>> savePatientVitals({
    required String patientId,
    required String admissionId,
    required String date,
    required String time,
    required List<Map<String, dynamic>> vitalEntries,
  }) async {
    debugPrint('Saving patient vitals...');
    debugPrint('Patient ID: $patientId, Admission ID: $admissionId');
    debugPrint('Date: $date, Time: $time');
    debugPrint('Number of vital entries: ${vitalEntries.length}');

    try {
      final prefs = await SharedPreferences.getInstance();

      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }

      final token = getPrefAsString('auth_token');
      final clinicId = getPrefAsString('clinicId');
      final userId = getPrefAsString('userId');
      final branchId = getPrefAsString('branchId') ?? '1';

      if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) {
        return {
          'success': false,
          'message': 'Missing session values',
        };
      }

      final headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        'branchId': '1',
        'Access-Control-Allow-Origin': '*',
      };

      debugPrint('Headers: $headers');

      final List<Map<String, dynamic>> requestBody = [];

      for (var entry in vitalEntries) {
        final vitalMasterId = entry['vitalMasterId'];
        final finding = entry['finding']?.toString() ?? '';

        if (finding.isEmpty) continue;

        final vitalEntry = {
          'patientId': patientId,
          'addmissionId': admissionId,
          'date': date,
          'time': time,
          'finding': finding,
          'vitalMasterId': vitalMasterId,
          'userId': userId,
          'branchId': int.tryParse(branchId) ?? 1,
          'clinicId': clinicId,
        };

        requestBody.add(vitalEntry);
      }

      if (requestBody.isEmpty) {
        return {
          'success': false,
          'message': 'No valid vitals to save',
        };
      }

      debugPrint('Request Body (first item): ${requestBody.first}');
      debugPrint('Total items: ${requestBody.length}');
      debugPrint('Full request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse(_saveVitalsUrl),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      debugPrint('API Response Status: ${response.statusCode}');
      debugPrint('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body);
          debugPrint('Decoded Response: $decoded');

          return {
            'success': true,
            'data': decoded,
            'message': 'Vitals saved successfully',
          };
        } catch (e) {
          return {
            'success': true,
            'message': 'Vitals saved successfully',
            'rawResponse': response.body,
          };
        }
      } else {
        String errorMessage = 'Failed with status ${response.statusCode}';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody is Map<String, dynamic>) {
            errorMessage = errorBody['message'] ??
                errorBody['error'] ??
                'Unknown error';
          }
        } catch (e) {
          errorMessage = response.body;
        }

        debugPrint('Error Details: $errorMessage');

        return {
          'success': false,
          'message': 'Failed to save vitals: $errorMessage',
          'statusCode': response.statusCode,
          'error': response.body,
        };
      }
    } catch (e, stackTrace) {
      debugPrint('Exception saving vitals: $e');
      debugPrint('Stack Trace: $stackTrace');
      return {
        'success': false,
        'message': 'Exception: $e',
      };
    }
  }

  Future<Map<String, dynamic>?> fetchPatientInformation(String patientId) async {
    debugPrint('Fetching patient information for ID: $patientId via InvestigationService');

    try {
      final response = await InvestigationService.fetchPatientInformation(
        patientId: patientId,
      );

      if (response != null) {
        return {
          'success': true,
          'data': response,
          'message': 'Patient information fetched successfully',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch patient information',
          'error': 'No data returned from API',
        };
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching patient information: $e');
      debugPrint('StackTrace: $stackTrace');
      return {
        'success': false,
        'message': 'Error fetching patient information: $e',
      };
    }
  }

  Future<Map<String, dynamic>?> fetchPatientIpdDetails(String patientId) async {
    debugPrint('Fetching patient IPD details for ID: $patientId via InvestigationService');

    try {
      final response = await InvestigationService.fetchPatientIpdDetails(
        patientId: patientId,
      );

      if (response != null) {
        return {
          'success': true,
          'data': response,
          'message': 'Patient IPD details fetched successfully',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch patient IPD details',
          'error': 'No data returned from API',
        };
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching patient IPD details: $e');
      debugPrint('StackTrace: $stackTrace');
      return {
        'success': false,
        'message': 'Error fetching patient IPD details: $e',
      };
    }
  }

  Future<Map<String, String>> getSavedPatientParams() async {
    return await InvestigationService.getSavedPatientParams();
  }

  Future<Map<String, String>> getSavedIpdParams() async {
    return await InvestigationService.getSavedIpdParams();
  }

  Future<Map<String, dynamic>> uploadPatientDocument({
    required String patientId,
    required String description,
    required String documentType,
    required String fileDataUrl,
    required String fileName,
    required String fileType,
    required String ipdOrOpd,
    required String uploadby,
    String practitionerId = "0",
    String conditionId = "0",
  }) async {
    debugPrint('Uploading document for patient: $patientId');
    debugPrint('Document Type: $documentType');
    debugPrint('File Name: $fileName');
    debugPrint('IPD/OPD: $ipdOrOpd');

    try {
      final prefs = await SharedPreferences.getInstance();

      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }

      final token = getPrefAsString('auth_token');
      final clinicId = getPrefAsString('clinicId');
      final userId = getPrefAsString('userId');
      final branchId = getPrefAsString('branchId') ?? '1';

      if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) {
        throw Exception('⚠️ Missing session values. Please login again.');
      }

      String uploadByUser = uploadby;
      if (uploadByUser.isEmpty) {
        uploadByUser = getPrefAsString('userFullName') ?? 
                      getPrefAsString('username') ?? 
                      'Staff User';
      }

      final headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        'branchId': branchId,
        'Access-Control-Allow-Origin': '*',
      };

      debugPrint('Upload Document Headers: $headers');

      // Parse ipdOrOpd to integer
      int ipdOrOpdInt;
      try {
        ipdOrOpdInt = int.parse(ipdOrOpd);
      } catch (e) {
        ipdOrOpdInt = 0;
        debugPrint('⚠️ Error parsing ipdOrOpd: $e, using 0');
      }

      // Parse practitionerId to integer (API expects number)
      int practitionerIdInt;
      try {
        practitionerIdInt = int.parse(practitionerId);
      } catch (e) {
        practitionerIdInt = 0;
        debugPrint('⚠️ Error parsing practitionerId: $e, using 0');
      }

      // Parse conditionId to integer (API expects number)
      int conditionIdInt;
      try {
        conditionIdInt = int.parse(conditionId);
      } catch (e) {
        conditionIdInt = 0;
        debugPrint('⚠️ Error parsing conditionId: $e, using 0');
      }

      final requestBody = {
        "data": [
          {
            "patientId": patientId,
            "description": description,
            "practitionerId": practitionerIdInt,  // 🔥 SEND AS NUMBER
            "conditionId": conditionIdInt,        // 🔥 SEND AS NUMBER
            "documentType": documentType,
            "ipdOrOpd": ipdOrOpdInt,
            "uploadby": uploadby,
            "fileName": fileName,
            "fileType": fileType,
            "fileDataUrl": fileDataUrl,
          }
        ]
      };

      debugPrint('Upload Document Request Body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse(_uploadDocumentUrl),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      debugPrint('Upload Document API Status Code: ${response.statusCode}');
      debugPrint('Upload Document API Response: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          debugPrint('Document uploaded successfully');
          
          final hasSuccessMessage = decoded.containsKey('File uploaded successfully!') ||
                                   decoded.containsKey('message') ||
                                   decoded.containsKey('success');
          
          return {
            'success': true,
            'data': decoded['data'] ?? [],
            'message': decoded['File uploaded successfully!'] ?? 
                      decoded['message'] ?? 
                      'Document uploaded successfully',
            'response': decoded,
          };
        } else {
          throw Exception('Unexpected API response format');
        }
      } else {
        String errorMessage = 'Failed with status ${response.statusCode}';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody is Map<String, dynamic>) {
            errorMessage = errorBody['message'] ?? 
                          errorBody['error'] ?? 
                          errorMessage;
          }
        } catch (e) {
          errorMessage = response.body;
        }

        throw Exception('Failed to upload document: $errorMessage');
      }
    } catch (e, stackTrace) {
      debugPrint('Error uploading document: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  Future<String> fileToBase64DataUrl(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      
      String mimeType = 'application/octet-stream';
      final extension = file.path.split('.').last.toLowerCase();
      
      switch (extension) {
        case 'png':
          mimeType = 'image/png';
          break;
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'pdf':
          mimeType = 'application/pdf';
          break;
        case 'doc':
          mimeType = 'application/msword';
          break;
        case 'docx':
          mimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
          break;
        default:
          mimeType = 'application/octet-stream';
      }
      return 'data:$mimeType;base64,$base64String';
    } catch (e) {
      debugPrint('Error converting file to base64: $e');
      throw Exception('Failed to convert file: $e');
    }
  }

// FINAL FIX - Replace uploadDocument method in ipd_service.dart

// ✅ DEFINITIVE FIX - Replace uploadDocument method in ipd_service.dart
// The API requires fileName, fileType, and fileDataUrl even when empty

// ✅ ACTUAL FIX - Based on React code analysis
// practitionerId and conditionId must be STRINGS (not numbers)

// 🔥 CRITICAL TEST - Send as ARRAY (no "data" wrapper)

Future<Map<String, dynamic>> uploadDocument({
  required String patientId,
  required String description,
  required String documentType,
  File? file,
  required String ipdOrOpd,
  required String uploadby,
  required String practitionerId,
  required String conditionId,
}) async {
  debugPrint('========== UPLOAD DOCUMENT (ARRAY FORMAT) ==========');

  try {
    final prefs = await SharedPreferences.getInstance();
    String getPrefAsString(String key) => prefs.get(key)?.toString() ?? '';

    final token = getPrefAsString('auth_token');
    final clinicId = getPrefAsString('clinicId');
    final userId = getPrefAsString('userId');
    final branchId = getPrefAsString('branchId') ?? '1';

    if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) {
      throw Exception('⚠️ Missing session values');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Accept': '*/*',
      'Authorization': 'SmartCare $token',
      'clinicid': clinicId,
      'userid': userId,
      'ZONEID': 'Asia/Kolkata',
      'branchId': branchId,
    };

    int ipdOrOpdInt = int.tryParse(ipdOrOpd) ?? 0;

    String fileName = "";
    String fileType = "";
    String fileDataUrl = "";

    if (file != null) {
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      
      final extension = file.path.split('.').last.toLowerCase();
      switch (extension) {
        case 'png': fileType = 'image/png'; break;
        case 'jpg':
        case 'jpeg': fileType = 'image/jpeg'; break;
        case 'pdf': fileType = 'application/pdf'; break;
        default: fileType = 'application/octet-stream';
      }

      fileName = file.path.split('/').last;
      fileDataUrl = 'data:$fileType;base64,$base64String';
    }

    // Match React field order exactly
    final documentData = {
      "patientId": patientId,
      "description": description,
      "practitionerId": practitionerId,  // STRING
      "conditionId": conditionId,        // STRING
      "uploadby": uploadby,
      "documentType": documentType,
      "fileName": fileName,
      "ipdOrOpd": ipdOrOpdInt,           // NUMBER
      "fileDataUrl": fileDataUrl,
      "fileType": fileType,
    };

    // 🔥 SEND AS ARRAY (NOT wrapped in "data")
    final requestBody = [documentData];

    final bodyString = jsonEncode(requestBody);
    debugPrint('📤 Body Type: Array');
    debugPrint('📤 First 300 chars: ${bodyString.substring(0, bodyString.length > 300 ? 300 : bodyString.length)}');

    final response = await http.post(
      Uri.parse(_uploadDocumentUrl),
      headers: headers,
      body: bodyString,
    );

    debugPrint('📡 Status: ${response.statusCode}');
    debugPrint('📡 Response: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body);
      return {
        'success': true,
        'data': decoded is Map ? (decoded['data'] ?? []) : [],
        'message': decoded is Map 
            ? (decoded['File uploaded successfully!'] ?? decoded['message'] ?? 'Success')
            : 'Document uploaded successfully',
      };
    } else {
      return {
        'success': false,
        'message': 'Upload failed: ${response.statusCode}',
        'statusCode': response.statusCode,
        'body': response.body,
      };
    }
  } catch (e, stackTrace) {
    debugPrint('❌ Error: $e\n$stackTrace');
    return {'success': false, 'message': 'Error: $e'};
  }
}

  Map<String, dynamic> validateVitalsAgainstMaster({
    required String temperature,
    required String heartRate,
    required String respiratoryRate,
    required String systolicBp,
    required String diastolicBp,
    required String rbs,
    required String spo2,
    List<dynamic>? masterData,
  }) {
    final errors = <String, String>{};

    if (masterData == null || masterData.isEmpty) {
      return _basicVitalsValidation(
        temperature: temperature,
        heartRate: heartRate,
        respiratoryRate: respiratoryRate,
        systolicBp: systolicBp,
        diastolicBp: diastolicBp,
        rbs: rbs,
        spo2: spo2,
      );
    }

    for (var vital in masterData) {
      if (vital is Map<String, dynamic>) {
        final vitalId = vital['id']?.toString();
        final vitalName = vital['name']?.toString() ?? '';

        switch (vitalId) {
          case '1':
            _validateVital(
              vitalName,
              temperature,
              vital['min_value_f']?.toString(),
              vital['max_value_f']?.toString(),
              errors,
              fieldName: 'temperature',
            );
            break;

          case '2':
            _validateVital(
              vitalName,
              heartRate,
              vital['min_value_f']?.toString(),
              vital['max_value_f']?.toString(),
              errors,
              fieldName: 'heartRate',
            );
            break;

          case '3':
            _validateVital(
              vitalName,
              respiratoryRate,
              vital['min_value_f']?.toString(),
              vital['max_value_f']?.toString(),
              errors,
              fieldName: 'respiratoryRate',
            );
            break;

          case '4':
            _validateVital(
              vitalName,
              systolicBp,
              vital['min_value_f']?.toString(),
              vital['max_value_f']?.toString(),
              errors,
              fieldName: 'systolicBp',
            );
            break;

          case '5':
            _validateVital(
              vitalName,
              diastolicBp,
              vital['min_value_f']?.toString(),
              vital['max_value_f']?.toString(),
              errors,
              fieldName: 'diastolicBp',
            );
            break;

          case '6':
            _validateVital(
              vitalName,
              rbs,
              vital['min_value_f']?.toString(),
              vital['max_value_f']?.toString(),
              errors,
              fieldName: 'rbs',
            );
            break;

          case '13': // SpO2
            _validateVital(
              vitalName,
              spo2,
              vital['min_value_f']?.toString(),
              vital['max_value_f']?.toString(),
              errors,
              fieldName: 'spo2',
            );
            break;
        }
      }
    }

    final sys = double.tryParse(systolicBp);
    final dia = double.tryParse(diastolicBp);
    if (sys != null && dia != null && sys <= dia) {
      errors['bloodPressure'] = 'Systolic must be greater than diastolic';
    }

    return {
      'isValid': errors.isEmpty,
      'errors': errors,
    };
  }

  Map<String, dynamic> _basicVitalsValidation({
    required String temperature,
    required String heartRate,
    required String respiratoryRate,
    required String systolicBp,
    required String diastolicBp,
    required String rbs,
    required String spo2,
  }) {
    final errors = <String, String>{};

    final temp = double.tryParse(temperature);
    if (temp == null || temp < 90 || temp > 110) {
      errors['temperature'] = 'Temperature must be between 90°F and 110°F';
    }

    final hr = int.tryParse(heartRate);
    if (hr == null || hr < 30 || hr > 200) {
      errors['heartRate'] = 'Heart rate must be between 30 and 200 bpm';
    }

    final rr = int.tryParse(respiratoryRate);
    if (rr == null || rr < 6 || rr > 60) {
      errors['respiratoryRate'] = 'Respiratory rate must be between 6 and 60 /min';
    }

    final sys = int.tryParse(systolicBp);
    final dia = int.tryParse(diastolicBp);
    if (sys == null || sys < 70 || sys > 250) {
      errors['systolicBp'] = 'Systolic BP must be between 70 and 250 mmHg';
    }
    if (dia == null || dia < 40 || dia > 150) {
      errors['diastolicBp'] = 'Diastolic BP must be between 40 and 150 mmHg';
    }
    if (sys != null && dia != null && sys <= dia) {
      errors['bloodPressure'] = 'Systolic must be greater than diastolic';
    }

    final rbsVal = int.tryParse(rbs);
    if (rbsVal == null || rbsVal < 20 || rbsVal > 600) {
      errors['rbs'] = 'RBS must be between 20 and 600 mg/dL';
    }

    final spo2Val = int.tryParse(spo2);
    if (spo2Val == null || spo2Val < 70 || spo2Val > 100) {
      errors['spo2'] = 'SpO2 must be between 70% and 100%';
    }

    return {
      'isValid': errors.isEmpty,
      'errors': errors,
    };
  }

  void _validateVital(
    String vitalName,
    String value,
    String? minValue,
    String? maxValue,
    Map<String, String> errors, {
    required String fieldName,
  }) {
    if (value.isEmpty) return;

    final numValue = double.tryParse(value);
    final min = double.tryParse(minValue ?? '');
    final max = double.tryParse(maxValue ?? '');

    if (numValue == null) {
      errors[fieldName] = '$vitalName must be a valid number';
      return;
    }

    if (min != null && numValue < min) {
      errors[fieldName] = '$vitalName must be at least $min';
    }

    if (max != null && numValue > max) {
      errors[fieldName] = '$vitalName must be at most $max';
    }
  }

  List<Map<String, dynamic>> prepareVitalEntries({
    required String temperature,
    required String heartRate,
    required String respiratoryRate,
    required String systolicBp,
    required String diastolicBp,
    required String rbs,
    required String spo2,
  }) {
    return [
      if (temperature.isNotEmpty) {'vitalMasterId': 1, 'finding': temperature},
      if (heartRate.isNotEmpty) {'vitalMasterId': 2, 'finding': heartRate},
      if (respiratoryRate.isNotEmpty) {'vitalMasterId': 3, 'finding': respiratoryRate},
      if (systolicBp.isNotEmpty) {'vitalMasterId': 4, 'finding': systolicBp},
      if (diastolicBp.isNotEmpty) {'vitalMasterId': 5, 'finding': diastolicBp},
      if (rbs.isNotEmpty) {'vitalMasterId': 6, 'finding': rbs},
      if (spo2.isNotEmpty) {'vitalMasterId': 13, 'finding': spo2},
    ];
  }

  Future fetchVitalsByType(int i) async {}

  // ---------------------------------------------------------------------------
  // Day-to-Day Notes
  // ---------------------------------------------------------------------------

  /// Fetches the day-to-day notes for an admitted IPD patient.
  ///
  /// [ipdid]         - The IPD record ID (e.g. 12129).
  /// [admissiondate] - The admission date-time string in the format
  ///                   "dd-MM-yyyy HH:mm:ss" (e.g. "07-01-2026 10:27:59").
  ///
  /// Returns a [Map] with:
  ///   - `success`  (bool)   – whether the call succeeded.
  ///   - `data`     (List)   – list of [DayToDayNote]-like maps from
  ///                           `day_to_day_note_list`, or an empty list.
  ///   - `message`  (String) – human-readable status.
  ///   - `error`    (String) – error detail when `success` is false.
  Future<Map<String, dynamic>> fetchDayToDayNotes({
    required String ipdid,
    required String admissiondate,
  }) async {
    debugPrint('Fetching day-to-day notes for ipdid: $ipdid, admissiondate: $admissiondate');

    try {
      final prefs = await SharedPreferences.getInstance();

      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }

      final token = getPrefAsString('auth_token');
      final clinicId = getPrefAsString('clinicId');
      final userId = getPrefAsString('userId');
      final branchId = getPrefAsString('branchId').isNotEmpty
          ? getPrefAsString('branchId')
          : '1';

      if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) {
        return {
          'success': false,
          'message': '⚠️ Missing session values. Please login again.',
          'data': [],
        };
      }

      final headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        'branchId': branchId,
        'Access-Control-Allow-Origin': '*',
      };

      final body = {
        'admissiondate': admissiondate,
        'ipdid': int.tryParse(ipdid) ?? ipdid,
      };

      debugPrint('--DAY TO DAY NOTES FETCH API--');
      debugPrint('URL     : $_dayToDayNotesUrl');
      debugPrint('Headers : $headers');
      debugPrint('Body    : ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse(_dayToDayNotesUrl),
        headers: headers,
        body: jsonEncode(body),
      );

      debugPrint('Day-to-Day Notes API Status Code : ${response.statusCode}');
      debugPrint('Day-to-Day Notes API Response    : ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          // The API wraps all notes inside "day_to_day_note_list".
          final noteList = decoded['day_to_day_note_list'];

          final List<dynamic> notes =
              (noteList is List) ? noteList : [];

          debugPrint('Successfully fetched ${notes.length} day-to-day note(s)');

          return {
            'success': true,
            'message': 'Day-to-day notes fetched successfully',
            'data': notes,
            // Also expose the root-level wrapper fields for completeness.
            'meta': {
              'id': decoded['id'],
              'ipdid': decoded['ipdid'],
              'day': decoded['day'],
              'patientid': decoded['patientid'],
              'date': decoded['date'],
              'isindish': decoded['isindish'],
              'createdByUserId': decoded['createdByUserId'],
              'admissiondate': decoded['admissiondate'],
            },
          };
        } else {
          throw Exception(
            'Unexpected API response format. Expected a map but got: ${decoded.runtimeType}',
          );
        }
      } else {
        String errorMessage = 'Failed with status ${response.statusCode}';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody is Map<String, dynamic>) {
            errorMessage = errorBody['message'] ??
                errorBody['error'] ??
                errorMessage;
          }
        } catch (_) {
          errorMessage = response.body.isNotEmpty
              ? response.body
              : errorMessage;
        }

        debugPrint('Day-to-Day Notes API Error: $errorMessage');

        return {
          'success': false,
          'message': 'Failed to fetch day-to-day notes: $errorMessage',
          'statusCode': response.statusCode,
          'data': [],
          'error': response.body,
        };
      }
    } catch (e, stackTrace) {
      debugPrint('Exception fetching day-to-day notes: $e');
      debugPrint('StackTrace: $stackTrace');
      return {
        'success': false,
        'message': 'Exception fetching day-to-day notes: $e',
        'data': [],
      };
    }
  }

  /// Saves a day-to-day note for an admitted IPD patient.
  ///
  /// [ipdid]         - The IPD record ID (e.g. 12129).
  /// [admissiondate] - The admission date-time string in the format
  ///                   "dd-MM-yyyy HH:mm:ss" (e.g. "07-01-2026 10:27:59").
  /// [notes]         - The note content to save.
  /// [day]           - The day number for the note.
  /// [id]            - The note ID (use 0 for new notes).
  /// [createdByUserId] - The user ID of the person creating the note.
  ///
  /// Returns a [Map] with:
  ///   - `success`  (bool)   – whether the call succeeded.
  ///   - `data`     (dynamic) – response data from the API.
  ///   - `message`  (String) – human-readable status.
  ///   - `error`    (String) – error detail when `success` is false.
  Future<Map<String, dynamic>> saveDayToDayNote({
    required String ipdid,
    required String admissiondate,
    required String notes,
    required int day,
    required int id,
    required String createdByUserId,
  }) async {
    debugPrint('Saving day-to-day note for ipdid: $ipdid, day: $day');

    try {
      final prefs = await SharedPreferences.getInstance();

      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }

      final token = getPrefAsString('auth_token');
      final clinicId = getPrefAsString('clinicId');
      final userId = getPrefAsString('userId');
      final branchId = getPrefAsString('branchId').isNotEmpty
          ? getPrefAsString('branchId')
          : '1';

      if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) {
        return {
          'success': false,
          'message': '⚠️ Missing session values. Please login again.',
          'data': null,
        };
      }

      final headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        'branchId': branchId,
        'Access-Control-Allow-Origin': '*',
      };

      // Parse ipdid to integer
      int ipdidInt;
      try {
        ipdidInt = int.parse(ipdid);
      } catch (e) {
        ipdidInt = 0;
        debugPrint('⚠️ Error parsing ipdid: $e, using 0');
      }

      final body = {
        'admissiondate': admissiondate,
        'ipdid': ipdidInt,
        'notes': notes,
        'day': day,
        'id': id,
        'createdByUserId': createdByUserId,
      };

      debugPrint('--DAY TO DAY NOTES SAVE API--');
      debugPrint('URL     : $_saveDayToDayNotesUrl');
      debugPrint('Headers : $headers');
      debugPrint('Body    : ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse(_saveDayToDayNotesUrl),
        headers: headers,
        body: jsonEncode(body),
      );

      debugPrint('Save Day-to-Day Notes API Status Code : ${response.statusCode}');
      debugPrint('Save Day-to-Day Notes API Response    : ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        return {
          'success': true,
          'message': 'Day-to-day note saved successfully',
          'data': decoded,
        };
      } else {
        String errorMessage = 'Failed with status ${response.statusCode}';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody is Map<String, dynamic>) {
            errorMessage = errorBody['message'] ??
                errorBody['error'] ??
                errorMessage;
          }
        } catch (_) {
          errorMessage = response.body.isNotEmpty
              ? response.body
              : errorMessage;
        }

        debugPrint('Save Day-to-Day Notes API Error: $errorMessage');

        return {
          'success': false,
          'message': 'Failed to save day-to-day note: $errorMessage',
          'statusCode': response.statusCode,
          'data': null,
          'error': response.body,
        };
      }
    } catch (e, stackTrace) {
      debugPrint('Exception saving day-to-day note: $e');
      debugPrint('StackTrace: $stackTrace');
      return {
        'success': false,
        'message': 'Exception saving day-to-day note: $e',
        'data': null,
      };
    }
  }
}