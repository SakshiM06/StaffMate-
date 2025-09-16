import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/patient_alert_model.dart'; // Adjusted import path

// Ensure you have this model file in your project:
// lib/models/patient_alert_model.dart
/*
import 'package:flutter/material.dart';

enum AlertCode {
  codeBlue,
  codeYellow,
  codeOrange,
  codeGreen,
  codeWhite,
  notification,
}

class PatientAlert {
  final AlertCode code;
  final String title;
  final String message;
  final String time;
  final IconData? icon;
  final Color? iconColor;

  PatientAlert({
    required this.code,
    required this.title,
    required this.message,
    required this.time,
    this.icon,
    this.iconColor,
  });
}
*/

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
}

class SmartCareHomeScreen extends StatelessWidget {
  const SmartCareHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions once at the top
    final Size screenSize = MediaQuery.of(context).size;
    final double screenHeight = screenSize.height;
    final double screenWidth = screenSize.width;

    // Responsive Spacing
    final double verticalPadding = screenHeight * 0.02; // 2% of screen height
    final double horizontalPadding = screenWidth * 0.05; // 5% of screen width
    final double sectionSpacing = screenHeight * 0.03; // 3% of screen height
    final double cardSpacing = screenHeight * 0.015; // 1.5% of screen height

    // Responsive Font Sizes (base font size and then scale)
    // Using a base font size relative to width helps maintain consistency across different device widths
    final double baseFontSize = screenWidth * 0.038; // Adjusted for better scaling
    final double headerFontSize = baseFontSize * 1.5; // e.g., 1.5 times base
    final double subHeaderFontSize = baseFontSize * 1.2; // e.g., 1.2 times base
    final double bodyFontSize = baseFontSize * 0.9; // e.g., 0.9 times base
    final double smallFontSize = baseFontSize * 0.7; // e.g., 0.7 times base

    // Simulated patient alerts
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
        code: AlertCode.codeWhite,
        title: "⚠️ Code White!",
        message: "Patient in Ward 7 aggressive – assistance required.",
        time: "20 mins ago",
      ),
      PatientAlert(
        code: AlertCode.notification,
        title: "New Task Assigned",
        message: "Complete the pre-op checklist for patient in Room 401.",
        time: "30 mins ago",
        icon: Icons.assignment_turned_in_outlined,
        iconColor: Colors.green.shade700,
      ),
      PatientAlert(
        code: AlertCode.notification,
        title: "Announcement",
        message:
        "New hospital-wide policy on visitor hours will be effective from Monday.",
        time: "1 hour ago",
        icon: Icons.campaign_outlined,
        iconColor: Colors.blue.shade700,
      ),
    ];

    return Scaffold(
      // Ensure the Scaffold has a key if it's used in a complex widget tree
      key: const ValueKey('SmartCareHomeScreenScaffold'),
      extendBodyBehindAppBar:
      true, // Allows the body content to go behind the app bar
      appBar: AppBar(
        backgroundColor: Colors
            .transparent, // Making AppBar transparent to show the gradient background
        elevation: 0, // No shadow
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.whiteColor),
          onPressed: () {
            // Navigator.of(context).pop(); // Example: Go back
          },
        ),
        // You can add more actions here if needed
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.whiteColor),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.whiteColor),
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        // The entire screen background with a gradient
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryDarkBlue,
              AppColors.midDarkBlue,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child:
        // Use SafeArea to ensure content isn't obscured by system UI (like notches, status bar)
        SafeArea(
          // Only apply bottom safety to allow the top to be handled by AppBar's extendBodyBehindAppBar
          top: false,
          child: ListView(
            // Apply horizontal padding and dynamic top padding for content below the AppBar
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              MediaQuery.of(context).padding.top +
                  kToolbarHeight +
                  verticalPadding, // kToolbarHeight is the standard AppBar height
              horizontalPadding,
              verticalPadding,
            ),
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 375),
              childAnimationBuilder: (widget) => SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: widget,
                ),
              ),
              children: [
                _buildHeader(headerFontSize, bodyFontSize),
                SizedBox(height: sectionSpacing),
                _buildQuickStats(bodyFontSize, subHeaderFontSize),
                SizedBox(height: sectionSpacing),
                _buildSectionHeader("Today's Schedule",
                    Icons.calendar_today_outlined, subHeaderFontSize),
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
                _buildSectionHeader("Notifications & Alerts",
                    Icons.notifications_active_outlined, subHeaderFontSize),
                SizedBox(height: cardSpacing),
                ...patientAlerts.map(
                      (alert) => _buildPatientAlertCard(
                      alert, bodyFontSize, smallFontSize),
                ),
                SizedBox(
                    height:
                    sectionSpacing), 
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildHeader(double headerFontSize, double bodyFontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome back,",
              style: TextStyle(
                color: AppColors.lightGreyColor,
                fontSize: bodyFontSize,
              ),
            ),
            Text(
              "Dr. Evelyn Reed",
              style: TextStyle(
                color: AppColors.whiteColor,
                fontSize: headerFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const CircleAvatar(
          radius: 30, // Can be made responsive with screenWidth * 0.07 or similar
          backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=32'),
          backgroundColor: AppColors.lightGreyColor, // Fallback background
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
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.fromLTRB(25, 30, 25, 40),
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
                label: "Pending Tasks",
                countFontSize: subHeaderFontSize * 1.2,
                labelFontSize: bodyFontSize),
            _StatItem(
                count: "08",
                label: "Completed",
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
        Icon(icon, color: AppColors.whiteColor, size: fontSize * 1.2),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
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
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: .1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              time,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .8),
                fontSize: bodyFontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .9),
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
        : AppColors.whiteColor.withValues(alpha: .7);
    Color timeColor = (alert.code == AlertCode.codeYellow ||
        alert.code == AlertCode.codeWhite ||
        alert.code == AlertCode.notification)
        ? AppColors.textBodyColor
        : AppColors.whiteColor.withValues(alpha: .6);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: .1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(15),
        ),
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(cardIcon, color: iconColor, size: titleFontSize * 1.5),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: titleFontSize,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.message,
                    style: TextStyle(
                      color: messageColor,
                      fontSize: bodyFontSize,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              alert.time,
              style: TextStyle(color: timeColor, fontSize: bodyFontSize * 0.8),
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
            style: TextStyle(
              fontSize: countFontSize,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDarkBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: labelFontSize,
              color: AppColors.textBodyColor,
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
    path.lineTo(0, size.height * 0.85);
    path.quadraticBezierTo(
        size.width / 2, size.height, size.width, size.height * 0.85);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}