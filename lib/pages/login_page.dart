import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

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

  // Future<void> _login() async {
  //   if (_isLoading) return; // Prevent multiple login attempts
  //   setState(() => _isLoading = true);

  //   const String apiUrl = "https://test.smartcarehis.com:8443/security/auth/login";
  //   final headers = {"Content-Type": "application/json"};
  //   final body = jsonEncode({
  //     "userName": _usernameController.text.trim(),
  //     "password": _passwordController.text.trim(),
  //   });

  //   try {
  //     final response = await http.post(Uri.parse(apiUrl), headers: headers, body: body);
  //     if (!mounted) return; // Check if the widget is still mounted
  //     debugPrint("Status: ${response.statusCode}");
  //     debugPrint("Body: ${response.body}");

  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       final innerData = data.data['data'];

  //       if (innerData != null) {
  //         final prefs = await SharedPreferences.getInstance();
  //         await prefs.setString('auth_token', innerData['token'] ?? '');
  //         // await prefs.setString('username', _usernameController.text.trim());
  //         // await prefs.setString('staffId', 'S-12345'); // Example default
  //         // await prefs.setString('role', 'Physician'); // Example default 
  //         // await prefs.setString('dept', 'Cardiology'); // Example default
  //         await prefs.setString('clinicId', innerData['clinicId'] ?? '');
  //         await prefs.setString('branchId', innerData['branchId'] ?? '');
  //         await prefs.setString('userId', innerData['userId'] ?? '');
  //         await prefs.setString('zoneId', innerData['zone'] ?? '');
  //         await prefs.setString('expiryTime', innerData['expiryTime'] ?? '');
          

  //         if (!mounted) return;
  //         Navigator.pushReplacementNamed(context, '/dashboard');
  //       } else {
  //         _showErrorDialog("Login failed: Invalid response from server.");
  //       }
  //     } else {
  //       final errorMsg = jsonDecode(response.body)['message'] ?? "Invalid credentials";
  //       _showErrorDialog("$errorMsg (${response.statusCode})");
  //     }
  //   } catch (e) {
  //     if (!mounted) return;
  //     _showErrorDialog("Something went wrong: Please check your connection. Error: $e");
  //   } finally {
  //     if (mounted) setState(() => _isLoading = false); // Ensure state is updated only if mounted
  //   }
  // }
Future<void> _login() async {
  if (_isLoading) return; // Prevent multiple login attempts
  setState(() => _isLoading = true);

  const String apiUrl = "https://test.smartcarehis.com:8443/security/auth/login";
  final headers = {"Content-Type": "application/json"};
  final body = jsonEncode({
    "userName": _usernameController.text.trim(),
    "password": _passwordController.text.trim(),
  });

  try {
    final response = await http.post(Uri.parse(apiUrl), headers: headers, body: body);
    if (!mounted) return;

    debugPrint("Status: ${response.statusCode}");
    debugPrint("Body: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final innerData = decoded['data']; // ✅ fixed
    debugPrint("inner: ${innerData['bearer']}");

      if (innerData != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('bearer', innerData['bearer'] ?? '');
        await prefs.setString('auth_token', innerData['token'] ?? '');
        await prefs.setString('clinicId', innerData['clinicid'] ?? '');
        await prefs.setString('userId', innerData['userId'] ?? '');
        await prefs.setString('zoneId', innerData['zoneid'] ?? '');
        await prefs.setString('expiryTime', innerData['expirytime'] ?? '');
        await prefs. setInt('branchId', innerData['branch_id'] ?? 0);

        // Navigate to dashboard page
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        _showErrorDialog("Unexpected response from server.");
      }
    } else {
      debugPrint('Login failed: ${response.statusCode}');
      _showErrorDialog(
          "Invalid username or password (Status ${response.statusCode}).");
    }
  } catch (e) {
    debugPrint('Error: $e');
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
            // Use a Column directly inside SingleChildScrollView to allow natural scrolling
            // and remove fixed height constraints that might cause overflow.
            child: AnimationLimiter(
              child: Column(
                // Use MainAxisAlignment.center to center content vertically if there's extra space
                // and MainAxisSize.min to prevent the column from taking more space than its children need.
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min, // Essential for Column inside SingleChildScrollView
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
                        icon: const Icon(Icons.arrow_back_ios, color: AppColors.whiteColor),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    // Removed Expanded here to allow flexible sizing based on content
                    // and available space, especially when keyboard is visible.
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0), // Add some padding
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Ensure 'assets/images/welcomesm.png' exists in pubspec.yaml and in the correct path
                          // Added a simple error builder for debugging image loading issues
                          Image.asset(
                            'assets/images/welcomesm.png',
                            height: MediaQuery.of(context).size.height * 0.18,
                            errorBuilder: (context, error, stackTrace) => const Icon(
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
                    // Removed Expanded here as well. The login box will now size based on its content.
                    // Added a spacer to push the login box down if there's empty space,
                    // but it will shrink when the keyboard appears.
                    // Using a Flexible space for better behavior with keyboard
                    Flexible(
                      fit: FlexFit.loose, // Allow it to take available space but shrink
                      child: const SizedBox(height: 20), // Minimum space
                    ),
                    _buildFloatingLoginBox(),
                    // Another Flexible space to help center or push down the content
                    Flexible(
                      fit: FlexFit.loose,
                      child: SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 0 : 20),
                    ),
                    // Add a small bottom padding to ensure the last elements are not cut off
                    // Adjust this based on your design for when the keyboard is not active
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
            color: Colors.black.withValues(alpha: .15), // Corrected withValues to withOpacity
            blurRadius: 25,
            offset: const Offset(0, 15),
          ),
        ], 
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Ensures the column only takes needed space
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
                // Handle forgot password logic here
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
        hintStyle: GoogleFonts.nunito(color: AppColors.primaryDarkBlue.withValues(alpha: .7)), // Corrected withValues
        prefixIcon: Icon(icon, color: AppColors.primaryDarkBlue),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.primaryDarkBlue.withValues(alpha: .6), // Corrected withValues
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : null,
        filled: true,
        fillColor: AppColors.primaryDarkBlue.withValues(alpha: .05), // Corrected withValues
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.primaryDarkBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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
          shadowColor: AppColors.primaryDarkBlue.withValues(alpha: .6), // Corrected withValues
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