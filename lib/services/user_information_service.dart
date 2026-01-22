// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:flutter/foundation.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class UserInformationService {
//   Future<void> fetchAndSaveUserInformation({
//     required String token,
//     required String clinicId,
//     required String userId,
//     required String zoneid,
//     required int branchId,
//   }) async {
//     final prefs = await SharedPreferences.getInstance();

//     final headers = {
//       'Content-Type': 'application/json',
//       'Authorization': 'SmartCare $token',
//       'clinicid': clinicId,
//       'userid': userId,
//       'zoneid': zoneid,
//       'branchId': branchId.toString(),
//       'Access-Control-Allow-Origin': '*', 
//     };

//     debugPrint('=== User Information API HEADERS ===');
//     headers.forEach((k, v) => debugPrint('$k: $v'));

//     final url = Uri.parse(
//       'https://test.smartcarehis.com:8443/smartcaremain/userinformation',
//     );

   
//     final response = await http.get(url, headers: headers);

//     debugPrint('Status: ${response.statusCode}');
//     debugPrint('=== Response Body ===');
//     debugPrint('url Resonseee: $url');
//     try {
//       final decoded = jsonDecode(response.body);
//       final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
//       debugPrint('Body_kkkkkkkkkk:\n$pretty');
//     } catch (_) {
//       debugPrint('Body: ${response.body}');
//     }

//     if (response.statusCode != 200) {
//       throw Exception(
//         'Failed to fetch user information: ${response.statusCode} ${response.body}',
//       );
//     }

  
//     final Map<String, dynamic> json = jsonDecode(response.body);
//     final Map<String, dynamic> data = json['data'] ?? {};

//     final bearer = data['bearer']?.toString() ?? '';
//     final newToken = data['token']?.toString() ?? '';
//     final newClinicId = data['clinicUserid']?.toString() ?? '';
//     final newUserId = data['userId']?.toString() ?? '';
//     final newZoneId = data['zoneid']?.toString() ?? '';
//     final newBranchId = data['branchId'].toString(); 0;
//     final expirytime = data['expirytime']?.toString() ?? '';
//     final subDays = data['subscription_remaining_days']?.toString() ?? '';

//     debugPrint('BranchIddd: $newBranchId');

//     // Save to SharedPreferences
//     await prefs.setString('bearer', bearer);
//     await prefs.setString('token', newToken);
//     await prefs.setString('clinicId', newClinicId);
//     await prefs.setString('userId', newUserId);
//     await prefs.setString('zoneid', newZoneId);
//     await prefs.setString('branchId', newBranchId);
//     await prefs.setString('expirytime', expirytime);
//     await prefs.setString('subscription_remaining_days', subDays);
//   }

//   /// Get all saved user information from SharedPreferences.
//   static Future<Map<String, String>> getSavedUserInformation() async {
//     final prefs = await SharedPreferences.getInstance();
//     return {
//       'bearer': prefs.getString('bearer') ?? '',
//       'token': prefs.getString('token') ?? '',
//       'clinicId': prefs.getString('clinicId') ?? '',
//       'userId': prefs.getString('userId') ?? '',
//       'zoneid': prefs.getString('zoneid') ?? '',
//       'branchId': prefs.getString('branchId') ?? '',
//       'expirytime': prefs.getString('expirytime') ?? '',
//       'subscription_remaining_days':
//           prefs.getString('subscription_remaining_days') ?? '',
//     };
//   }

//   Future getUserInformation() async {}
// }


import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserInformationService {
  Future<Map<String, dynamic>> fetchAndSaveUserInformation({
    required String token,
    required String clinicId,
    required String userId,
    required String zoneid,
    required int branchId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'SmartCare $token',
      'clinicid': clinicId,
      'userid': userId,
      'zoneid': zoneid,
      'branchId': branchId.toString(),
      'Access-Control-Allow-Origin': '*', 
    };

    debugPrint('=== User Information API HEADERS ===');
    headers.forEach((k, v) => debugPrint('$k: $v'));

    final url = Uri.parse(
      'https://test.smartcarehis.com:8443/smartcaremain/userinformation',
    );

    final response = await http.get(url, headers: headers);

    debugPrint('Status: ${response.statusCode}');
    debugPrint('=== Response Body ===');
    debugPrint('url Response: $url');
    
    if (response.statusCode != 200) {
      debugPrint('Body: ${response.body}');
      throw Exception(
        'Failed to fetch user information: ${response.statusCode} ${response.body}',
      );
    }

    try {
      final Map<String, dynamic> json = jsonDecode(response.body);
      final pretty = const JsonEncoder.withIndent('  ').convert(json);
      debugPrint('Body:\n$pretty');

      // Check if API returned an error
      if (json['error'] != null && json['error'] is String) {
        final errorMsg = json['error'] as String;
        if (errorMsg.isNotEmpty && errorMsg != "null") {
          throw Exception('API Error: $errorMsg');
        }
      }

      final Map<String, dynamic> data = json['data'] ?? {};
      
      if (data.isEmpty) {
        throw Exception('No user data received from API');
      }

      debugPrint('✅ Successfully parsed user information');
      debugPrint('User ID: ${data['userId']}');
      debugPrint('Name: ${data['firstName']} ${data['lastName']}');
      debugPrint('Email: ${data['email']}');
      debugPrint('Mobile: ${data['mobileNo']}');
      debugPrint('Role: ${data['jobtitle']}');
      debugPrint('Clinic: ${data['clinicName']}');

      // Save COMPLETE user data to SharedPreferences
      await _saveUserDataToPrefs(prefs, data);
      
      // Also save the complete JSON response for easy access
      await prefs.setString('user_data_json', jsonEncode(json));
      
      debugPrint('✅ User information saved to SharedPreferences');
      
      return data;
      
    } catch (e) {
      debugPrint('❌ Error parsing response: $e');
      debugPrint('Raw response: ${response.body}');
      rethrow;
    }
  }

  /// Save all user data fields to SharedPreferences
  Future<void> _saveUserDataToPrefs(
      SharedPreferences prefs, Map<String, dynamic> data) async {
    
    // Personal Information
    await prefs.setString('userId', data['userId']?.toString() ?? '');
    await prefs.setString('username', data['userId']?.toString() ?? '');
    await prefs.setString('firstName', data['firstName']?.toString() ?? '');
    await prefs.setString('lastName', data['lastName']?.toString() ?? '');
    await prefs.setString('initial', data['initial']?.toString() ?? '');
    await prefs.setString('mobileNo', data['mobileNo']?.toString() ?? '');
    await prefs.setString('email', data['email']?.toString() ?? '');
    await prefs.setString('jobtitle', data['jobtitle']?.toString() ?? '');
    await prefs.setString('clinicName', data['clinicName']?.toString() ?? '');
    await prefs.setString('userType', data['userType']?.toString() ?? '');
    
    // Clinic/Branch Information
    await prefs.setString('clinicUserid', data['clinicUserid']?.toString() ?? '');
    await prefs.setString('branchId', data['branchId']?.toString() ?? '');
    await prefs.setString('branchAbrivation', data['branchAbrivation']?.toString() ?? '');
    
    // Address Information
    await prefs.setString('country', data['country']?.toString() ?? '');
    await prefs.setString('state', data['state']?.toString() ?? '');
    await prefs.setString('city', data['city']?.toString() ?? '');
    await prefs.setString('address', data['address']?.toString() ?? '');
    await prefs.setString('pinCode', data['pinCode']?.toString() ?? '');
    
    // Additional Information
    await prefs.setString('globalaccess', data['globalaccess']?.toString() ?? '');
    await prefs.setString('hasDiary', data['hasDiary']?.toString() ?? '');
    await prefs.setString('landLine', data['landLine']?.toString() ?? '');
    await prefs.setString('lastpasswordDate', data['lastpasswordDate']?.toString() ?? '');
    
    // Section/Specialization Information
    await prefs.setString('sectionId', data['sectionId']?.toString() ?? '');
    await prefs.setString('sectionName', data['sectionName']?.toString() ?? '');
    await prefs.setString('specializationId', data['specializationId']?.toString() ?? '');
    await prefs.setString('empId', data['empId']?.toString() ?? '');
    
    // Save accessinfo as JSON string
    if (data['accessinfo'] != null) {
      await prefs.setString('accessinfo', jsonEncode(data['accessinfo']));
    }
    
    // Save configurationMap as JSON string
    if (data['configurationMap'] != null) {
      await prefs.setString('configurationMap', jsonEncode(data['configurationMap']));
    }
    
    // Save tallyConfigurationMap as JSON string
    if (data['tallyConfigurationMap'] != null) {
      await prefs.setString('tallyConfigurationMap', jsonEncode(data['tallyConfigurationMap']));
    }
    
    debugPrint('📋 Saved ${data.length} user data fields to SharedPreferences');
  }

  /// Get all saved user information from SharedPreferences.
  static Future<Map<String, dynamic>> getSavedUserInformation() async {
    final prefs = await SharedPreferences.getInstance();
    
    final Map<String, dynamic> userInfo = {
      // Personal Information
      'userId': prefs.getString('userId') ?? '',
      'username': prefs.getString('username') ?? '',
      'firstName': prefs.getString('firstName') ?? '',
      'lastName': prefs.getString('lastName') ?? '',
      'initial': prefs.getString('initial') ?? '',
      'mobileNo': prefs.getString('mobileNo') ?? '',
      'email': prefs.getString('email') ?? '',
      'jobtitle': prefs.getString('jobtitle') ?? '',
      'clinicName': prefs.getString('clinicName') ?? '',
      'userType': prefs.getString('userType') ?? '',
      
      // Clinic/Branch Information
      'clinicUserid': prefs.getString('clinicUserid') ?? '',
      'branchId': prefs.getString('branchId') ?? '',
      'branchAbrivation': prefs.getString('branchAbrivation') ?? '',
      
      // Address Information
      'country': prefs.getString('country') ?? '',
      'state': prefs.getString('state') ?? '',
      'city': prefs.getString('city') ?? '',
      'address': prefs.getString('address') ?? '',
      'pinCode': prefs.getString('pinCode') ?? '',
      
      // Additional Information
      'globalaccess': prefs.getString('globalaccess') ?? '',
      'hasDiary': prefs.getString('hasDiary') ?? '',
      'landLine': prefs.getString('landLine') ?? '',
      'lastpasswordDate': prefs.getString('lastpasswordDate') ?? '',
      
      // Section/Specialization Information
      'sectionId': prefs.getString('sectionId') ?? '',
      'sectionName': prefs.getString('sectionName') ?? '',
      'specializationId': prefs.getString('specializationId') ?? '',
      'empId': prefs.getString('empId') ?? '',
    };

    // Try to parse JSON fields
    try {
      final accessinfoStr = prefs.getString('accessinfo');
      if (accessinfoStr != null && accessinfoStr.isNotEmpty) {
        userInfo['accessinfo'] = jsonDecode(accessinfoStr);
      }
      
      final configMapStr = prefs.getString('configurationMap');
      if (configMapStr != null && configMapStr.isNotEmpty) {
        userInfo['configurationMap'] = jsonDecode(configMapStr);
      }
      
      final tallyConfigStr = prefs.getString('tallyConfigurationMap');
      if (tallyConfigStr != null && tallyConfigStr.isNotEmpty) {
        userInfo['tallyConfigurationMap'] = jsonDecode(tallyConfigStr);
      }
    } catch (e) {
      debugPrint('❌ Error parsing JSON fields: $e');
    }

    return userInfo;
  }

  /// Get the complete user data JSON saved from API response
  static Future<Map<String, dynamic>?> getCompleteUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataJson = prefs.getString('user_data_json');
    
    if (userDataJson != null && userDataJson.isNotEmpty) {
      try {
        return jsonDecode(userDataJson);
      } catch (e) {
        debugPrint('❌ Error parsing user_data_json: $e');
      }
    }
    return null;
  }

  /// Get user profile info for display purposes
  static Future<Map<String, String>> getUserProfileForDisplay() async {
    final info = await getSavedUserInformation();
    
    // Build full name
    String fullName = '';
    final initial = info['initial'] ?? '';
    final firstName = info['firstName'] ?? '';
    final lastName = info['lastName'] ?? '';
    
    if (initial.isNotEmpty || firstName.isNotEmpty || lastName.isNotEmpty) {
      fullName = '$initial $firstName $lastName'.trim();
    } else {
      fullName = info['username'] ?? info['userId'] ?? 'User';
    }
    
    return {
      'fullName': fullName,
      'username': info['username'] ?? '',
      'userId': info['userId'] ?? '',
      'phone': info['mobileNo'] ?? '',
      'email': info['email'] ?? '',
      'role': info['jobtitle'] ?? 'Staff',
      'clinic': info['clinicName'] ?? '',
      'branch': info['branchAbrivation'] ?? '',
    };
  }

  /// Clear all user information from SharedPreferences
  static Future<void> clearUserInformation() async {
    final prefs = await SharedPreferences.getInstance();
    
    // List of all keys to remove
    final userKeys = [
      'userId', 'username', 'firstName', 'lastName', 'initial',
      'mobileNo', 'email', 'jobtitle', 'clinicName', 'userType',
      'clinicUserid', 'branchId', 'branchAbrivation',
      'country', 'state', 'city', 'address', 'pinCode',
      'globalaccess', 'hasDiary', 'landLine', 'lastpasswordDate',
      'sectionId', 'sectionName', 'specializationId', 'empId',
      'accessinfo', 'configurationMap', 'tallyConfigurationMap',
      'user_data_json',
    ];
    
    for (final key in userKeys) {
      await prefs.remove(key);
    }
    
    debugPrint('🧹 Cleared all user information from SharedPreferences');
  }

  /// Check if user information exists
  static Future<bool> hasUserInformation() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    return userId != null && userId.isNotEmpty;
  }

  static Future getSavedUserData() async {}

  static Future getCachedProfileInfo() async {}
}