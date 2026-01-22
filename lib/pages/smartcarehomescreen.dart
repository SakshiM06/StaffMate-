import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_mate/models/patient_alert_model.dart'; // Ensure path is correct
import 'package:staff_mate/pages/welcome_page.dart';
import 'package:staff_mate/services/user_information_service.dart';

// Unified Color Palette
class AppColors {
  static const Color primaryDarkBlue = Color(0xFF1A237E); // Deep Indigo
  static const Color midDarkBlue = Color(0xFF283593);
  static const Color accentTeal = Color(0xFF00C897);
  static const Color lightBlue = Color(0xFF66D7EE);
  static const Color whiteColor = Colors.white;
  static const Color textDark = Color(0xFF1A237E);
  static const Color textBodyColor = Color(0xFF90A4AE);
  static const Color lightGreyColor = Color(0xFFF0F4F8);
  static const Color errorRed = Color(0xFFE53935);
}

class SmartCareHomeScreen extends StatefulWidget {
  const SmartCareHomeScreen({super.key});

  @override
  State<SmartCareHomeScreen> createState() => _SmartCareHomeScreenState();
}

class _SmartCareHomeScreenState extends State<SmartCareHomeScreen> {
  // User Data Variables
  String fullName = 'Dr. Staff Member';
  String userId = '';
  String clinicName = 'Smart Care Hospital';
  String userRole = 'Medical Staff';
  String initial = 'S';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Fetch User Data
  Future<void> _loadUserData() async {
    try {
      // 1. Try fetching fresh data from Service
      final completeData = await UserInformationService.getCompleteUserData();
      if (completeData != null && completeData.containsKey('data')) {
        _setUserDataFromMap(completeData['data']);
        return;
      }

      // 2. Fallback to saved User Information
      final userInfo = await UserInformationService.getSavedUserInformation();
      if (userInfo.isNotEmpty && userInfo['userId']?.isNotEmpty == true) {
        _setUserDataFromInfoMap(userInfo);
        return;
      }

      // 3. Last resort: Basic Profile Info
      final profileInfo = await UserInformationService.getUserProfileForDisplay();
      if (profileInfo.isNotEmpty) {
        setState(() {
          fullName = profileInfo['fullName'] ?? 'Dr. Staff Member';
          userId = profileInfo['userId'] ?? '';
          clinicName = profileInfo['clinic'] ?? 'Smart Care Hospital';
          userRole = profileInfo['role'] ?? 'Medical Staff';
          initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S';
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading home user data: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _setUserDataFromMap(Map<String, dynamic> data) {
    if (!mounted) return;
    setState(() {
      userId = data['userId']?.toString() ?? '';
      String first = data['firstName']?.toString() ?? '';
      String last = data['lastName']?.toString() ?? '';
      String init = data['initial']?.toString() ?? '';
      
      fullName = '$init $first $last'.trim();
      if (fullName.isEmpty) fullName = userId;
      
      clinicName = data['clinicName']?.toString() ?? 'Smart Care Hospital';
      String job = data['jobtitle']?.toString() ?? '';
      userRole = job.isNotEmpty ? job : 'Medical Staff';
      initial = first.isNotEmpty ? first[0].toUpperCase() : (userId.isNotEmpty ? userId[0].toUpperCase() : 'S');
      isLoading = false;
    });
  }

  void _setUserDataFromInfoMap(Map<String, dynamic> userInfo) {
    if (!mounted) return;
    setState(() {
      userId = userInfo['userId']?.toString() ?? '';
      String first = userInfo['firstName']?.toString() ?? '';
      String last = userInfo['lastName']?.toString() ?? '';
      String init = userInfo['initial']?.toString() ?? '';

      fullName = '$init $first $last'.trim();
      if (fullName.isEmpty) fullName = userId;

      clinicName = userInfo['clinicName']?.toString() ?? 'Smart Care Hospital';
      String job = userInfo['jobtitle']?.toString() ?? '';
      userRole = job.isNotEmpty ? job : 'Medical Staff';
      initial = first.isNotEmpty ? first[0].toUpperCase() : 'S';
      isLoading = false;
    });
  }

  // Logout Logic
  Future<void> _handleLogout() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Logout", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text("Cancel")
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: Text("Logout", style: GoogleFonts.poppins(color: AppColors.errorRed)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WelcomePage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenHeight = screenSize.height;
    final double screenWidth = screenSize.width;

    // Adjusted sizes for a more compact and professional look
    final double verticalPadding = screenHeight * 0.015; // Reduced top padding
    final double horizontalPadding = screenWidth * 0.05;
    final double sectionSpacing = screenHeight * 0.025; // Reduced spacing between sections
    final double cardSpacing = screenHeight * 0.015;

    final double baseFontSize = screenWidth * 0.035; // Slightly smaller base font
    final double headerFontSize = baseFontSize * 1.4; // Reduced header size
    final double subHeaderFontSize = baseFontSize * 1.1;
    final double bodyFontSize = baseFontSize * 0.9;
    final double smallFontSize = baseFontSize * 0.75;

    final List<PatientAlert> patientAlerts = [
      PatientAlert(
        code: AlertCode.codeBlue,
        title: "🚨 Code Blue!",
        message: "Patient in ICU Bed 3 requires immediate resuscitation.",
        time: "1 min ago",
      ),
      PatientAlert(
        code: AlertCode.codeYellow,
        title: "⚠️ Code Yellow!",
        message: "Patient in Ward 5 showing rapid deterioration.",
        time: "5 mins ago",
      ),
      PatientAlert(
        code: AlertCode.codeOrange,
        title: "☣️ Code Orange!",
        message: "Patient in ER has hazardous exposure – use PPE.",
        time: "10 mins ago",
      ),
      PatientAlert(
        code: AlertCode.codeGreen,
        title: "🚑 Code Green!",
        message: "Transfer patient from Ward 2 to ICU immediately.",
        time: "15 mins ago",
      ),
      PatientAlert(
        code: AlertCode.notification,
        title: "New Task Assigned",
        message: "Complete the pre-op checklist for patient in Room 401.",
        time: "30 mins ago",
        icon: Icons.assignment_turned_in_outlined,
        iconColor: Colors.green.shade700,
      ),
    ];

    return Scaffold(
      key: const ValueKey('SmartCareHomeScreenScaffold'),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, 
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.whiteColor),
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppColors.errorRed, size: 20),
                    SizedBox(width: 10),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryDarkBlue, AppColors.midDarkBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          top: false,
          child: isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    MediaQuery.of(context).padding.top + kToolbarHeight, // Removed extra vertical padding here
                    horizontalPadding,
                    verticalPadding,
                  ),
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 375),
                    childAnimationBuilder: (widget) => SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(child: widget),
                    ),
                    children: [
                      // Compact Header
                      _buildHeader(headerFontSize, bodyFontSize),
                      
                      SizedBox(height: sectionSpacing * 0.8),
                      
                      // Stats Card
                      _buildQuickStats(bodyFontSize, subHeaderFontSize),
                      
                      SizedBox(height: sectionSpacing),
                      _buildSectionHeader("Today's Schedule", Icons.calendar_today_outlined, subHeaderFontSize),
                      
                      SizedBox(height: cardSpacing),
                      _buildScheduleCard(
                        "09:00 AM - 11:00 AM",
                        "Patient Visit: Mrs. Helen",
                        "Room 302, Cardiology",
                        AppColors.accentTeal,
                        bodyFontSize,
                        smallFontSize,
                      ),
                      
                      SizedBox(height: cardSpacing),
                      _buildScheduleCard(
                        "12:30 PM",
                        "Team Meeting",
                        "Conference Room A",
                        AppColors.lightBlue,
                        bodyFontSize,
                        smallFontSize,
                      ),
                      
                      SizedBox(height: sectionSpacing),
                      _buildSectionHeader("Notifications & Alerts", Icons.notifications_active_outlined, subHeaderFontSize),
                      
                      SizedBox(height: cardSpacing),
                      ...patientAlerts.map(
                        (alert) => _buildPatientAlertCard(alert, bodyFontSize, smallFontSize),
                      ),
                      SizedBox(height: sectionSpacing),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(double headerFontSize, double bodyFontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                clinicName.toUpperCase(),
                style: GoogleFonts.poppins(
                  color: AppColors.whiteColor.withOpacity(0.9),
                  fontStyle: FontStyle.italic,
                  fontSize: bodyFontSize * 0.75, // Smaller font
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2), // Reduced spacing
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "Hello, ",
                      style: GoogleFonts.poppins(
                        color: AppColors.whiteColor.withOpacity(0.9),
                        fontSize: bodyFontSize,
                      ),
                    ),
                    TextSpan(
                      text: fullName,
                      style: GoogleFonts.poppins(
                        color: AppColors.whiteColor,
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "ID: $userId • $userRole",
                  style: GoogleFonts.nunito(
                    color: Colors.white70,
                    fontSize: bodyFontSize * 0.75,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
          ),
          child: CircleAvatar(
            radius: 24, // Smaller radius
            backgroundColor: AppColors.whiteColor,
            child: Text(
              initial,
              style: GoogleFonts.poppins(
                fontSize: 20, // Smaller font
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDarkBlue,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats(double bodyFontSize, double subHeaderFontSize) {
    return ClipPath(
      clipper: CustomShapeClipper(),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        // Reduced padding to make the card more compact
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
                count: "12",
                label: "Patients",
                countFontSize: subHeaderFontSize * 1.2,
                labelFontSize: bodyFontSize),
            _StatItem(
                count: "04",
                label: "Tasks",
                countFontSize: subHeaderFontSize * 1.2,
                labelFontSize: bodyFontSize),
            _StatItem(
                count: "08",
                label: "Done",
                countFontSize: subHeaderFontSize * 1.2,
                labelFontSize: bodyFontSize),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, double fontSize) {
    return Row(
      children: [
        Icon(icon, color: AppColors.whiteColor, size: fontSize * 1.1),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: FontWeight.w600, // Slightly lighter weight
            color: AppColors.whiteColor,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleCard(String time, String title, String subtitle,
      Color color, double titleFontSize, double bodyFontSize) {
    return Card(
      margin: const EdgeInsets.only(bottom: 0),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // Compact padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.white70, size: 12),
                SizedBox(width: 5),
                Text(
                  time,
                  style: GoogleFonts.nunito(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: bodyFontSize * 0.9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: titleFontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.nunito(
                color: Colors.white.withOpacity(0.9),
                fontSize: bodyFontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientAlertCard(
      PatientAlert alert, double titleFontSize, double bodyFontSize) {
    Color cardColor;
    IconData cardIcon;
    Color iconColor;

    switch (alert.code) {
      case AlertCode.codeBlue:
        cardColor = Colors.blue.shade700;
        cardIcon = Icons.medical_services_outlined;
        iconColor = Colors.white;
        break;
      case AlertCode.codeYellow:
        cardColor = Colors.yellow.shade700;
        cardIcon = Icons.warning_amber_rounded;
        iconColor = Colors.black87;
        break;
      case AlertCode.codeOrange:
        cardColor = Colors.orange.shade700;
        cardIcon = Icons.masks_outlined;
        iconColor = Colors.white;
        break;
      case AlertCode.codeGreen:
        cardColor = Colors.green.shade700;
        cardIcon = Icons.local_hospital_outlined;
        iconColor = Colors.white;
        break;
      case AlertCode.codeWhite:
        cardColor = Colors.grey.shade300;
        cardIcon = Icons.mood_bad_outlined;
        iconColor = Colors.black87;
        break;
      case AlertCode.notification:
        cardColor = AppColors.whiteColor;
        cardIcon = alert.icon ?? Icons.notifications_none;
        iconColor = alert.iconColor ?? Colors.grey.shade700;
        break;
    }

    Color titleColor = (alert.code == AlertCode.codeYellow ||
        alert.code == AlertCode.codeWhite ||
        alert.code == AlertCode.notification)
        ? AppColors.textDark
        : AppColors.whiteColor;
    Color messageColor = (alert.code == AlertCode.codeYellow ||
        alert.code == AlertCode.codeWhite ||
        alert.code == AlertCode.notification)
        ? AppColors.textBodyColor
        : AppColors.whiteColor.withOpacity(0.8);
    Color timeColor = (alert.code == AlertCode.codeYellow ||
        alert.code == AlertCode.codeWhite ||
        alert.code == AlertCode.notification)
        ? AppColors.textBodyColor
        : AppColors.whiteColor.withOpacity(0.7);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(cardIcon, color: iconColor, size: titleFontSize),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: titleFontSize,
                            color: titleColor,
                          ),
                        ),
                      ),
                      Text(
                        alert.time,
                        style: GoogleFonts.nunito(
                          color: timeColor, 
                          fontSize: bodyFontSize * 0.8
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alert.message,
                    style: GoogleFonts.nunito(
                      color: messageColor,
                      fontSize: bodyFontSize,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String count;
  final String label;
  final double countFontSize;
  final double labelFontSize;

  const _StatItem({
    required this.count,
    required this.label,
    required this.countFontSize,
    required this.labelFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(
        children: [
          Text(
            count,
            style: GoogleFonts.poppins(
              fontSize: countFontSize,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDarkBlue,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: labelFontSize,
              color: AppColors.textBodyColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class CustomShapeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    // Made the curve shallower to reduce vertical space used
    path.lineTo(0, size.height * 0.9);
    path.quadraticBezierTo(
        size.width / 2, size.height, size.width, size.height * 0.9);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}