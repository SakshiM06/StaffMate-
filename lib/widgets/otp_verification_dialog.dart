import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:http/http.dart' as http;
import 'package:staff_mate/pages/login_page.dart'; 
import 'package:shared_preferences/shared_preferences.dart';

class OTPVerificationDialog extends StatefulWidget {
  final String userId;
  final String clinicId;
  final String token;
  final VoidCallback onVerificationSuccess;
  final VoidCallback onVerificationFailed;

  const OTPVerificationDialog({
    super.key,
    required this.userId,
    required this.clinicId,
    required this.token,
    required this.onVerificationSuccess,
    required this.onVerificationFailed,
  });

  @override
  State<OTPVerificationDialog> createState() => _OTPVerificationDialogState();
}

class _OTPVerificationDialogState extends State<OTPVerificationDialog> {
  // Controllers
  final TextEditingController _emailController = TextEditingController();
  // final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  
  // API URLs
  final String _baseUrl = "https://test.smartcarehis.com:8443/smartcaremain/passwordupdate";
  final String _sendOtpUrl = "/sendEmailOTP";
  final String _verifyOtpUrl = "/verifyOTP";
  
  // UI State
  bool _isLoading = false;
  bool _showOTPInput = false;
  bool _isResendEnabled = true;
  int _resendTimer = 120;
  Timer? _timer;
  
  // Data
  String _currentEmail = '';
  String _currentPhone = '';

  @override
  void dispose() {
    _emailController.dispose();
    // _phoneController.dispose();
    _otpController.dispose();
    _pinFocusNode.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _isResendEnabled = false;
      _resendTimer = 30;
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        setState(() => _isResendEnabled = true);
        timer.cancel();
      }
    });
  }

  Future<Map<String, String>> _getHeaders() async {
    return {
      'Content-Type': 'application/json',
      'Accept': '*/*',
      'Authorization': widget.token.isNotEmpty ? 'SmartCare ${widget.token}' : '',
      'clinicid': widget.clinicId,
      'userid': widget.userId,
      'ZONEID': 'Asia/Kolkata',
      'branchId': '1', // Default branch ID
      'Access-Control-Allow-Origin': '*',
    };
  }

  Future<void> _sendOTP() async {
    // Validate at least one contact method
    if (_emailController.text.trim().isEmpty ) {
      _showSnackBar("Please enter email ", Colors.red);
      return;
    }

    // Validate email if provided
    if (_emailController.text.trim().isNotEmpty && 
        !_isValidEmail(_emailController.text.trim())) {
      _showSnackBar("Please enter a valid email address", Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
      _currentEmail = _emailController.text.trim();
      // _currentPhone = _phoneController.text.trim();
    });

    try {
      final headers = await _getHeaders();
      
      final body = {
        "email": _currentEmail.isNotEmpty ? _currentEmail : _currentPhone,
        "userId": widget.userId,
      };
      
      // debugPrint('🔍 Send OTP URL: $_baseUrl$_sendOtpUrl');
      // debugPrint('🔍 Send OTP Headers: $headers');
      // debugPrint('🔍 Send OTP Body: $body');

      final response = await http.post(
        Uri.parse("$_baseUrl$_sendOtpUrl"),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      debugPrint('🔍 Send OTP Response Status: ${response.statusCode}');
      debugPrint('🔍 Send OTP Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final statusCode = decoded['status_code'] ?? 200;
        
        if (statusCode == 200) {
          setState(() {
            _showOTPInput = true;
          });

          final prefs = await SharedPreferences.getInstance();
await prefs.setString('otp_email', _currentEmail);

          _startResendTimer();
          _showSnackBar(
            "OTP sent to ${_currentEmail.isNotEmpty ? _currentEmail : _currentPhone}", 
            Colors.green
          );
          
          // Auto-focus OTP field
          Future.delayed(const Duration(milliseconds: 300), () {
            FocusScope.of(context).requestFocus(_pinFocusNode);
          });
        } else {
          _showSnackBar(decoded['message'] ?? "Failed to send OTP", Colors.red);
        }
      } else {
        String errorMessage = "Failed to send OTP";
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage = errorBody['message'] ?? errorBody['error']?['cause'] ?? errorMessage;
        } catch (e) {
          // Use default message
        }
        _showSnackBar(errorMessage, Colors.red);
      }
    } catch (e) {
      debugPrint('❌ Error sending OTP: $e');
      _showSnackBar("Network error: ${e.toString()}", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.trim().isEmpty) {
      _showSnackBar("Please enter OTP", Colors.red);
      return;
    }

    if (_otpController.text.trim().length < 6) {
      _showSnackBar("Please enter valid 6-digit OTP", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final headers = await _getHeaders();
      
      final body = {
        "userOtp": _otpController.text.trim(),
        "userId": widget.userId,
      };
      
      // debugPrint('🔍 Verify OTP URL: $_baseUrl$_verifyOtpUrl');
      // debugPrint('🔍 Verify OTP Headers: $headers');
      // debugPrint('🔍 Verify OTP Body: $body');

      final response = await http.post(
        Uri.parse("$_baseUrl$_verifyOtpUrl"),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      debugPrint('🔍 Verify OTP Response Status: ${response.statusCode}');
      debugPrint('🔍 Verify OTP Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final statusCode = decoded['status_code'] ?? 200;
        
        if (statusCode == 200) {
          _showSnackBar("OTP verified successfully!", Colors.green);
          
          // Close dialog after short delay
          Future.delayed(const Duration(milliseconds: 500), () {
            Navigator.of(context).pop(); // Close dialog
            widget.onVerificationSuccess(); // Proceed to dashboard
          });
        } else {
          _showSnackBar(decoded['message'] ?? "Invalid OTP", Colors.red);
        }
      } else {
        String errorMessage = "Verification failed";
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage = errorBody['message'] ?? errorBody['error']?['cause'] ?? errorMessage;
        } catch (e) {
          // Use default message
        }
        _showSnackBar(errorMessage, Colors.red);
      }
    } catch (e) {
      debugPrint('❌ Error verifying OTP: $e');
      _showSnackBar("Network error: ${e.toString()}", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOTP() async {
    if (!_isResendEnabled) return;

    setState(() => _isLoading = true);

    try {
      final headers = await _getHeaders();
      
      final body = {
        "email": _currentEmail.isNotEmpty ? _currentEmail : _currentPhone,
        "userId": widget.userId,
      };

      final response = await http.post(
        Uri.parse("$_baseUrl$_sendOtpUrl"),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status_code'] == 200) {
          _startResendTimer();
          _showSnackBar("OTP resent successfully", Colors.green);
          _otpController.clear();
        } else {
          _showSnackBar(decoded['message'] ?? "Failed to resend OTP", Colors.red);
        }
      } else {
        _showSnackBar("Failed to resend OTP", Colors.red);
      }
    } catch (e) {
      _showSnackBar("Error: ${e.toString()}", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primaryDarkBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _showOTPInput ? Icons.mark_email_read_rounded : Icons.verified_user_rounded,
                  color: AppColors.primaryDarkBlue,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              
              // Title
              Text(
                _showOTPInput ? "Verify OTP" : "Verify Identity",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              
              // Subtitle
              Text(
                _showOTPInput 
                    ? "Enter the 6-digit code sent to your email"
                    : "Please provide your contact details",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textBodyColor,
                ),
              ),
              const SizedBox(height: 24),

              // Input fields based on state
              if (!_showOTPInput) ...[
                // Email field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Email Address",
                      hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                      prefixIcon: Icon(Icons.email_outlined, color: AppColors.primaryDarkBlue, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // OR divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        "OR",
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Phone field
                // Container(
                //   decoration: BoxDecoration(
                //     color: Colors.grey.shade50,
                //     borderRadius: BorderRadius.circular(12),
                //     border: Border.all(color: Colors.grey.shade200),
                //   ),
                //   child: TextField(
                //     controller: _phoneController,
                //     keyboardType: TextInputType.phone,
                //     style: GoogleFonts.poppins(fontSize: 14),
                //     decoration: InputDecoration(
                //       hintText: "Phone Number",
                //       hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                //       prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primaryDarkBlue, size: 20),
                //       border: InputBorder.none,
                //       contentPadding: const EdgeInsets.symmetric(vertical: 15),
                //     ),
                //   ),
                // ),
              ] else ...[
                // OTP Input
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Pinput(
                    controller: _otpController,
                    focusNode: _pinFocusNode,
                    length: 6,
                    defaultPinTheme: PinTheme(
                      width: 45,
                      height: 50,
                      textStyle: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDarkBlue,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                    ),
                    focusedPinTheme: PinTheme(
                      width: 45,
                      height: 50,
                      textStyle: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDarkBlue,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primaryDarkBlue, width: 2),
                      ),
                    ),
                    onCompleted: (pin) {
                      _verifyOTP();
                    },
                  ),
                ),
                const SizedBox(height: 16),
                
                // Resend option
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive code? ",
                      style: GoogleFonts.poppins(
                        color: AppColors.textBodyColor,
                        fontSize: 13,
                      ),
                    ),
                    GestureDetector(
                      onTap: _isResendEnabled ? _resendOTP : null,
                      child: Text(
                        _isResendEnabled ? "Resend" : "Resend in $_resendTimer sec",
                        style: GoogleFonts.poppins(
                          color: _isResendEnabled ? AppColors.primaryDarkBlue : Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: _isResendEnabled ? TextDecoration.underline : TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // Action buttons
              if (!_showOTPInput) ...[
                // Send OTP button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDarkBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            "Send OTP",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ] else ...[
                // Verify OTP button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDarkBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            "Verify & Continue",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Cancel button
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onVerificationFailed();
                },
                child: Text(
                  "Cancel",
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}