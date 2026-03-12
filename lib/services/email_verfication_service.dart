// lib/services/email_verification_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EmailVerificationService {
  static const String _baseUrl = "http://192.168.1.38:9090/smartcaremain/verifyemail";
  
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

      return {
        'Content-Type': 'application/json',
        'Accept': '*/*',
        'Authorization': token.isNotEmpty ? 'SmartCare $token' : '',
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

  /// Send OTP to email for verification
  Future<Map<String, dynamic>> sendEmailOTP({
    required String email,
    required String userId,
  }) async {
    debugPrint('Sending email verification OTP to: $email for user: $userId');
    
    try {
      final headers = await _getHeaders();
      
      final body = {
        "email": email.trim(),
        "userId": userId.trim(),
      };
      
      debugPrint('Send OTP URL: $_sendOtpUrl');
      debugPrint('Send OTP Headers: $headers');
      debugPrint('Send OTP Body: $body');

      final response = await http.post(
        Uri.parse(_sendOtpUrl),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      debugPrint('Send OTP API Status Code: ${response.statusCode}');
      debugPrint('Send OTP API Response: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        if (decoded is Map<String, dynamic>) {
          final statusCode = decoded['status_code'] ?? 200;
          final message = decoded['message'] ?? '';
          final data = decoded['data'] ?? {};
          
          return {
            'success': statusCode == 200,
            'statusCode': statusCode,
            'message': message,
            'data': data,
            'timestamp': decoded['timestamp'] ?? '',
            'error': decoded['error'],
          };
        } else {
          return {
            'success': false,
            'message': 'Invalid response format from server',
            'error': 'Response is not in expected JSON format',
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
      final headers = await _getHeaders();
      
      final body = {
        "userOtp": userOtp.trim(),
        "userId": userId.trim(),
      };
      
      debugPrint('Verify OTP URL: $_verifyOtpUrl');
      debugPrint('Verify OTP Headers: $headers');
      debugPrint('Verify OTP Body: $body');

      final response = await http.post(
        Uri.parse(_verifyOtpUrl),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      debugPrint('Verify OTP API Status Code: ${response.statusCode}');
      debugPrint('Verify OTP API Response: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        if (decoded is Map<String, dynamic>) {
          final statusCode = decoded['status_code'] ?? 200;
          final message = decoded['message'] ?? '';
          final data = decoded['data'] ?? {};
          
          return {
            'success': statusCode == 200,
            'statusCode': statusCode,
            'message': message,
            'data': data,
            'timestamp': decoded['timestamp'] ?? '',
            'error': decoded['error'],
          };
        } else {
          return {
            'success': false,
            'message': 'Invalid response format from server',
            'error': 'Response is not in expected JSON format',
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

  /// Complete email verification flow (send OTP + verify OTP)
  Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String userId,
    required String otp,
  }) async {
    debugPrint('Starting email verification flow for user: $userId');
    
    // Step 1: Send OTP
    debugPrint('Step 1: Sending verification OTP...');
    final otpResult = await sendEmailOTP(email: email, userId: userId);
    
    if (!otpResult['success']) {
      return otpResult;
    }
    
    // Step 2: Verify OTP
    debugPrint('Step 2: Verifying OTP...');
    final verifyResult = await verifyOTP(userOtp: otp, userId: userId);
    
    return verifyResult;
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

  /// Check if email is already verified (can be implemented based on your app logic)
  Future<bool> isEmailVerified(String email) async {
    try {
      // You might want to check with your backend or local storage
      // This is a placeholder implementation
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