import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mime_type/mime_type.dart';
import 'package:http_parser/http_parser.dart';

class SupportService {
  static const String _physicalDeviceUrl = 'http://192.168.1.38:9091';
  static const String _createTicketEndpoint = '/support/ticket/create';
  static const String _getTicketsEndpoint = '/support/ticket/get/list'; 
  static const String _updateTicketEndpoint = '/support/ticket/update';
  static const String _viewImageBase64Endpoint = '/support/ticket/view/base64';

  static const String _supportClinicIdKey = 'support_clinic_id';
  static const String _defaultSupportClinicId = 'pcsadmin';

  static Future<void> saveSupportClinicId(String clinicId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_supportClinicIdKey, clinicId);
    debugPrint('✅ Support Clinic ID saved: $clinicId');
  }

  static Future<String> getSupportClinicId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_supportClinicIdKey) ?? _defaultSupportClinicId;
  }

  static Future<void> clearSupportClinicId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_supportClinicIdKey);
    debugPrint('✅ Support Clinic ID cleared');
  }

  static Future<Map<String, dynamic>> createTicket({
    required String title,
    required String description,
    required String priority,
    required String userId,
    String? clinicId,
    String? zoneId,
    List<File>? images,
  }) async {
    final stopwatch = Stopwatch()..start();
    debugPrint('SupportService Base URL: $_physicalDeviceUrl');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final token = prefs.getString('auth_token') ?? '';
      final supportClinicId = await getSupportClinicId();
      final userIdFromPrefs = prefs.getString('userId') ?? userId;
      final branchId = prefs.getString('branchId') ?? '';
      final zoneIdFromPrefs = prefs.getString('zoneId') ?? zoneId ?? 'Asia/Kolkata';

      if (token.isEmpty) throw Exception('Authentication token missing');
      if (supportClinicId.isEmpty) throw Exception('Support Clinic ID missing');
      if (userIdFromPrefs.isEmpty) throw Exception('User ID missing');
      if (title.isEmpty) throw Exception('Title is required');
      if (description.isEmpty) throw Exception('Description is required');
      if (priority.isEmpty) throw Exception('Priority is required');

      final headers = {
        'Accept': '*/*',
        'Authorization': 'SmartCare $token',
        'clinicid': supportClinicId,
        'userid': userIdFromPrefs,
        'ZONEID': zoneIdFromPrefs,
        'branchId': branchId,
        'Access-Control-Allow-Origin': '*',
      };

      final url = '$_physicalDeviceUrl$_createTicketEndpoint';
      
      debugPrint('\n=== CREATE SUPPORT TICKET API REQUEST DEBUG ===');
      debugPrint('URL: $url');
      debugPrint('Headers:');
      debugPrint('  - Authorization: SmartCare $token');
      debugPrint('  - clinicid: $supportClinicId');
      debugPrint('  - userid: $userIdFromPrefs');
      debugPrint('  - ZONEID: $zoneIdFromPrefs');
      debugPrint('  - branchId: ${branchId.isNotEmpty ? branchId : "Not provided"}');
      debugPrint('Ticket Data:');
      debugPrint('  - Title: $title');
      debugPrint('  - Description: $description');
      debugPrint('  - Priority: $priority');
      debugPrint('  - UserID: $userIdFromPrefs');
      debugPrint('  - Images count: ${images?.length ?? 0}');

      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers.addAll(headers);
      
      final ticketData = {
        'title': title,
        'description': description,
        'priority': priority.toUpperCase(),
        'userid': userIdFromPrefs,
      };
      
      request.fields['ticket'] = jsonEncode(ticketData);
      debugPrint('  - Encoded Ticket JSON: ${jsonEncode(ticketData)}');

      if (images != null && images.isNotEmpty) {
        debugPrint('\n📸 Processing images:');
        
        for (var i = 0; i < images.length; i++) {
          final image = images[i];
          if (await image.exists()) {
            final fileSize = await image.length();
            const maxSize = 5 * 1024 * 1024;
            if (fileSize > maxSize) {
              debugPrint('⚠️ Warning: File ${image.path} exceeds 5MB, skipping');
              continue;
            }

            final mimeType = _getMimeType(image.path);
            if (mimeType == null || !mimeType.startsWith('image/')) {
              debugPrint('⚠️ Warning: File ${image.path} is not a valid image, skipping');
              continue;
            }

            request.files.add(
              await http.MultipartFile.fromPath(
                'file',
                image.path,
                contentType: MediaType.parse(mimeType),
              ),
            );
            
            debugPrint('  - Image $i added: ${image.path} (${_formatFileSize(fileSize)})');
          }
        }
      }

      debugPrint('\n📤 Sending multipart request with ${request.files.length} file(s)...');
      
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Connection timeout. Server not responding');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);
      
      stopwatch.stop();
      debugPrint('\n=== CREATE SUPPORT TICKET API RESPONSE DEBUG ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Time: ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        debugPrint('✅ Ticket created successfully!');
        
        return {
          'success': true,
          'message': 'Support ticket created successfully',
          'status_code': response.statusCode,
          'data': decoded,
        };
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('\n❌ SupportService Error (createTicket): $e');
      rethrow;
    }
  }

  // Update a ticket using PUT /support/ticket/update
  static Future<Map<String, dynamic>> updateTicket({
    required int ticketId,
    required String title,
    required String description,
    required String priority,
    required String status,
    String? currentResolutionSummary,
    String? userId,
    String? clinicId,
    String? zoneId,
  }) async {
    final stopwatch = Stopwatch()..start();
    debugPrint('\n📝 Updating ticket #$ticketId via /support/ticket/update');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final token = prefs.getString('auth_token') ?? '';
      final supportClinicId = await getSupportClinicId();
      final userIdFromPrefs = prefs.getString('userId') ?? userId ?? '';
      final branchId = prefs.getString('branchId') ?? '';
      final zoneIdFromPrefs = prefs.getString('zoneId') ?? zoneId ?? 'Asia/Kolkata';

      if (token.isEmpty) throw Exception('Authentication token missing');
      if (supportClinicId.isEmpty) throw Exception('Support Clinic ID missing');
      if (userIdFromPrefs.isEmpty) throw Exception('User ID missing');
      if (title.isEmpty) throw Exception('Title is required');
      if (description.isEmpty) throw Exception('Description is required');
      if (priority.isEmpty) throw Exception('Priority is required');
      if (status.isEmpty) throw Exception('Status is required');

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'SmartCare $token',
        'clinicid': supportClinicId,
        'userid': userIdFromPrefs,
        'ZONEID': zoneIdFromPrefs,
        if (branchId.isNotEmpty) 'branchId': branchId,
        'Access-Control-Allow-Origin': '*',
      };

      final url = '$_physicalDeviceUrl$_updateTicketEndpoint';
      
      // Build request body
      final Map<String, dynamic> requestBody = {
        'ticketId': ticketId,
        'title': title,
        'description': description,
        'priority': priority.toUpperCase(),
        'status': status.toUpperCase(),
        'userid': userIdFromPrefs,
        'clinicid': supportClinicId,
      };

      // Add optional fields if provided
      if (currentResolutionSummary != null && currentResolutionSummary.isNotEmpty) {
        requestBody['currentResolutionSummary'] = currentResolutionSummary;
      }

      debugPrint('\n=== UPDATE TICKET API REQUEST DEBUG ===');
      debugPrint('URL: $url');
      debugPrint('Method: PUT');
      debugPrint('Headers:');
      debugPrint('  - Authorization: SmartCare $token');
      debugPrint('  - clinicid: $supportClinicId');
      debugPrint('  - userid: $userIdFromPrefs');
      debugPrint('  - ZONEID: $zoneIdFromPrefs');
      debugPrint('  - branchId: ${branchId.isNotEmpty ? branchId : "Not provided"}');
      debugPrint('Request Body: ${jsonEncode(requestBody)}');

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Server not responding');
        },
      );

      stopwatch.stop();
      debugPrint('\n=== UPDATE TICKET API RESPONSE DEBUG ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Time: ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('Response Headers: ${response.headers}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('✅ Ticket updated successfully!');
        debugPrint('Message: ${decoded['message']}');
        
        return {
          'success': true,
          'message': decoded['message'] ?? 'Ticket updated successfully',
          'status_code': response.statusCode,
          'data': decoded,
        };
      } else if (response.statusCode == 400) {
        final errorResponse = jsonDecode(response.body);
        String errorMessage = 'Failed to update ticket: ';
        if (errorResponse is Map) {
          errorMessage = errorResponse['message'] ?? 
                        errorResponse['error'] ?? 
                        'Bad request';
        }
        throw Exception(errorMessage);
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access forbidden. Check your permissions.');
      } else if (response.statusCode == 404) {
        throw Exception('Ticket not found with ID: $ticketId');
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('\n❌ SupportService Error (updateTicket): $e');
      return {
        'success': false,
        'message': e.toString(),
        'status_code': 500,
        'data': null,
      };
    }
  }

  // Convenience method to update ticket status only
  static Future<Map<String, dynamic>> updateTicketStatus({
    required int ticketId,
    required String status,
    String? currentResolutionSummary,
  }) async {
    debugPrint('\n🔄 Updating status for ticket #$ticketId to $status');
    
    try {
      // First, get the current ticket details
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      
      // Get tickets using the POST method with filters
      final ticketsResult = await getTicketsByUserAndDate(
        userId: userId,
        date: DateTime.now().toIso8601String().split('T')[0],
        status: status, // Pass status to filter
      );
      
      if (!ticketsResult['success'] || ticketsResult['data'] == null) {
        throw Exception('Could not fetch ticket details');
      }
      
      final data = ticketsResult['data'];
      List<dynamic> ticketsData = [];
      
      if (data['data'] != null && data['data'] is List) {
        ticketsData = data['data'];
      } else if (data is List) {
        ticketsData = data;
      }
      
      // Find the ticket with matching ID
      final ticketJson = ticketsData.firstWhere(
        (t) => t['ticketId'] == ticketId || t['id'] == ticketId,
        orElse: () => null,
      );
      
      if (ticketJson == null) {
        throw Exception('Ticket not found with ID: $ticketId');
      }
      
      // Update only the status and resolution summary
      return await updateTicket(
        ticketId: ticketId,
        title: ticketJson['title'] ?? '',
        description: ticketJson['description'] ?? '',
        priority: ticketJson['priority'] ?? 'MEDIUM',
        status: status,
        currentResolutionSummary: currentResolutionSummary ?? ticketJson['currentResolutionSummary'],
      );
    } catch (e) {
      debugPrint('❌ Error in updateTicketStatus: $e');
      return {
        'success': false,
        'message': e.toString(),
        'status_code': 500,
        'data': null,
      };
    }
  }

  // UPDATED METHOD: Get tickets by user ID and date (using POST with JSON payload)
  // Status is now required in the payload
  static Future<Map<String, dynamic>> getTicketsByUserAndDate({
    required String userId,
    required String date, // Format: YYYY-MM-DD
    required String status, // Status is now required
    int page = 0,
    int size = 20,
  }) async {
    debugPrint('\n📋 Fetching tickets for user: $userId on date: $date with status: $status');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final token = prefs.getString('auth_token') ?? '';
      // Get clinic ID from SharedPreferences - don't hardcode
      final supportClinicId = await getSupportClinicId();
      final currentUserId = prefs.getString('userId') ?? '';
      final branchId = prefs.getString('branchId') ?? '';

      if (token.isEmpty) {
        throw Exception('Authentication token missing');
      }
      
      if (currentUserId.isEmpty) {
        throw Exception('Current user ID missing');
      }

      if (supportClinicId.isEmpty) {
        throw Exception('Support Clinic ID missing');
      }

      if (status.isEmpty) {
        throw Exception('Status is required');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'SmartCare $token',
        'clinicid': supportClinicId,
        'userid': currentUserId,
        'ZONEID': 'Asia/Kolkata',
        if (branchId.isNotEmpty) 'branchId': branchId,
        'Access-Control-Allow-Origin': '*',
      };

      // Construct URL without userId in path - just the base endpoint
      final url = '$_physicalDeviceUrl$_getTicketsEndpoint';
      
      // Build request body with required fields
      final Map<String, dynamic> requestBody = {
        'userid': userId,
        'clinicid': supportClinicId,
        'status': status, // Status is now required
      };

      // Add pagination parameters as query params
      final queryParams = <String, String>{
        'page': page.toString(),
        'size': size.toString(),
      };

      final uri = Uri.parse(url).replace(queryParameters: queryParams);

      debugPrint('\n=== GET TICKETS BY USER AND DATE API REQUEST DEBUG ===');
      debugPrint('URL: $uri');
      debugPrint('Method: POST');
      debugPrint('Headers:');
      debugPrint('  - Authorization: SmartCare $token');
      debugPrint('  - clinicid: $supportClinicId');
      debugPrint('  - userid: $currentUserId');
      debugPrint('  - ZONEID: Asia/Kolkata');
      debugPrint('  - branchId: ${branchId.isNotEmpty ? branchId : "Not provided"}');
      debugPrint('Request Body: ${jsonEncode(requestBody)}');
      debugPrint('Query Parameters:');
      debugPrint('  - page: $page');
      debugPrint('  - size: $size');

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Server not responding');
        },
      );

      debugPrint('\n=== GET TICKETS BY USER AND DATE API RESPONSE DEBUG ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Headers: ${response.headers}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('✅ Tickets fetched successfully for user $userId on date $date!');
        
        return {
          'success': true,
          'message': 'Tickets fetched successfully',
          'status_code': response.statusCode,
          'data': decoded,
        };
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access forbidden. Check your permissions.');
      } else if (response.statusCode == 404) {
        debugPrint('ℹ️ No tickets found for user $userId on date $date');
        return {
          'success': true,
          'message': 'No tickets found',
          'status_code': response.statusCode,
          'data': {'list': []},
        };
      } else {
        throw Exception('Failed to fetch tickets: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('\n❌ SupportService Error (getTicketsByUserAndDate): $e');
      return {
        'success': false,
        'message': e.toString(),
        'status_code': 500,
        'data': null,
      };
    }
  }

  static Future<Map<String, dynamic>> getTicketsByDateRange({
    required String userId,
    required String fromDate,
    required String toDate,
    required String status, 
    int page = 0,
    int size = 20,
  }) async {
    debugPrint('\n📋 Fetching tickets for user: $userId from $fromDate to $toDate with status: $status');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final token = prefs.getString('auth_token') ?? '';
      final supportClinicId = await getSupportClinicId();
      final currentUserId = prefs.getString('userId') ?? '';
      final branchId = prefs.getString('branchId') ?? '';

      if (token.isEmpty) {
        throw Exception('Authentication token missing');
      }
      
      if (currentUserId.isEmpty) {
        throw Exception('Current user ID missing');
      }

      if (supportClinicId.isEmpty) {
        throw Exception('Support Clinic ID missing');
      }

      if (status.isEmpty) {
        throw Exception('Status is required');
      }

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'SmartCare $token',
        'clinicid': supportClinicId,
        'userid': currentUserId,
        'ZONEID': 'Asia/Kolkata',
        if (branchId.isNotEmpty) 'branchId': branchId,
        'Access-Control-Allow-Origin': '*',
      };

      final url = '$_physicalDeviceUrl$_getTicketsEndpoint';
      
      final Map<String, dynamic> requestBody = {
        'userid': userId,
        'clinicid': supportClinicId,
        'fromDate': fromDate,
        'toDate': toDate,
        'status': status,
      };

      final queryParams = <String, String>{
        'page': page.toString(),
        'size': size.toString(),
      };

      final uri = Uri.parse(url).replace(queryParameters: queryParams);

      debugPrint('\n=== GET TICKETS BY DATE RANGE API REQUEST DEBUG ===');
      debugPrint('URL: $uri');
      debugPrint('Method: POST');
      debugPrint('Headers:');
      debugPrint('  - Authorization: SmartCare $token');
      debugPrint('  - clinicid: $supportClinicId');
      debugPrint('  - userid: $currentUserId');
      debugPrint('  - ZONEID: Asia/Kolkata');
      debugPrint('  - branchId: ${branchId.isNotEmpty ? branchId : "Not provided"}');
      debugPrint('Request Body: ${jsonEncode(requestBody)}');
      debugPrint('Query Parameters:');
      debugPrint('  - page: $page');
      debugPrint('  - size: $size');

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout. Server not responding');
        },
      );

      debugPrint('\n=== GET TICKETS BY DATE RANGE API RESPONSE DEBUG ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Headers: ${response.headers}');
      debugPrint('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        debugPrint('✅ Tickets fetched successfully for user $userId from $fromDate to $toDate!');
        
        return {
          'success': true,
          'message': 'Tickets fetched successfully',
          'status_code': response.statusCode,
          'data': decoded,
        };
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 403) {
        throw Exception('Access forbidden. Check your permissions.');
      } else if (response.statusCode == 404) {
        debugPrint('ℹ️ No tickets found for user $userId in the specified date range');
        return {
          'success': true,
          'message': 'No tickets found',
          'status_code': response.statusCode,
          'data': {'list': []},
        };
      } else {
        throw Exception('Failed to fetch tickets: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('\n❌ SupportService Error (getTicketsByDateRange): $e');
      return {
        'success': false,
        'message': e.toString(),
        'status_code': 500,
        'data': null,
      };
    }
  }

  static Future<Map<String, dynamic>> getTodayTickets({required String status}) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';
    final today = DateTime.now().toIso8601String().split('T')[0]; 
    
    return getTicketsByUserAndDate(
      userId: userId,
      date: today,
      status: status,
    );
  }

  static Future<Map<String, dynamic>> getTodayTicketsByUser(
    String userId, {
    required String status,
  }) async {
    final today = DateTime.now().toIso8601String().split('T')[0]; 
    return getTicketsByUserAndDate(
      userId: userId,
      date: today,
      status: status,
    );
  }

  static Future<Map<String, dynamic>> getThisWeekTickets({required String status}) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';
    final today = DateTime.now();
    final weekAgo = today.subtract(const Duration(days: 7));
    
    final fromDate = weekAgo.toIso8601String().split('T')[0];
    final toDate = today.toIso8601String().split('T')[0];
    
    return getTicketsByDateRange(
      userId: userId,
      fromDate: fromDate,
      toDate: toDate,
      status: status,
    );
  }

  static Future<Map<String, dynamic>> getThisWeekTicketsByUser(
    String userId, {
    required String status,
  }) async {
    final today = DateTime.now();
    final weekAgo = today.subtract(const Duration(days: 7));
    
    final fromDate = weekAgo.toIso8601String().split('T')[0];
    final toDate = today.toIso8601String().split('T')[0];
    
    return getTicketsByDateRange(
      userId: userId,
      fromDate: fromDate,
      toDate: toDate,
      status: status,
    );
  }

static Future<Map<String, dynamic>> viewTicketImageBase64({
  required int ticketId,
  required String fileType,
}) async {
  debugPrint('\n🖼️ Fetching base64 image for ticket #$ticketId with fileType: $fileType');
  
  try {
    final prefs = await SharedPreferences.getInstance();
    
    final token = prefs.getString('auth_token') ?? '';
    final supportClinicId = await getSupportClinicId();
    final userId = prefs.getString('userId') ?? '';
    final branchId = prefs.getString('branchId') ?? '';

    if (token.isEmpty) {
      throw Exception('Authentication token missing');
    }
    
    if (userId.isEmpty) {
      throw Exception('User ID missing');
    }

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'SmartCare $token',
      'clinicid': supportClinicId,
      'userid': userId,
      'ZONEID': 'Asia/Kolkata',
      if (branchId.isNotEmpty) 'branchId': branchId,
    };

    final url = '$_physicalDeviceUrl$_viewImageBase64Endpoint';
    
    final Map<String, dynamic> requestBody = {
      'ticketId': ticketId,
      'fileType': fileType.toUpperCase(),
    };

    debugPrint('\n=== VIEW BASE64 IMAGE API REQUEST ===');
    debugPrint('URL: $url');
    debugPrint('Request Body: ${jsonEncode(requestBody)}');

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 30));

    debugPrint('Status Code: ${response.statusCode}');
    
 // WITH THIS:
if (response.statusCode == 200) {
  final decoded = jsonDecode(response.body);
  
  final innerData = (decoded['data'] ?? decoded) as Map<String, dynamic>;
  
  // Strip data URL prefix right here, so callers always get pure base64
  if (innerData['imageBase64'] != null) {
    final raw = innerData['imageBase64'].toString();
    if (raw.contains(',')) {
      innerData['imageBase64'] = raw.split(',').last;
    }
  }
  
  debugPrint('✅ imageBase64 cleaned, length: ${innerData['imageBase64']?.length ?? 0}');
  
  return {
    'success': true,
    'message': 'Image fetched successfully',
    'status_code': response.statusCode,
    'data': innerData,
  };
    } else if (response.statusCode == 404 || response.statusCode == 400) {
      return {
        'success': false,
        'message': 'No image found for this ticket',
        'status_code': response.statusCode,
        'data': null,
      };
    } else {
      return {
        'success': false,
        'message': 'Failed with status ${response.statusCode}',
        'status_code': response.statusCode,
        'data': null,
      };
    }
    
  } catch (e) {
    debugPrint('❌ Error: $e');
    return {
      'success': false,
      'message': e.toString(),
      'status_code': 500,
      'data': null,
    };
  }
}

  // Helper method to determine content type from base64 string
  static String _getImageContentType(String base64String) {
    if (base64String.startsWith('/9j/')) {
      return 'image/jpeg';
    } else if (base64String.startsWith('iVBOR')) {
      return 'image/png';
    // } else if (base64String.startsWith('R0lGOD')) {
    //   return 'image/gif';
    // } else if (base64String.startsWith('UklGR')) {
    //   return 'image/webp';
    }
    return 'image/jpeg'; // Default to JPEG
  }

  // Convenience method to view user image (returns base64)
  static Future<Map<String, dynamic>> viewUserImageBase64(int ticketId) {
    return viewTicketImageBase64(ticketId: ticketId, fileType: 'USER');
  }

  static Future<Map<String, dynamic>> viewResUserImageBase64(int ticketId) {
    return viewTicketImageBase64(ticketId: ticketId, fileType: 'RESUSER');
  }

  @Deprecated('Use viewUserImageBase64 instead')
  static Future<Map<String, dynamic>> viewUserImage(int ticketId) {
    return viewUserImageBase64(ticketId);
  }

  @Deprecated('Use viewResUserImageBase64 instead')
  static Future<Map<String, dynamic>> viewResUserImage(int ticketId) {
    return viewResUserImageBase64(ticketId);
  }

  @Deprecated('Use viewTicketImageBase64 instead')
  static Future<Map<String, dynamic>> viewTicketImage({
    required int ticketId,
    required String fileType,
  }) {
    return viewTicketImageBase64(ticketId: ticketId, fileType: fileType);
  }

  // Initialize support clinic ID
  static Future<void> initializeSupportClinicId() async {
    final prefs = await SharedPreferences.getInstance();
    final existingId = prefs.getString(_supportClinicIdKey);
    
    if (existingId == null) {
      await prefs.setString(_supportClinicIdKey, _defaultSupportClinicId);
      debugPrint('✅ Support Clinic ID initialized to: $_defaultSupportClinicId');
    } else {
      debugPrint('✅ Support Clinic ID already exists: $existingId');
    }
  }

  // Update support clinic ID
  static Future<void> updateSupportClinicId(String newClinicId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_supportClinicIdKey, newClinicId);
    debugPrint('✅ Support Clinic ID updated to: $newClinicId');
  }

  // Test connection to server
  static Future<bool> testConnection() async {
    try {
      debugPrint('\n🔍 Testing connection to $_physicalDeviceUrl...');
      final client = http.Client();
      final response = await client
          .get(Uri.parse('$_physicalDeviceUrl/health'))
          .timeout(const Duration(seconds: 5));
      client.close();
      final isConnected = response.statusCode == 200;
      debugPrint('Connection test: ${isConnected ? '✅ Success' : '❌ Failed'}');
      return isConnected;
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return false;
    }
  }

  // Helper method to get mime type from file path
  static String? _getMimeType(String filePath) {
    return mime(filePath) ?? 'image/jpeg';
  }

  // Helper method to format file size
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Validate image file before upload
  static bool isValidImage(File file, {int maxSizeMB = 5}) {
    try {
      if (!file.existsSync()) return false;
      final extension = file.path.split('.').last.toLowerCase();
      final validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
      if (!validExtensions.contains(extension)) return false;
      final fileSize = file.lengthSync();
      final maxSizeBytes = maxSizeMB * 1024 * 1024;
      if (fileSize > maxSizeBytes) return false;
      debugPrint('✅ Image validation passed: ${file.path}');
      return true;
    } catch (e) {
      debugPrint('Error validating image: $e');
      return false;
    }
  }

  // Helper method to get minimum of two integers
  static int min(int a, int b) => a < b ? a : b;
}