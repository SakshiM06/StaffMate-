import 'package:flutter/material.dart';
import 'package:staff_mate/pages/attendance_page.dart';
import 'package:staff_mate/pages/ipd_dashboard_page.dart';
import 'package:staff_mate/pages/nurse_page.dart';
import 'package:staff_mate/pages/profile_page.dart';
import 'package:staff_mate/pages/smartcarehomescreen.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentTab = 0;

  // This bucket stores the state of the pages (data, scroll position)
  final PageStorageBucket _bucket = PageStorageBucket();

  // Keys to maintain nested navigation
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(), // Home
    // GlobalKey<NavigatorState>(), // Nurse (COMMENTED OUT)
    // GlobalKey<NavigatorState>(), // Attendance (COMMENTED OUT)
    GlobalKey<NavigatorState>(), // IPD
    GlobalKey<NavigatorState>(), // Profile
  ];

  // The actual pages
  final List<Widget> _pages = const [
    SmartCareHomeScreen(key: PageStorageKey('Page1')),
    // NursePage(key: PageStorageKey('Page2')), // COMMENTED OUT
    // AttendancePage(key: PageStorageKey('Page3')), // COMMENTED OUT
    IpdDashboardPage(key: PageStorageKey('Page4')),
    ProfilePage(key: PageStorageKey('Page5')),
  ];

  void _onItemTapped(int index) {
    if (_currentTab == index) {
      // If tapping the same tab, go back to the first screen of that tab
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _currentTab = index;
      });
    }
  }

  Widget _buildNavigator(int index) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (RouteSettings settings) {
        return MaterialPageRoute(
          maintainState: true,
          builder: (context) => _pages[index],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // PopScope handles the Android Back Button logic
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        // Check if the current tab can go back
        final NavigatorState? currentNavigator = _navigatorKeys[_currentTab].currentState;
        if (currentNavigator != null && currentNavigator.canPop()) {
          currentNavigator.pop();
        } else {
          // If we are at the root of a tab, go to Home or close app
          if (_currentTab != 0) {
            setState(() => _currentTab = 0);
          } else {
            // Close the app if on Home Page
            if (context.mounted) Navigator.of(context).pop(); 
          }
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false, // Prevents keyboard from pushing Navbar up
        body: PageStorage(
          bucket: _bucket,
          // Using IndexedStack allows switching instanty, but loads all at once.
          // If you want to load ONLY when clicked, replace IndexedStack with:
          // child: _buildNavigator(_currentTab), 
          // But that won't keep the bottom bar state perfect without IndexedStack.
          
          child: IndexedStack(
            index: _currentTab,
            children: [
              _buildNavigator(0),
              // _buildNavigator(1), // Nurse (COMMENTED OUT)
              // _buildNavigator(2), // Attendance (COMMENTED OUT)
              _buildNavigator(1), // IPD (now index 1 since we removed Nurse)
              _buildNavigator(2), // Profile (now index 2 since we removed Attendance)
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF1A237E),
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            // BottomNavigationBarItem(icon: Icon(Icons.local_hospital), label: 'Nurse'), // COMMENTED OUT
            // BottomNavigationBarItem(icon: Icon(Icons.group_add), label: 'Attendance'), // COMMENTED OUT
            BottomNavigationBarItem(icon: Icon(Icons.medical_services), label: 'IPD'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}