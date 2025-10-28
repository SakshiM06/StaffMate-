import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:staff_mate/models/dashboard_data.dart';
import 'package:staff_mate/models/patient.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IpdService {
  static const String _baseUrl =
      "https://test.smartcarehis.com:8443/ipd/patient/all";

  Future<IpdDashboardData> fetchDashboardData() async {
    debugPrint('Fetching IPD dashboard data...');
    try {
      final prefs = await SharedPreferences.getInstance();

      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }

      final token = getPrefAsString('auth_token');
      // final clinicId = getPrefAsString('userId');
      final clinicId = getPrefAsString('clinicId');
      // final branchId = getPrefAsString('branchId');
      final userId = getPrefAsString('userId');
      // final zoneid = getPrefAsString('zoneid');

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
        'branchId': 1,
      };

      debugPrint('Headerss $headers');

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

  // ✅ Save first patient's admissionId (or whichever is needed)
  if (patientList.isNotEmpty) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admissionid', patientList.first.admissionId);
        debugPrint("Admission ID saved: ${patientList.first.admissionId}");
  }

  return IpdDashboardData(
    patients: patientList,
  );
}
 else {
          throw Exception(
            'Unexpected API format. Expected a list of patients but got: ${decoded.runtimeType}',
          );
        }
      } else {
        throw Exception(
          'Failed too load IPD data (Status ${response.statusCode}). Body: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching dashboard data: $e');
      log('StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Calculate dashboard counts from patient list
  // Map<String, int> _calculateStatistics(List<Patient> patients) {
  //   int excessAmount = 0;
  //   int self = 0;
  //   int mlc = 0;
  //   int tp = 0;
  //   int tpCorporate = 0;
  //   int toBeDischarged = 0;

  //   for (final p in patients) {
  //     if (p.dischargeStatus != '0') toBeDischarged++;
  //     if (p.isMlc != '0') mlc++;
  //     if (p.patientBalance > 0) excessAmount++;

  //     final partyLower = p.party.toLowerCase();
  //     if (partyLower.contains('corporate')) {
  //       tpCorporate++;
  //     } else if (partyLower.contains('third party')) {
  //       tp++;
  //     } else if (partyLower.contains('self')) {
  //       self++;
  //     }
  //   }

  //   return {
  //     'Excess Amount': excessAmount,
  //     'Inhouse Patients': patients.length,
  //     'Self': self,
  //     'MLC': mlc,
  //     'TP': tp,
  //     'TP Corporate': tpCorporate,
  //     'To be Discharged': toBeDischarged,
  //     'Total Bed': 97,
  //     'Available': 97 - patients.length,
  //   };
  // }
}
