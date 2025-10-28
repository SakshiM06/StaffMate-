import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:staff_mate/pages/dashboard_page.dart';
import 'package:google_fonts/google_fonts.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  RegisterPageState createState() => RegisterPageState();
}

class RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  final Color primaryColor = const Color(0xFF6A7BFF);
  final Color backgroundColor = const Color(0xFFF4F6FF);
  final Color textDark = const Color(0xFF333D79);
  final Color textLight = Colors.black54;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _tryRegister() async {
    final bool isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() { _isLoading = true; });

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DashboardPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back_ios_new, color: textDark),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    // --- Header Section ---
                    const SizedBox(height: 10),
                    Text(
                      'Create Your Account',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 30),

                    AnimationLimiter(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: .1),
                              spreadRadius: 5,
                              blurRadius: 15,
                            ),
                          ],
                        ),
                      
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Form(
                            key: _formKey,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: AnimationConfiguration.toStaggeredList(
                                duration: const Duration(milliseconds: 500),
                                childAnimationBuilder: (widget) => SlideAnimation(
                                  verticalOffset: 30.0,
                                  child: FadeInAnimation(child: widget),
                                ),
                                children: [
                                  _buildTextField(
                                    controller: _nameController,
                                    hintText: 'Full Name',
                                    prefixIcon: Icons.person_outline,
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your name.' : null,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildTextField(
                                    controller: _emailController,
                                    hintText: 'Email Address',
                                    prefixIcon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Please enter your email.';
                                      if (!RegExp(r'\S+@\S+\.\S+').hasMatch(v)) return 'Enter a valid email.';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  _buildTextField(
                                    controller: _passwordController,
                                    hintText: 'Password',
                                    prefixIcon: Icons.lock_outline,
                                    isPassword: true,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Please enter a password.';
                                      if (v.length < 6) return 'Password must be at least 6 characters.';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  _buildTextField(
                                    controller: _confirmPasswordController,
                                    hintText: 'Confirm Password',
                                    prefixIcon: Icons.lock_outline,
                                    isPassword: true,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Please confirm your password.';
                                      if (v != _passwordController.text) return 'Passwords do not match.';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 30),
                                  ElevatedButton(
                                    onPressed: _isLoading ? null : _tryRegister,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 5,
                                      shadowColor: primaryColor.withValues(alpha: .4),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                          )
                                        : Text(
                                            'Create Account',
                                            style: GoogleFonts.poppins(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Already have an account?", style: GoogleFonts.nunito(color: textLight, fontSize: 16)),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              "Login",
                              style: GoogleFonts.poppins(
                                color: primaryColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: isPassword && !_isPasswordVisible,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.nunito(color: textLight.withValues(alpha: .8)),
        prefixIcon: Icon(prefixIcon, color: primaryColor.withValues(alpha: .7)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: textLight,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              )
            : null,
        filled: true,
        fillColor: backgroundColor.withValues(alpha: .8),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2.0),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }
}