import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:staff_mate/pages/login_page.dart';
import 'package:staff_mate/pages/register_page.dart';

// Updated Color Palette to match IPD Dashboard & Welcome Page
class AppColors {
  static const Color primaryDarkBlue = Color(0xFF1A237E); // Deep Indigo
  static const Color bgGrey = Color(0xFFF5F7FA); // Light Grey for sheet
  static const Color whiteColor = Colors.white;
  static const Color textDark = Color(0xFF1A237E);
  static final Color textBodyColor = Colors.grey.shade600;
  static const Color accentBlue = Color(0xFF0289A1); // Kept for accents if needed
}

class AuthOptionsPage extends StatelessWidget {
  const AuthOptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions
    final Size size = MediaQuery.of(context).size;
    final EdgeInsets padding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: AppColors.primaryDarkBlue,
      extendBodyBehindAppBar: true,
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
          // --- Background Decor (Consistent with Welcome Page) ---
          Positioned(
            top: -size.width * 0.2,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.8,
              height: size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          
          // --- Main Layout ---
          Column(
            children: [
              // 1. TOP SECTION: Visual/Icon area
              Expanded(
                flex: 4,
                child: SafeArea(
                  child: Center(
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
                              padding: EdgeInsets.all(size.width * 0.06),
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
                              child: Icon(
                                Icons.lock_person_rounded,
                                size: size.width * 0.18,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 2. BOTTOM SECTION: White Action Sheet
              Expanded(
                flex: 5, // Gives slightly more room to the bottom sheet
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
                      child: Padding(
                        // Add bottom padding to account for safe area (home indicator)
                        padding: EdgeInsets.fromLTRB(30, 40, 30, 30 + padding.bottom),
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

                                // Title
                                Text(
                                  'Let\'s Get Started',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: size.width * 0.075, // Responsive text
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Subtitle
                                Text(
                                  'Log in to your existing account to continue managing your hospital workflow with StaffMate.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: size.width * 0.038,
                                    color: AppColors.textBodyColor,
                                    height: 1.6,
                                  ),
                                ),
                                SizedBox(height: size.height * 0.05),

                                // Login Button
                                _buildLoginButton(context, AppColors.primaryDarkBlue, AppColors.whiteColor),
                                
                                // Spacer
                                const SizedBox(height: 16),

                                // --- REGISTER BUTTON (COMMENTED OUT AS REQUESTED) ---
                                /*
                                _buildRegisterButton(context, AppColors.primaryDarkBlue, AppColors.primaryDarkBlue),
                                const SizedBox(height: 20),
                                */
                                // ----------------------------------------------------
                              ],
                            ),
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

  Widget _buildLoginButton(BuildContext context, Color buttonColor, Color textColor) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: textColor,
          elevation: 8,
          shadowColor: buttonColor.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Login',
              style: GoogleFonts.poppins(
                fontSize: 18, 
                fontWeight: FontWeight.w600, 
                color: textColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.login_rounded, size: 22),
          ],
        ),
      ),
    );
  }

  // --- REGISTER BUTTON HELPER (COMMENTED OUT BUT PRESERVED) ---
  /*
  Widget _buildRegisterButton(BuildContext context, Color outlineColor, Color textColor) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage()));
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: outlineColor.withOpacity(0.5), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          foregroundColor: outlineColor,
        ),
        child: Text(
          'Register',
          style: GoogleFonts.poppins(
            fontSize: 18, 
            fontWeight: FontWeight.w600, 
            color: textColor
          ),
        ),
      ),
    );
  }
  */
}