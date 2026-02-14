import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:staff_mate/pages/login_page.dart';
import 'package:staff_mate/services/forgetpassword_service.dart';

class AppColors {
  static const Color primaryDarkBlue = Color(0xFF1A237E); 
  static const Color bgGrey = Color(0xFFF5F7FA); 
  static const Color whiteColor = Colors.white;
  static const Color textDark = Color(0xFF1A237E);
  static final Color textBodyColor = Colors.grey.shade600;
  static const Color errorRed = Color(0xFFE53935);
  static const Color accentBlue = Color(0xFF0289A1);
  static const Color successGreen = Color(0xFF4CAF50);
  static final Color borderColor = Colors.grey.shade300;
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  int _remainingTime = 300; 
  late Timer _timer;
  
  final ForgetPasswordService _passwordService = ForgetPasswordService();

  String? _otpError;
  bool _showResendOption = false;
  String? _currentUserId;
  String? _currentEmail;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadSavedData();
  }

  @override
  void dispose() {
    _timer.cancel();
    _emailController.dispose();
    _userIdController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    try {
      final resetData = await _passwordService.getResetData();
      if (resetData['email']?.isNotEmpty == true) {
        _emailController.text = resetData['email']!;
      }
      if (resetData['userId']?.isNotEmpty == true) {
        _userIdController.text = resetData['userId']!;
      }
      if (resetData['otp']?.isNotEmpty == true) {
        _otpController.text = resetData['otp']!;
      }
    } catch (e) {
      debugPrint('Error loading saved data: $e');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        setState(() {
          _showResendOption = true;
        });
        timer.cancel();
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  Future<void> _sendOtp() async {
    if (_isLoading) return;

    if (_emailController.text.trim().isEmpty) {
      _showErrorDialog("Please enter your email address");
      return;
    }

    if (_userIdController.text.trim().isEmpty) {
      _showErrorDialog("Please enter your User ID");
      return;
    }

    if (!_passwordService.isValidEmail(_emailController.text.trim())) {
      _showErrorDialog("Please enter a valid email address");
      return;
    }

    setState(() {
      _isLoading = true;
      _otpError = null;
    });

    _currentEmail = _emailController.text.trim();
    _currentUserId = _userIdController.text.trim();

 
    final result = await _passwordService.sendEmailOTP(
      email: _currentEmail!,
      userId: _currentUserId!,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      await _passwordService.saveResetData(
        email: _currentEmail!,
        userId: _currentUserId!,
      );
      
      setState(() {
        _otpSent = true;
        _remainingTime = 300;
        _showResendOption = false;
        _startTimer();
      });

      _showSuccessDialog(
        "OTP Sent",
        result['message'] ?? "A 6-digit OTP has been sent to your email $_currentEmail",
      );
    } else {
      _showErrorDialog(result['message'] ?? "Failed to send OTP. Please try again.");
    }
  }

  Future<void> _verifyOtp() async {
    if (_isLoading) return;

    if (_otpController.text.trim().isEmpty) {
      setState(() {
        _otpError = "Please enter the OTP";
      });
      return;
    }

    if (!_passwordService.isValidOTP(_otpController.text.trim())) {
      setState(() {
        _otpError = "OTP must be 6 digits";
      });
      return;
    }

    if (_currentUserId == null) {
      _showErrorDialog("Please enter your User ID first");
      return;
    }

    setState(() {
      _isLoading = true;
      _otpError = null;
    });


    final result = await _passwordService.verifyOTP(
      userOtp: _otpController.text.trim(),
      userId: _currentUserId!,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      await _passwordService.saveResetData(
        email: _currentEmail!,
        userId: _currentUserId!,
        otp: _otpController.text.trim(),
      );
      
      setState(() {
        _otpVerified = true;
      });
      
      _showSuccessDialog(
        "OTP Verified",
        result['message'] ?? "Your OTP has been verified successfully. You can now set a new password.",
      );
    } else {
      setState(() {
        _otpError = result['message'] ?? "Invalid or expired OTP";
      });
    }
  }

  Future<void> _resetPassword() async {
    if (_isLoading) return;

  
    if (_newPasswordController.text.trim().isEmpty) {
      _showErrorDialog("Please enter a new password");
      return;
    }

    final passwordValidation = _passwordService.validatePassword(_newPasswordController.text.trim());
    if (!passwordValidation['isValid']) {
      _showErrorDialog(passwordValidation['errors'].first.toString());
      return;
    }

    if (_confirmPasswordController.text.trim().isEmpty) {
      _showErrorDialog("Please confirm your new password");
      return;
    }

    if (_newPasswordController.text.trim() != _confirmPasswordController.text.trim()) {
      _showErrorDialog("Passwords do not match");
      return;
    }

    if (_currentEmail == null || _currentUserId == null) {
      _showErrorDialog("Session expired. Please start the process again.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

  
    final result = await _passwordService.updatePassword(
      password: _newPasswordController.text.trim(),
      email: _currentEmail!,
      userId: _currentUserId!,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
        await _passwordService.clearResetData();
    
      _showSuccessDialog(
        "Password Updated",
        result['message'] ?? "Your password has been updated successfully. You can now login with your new password.",
        onDismiss: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        },
      );
    } else {
      _showErrorDialog(result['message'] ?? "Failed to update password. Please try again.");
    }
  }

  void _resendOtp() {
    if (_currentEmail == null || _currentUserId == null) {
      _showErrorDialog("Please enter your email and user ID first");
      return;
    }
    
    setState(() {
      _showResendOption = false;
      _remainingTime = 300;
      _otpError = null;
      _otpController.clear();
    });
    _startTimer();
    _sendOtp();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Error",
          style: GoogleFonts.poppins(
            color: AppColors.errorRed,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(color: AppColors.textBodyColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "OK",
              style: GoogleFonts.poppins(
                color: AppColors.primaryDarkBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message, {VoidCallback? onDismiss}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: AppColors.successGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(color: AppColors.textBodyColor),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDismiss?.call();
            },
            child: Text(
              "OK",
              style: GoogleFonts.poppins(
                color: AppColors.primaryDarkBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final EdgeInsets padding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: AppColors.primaryDarkBlue,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -size.width * 0.2,
            right: -size.width * 0.2,
            child: _buildCircle(size.width * 0.8, Colors.white.withOpacity(0.05)),
          ),
          Positioned(
            top: size.height * 0.2,
            left: -size.width * 0.1,
            child: _buildCircle(size.width * 0.4, Colors.white.withOpacity(0.03)),
          ),

          Column(
            children: [
              Expanded(
                flex: 3,
                child: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(size.width * 0.05),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.lock_reset_rounded,
                              size: size.width * 0.2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: size.height * 0.02),
                          Text(
                            "Reset Password",
                            style: GoogleFonts.poppins(
                              fontSize: size.width * 0.065,
                              fontWeight: FontWeight.bold,
                              color: AppColors.whiteColor,
                            ),
                          ),
                          SizedBox(height: size.height * 0.01),
                          Text(
                            "Secure your account access",
                            style: GoogleFonts.poppins(
                              fontSize: size.width * 0.035,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Expanded(
                flex: 7,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.bgGrey,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(30, 40, 30, 30 + bottomInset + padding.bottom),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 25),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),

                          Text(
                            _otpVerified ? "Set New Password" : "Forgot Password",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: size.width * 0.06,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _otpVerified 
                                ? "Create a strong new password"
                                : "Enter your details to receive OTP",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: size.width * 0.035,
                              color: AppColors.textBodyColor,
                            ),
                          ),
                          
                          const SizedBox(height: 30),

                          if (!_otpSent && !_otpVerified) ...[
                            _buildTextField(
                              controller: _emailController,
                              hint: 'Email Address',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            
                            const SizedBox(height: 16),

                            _buildTextField(
                              controller: _userIdController,
                              hint: 'User ID',
                              icon: Icons.person_outline_rounded,
                            ),
                            
                            const SizedBox(height: 30),

                         
                            _buildActionButton(
                              text: "Send OTP",
                              onPressed: _sendOtp,
                              isLoading: _isLoading,
                            ),
                          ],

                          if (_otpSent && !_otpVerified) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                              decoration: BoxDecoration(
                                color: AppColors.primaryDarkBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primaryDarkBlue.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    color: AppColors.primaryDarkBlue,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "OTP expires in ${_formatTime(_remainingTime)}",
                                    style: GoogleFonts.poppins(
                                      color: AppColors.primaryDarkBlue,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 20),

                            _buildTextField(
                              controller: _otpController,
                              hint: 'Enter 6-digit OTP',
                              icon: Icons.password_outlined,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                            ),
                            
                            if (_otpError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _otpError!,
                                style: GoogleFonts.poppins(
                                  color: AppColors.errorRed,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            
                            const SizedBox(height: 20),

                            _buildActionButton(
                              text: "Verify OTP",
                              onPressed: _verifyOtp,
                              isLoading: _isLoading,
                            ),
                            
                            const SizedBox(height: 16),

                            if (_showResendOption)
                              TextButton(
                                onPressed: _resendOtp,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.refresh_rounded,
                                      color: AppColors.primaryDarkBlue,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Resend OTP",
                                      style: GoogleFonts.poppins(
                                        color: AppColors.primaryDarkBlue,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],

                          if (_otpVerified) ...[
                            _buildPasswordField(
                              controller: _newPasswordController,
                              hint: 'New Password',
                              isObscure: _obscureNewPassword,
                              onToggle: () {
                                setState(() {
                                  _obscureNewPassword = !_obscureNewPassword;
                                });
                              },
                            ),
                            
                            const SizedBox(height: 16),

                            _buildPasswordField(
                              controller: _confirmPasswordController,
                              hint: 'Confirm New Password',
                              isObscure: _obscureConfirmPassword,
                              onToggle: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            
                            const SizedBox(height: 30),

                            _buildActionButton(
                              text: "Reset Password",
                              onPressed: _resetPassword,
                              isLoading: _isLoading,
                            ),
                            
                            const SizedBox(height: 16),

                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Password must contain:",
                                    style: GoogleFonts.poppins(
                                      color: AppColors.textDark,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildRequirement("At least 6 characters", true),
                                  _buildRequirement("Uppercase & lowercase letters", true),
                                  _buildRequirement("At least one number", false),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        cursorColor: AppColors.primaryDarkBlue,
        style: GoogleFonts.poppins(color: AppColors.textDark, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey.shade400,
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: AppColors.primaryDarkBlue.withOpacity(0.7), size: 22),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool isObscure,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        cursorColor: AppColors.primaryDarkBlue,
        style: GoogleFonts.poppins(color: AppColors.textDark, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey.shade400,
            fontSize: 14,
          ),
          prefixIcon: Icon(Icons.lock_outline_rounded, 
              color: AppColors.primaryDarkBlue.withOpacity(0.7), size: 22),
          suffixIcon: IconButton(
            icon: Icon(
              isObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.grey.shade400,
              size: 20,
            ),
            onPressed: onToggle,
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback onPressed,
    required bool isLoading,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDarkBlue,
          foregroundColor: AppColors.whiteColor,
          elevation: 8,
          shadowColor: AppColors.primaryDarkBlue.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: AppColors.whiteColor,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    text,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 22),
                ],
              ),
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            color: isMet ? AppColors.successGreen : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.poppins(
              color: isMet ? AppColors.successGreen : Colors.grey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}