import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
 
class SmartCareHomeScreen extends StatelessWidget {
  const SmartCareHomeScreen({super.key});
 
  @override
  Widget build(BuildContext context) {
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

                _buildNotificationCard(

                  "New Task Assigned",

                  "Complete the pre-op checklist for patient in Room 401.",

                  "2 mins ago",

                  Icons.assignment_turned_in_outlined,

                  Colors.green.shade700

                ),

                _buildNotificationCard(

                  "Urgent Alert",

                  "Patient in Room 205 has a critical heart rate alert.",

                  "5 mins ago",

                  Icons.warning_amber_rounded,

                  Colors.red.shade700

                ),

                 _buildNotificationCard(

                  "Announcement",

                  "New hospital-wide policy on visitor hours will be effective from Monday.",

                  "1 hour ago",

                  Icons.campaign_outlined,

                  Colors.blue.shade700

                ),

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

      shadowColor: Colors.black.withValues(alpha: 0.1),

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
 
  Widget _buildNotificationCard(String title, String message, String time, IconData icon, Color iconColor) {

    return Card(

      margin: const EdgeInsets.only(bottom: 12),

      elevation: 2,

      shadowColor: Colors.black.withValues(alpha: .05),

      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),

      child: Padding(

        padding: const EdgeInsets.all(12.0),

        child: Row(

          children: [

            Icon(icon, color: iconColor, size: 30),

            const SizedBox(width: 15),

            Expanded(

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text(

                    title,

                    style: const TextStyle(

                      fontWeight: FontWeight.bold,

                      fontSize: 16,

                      color: Color(0xFF333333),

                    ),

                  ),

                  const SizedBox(height: 4),

                  Text(

                    message,

                    style: TextStyle(

                      color: Colors.grey[600],

                      fontSize: 14,

                    ),

                  ),

                ],

              ),

            ),

             const SizedBox(width: 10),

             Text(

                time,

                style: TextStyle(color: Colors.grey[500], fontSize: 12),

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
 