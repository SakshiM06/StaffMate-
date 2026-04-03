import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:staff_mate/services/biometric_auth_service.dart';

/// A PhonePe/GPay-style biometric setup screen.
/// Place this in your pages/ folder as biometric_setup_page.dart
/// Route to this page after login when biometric is available but not yet enabled.
class BiometricSetupPage extends StatefulWidget {
  final VoidCallback onContinue;
  final bool isFromSettings; // true = came from Settings toggle

  const BiometricSetupPage({
    super.key,
    required this.onContinue,
    this.isFromSettings = false,
  });

  @override
  State<BiometricSetupPage> createState() => _BiometricSetupPageState();
}

class _BiometricSetupPageState extends State<BiometricSetupPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  String _biometricLabel = 'Biometric';
  IconData _biometricIcon = Icons.fingerprint;
  bool _isLoading = false;
  bool _isEnabled = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadBiometricInfo();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );

    _slideController.forward();
  }

  Future<void> _loadBiometricInfo() async {
    final label = await BiometricAuthService.getBiometricLabel();
    final icon = await BiometricAuthService.getBiometricIcon();
    final enabled = await BiometricAuthService.isBiometricEnabled(); 
    if (mounted) {
      setState(() {
        _biometricLabel = label;
        _biometricIcon = icon;
        _isEnabled = enabled;
      });
    }
  }
  Future<void> _handleEnable() async {
  setState(() => _isLoading = true);
  final result = await BiometricAuthService.enableBiometric();
  if (!mounted) return;
  setState(() => _isLoading = false);

  switch (result) {
    case BiometricResult.success:
      setState(() => _isEnabled = true);
      _showSuccessAndContinue();
      break;
    case BiometricResult.cancelled:
      // User dismissed — do nothing
      break;
    case BiometricResult.lockedOut:
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Too many attempts. Please use your PIN or password first, then try again.',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      break;
    case BiometricResult.notAvailable:
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Biometric sensor not available. Make sure a fingerprint or face is enrolled in your device Settings.',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.orange[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
      ));
      break;
    case BiometricResult.failed:
      _showFailureSnackbar();
      break;
    default:
      break;
  }
}

  Future<void> _handleDisable() async {
    setState(() => _isLoading = true);
    final success = await BiometricAuthService.disableBiometric();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _isEnabled = !success; // if success, it's now disabled
    });
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_biometricLabel login disabled',
              style: GoogleFonts.poppins()),
          backgroundColor: Colors.grey[800],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showSuccessAndContinue() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SuccessDialog(
        label: _biometricLabel,
        icon: _biometricIcon,
        onDone: () {
          Navigator.of(ctx).pop();
          widget.onContinue();
        },
      ),
    );
  }

  void _showFailureSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$_biometricLabel verification failed. Try again.',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F2C),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Top row: Skip / Back
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (widget.isFromSettings)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        )
                      else
                        const SizedBox(width: 48),
                      if (!widget.isFromSettings)
                        TextButton(
                          onPressed: widget.onContinue,
                          child: Text(
                            'Skip',
                            style: GoogleFonts.poppins(
                              color: Colors.white54,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const Spacer(flex: 2),

                  // Animated biometric icon
                  ScaleTransition(
                    scale: _pulseAnim,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1565C0), Color(0xFF00BCD4)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1565C0).withOpacity(0.5),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        _biometricIcon,
                        size: 72,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Title
                  Text(
                    'Enable $_biometricLabel',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Sign in instantly with your $_biometricLabel.\nNo password needed every time.',
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      color: Colors.white60,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // Feature bullets (like PhonePe)
                  _FeatureTile(
                    icon: Icons.bolt_rounded,
                    color: const Color(0xFFFFD740),
                    title: 'Instant Login',
                    subtitle: 'Get in with a glance or touch',
                  ),
                  const SizedBox(height: 14),
                  _FeatureTile(
                    icon: Icons.shield_rounded,
                    color: const Color(0xFF69F0AE),
                    title: 'Secure & Private',
                    subtitle: 'Your biometric stays on device, always',
                  ),
                  const SizedBox(height: 14),
                  _FeatureTile(
                    icon: Icons.no_encryption_gmailerrorred_rounded,
                    color: const Color(0xFF40C4FF),
                    title: 'No Password Hassle',
                    subtitle: 'Skip typing every time you open the app',
                  ),

                  const Spacer(flex: 3),

                  // Enable button
                  if (!_isEnabled) ...[
                    _PrimaryButton(
                      label: 'Enable $_biometricLabel',
                      icon: _biometricIcon,
                      isLoading: _isLoading,
                      onTap: _handleEnable,
                    ),
                    const SizedBox(height: 14),
                    if (!widget.isFromSettings)
                      TextButton(
                        onPressed: widget.onContinue,
                        child: Text(
                          'Maybe later',
                          style: GoogleFonts.poppins(
                            color: Colors.white38,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ] else ...[
                    // Already enabled state
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF69F0AE).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF69F0AE).withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF69F0AE), size: 22),
                          const SizedBox(width: 10),
                          Text(
                            '$_biometricLabel is enabled',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF69F0AE),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: _isLoading ? null : _handleDisable,
                      child: Text(
                        'Disable $_biometricLabel',
                        style: GoogleFonts.poppins(
                          color: Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF00BCD4)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1565C0).withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Success Dialog ──────────────────────────────────────────────────────────

class _SuccessDialog extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onDone;

  const _SuccessDialog({
    required this.label,
    required this.icon,
    required this.onDone,
  });

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();

    // Auto-dismiss after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Dialog(
        backgroundColor: const Color(0xFF0D1B3E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF00BCD4)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00BCD4).withOpacity(0.4),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 42),
              ),
              const SizedBox(height: 22),
              Text(
                '${widget.label} Enabled!',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can now sign in instantly\nusing your ${widget.label}.',
                style: GoogleFonts.poppins(
                  color: Colors.white54,
                  fontSize: 13.5,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const LinearProgressIndicator(
                backgroundColor: Colors.white12,
                color: Color(0xFF00BCD4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}