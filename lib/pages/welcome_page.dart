import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:staff_mate/pages/auth_options.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with TickerProviderStateMixin {
  // IPD Page Color Palette
  static const Color primaryDarkBlue = Color(0xFF1A237E); 
  static const Color bgGrey = Color(0xFFF5F7FA);
  static const Color whiteColor = Colors.white;
  static const Color textDark = Color(0xFF1A237E);
  static final Color textBodyColor = Colors.grey.shade600;

  // Animation controllers
  late AnimationController _logoScaleController;
  late Animation<double> _logoScaleAnimation;

  late AnimationController _contentSlideController;
  late Animation<Offset> _contentSlideAnimation;
  late Animation<double> _contentFadeAnimation;

  late AnimationController _buttonPulseController;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();

    // Force full screen edge-to-edge
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    // Logo Animation
    _logoScaleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoScaleController, curve: Curves.elasticOut),
    );

    // Content Slide Animation
    _contentSlideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _contentSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _contentSlideController, curve: Curves.easeOutQuart));
    
    _contentFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentSlideController, curve: Curves.easeIn),
    );

    // Button Pulse Animation
    _buttonPulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _buttonPulseController, curve: Curves.easeInOutSine),
    );

    Future.delayed(const Duration(milliseconds: 200), () => _logoScaleController.forward());
    Future.delayed(const Duration(milliseconds: 600), () => _contentSlideController.forward());
  }

  @override
  void dispose() {
    _logoScaleController.dispose();
    _contentSlideController.dispose();
    _buttonPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get precise screen dimensions and safe areas
    final Size size = MediaQuery.of(context).size;
    final EdgeInsets padding = MediaQuery.of(context).padding; // Safe area padding

    return Scaffold(
      backgroundColor: primaryDarkBlue,
      // Stack allows the background circles to sit behind everything
      body: Stack(
        children: [
          // --- Background Decor ---
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

          // --- Main Content ---
          Column(
            children: [
              // TOP SECTION: Logo & Branding
              // Expanded ensures it takes remaining space, Flex 5 gives it 55% of screen
              Expanded(
                flex: 5,
                child: SafeArea(
                  bottom: false, // Don't respect bottom safe area here, let content flow
                  child: Center(
                    child: SingleChildScrollView( // Prevents overflow on very short screens in landscape
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ScaleTransition(
                            scale: _logoScaleAnimation,
                            child: Container(
                              padding: EdgeInsets.all(size.width * 0.05), // Dynamic padding
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
                                height: size.width * 0.30, // Responsive image size
                                fit: BoxFit.contain,
                                errorBuilder: (c, o, s) => Icon(
                                  Icons.local_hospital_rounded,
                                  size: size.width * 0.25,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: size.height * 0.03), // Dynamic spacing
                          FadeTransition(
                            opacity: _logoScaleAnimation,
                            child: Text(
                              "StaffMate",
                              style: GoogleFonts.poppins(
                                fontSize: size.width * 0.08, // Dynamic font size
                                fontWeight: FontWeight.w700,
                                color: whiteColor,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // BOTTOM SECTION: White Action Sheet
              Expanded(
                flex: 4,
                child: SlideTransition(
                  position: _contentSlideAnimation,
                  child: FadeTransition(
                    opacity: _contentFadeAnimation,
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: bgGrey,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      // Use Padding + SingleChildScrollView to handle small screens gracefully
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            // Add 'padding.bottom' to avoid home indicator overlap on iOS
                            padding: EdgeInsets.fromLTRB(30, 40, 30, 30 + padding.bottom),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min, // Wrap content tightly
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
                                  "Manage Your Hospital\nWith Ease",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: size.width * 0.06, // Responsive font
                                    fontWeight: FontWeight.bold,
                                    color: textDark,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Streamline scheduling, track patient attendance, and enhance team communication in one unified platform.",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: size.width * 0.035, // Responsive font
                                    color: textBodyColor,
                                    height: 1.5,
                                  ),
                                ),
                                
                                SizedBox(height: size.height * 0.05), // Dynamic spacer
                                
                                ScaleTransition(
                                  scale: _buttonScaleAnimation,
                                  child: _buildGetStartedButton(context),
                                ),
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

  // Helper for background circles
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

  Widget _buildGetStartedButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56, // Standard touch target size (fixed is fine here)
      child: ElevatedButton(
  // In WelcomePage's _buildGetStartedButton method:
onPressed: () {
  HapticFeedback.mediumImpact();
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          const AuthOptionsPage(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutQuart;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 500),
      fullscreenDialog: true, // ADD THIS LINE
    ),
  );
},
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDarkBlue,
          foregroundColor: whiteColor,
          elevation: 8,
          shadowColor: primaryDarkBlue.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Get Started",
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}