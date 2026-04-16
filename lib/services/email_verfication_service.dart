// lib/services/email_verification_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmailVerificationService {
  // Change this to your actual server IP
  static const String _baseUrl = "https://test.smartcarehis.com:8443/smartcaremain/verifyemail";
  
  static const String _sendOtpUrl = "$_baseUrl/sendEmailOTP";
  static const String _verifyOtpUrl = "$_baseUrl/verifyOTP";

  Future<Map<String, String>> _getHeaders() async {
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

      debugPrint('📋 Token being sent: ${token.substring(0, token.length > 50 ? 50 : token.length)}...');
      debugPrint('📋 ClinicId: $clinicId');
      debugPrint('📋 UserId: $userId');

      return {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        // Try different Authorization formats
        'Authorization': token.isNotEmpty ? 'Bearer $token' : '', // Changed from 'SmartCare' to 'Bearer'
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        'branchId': branchId,
        'Access-Control-Allow-Origin': '*',
      };
    } catch (e) {
      debugPrint('Error getting headers: $e');
      return {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'Access-Control-Allow-Origin': '*',
      };
    }
  }

  /// Alternative headers without token (if endpoint doesn't require auth)
  Future<Map<String, String>> _getHeadersWithoutAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      String getPrefAsString(String key) {
        final val = prefs.get(key);
        return val?.toString() ?? '';
      }

      final clinicId = getPrefAsString('clinicId');
      final userId = getPrefAsString('userId');
      final branchId = getPrefAsString('branchId') ?? '1';

      return {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'clinicid': clinicId,
        'userid': userId,
        'ZONEID': 'Asia/Kolkata',
        'branchId': branchId,
        'Access-Control-Allow-Origin': '*',
      };
    } catch (e) {
      debugPrint('Error getting headers without auth: $e');
      return {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'Access-Control-Allow-Origin': '*',
      };
    }
  }

  /// Send OTP to email for verification
  Future<Map<String, dynamic>> sendEmailOTP({
    required String email,
    required String userId,
  }) async {
    debugPrint('Sending email verification OTP to: $email for user: $userId');
    
    try {
      // Try with authentication first
      var headers = await _getHeaders();
      
      final body = {
        "email": email.trim(),
        "userId": userId.trim(),
      };
      
      debugPrint('Send OTP URL: $_sendOtpUrl');
      debugPrint('Send OTP Headers: $headers');
      debugPrint('Send OTP Body: $body');

      var response = await http.post(
        Uri.parse(_sendOtpUrl),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      // If 403, try without authentication
      if (response.statusCode == 403) {
        debugPrint('⚠️ Authentication failed, trying without Authorization header...');
        headers = await _getHeadersWithoutAuth();
        
        debugPrint('Retry Headers (no auth): $headers');
        
        response = await http.post(
          Uri.parse(_sendOtpUrl),
          headers: headers,
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 30));
      }

      debugPrint('Send OTP API Status Code: ${response.statusCode}');
      debugPrint('Send OTP API Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        
        if (decoded is Map<String, dynamic>) {
          final statusCode = decoded['status_code'] ?? decoded['status'] ?? 200;
          final message = decoded['message'] ?? '';
          final data = decoded['data'] ?? {};
          
          // Check if the response indicates success
          bool isSuccess = statusCode == 200 || statusCode == 201;
          
          return {
            'success': isSuccess,
            'statusCode': statusCode,
            'message': message.isNotEmpty ? message : 'OTP sent successfully',
            'data': data,
            'timestamp': decoded['timestamp'] ?? '',
            'error': decoded['error'],
          };
        } else {
          return {
            'success': true,
            'message': 'OTP sent successfully',
            'data': response.body,
          };
        }
      } else {
        String errorMessage = 'Failed to send verification OTP (Status ${response.statusCode})';
        
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
        
        return {
          'success': false,
          'message': errorMessage,
          'statusCode': response.statusCode,
        };
      }
    } catch (e, stackTrace) {
      debugPrint('Error sending verification OTP: $e');
      debugPrint('StackTrace: $stackTrace');
      
      String errorMessage = 'Network error occurred';
      if (e is http.ClientException) {
        errorMessage = 'Connection failed. Please check your internet connection.';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Request timed out. Please try again.';
      }
      
      return {
        'success': false,
        'message': errorMessage,
        'error': e.toString(),
      };
    }
  }

  /// Verify OTP for email verification
  Future<Map<String, dynamic>> verifyOTP({
    required String userOtp,
    required String userId,
  }) async {
    debugPrint('Verifying email OTP: $userOtp for user: $userId');
    
    try {
      // Try with authentication first
      var headers = await _getHeaders();
      
      final body = {
        "userOtp": userOtp.trim(),
        "userId": userId.trim(),
      };
      
      debugPrint('Verify OTP URL: $_verifyOtpUrl');
      debugPrint('Verify OTP Headers: $headers');
      debugPrint('Verify OTP Body: $body');

      var response = await http.post(
        Uri.parse(_verifyOtpUrl),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      // If 403, try without authentication
      if (response.statusCode == 403) {
        debugPrint('⚠️ Authentication failed for verification, trying without Authorization header...');
        headers = await _getHeadersWithoutAuth();
        
        response = await http.post(
          Uri.parse(_verifyOtpUrl),
          headers: headers,
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 30));
      }

      debugPrint('Verify OTP API Status Code: ${response.statusCode}');
      debugPrint('Verify OTP API Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        
        if (decoded is Map<String, dynamic>) {
          final statusCode = decoded['status_code'] ?? decoded['status'] ?? 200;
          final message = decoded['message'] ?? '';
          final data = decoded['data'] ?? {};
          
          bool isSuccess = statusCode == 200 || statusCode == 201;
          
          return {
            'success': isSuccess,
            'statusCode': statusCode,
            'message': message.isNotEmpty ? message : 'OTP verified successfully',
            'data': data,
            'timestamp': decoded['timestamp'] ?? '',
            'error': decoded['error'],
          };
        } else {
          return {
            'success': true,
            'message': 'OTP verified successfully',
            'data': response.body,
          };
        }
      } else {
        String errorMessage = 'Failed to verify OTP (Status ${response.statusCode})';
        
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
        
        return {
          'success': false,
          'message': errorMessage,
          'statusCode': response.statusCode,
        };
      }
    } catch (e, stackTrace) {
      debugPrint('Error verifying email OTP: $e');
      debugPrint('StackTrace: $stackTrace');
      
      String errorMessage = 'Network error occurred';
      if (e is http.ClientException) {
        errorMessage = 'Connection failed. Please check your internet connection.';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Request timed out. Please try again.';
      }
      
      return {
        'success': false,
        'message': errorMessage,
        'error': e.toString(),
      };
    }
  }

  /// Validate email format
  bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email.trim());
  }

  /// Validate OTP format (6-digit number)
  bool isValidOTP(String otp) {
    final otpRegex = RegExp(r'^\d{6}$');
    return otpRegex.hasMatch(otp.trim());
  }

  /// Save email verification data to SharedPreferences
  Future<void> saveVerificationData({
    required String email,
    required String userId,
    String? otp,
    String? verificationToken,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('verification_email', email);
      await prefs.setString('verification_userId', userId);
      
      if (otp != null) {
        await prefs.setString('verification_otp', otp);
      }
      
      if (verificationToken != null) {
        await prefs.setString('verification_token', verificationToken);
      }
      
      debugPrint('Email verification data saved to SharedPreferences');
    } catch (e) {
      debugPrint('Error saving verification data: $e');
    }
  }

  /// Get saved email verification data
  Future<Map<String, String>> getVerificationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'email': prefs.getString('verification_email') ?? '',
        'userId': prefs.getString('verification_userId') ?? '',
        'otp': prefs.getString('verification_otp') ?? '',
        'verificationToken': prefs.getString('verification_token') ?? '',
      };
    } catch (e) {
      debugPrint('Error getting verification data: $e');
      return {};
    }
  }

  /// Clear saved email verification data
  Future<void> clearVerificationData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('verification_email');
      await prefs.remove('verification_userId');
      await prefs.remove('verification_otp');
      await prefs.remove('verification_token');
      debugPrint('Email verification data cleared from SharedPreferences');
    } catch (e) {
      debugPrint('Error clearing verification data: $e');
    }
  }

  /// Check if email is already verified
  Future<bool> isEmailVerified(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final verifiedEmail = prefs.getString('verified_email');
      return verifiedEmail == email;
    } catch (e) {
      debugPrint('Error checking email verification status: $e');
      return false;
    }
  }

  /// Mark email as verified in local storage
  Future<void> markEmailAsVerified(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('verified_email', email);
      debugPrint('Email marked as verified: $email');
    } catch (e) {
      debugPrint('Error marking email as verified: $e');
    }
  }
}