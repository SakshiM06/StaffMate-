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
  // Updated color palette
 Color primaryDarkBlue = Color(0xFF0D1B2A);
   Color midDarkBlue = Color(0xFF1B263B);
  static const Color accentBlue = Color(0xFF0289A1);
  static const Color lightBlue = Color(0xFF87CEEB);
  static const Color whiteColor = Colors.white;
  static const Color textDark = Color(0xFF0D1B2A);
  static const Color textBodyColor = Color(0xFF4A5568);
 Color lightGreyColor = Color(0xFFF7FAFC);

  // Animation controllers
  late AnimationController _logoScaleController;
  late Animation<double> _logoScaleAnimation;
  
  late AnimationController _contentSlideController;
  late Animation<Offset> _contentSlideAnimation;
  late Animation<double> _contentFadeAnimation;
  
  late AnimationController _backgroundGradientController;
  late Animation<Color?> _backgroundGradientAnimation;
  
  late AnimationController _buttonPulseController;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
    
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    _logoScaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _logoScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoScaleController,
        curve: Curves.elasticOut,
      ),
    );

    _contentSlideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _contentSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentSlideController,
      curve: Curves.easeOutCubic,
    ));
    _contentFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentSlideController,
        curve: Curves.easeInOut,
      ),
    );

   
   _backgroundGradientController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _backgroundGradientAnimation = ColorTween(
      begin: const Color(0xFF0A192F),
      end: const Color(0xFF1B3A73),
    ).animate(CurvedAnimation(
      parent: _backgroundGradientController,
      curve: Curves.easeInOutSine,
    ));

    _buttonPulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _buttonScaleAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(
        parent: _buttonPulseController,
        curve: Curves.easeInOutSine,
      ),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      _logoScaleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      _contentSlideController.forward();
    });
  }

  @override
  void dispose() {
    _logoScaleController.dispose();
    _contentSlideController.dispose();
    _backgroundGradientController.dispose();
    _buttonPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: AnimatedBuilder(
        animation: _backgroundGradientController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _backgroundGradientAnimation.value!,
                  const Color(0xFF112D4E),
                  const Color(0xFF1B3A73),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: child,
          );
        },
        child: Stack(
          children: [
          
  Positioned(
              top: screenHeight * 0.1,
              right: -screenWidth * 0.2,
              child: Container(
                width: screenWidth * 0.6,
                height: screenWidth * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lightBlue.withValues(alpha: .1),
                ),
              ),
            ),
            Positioned(
              bottom: screenHeight * 0.2, 
              left: -screenWidth * 0.15,
              child: Container(
                width: screenWidth * 0.4,
                height: screenWidth * 0.4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentBlue.withValues(alpha: .1),
                ),
              ),
            ),

            // Top section with logo and app name
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: screenHeight * 0.15),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _logoScaleAnimation,
                      child: Image.asset(
                        'assets/images/welcomesm.png',
                        height: screenHeight * 0.28,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeTransition(
                      opacity: _logoScaleController,
                      // child: Text(
                      //   "StaffMate",
                      //   textAlign: TextAlign.center,
                      //   style: GoogleFonts.cormorantGaramond(
                      //     fontSize: screenWidth * 0.12,
                      //     fontWeight: FontWeight.w700,
                      //     color: whiteColor,
                      //     letterSpacing: 1.5,
                      //   ),
                      // ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom content container
            Align(
              alignment: Alignment.bottomCenter,
              child: SlideTransition(
                position: _contentSlideAnimation,
                child: FadeTransition(
                  opacity: _contentFadeAnimation,
                  child: Container(
                    height: screenHeight * 0.45,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: whiteColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .2),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(flex: 1),
                          Text(
                            "Welcome to StaffMate",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: screenWidth * 0.080,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                              height:  1.1,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Your smart staff management partner, right in your pocket. Streamline scheduling, track attendance, and enhance team communication.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunitoSans(
                              fontSize: screenWidth * 0.04,
                              color: textBodyColor,
                              height: 1.6,
                            ),
                          ),
                          const Spacer(flex: 2),
                          ScaleTransition(
                            scale: _buttonScaleAnimation,
                            child: _buildGetStartedButton(context),
                          ),
                          const Spacer(flex: 1),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGetStartedButton(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.8,
      child: ElevatedButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const AuthOptionsPage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOut;
                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: whiteColor,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 6,
          shadowColor: accentBlue.withValues(alpha: .4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Get Started",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward_rounded, size: 22),
          ],
        ),
      ),
    );
  }
}