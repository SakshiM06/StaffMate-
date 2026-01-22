import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PackageService {
  static const String _apiUrl =
      'https://test.smartcarehis.com:8443/billing/patientpackage/getPackageIfExists';
  static const String _referenceListApiUrl =
      'https://test.smartcarehis.com:8443/smartcaremain/refrencelist';
  static const String _chargeTypeListApiUrl =
      'https://test.smartcarehis.com:8443/billing/charges/chargetype/list';
  static const String _masterDetailListApiUrl =
      'https://test.smartcarehis.com:8443/billing/charges/master-detail-list';
  static const String _createChargeApiUrl =
      'https://test.smartcarehis.com:8443/billing/charges/createnew';

  static Future<Map<String, dynamic>> getPackageIfExists({
    required String patientId,
    required String datetime,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      debugPrint('=== SHARED PREFERENCES DEBUG ===');
      debugPrint('Available keys: ${prefs.getKeys()}');

      final token = prefs.getString('auth_token') ?? '';
      final clinicId = prefs.getString('clinicId') ?? '';
      final branchId = prefs.getString('branchId') ?? '';
      final userId = prefs.getString('userId') ?? '';

      debugPrint('Token length: ${token.length}');
      debugPrint('Token: $token');
      debugPrint('ClinicId: $clinicId');
      debugPrint('UserId: $userId');
      debugPrint('BranchId: $branchId');

      if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) {
        debugPrint('Missing required credentials: token=${token.isEmpty}, clinicId=${clinicId.isEmpty}, userId=${userId.isEmpty}');
        debugPrint('Returning empty package data');
        return {};
      }

      final headers = {
        'Content-Type': 'application/json',
        "Access-Control-Allow-Origin": "*",
        'Authorization': token.startsWith('SmartCare') ? token : 'SmartCare $token',
        'clinicId': clinicId,
        'zoneid': 'Asia/Kolkata',
        'userId': userId,
        'branchId': branchId,
      };

      final Map<String, dynamic> body = {
        'patientid': patientId,
        'datetime': datetime,
      };
      
      debugPrint('Patient ID: $patientId');
      debugPrint('Datetime: $datetime');
      debugPrint('=== API REQUEST DEBUG ===');
      debugPrint('URL: $_apiUrl');
      debugPrint('Headers: $headers');
      debugPrint('Body: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      debugPrint('=== API RESPONSE DEBUG ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        
        debugPrint('Package API Response decoded successfully');
        debugPrint('Package exists check: ${decoded.containsKey('id') && decoded['id'] != 0}');
        
        // Cache the response if package exists
        if (decoded['exists'] == true || decoded['package'] != null || (decoded.containsKey('id') && decoded['id'] != 0)) {
          await _cachePackageData(patientId, decoded);
          debugPrint('Package data cached for patient: $patientId');
        } else {
          debugPrint('No active package found for patient: $patientId');
        }
        
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
        
        debugPrint('PackageService: API returned error - $errorMessage');
        debugPrint('Continuing with empty package data');
        return {}; // Return empty map instead of throwing exception
      }
    } catch (e) {
      debugPrint('PackageService Error: $e');
      debugPrint('Stack trace: ${e.toString()}');
      debugPrint('Returning empty package data');
      return {}; // Return empty map on any error
    }
  }

  static Future<Map<String, dynamic>> getReferenceList({
    required String branchId,
    required String referredBy,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      debugPrint('=== REFERENCE LIST API - SHARED PREFERENCES DEBUG ===');
      debugPrint('Available keys: ${prefs.getKeys()}');

      final token = prefs.getString('auth_token') ?? '';
      final clinicId = prefs.getString('clinicId') ?? '';
      final storedBranchId = prefs.getString('branchId') ?? '';
      final userId = prefs.getString('userId') ?? '';

      debugPrint('Token length: ${token.length}');
      debugPrint('Token: $token');
      debugPrint('ClinicId: $clinicId');
      debugPrint('UserId: $userId');
      debugPrint('BranchId: $storedBranchId');

      if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) {
        debugPrint('Missing required credentials: token=${token.isEmpty}, clinicId=${clinicId.isEmpty}, userId=${userId.isEmpty}');
        debugPrint('Returning empty reference list data');
        return {};
      }

      final headers = {
        'Content-Type': 'application/json',
        "Access-Control-Allow-Origin": "*",
        'Authorization': token.startsWith('SmartCare') ? token : 'SmartCare $token',
        'clinicId': clinicId,
        'zoneid': 'Asia/Kolkata',
        'userId': userId,
        'branchId': storedBranchId,
      };

      final Map<String, dynamic> body = {
        'branchid': branchId,
        'reffered_by': referredBy,
      };

      debugPrint('=== REFERENCE LIST API REQUEST DEBUG ===');
      debugPrint('URL: $_referenceListApiUrl');
      debugPrint('Headers: $headers');
      debugPrint('Body: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse(_referenceListApiUrl),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      debugPrint('=== REFERENCE LIST API RESPONSE DEBUG ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        
        debugPrint('Reference list API Response decoded successfully');
        
        // Cache the response
        await _cacheReferenceList(branchId, referredBy, decoded);
        debugPrint('Reference list cached for branchId: $branchId, referredBy: $referredBy');
        
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
        
        debugPrint('ReferenceList: API returned error - $errorMessage');
        debugPrint('Continuing with empty reference list data');
        return {}; // Return empty map instead of throwing exception
      }
    } catch (e) {
      debugPrint('ReferenceList Error: $e');
      debugPrint('Stack trace: ${e.toString()}');
      debugPrint('Returning empty reference list data');
      return {}; // Return empty map on any error
    }
  }

  static Future<List<dynamic>> getChargeTypeList() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      debugPrint('=== CHARGE TYPE LIST API - SHARED PREFERENCES DEBUG ===');
      debugPrint('Available keys: ${prefs.getKeys()}');

      final token = prefs.getString('auth_token') ?? '';
      final clinicId = prefs.getString('clinicId') ?? '';
      final branchId = prefs.getString('branchId') ?? '';
      final userId = prefs.getString('userId') ?? '';

      debugPrint('Token length: ${token.length}');
      debugPrint('Token: $token');
      debugPrint('ClinicId: $clinicId');
      debugPrint('UserId: $userId');
      debugPrint('BranchId: $branchId');

      if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) {
        debugPrint('Missing required credentials: token=${token.isEmpty}, clinicId=${clinicId.isEmpty}, userId=${userId.isEmpty}');
        debugPrint('Returning empty charge type list');
        return [];
      }

      final headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Authorization': token.startsWith('SmartCare') ? token : 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        'branchId': branchId,
      };

      debugPrint('=== CHARGE TYPE LIST API REQUEST DEBUG ===');
      debugPrint('URL: $_chargeTypeListApiUrl');
      debugPrint('Headers: $headers');
      debugPrint('Note: This is a GET request with headers only');

      final response = await http.get(
        Uri.parse(_chargeTypeListApiUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      debugPrint('=== CHARGE TYPE LIST API RESPONSE DEBUG ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        
        debugPrint('Charge type list API Response decoded successfully');
        
        // Handle both array and object responses
        List<dynamic> chargeTypes = [];
        
        if (decoded is List) {
          chargeTypes = decoded;
          debugPrint('Response is a List with ${chargeTypes.length} items');
        } else if (decoded is Map<String, dynamic>) {
          // Check if the response contains a list in a property
          if (decoded.containsKey('data') && decoded['data'] is List) {
            chargeTypes = decoded['data'] as List<dynamic>;
            debugPrint('Response contains data List with ${chargeTypes.length} items');
          } else if (decoded.containsKey('chargeTypes') && decoded['chargeTypes'] is List) {
            chargeTypes = decoded['chargeTypes'] as List<dynamic>;
            debugPrint('Response contains chargeTypes List with ${chargeTypes.length} items');
          } else {
            debugPrint('Response is a Map but doesn\'t contain expected list property');
            // Try to convert the map to a list if it has array-like structure
            if (decoded.isNotEmpty) {
              chargeTypes = [decoded];
            }
          }
        }
        
        // Cache the response
        await _cacheChargeTypeList(chargeTypes);
        debugPrint('Charge type list cached with ${chargeTypes.length} items');
        
        return chargeTypes;
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
        
        debugPrint('ChargeTypeList: API returned error - $errorMessage');
        debugPrint('Continuing with empty charge type list');
        return []; // Return empty list instead of throwing exception
      }
    } catch (e) {
      debugPrint('ChargeTypeList Error: $e');
      debugPrint('Stack trace: ${e.toString()}');
      debugPrint('Returning empty charge type list');
      return []; // Return empty list on any error
    }
  }

  // NEW METHOD: Get Master Detail List of Charges
  static Future<Map<String, dynamic>> getMasterDetailList({
    required String chargeTypeId,
    String? practitionerId,
    String? searchKey,
    bool showWard = false,
    int thirdPartyId = 0,
    int wardId = 1,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      debugPrint('=== MASTER DETAIL LIST API - SHARED PREFERENCES DEBUG ===');
      debugPrint('Available keys: ${prefs.getKeys()}');

      final token = prefs.getString('auth_token') ?? '';
      final clinicId = prefs.getString('clinicId') ?? '';
      final branchId = prefs.getString('branchId') ?? '';
      final userId = prefs.getString('userId') ?? '';

      debugPrint('Token length: ${token.length}');
      debugPrint('Token: $token');
      debugPrint('ClinicId: $clinicId');
      debugPrint('UserId: $userId');
      debugPrint('BranchId: $branchId');

      if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) {
        debugPrint('Missing required credentials: token=${token.isEmpty}, clinicId=${clinicId.isEmpty}, userId=${userId.isEmpty}');
        debugPrint('Returning empty master detail list data');
        return {};
      }

      // Using the same headers as chargeTypeList API as specified
      final headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Authorization': token.startsWith('SmartCare') ? token : 'SmartCare $token',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        'branchId': branchId,
      };

      // Prepare request body based on the provided payload structure
      final Map<String, dynamic> body = {
        'chargeTypeId': chargeTypeId,
        'showWard': showWard,
        'thirdPartyId': thirdPartyId,
        'wardid': wardId,
      };

      // Add optional parameters if provided
      if (practitionerId != null && practitionerId.isNotEmpty) {
        body['practitionerid'] = practitionerId;
      }
      
      if (searchKey != null && searchKey.isNotEmpty) {
        body['searchKey'] = searchKey;
      }

      debugPrint('=== MASTER DETAIL LIST API REQUEST DEBUG ===');
      debugPrint('URL: $_masterDetailListApiUrl');
      debugPrint('Headers: $headers');
      debugPrint('Body: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse(_masterDetailListApiUrl),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      debugPrint('=== MASTER DETAIL LIST API RESPONSE DEBUG ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        
        debugPrint('Master detail list API Response decoded successfully');
        debugPrint('Response contains data: ${decoded.containsKey('data')}');
        debugPrint('Response message: ${decoded['message']}');
        
        // Cache the response with a specific key based on parameters
        await _cacheMasterDetailList(
          chargeTypeId: chargeTypeId,
          practitionerId: practitionerId,
          searchKey: searchKey,
          showWard: showWard,
          thirdPartyId: thirdPartyId,
          wardId: wardId,
          responseData: decoded,
        );
        
        debugPrint('Master detail list cached for chargeTypeId: $chargeTypeId');
        
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
        
        debugPrint('MasterDetailList: API returned error - $errorMessage');
        debugPrint('Continuing with empty master detail list data');
        return {}; // Return empty map instead of throwing exception
      }
    } catch (e) {
      debugPrint('MasterDetailList Error: $e');
      debugPrint('Stack trace: ${e.toString()}');
      debugPrint('Returning empty master detail list data');
      return {}; // Return empty map on any error
    }
  }

  // UPDATED METHOD: Create Charge with correct payload structure
  static Future<Map<String, dynamic>> createCharge({
    required int opdId,
    required int branchId,
    required String date,
    required String dateTime,
    required int discountGrpId,
    required List<Map<String, dynamic>> childListDTO,
    required int chargeAmount,
    required int chargeDiscountAmount,
    required int chargeId,
    required String patientId,
    required String patientName,
    required String practitionerID,
    required String practitionerName,
    String specializationId = "0",
    String standardChargeDate = "",
    int standardChargeId = 0,
    int thirdPartyId = 0,
    int investigationRequestId = 0,
    String investigationParentId = "",
    int packageidAppliedId = 0,
    int discountTeamId = 0,
    int discountTeamUserid = 0,
    bool opdCompleted = false,
    String? userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      debugPrint('=== CREATE CHARGE API - SHARED PREFERENCES DEBUG ===');
      debugPrint('Available keys: ${prefs.getKeys()}');

      final token = prefs.getString('auth_token') ?? '';
      final clinicId = prefs.getString('clinicId') ?? '';
      final storedBranchId = prefs.getString('branchId') ?? '';
      final currentUserId = userId ?? prefs.getString('userId') ?? '';

      debugPrint('Token length: ${token.length}');
      debugPrint('Token: $token');
      debugPrint('ClinicId: $clinicId');
      debugPrint('UserId: $currentUserId');
      debugPrint('BranchId: $storedBranchId');

      if (token.isEmpty || clinicId.isEmpty || currentUserId.isEmpty) {
        debugPrint('Missing required credentials: token=${token.isEmpty}, clinicId=${clinicId.isEmpty}, userId=${currentUserId.isEmpty}');
        debugPrint('Returning error response');
        return {
          'success': false,
          'message': 'Missing authentication credentials',
          'error': 'Unauthorized',
        };
      }

      // Prepare headers based on existing API patterns
      final headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Authorization': token.startsWith('SmartCare') ? token : 'SmartCare $token',
        'clinicId': clinicId,
        'userid': currentUserId,
        'ZONEID': 'Asia/Kolkata',
        'branchId': branchId.toString(),
      };

      // Prepare request body based on the provided payload structure
      final Map<String, dynamic> body = {
        'opdId': opdId,
        'branchId': branchId,
        'date': date,
        'dateTime': dateTime,
        'discountGrpId': discountGrpId,
        'childListDTO': childListDTO,
        'patientId': patientId,
        'patientName': patientName,
        'practitionerID': practitionerID,
        'practitionerName': practitionerName,
        'specializationId': specializationId,
        'standardChargeDate': standardChargeDate.isEmpty ? date : standardChargeDate,
        'standardChargeId': standardChargeId,
        'thirdPartyId': thirdPartyId,
        'investigationRequestId': investigationRequestId,
        'investigationParentId': investigationParentId,
        'packageidAppliedId': packageidAppliedId,
        'discountTeamId': discountTeamId,
        'discountTeamUserid': discountTeamUserid,
        'opdCompleted': opdCompleted,
        'userId': currentUserId,
      };

      debugPrint('=== CREATE CHARGE API REQUEST DEBUG ===');
      debugPrint('URL: $_createChargeApiUrl');
      debugPrint('Headers: $headers');
      debugPrint('Body: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse(_createChargeApiUrl),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      debugPrint('=== CREATE CHARGE API RESPONSE DEBUG ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        
        debugPrint('Create charge API Response decoded successfully');
        debugPrint('Response status: ${decoded['status']}');
        debugPrint('Response message: ${decoded['message']}');
        
        return {
          'success': true,
          'data': decoded,
          'message': decoded['message'] ?? 'Charge created successfully',
        };
      } else {
        String errorMessage = 'Error ${response.statusCode}';
        Map<String, dynamic> errorData = {};
        
        try {
          final err = jsonDecode(response.body);
          if (err is Map) {
            errorData = err as Map<String, dynamic>;
            if (err['message'] != null) {
              errorMessage = err['message'].toString();
            } else if (err['error'] != null) {
              errorMessage = err['error'].toString();
            } else if (err['status'] != null) {
              errorMessage = err['status'].toString();
            }
          }
        } catch (_) {
          errorMessage = response.body;
        }
        
        debugPrint('CreateCharge: API returned error - $errorMessage');
        
        return {
          'success': false,
          'message': errorMessage,
          'error': errorData,
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      debugPrint('CreateCharge Error: $e');
      debugPrint('Stack trace: ${e.toString()}');
      
      return {
        'success': false,
        'message': 'Failed to create charge: $e',
        'error': e.toString(),
      };
    }
  }

  // Helper method to create childListDTO item
  static Map<String, dynamic> createChildListItem({
    required int chargeId,
    required String chargeAmount,
    String? chargeDiscountAmount,
    String? chargeName,
    int chargeTypeId = 0,
    int discountGrpId = 0,
    int id = 0,
    bool isDiscard = false,
    int quantity = 1,
    String? serviceChargeId,
    String? unitId,
  }) {
    return {
      'chargeId': chargeId,
      'chargeAmount': chargeAmount,
      'chargeDiscountAmount': chargeDiscountAmount,
      'chargeName': chargeName ?? 'Service',
      'chargeTypeId': chargeTypeId,
      'discountGrpId': discountGrpId,
      'id': id,
      'isDiscard': isDiscard,
      'quantity': quantity,
      'serviceChargeId': serviceChargeId,
      'unitId': unitId,
    };
  }

  // Cache methods
  static Future<void> _cachePackageData(
    String patientId,
    Map<String, dynamic> packageData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'package_data_$patientId';
      await prefs.setString(key, jsonEncode(packageData));
      debugPrint('Package data cached for patient: $patientId');
    } catch (e) {
      debugPrint('Error caching package data: $e');
    }
  }

  static Future<void> _cacheReferenceList(
    String branchId,
    String referredBy,
    Map<String, dynamic> referenceData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'reference_list_${branchId}_$referredBy';
      await prefs.setString(key, jsonEncode(referenceData));
      debugPrint('Reference list cached for branchId: $branchId, referredBy: $referredBy');
    } catch (e) {
      debugPrint('Error caching reference list: $e');
    }
  }

  static Future<void> _cacheChargeTypeList(
    List<dynamic> chargeTypes,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'charge_type_list';
      await prefs.setString(key, jsonEncode(chargeTypes));
      debugPrint('Charge type list cached with ${chargeTypes.length} items');
    } catch (e) {
      debugPrint('Error caching charge type list: $e');
    }
  }

  static Future<void> _cacheMasterDetailList({
    required String chargeTypeId,
    String? practitionerId,
    String? searchKey,
    required bool showWard,
    required int thirdPartyId,
    required int wardId,
    required Map<String, dynamic> responseData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Create a unique key based on all parameters
      final key = 'master_detail_${chargeTypeId}_${practitionerId ?? 'null'}_${searchKey ?? 'null'}_${showWard}_${thirdPartyId}_${wardId}';
      
      await prefs.setString(key, jsonEncode(responseData));
      debugPrint('Master detail list cached with key: $key');
    } catch (e) {
      debugPrint('Error caching master detail list: $e');
    }
  }

  // Get cached data methods
  static Future<Map<String, dynamic>?> getCachedPackageData(
    String patientId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'package_data_$patientId';
      final cached = prefs.getString(key);
      
      if (cached == null || cached.isEmpty) {
        debugPrint('No cached package data found for patient: $patientId');
        return null;
      }
      
      debugPrint('Retrieved cached package data for patient: $patientId');
      return jsonDecode(cached) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error getting cached package data: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getCachedReferenceList(
    String branchId,
    String referredBy,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'reference_list_${branchId}_$referredBy';
      final cached = prefs.getString(key);
      
      if (cached == null || cached.isEmpty) {
        debugPrint('No cached reference list found for branchId: $branchId, referredBy: $referredBy');
        return null;
      }
      
      debugPrint('Retrieved cached reference list for branchId: $branchId, referredBy: $referredBy');
      return jsonDecode(cached) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error getting cached reference list: $e');
      return null;
    }
  }

  static Future<List<dynamic>> getCachedChargeTypeList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'charge_type_list';
      final cached = prefs.getString(key);
      
      if (cached == null || cached.isEmpty) {
        debugPrint('No cached charge type list found');
        return [];
      }
      
      debugPrint('Retrieved cached charge type list');
      final decoded = jsonDecode(cached);
      
      if (decoded is List) {
        return decoded;
      } else if (decoded is Map<String, dynamic>) {
        // Handle case where it might be stored as a map
        return [decoded];
      }
      
      return [];
    } catch (e) {
      debugPrint('Error getting cached charge type list: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getCachedMasterDetailList({
    required String chargeTypeId,
    String? practitionerId,
    String? searchKey,
    bool showWard = false,
    int thirdPartyId = 0,
    int wardId = 1,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Create the same unique key used for caching
      final key = 'master_detail_${chargeTypeId}_${practitionerId ?? 'null'}_${searchKey ?? 'null'}_${showWard}_${thirdPartyId}_${wardId}';
      
      final cached = prefs.getString(key);
      
      if (cached == null || cached.isEmpty) {
        debugPrint('No cached master detail list found for chargeTypeId: $chargeTypeId');
        return null;
      }
      
      debugPrint('Retrieved cached master detail list for chargeTypeId: $chargeTypeId');
      return jsonDecode(cached) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error getting cached master detail list: $e');
      return null;
    }
  }

  // Clear cache methods
  static Future<void> clearCachedPackageData(String patientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'package_data_$patientId';
      await prefs.remove(key);
      debugPrint('Cached package data cleared for patient: $patientId');
    } catch (e) {
      debugPrint('Error clearing cached package data: $e');
    }
  }

  static Future<void> clearCachedReferenceList(
    String branchId,
    String referredBy,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'reference_list_${branchId}_$referredBy';
      await prefs.remove(key);
      debugPrint('Cached reference list cleared for branchId: $branchId, referredBy: $referredBy');
    } catch (e) {
      debugPrint('Error clearing cached reference list: $e');
    }
  }

  static Future<void> clearCachedChargeTypeList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'charge_type_list';
      await prefs.remove(key);
      debugPrint('Cached charge type list cleared');
    } catch (e) {
      debugPrint('Error clearing cached charge type list: $e');
    }
  }

  static Future<void> clearCachedMasterDetailList({
    required String chargeTypeId,
    String? practitionerId,
    String? searchKey,
    bool showWard = false,
    int thirdPartyId = 0,
    int wardId = 1,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Create the same unique key used for caching
      final key = 'master_detail_${chargeTypeId}_${practitionerId ?? 'null'}_${searchKey ?? 'null'}_${showWard}_${thirdPartyId}_${wardId}';
      
      await prefs.remove(key);
      debugPrint('Cached master detail list cleared for key: $key');
    } catch (e) {
      debugPrint('Error clearing cached master detail list: $e');
    }
  }

  // Clear all cached data methods
  static Future<void> clearAllCachedPackages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      int count = 0;
      
      for (final key in keys) {
        if (key.startsWith('package_data_')) {
          await prefs.remove(key);
          count++;
        }
      }
      
      debugPrint('$count cached package data items cleared');
    } catch (e) {
      debugPrint('Error clearing all cached packages: $e');
    }
  }

  static Future<void> clearAllCachedReferenceLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      int count = 0;
      
      for (final key in keys) {
        if (key.startsWith('reference_list_')) {
          await prefs.remove(key);
          count++;
        }
      }
      
      debugPrint('$count cached reference list items cleared');
    } catch (e) {
      debugPrint('Error clearing all cached reference lists: $e');
    }
  }

  static Future<void> clearAllCachedChargeTypeLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      int count = 0;
      
      for (final key in keys) {
        if (key.startsWith('charge_type_list')) {
          await prefs.remove(key);
          count++;
        }
      }
      
      debugPrint('$count cached charge type list items cleared');
    } catch (e) {
      debugPrint('Error clearing all cached charge type lists: $e');
    }
  }

  static Future<void> clearAllCachedMasterDetailLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      int count = 0;
      
      for (final key in keys) {
        if (key.startsWith('master_detail_')) {
          await prefs.remove(key);
          count++;
        }
      }
      
      debugPrint('$count cached master detail list items cleared');
    } catch (e) {
      debugPrint('Error clearing all cached master detail lists: $e');
    }
  }

  // Utility methods
  static Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    return headers; // Return headers as-is (showing full token for debugging)
  }
  
  static String formatDateTimeForApi(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  static String getCurrentDateTime() {
    return formatDateTimeForApi(DateTime.now());
  }

  // Debugging methods
  static void debugPrintPackageResponse(Map<String, dynamic> response) {
    debugPrint('=== PACKAGE RESPONSE ANALYSIS ===');
    debugPrint('Response keys: ${response.keys}');
    
    if (response.isEmpty) {
      debugPrint('Response is empty');
      return;
    }
    
    // Check for package existence indicators
    bool hasPackage = false;
    if (response['id'] != null && response['id'] != 0) {
      debugPrint('Package ID found: ${response['id']}');
      hasPackage = true;
    }
    
    if (response['packagename'] != null && response['packagename'].toString().isNotEmpty) {
      debugPrint('Package name found: ${response['packagename']}');
      hasPackage = true;
    }
    
    if (response['exists'] == true) {
      debugPrint('Package exists flag: true');
      hasPackage = true;
    }
    
    if (response['package'] != null) {
      debugPrint('Package object found');
      hasPackage = true;
    }
    
    if (response['amount'] != null && (response['amount'] as num) > 0) {
      debugPrint('Package amount: ${response['amount']}');
      hasPackage = true;
    }
    
    debugPrint('Package exists: $hasPackage');
    
    // Print all values
    response.forEach((key, value) {
      debugPrint('$key: $value (${value.runtimeType})');
    });
  }

  static void debugPrintChargeTypeList(List<dynamic> chargeTypes) {
    debugPrint('=== CHARGE TYPE LIST ANALYSIS ===');
    debugPrint('Total charge types: ${chargeTypes.length}');
    
    for (int i = 0; i < chargeTypes.length && i < 5; i++) {
      final chargeType = chargeTypes[i];
      if (chargeType is Map) {
        debugPrint('Charge Type $i:');
        debugPrint('  ID: ${chargeType['id']}');
        debugPrint('  Name: ${chargeType['name']}');
        debugPrint('  Master ID: ${chargeType['masterid']}');
        debugPrint('  Compulsory Consultant: ${chargeType['compulsay_consultant']}');
      } else {
        debugPrint('Charge Type $i: $chargeType (${chargeType.runtimeType})');
      }
    }
    
    if (chargeTypes.length > 5) {
      debugPrint('... and ${chargeTypes.length - 5} more items');
    }
  }

  // NEW METHOD: Debug master detail list response
  static void debugPrintMasterDetailList(Map<String, dynamic> response) {
    debugPrint('=== MASTER DETAIL LIST RESPONSE ANALYSIS ===');
    debugPrint('Response keys: ${response.keys}');
    
    if (response.isEmpty) {
      debugPrint('Response is empty');
      return;
    }
    
    debugPrint('Status code: ${response['status_code']}');
    debugPrint('Message: ${response['message']}');
    debugPrint('Timestamp: ${response['timestamp']}');
    
    if (response.containsKey('data') && response['data'] is Map) {
      final data = response['data'] as Map<String, dynamic>;
      debugPrint('Data keys: ${data.keys}');
      
      if (data.containsKey('list') && data['list'] is List) {
        final list = data['list'] as List<dynamic>;
        debugPrint('List contains ${list.length} items');
        
        for (int i = 0; i < list.length && i < 5; i++) {
          final item = list[i];
          if (item is Map) {
            debugPrint('Item $i:');
            debugPrint('  ID: ${item['id']}');
            debugPrint('  Name: ${item['name']}');
            debugPrint('  Code: ${item['code']}');
            debugPrint('  Charge Type ID: ${item['chargeTypeId']}');
          }
        }
        
        if (list.length > 5) {
          debugPrint('... and ${list.length - 5} more items');
        }
      }
      
      if (data.containsKey('obj') && data['obj'] != null) {
        debugPrint('Object data available');
      }
    }
  }

  // Helper method to extract list from master detail response
  static List<dynamic> extractChargeListFromMasterDetail(Map<String, dynamic> response) {
    try {
      if (response.containsKey('data') && 
          response['data'] is Map && 
          (response['data'] as Map).containsKey('list')) {
        final list = (response['data'] as Map)['list'];
        if (list is List) {
          return list;
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error extracting charge list: $e');
      return [];
    }
  }
}