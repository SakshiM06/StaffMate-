import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/patient_alert_model.dart'; // Adjusted import path

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
        message: "New hospital-wide policy on visitor hours will be effective from Monday.",
        time: "1 hour ago",
        icon: Icons.campaign_outlined,
        iconColor: Colors.blue.shade700,
      ),
    ];

    return Scaffold(
      body: Container(
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
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 375),
              childAnimationBuilder: (widget) => SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: widget,
                ),
              ),
              children: [
                const SizedBox(height: 20),
                _buildHeader(),
                const SizedBox(height: 30),
                _buildQuickStats(),
                const SizedBox(height: 20),
                _buildSectionHeader("Today's Schedule", Icons.calendar_today_outlined),
                const SizedBox(height: 15),
                _buildScheduleCard(
                  "09:00 AM - 11:00 AM",
                  "Patient Visit: Mrs. Helen",
                  "Room 302, Cardiology",
                  AppColors.accentTeal, 
                ),
                _buildScheduleCard(
                  "12:30 PM",
                  "Team Meeting",
                  "Conference Room A",
                  AppColors.lightBlue,
                ),
                const SizedBox(height: 30),
                _buildSectionHeader("Notifications & Alerts", Icons.notifications_active_outlined),
                const SizedBox(height: 15),
                ...patientAlerts.map((alert) => _buildPatientAlertCard(alert)),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildHeader() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome back,",
              style: TextStyle(
                color: AppColors.lightGreyColor, 
                fontSize: 18,
              ),
            ),
            Text(
              "Dr. Evelyn Reed",
              style: TextStyle(
                color: AppColors.whiteColor,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        CircleAvatar(
          radius: 30,
          backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=32'),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return ClipPath(
      clipper: CustomShapeClipper(),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.whiteColor,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.fromLTRB(25, 30, 25, 40),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(count: "12", label: "Patients"),
            _StatItem(count: "04", label: "Pending Tasks"),
            _StatItem(count: "08", label: "Completed"),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.whiteColor, size: 28), 
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.whiteColor, 
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleCard(String time, String title, String subtitle, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12), 
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
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .9),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientAlertCard(PatientAlert alert) {
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

    Color titleColor = (alert.code == AlertCode.codeYellow || alert.code == AlertCode.codeWhite || alert.code == AlertCode.notification)
        ? AppColors.textDark 
        : AppColors.whiteColor;
    Color messageColor = (alert.code == AlertCode.codeYellow || alert.code == AlertCode.codeWhite || alert.code == AlertCode.notification)
        ? AppColors.textBodyColor 
        : AppColors.whiteColor.withValues(alpha: .7);
    Color timeColor = (alert.code == AlertCode.codeYellow || alert.code == AlertCode.codeWhite || alert.code == AlertCode.notification)
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
            Icon(cardIcon, color: iconColor, size: 36),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.message,
                    style: TextStyle(
                      color: messageColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              alert.time,
              style: TextStyle(color: timeColor, fontSize: 12),
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
  const _StatItem({required this.count, required this.label});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDarkBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textBodyColor, 
          ),
        ),
      ],
    );
  }
}

class CustomShapeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(
        size.width / 2, size.height, size.width, size.height - 30);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}