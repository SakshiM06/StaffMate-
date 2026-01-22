import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:staff_mate/services/clinic_service.dart';
import 'package:staff_mate/services/user_information_service.dart';

// Unified Color Palette
class AppColors {
  static const Color primaryDarkBlue = Color(0xFF1A237E); // Deep Indigo
  static const Color bgGrey = Color(0xFFF5F7FA); // Light Grey for sheet
  static const Color whiteColor = Colors.white;
  static const Color textDark = Color(0xFF1A237E);
  static final Color textBodyColor = Colors.grey.shade600;
  static const Color errorRed = Color(0xFFE53935);
  static const Color accentBlue = Color(0xFF0289A1);
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // --- EXISTING LOGIC VARIABLES ---
  bool _obscurePassword = true;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // --- EXISTING BACKEND LOGIC (UNCHANGED) ---
  Future<void> _login() async {
    if (_isLoading) return;
    
    // Validation
    if (_usernameController.text.trim().isEmpty) {
      _showErrorDialog("Please enter your username");
      return;
    }
    
    if (_passwordController.text.trim().isEmpty) {
      _showErrorDialog("Please enter your password");
      return;
    }

    setState(() => _isLoading = true);

    const String apiUrl = "https://test.smartcarehis.com:443/security/auth/login";
    final headers = {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    };
    final body = jsonEncode({
      "userName": _usernameController.text.trim(),
      "password": _passwordController.text.trim(),
      "forceLogin": false
    });

    try {
      final response = await http.post(
        Uri.parse(apiUrl), 
        headers: headers, 
        body: body
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final innerData = decoded['data'];
        
        if (innerData == null) {
          _showErrorDialog("Invalid response from server");
          return;
        }

        final subscriptionDays = innerData['subscription_remaining_days'] ?? 0;
        if (subscriptionDays <= 0) {
          _showErrorDialog("Your subscription has expired. Please contact support.");
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        final bearer = innerData['bearer'] ?? '';
        final token = innerData['token'] ?? '';
        final clinicId = innerData['clinicid'] ?? '';
        final userId = innerData['userId'] ?? '';
        final zoneid = innerData['zoneid'] ?? 'Asia/Kolkata';
        final expiryTime = innerData['expirytime'] ?? '';

        await prefs.setString('bearer', bearer);
        await prefs.setString('auth_token', token);
        await prefs.setString('clinicId', clinicId);
        await prefs.setString('userId', userId);
        await prefs.setString('zoneid', zoneid);
        await prefs.setString('expiryTime', expiryTime);
        await prefs.setInt('subscription_remaining_days', subscriptionDays);

        try {
          final clinicService = ClinicService();
          await clinicService.fetchAndSaveClinicDetails(
            token: token,
            clinicId: clinicId,
            userId: userId,
            zoneid: zoneid,
            branchId: 1, 
          );
        } catch (clinicError) {
          debugPrint("⚠️ Clinic details fetch failed: $clinicError");
        }

        try {
          final userInfoService = UserInformationService();
          await userInfoService.fetchAndSaveUserInformation(
            token: token,
            clinicId: clinicId,
            userId: userId,
            zoneid: zoneid,
            branchId: 1, 
          );
        } catch (userError) {
          debugPrint("⚠️ User information fetch failed: $userError");
        }

        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/dashboard');
        
      } else if (response.statusCode == 401) {
        _showErrorDialog("Invalid username or password");
      } else if (response.statusCode == 409) {
        _showErrorDialog("You are already logged in on another device. Please logout there first.");
      } else {
        _showErrorDialog("Login failed (Status ${response.statusCode}). Please try again.");
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog("Network error. Please check your connection and try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Login Failed",
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

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- NEW UI IMPLEMENTATION ---
  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    // Essential for preventing keyboard overlap
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final EdgeInsets padding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: AppColors.primaryDarkBlue,
      extendBodyBehindAppBar: true,
      // ✅ FIX: Prevents layout overflow when keyboard opens
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
          // Background Decor
          Positioned(
            top: -size.width * 0.2,
            right: -size.width * 0.2,
            child: _buildCircle(size.width * 0.8, Colors.white.withValues(alpha: 0.05)),
          ),
          Positioned(
            top: size.height * 0.2,
            left: -size.width * 0.1,
            child: _buildCircle(size.width * 0.4, Colors.white.withValues(alpha: 0.03)),
          ),

          // Main Content
          Column(
            children: [
              // 1. TOP SECTION: Logo
              Expanded(
                flex: 4, // 40% height
                child: SafeArea(
                  child: Center(
                    // ✅ FIX: SingleChildScrollView prevents tiny overflows on small screens
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: AnimationLimiter(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: AnimationConfiguration.toStaggeredList(
                            duration: const Duration(milliseconds: 600),
                            childAnimationBuilder: (widget) => ScaleAnimation(
                              child: FadeInAnimation(child: widget),
                            ),
                            children: [
                              Container(
                                padding: EdgeInsets.all(size.width * 0.05),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/images/welcomesm.png',
                                  height: size.width * 0.25,
                                  fit: BoxFit.contain,
                                  errorBuilder: (c, o, s) => Icon(
                                    Icons.local_hospital_rounded,
                                    size: size.width * 0.2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(height: size.height * 0.02),
                              Text(
                                "Welcome Back",
                                style: GoogleFonts.poppins(
                                  fontSize: size.width * 0.065,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.whiteColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 2. BOTTOM SECTION: White Action Sheet (Form)
              Expanded(
                flex: 6, // 60% height
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
                      // Add bottom inset padding to handle keyboard
                      padding: EdgeInsets.fromLTRB(30, 40, 30, 30 + bottomInset + padding.bottom),
                      child: AnimationLimiter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: AnimationConfiguration.toStaggeredList(
                            duration: const Duration(milliseconds: 600),
                            childAnimationBuilder: (widget) => SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(child: widget),
                            ),
                            children: [
                              // Handle bar
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
                                "Login to StaffMate",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: size.width * 0.06,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Please enter your credentials below",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: size.width * 0.035,
                                  color: AppColors.textBodyColor,
                                ),
                              ),
                              
                              const SizedBox(height: 30),

                              // Username Field
                              _buildTextField(
                                controller: _usernameController,
                                hint: 'Username',
                                icon: Icons.person_outline_rounded,
                              ),
                              
                              const SizedBox(height: 16),

                              // Password Field
                              _buildTextField(
                                controller: _passwordController,
                                hint: 'Password',
                                icon: Icons.lock_outline_rounded,
                                isPassword: true,
                              ),
                              
                              // Forgot Password
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    // Logic preserved
                                    debugPrint("Forgot Password pressed!");
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: Text(
                                    "Forgot Password?",
                                    style: GoogleFonts.poppins(
                                      color: AppColors.primaryDarkBlue,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 25),

                              // Login Button
                              _buildLoginButton(),
                            ],
                          ),
                        ),
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
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        cursorColor: AppColors.primaryDarkBlue,
        style: GoogleFonts.poppins(color: AppColors.textDark, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            color: Colors.grey.shade400,
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: AppColors.primaryDarkBlue.withValues(alpha: 0.7), size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                )
              : null,
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

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDarkBlue,
          foregroundColor: AppColors.whiteColor,
          elevation: 8,
          shadowColor: AppColors.primaryDarkBlue.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
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
                    "Login",
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
}