import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/patient_alert_model.dart'; // Adjusted import path

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
      // Example of a generic notification using the same card style
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
              Color(0xFF7E90F8),
              Color(0xFF8B99FA),
              Color(0xFFB1B9FC),
              Color(0xFFE3E6FD),
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
                  const Color(0xFF4A47A3),
                ),
                _buildScheduleCard(
                  "12:30 PM",
                  "Team Meeting",
                  "Conference Room A",
                  const Color(0xFF005082),
                ),
                const SizedBox(height: 30),
                _buildSectionHeader("Notifications & Alerts", Icons.notifications_active_outlined),
                const SizedBox(height: 15),
                // Dynamically build patient alert cards
                ...patientAlerts.map((alert) => _buildPatientAlertCard(alert)), // Removed .toList()
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
                color: Colors.white70,
                fontSize: 18,
              ),
            ),
            Text(
              "Dr. Evelyn Reed",
              style: TextStyle(
                color: Colors.white,
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
          color: Colors.white,
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
        Icon(icon, color: Colors.black54, size: 28),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleCard(String time, String title, String subtitle, Color color) {
    return Card(
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
    Color iconColor; // For the internal icon in the card

    switch (alert.code) {
      case AlertCode.codeBlue:
        cardColor = Colors.blue.shade700;
        cardIcon = Icons.medical_services_outlined; // Or a specific 'critical' icon
        iconColor = Colors.white;
        break;
      case AlertCode.codeYellow:
        cardColor = Colors.yellow.shade700;
        cardIcon = Icons.warning_amber_rounded;
        iconColor = Colors.black87;
        break;
      case AlertCode.codeOrange:
        cardColor = Colors.orange.shade700;
        cardIcon = Icons.masks_outlined; // Represents PPE
        iconColor = Colors.white;
        break;
      case AlertCode.codeGreen:
        cardColor = Colors.green.shade700;
        cardIcon = Icons.local_hospital_outlined; // Represents transfer
        iconColor = Colors.white;
        break;
      case AlertCode.codeWhite:
        cardColor = Colors.grey.shade300; // Using a softer grey for white code
        cardIcon = Icons.mood_bad_outlined; // Represents aggression
        iconColor = Colors.black87;
        break;
      case AlertCode.notification:
        cardColor = Colors.white; // Default for general notifications
        cardIcon = alert.icon ?? Icons.notifications_none; // Use provided icon or default
        iconColor = alert.iconColor ?? Colors.grey.shade700;
        break;
      // Removed the 'default' clause as all enum values are explicitly handled
    }

    // Adjust text color based on card background for readability
    Color titleColor = (alert.code == AlertCode.codeYellow || alert.code == AlertCode.codeWhite || alert.code == AlertCode.notification)
        ? Colors.black87
        : Colors.white;
    Color messageColor = (alert.code == AlertCode.codeYellow || alert.code == AlertCode.codeWhite || alert.code == AlertCode.notification)
        ? Colors.grey.shade700
        : Colors.white70;
    Color timeColor = (alert.code == AlertCode.codeYellow || alert.code == AlertCode.codeWhite || alert.code == AlertCode.notification)
        ? Colors.grey.shade600
        : Colors.white60;


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
            // Using a slightly larger icon for alerts for better visibility
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

// --- HELPER WIDGETS AND CLASSES ---

// For the stats section items
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
            color: Color(0xFF4A47A3),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}

// Custom clipper for the unique shape
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