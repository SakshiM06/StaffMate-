import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

// Make sure this path to your camera widget is correct.
import '../widgets/camera_preview_widget.dart'; // Assuming this path is correct

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with SingleTickerProviderStateMixin {
  // --- UNCHANGED STATE LOGIC ---
  bool isPunchedIn = false;
  DateTime? punchInTime;
  DateTime? punchOutTime;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  Timer? _timer;
  String _currentTime = "";

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _getTime());
    _getTime();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _getTime() {
    final DateTime now = DateTime.now();
    if (mounted) {
      setState(() {
        _currentTime =
            "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      });
    }
  }

  void _punch() {
    _animationController.forward().then((_) {
      _animationController.reverse();
      setState(() {
        isPunchedIn = !isPunchedIn;
        if (isPunchedIn) {
          punchInTime = DateTime.now();
          punchOutTime = null;
        } else {
          punchOutTime = DateTime.now();
        }
      });
    });
  }
  // --- END OF UNCHANGED STATE LOGIC ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3E6FD), // Lightest theme color
      // Removed BottomNavigationBar from here for cleaner focus, assuming it's in a parent widget like main_screen.dart
      body: Stack(
        children: [
          // Layer 1: The custom-shaped header with the clock
          _buildHeaderAndClock(),

          // Layer 2: The main content, pushed down to avoid the header
          // Use a LayoutBuilder to dynamically get available height
          LayoutBuilder(
            builder: (context, constraints) {
              // Calculate the available height for the content below the header.
              // We subtract the height of the header clip path (approx 25% of screen height)
              // and some additional padding to ensure it fits.
              final double headerHeight = MediaQuery.of(context).size.height * 0.25;
              final double topPaddingForContent = headerHeight - 40; // Adjust based on clipper's lowest point

              return Padding(
                padding: EdgeInsets.only(
                  top: topPaddingForContent + 20, 
                  left: 20,
                  right: 20,
                ),
                child: Column(
                  children: [
                    _buildCameraPreview(), 
                    const Spacer(),
                    _buildPunchButton(),
                    const Spacer(),
                    // Wrap the punch time display in Flexible to prevent overflow
                    Flexible(child: _buildPunchTimeDisplay()),
                    const SizedBox(height: 20), // Add some bottom spacing
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- NEW WIDGET BUILDING METHODS ---

  Widget _buildHeaderAndClock() {
    return ClipPath(
      clipper: AttendanceHeaderClipper(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.25,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7E90F8), Color(0xFF8B99FA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Attendance",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _currentTime,
                style: GoogleFonts.nunito( // Using Nunito as in the original image for the time
                  fontSize: 52,
                  fontWeight: FontWeight.w300,
                  color: Colors.white.withValues(alpha: .9), // Corrected withValues to withOpacity
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    final screenHeight = MediaQuery.of(context).size.height;
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: .1), // Corrected withValues to withOpacity
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: screenHeight * 0.35, // Adjusted for better balance
          width: double.infinity,
          child: const CameraPreviewWidget(), // Your existing camera widget
        ),
      ),
    );
  }

  Widget _buildPunchButton() {
    return GestureDetector(
      onTap: _punch,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: 180,
          width: 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPunchedIn
                  ? [const Color(0xFFF96A5C), const Color(0xFFFF8A80)] // Red gradient
                  : [const Color(0xFF26A69A), const Color(0xFF00C853)], // Green gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isPunchedIn ? Colors.red.shade200 : Colors.green.shade200)
                    .withValues(alpha: .7), // Corrected withValues to withOpacity
                spreadRadius: 2,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPunchedIn ? Icons.logout_rounded : Icons.login_rounded,
                  size: 60,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                Text(
                  isPunchedIn ? "Punch Out" : "Punch In",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPunchTimeDisplay() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: .05), // Corrected withValues to withOpacity
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Use mainAxisSize.min to take only required space
          children: [
            if (punchInTime != null)
              _buildPunchTimeRow(
                "Punched In",
                "${punchInTime!.hour.toString().padLeft(2, '0')}:${punchInTime!.minute.toString().padLeft(2, '0')}",
                const Color(0xFF00C853),
              ),
            if (punchInTime != null && punchOutTime != null)
              const Divider(height: 15),
            if (punchOutTime != null)
              _buildPunchTimeRow(
                "Punched Out",
                "${punchOutTime!.hour.toString().padLeft(2, '0')}:${punchOutTime!.minute.toString().padLeft(2, '0')}",
                const Color(0xFFF96A5C),
              ),
            if (punchInTime == null && punchOutTime == null) // Show only if neither is set
              Text(
                "Ready to punch in",
                style: GoogleFonts.nunito(color: Colors.grey[600], fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPunchTimeRow(String title, String time, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        Text(
          time,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// Custom Clipper for the fluid header shape
class AttendanceHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
        size.width / 4, size.height, size.width / 2, size.height - 20);
    path.quadraticBezierTo(
        size.width * 3 / 4, size.height - 40, size.width, size.height - 80);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}