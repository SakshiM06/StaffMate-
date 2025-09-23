import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // For date formatting

// Make sure this path to your camera widget is correct.
import '../widgets/camera_preview_widget.dart'; // Assuming this path is correct

// Define the color palette
class AppColors {
  static const Color primaryDarkBlue = Color(0xFF1A2C42);
  static const Color midDarkBlue = Color(0xFF273F5A);
  static const Color accentTeal = Color(0xFF00C897);
  static const Color darkerAccentTeal = Color(0xFF00A37D);
  static const Color lightBlue = Color(0xFF66D7EE);
  static const Color whiteColor = Colors.white;
  static const Color textDark = primaryDarkBlue;
  static const Color textBodyColor = Color(0xFF90A4AE);
  static const Color lightGreyColor = Color(0xFFF0F4F8);
  static const Color fieldFillColor = Color(0xFFE3E8ED);
  static const Color errorRed = Color(0xFFE53935);
  static const Color warningOrange = Color(0xFFFFA726); // Added for warnings
}

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with SingleTickerProviderStateMixin {
  bool isPunchedIn = false;
  DateTime? punchInTime;
  DateTime? punchOutTime;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  Timer? _timer;
  String _currentTime = "";
  String? _attendanceStatusMessage;

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
    _getTime(); // Initial call to set the time immediately

    _loadAttendanceState();
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
        _currentTime = DateFormat('HH:mm:ss').format(now);
      });
    }
  }

  void _loadAttendanceState() {
    // In a real application, you would load these values from persistent storage
    // (e.g., SharedPreferences, a database, or a backend API) for the current day.
    // For this example, we start fresh each time the page loads.
    isPunchedIn = false;
    punchInTime = null;
    punchOutTime = null;
    _attendanceStatusMessage = null;
  }

  void _punch() {
    _animationController.forward().then((_) {
      _animationController.reverse();
      setState(() {
        if (!isPunchedIn) {
          // --- Punch In Logic ---
          // Check if already punched in today
          if (punchInTime != null && punchInTime!.day == DateTime.now().day &&
              punchInTime!.month == DateTime.now().month &&
              punchInTime!.year == DateTime.now().year) {
            _attendanceStatusMessage = "You have already punched in today.";
            return; // Prevent punching in again
          }

          isPunchedIn = true;
          punchInTime = DateTime.now();
          punchOutTime = null; // Clear previous punch out on new punch in
          _attendanceStatusMessage = "Punched In Successfully!";
        } else {
          // --- Punch Out Logic ---
          if (punchInTime == null) {
            _attendanceStatusMessage = "Error: No punch-in record found to punch out.";
            isPunchedIn = false; // Reset to ensure consistent state
            return;
          }

          final Duration workedDuration = DateTime.now().difference(punchInTime!);

          // Minimum 6 hours work check
          if (workedDuration.inHours < 6) {
            _attendanceStatusMessage =
            "Cannot punch out. Minimum 6 hours of work required. (Worked: ${workedDuration.inHours}h ${workedDuration.inMinutes.remainder(60)}m)";
            return; // Prevent punch out
          }

          punchOutTime = DateTime.now();
          isPunchedIn = false; // Reset state after punching out

          // Half-day calculation (6 to 8 hours)
          if (workedDuration.inHours < 8) {
            _attendanceStatusMessage =
            "Punched Out (Half Day - ${workedDuration.inHours}h ${workedDuration.inMinutes.remainder(60)}m)";
          } else {
            _attendanceStatusMessage =
            "Punched Out (Full Day - ${workedDuration.inHours}h ${workedDuration.inMinutes.remainder(60)}m)";
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;

    // Calculate dynamic padding for content based on header height
    final double headerHeight = screenHeight * 0.25;
    // The clipper's lowest point is around size.height - size.height * 0.3
    // We want the content to start a bit below that curve
    final double contentTopPadding = headerHeight - (screenHeight * 0.25 * 0.2);


    return Scaffold(
      backgroundColor: AppColors.lightGreyColor,
      body: Stack(
        children: [
          // Layer 1: The custom-shaped header with the clock
          _buildHeaderAndClock(screenHeight, screenWidth),

          // Layer 2: Main content, starting below the header
          Positioned.fill(
            top: contentTopPadding, // Adjust position to start below the header curve
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
              ),
              child: Column(
                children: [
                  SizedBox(height: screenHeight * 0.03), // Space from header
                  _buildCameraPreview(screenHeight, screenWidth),
                  SizedBox(height: screenHeight * 0.04),
                  if (_attendanceStatusMessage != null)
                    _buildStatusMessage(screenHeight, screenWidth),
                  SizedBox(height: _attendanceStatusMessage != null ? screenHeight * 0.02 : 0),
                  _buildPunchButton(screenHeight, screenWidth),
                  SizedBox(height: screenHeight * 0.04),
                  _buildPunchTimeDisplay(screenHeight, screenWidth),
                  SizedBox(height: screenHeight * 0.05), // Bottom spacing
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAndClock(double screenHeight, double screenWidth) {
    return ClipPath(
      clipper: AttendanceHeaderClipper(),
      child: Container(
        height: screenHeight * 0.25,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryDarkBlue, AppColors.midDarkBlue],
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
                  color: AppColors.whiteColor,
                  fontSize: screenWidth * 0.065,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              Text(
                _currentTime,
                style: GoogleFonts.nunito(
                  fontSize: screenWidth * 0.12,
                  fontWeight: FontWeight.w300,
                  color: AppColors.whiteColor.withValues(alpha: .9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview(double screenHeight, double screenWidth) {
    return Card(
      elevation: 8,
      shadowColor: AppColors.primaryDarkBlue.withValues(alpha: .15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(screenWidth * 0.06)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(screenWidth * 0.06),
        child: Container(
          height: screenHeight * 0.30, // Slightly adjusted height
          width: double.infinity,
          color: Colors.grey[200], // Placeholder background for camera
          child: const CameraPreviewWidget(), // Your actual camera widget
        ),
      ),
    );
  }

  Widget _buildPunchButton(double screenHeight, double screenWidth) {
    final buttonSize = screenWidth * 0.48; // Responsive button size
    return GestureDetector(
      onTap: _punch,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: buttonSize,
          width: buttonSize,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPunchedIn
                  ? [AppColors.errorRed, AppColors.errorRed.withValues(alpha:0.8)] // Red gradient for punch out
                  : [AppColors.accentTeal, AppColors.darkerAccentTeal], // Teal gradient for punch in
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (isPunchedIn ? AppColors.errorRed : AppColors.accentTeal)
                    .withValues(alpha: .5),
                spreadRadius: 2,
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPunchedIn ? Icons.logout_rounded : Icons.login_rounded,
                  size: screenWidth * 0.16, // Responsive icon size
                  color: AppColors.whiteColor,
                ),
                SizedBox(height: screenHeight * 0.01),
                Text(
                  isPunchedIn ? "Punch Out" : "Punch In",
                  style: GoogleFonts.poppins(
                    fontSize: screenWidth * 0.055,
                    fontWeight: FontWeight.bold,
                    color: AppColors.whiteColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPunchTimeDisplay(double screenHeight, double screenWidth) {
    return Card(
      elevation: 4,
      shadowColor: AppColors.primaryDarkBlue.withValues(alpha: .05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(screenWidth * 0.04)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05, vertical: screenHeight * 0.02),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (punchInTime != null)
              _buildPunchTimeRow(
                "Punched In",
                DateFormat('hh:mm a').format(punchInTime!),
                AppColors.accentTeal,
                screenWidth,
              ),
            if (punchInTime != null && punchOutTime != null)
              Divider(height: screenHeight * 0.03, color: AppColors.fieldFillColor),
            if (punchOutTime != null)
              _buildPunchTimeRow(
                "Punched Out",
                DateFormat('hh:mm a').format(punchOutTime!),
                AppColors.errorRed,
                screenWidth,
              ),
            if (punchInTime == null && punchOutTime == null)
              Text(
                "Ready to punch in",
                style: GoogleFonts.nunito(
                  color: AppColors.textBodyColor,
                  fontSize: screenWidth * 0.04,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPunchTimeRow(String title, String time, Color color, double screenWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: screenWidth * 0.045,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        Text(
          time,
          style: GoogleFonts.poppins(
            fontSize: screenWidth * 0.045,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusMessage(double screenHeight, double screenWidth) {
    Color bgColor;
    Color textColor;
    Color borderColor;

    if (_attendanceStatusMessage != null) {
      if (_attendanceStatusMessage!.contains("Cannot punch out") ||
          _attendanceStatusMessage!.contains("Error")) {
        bgColor = AppColors.errorRed.withValues(alpha: .1);
        textColor = AppColors.errorRed;
        borderColor = AppColors.errorRed.withValues(alpha: .3);
      } else if (_attendanceStatusMessage!.contains("Half Day")) {
        bgColor = AppColors.warningOrange.withValues(alpha: .1);
        textColor = AppColors.warningOrange;
        borderColor = AppColors.warningOrange.withValues(alpha: .3);
      } else {
        bgColor = AppColors.accentTeal.withValues(alpha: .1);
        textColor = AppColors.accentTeal;
        borderColor = AppColors.accentTeal.withValues(alpha: .3);
      }
    } else {
      // Default / should not be reached if _attendanceStatusMessage is null
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenHeight * 0.015,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Text(
        _attendanceStatusMessage!, // Using ! because we've checked for null above
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: screenWidth * 0.038,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// Custom Clipper for the fluid header shape (unchanged, but its effect will be with new colors)
class AttendanceHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - size.height * 0.15); // Adjusted for responsiveness
    path.quadraticBezierTo(
        size.width / 4, size.height, size.width / 2, size.height - size.height * 0.08);
    path.quadraticBezierTo(
        size.width * 3 / 4, size.height - size.height * 0.15, size.width, size.height - size.height * 0.3);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}