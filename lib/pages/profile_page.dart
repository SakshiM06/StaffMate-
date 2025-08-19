import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_mate/pages/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // State variables for all user data
  String? username;
  String? token;
  String? staffId;
  String? dept;
  String? role;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        username = prefs.getString('username');
        token = prefs.getString('token');
        staffId = prefs.getString('staffId');
        dept = prefs.getString('dept');
        role = prefs.getString('role');
        isLoading = false;
      });
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // List of widgets for the scrollable section ONLY
    final List<Widget> contentWidgets = [
      _buildInfoPod(
        icon: Icons.badge_outlined,
        label: "Staff ID",
        value: staffId ?? '--',
        iconColor: const Color(0xFF6A5AE0),
      ),
      _buildInfoPod(
        icon: Icons.business_center_outlined,
        label: "Department",
        value: dept ?? '--',
        iconColor: const Color(0xFF3E8BFF),
      ),
      _buildInfoPod(
        icon: Icons.security_outlined,
        label: "Access Token",
        value: token != null ? "${token!.substring(0, 10)}..." : '--',
        iconColor: const Color(0xFF00BFA5),
      ),
      const SizedBox(height: 30),
      _buildLogoutButton(),
      const SizedBox(height: 30),
    ];

    return Scaffold(
      body: isLoading
          ? _buildLoadingScreen()
          : Stack(
              children: [
                // Layer 1: The background color
                Container(
                  color: const Color(0xFFE3E6FD),
                ),

                // Layer 2: The scrollable content with animations
                AnimationLimiter(
                  child: Padding(
                    // =================================================================
                    // THE FIX IS HERE: Increased padding to shift the content down.
                    // =================================================================
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).size.height * 0.40, // Was 0.35
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      itemCount: contentWidgets.length,
                      itemBuilder: (context, index) {
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 500),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child: contentWidgets[index],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                AnimationConfiguration.staggeredList(
                  position: 0,
                  duration: const Duration(milliseconds: 500),
                  child: SlideAnimation(
                    verticalOffset: -50.0, // Slides down from the top
                    child: FadeInAnimation(
                      child: _buildFloatingHeader(),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // --- WIDGET BUILDING METHODS ---

  Widget _buildLoadingScreen() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7E90F8), Color(0xFFE3E6FD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }

  Widget _buildFloatingHeader() {
    // The header is now taller to accommodate the name and role
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.38,
      child: Stack(
        children: [
          // The curved shape
          ClipPath(
            clipper: ProfileHeaderClipper(),
            child: Container(
              height: 250,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7E90F8), Color(0xFF8B99FA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          // The logout button
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.logout, color: Colors.white, size: 28),
                tooltip: "Logout",
                onPressed: logout,
              ),
            ),
          ),
          // Positioned Column for Avatar, Name, and Role
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .15),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const CircleAvatar(
                    radius: 60,
                    backgroundColor: Color(0xFFE3E6FD),
                    child: Icon(
                      Icons.person_rounded,
                      size: 70,
                      color: Color(0xFF7E90F8),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  username ?? 'Loading...',
                  style: const TextStyle(
                    color: Color(0xFF333D79),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role ?? 'Staff Member',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPod({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: .1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: logout,
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text(
          "Logout",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7E90F8),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 5,
          shadowColor: const Color(0xFF7E90F8).withValues(alpha: .4),
        ),
      ),
    );
  }
}

class ProfileHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(
        size.width / 2, size.height, size.width, size.height - 50);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}