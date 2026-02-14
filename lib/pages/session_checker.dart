import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:staff_mate/pages/login_page.dart';
import 'package:staff_mate/pages/dashboard_page.dart';
import 'package:staff_mate/services/session_manger.dart';
import 'package:staff_mate/services/biometric_auth_service.dart';

// AppColors from login_page
class AppColors {
  static const Color primaryDarkBlue = Color(0xFF1A237E);
  static const Color bgGrey = Color(0xFFF5F7FA);
  static const Color whiteColor = Colors.white;
  static const Color textDark = Color(0xFF1A237E);
  static final Color textBodyColor = Colors.grey.shade600;
  static const Color errorRed = Color(0xFFE53935);
  static const Color accentBlue = Color(0xFF0289A1);
}

class SessionChecker extends StatefulWidget {
  const SessionChecker({super.key});

  @override
  State<SessionChecker> createState() => _SessionCheckerState();
}

class _SessionCheckerState extends State<SessionChecker> {
  bool _isLoading = true;
  bool _showBiometricPrompt = false;
  bool _hasValidSession = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // First check if user has ever logged in before
    final hasPreviousLogin = await SessionManager.hasPreviousLogin();
    
    if (!hasPreviousLogin) {
      // First time user, go to welcome/login flow
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasValidSession = false;
        });
      }
      return;
    }

    // Check if user has a valid session
    _hasValidSession = await SessionManager.hasValidSession();
    
    if (_hasValidSession) {
      // Check biometric settings
      final biometricEnabled = await BiometricAuthService.isBiometricEnabled();
      final biometricAvailable = await BiometricAuthService.isBiometricAvailable();
      
      if (biometricEnabled && biometricAvailable) {
        // Show biometric prompt
        if (mounted) {
          setState(() {
            _showBiometricPrompt = true;
            _isLoading = false;
          });
        }
        return;
      }
    }
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _authenticateWithBiometric() async {
    final authenticated = await BiometricAuthService.authenticate();
    
    if (authenticated) {
      // Successful biometric auth, go to dashboard
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage()),
        );
      }
    } else {
      // Biometric failed, clear auth but keep username
      await SessionManager.clearAuthData();
      if (mounted) {
        setState(() {
          _showBiometricPrompt = false;
          _hasValidSession = false;
        });
      }
    }
  }

  Future<void> _skipBiometric() async {
    // User wants to skip biometric and use password
    await SessionManager.clearAuthData();
    if (mounted) {
      setState(() {
        _showBiometricPrompt = false;
        _hasValidSession = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildSplashScreen();
    }
    
    if (_showBiometricPrompt) {
      return _buildBiometricScreen();
    }
    
    // Return to original flow based on session
    return _hasValidSession ? const DashboardPage() : const LoginPage();
  }

  Widget _buildSplashScreen() {
    return Scaffold(
      backgroundColor: AppColors.primaryDarkBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Your app logo
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
              child: Image.asset(
                'assets/images/welcomesm.png',
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (c, o, s) => Icon(
                  Icons.local_hospital_rounded,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              "StaffMate",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Loading...",
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricScreen() {
    return Scaffold(
      backgroundColor: AppColors.primaryDarkBlue,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Biometric icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
              child: const Icon(
                Icons.fingerprint,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              "Welcome Back",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Use biometrics to quickly access your account",
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            
            // Biometric Auth Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _authenticateWithBiometric,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryDarkBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fingerprint, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      "Authenticate",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Use Password Instead
            TextButton(
              onPressed: _skipBiometric,
              child: Text(
                "Use Password Instead",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}