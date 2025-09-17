import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

// ✅ import your services here
import 'package:staff_mate/services/clinic_service.dart';
import 'package:staff_mate/services/user_information_service.dart';

class AppColors {
  static const Color primaryDarkBlue = Color(0xFF1A2C42);
  static const Color midDarkBlue = Color(0xFF273F5A);
  static const Color accentTeal = Color(0xFF00C897);
  static const Color darkerAccentTeal = Color(0xFF00A37D);
  static const Color lightBlue = Color(0xFF66D7EE);
  static const Color whiteColor = Colors.white;
  static const Color textDark = primaryDarkBlue;
  static const Color textBodyColor = Color(0xFF90A4AE);
  static const Color lightGreyColor = Color(0xFFF0F4F8);
  static const Color fieldFillColor = Color(0xFFE3E8ED);
  static const Color errorRed = Color(0xFFE53935);
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscurePassword = true;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    const String apiUrl = "https://test.smartcarehis.com:8443/security/auth/login";
    final headers = {"Content-Type": "application/json"};
    final body = jsonEncode({
      "userName": _usernameController.text.trim(),
      "password": _passwordController.text.trim(),
    });

    try {
      final response =
          await http.post(Uri.parse(apiUrl), headers: headers, body: body);
      if (!mounted) return;

      debugPrint("Status: ${response.statusCode}");
      debugPrint("Body: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final innerData = decoded['data'];
              debugPrint("Body_ppppppppp: $innerData");

        if (innerData != null) {
          // ✅ save token and other info
          final prefs = await SharedPreferences.getInstance();
          final token = innerData['token'] ?? '';
          await prefs.setString('bearer', innerData['bearer'] ?? '');
          await prefs.setString('auth_token', token);
          await prefs.setString('clinicId', innerData['clinicid'] ?? 'aureus');
          await prefs.setString('userId', innerData['userId'] ?? 'aureus');
          await prefs.setString('zoneId', innerData['zoneid'] ?? 'Asia/Kolkata');
          await prefs.setString('expiryTime', innerData['expirytime'] ?? '');

          // ✅ immediately call ClinicService to fetch & save clinic details
          final clinicService = ClinicService();
          await clinicService.fetchAndSaveClinicDetails(
            token: token,
            clinicId: innerData['clinicid'] ?? 'aureus',
            userId: innerData['userId'] ?? 'aureus',
            zoneId: innerData['zoneid'] ?? 'Asia/Kolkata',
            branchId: innerData['branch_id'] ?? 1,
          );

          // ✅ NEW: call UserInformationService to fetch & save user information
          final userInfoService = UserInformationService();
          await userInfoService.fetchAndSaveUserInformation(
            token: token,
            clinicId: innerData['clinicid'] ?? 'aureus',
            userId: innerData['userId'] ?? 'aureus',
            zoneId: innerData['zoneid'] ?? 'Asia/Kolkata',
            branchId: innerData['branch_id'] ?? 1,
          );

          if (!mounted) return;
          // ✅ navigate to dashboard/home after success
          Navigator.pushReplacementNamed(context, '/dashboard');
        } else {
          _showErrorDialog("Unexpected response from server.");
        }
      } else {
        _showErrorDialog(
            "Invalid username or password (Status ${response.statusCode}).");
      }
    } catch (e) {
      _showErrorDialog("An error occurred. Please try again.\n\n$e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Login Failed",
          style: GoogleFonts.poppins(
            color: AppColors.errorRed,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.nunito(color: AppColors.textBodyColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "OK",
              style: GoogleFonts.poppins(
                color: AppColors.accentTeal,
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryDarkBlue,
              AppColors.midDarkBlue,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: AnimationLimiter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: AnimationConfiguration.toStaggeredList(
                  duration: const Duration(milliseconds: 500),
                  childAnimationBuilder: (widget) => SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(child: widget),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: AppColors.whiteColor),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/welcomesm.png',
                            height: MediaQuery.of(context).size.height * 0.18,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.image_not_supported_outlined,
                              color: AppColors.whiteColor,
                              size: 80,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Welcome Back",
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.whiteColor,
                            ),
                          ),
                          Text(
                            "Login to your StaffMate account",
                            style: GoogleFonts.nunito(
                              fontSize: 18,
                              color: AppColors.lightBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildFloatingLoginBox(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingLoginBox() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 25.0),
      padding: const EdgeInsets.all(30.0),
      decoration: BoxDecoration(
        color: AppColors.whiteColor,
        borderRadius: BorderRadius.circular(30.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .15),
            blurRadius: 25,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTextField(
            controller: _usernameController,
            hint: 'Username',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _passwordController,
            hint: 'Password',
            icon: Icons.lock_outline,
            isPassword: true,
          ),
          const SizedBox(height: 13),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                debugPrint("Forgot Password pressed!");
              },
              child: Text(
                "Forgot Password?",
                style: GoogleFonts.poppins(
                  color: AppColors.primaryDarkBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 25),
          _buildLoginButton(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      cursorColor: AppColors.primaryDarkBlue,
      style: GoogleFonts.nunito(color: AppColors.primaryDarkBlue),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunito(
            color: AppColors.primaryDarkBlue.withValues(alpha: .7)),
        prefixIcon: Icon(icon, color: AppColors.primaryDarkBlue),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.primaryDarkBlue.withValues(alpha: .6),
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : null,
        filled: true,
        fillColor: AppColors.primaryDarkBlue.withValues(alpha: .05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide:
              const BorderSide(color: AppColors.primaryDarkBlue, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDarkBlue,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 10,
          shadowColor: AppColors.primaryDarkBlue.withValues(alpha: .6),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: AppColors.whiteColor,
                  strokeWidth: 3,
                ),
              )
            : Text(
                "Login",
                style: GoogleFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.whiteColor,
                ),
              ),
      ),
    );
  }
}
