import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ForgetPasswordService {
  static const String _baseUrl = "https://test.smartcarehis.com:443/smartcaremain/passwordupdate";
  
  static const String _sendOtpUrl = "$_baseUrl/sendEmailOTP";
  static const String _verifyOtpUrl = "$_baseUrl/verifyOTP";
  static const String _updatePasswordUrl = "$_baseUrl/updatePassword";

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

  Future<Map<String, dynamic>> sendEmailOTP({
    required String email,
    required String userId,
  }) async {
    debugPrint('Sending OTP to email: $email for user: $userId');
    
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
        String errorMessage = 'Failed to send OTP (Status ${response.statusCode})';
        
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
      debugPrint('Error sending OTP: $e');
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


  Future<Map<String, dynamic>> verifyOTP({
    required String userOtp,
    required String userId,
  }) async {
    debugPrint('Verifying OTP: $userOtp for user: $userId');
    
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
      debugPrint('Error verifying OTP: $e');
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

  Future<Map<String, dynamic>> updatePassword({
    required String password,
    required String email,
    required String userId,
  }) async {
    debugPrint('Updating password for user: $userId');
    
    try {
      final headers = await _getHeaders();
      
      if (password.length < 6) {
        return {
          'success': false,
          'message': 'Password must be at least 6 characters long',
        };
      }
     
      final body = {
        "password": password.trim(),
        "email": email.trim(),
        "userId": userId.trim(),
      };
      
      debugPrint('Update Password URL: $_updatePasswordUrl');
      debugPrint('Update Password Headers: $headers');
      debugPrint('Update Password Body: ${body.toString().replaceAll(password, '***')}'); // Hide password in logs

      final response = await http.post(
        Uri.parse(_updatePasswordUrl),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      debugPrint('Update Password API Status Code: ${response.statusCode}');
      debugPrint('Update Password API Response: ${response.body}');

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
        String errorMessage = 'Failed to update password (Status ${response.statusCode})';
        
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
      debugPrint('Error updating password: $e');
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

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String userId,
    required String otp,
    required String newPassword,
  }) async {
    debugPrint('Starting password reset flow for user: $userId');
    
   
    debugPrint('Step 1: Sending OTP...');
    final otpResult = await sendEmailOTP(email: email, userId: userId);
    
    if (!otpResult['success']) {
      return otpResult;
    }
    
    debugPrint('Step 2: Verifying OTP...');
    final verifyResult = await verifyOTP(userOtp: otp, userId: userId);
    
    if (!verifyResult['success']) {
      return verifyResult;
    }
    
    debugPrint('Step 3: Updating password...');
    final updateResult = await updatePassword(
      password: newPassword,
      email: email,
      userId: userId,
    );
    
    return updateResult;
  }


  bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email.trim());
  }

  bool isValidOTP(String otp) {
    final otpRegex = RegExp(r'^\d{6}$');
    return otpRegex.hasMatch(otp.trim());
  }

  Map<String, dynamic> validatePassword(String password) {
    final errors = <String>[];
    
    if (password.length < 6) {
      errors.add('Password must be at least 6 characters long');
    }
    
    return {
      'isValid': errors.isEmpty,
      'errors': errors,
      'strength': _calculatePasswordStrength(password),
    };
  }

  int _calculatePasswordStrength(String password) {
    int strength = 0;
    
    if (password.length >= 6) strength++;
    if (password.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[a-z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;
    
    return strength.clamp(1, 5);
  }

  Future<void> saveResetData({
    required String email,
    required String userId,
    String? otp,
    String? resetToken,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('reset_email', email);
      await prefs.setString('reset_userId', userId);
      
      if (otp != null) {
        await prefs.setString('reset_otp', otp);
      }
      
      if (resetToken != null) {
        await prefs.setString('reset_token', resetToken);
      }
      
      debugPrint('Reset data saved to SharedPreferences');
    } catch (e) {
      debugPrint('Error saving reset data: $e');
    }
  }

  Future<Map<String, String>> getResetData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'email': prefs.getString('reset_email') ?? '',
        'userId': prefs.getString('reset_userId') ?? '',
        'otp': prefs.getString('reset_otp') ?? '',
        'resetToken': prefs.getString('reset_token') ?? '',
      };
    } catch (e) {
      debugPrint('Error getting reset data: $e');
      return {};
    }
  }
  Future<void> clearResetData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('reset_email');
      await prefs.remove('reset_userId');
      await prefs.remove('reset_otp');
      await prefs.remove('reset_token');
      debugPrint('Reset data cleared from SharedPreferences');
    } catch (e) {
      debugPrint('Error clearing reset data: $e');
    }
  }
}