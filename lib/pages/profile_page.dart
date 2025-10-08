import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_mate/pages/login_page.dart';
import 'package:staff_mate/pages/submit_ticket_page.dart';
import 'package:staff_mate/services/session_manger.dart';

// Assuming AppColors is defined as in your original code
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

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? bearer;
  String? clinicId;
  String? userId;
  String? userName;
  String? zoneid;
  String? expiryTime;
  String? authToken;
  String? branchId;
  bool isLoading = true;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionData = await SessionManager.getSession();

      if (mounted) {
        setState(() {
          bearer = sessionData['bearer'] ?? prefs.getString('bearer') ?? '--';
          clinicId = sessionData['clinicId'] ?? prefs.getString('clinicId') ?? '--';
          userId = sessionData['userId'] ?? prefs.getString('userId') ?? '--';
          userName = prefs.getString('userName') ?? userId ?? '--';
          zoneid = prefs.getString('zoneid') ?? 'Asia/Kolkata';
          expiryTime = prefs.getString('expiryTime') ?? '--';
          authToken = prefs.getString('auth_token') ?? '--';
          branchId = prefs.getString('branch_id') ?? '1';
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> logout() async {
    await SessionManager.clearSession();
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
    // Get screen dimensions for responsiveness
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;

    final List<Widget> contentWidgets = [
      _buildInfoPod(
        icon: Icons.person_outline,
        label: "Username",
        value: userName ?? '--',
        iconColor: AppColors.accentTeal,
      ),
      _buildInfoPod(
        icon: Icons.badge_outlined,
        label: "User ID",
        value: userId ?? '--',
        iconColor: AppColors.lightBlue,
      ),
      _buildInfoPod(
        icon: Icons.business_center_outlined,
        label: "Clinic ID",
        value: clinicId ?? '--',
        iconColor: AppColors.primaryDarkBlue,
      ),
      _buildInfoPod(
        icon: Icons.location_on_outlined,
        label: "Zone ID",
        value: zoneid ?? '--',
        iconColor: AppColors.darkerAccentTeal,
      ),
      _buildInfoPod(
        icon: Icons.access_time_outlined,
        label: "Token Expiry",
        value: expiryTime != null && expiryTime != '--'
            ? _formatExpiryTime(expiryTime!)
            : '--',
        iconColor: AppColors.warningOrange,
      ),
      _buildInfoPod(
        icon: Icons.security_outlined,
        label: "Bearer Token",
        value: bearer != null && bearer != '--'
            ? "${bearer!.substring(0, bearer!.length > 15 ? 15 : bearer!.length)}..."
            : '--',
        iconColor: AppColors.midDarkBlue,
      ),
      SizedBox(height: screenHeight * 0.03), // Responsive spacing
      _buildLogoutButton(screenWidth), // Pass screenWidth for button responsiveness
      SizedBox(height: screenHeight * 0.03), // Responsive spacing
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightGreyColor,
      drawer: _buildDrawer(screenHeight, screenWidth), // Pass dimensions to drawer
      body: isLoading
          ? _buildLoadingScreen()
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(screenHeight, screenWidth), // Pass dimensions to app bar
                SliverToBoxAdapter(
                  child: AnimationLimiter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.05, // Responsive padding
                          vertical: screenHeight * 0.02), // Responsive padding
                      child: Column(
                        children: AnimationConfiguration.toStaggeredList(
                          duration: const Duration(milliseconds: 500),
                          childAnimationBuilder: (widget) => SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child: widget,
                            ),
                          ),
                          children: contentWidgets,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _formatExpiryTime(String expiryTime) {
    try {
      if (expiryTime.contains('T')) {
        final dateTime = DateTime.parse(expiryTime);
        return "${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
      }
      return expiryTime;
    } catch (e) {
      return expiryTime;
    }
  }

  Widget _buildLoadingScreen() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDarkBlue, AppColors.midDarkBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.whiteColor),
      ),
    );
  }

  Widget _buildSliverAppBar(double screenHeight, double screenWidth) {
    return SliverAppBar(
      expandedHeight: screenHeight * 0.35, // Responsive expanded height
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primaryDarkBlue,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDarkBlue, AppColors.midDarkBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Decorative wave at the bottom of the header
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: CustomPaint(
                painter: HeaderWavePainter(color: AppColors.lightGreyColor.withValues(alpha: .1)), // Slightly transparent wave
                child: Container(height: screenHeight * 0.05), // Responsive wave height
              ),
            ),
            Positioned(
              bottom: screenHeight * 0.03, // Responsive positioning
              left: 0,
              right: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.whiteColor, width: screenWidth * 0.01), // Responsive border width
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentTeal.withValues(alpha: .4),
                          spreadRadius: screenWidth * 0.008, // Responsive spread radius
                          blurRadius: screenWidth * 0.02, // Responsive blur radius
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: screenWidth * 0.15, // Responsive avatar size
                      backgroundColor: AppColors.accentTeal,
                      child: Icon(
                        Icons.person_rounded,
                        size: screenWidth * 0.18, // Responsive icon size
                        color: AppColors.whiteColor,
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.015), // Responsive spacing
                  Text(
                    userName ?? userId ?? 'Loading...',
                    style: GoogleFonts.poppins(
                      color: AppColors.whiteColor,
                      fontSize: screenWidth * 0.07, // Responsive font size
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.005), // Responsive spacing
                  Text(
                    clinicId ?? 'Clinic',
                    style: GoogleFonts.nunito(
                      color: AppColors.lightBlue,
                      fontSize: screenWidth * 0.045, // Responsive font size
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.menu, color: AppColors.whiteColor, size: screenWidth * 0.07), // Responsive icon size
        tooltip: "Menu",
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.logout, color: AppColors.whiteColor, size: screenWidth * 0.07), // Responsive icon size
          tooltip: "Logout",
          onPressed: logout,
        ),
      ],
    );
  }

  Widget _buildInfoPod({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Card(
      margin: EdgeInsets.only(bottom: screenWidth * 0.04), // Responsive margin
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: .15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(screenWidth * 0.05)), // Responsive border radius
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.05), // Responsive padding
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(screenWidth * 0.025), // Responsive padding
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(screenWidth * 0.035), // Responsive border radius
              ),
              child: Icon(icon, color: iconColor, size: screenWidth * 0.07), // Responsive icon size
            ),
            SizedBox(width: screenWidth * 0.05), // Responsive spacing
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.nunito(
                      color: AppColors.textBodyColor,
                      fontSize: screenWidth * 0.038, // Responsive font size
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.01), // Responsive spacing
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      color: AppColors.textDark,
                      fontSize: screenWidth * 0.045, // Responsive font size
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(double screenWidth) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: logout,
        icon: Icon(Icons.logout, color: AppColors.whiteColor, size: screenWidth * 0.06), // Responsive icon size
        label: Text(
          "Logout",
          style: GoogleFonts.poppins(
            color: AppColors.whiteColor,
            fontWeight: FontWeight.bold,
            fontSize: screenWidth * 0.045, // Responsive font size
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.errorRed,
          padding: EdgeInsets.symmetric(vertical: screenWidth * 0.045), // Responsive padding
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(screenWidth * 0.05), // Responsive border radius
          ),
          elevation: 8,
          shadowColor: AppColors.errorRed.withValues(alpha: .5),
        ),
      ),
    );
  }

  Widget _buildDrawer(double screenHeight, double screenWidth) {
    return Drawer(
      child: Container(
        color: AppColors.lightGreyColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDarkBlue, AppColors.midDarkBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: screenWidth * 0.075, // Responsive avatar size
                    backgroundColor: AppColors.accentTeal,
                    child: Icon(
                      Icons.person_rounded,
                      size: screenWidth * 0.1, // Responsive icon size
                      color: AppColors.whiteColor,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01), // Responsive spacing
                  Text(
                    userName ?? userId ?? 'User',
                    style: GoogleFonts.poppins(
                      color: AppColors.whiteColor,
                      fontSize: screenWidth * 0.055, // Responsive font size
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    clinicId ?? 'Clinic',
                    style: GoogleFonts.nunito(
                      color: AppColors.lightBlue,
                      fontSize: screenWidth * 0.035, // Responsive font size
                    ),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              icon: Icons.dashboard_outlined,
              text: 'Approval Dashboard',
              onTap: () {},
              screenWidth: screenWidth,
            ),
            _buildDrawerItem(
              icon: Icons.outbox_outlined,
              text: 'Submit Ticket',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SubmitTicketPage()),
                );
              },
              screenWidth: screenWidth,
            ),
            _buildDrawerItem(
              icon: Icons.history_outlined,
              text: 'Token History',
              onTap: () {},
              screenWidth: screenWidth,
            ),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: Icon(Icons.date_range_outlined, color: AppColors.textDark, size: screenWidth * 0.06), // Responsive icon size
                title: Text(
                  'Attendance Record',
                  style: GoogleFonts.poppins(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: screenWidth * 0.04, // Responsive font size
                  ),
                ),
                children: <Widget>[
                  _buildSubDrawerItem(
                    icon: Icons.calendar_today_outlined,
                    text: 'Monthly',
                    onTap: () {},
                    screenWidth: screenWidth,
                  ),
                  _buildSubDrawerItem(
                    icon: Icons.beach_access_outlined,
                    text: 'Gov Leave',
                    onTap: () {},
                    screenWidth: screenWidth,
                  ),
                ],
              ),
            ),
            Divider(height: screenHeight * 0.025, thickness: 1, indent: screenWidth * 0.05, endIndent: screenWidth * 0.05), // Responsive divider
            _buildDrawerItem(
              icon: Icons.info_outline,
              text: 'About Us',
              onTap: () {},
              screenWidth: screenWidth,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String text,
    required GestureTapCallback onTap,
    required double screenWidth,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textDark, size: screenWidth * 0.06), // Responsive icon size
      title: Text(
        text,
        style: GoogleFonts.poppins(
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
          fontSize: screenWidth * 0.04, // Responsive font size
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildSubDrawerItem({
    required IconData icon,
    required String text,
    required GestureTapCallback onTap,
    required double screenWidth,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: screenWidth * 0.06), // Responsive padding
      child: ListTile(
        leading: Icon(icon, color: AppColors.accentTeal, size: screenWidth * 0.05), // Responsive icon size
        title: Text(
          text,
          style: GoogleFonts.nunito(
            color: AppColors.accentTeal,
            fontWeight: FontWeight.normal,
            fontSize: screenWidth * 0.038, // Responsive font size
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

// Custom painter for the wave effect in the header
class HeaderWavePainter extends CustomPainter {
  final Color color;

  HeaderWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();

    path.lineTo(0, size.height * 0.8);
    path.quadraticBezierTo(size.width * 0.25, size.height, size.width * 0.5, size.height * 0.8);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.6, size.width, size.height * 0.8);
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// The ProfileHeaderClipper is no longer needed with SliverAppBar
// but kept here just in case you want to use it elsewhere.
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