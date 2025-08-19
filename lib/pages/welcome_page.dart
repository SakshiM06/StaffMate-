import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:staff_mate/pages/login_page.dart';
 
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
 
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
 
    return Scaffold(
      body: Container(
        // Using the same gradient as the other pages for theme consistency
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF7E90F8), // Starting color from the main theme
              Color(0xFFB1B9FC),
              Color(0xFFE3E6FD), // Ending color from the main theme
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: AnimationLimiter(
          child: Stack(
            children: [
              // The main content is built in layers using a Stack
              // Layer 1: The welcome image
              AnimationConfiguration.staggeredList(
                position: 0,
                duration: const Duration(milliseconds: 500),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: screenHeight * 0.1),
                        child: Image.asset(
                          'assets/images/welcome-removebg-preview.png',
                          height: screenHeight * 0.45,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
 
              // Layer 2: The curved container with text and button
              Align(
                alignment: Alignment.bottomCenter,
                child: ClipPath(
                  clipper: WaveClipper(), // Custom clipper for the wave shape
                  child: Container(
                    height: screenHeight * 0.5,
                    width: double.infinity,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: AnimationConfiguration.toStaggeredList(
                          duration: const Duration(milliseconds: 500),
                          childAnimationBuilder: (widget) => SlideAnimation(
                            verticalOffset: 80.0,
                            child: FadeInAnimation(
                              child: widget,
                            ),
                          ),
                          children: [
                            const Spacer(flex: 3),
                            Text(
                              "Welcome to StaffMate",
                              style: GoogleFonts.poppins(
                                fontSize: screenWidth * 0.07, // Responsive font size
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF333D79),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Your smart staff management partner, right in your pocket.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(
                                fontSize: screenWidth * 0.045,
                                color: Colors.black54,
                                height: 1.4,
                              ),
                            ),
                            const Spacer(flex: 2),
                            _buildGetStartedButton(context),
                            const Spacer(flex: 2),
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
      ),
    );
  }
 
  Widget _buildGetStartedButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF7E90F8),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 8,
        shadowColor: const Color(0xFF7E90F8).withValues(alpha: .5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Get Started",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.arrow_forward, color: Colors.white),
        ],
      ),
    );
  }
}
 
// Custom Clipper class to create the wave effect
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, 20); // Start a bit down
    path.quadraticBezierTo(
        size.width / 4, 0, // Control point
        size.width / 2, 20); // Mid point
    path.quadraticBezierTo(
        size.width * 3 / 4, 40, // Control point
        size.width, 20); // End point
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }
 
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}