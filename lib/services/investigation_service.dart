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

  static const String _patientIpdDetailsUrl =
      'https://test.smartcarehis.com:8443/billing/statement/patientinfoandlastipddetails';

  static Future<List<Map<String, dynamic>>> fetchJobTitles() async {
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

      debugPrint('🔹 FETCHING JOB TITLES FROM API');
      debugPrint('🔹 URL: $_jobTitleListUrl');

      final response = await http.get(
        Uri.parse(_jobTitleListUrl),
        headers: headers,
      );

      debugPrint('🔹 Job Titles API Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        List<Map<String, dynamic>> jobTitles = [];

        if (decoded is List) {
          jobTitles = List<Map<String, dynamic>>.from(
            decoded.map((item) => {
              'id': item['id'] ?? 0,
              'jobtitle': item['jobtitle'] ?? '',
              'jobgroup_id': item['jobgroup_id'] ?? 0,
              'userid': item['userid'] ?? 0,
            }),
          );
        } else if (decoded is Map) {
          final data = decoded['data'] ?? decoded['list'] ?? decoded;
          if (data is List) {
            jobTitles = List<Map<String, dynamic>>.from(
              data.map((item) => {
                'id': item['id'] ?? 0,
                'jobtitle': item['jobtitle'] ?? '',
                'jobgroup_id': item['jobgroup_id'] ?? 0,
                'userid': item['userid'] ?? 0,
              }),
            );
          }
        }

        await prefs.setString('cached_job_titles', jsonEncode(jobTitles));
        return jobTitles;
      } else {
        final cachedData = prefs.getString('cached_job_titles');
        if (cachedData != null) {
          final cachedList = jsonDecode(cachedData) as List;
          return List<Map<String, dynamic>>.from(
            cachedList.map((item) => Map<String, dynamic>.from(item))
          );
        }
        
        return [];
      }
    } catch (e, stackTrace) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedData = prefs.getString('cached_job_titles');
        if (cachedData != null) {
          final cachedList = jsonDecode(cachedData) as List;
          return List<Map<String, dynamic>>.from(
            cachedList.map((item) => Map<String, dynamic>.from(item))
          );
        }
      } catch (_) {}

      return [];
    }
  }

  static Future<Map<String, dynamic>?> fetchPatientIpdDetails({
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

      final url = '$_patientIpdDetailsUrl/$patientId';

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        Map<String, dynamic> ipdData;
        
        if (decoded is Map) {
          ipdData = (decoded['data'] ?? decoded) as Map<String, dynamic>;
        } else {
          ipdData = decoded as Map<String, dynamic>;
        }

        if (ipdData.isNotEmpty) {
          if (ipdData.containsKey('wardId')) {
            await prefs.setString('ipd_wardId', ipdData['wardId'].toString());
          }
          if (ipdData.containsKey('bedId')) {
            await prefs.setString('ipd_bedId', ipdData['bedId'].toString());
          }
          if (ipdData.containsKey('wardName')) {
            await prefs.setString('ipd_wardName', ipdData['wardName'].toString());
          }
          if (ipdData.containsKey('bedName')) {
            await prefs.setString('ipd_bedName', ipdData['bedName'].toString());
          }
          if (ipdData.containsKey('admissionDate')) {
            await prefs.setString('ipd_admissionDate', ipdData['admissionDate'].toString());
          }
          if (ipdData.containsKey('dischargeDate')) {
            await prefs.setString('ipd_dischargeDate', ipdData['dischargeDate'].toString());
          }
          if (ipdData.containsKey('tpId')) {
            await prefs.setString('ipd_tpId', ipdData['tpId'].toString());
          }

          await prefs.setString('cached_ipd_$patientId', jsonEncode(ipdData));
        }

        return ipdData;
      } else {
        final cachedData = prefs.getString('cached_ipd_$patientId');
        if (cachedData != null) {
          return jsonDecode(cachedData) as Map<String, dynamic>;
        }
        return null;
      }
    } catch (e, stackTrace) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedData = prefs.getString('cached_ipd_$patientId');
        if (cachedData != null) {
          return jsonDecode(cachedData) as Map<String, dynamic>;
        }
      } catch (_) {}

      return null;
    }
  }

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

      final url = '$_patientInfoUrl/$patientId';
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        Map<String, dynamic> patientData;
        
        if (decoded is Map) {
          patientData = (decoded['data'] ?? decoded) as Map<String, dynamic>;
        } else {
          patientData = decoded as Map<String, dynamic>;
        }

        if (patientData.isNotEmpty) {
          if (patientData.containsKey('tpId')) {
            await prefs.setString('patient_tpId', patientData['tpId'].toString());
          }
          if (patientData.containsKey('wardId')) {
            await prefs.setString('patient_wardId', patientData['wardId'].toString());
          }
          if (patientData.containsKey('patientName') || patientData.containsKey('name')) {
            final name = patientData['patientName'] ?? patientData['name'];
            await prefs.setString('patient_name', name.toString());
          }
          if (patientData.containsKey('gender')) {
            await prefs.setString('patient_gender', patientData['gender'].toString());
          }

          await prefs.setString('cached_patient_$patientId', jsonEncode(patientData));
        }

        return patientData;
      } else {
        final cachedData = prefs.getString('cached_patient_$patientId');
        if (cachedData != null) {
          return jsonDecode(cachedData) as Map<String, dynamic>;
        }
        return null;
      }
    } catch (e, stackTrace) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedData = prefs.getString('cached_patient_$patientId');
        if (cachedData != null) {
          return jsonDecode(cachedData) as Map<String, dynamic>;
        }
      } catch (_) {}

      return null;
    }
  }

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
      'Authorization': token.startsWith('SmartCare') ? token : token,
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
          : 'SmartCare $token',
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
          'sectionId': e['sectionId'] ?? 0,
          'testTypeId': e['testTypeId'] ?? e['id'] ?? 0,
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
          : 'SmartCare $token',
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
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> dataList = decoded['data'] ?? [];
        return dataList;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

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
        "tpId": tpId == 'null' ? 0 : int.tryParse(tpId) ?? 0,
        "investigationId": investigationId,
        "wardId": wardId == 'null' ? "0" : wardId,
        "name": name,
      });

      debugPrint('💰 CHARGE API REQUEST');
      debugPrint('🔹 Body: $body');

      final response = await http.post(
        Uri.parse(_getChargeUrl),
        headers: headers,
        body: body,
      );

      debugPrint('💰 CHARGE API RESPONSE');
      debugPrint('🔹 Status Code: ${response.statusCode}');
      debugPrint('🔹 Response: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded is Map<String, dynamic> 
            ? decoded 
            : {'data': decoded};
      } else {
        return {'error': 'Status ${response.statusCode}'};
      }
    } catch (e, stackTrace) {
      return {'error': e.toString()};
    }
  }

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

static Future<Map<String, dynamic>> saveInvestigationRequest({
  required String patientId,
  required List<Map<String, dynamic>> testList,
  required String jobTitle,
  required String location,
  required String consultantName,
  required String totalAmount,
  required bool isUrgent,
  String? tpId,
  String? wardId, 
  required List<Map<String, dynamic>> investigations,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    String getPref(String key) => prefs.getString(key) ?? '';
    
    final token = getPref('auth_token');
    final clinicId = getPref('clinicId');
    final branchId = getPref('branchId');
    final userId = getPref('userId');
    final userName = getPref('userName') ?? userId;
    final userNumericId = getPref('userNumericId') ?? '0';
   
    final savedIpdData = await getSavedIpdParams();
    final practitionerId = savedIpdData['practitionerId'] ?? getPref('practitionerId') ?? '0';
    final practitionerName = savedIpdData['practitionerName'] ?? getPref('practitionerName') ?? '';

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

    debugPrint('🔹 SAVE INVESTIGATION REQUEST - Preparing payload');
    debugPrint('🔹 User ID: $userId');
    debugPrint('🔹 User Numeric ID: $userNumericId');
    debugPrint('🔹 Practitioner ID: $practitionerId');
    debugPrint('🔹 Practitioner Name: $practitionerName');
    debugPrint('🔹 Branch ID: $branchId');

   
    int parsedTpId = 0;
    if (tpId != null && tpId.isNotEmpty && tpId != 'null') {
      try {
        parsedTpId = int.parse(tpId);
      } catch (e) {
        parsedTpId = 0;
      }
    }

    int parsedWardId = 0;
    if (wardId != null && wardId.isNotEmpty && wardId != 'null') {
      try {
        parsedWardId = int.parse(wardId);
      } catch (e) {
        parsedWardId = 0;
      }
    }

    final now = DateTime.now();
    final formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    final formattedTestList = testList.map((test) {
      final investigationType = investigations.firstWhere(
        (item) => item['typeId'] == test['typeId'],
        orElse: () => {},
      );

      int parsedPractitionerId = 0;
      if (practitionerId.isNotEmpty && practitionerId != 'null') {
        try {
          parsedPractitionerId = int.parse(practitionerId);
        } catch (e) {
          parsedPractitionerId = 0;
        }
      }

      
      int parsedUserNumericId = 0;
      if (userNumericId.isNotEmpty && userNumericId != 'null') {
        try {
          parsedUserNumericId = int.parse(userNumericId);
        } catch (e) {
          parsedUserNumericId = 0;
        }
      }

      int parsedBranchId = 1;
      if (branchId.isNotEmpty && branchId != 'null') {
        try {
          parsedBranchId = int.parse(branchId);
        } catch (e) {
          parsedBranchId = 1;
        }
      }

    
      int parsedPatientId = 0;
      if (patientId.isNotEmpty && patientId != 'null') {
        try {
          parsedPatientId = int.parse(patientId);
        } catch (e) {
          parsedPatientId = 0;
        }
      }

      final parameterList = [
        {
          "id": test['typeId'] ?? 0,
          "clientTestParameterId": null,
          "parameterId": test['typeId'] ?? 0,
          "parameterName": test['parameter']?.toString().split(',')[0]?.trim() ?? "",
          "parameterType": "",
          "investigationId": test['typeId'] ?? 0,
          "testTypeId": null,
          "testTypeName": null,
          "findings": "",
          "testParameterMethod": null,
          "normalValue": null,
          "totalObtainedValue": null,
          "specimen": "",
          "parameterUnit": "",
          "investigationCode": test['searchCode']?.toString() ?? "",
          "dateTime": null,
          "maleCriticalValue": null,
          "femaleCriticalValue": null,
          "childrenCriticalValue": null,
          "criticalValueFlag": null,
          "lowerCriticalValueFlag": null,
          "higherCriticalValueFlag": null,
          "constantParameterName": null,
          "parameterMethod": null,
          "methodName": "",
          "sectionName": null,
          "machineName": null,
          "labName": null,
          "constantTestName": null,
          "criticalValue": null,
          "reportType": null,
          "testParameterType": null,
          "historicParameterDataList": null,
          "indvRetportType": null,
          "unit": null,
          "rone": null,
          "rtwo": null,
          "rthree": null
        }
      ];

      return {
        "chargeAmount": null,
        "investigationId": test['typeId'] ?? 0,
        "investigationrequestId": null,
        "requestedDate": formattedDate,
        "collectedDate": null,
        "completedDate": null,
        "approvedDate": null,
        "testName": null,
        "sectionId": investigationType['sectionId'] ?? 14, 
        "reportType": "Text",
        "remark": "",
        "investigationScore": null,
        "practionerRegistrationNumber": null,
        "practitionerName": practitionerName,
        "patientName": null,
        "gender": null,
        "age": null,
        "uhid": null,
        "patientType": null,
        "referalName": null,
        "firstVerifierName": null,
        "verifierOneQualification": null,
        "verifierOneRegistrationNumber": null,
        "verifierOneSignature": null,
        "secondVerifierName": null,
        "verifierTwoQualification": null,
        "verifierTwoRegistrationNumber": null,
        "verifierTwoSignature": null,
        "completedByUserName": null,
        "approvedByUserName": null,
        "labName": null,
        "colonyCount": null,
        "gramStain": null,
        "growth": null,
        "hangingDrop": null,
        "macroScopy": null,
        "organismsIsolated": null,
        "znStains": null,
        "sectionName": null,
        "machineName": "",
        "constantTestName": null,
        "jobtitle": jobTitle,
        "parameterUnit": null,
        "testTypeId": test['typeId'] ?? 0,
        "testTypeDepartmentId": _getDepartmentIdFromJobTitle(jobTitle),
        "practitionerId": parsedPractitionerId,
        "patientId": parsedPatientId,
        "practitionerSpecializationId": _getSpecializationIdFromJobTitle(jobTitle),
        "dummy": null,
        "branchId": parsedBranchId,
        "advice": "",
        "indications": test['indications']?.toString() ?? "",
        "adviceInEnglish": "1",
        "adviceInHindi": "0",
        "adviceInRegional": "0",
        "packageId": 0,
        "userAlphaNumericId": userName,
        "userNumericId": parsedUserNumericId,
        "urgent": isUrgent ? 1 : 0,
        "testTypeName": test['type']?.toString() ?? "",
        "contactNo": null,
        "address": null,
        "collectedAt": null,
        "testParameterDTO": null,
        "parameterlist": parameterList,
        "antibioticsList": null,
        "emailTo": null,
        "clinicName": null,
        "clinicAddress": null,
        "phoneNo": null,
        "payee": null,
        "tpName": null,
        "wardName": null,
        "bedName": null,
        "imagePath": null,
        "sectionNameAccess": false,
        "hidemethod": false,
        "clinicEmail": null,
        "createdDateTime": null,
        "dob": null,
        "patientAge": null,
        "incubationTemperature": null,
        "incubationMedium": null,
        "incubationTime": null,
        "chargeStatus": null,
        "cultureMediaUsed": null,
        "cultureSpecimen": null,
        "requestDateTime": null,
        "methodForRt05": null,
        "abhaNumber": null,
        "abhaAddress": null,
        "website": null
      };
    }).toList();

    final body = jsonEncode({
      "patientId": patientId,
      "somantiqIntegration": false,
      "testList": formattedTestList,
      "jobTitle": jobTitle,
      "location": location,
      "consultantName": consultantName,
      "totalAmount": totalAmount,
      "isUrgent": isUrgent,
      "tpId": parsedTpId,
      "wardId": parsedWardId,
      "branchId": int.tryParse(branchId) ?? 1,
    });

    debugPrint('🔹 SAVE INVESTIGATION REQUEST');
    debugPrint('🔹 URL: $_saveTestRequestUrl');
    debugPrint('🔹 Headers: $headers');
    debugPrint('🔹 Request Body: $body');

    final response = await http.post(
      Uri.parse(_saveTestRequestUrl),
      headers: headers,
      body: body,
    ).timeout(const Duration(seconds: 30));

    debugPrint('🔹 Response Status Code: ${response.statusCode}');
    debugPrint('🔹 Response Body: ${response.body}');

    final decoded = jsonDecode(response.body);
    final responseMessage = decoded['message']?.toString() ?? '';
    final jsonStatusCode = decoded['status_code'];
    
    bool isSuccess = false;
    
    final lowerMessage = responseMessage.toLowerCase();
    if (lowerMessage.contains('saved successfully') || 
        lowerMessage.contains('successfully') ||
        lowerMessage.contains('investigation request saved')) {
      isSuccess = true;
    }
    
    if (jsonStatusCode != null && (jsonStatusCode == 200 || jsonStatusCode == 201)) {
      isSuccess = true;
    }
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      isSuccess = true;
    }

    if (isSuccess) {
      debugPrint('✅ Investigation Request SAVED SUCCESSFULLY');
      debugPrint('✅ Message: $responseMessage');
      return {
        'success': true,
        'message': responseMessage,
        'data': decoded['data'],
        'status_code': jsonStatusCode ?? response.statusCode,
      };
    } else {
      debugPrint('❌ Investigation Request FAILED');
      debugPrint('❌ Message: $responseMessage');
      return {
        'success': false,
        'message': responseMessage,
        'error': decoded['error'],
        'status_code': jsonStatusCode ?? response.statusCode,
      };
    }
  } catch (e) {
    debugPrint('🔹 Network error in saveInvestigationRequest: $e');
    return {
      'success': false,
      'message': 'Network error: $e',
      'error': e.toString(),
      'status_code': 0,
    };
  }
}

static int _getDepartmentIdFromJobTitle(String jobTitle) {
  switch (jobTitle.toLowerCase()) {
    case 'pathlab':
      return 5;
    case 'radiology':
      return 7;
    case 'cardiology':
      return 20;
    default:
      return 1;
  }
}

static int _getSpecializationIdFromJobTitle(String jobTitle) {
  switch (jobTitle.toLowerCase()) {
    case 'pathlab':
      return 5;
    case 'radiology':
      return 8; 
    case 'cardiology':
      return 9; 
    default:
      return 0;
  }
}


static Future<Map<String, String>> getSavedIpdParams() async {
  final prefs = await SharedPreferences.getInstance();
  return {
    'admissionId': prefs.getString('ipd_admissionId') ?? '',
    'wardId': prefs.getString('ipd_wardId') ?? '',
    'bedId': prefs.getString('ipd_bedId') ?? '',
    'wardName': prefs.getString('ipd_wardName') ?? '',
    'bedName': prefs.getString('ipd_bedName') ?? '',
    'admissionDate': prefs.getString('ipd_admissionDate') ?? '',
    'dischargeDate': prefs.getString('ipd_dischargeDate') ?? '',
    'tpId': prefs.getString('ipd_tpId') ?? '',
    'practitionerId': prefs.getString('ipd_practitionerId') ?? '',
    'practitionerName': prefs.getString('ipd_practitionerName') ?? '',
  };
}

static Future<void> _saveIpdDataToPrefs(Map<String, dynamic> ipdData) async {
  final prefs = await SharedPreferences.getInstance();
  
  if (ipdData.containsKey('wardId')) {
    await prefs.setString('ipd_wardId', ipdData['wardId'].toString());
  }
  if (ipdData.containsKey('bedId')) {
    await prefs.setString('ipd_bedId', ipdData['bedId'].toString());
  }
  if (ipdData.containsKey('wardName')) {
    await prefs.setString('ipd_wardName', ipdData['wardName'].toString());
  }
  if (ipdData.containsKey('bedName')) {
    await prefs.setString('ipd_bedName', ipdData['bedName'].toString());
  }
  if (ipdData.containsKey('admissionDate')) {
    await prefs.setString('ipd_admissionDate', ipdData['admissionDate'].toString());
  }
  if (ipdData.containsKey('dischargeDate')) {
    await prefs.setString('ipd_dischargeDate', ipdData['dischargeDate'].toString());
  }
  if (ipdData.containsKey('tpId')) {
    await prefs.setString('ipd_tpId', ipdData['tpId'].toString());
  }
  if (ipdData.containsKey('practitionerId')) {
    await prefs.setString('ipd_practitionerId', ipdData['practitionerId'].toString());
  }
  if (ipdData.containsKey('practitionername')) {
    await prefs.setString('ipd_practitionerName', ipdData['practitionername'].toString());
  }
  
  debugPrint('✅ Saved practitionerId: ${ipdData['practitionerId']}');
  debugPrint('✅ Saved practitionerName: ${ipdData['practitionername']}');
}

  static Future<Map<String, String>> getSavedPatientParams() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'patientName': prefs.getString('patient_name') ?? '',
      'patientGender': prefs.getString('patient_gender') ?? '',
      'patientTpId': prefs.getString('patient_tpId') ?? '',
      'patientWardId': prefs.getString('patient_wardId') ?? '',
    };
  }
}
  
