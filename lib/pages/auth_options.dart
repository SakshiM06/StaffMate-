import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:staff_mate/pages/login_page.dart';
import 'package:staff_mate/pages/register_page.dart';

// Define the new color palette as a separate class
class AppColors {
  static const Color primaryDarkBlue = Color(0xFF0D1B2A);
  static const Color midDarkBlue = Color(0xFF1B263B);
  static const Color accentBlue = Color(0xFF0289A1);
  static const Color lightBlue = Color(0xFF87CEEB);
  static const Color whiteColor = Colors.white;
  static const Color textDark = primaryDarkBlue;
  static const Color textBodyColor = Color(0xFF4A5568);
  static const Color lightGreyColor = Color(0xFFF7FAFC);
}

class AuthOptionsPage extends StatelessWidget {
  const AuthOptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGreyColor, // Using lightGreyColor for background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const _AuthOptionsBody(),
    );
  }
}

class _AuthOptionsBody extends StatelessWidget {
  const _AuthOptionsBody();

  @override
  Widget build(BuildContext context) {
    // Get the screen height
    final double screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      child: AnimationLimiter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 500),
              childAnimationBuilder: (widget) => SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: widget,
                ),
              ),
              children: [
                // Flexible space at the top to push content towards the center/bottom
                SizedBox(height: screenHeight * 0.1), // Adjusted based on screen height

                // Enhanced Title
                Text(
                  'Let\'s Get Started',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDarkBlue, // Using primaryDarkBlue for title
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Log in to your existing account or create a new one to continue with StaffMate.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    color: AppColors.textBodyColor, // Using textBodyColor for body text
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 60),

                // Login Button
                _buildLoginButton(context, AppColors.accentBlue, AppColors.whiteColor), 
                const SizedBox(height: 16),

                // Register Button
                _buildRegisterButton(context, AppColors.accentBlue, AppColors.primaryDarkBlue), 
                const SizedBox(height: 40),

                SizedBox(height: screenHeight * 0.05), 
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context, Color buttonColor, Color textColor) {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        minimumSize: const Size(double.infinity, 58), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), 
        elevation: 8, // More prominent shadow
        shadowColor: buttonColor.withValues(alpha: .4),
      ),
      child: Text(
        'Login',
        style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700, color: textColor),
      ),
    );
  }

  Widget _buildRegisterButton(BuildContext context, Color outlineColor, Color textColor) {
    return OutlinedButton(
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage()));
      },
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: outlineColor, width: 2), // Thicker outline
        minimumSize: const Size(double.infinity, 58), // Slightly larger button
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), // More rounded corners
      ),
      child: Text(
        'Register',
        style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700, color: textColor),
      ),
    );
  }
}