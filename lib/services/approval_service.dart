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
  static const String _discountDashboardUrl = "https://test.smartcarehis.com:8443/billing/discount/dashboard";
  static const String _discountApproveUrl = "https://test.smartcarehis.com:8443/billing/discount/approve";
  static const String _refundCancelUrl = "https://test.smartcarehis.com:8443/billing/refund/request/cancle";

  Future<Map<String, dynamic>> cancelRefundRequest({
    required int id,
    required String reason,
    String? userId,
  }) async {
    debugPrint('🔄 Cancelling refund request with ID: $id...');
    
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

      debugPrint('Refund Cancel API URL: $_refundCancelUrl');

      // Prepare request body as per the provided payload
      final requestBody = {
        'id': id,
        'reason': reason,
        'userid': userId ?? currentUserId,
      };

      debugPrint('Refund Cancel API Request Body: $requestBody');

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

      debugPrint('Refund Cancel API Headers: $headers');
      
      final response = await http.post(
        Uri.parse(_refundCancelUrl),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      debugPrint('Refund Cancel API Status Code: ${response.statusCode}');
      debugPrint('Refund Cancel API Response: ${response.body}');

      // Handle successful responses (200, 201, 202)
      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
        try {
          final decoded = jsonDecode(response.body);
          
          if (decoded is Map<String, dynamic>) {
            final statusCode = decoded['status_code'] ?? response.statusCode;
            final message = decoded['message'] ?? 'Refund request cancelled successfully';
            final data = decoded['data'] ?? {};
            final error = decoded['error'];
            final timestamp = decoded['timestamp'] ?? '';

            if (statusCode == 200 || statusCode == 201 || statusCode == 202) {
              debugPrint('✅ Successfully cancelled refund request with ID: $id');
              
              return {
                'success': true,
                'statusCode': statusCode,
                'message': message,
                'timestamp': timestamp,
                'data': data,
                'error': error,
              };
            }
          }
          
          // If we can't parse but status is 2xx, consider it success
          return {
            'success': true,
            'statusCode': response.statusCode,
            'message': 'Refund request cancelled successfully',
            'timestamp': DateTime.now().toIso8601String(),
            'data': response.body,
            'error': null,
          };
        } catch (e) {
          // If JSON parsing fails but status is success, still return success
          debugPrint('Warning: Could not parse response JSON but status is ${response.statusCode}');
          return {
            'success': true,
            'statusCode': response.statusCode,
            'message': 'Refund request cancelled successfully',
            'timestamp': DateTime.now().toIso8601String(),
            'data': response.body,
            'error': null,
          };
        }
      } else if (response.statusCode == 400) {
        // Handle 400 Bad Request - parse error message if available
        try {
          final decoded = jsonDecode(response.body);
          String errorMessage = 'Bad Request';
          if (decoded is Map<String, dynamic>) {
            errorMessage = decoded['message'] ?? decoded['error'] ?? 'Invalid request parameters';
          }
          throw Exception('⚠️ $errorMessage');
        } catch (e) {
          throw Exception('⚠️ Bad Request: Failed to cancel refund request');
        }
      } else {
        throw Exception(
          'Failed to cancel refund request (Status ${response.statusCode}). Body: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error cancelling refund request: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  // Convenience method to cancel refund from a refund object
  Future<Map<String, dynamic>> cancelRefundFromObject({
    required Map<String, dynamic> refundObject,
    required String reason,
    String? userId,
  }) async {
    try {
      // Extract required fields from the refund object
      final id = refundObject['id'] as int? ?? 0;
      
      if (id == 0) {
        throw Exception('Invalid refund object: missing or invalid ID');
      }

      final response = await cancelRefundRequest(
        id: id,
        reason: reason,
        userId: userId,
      );
      
      return response;
    } catch (e) {
      debugPrint('Exception in cancelRefundFromObject: $e');
      rethrow;
    }
  }

  // Convenience method for batch cancelling multiple refunds
  Future<List<Map<String, dynamic>>> cancelMultipleRefunds({
    required List<Map<String, dynamic>> refundList,
    required String reason,
    String? userId,
  }) async {
    final results = <Map<String, dynamic>>[];
    
    for (var refund in refundList) {
      try {
        final result = await cancelRefundFromObject(
          refundObject: refund,
          reason: reason,
          userId: userId,
        );
        results.add({
          'id': refund['id'],
          'success': true,
          'response': result,
        });
      } catch (e) {
        results.add({
          'id': refund['id'],
          'success': false,
          'error': e.toString(),
        });
      }
    }
    
    debugPrint('✅ Cancelled ${results.where((r) => r['success'] == true).length} out of ${refundList.length} refund requests');
    return results;
  }

  // Get cancelled refund data list from get-request-list API
  Future<List<dynamic>> getCancelledRefundDataList({
    String? fromDate,
    String? toDate,
    String? userId,
    String? searchText,
  }) async {
    try {
      // Use refundStatus '3' for cancelled requests (assuming 3 is the status code for cancelled)
      final response = await getRefundGetRequestList(
        fromDate: fromDate,
        toDate: toDate,
        userId: userId,
        searchText: searchText,
        refundStatus: '3', // Assuming status 3 represents cancelled
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
      debugPrint('Error getting cancelled refund data list: $e');
      return [];
    }
  }

  // Your existing methods remain unchanged below...
  Future<Map<String, dynamic>> approveAllRefunds({
    required List<Map<String, dynamic>> refundList,
    required String approvedNotes,
  }) async {
    // ... existing code ...
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

  // NEW: Batch Discount Approval API Method with PUT method
 // UPDATED: Discount Approval API Method with better error handling
// UPDATED: Discount Approval API Method with better error handling
// In approval_service.dart - Replace the approveDiscount method

Future<Map<String, dynamic>> approveDiscount({
  required int id,
  required int invoiceid,
  required int patient_id,
  required int practitionerid,
  required String requested_userid,
  String? abrivationId,
  required String approve_note,
  required String approver_userid,
  int? balanceAmount,
  int? branch_id,
  required int charge_discount_amount,
  String? delete_date_time,
  int? deleted,
  String? deletedby,
  String? deleteremark,
  required String discount,
  int? discountAmt,
  required bool discountSms,
  String? discount_given_userid,
  required int discount_type,
  required int discountstatus,
  required int invoice_amount,
  required int invoice_amount_after_discount,
  String? invoice_type,
  String? patientname,
  String? practitionername,
  required String request_note,
  String? request_type,
  required String requested_date,
  String? type,
}) async {
  debugPrint('🔄 Approving discount with ID: $id...');
  
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

    debugPrint('Discount Approve API URL: $_discountApproveUrl');

    final now = DateTime.now();
    final approvedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    // Ensure discount is properly formatted as a string
    String formattedDiscount = discount;
    if (discount.contains('(') || discount.contains(',')) {
      // Keep it as is - it's already a complex string
      formattedDiscount = discount;
    }

    final requestBody = {
      'id': id,
      'invoiceid': invoiceid,
      'patient_id': patient_id,
      'practitionerid': practitionerid,
      'requested_userid': requested_userid,
      'abrivationId': abrivationId,
      'approve_note': approve_note,
      'approved_date': approvedDate,
      'approver_userid': approver_userid,
      'balanceAmount': balanceAmount ?? 0,
      'branch_id': branch_id ?? 0,
      'charge_discount_amount': charge_discount_amount,
      'delete_date_time': delete_date_time ?? '',
      'deleted': deleted ?? 0,
      'deletedby': deletedby ?? '',
      'deleteremark': deleteremark ?? '',
      'discount': formattedDiscount, // Use formatted discount
      'discountAmt': discountAmt ?? 0,
      'discountSms': discountSms,
      'discount_given_userid': discount_given_userid,
      'discount_type': discount_type,
      'discountstatus': discountstatus, // Keep as passed (0 from UI)
      'invoice_amount': invoice_amount,
      'invoice_amount_after_discount': invoice_amount_after_discount,
      'invoice_type': invoice_type ?? '',
      'patientname': patientname,
      'practitionername': practitionername ?? '',
      'request_note': request_note,
      'request_type': request_type ?? '',
      'requested_date': requested_date,
      'type': type ?? '',
    };

    debugPrint('Discount Approve API Request Body: $requestBody');

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

    debugPrint('Discount Approve API Headers: $headers');
    
    final response = await http.put(
      Uri.parse(_discountApproveUrl),
      headers: headers,
      body: jsonEncode(requestBody),
    );

    debugPrint('Discount Approve API Status Code: ${response.statusCode}');
    debugPrint('Discount Approve API Response: ${response.body}');

    // Handle 200, 201, 202 status codes as success
    if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
      try {
        final decoded = jsonDecode(response.body);
        
        if (decoded is Map<String, dynamic>) {
          final statusCode = decoded['status_code'] ?? response.statusCode;
          final message = decoded['message'] ?? 'Success';
          final data = decoded['data'] ?? {};
          final error = decoded['error'];

          if (statusCode == 200 || statusCode == 201 || statusCode == 202) {
            debugPrint('✅ Successfully approved discount with ID: $id');
            
            return {
              'success': true,
              'statusCode': statusCode,
              'message': message,
              'timestamp': decoded['timestamp'] ?? '',
              'data': data,
              'error': error,
            };
          }
        }
        
        // If we can't parse but status is 2xx, consider it success
        return {
          'success': true,
          'statusCode': response.statusCode,
          'message': 'Discount approved successfully',
          'timestamp': DateTime.now().toIso8601String(),
          'data': response.body,
          'error': null,
        };
      } catch (e) {
        // If JSON parsing fails but status is success, still return success
        debugPrint('Warning: Could not parse response JSON but status is ${response.statusCode}');
        return {
          'success': true,
          'statusCode': response.statusCode,
          'message': 'Discount approved successfully',
          'timestamp': DateTime.now().toIso8601String(),
          'data': response.body,
          'error': null,
        };
      }
    } else {
      throw Exception(
        'Failed to approve discount (Status ${response.statusCode}). Body: ${response.body}',
      );
    }
  } catch (e, stackTrace) {
    debugPrint('Error approving discount: $e');
    debugPrint('StackTrace: $stackTrace');
    rethrow;
  }
}

  // Convenience method for approving discount with minimal parameters
  Future<Map<String, dynamic>> approveDiscountSimple({
    required int id,
    required int invoiceid,
    required int patient_id,
    required int practitionerid,
    required String requested_userid,
    required String approve_note,
    required String approver_userid,
    required int charge_discount_amount,
    required String discount,
    required bool discountSms,
    required int discount_type,
    required int discountstatus,
    required int invoice_amount,
    required int invoice_amount_after_discount,
    required String request_note,
    required String requested_date,
  }) async {
    try {
      final response = await approveDiscount(
        id: id,
        invoiceid: invoiceid,
        patient_id: patient_id,
        practitionerid: practitionerid,
        requested_userid: requested_userid,
        approve_note: approve_note,
        approver_userid: approver_userid,
        charge_discount_amount: charge_discount_amount,
        discount: discount,
        discountSms: discountSms,
        discount_type: discount_type,
        discountstatus: discountstatus,
        invoice_amount: invoice_amount,
        invoice_amount_after_discount: invoice_amount_after_discount,
        request_note: request_note,
        requested_date: requested_date,
        // Set default values for optional parameters
        balanceAmount: 0,
        branch_id: 0,
        delete_date_time: '',
        deleted: 0,
        deletedby: '',
        deleteremark: '',
        discountAmt: 0,
        discount_given_userid: null,
        invoice_type: '',
        patientname: null,
        practitionername: '',
        request_type: '',
        type: '',
        abrivationId: null,
      );
      
      return response;
    } catch (e) {
      debugPrint('Exception in approveDiscountSimple: $e');
      rethrow;
    }
  }

  // Convenience method to approve discount from a discount object
  Future<Map<String, dynamic>> approveDiscountFromObject({
    required Map<String, dynamic> discountObject,
    required String approve_note,
    required String approver_userid,
  }) async {
    try {
      // Extract required fields from the discount object
      final id = discountObject['id'] as int? ?? 0;
      final invoiceid = discountObject['invoiceid'] as int? ?? 0;
      final patient_id = discountObject['patient_id'] as int? ?? 0;
      final practitionerid = discountObject['practitionerid'] as int? ?? 0;
      final requested_userid = discountObject['requested_userid']?.toString() ?? '';
      final charge_discount_amount = discountObject['charge_discount_amount'] as int? ?? 0;
      final discount = discountObject['discount']?.toString() ?? '0';
      final discountSms = discountObject['discountSms'] as bool? ?? false;
      final discount_type = discountObject['discount_type'] as int? ?? 0;
      final discountstatus = 2;
      final invoice_amount = discountObject['invoice_amount'] as int? ?? 0;
      final invoice_amount_after_discount = 0;
      final request_note = discountObject['request_note']?.toString() ?? '';
      final requested_date = discountObject['requested_date']?.toString() ?? '';

      final response = await approveDiscount(
        id: id,
        invoiceid: invoiceid,
        patient_id: patient_id,
        practitionerid: practitionerid,
        requested_userid: requested_userid,
        approve_note: approve_note,
        approver_userid: approver_userid,
        charge_discount_amount: charge_discount_amount,
        discount: discount,
        discountSms: discountSms,
        discount_type: discount_type,
        discountstatus: discountstatus,
        invoice_amount: invoice_amount,
        invoice_amount_after_discount: invoice_amount_after_discount,
        request_note: request_note,
        requested_date: requested_date,
        balanceAmount: discountObject['balanceAmount'] as int? ?? 0,
        branch_id: discountObject['branch_id'] as int? ?? 0,
        delete_date_time: discountObject['delete_date_time']?.toString() ?? '',
        deleted: discountObject['deleted'] as int? ?? 0,
        deletedby: discountObject['deletedby']?.toString() ?? '',
        deleteremark: discountObject['deleteremark']?.toString() ?? '',
        discountAmt: discountObject['discountAmt'] as int? ?? 0,
        discount_given_userid: discountObject['discount_given_userid']?.toString(),
        invoice_type: discountObject['invoice_type']?.toString() ?? '',
        patientname: discountObject['patientname']?.toString(),
        practitionername: discountObject['practitionername']?.toString() ?? '',
        request_type: discountObject['request_type']?.toString() ?? '',
        type: discountObject['type']?.toString() ?? '',
        abrivationId: discountObject['abrivationId']?.toString(),
      );
      
      return response;
    } catch (e) {
      debugPrint('Exception in approveDiscountFromObject: $e');
      rethrow;
    }
  }

  // Convenience method for batch approving multiple discounts
  Future<List<Map<String, dynamic>>> approveMultipleDiscounts({
    required List<Map<String, dynamic>> discountList,
    required String approve_note,
    required String approver_userid,
  }) async {
    final results = <Map<String, dynamic>>[];
    
    for (var discount in discountList) {
      try {
        final result = await approveDiscountFromObject(
          discountObject: discount,
          approve_note: approve_note,
          approver_userid: approver_userid,
        );
        results.add({
          'id': discount['id'],
          'success': true,
          'response': result,
        });
      } catch (e) {
        results.add({
          'id': discount['id'],
          'success': false,
          'error': e.toString(),
        });
      }
    }
    
    debugPrint('✅ Approved ${results.where((r) => r['success'] == true).length} out of ${discountList.length} discounts');
    return results;
  }

  // NEW: Discount Dashboard API Method
  Future<Map<String, dynamic>> fetchDiscountDashboard({
    required String fromDate,
    required String toDate,
    required String userid,
    required String userNumericId,
    String? searchText,
    String? status,
  }) async {
    debugPrint('🔄 Fetching discount dashboard data...');
    debugPrint('API URL Discount: $_discountDashboardUrl');
    debugPrint('Discount statuscode: $status');
    debugPrint(' Discount body: {fromDate: $fromDate, toDate: $toDate, userid: $userid, userNumericId: $userNumericId, searchText: $searchText, status: $status}');
    
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

      debugPrint('Discount Dashboard API URL: $_discountDashboardUrl');

      // Prepare request body matching the payload from example
      final requestBody = {
        'fromDate': fromDate,
        'toDate': toDate,
        'userid': userid,
        'userNumericId': userNumericId,
        'searchText': searchText ?? '',
        'status': status,
      };

      debugPrint('Discount Dashboard API Request Body: $requestBody');

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

      debugPrint('Discount Dashboard API Headers: $headers');
      
      final response = await http.post(
        Uri.parse(_discountDashboardUrl),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      debugPrint('Discount Dashboard API Status Code: ${response.statusCode}');
      debugPrint('Discount Dashboard API Response: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        if (decoded is Map<String, dynamic>) {
          final statusCode = decoded['status_code'] ?? response.statusCode;
          final message = decoded['message'] ?? 'Success';
          final data = decoded['data'] ?? {};
          final error = decoded['error'];
          final timestamp = decoded['timestamp'] ?? '';

          if (statusCode == 200) {
            debugPrint('✅ Successfully fetched discount dashboard data');
            
            // Extract counts from the response
            if (data is Map<String, dynamic> && data.containsKey('list')) {
              final listData = data['list'] as Map<String, dynamic>;
              final nonApplied = listData['nonApplied'] ?? 0;
              final nonApproved = listData['nonApproved'] ?? 0;
              debugPrint('✅ Counts - Non Applied: $nonApplied, Non Approved: $nonApproved');
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
          'Failed to load discount dashboard data (Status ${response.statusCode}). Body: ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching discount dashboard data: $e');
      debugPrint('StackTrace: $stackTrace');
      rethrow;
    }
  }

  // Convenience method for discount dashboard with default parameters
  Future<Map<String, dynamic>> getDiscountDashboardData({
    String? fromDate,
    String? toDate,
    String? userid,
    String? userNumericId,
    String? searchText,
    String? status,
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
      final currentUserName = getPrefAsString('userName') ?? currentUserId;

      final response = await fetchDiscountDashboard(
        fromDate: fromDate ?? formattedDate,
        toDate: toDate ?? formattedDate,
        userid: userid ?? currentUserName,
        userNumericId: userNumericId ?? currentUserId,
        searchText: searchText,
        status: status,
      );
      
      return response;
    } catch (e) {
      debugPrint('Exception in getDiscountDashboardData: $e');
      rethrow;
    }
  }

  // Get discount counts from dashboard API
  Future<Map<String, int>> getDiscountCountsFromDashboard({
    String? fromDate,
    String? toDate,
    String? userid,
    String? userNumericId,
  }) async {
    try {
      final response = await getDiscountDashboardData(
        fromDate: fromDate,
        toDate: toDate,
        userid: userid,
        userNumericId: userNumericId,
      );
      
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        final list = data['list'] as Map<String, dynamic>;
        
        final nonApplied = (list['nonApplied'] as int?) ?? 0;
        final nonApproved = (list['nonApproved'] as int?) ?? 0;
        
        return {
          'nonApplied': nonApplied,
          'nonApproved': nonApproved,
        };
      } else {
        return {'nonApplied': 0, 'nonApproved': 0};
      }
    } catch (e) {
      debugPrint('Error getting discount counts from dashboard: $e');
      return {'nonApplied': 0, 'nonApproved': 0};
    }
  }

  // Get discount data list from dashboard API
  Future<List<dynamic>> getDiscountDataListFromDashboard({
    String? fromDate,
    String? toDate,
    String? userid,
    String? userNumericId,
    String? searchText,
    String? status,
  }) async {
    try {
      final response = await getDiscountDashboardData(
        fromDate: fromDate,
        toDate: toDate,
        userid: userid,
        userNumericId: userNumericId,
        searchText: searchText,
        status: status,
      );
      
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        final list = data['list'] as Map<String, dynamic>;
        
        // Check for discountDashboardList first, then fallback to discountList
        final discountDataList = list['discountDashboardList'] as List<dynamic>? ?? 
                                 list['discountList'] as List<dynamic>? ?? [];
        
        return discountDataList;
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Error getting discount data list from dashboard: $e');
      return [];
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
 // In approval_service.dart - Update the fetchRefundGetRequestList method

// In approval_service.dart - Replace the fetchRefundGetRequestList method

Future<Map<String, dynamic>> fetchRefundGetRequestList({
  required String fromDate,
  required String toDate,
  required String userId,
  String? searchText,
  String? refundStatus,      // For filtering specific status
  String? refundDashboardStatus,  // For dashboard counts view
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

    // IMPORTANT: For dashboard view, refundStatus should be null
    // and refundDashboardStatus should be used for filtering
    final requestBody = {
      'fromDate': fromDate,
      'toDate': toDate,
      'userId': userId,
      'searchText': searchText ?? '',
    };
    
    // Only add status fields if they are not null
    if (refundStatus != null && refundStatus.isNotEmpty) {
      requestBody['refundStatus'] = refundStatus;
    }
    
    if (refundDashboardStatus != null && refundDashboardStatus.isNotEmpty) {
      requestBody['refundDashboardStatus'] = refundDashboardStatus;
    }

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
    } else if (response.statusCode == 400) {
      // Handle 400 error gracefully
      debugPrint('⚠️ API returned 400 Bad Request. Trying without status filters...');
      throw Exception('Bad Request - The status parameter might be invalid');
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
 // In approval_service.dart - Update the getRefundGetRequestList method

Future<Map<String, dynamic>> getRefundGetRequestList({
  String? fromDate,
  String? toDate,
  String? userId,
  String? searchText,
  String? refundStatus,           // For filtering specific status
  String? refundDashboardStatus,  // For dashboard tabs (Un-Approved Request, Un-Paid Approval, etc.)
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

    // IMPORTANT: For dashboard view, we want refundStatus to be null
    // and refundDashboardStatus to be used for filtering
    final response = await fetchRefundGetRequestList(
      fromDate: fromDate ?? formattedDate,
      toDate: toDate ?? formattedDate,
      userId: userId ?? currentUserId,
      searchText: searchText,
      refundStatus: null,  // Always null for dashboard to get counts
      refundDashboardStatus: refundDashboardStatus,  // Pass the dashboard status for filtering
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

  // Update the testConnection method to include refund cancel
  Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await fetchBankNames();
      final locationResponse = await fetchLocationList();
      final invoiceTypeResponse = await fetchInvoiceTypeList();
      final refundGetRequestResponse = await getRefundGetRequestList();
      
      // Test discount dashboard with minimal parameters
      final discountDashboardResponse = await getDiscountDashboardData();
      
      // Test refund cancel endpoint with a dummy ID (won't actually cancel)
      bool refundCancelEndpointReachable = true;
      try {
        // Just test the endpoint without actually cancelling
        final headers = await getHeaders();
        final testResponse = await http.post(
          Uri.parse(_refundCancelUrl),
          headers: headers,
          body: jsonEncode({'id': 0, 'reason': 'test', 'userid': 'test'}),
        );
        refundCancelEndpointReachable = testResponse.statusCode != 404;
      } catch (e) {
        refundCancelEndpointReachable = false;
      }
      
      return {
        'success': response['success'] == true,
        'message': response['message'] ?? 'Connection test completed',
        'bankDataCount': response['data'] is List ? (response['data'] as List).length : 0,
        'locationDataCount': locationResponse['data'] is List ? (locationResponse['data'] as List).length : 0,
        'invoiceTypeDataCount': invoiceTypeResponse['data'] is List ? (invoiceTypeResponse['data'] as List).length : 0,
        'refundGetRequestSuccess': refundGetRequestResponse['success'] == true,
        'discountDashboardSuccess': discountDashboardResponse['success'] == true,
        'refundCancelEndpointReachable': refundCancelEndpointReachable,
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
        'discountDashboardSuccess': false,
        'refundCancelEndpointReachable': false,
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