import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class InvestigationService {
  static const String _packageUrl =
      'https://test.smartcarehis.com:8443/master/package/packagelist';

  static const String _investigationTypeBaseUrl =
      'https://test.smartcarehis.com:8443/smartcaremain/investigation/master/testtypelist';

  static const String _templateUrl =
      'https://test.smartcarehis.com:8443/smartcaremain/investigation/investigtiontemplate';

  static const String _practitionerUrl =
      'https://test.smartcarehis.com:8443/smartcaremain/practitionerlist';

   static const String _saveTestRequestUrl =  
  'https://test.smartcarehis.com:8443/smartcaremain/investigation/savetestrequest';

  static const String _parameterListUrl =
      'https://test.smartcarehis.com:8443/smartcaremain/investigation/master/parameterlist';

  static const String _getChargeUrl =
      'https://test.smartcarehis.com:8443/smartcaremain/investigation/master/getcharge';

  static const String _jobTitleListUrl =
      'https://test.smartcarehis.com:8443/smartcaremain/clinic/jobtitle/list';

  static const String _patientInfoUrl = 
      'https://test.smartcarehis.com:8443/smartcaremain/patient/information';

  // 🔹 UPDATED: Fetch Patient Information and Save to SharedPreferences
  static Future<Map<String, dynamic>?> fetchPatientInformation({
    required String patientId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String getPref(String key) => prefs.getString(key) ?? '';

      final token = getPref('auth_token');
      final clinicId = getPref('clinicId');
      final branchId = getPref('branchId');
      final userId = getPref('userId');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': token.startsWith('SmartCare')
            ? token
            : 'SmartCare $token',
        'clinicid': clinicId,
        'zoneid': "Asia/Kolkata",
        'userid': userId,
        'branchId': branchId,
      };

      // 🔹 Add patientId at the end of URL like typeId/gender pattern
      final url = '$_patientInfoUrl/$patientId';
      debugPrint('🔹 Fetching patient information from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      debugPrint('🔹 Patient Info API Status: ${response.statusCode}');
      debugPrint('🔹 Patient Info Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('🔹 Patient Info Decoded: $decoded');
        
        // Handle different response structures
        Map<String, dynamic> patientData;
        if (decoded is Map) {
          patientData = (decoded['data'] ?? decoded) as Map<String, dynamic>;
        } else {
          patientData = decoded as Map<String, dynamic>;
        }
        
        // 🔹 Save patient-related parameters to SharedPreferences
        if (patientData.isNotEmpty) {
          // Save tpId (Treatment Plan ID)
          if (patientData.containsKey('tpId')) {
            await prefs.setString('patient_tpId', patientData['tpId'].toString());
            debugPrint('✅ Saved tpId: ${patientData['tpId']}');
          }
          // Save wardId
          if (patientData.containsKey('wardId')) {
            await prefs.setString('patient_wardId', patientData['wardId'].toString());
            debugPrint('✅ Saved wardId: ${patientData['wardId']}');
          }
          
          // Save patient name
          if (patientData.containsKey('patientName') || patientData.containsKey('name')) {
            final name = patientData['patientName'] ?? patientData['name'];
            await prefs.setString('patient_name', name.toString());
            debugPrint('✅ Saved patient name: $name');
          }
          
          // Save gender
          if (patientData.containsKey('gender')) {
            await prefs.setString('patient_gender', patientData['gender'].toString());
            debugPrint('✅ Saved gender: ${patientData['gender']}');
          }
          
          // Save age
          if (patientData.containsKey('age')) {
            await prefs.setString('patient_age', patientData['age'].toString());
            debugPrint('✅ Saved age: ${patientData['age']}');
          }
          
          // Save patient type/category
          if (patientData.containsKey('patientType')) {
            await prefs.setString('patient_type', patientData['patientType'].toString());
            debugPrint('✅ Saved patient type: ${patientData['patientType']}');
          }
          
          // Save admission ID if exists
          if (patientData.containsKey('admissionId')) {
            await prefs.setString('patient_admissionId', patientData['admissionId'].toString());
            debugPrint('✅ Saved admission ID: ${patientData['admissionId']}');
          }
          
          // Cache complete patient data for offline use
          await prefs.setString('cached_patient_$patientId', jsonEncode(patientData));
          debugPrint('✅ Cached complete patient data');
        }
        
        return patientData;
      } else {
        debugPrint('⚠️ Patient Info API returned: ${response.statusCode}');
        
        // Try to return cached data if API fails
        final cachedData = prefs.getString('cached_patient_$patientId');
        if (cachedData != null) {
          debugPrint('📦 Using cached patient data');
          return jsonDecode(cachedData) as Map<String, dynamic>;
        }
        
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error in fetchPatientInformation: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Try to return cached data on error
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedData = prefs.getString('cached_patient_$patientId');
        if (cachedData != null) {
          debugPrint('📦 Using cached patient data due to error');
          return jsonDecode(cachedData) as Map<String, dynamic>;
        }
      } catch (_) {}
      
      return null;
    }
  }

  // 🔹 NEW: Helper method to get saved patient parameters
  static Future<Map<String, String>> getSavedPatientParams() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'tpId': prefs.getString('patient_tpId') ?? '',
      'wardId': prefs.getString('patient_wardId') ?? '',
      'name': prefs.getString('patient_name') ?? '',
      'gender': prefs.getString('patient_gender') ?? '',
      'age': prefs.getString('patient_age') ?? '',
      'patientType': prefs.getString('patient_type') ?? '',
      'admissionId': prefs.getString('patient_admissionId') ?? '',
    };
  }

  // 🔹 NEW: Clear patient data from SharedPreferences
  static Future<void> clearPatientData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('patient_tpId');
    await prefs.remove('patient_wardId');
    await prefs.remove('patient_name');
    await prefs.remove('patient_gender');
    await prefs.remove('patient_age');
    await prefs.remove('patient_type');
    await prefs.remove('patient_admissionId');
    debugPrint('Cleared all patient data from SharedPreferences');
  }

  // Fetch Investigations
  static Future<List<String>> fetchInvestigations({
    required String query,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String getPref(String key) => prefs.getString(key) ?? '';

    final token = getPref('auth_token');
    final clinicId = getPref('clinicId');
    final branchId = getPref('branchId');
    final userId = getPref('userId');

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': token.startsWith('SmartCare')
          ? token
          : token,
      'clinicid': clinicId,
      'zoneid': "Asia/Kolkata",
      'userid': userId,
      'branchId': branchId,
    };

    final response = await http.get(Uri.parse(_packageUrl), headers: headers);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List<dynamic> dataList = decoded['data'] ?? [];

      final investigations = dataList
          .map((e) => e['name'] ?? e['packageName'] ?? '')
          .where((name) => name.toString().isNotEmpty)
          .cast<String>()
          .toList();

      await prefs.setStringList('cached_investigations', investigations);
      return investigations;
    } else {
      throw Exception(
        'Failed to load investigations. Code: ${response.statusCode}',
      );
    }
  }

  // Fetch Investigation Types - Returns full data with ID and gender
  static Future<List<Map<String, dynamic>>> fetchInvestigationTypes({
    required int typeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String getPref(String key) => prefs.getString(key) ?? '';

    final token = getPref('auth_token');
    final clinicId = getPref('clinicId');
    final branchId = getPref('branchId');
    final userId = getPref('userId');

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': token.startsWith('SmartCare')
          ? token
          :  'SmartCare $token',
      'clinicid': clinicId,
      'zoneid': "Asia/Kolkata",
      'userid': userId,
      'branchId': branchId,
    };

    final response = await http.get(
      Uri.parse('$_investigationTypeBaseUrl/$typeId/0'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List<dynamic> dataList = decoded['data'] ?? [];

      final types = dataList.map((e) {
        return {
          'id': e['id'] ?? e['testTypeId'] ?? 0,
          'name': e['name'] ?? e['testTypeName'] ?? '',
          'gender': e['gender'] ?? e['genderType'] ?? '',
          'testCode': e['testCode'] ?? e['code'] ?? e['searchCode'] ?? '',
          'charge': e['charge'] ?? e['amount'] ?? e['rate'] ?? '0',
          'description': e['description'] ?? '',
          'department': e['department'] ?? '',
        };
      }).where((item) => item['name'].toString().isNotEmpty).toList();

      final names = types.map((e) => e['name'].toString()).toList();
      await prefs.setStringList('cached_investigation_types', names);
      
      return types;
    } else {
      throw Exception(
        'Failed to load investigation types. Code: ${response.statusCode}',
      );
    }
  }

  // Fetch Investigation Templates
  static Future<List<String>> fetchInvestigationTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    String getPref(String key) => prefs.getString(key) ?? '';

    final token = getPref('auth_token');
    final clinicId = getPref('clinicId');
    final branchId = getPref('branchId');
    final userId = getPref('userId');

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': token.startsWith('SmartCare')
          ? token
          :  'SmartCare $token',
      'clinicid': clinicId,
      'zoneid': "Asia/Kolkata",
      'userid': userId,
      'branchId': branchId,
    };

    final response = await http.get(Uri.parse(_templateUrl), headers: headers);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List<dynamic> dataList = decoded['data'] ?? [];

      final templates = dataList
          .map((e) => e['templateName'] ?? e['name'] ?? '')
          .where((name) => name.toString().isNotEmpty)
          .cast<String>()
          .toList();

      await prefs.setStringList('cached_investigation_templates', templates);
      return templates;
    } else {
      throw Exception(
        'Failed to load investigation templates. Code: ${response.statusCode}',
      );
    }
  }

  // Fetch Parameter List - Accepts ID and gender
  static Future<List<dynamic>> fetchParameterList({
    int? investigationTypeId,
    String? gender,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String getPref(String key) => prefs.getString(key) ?? '';

      final token = getPref('auth_token');
      final clinicId = getPref('clinicId');
      final branchId = getPref('branchId');
      final userId = getPref('userId');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': token.startsWith('SmartCare')
            ? token
            : 'SmartCare $token',
        'clinicid': clinicId,
        'zoneid': "Asia/Kolkata",
        'userid': userId,
        'branchId': branchId,
      };

      String url = _parameterListUrl;
      if (investigationTypeId != null && gender != null && gender.isNotEmpty) {
        url = '$_parameterListUrl/$investigationTypeId/$gender';
        debugPrint('🔹 Fetching parameters with ID: $investigationTypeId, Gender: $gender');
      }

      debugPrint('🔹 Parameter API URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      debugPrint('🔹 Parameter List API Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> dataList = decoded['data'] ?? [];
        debugPrint('🔹 Parameter list returned ${dataList.length} items');
        return dataList;
      } else {
        debugPrint('⚠️ Parameter list API returned: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error in fetchParameterList: $e');
      return [];
    }
  }

  // 🔹 UPDATED: Get Charge API - now uses saved params from SharedPreferences
  static Future<Map<String, dynamic>> getCharge({
    required String tpId,
    required int investigationId,
    required String wardId, 
    required String name,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String getPref(String key) => prefs.getString(key) ?? '';

      final token = getPref('auth_token');
      final clinicId = getPref('clinicId');
      final branchId = getPref('branchId');
      final userId = getPref('userId');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': token.startsWith('SmartCare')
            ? token
            : 'SmartCare $token',
        'clinicid': clinicId,
        'zoneid': "Asia/Kolkata",
        'userid': userId,
        'branchId': branchId,
      };

      final body = jsonEncode({
        "tpId": tpId,
        "investigationId": investigationId,
        "wardId": wardId,
        "name": name,
        "clinicId": clinicId,
        "branchId": branchId,
      });

      debugPrint('🔹 Charge API Headers: $headers');
      debugPrint('🔹 Charge API Body: $body');

      final response = await http.post(
        Uri.parse(_getChargeUrl),
        headers: headers,
        body: body,
      );

      debugPrint('🔹 Charge API Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded;
      } else {
        debugPrint('⚠️ Charge API not available, will use default values');
        return {};
      }
    } catch (e) {
      debugPrint('⚠️ Charge API error (will use defaults): $e');
      return {};
    }
  }

  // Fetch Job Title List
  static Future<List<dynamic>> fetchJobTitleList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String getPref(String key) => prefs.getString(key) ?? '';

      final token = getPref('auth_token');
      final clinicId = getPref('clinicId');
      final branchId = getPref('branchId');
      final userId = getPref('userId');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': token.startsWith('SmartCare')
            ? token
            : 'SmartCare $token', 
        'clinicid': clinicId,
        'zoneid': "Asia/Kolkata",
        'userid': userId,
        'branchId': branchId,
      };

      debugPrint('Fetching Job Titles from: $_jobTitleListUrl');

      final response = await http.get(
        Uri.parse(_jobTitleListUrl),
        headers: headers,
      );

      debugPrint('Job Title API Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('Job Title API Response: ${response.body}');
        
        final decoded = jsonDecode(response.body);
        
        if (decoded is List) {
          debugPrint('Response is a List with ${decoded.length} items');
          return decoded;
        } else if (decoded is Map) {
          final List<dynamic> dataList = decoded['data'] ?? 
                                         decoded['jobTitles'] ?? 
                                         decoded['list'] ?? 
                                         decoded['jobtitles'] ?? 
                                         [];
          debugPrint('Response is a Map, extracted list with ${dataList.length} items');
          return dataList;
        }
        debugPrint('Response format not recognized');
        return [];
      } else {
        debugPrint('Job title list API returned: ${response.statusCode}');
        return [];
      }
    } catch (e, stackTrace) {
      debugPrint('Error in fetchJobTitleList: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  // Cached Data
  static Future<List<String>> getCachedInvestigations() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('cached_investigations') ?? [];
  }

  static Future<List<String>> getCachedInvestigationTypes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('cached_investigation_types') ?? [];
  }

  static Future<List<String>> getCachedInvestigationTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('cached_investigation_templates') ?? [];
  }

  static Future<void> cacheInvestigations(List<String> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('cached_investigations', list);
  }

  static Future<void> cacheInvestigationTypes(List<String> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('cached_investigation_types', list);
  }

  static Future<void> cacheInvestigationTemplates(List<String> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('cached_investigation_templates', list);
  }

  // Fetch Practitioners Names
  static Future<List<String>> fetchPractitionersNames({
    required String branchId,
    required int specializationId,
    required int isVisitingConsultant,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String getPref(String key) => prefs.getString(key) ?? '';
    final token = getPref('auth_token');
    final clinicId = getPref('clinicId');
    final userId = getPref('userId');

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': token.startsWith('SmartCare')
          ? token
          : 'SmartCare $token',
      'clinicid': clinicId,
      'zoneid': "Asia/Kolkata",
      'userid': userId,
      'branchId': branchId,
    };

    final body = jsonEncode({
      "branchid": branchId,
      "specializationid": specializationId,
      "isVisitingConsultant": isVisitingConsultant,
    });

    final response = await http.post(
      Uri.parse(_practitionerUrl),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List<dynamic> dataList = decoded['practitionerList'] ?? [];
      final names = dataList
          .map((e) => e['practitionername'] ?? '')
          .where((name) => name.toString().isNotEmpty)
          .cast<String>()
          .toList();
      return names;
    } else {
      throw Exception(
        'Failed to load practitioners. Code: ${response.statusCode}',
      );
    }
  }

  // Save Investigation Test Request
  static Future<bool> saveInvestigationRequest({
    required String patientId,
    required List<Map<String, dynamic>> testList,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String getPref(String key) => prefs.getString(key) ?? '';
    final token = getPref('auth_token');
    final clinicId = getPref('clinicId');
    final branchId = getPref('branchId');
    final userId = getPref('userId');

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': token.startsWith('SmartCare')
          ? token
          : 'SmartCare $token',
      'clinicid': clinicId,
      'zoneid': "Asia/Kolkata",
      'userid': userId,
      'branchId': branchId,
    };

    final body = jsonEncode({"patientId": patientId, "testList": testList});
    debugPrint('Status code $_saveTestRequestUrl');
    debugPrint('Hello Hii $body');
    debugPrint('Headers $headers');

    final response = await http.post(
      Uri.parse(_saveTestRequestUrl),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded['status'] == 'success' || decoded['success'] == true) {
        return true;
      } else {
        throw Exception(
          'Failed to save investigation request: ${decoded['message'] ?? 'Unknown error'}',
        );
      }
    } else {
      throw Exception(
        'Failed to save investigation request. Code: ${response.statusCode}',
      );
    }
  }

  static Future<bool> submitInvestigationRequest(
    Map<String, Object?> requestData,
  ) async {
    throw UnimplementedError();
  }
}