import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:staff_mate/services/biometric_auth_service.dart';
import 'package:staff_mate/services/session_manger.dart';
import 'package:staff_mate/api/api_service.dart';

class BiometricLockScreen extends StatefulWidget {
  final bool isFromSettings;
  final VoidCallback onContinue;

  const BiometricLockScreen({
    super.key,
    this.isFromSettings = false,
    required this.onContinue,
  });

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  bool _isAuthenticating = false;
  bool _authFailed = false;
  int _failCount = 0;
  String _biometricLabel = 'Biometric';
  IconData _biometricIcon = Icons.fingerprint;
  String? _username;
  bool _hasFaceId = false;
  bool _hasFingerprint = false;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _init();
  }

  void _setupAnimation() {
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.93, end: 1.07).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  Future<void> _init() async {
    final label = await BiometricAuthService.getBiometricLabel();
    final icon = await BiometricAuthService.getBiometricIcon();
    final username = await SessionManager.getLastUsername();
    final hasFaceId = await BiometricAuthService.isFaceIdAvailable();
    final hasFingerprint = await BiometricAuthService.isFingerprintAvailable();
    
    if (mounted) {
      setState(() {
        _biometricLabel = label;
        _biometricIcon = icon;
        _username = username;
        _hasFaceId = hasFaceId;
        _hasFingerprint = hasFingerprint;
      });
    }
    await Future.delayed(const Duration(milliseconds: 400));
    _authenticate();
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _authFailed = false;
    });

    final result = await BiometricAuthService.authenticateSecure(
      reason: 'Verify it\'s you to continue',
    );

    if (!mounted) return;

    switch (result) {
      case BiometricResult.success:
        await _onAuthSuccess();
        break;

      case BiometricResult.cancelled:
        setState(() {
          _isAuthenticating = false;
          _authFailed = false;
        });
        break;

      case BiometricResult.enrollmentChanged:
        setState(() => _isAuthenticating = false);
        _showEnrollmentChangedAlert();
        break;

      case BiometricResult.keyInvalidated:
        setState(() => _isAuthenticating = false);
        _forceFullLogin(reason: 'Your session has expired. Please login again.');
        break;

      case BiometricResult.failed:
        setState(() {
          _isAuthenticating = false;
          _authFailed = true;
          _failCount++;
        });
        break;
      case BiometricResult.lockedOut:
        setState(() {
          _isAuthenticating = false;
        });
        _showLockedOutDialog();
        break;
      case BiometricResult.notAvailable:
        setState(() {
          _isAuthenticating = false;
        });
        _showNotAvailableDialog();
        break;
    }
  }

  Future<void> _onAuthSuccess() async {
    try {
      final refreshed = await ApiService.refreshUserToken();
      if (!refreshed) {
        final isValid = await SessionManager.hasValidSession();
        if (!isValid) {
          _forceFullLogin(reason: 'Your session has expired. Please login again.');
          return;
        }
      }
    } catch (e) {
      debugPrint("Token refresh error: $e — checking local session");
      final isValid = await SessionManager.hasValidSession();
      if (!isValid) {
        _forceFullLogin(reason: 'Your session has expired. Please login again.');
        return;
      }
    }

    SessionManager.updateUserActivity();
    SessionManager.startSessionMonitoring();

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/dashboard');
  }

  void _showEnrollmentChangedAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.security_rounded, color: Color(0xFFFFB300), size: 26),
            const SizedBox(width: 10),
            Text(
              'Security Alert',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'A new biometric has been added to this device.\n\n'
          'For your security, please login again with your password to re-verify your identity.',
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 13.5,
            height: 1.6,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _forceFullLogin(
                reason: 'Please login with your password to re-verify after biometric change.',
              );
            },
            child: Text(
              'Login with Password',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showLockedOutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.lock_rounded, color: Color(0xFFEF5350), size: 26),
            const SizedBox(width: 10),
            Text(
              'Too Many Attempts',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Biometric authentication has been locked due to too many failed attempts.\n\nPlease use your password to login.',
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 13.5,
            height: 1.6,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _usePasswordFallback();
            },
            child: Text(
              'Enter Password',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotAvailableDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.devices_rounded, color: Color(0xFFFFB300), size: 26),
            const SizedBox(width: 10),
            Text(
              'Biometric Not Available',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Biometric authentication is not available on this device.\n\nPlease login with your password.',
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 13.5,
            height: 1.6,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _usePasswordFallback();
            },
            child: Text(
              'Enter Password',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _forceFullLogin({String? reason}) async {
    await SessionManager.clearSession();
    await BiometricAuthService.setBiometricEnabled(false);
    ApiService.clearSession();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false,
        arguments: reason);
  }

  void _usePasswordFallback() async {
    await SessionManager.clearSession();
    ApiService.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  String _getBiometricInstruction() {
    if (_hasFaceId && _hasFingerprint) {
      return 'Use Face or Fingerprint to Open SmartMate';
    } else if (_hasFaceId) {
      return 'Use Face ID to Open SmartMate';
    } else if (_hasFingerprint) {
      return 'Use Fingerprint to Open SmartMate';
    } else {
      return 'Use Biometric to Open SmartMate';
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if(widget.isFromSettings) {
          Navigator.of(context).pop();
        } else {
          widget.onContinue();
        }
      },
      child: Container(
        color: const Color(0xFF0A0F2C),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 1),

                // App Logo/Icon (Optional)
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF00BCD4)],
                    ),
                  ),
                  child: const Icon(
                    Icons.smartphone,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                
                const SizedBox(height: 24),

                // Greeting
                if (_username != null) ...[
                  Text(
                    'Welcome back,',
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _username!,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),
                ] else ...[
                  const SizedBox(height: 40),
                ],

                // Biometric Instruction Text
                Text(
                  _getBiometricInstruction(),
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Biometric Icon with Pulse Animation
                ScaleTransition(
                  scale: _pulseAnim,
                  child: GestureDetector(
                    onTap: _authenticate,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _authFailed
                              ? [const Color(0xFFB71C1C), const Color(0xFFE53935)]
                              : [const Color(0xFF1565C0), const Color(0xFF00BCD4)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_authFailed
                                    ? const Color(0xFFE53935)
                                    : const Color(0xFF1565C0))
                                .withOpacity(0.5),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: _isAuthenticating
                          ? const Center(
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(
                                  color: Colors.white, 
                                  strokeWidth: 3
                                ),
                              ),
                            )
                          : Icon(_biometricIcon, size: 64, color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Status text
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _authFailed
                      ? Column(
                          key: const ValueKey('failed'),
                          children: [
                            Text(
                              '$_biometricLabel not recognized',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFEF5350),
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap the icon to try again',
                              style: GoogleFonts.poppins(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        )
                      : _isAuthenticating
                          ? Column(
                              key: const ValueKey('verifying'),
                              children: [
                                Text(
                                  'Verifying...',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                ),

                const Spacer(flex: 2),

                // Enter Password Button (Always Visible)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ElevatedButton(
                    onPressed: _usePasswordFallback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: const Color(0xFF40C4FF),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: const Color(0xFF40C4FF).withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Enter Password',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Optional: Trouble signing in? (Appears after 2 failures)
                AnimatedOpacity(
                  opacity: _failCount >= 2 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Having trouble? Tap "Enter Password" above',
                      style: GoogleFonts.poppins(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}