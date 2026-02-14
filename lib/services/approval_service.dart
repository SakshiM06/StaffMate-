import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApprovalService {
  static const String _bankNameUrl = "https://test.smartcarehis.com:8443/master/bankName/get";
  static const String _refundRequestListUrl = "https://test.smartcarehis.com:8443/billing/refund/get-request-list";
  static const String _locationUrl = "https://test.smartcarehis.com:8443/billing/charges/location/list";
  static const String _invoiceTypeListUrl = "https://test.smartcarehis.com:8443/billing/invoice/typelist";
  static const String _refundListUrl = "https://test.smartcarehis.com:8443/billing/refund/get-request-list";
  static const String _approveAllRefundUrl = "https://test.smartcarehis.com:8443/billing/refund/approveAll";

  // NEW: Approve All Refunds API Method
  Future<Map<String, dynamic>> approveAllRefunds({
    required List<Map<String, dynamic>> refundList,
    required String approvedNotes,
  }) async {
    debugPrint('🔄 Approving all selected refunds...');
    
    try {
      final prefs = await SharedPreferences.getInstance();

      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }
      
      final token = getPrefAsString('auth_token');
      final clinicId = getPrefAsString('clinicId');
      final currentUserId = getPrefAsString('userId');
      final branchId = getPrefAsString('branchId') ?? '1';

      if (token.isEmpty || clinicId.isEmpty || currentUserId.isEmpty) {
        throw Exception('⚠️ Missing session values. Please login again.');
      }

      debugPrint('Approve All Refunds API URL: $_approveAllRefundUrl');
      debugPrint('Number of refunds to approve: ${refundList.length}');
      debugPrint('Approval note: $approvedNotes');

      // Prepare request body as per your requirement
      final requestBody = {
        'refundList': refundList,
        'approvedNotes': approvedNotes,
      };

      debugPrint('Approve All Refunds API Request Body: $requestBody');

      final headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': currentUserId,
        'ZONEID': 'Asia/Kolkata',
        'branchId': branchId,
        'Access-Control-Allow-Origin': '*',
      };

      debugPrint('Approve All Refunds API Headers: $headers');
      
      final response = await http.post(
        Uri.parse(_approveAllRefundUrl),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      debugPrint('Approve All Refunds API Status Code: ${response.statusCode}');
      debugPrint('Approve All Refunds API Response: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        if (decoded is Map<String, dynamic>) {
          final statusCode = decoded['status_code'] ?? response.statusCode;
          final message = decoded['message'] ?? 'Success';
          final data = decoded['data'] ?? {};
          final error = decoded['error'];
          final timestamp = decoded['timestamp'] ?? '';

          if (statusCode == 200) {
            debugPrint('✅ Successfully approved ${refundList.length} refund(s)');
            
            return {
              'success': true,
              'statusCode': statusCode,
              'message': message,
              'timestamp': timestamp,
              'data': data,
              'error': error,
            };
          } else {
            throw Exception(
              'API returned error: $message (Status: $statusCode)',
            );
          }
        } else {
          throw Exception(
            'Unexpected API response format. Expected a map but got: ${decoded.runtimeType}',
          );
        }
      } else {
        throw Exception(
          'Failed to approve refunds (Status ${response.statusCode}). Body: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error approving refunds: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  // Convenience method for approving all refunds
  Future<Map<String, dynamic>> approveSelectedRefunds({
    required List<Map<String, dynamic>> refundList,
    String? approvedNotes,
  }) async {
    try {
      final response = await approveAllRefunds(
        refundList: refundList,
        approvedNotes: approvedNotes ?? '',
      );
      
      return response;
    } catch (e) {
      debugPrint('Exception in approveSelectedRefunds: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchInvoiceTypeList() async {
    debugPrint('Fetching invoice type list...');
    
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

      debugPrint('Invoice Type List API URL: $_invoiceTypeListUrl');

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

      debugPrint('Invoice Type List API Headers: $headers');
      
      final response = await http.get(
        Uri.parse(_invoiceTypeListUrl),
        headers: headers,
      );

      debugPrint('Invoice Type List API Status Code: ${response.statusCode}');
      debugPrint('Invoice Type List API Response: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        // Handle different response formats
        if (decoded is List) {
          // API returns a list directly
          debugPrint('✅ Invoice Type API returned a List directly');
          
          return {
            'success': true,
            'statusCode': 200,
            'message': 'Successfully fetched invoice type list',
            'timestamp': DateTime.now().toIso8601String(),
            'data': decoded,
            'error': null,
          };
        } else if (decoded is Map<String, dynamic>) {
          // API returns a map with standard format
          final statusCode = decoded['status_code'] ?? response.statusCode;
          final message = decoded['message'] ?? 'Success';
          final data = decoded['data'] ?? [];
          final error = decoded['error'];
          final timestamp = decoded['timestamp'] ?? '';

          if (statusCode == 200 && data is List) {
            debugPrint('✅ Invoice Type API returned a Map with standard format');
            
            return {
              'success': true,
              'statusCode': statusCode,
              'message': message,
              'timestamp': timestamp,
              'data': data,
              'error': error,
            };
          } else {
            throw Exception(
              'API returned error: $message (Status: $statusCode)',
            );
          }
        } else {
          throw Exception(
            'Unexpected API response format. Expected a List or Map but got: ${decoded.runtimeType}',
          );
        }
      } else {
        throw Exception(
          'Failed to load invoice types (Status ${response.statusCode}). Body: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching invoice types: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  // Convenience methods for invoice types
  Future<List<dynamic>> getInvoiceTypeList() async {
    try {
      final response = await fetchInvoiceTypeList();
      
      if (response['success'] == true && response['data'] is List) {
        return response['data'] as List;
      } else {
        debugPrint('Failed to get invoice type list: ${response['message']}');
        return [];
      }
    } catch (e) {
      debugPrint('Exception in getInvoiceTypeList: $e');
      return [];
    }
  }

  Future<Map<int, String>> getInvoiceTypeMap() async {
    try {
      final invoiceTypeList = await getInvoiceTypeList();
      final invoiceTypeMap = <int, String>{};
      
      for (var invoiceType in invoiceTypeList) {
        if (invoiceType is Map<String, dynamic>) {
          final id = invoiceType['invoice_type_id'];
          final name = invoiceType['invoice_type_name']?.toString() ?? '';
          
          if (id != null && name.isNotEmpty) {
            final intId = int.tryParse(id.toString());
            if (intId != null) {
              invoiceTypeMap[intId] = name;
            }
          }
        }
      }
      
      debugPrint('Created invoice type map with ${invoiceTypeMap.length} entries');
      return invoiceTypeMap;
    } catch (e) {
      debugPrint('Error creating invoice type map: $e');
      return {};
    }
  }

  Future<List<String>> getInvoiceTypeNameList() async {
    try {
      final invoiceTypeList = await getInvoiceTypeList();
      final nameList = <String>[];
      
      for (var invoiceType in invoiceTypeList) {
        if (invoiceType is Map<String, dynamic>) {
          final name = invoiceType['invoice_type_name']?.toString() ?? '';
          if (name.isNotEmpty) {
            nameList.add(name);
          }
        }
      }
      
      debugPrint('Created invoice type name list with ${nameList.length} entries');
      return nameList;
    } catch (e) {
      debugPrint('Error creating invoice type name list: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getInvoiceTypeById(int invoiceTypeId) async {
    try {
      final invoiceTypeList = await getInvoiceTypeList();
      
      for (var invoiceType in invoiceTypeList) {
        if (invoiceType is Map<String, dynamic>) {
          final id = invoiceType['invoice_type_id'];
          final intId = int.tryParse(id?.toString() ?? '');
          
          if (intId == invoiceTypeId) {
            return invoiceType;
          }
        }
      }
      
      debugPrint('Invoice type with ID $invoiceTypeId not found');
      return null;
    } catch (e) {
      debugPrint('Error finding invoice type by ID: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getInvoiceTypeByName(String invoiceTypeName) async {
    try {
      final invoiceTypeList = await getInvoiceTypeList();
      final searchName = invoiceTypeName.toLowerCase();
      
      for (var invoiceType in invoiceTypeList) {
        if (invoiceType is Map<String, dynamic>) {
          final name = invoiceType['invoice_type_name']?.toString() ?? '';
          if (name.toLowerCase().contains(searchName)) {
            return invoiceType;
          }
        }
      }
      
      debugPrint('Invoice type with name containing "$invoiceTypeName" not found');
      return null;
    } catch (e) {
      debugPrint('Error finding invoice type by name: $e');
      return null;
    }
  }

  Future<String?> getInvoiceTypeNameById(int invoiceTypeId) async {
    try {
      final invoiceType = await getInvoiceTypeById(invoiceTypeId);
      return invoiceType?['invoice_type_name']?.toString();
    } catch (e) {
      debugPrint('Error getting invoice type name by ID: $e');
      return null;
    }
  }

  Future<int?> getInvoiceTypeIdByName(String invoiceTypeName) async {
    try {
      final invoiceType = await getInvoiceTypeByName(invoiceTypeName);
      if (invoiceType != null) {
        final id = invoiceType['invoice_type_id'];
        return int.tryParse(id?.toString() ?? '');
      }
      return null;
    } catch (e) {
      debugPrint('Error getting invoice type ID by name: $e');
      return null;
    }
  }

  // Bank Name API Methods (existing)
  Future<Map<String, dynamic>> fetchBankNames() async {
    debugPrint('Fetching bank names...');
    
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

      debugPrint('Bank Name API URL: $_bankNameUrl');

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

      debugPrint('Bank Name API Headers: $headers');
      final response = await http.get(
        Uri.parse(_bankNameUrl),
        headers: headers,
      );

      debugPrint('Bank Name API Status Code: ${response.statusCode}');
      debugPrint('Bank Name API Response: ${response.body}');

    
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        if (decoded is Map<String, dynamic>) {
          final statusCode = decoded['status_code'] ?? response.statusCode;
          final message = decoded['message'] ?? 'Success';
          final data = decoded['data'] ?? [];
          final error = decoded['error'];
          final timestamp = decoded['timestamp'] ?? '';
          

          if (statusCode == 200 && data is List) {
            // debugPrint('Successfully fetched ${data.length} bank names');
            
            return {
              'success': true,
              'statusCode': statusCode,
              'message': message,
              'timestamp': timestamp,
              'data': data,
              'error': error,
            };
          } else {
            throw Exception(
              'API returned error: $message (Status: $statusCode)',
            );
          }
        } else {
          throw Exception(
            'Unexpected API response format. Expected a map but got: ${decoded.runtimeType}',
          );
        }
      } else {
        throw Exception(
          'Failed to load bank names (Status ${response.statusCode}). Body: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching bank names: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  // Refund Request List API Method (existing)
  Future<Map<String, dynamic>> fetchRefundRequestList({
    required String fromDate,
    required String toDate,
    required String userId,
    String? searchText,
    String? refundStatus,
    String? refundDashboardStatus,
  }) async {
    debugPrint('Fetching refund request list...');
    
    try {
      final prefs = await SharedPreferences.getInstance();

      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }
      
      final token = getPrefAsString('auth_token');
      final clinicId = getPrefAsString('clinicId');
      final currentUserId = getPrefAsString('userId');
      final branchId = getPrefAsString('branchId') ?? '1';

      if (token.isEmpty || clinicId.isEmpty || currentUserId.isEmpty) {
        throw Exception('⚠️ Missing session values. Please login again.');
      }

      debugPrint('Refund Request List API URL: $_refundRequestListUrl');

      // Prepare request body
      final requestBody = {
        'fromDate': fromDate,
        'toDate': toDate,
        'userId': userId,
        'searchText': searchText ?? '',
        'refundStatus': refundStatus,
        'refundDashboardStatus': refundDashboardStatus,
      };

      debugPrint('Refund Request List API Request Body: $requestBody');

      final headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': currentUserId,
        'ZONEID': 'Asia/Kolkata',
        'branchId': branchId,
        'Access-Control-Allow-Origin': '*',
      };

      debugPrint('Refund Request List API Headers: $headers');
      
      final response = await http.post(
        Uri.parse(_refundRequestListUrl),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      debugPrint('Refund Request List API Status Code: ${response.statusCode}');
      debugPrint('Refund Request List API Response: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        if (decoded is Map<String, dynamic>) {
          final statusCode = decoded['status_code'] ?? response.statusCode;
          final message = decoded['message'] ?? 'Success';
          final data = decoded['data'] ?? {};
          final error = decoded['error'];
          final timestamp = decoded['timestamp'] ?? '';

          if (statusCode == 200) {
            debugPrint('Successfully fetched refund request list');
            
            return {
              'success': true,
              'statusCode': statusCode,
              'message': message,
              'timestamp': timestamp,
              'data': data,
              'error': error,
            };
          } else {
            throw Exception(
              'API returned error: $message (Status: $statusCode)',
            );
          }
        } else {
          throw Exception(
            'Unexpected API response format. Expected a map but got: ${decoded.runtimeType}',
          );
        }
      } else {
        throw Exception(
          'Failed to load refund request list (Status ${response.statusCode}). Body: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching refund request list: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  // NEW: Refund Get Request List API Method (from your example)
  Future<Map<String, dynamic>> fetchRefundGetRequestList({
    required String fromDate,
    required String toDate,
    required String userId,
    String? searchText,
    String? refundStatus,
    String? refundDashboardStatus,
  }) async {
    debugPrint('Fetching refund get request list...');
    
    try {
      final prefs = await SharedPreferences.getInstance();

      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }
      
      final token = getPrefAsString('auth_token');
      final clinicId = getPrefAsString('clinicId');
      final currentUserId = getPrefAsString('userId');
      final branchId = getPrefAsString('branchId') ?? '1';

      if (token.isEmpty || clinicId.isEmpty || currentUserId.isEmpty) {
        throw Exception('⚠️ Missing session values. Please login again.');
      }

   
      debugPrint('Refund Get Request List API URL: $_refundListUrl');

      // Prepare request body - matching the payload from your example
      final requestBody = {
        'fromDate': fromDate,
        'toDate': toDate,
        'userId': userId,
        'searchText': searchText ?? '',
        'refundStatus': refundStatus,
        'refundDashboardStatus': refundDashboardStatus,
      };

      debugPrint('Refund Get Request List API Request Body: $requestBody');

      final headers = {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'Authorization': 'SmartCare $token',
        'clinicid': clinicId,
        'userid': currentUserId,
        'ZONEID': 'Asia/Kolkata',
        'branchId': branchId,
        'Access-Control-Allow-Origin': '*',
      };

      debugPrint('Refund Get Request List API Headers: $headers');
      
      final response = await http.post(
        Uri.parse(_refundListUrl),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      debugPrint('Refund Get Request List API Status Code: ${response.statusCode}');
      debugPrint('Refund Get Request List API Response: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        if (decoded is Map<String, dynamic>) {
          final statusCode = decoded['status_code'] ?? response.statusCode;
          final message = decoded['message'] ?? 'Success';
          final data = decoded['data'] ?? {};
          final error = decoded['error'];
          final timestamp = decoded['timestamp'] ?? '';

          if (statusCode == 200) {
            debugPrint('✅ Successfully fetched refund get request list');
            
            // Extract counts from the response
            if (data is Map<String, dynamic> && data.containsKey('list')) {
              final listData = data['list'] as Map<String, dynamic>;
              final unApprovedCount = listData['unApprovedCount'] ?? 0;
              final unPaidCount = listData['unPaidCount'] ?? 0;
              debugPrint('✅ Counts - Unapproved: $unApprovedCount, Unpaid: $unPaidCount');
            }
            
            return {
              'success': true,
              'statusCode': statusCode,
              'message': message,
              'timestamp': timestamp,
              'data': data,
              'error': error,
            };
          } else {
            throw Exception(
              'API returned error: $message (Status: $statusCode)',
            );
          }
        } else {
          throw Exception(
            'Unexpected API response format. Expected a map but got: ${decoded.runtimeType}',
          );
        }
      } else {
        throw Exception(
          'Failed to load refund get request list (Status ${response.statusCode}). Body: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching refund get request list: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  // Convenience method for refund get request list
  Future<Map<String, dynamic>> getRefundGetRequestList({
    String? fromDate,
    String? toDate,
    String? userId,
    String? searchText,
    String? refundStatus,
    String? refundDashboardStatus,
  }) async {
    try {
      // Get current date for default values
      final now = DateTime.now();
      final formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      final prefs = await SharedPreferences.getInstance();
      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }
      
      final currentUserId = getPrefAsString('userId');

      final response = await fetchRefundGetRequestList(
        fromDate: fromDate ?? formattedDate,
        toDate: toDate ?? formattedDate,
        userId: userId ?? currentUserId,
        searchText: searchText,
        refundStatus: refundStatus,
        refundDashboardStatus: refundDashboardStatus,
      );
      
      return response;
    } catch (e) {
      debugPrint('Exception in getRefundGetRequestList: $e');
      rethrow;
    }
  }

  // Get refund counts from get-request-list API
  Future<Map<String, int>> getRefundCountsFromGetRequestList({
    String? fromDate,
    String? toDate,
    String? userId,
  }) async {
    try {
      final response = await getRefundGetRequestList(
        fromDate: fromDate,
        toDate: toDate,
        userId: userId,
      );
      
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        final list = data['list'] as Map<String, dynamic>;
        
        final unApprovedCount = (list['unApprovedCount'] as int?) ?? 0;
        final unPaidCount = (list['unPaidCount'] as int?) ?? 0;
        
        return {
          'unApprovedCount': unApprovedCount,
          'unPaidCount': unPaidCount,
        };
      } else {
        return {'unApprovedCount': 0, 'unPaidCount': 0};
      }
    } catch (e) {
      debugPrint('Error getting refund counts from get-request-list: $e');
      return {'unApprovedCount': 0, 'unPaidCount': 0};
    }
  }

  // Get refund data list from get-request-list API
  Future<List<dynamic>> getRefundDataFromGetRequestList({
    String? fromDate,
    String? toDate,
    String? userId,
    String? searchText,
    String? refundStatus,
    String? refundDashboardStatus,
  }) async {
    try {
      final response = await getRefundGetRequestList(
        fromDate: fromDate,
        toDate: toDate,
        userId: userId,
        searchText: searchText,
        refundStatus: refundStatus,
        refundDashboardStatus: refundDashboardStatus,
      );
      
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        final list = data['list'] as Map<String, dynamic>;
        final refundDataList = list['refundDataList'] as List<dynamic>? ?? [];
        
        return refundDataList;
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Error getting refund data from get-request-list: $e');
      return [];
    }
  }

  // Convenience method to get refund request list with default parameters (existing)
  Future<Map<String, dynamic>> getRefundRequestList({
    String? fromDate,
    String? toDate,
    String? userId,
    String? searchText,
    String? refundStatus,
    String? refundDashboardStatus,
  }) async {
    try {
      // Get current date for default values
      final now = DateTime.now();
      final formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      final prefs = await SharedPreferences.getInstance();
      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }
      
      final currentUserId = getPrefAsString('userId');

      final response = await fetchRefundRequestList(
        fromDate: fromDate ?? formattedDate,
        toDate: toDate ?? formattedDate,
        userId: userId ?? currentUserId,
        searchText: searchText,
        refundStatus: refundStatus,
        refundDashboardStatus: refundDashboardStatus,
      );
      
      return response;
    } catch (e) {
      debugPrint('Exception in getRefundRequestList: $e');
      rethrow;
    }
  }

  // Get refund counts (unApprovedCount and unPaidCount) (existing)
  Future<Map<String, int>> getRefundCounts({
    String? fromDate,
    String? toDate,
    String? userId,
  }) async {
    try {
      final response = await getRefundRequestList(
        fromDate: fromDate,
        toDate: toDate,
        userId: userId,
      );
      
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        final list = data['list'] as Map<String, dynamic>;
        
        final unApprovedCount = list['unApprovedCount'] as int? ?? 0;
        final unPaidCount = list['unPaidCount'] as int? ?? 0;
        
        return {
          'unApprovedCount': unApprovedCount,
          'unPaidCount': unPaidCount,
        };
      } else {
        return {'unApprovedCount': 0, 'unPaidCount': 0};
      }
    } catch (e) {
      debugPrint('Error getting refund counts: $e');
      return {'unApprovedCount': 0, 'unPaidCount': 0};
    }
  }

  // Get refund data list (existing)
  Future<List<dynamic>> getRefundDataList({
    String? fromDate,
    String? toDate,
    String? userId,
    String? searchText,
    String? refundStatus,
    String? refundDashboardStatus,
  }) async {
    try {
      final response = await getRefundRequestList(
        fromDate: fromDate,
        toDate: toDate,
        userId: userId,
        searchText: searchText,
        refundStatus: refundStatus,
        refundDashboardStatus: refundDashboardStatus,
      );
      
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        final list = data['list'] as Map<String, dynamic>;
        final refundDataList = list['refundDataList'] as List<dynamic>? ?? [];
        
        return refundDataList;
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Error getting refund data list: $e');
      return [];
    }
  }

  // Existing Bank Name Methods (existing)
  Future<List<dynamic>> getBankList() async {
    try {
      final response = await fetchBankNames();
      
      if (response['success'] == true && response['data'] is List) {
        return response['data'] as List;
      } else {
        debugPrint('Failed to get bank list: ${response['message']}');
        return [];
      }
    } catch (e) {
      debugPrint('Exception in getBankList: $e');
      return [];
    }
  }

  Future<List<dynamic>> getLocationList() async{
    try {
      final response = await fetchLocationList();
      
      if (response['success'] == true && response['data'] is List) {
        return response['data'] as List;
      } else {
        debugPrint('Failed to get location list: ${response['message']}');
        return [];
      }
    } catch (e) {
      debugPrint('Exception in getLocationList: $e');
      return [];
    }
  }

  Future<Map<int, String>> getLocationMap() async {
    try {
      final locationList = await getLocationList();
      final locationMap = <int, String>{};
      
      for (var location in locationList) {
        if (location is Map<String, dynamic>) {
          final id = location['id'];
          final name = location['name']?.toString() ?? '';
          
          if (id != null && name.isNotEmpty) {
            final intId = int.tryParse(id.toString());
            if (intId != null) {
              locationMap[intId] = name;
            }
          }
        }
      }
      
      debugPrint('Created location map with ${locationMap.length} entries');
      return locationMap;
    } catch (e) {
      debugPrint('Error creating location map: $e');
      return {};
    }
  }

  Future<List<String>> getLocationNameList() async {
    try {
      final locationList = await getLocationList();
      final nameList = <String>[];
      
      for (var location in locationList) {
        if (location is Map<String, dynamic>) {
          final name = location['name']?.toString() ?? '';
          if (name.isNotEmpty) {
            nameList.add(name);
          }
        }
      }
      
      debugPrint('Created location name list with ${nameList.length} entries');
      return nameList;
    } catch (e) {
      debugPrint('Error creating location name list: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getLocationById(int locationId) async {
    try {
      final locationList = await getLocationList();
      
      for (var location in locationList) {
        if (location is Map<String, dynamic>) {
          final id = location['id'];
          final intId = int.tryParse(id?.toString() ?? '');
          
          if (intId == locationId) {
            return location;
          }
        }
      }
      
      debugPrint('Location with ID $locationId not found');
      return null;
    } catch (e) {
      debugPrint('Error finding location by ID: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getLocationByName(String locationName) async {
    try {
      final locationList = await getLocationList();
      final searchName = locationName.toLowerCase();
      
      for (var location in locationList) {
        if (location is Map<String, dynamic>) {
          final name = location['name']?.toString() ?? '';
          if (name.toLowerCase().contains(searchName)) {
            return location;
          }
        }
      }
      
      debugPrint('Location with name containing "$locationName" not found');
      return null;
    } catch (e) {
      debugPrint('Error finding location by name: $e');
      return null;
    }
  }

  Future<Map<int, String>> getLocationAbbreviationMap() async {
    try {
      final locationList = await getLocationList();
      final abbreviationMap = <int, String>{};
      
      for (var location in locationList) {
        if (location is Map<String, dynamic>) {
          final id = location['id'];
          final abbreviation = location['abrivation']?.toString() ?? '';
          
          if (id != null && abbreviation.isNotEmpty) {
            final intId = int.tryParse(id.toString());
            if (intId != null) {
              abbreviationMap[intId] = abbreviation;
            }
          }
        }
      }
      
      debugPrint('Created location abbreviation map with ${abbreviationMap.length} entries');
      return abbreviationMap;
    } catch (e) {
      debugPrint('Error creating location abbreviation map: $e');
      return {};
    }
  }

  Future<Map<int, String>> getBankNameMap() async {
    try {
      final bankList = await getBankList();
      final bankMap = <int, String>{};
      
      for (var bank in bankList) {
        if (bank is Map<String, dynamic>) {
          final id = bank['id'];
          final name = bank['name']?.toString() ?? '';
          
          if (id != null && name.isNotEmpty) {
            final intId = int.tryParse(id.toString());
            if (intId != null) {
              bankMap[intId] = name;
            }
          }
        }
      }
      
      debugPrint('Created bank map with ${bankMap.length} entries');
      return bankMap;
    } catch (e) {
      debugPrint('Error creating bank name map: $e');
      return {};
    }
  }

  Future<List<String>> getBankNameList() async {
    try {
      final bankList = await getBankList();
      final nameList = <String>[];
      
      for (var bank in bankList) {
        if (bank is Map<String, dynamic>) {
          final name = bank['name']?.toString() ?? '';
          if (name.isNotEmpty) {
            nameList.add(name);
          }
        }
      }
      
      debugPrint('Created bank name list with ${nameList.length} entries');
      return nameList;
    } catch (e) {
      debugPrint('Error creating bank name list: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getBankById(int bankId) async {
    try {
      final bankList = await getBankList();
      
      for (var bank in bankList) {
        if (bank is Map<String, dynamic>) {
          final id = bank['id'];
          final intId = int.tryParse(id?.toString() ?? '');
          
          if (intId == bankId) {
            return bank;
          }
        }
      }
      
      debugPrint('Bank with ID $bankId not found');
      return null;
    } catch (e) {
      debugPrint('Error finding bank by ID: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getBankByName(String bankName) async {
    try {
      final bankList = await getBankList();
      final searchName = bankName.toLowerCase();
      
      for (var bank in bankList) {
        if (bank is Map<String, dynamic>) {
          final name = bank['name']?.toString() ?? '';
          if (name.toLowerCase().contains(searchName)) {
            return bank;
          }
        }
      }
      
      debugPrint('Bank with name containing "$bankName" not found');
      return null;
    } catch (e) {
      debugPrint('Error finding bank by name: $e');
      return null;
    }
  }

  // Location API Method (existing)
  Future<Map<String, dynamic>> fetchLocationList() async {
    debugPrint('Fetching location list...');
    
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

      debugPrint('Location API URL: $_locationUrl');

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

      debugPrint('Location API Headers: $headers');
      final response = await http.get(
        Uri.parse(_locationUrl),
        headers: headers,
      );

      debugPrint('Location API Status Code: ${response.statusCode}');
      debugPrint('Location API Response: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        // Handle different response formats
        if (decoded is List) {
          // API returns a list directly (like your location API)
          debugPrint('✅ Location API returned a List directly');
          
          return {
            'success': true,
            'statusCode': 200,
            'message': 'Successfully fetched location list',
            'timestamp': DateTime.now().toIso8601String(),
            'data': decoded,
            'error': null,
          };
        } else if (decoded is Map<String, dynamic>) {
          // API returns a map with standard format (like your bank API)
          final statusCode = decoded['status_code'] ?? response.statusCode;
          final message = decoded['message'] ?? 'Success';
          final data = decoded['data'] ?? [];
          final error = decoded['error'];
          final timestamp = decoded['timestamp'] ?? '';

          if (statusCode == 200 && data is List) {
            debugPrint('✅ Location API returned a Map with standard format');
            
            return {
              'success': true,
              'statusCode': statusCode,
              'message': message,
              'timestamp': timestamp,
              'data': data,
              'error': error,
            };
          } else {
            throw Exception(
              'API returned error: $message (Status: $statusCode)',
            );
          }
        } else {
          throw Exception(
            'Unexpected API response format. Expected a List or Map but got: ${decoded.runtimeType}',
          );
        }
      } else {
        throw Exception(
          'Failed to load locations (Status ${response.statusCode}). Body: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching locations: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  // Update the testConnection method to include invoice types
  Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await fetchBankNames();
      final locationResponse = await fetchLocationList();
      final invoiceTypeResponse = await fetchInvoiceTypeList();
      final refundGetRequestResponse = await getRefundGetRequestList();
      
      return {
        'success': response['success'] == true,
        'message': response['message'] ?? 'Connection test completed',
        'bankDataCount': response['data'] is List ? (response['data'] as List).length : 0,
        'locationDataCount': locationResponse['data'] is List ? (locationResponse['data'] as List).length : 0,
        'invoiceTypeDataCount': invoiceTypeResponse['data'] is List ? (invoiceTypeResponse['data'] as List).length : 0,
        'refundGetRequestSuccess': refundGetRequestResponse['success'] == true,
        'dataCount': response['data'] is List ? (response['data'] as List).length : 0,
        'timestamp': response['timestamp'] ?? '',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection test failed: $e',
        'bankDataCount': 0,
        'locationDataCount': 0,
        'invoiceTypeDataCount': 0,
        'refundGetRequestSuccess': false,
      };
    }
  }

  // Existing methods
  Future<bool> validateSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }

      final token = getPrefAsString('auth_token');
      final clinicId = getPrefAsString('clinicId');
      final userId = getPrefAsString('userId');

      return token.isNotEmpty && clinicId.isNotEmpty && userId.isNotEmpty;
    } catch (e) {
      debugPrint('Error validating session: $e');
      return false;
    }
  }

  Future<Map<String, String>> getHeaders() async {
    final prefs = await SharedPreferences.getInstance();

    String getPrefAsString(String key) {
      final val = prefs.get(key);
      return val?.toString() ?? '';
    }

    final token = getPrefAsString('auth_token');
    final clinicId = getPrefAsString('clinicId');
    final userId = getPrefAsString('userId');
    final branchId = getPrefAsString('branchId') ?? '1';

    return {
      'Content-Type': 'application/json',
      'Accept': '*/*',
      'Authorization': 'SmartCare $token',
      'clinicid': clinicId,
      'userid': userId,
      'ZONEID': 'Asia/Kolkata',
      'branchId': branchId,
      'Access-Control-Allow-Origin': '*',
    };
  }
}