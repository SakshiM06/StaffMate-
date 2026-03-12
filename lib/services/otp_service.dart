import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class OTPService {
  static const String baseUrl = "https://test.smartcarehis.com:8443";

  static Future<Map<String, dynamic>> sendOTP({
    required String? token,
    required String? userId,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/security/auth/send-otp");
      
      final headers = {
        "Content-Type": "application/json",
        "Authorization": "SmartCare $token",
        "userid": userId ?? '',
        "Access-Control-Allow-Origin": "*",
      };
      
      final body = jsonEncode({
        "userId": userId,
        "sendTo": "both",
      });
      
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to send OTP');
      }
    } catch (e) {
      debugPrint('❌ OTP Send Error: $e');
      rethrow;
    }
  }

  static Future<bool> verifyOTP({
    required String? token,
    required String? userId,
    required String otp,
  }) async {
    try {
      final url = Uri.parse("$baseUrl/security/auth/verify-otp");
      
      final headers = {
        "Content-Type": "application/json",
        "Authorization": "SmartCare $token",
        "userid": userId ?? '',
        "Access-Control-Allow-Origin": "*",
      };
      
      final body = jsonEncode({
        "userId": userId,
        "otp": otp,
        "verifyFor": "login",
      });

      final response = await http.post(
        url,
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['status_code'] == 200;
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ OTP Verify Error: $e');
      return false;
    }
  }

  static Future sendEmailOTP({required String email}) async {}

  static Future verifyEmailOTP({required String email, required String otp, required String verificationId}) async {}
}