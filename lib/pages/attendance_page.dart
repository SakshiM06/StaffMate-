import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';

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
  static const Color warningOrange = Color(0xFFFFA726);
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

  // Camera related variables
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _cameraError = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeTimer();
    _initializeCamera();
    _loadAttendanceState();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  void _initializeTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _getTime());
    _getTime();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        // Use front camera if available, otherwise use the first camera
        final frontCamera = _cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras.first,
        );

        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            _cameraError = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _cameraError = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      if (mounted) {
        setState(() {
          _cameraError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer?.cancel();
    _cameraController?.dispose();
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
    // Load from persistent storage in real app
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
          // Punch In Logic
          if (punchInTime != null && 
              _isSameDay(punchInTime!, DateTime.now())) {
            _attendanceStatusMessage = "You have already punched in today.";
            return;
          }

          isPunchedIn = true;
          punchInTime = DateTime.now();
          punchOutTime = null;
          _attendanceStatusMessage = "Punched In Successfully!";
        } else {
          // Punch Out Logic
          if (punchInTime == null) {
            _attendanceStatusMessage = "Error: No punch-in record found to punch out.";
            isPunchedIn = false;
            return;
          }

          final Duration workedDuration = DateTime.now().difference(punchInTime!);

          // Minimum 6 hours work check
          if (workedDuration.inHours < 6) {
            _attendanceStatusMessage =
                "Cannot punch out. Minimum 6 hours of work required. (Worked: ${workedDuration.inHours}h ${workedDuration.inMinutes.remainder(60)}m)";
            return;
          }

          punchOutTime = DateTime.now();
          isPunchedIn = false;

          // Half-day or full-day calculation
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

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final Size screenSize = mediaQuery.size;
    final double screenHeight = screenSize.height;
    final double screenWidth = screenSize.width;
    final EdgeInsets viewPadding = mediaQuery.viewPadding;

    final double statusBarHeight = viewPadding.top;
    final double bottomNavHeight = viewPadding.bottom;
    final double availableHeight = screenHeight - statusBarHeight - bottomNavHeight;

    final double headerHeight = availableHeight * 0.22; 
    final double horizontalPadding = screenWidth * 0.05;

    return Scaffold(
      backgroundColor: AppColors.lightGreyColor,
      body: Column(
        children: [
          _buildHeaderAndClock(headerHeight, screenWidth, statusBarHeight),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: screenHeight * 0.02,
              ),
              child: Column(
                children: [
                  _buildCameraPreview(screenHeight, screenWidth),
                SizedBox(height: screenHeight * 0.025),
                  
                 if (_attendanceStatusMessage != null)
                    _buildStatusMessage(screenHeight, screenWidth),
                  
                  if (_attendanceStatusMessage != null)
                    SizedBox(height: screenHeight * 0.02),
                  
                  // Punch button
                  _buildPunchButton(screenHeight, screenWidth),
                  
                  SizedBox(height: screenHeight * 0.025),
                  
                  // Punch time display
                  _buildPunchTimeDisplay(screenHeight, screenWidth),
                   SizedBox(height: screenHeight * 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderAndClock(double headerHeight, double screenWidth, double statusBarHeight) {
    return ClipPath(
      clipper: AttendanceHeaderClipper(),
      child: Container(
        height: headerHeight + statusBarHeight,
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
              SizedBox(height: headerHeight * 0.05),
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
   final double squareSize = screenWidth * 0.9;
    
    return Card(
      elevation: 8,
      shadowColor: AppColors.primaryDarkBlue.withValues(alpha: .15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(screenWidth * 0.04),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(screenWidth * 0.04),
        child: Container(
          height: squareSize, // Square shape
          width: squareSize,
          color: Colors.grey[200],
          child: _buildCameraWidget(screenHeight, screenWidth),
        ),
      ),
    );
  }

  Widget _buildCameraWidget(double screenHeight, double screenWidth) {
    if (_cameraError) {
      return _buildCameraErrorWidget(screenWidth);
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return _buildCameraLoadingWidget(screenWidth);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraController!.value.previewSize?.height ?? 100,
            height: _cameraController!.value.previewSize?.width ?? 100,
            child: CameraPreview(_cameraController!),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.accentTeal.withValues(alpha: 0.3),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(screenWidth * 0.04),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentTeal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.videocam,
                  color: AppColors.whiteColor,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  "LIVE",
                  style: GoogleFonts.poppins(
                    color: AppColors.whiteColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraLoadingWidget(double screenWidth) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.accentTeal,
          ),
          SizedBox(height: screenWidth * 0.04),
          Text(
            "Initializing Camera...",
            style: GoogleFonts.poppins(
              color: AppColors.textBodyColor,
              fontSize: screenWidth * 0.035,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraErrorWidget(double screenWidth) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: screenWidth * 0.12,
            color: AppColors.textBodyColor,
          ),
          SizedBox(height: screenWidth * 0.03),
          Text(
            "Camera not available",
            style: GoogleFonts.poppins(
              color: AppColors.textBodyColor,
              fontSize: screenWidth * 0.035,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: screenWidth * 0.02),
          ElevatedButton.icon(
            onPressed: _initializeCamera,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text("Retry"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentTeal,
              foregroundColor: AppColors.whiteColor,
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.04,
                vertical: screenWidth * 0.02,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPunchButton(double screenHeight, double screenWidth) {
    final double buttonWidth = screenWidth * 0.6; // Rectangle width
    final double buttonHeight = screenHeight * 0.08; // Rectangle height
    
    return GestureDetector(
      onTap: _punch,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: buttonHeight,
          width: buttonWidth,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPunchedIn
                  ? [AppColors.errorRed, AppColors.errorRed.withValues(alpha: 0.8)]
                  : [AppColors.accentTeal, AppColors.darkerAccentTeal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(screenWidth * 0.04), // Rectangle with rounded corners
            boxShadow: [
              BoxShadow(
                color: (isPunchedIn ? AppColors.errorRed : AppColors.accentTeal)
                    .withValues(alpha: .4),
                spreadRadius: 1,
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPunchedIn ? Icons.logout_rounded : Icons.login_rounded,
                  size: screenWidth * 0.08,
                  color: AppColors.whiteColor,
                ),
                SizedBox(width: screenWidth * 0.03),
                Text(
                  isPunchedIn ? "Punch Out" : "Punch In",
                  style: GoogleFonts.poppins(
                    fontSize: screenWidth * 0.05,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(screenWidth * 0.04),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: screenHeight * 0.015,
        ),
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
              Divider(
                height: screenHeight * 0.025,
                color: AppColors.fieldFillColor,
              ),
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
            fontSize: screenWidth * 0.04,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        Text(
          time,
          style: GoogleFonts.poppins(
            fontSize: screenWidth * 0.04,
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
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenHeight * 0.012,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(screenWidth * 0.03),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Text(
        _attendanceStatusMessage!,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: screenWidth * 0.035,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class AttendanceHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - size.height * 0.2);
    path.quadraticBezierTo(
      size.width / 4,
      size.height - size.height * 0.05,
      size.width / 2,
      size.height - size.height * 0.15,
    );
    path.quadraticBezierTo(
      size.width * 3 / 4,
      size.height - size.height * 0.25,
      size.width,
      size.height - size.height * 0.2,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}