import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:staff_mate/pages/login_page.dart';
import 'package:staff_mate/pages/dashboard_page.dart';
import 'package:staff_mate/services/session_manger.dart';
import 'package:staff_mate/services/biometric_auth_service.dart';
import 'package:staff_mate/services/session_bootstrap.dart';

class SessionChecker extends StatefulWidget {
  const SessionChecker({super.key});

  @override
  State<SessionChecker> createState() => _SessionCheckerState();
}

class _SessionCheckerState extends State<SessionChecker>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _showBiometricPrompt = false;
  bool _hasValidSession = false;
  bool _isAuthenticating = false;
  String _biometricLabel = 'Biometrics';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-trigger biometric if app comes back to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _showBiometricPrompt) {
      _triggerBiometric();
    }
  }

  Future<void> _checkSession() async {
    // Check if user has ever logged in (uses secure storage now)
    final hasPreviousLogin = await SessionManager.hasPreviousLogin();

    if (!hasPreviousLogin) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Check if we should show biometric (independent of token validity)
    final biometricSessionActive =
        await SessionManager.isBiometricSessionActive();
    final biometricEnabled = await BiometricAuthService.isBiometricEnabled();
    final biometricAvailable = await BiometricAuthService.isBiometricAvailable();

    if (biometricSessionActive && biometricEnabled && biometricAvailable) {
      _biometricLabel = await BiometricAuthService.getBiometricLabel();
      if (mounted) {
        setState(() {
          _showBiometricPrompt = true;
          _isLoading = false;
        });
      }
      // Auto-trigger the system prompt
      await Future.delayed(const Duration(milliseconds: 400));
      _triggerBiometric();
      return;
    }

    // No biometric — check token validity for dashboard vs login
    _hasValidSession = await SessionManager.hasValidSession();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isLoading = false);
  }

Future<void> _triggerBiometric() async {
  if (_isAuthenticating || !mounted) return;
  setState(() => _isAuthenticating = true);

  final authenticated = await BiometricAuthService.authenticate();

  if (!mounted) return;
  setState(() => _isAuthenticating = false);

  if (authenticated) {
    // ✅ Run bootstrap BEFORE going to dashboard
    await SessionBootstrap.run();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardPage()),
    );
  }
}

  Future<void> _skipBiometric() async {
    // Don't clear auth data here — just navigate to login
    // LoginPage will pre-fill username from last_username
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSplashScreen();
    if (_showBiometricPrompt) return _buildBiometricScreen();
    return _hasValidSession ? const DashboardPage() : const LoginPage();
  }

  Widget _buildSplashScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                errorBuilder: (c, o, s) => const Icon(
                  Icons.local_hospital_rounded,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            const SizedBox(height: 20),
            Text("SmartMate",
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Loading...",
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated biometric icon
            GestureDetector(
              onTap: _triggerBiometric,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isAuthenticating
                      ? Colors.white.withOpacity(0.25)
                      : Colors.white.withOpacity(0.1),
                  border: Border.all(color: Colors.white38, width: 2),
                ),
                child: _isAuthenticating
                    ? const Padding(
                        padding: EdgeInsets.all(30),
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Icon(Icons.fingerprint,
                        size: 56, color: Colors.white),
              ),
            ),

            const SizedBox(height: 28),

            Text("Welcome Back",
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              "Tap to verify with $_biometricLabel",
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isAuthenticating ? null : _triggerBiometric,
                icon: const Icon(Icons.fingerprint),
                label: Text("Authenticate with $_biometricLabel",
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1A237E),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextButton(
              onPressed: _skipBiometric,
              child: Text("Use Password Instead",
                  style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}