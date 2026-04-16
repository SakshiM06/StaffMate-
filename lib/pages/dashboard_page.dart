import 'package:flutter/material.dart';
import 'package:staff_mate/pages/attendance_page.dart';
import 'package:staff_mate/pages/ipd_dashboard_page.dart';
import 'package:staff_mate/pages/mytasks.dart';
import 'package:staff_mate/pages/nurse_page.dart';
import 'package:staff_mate/pages/smartcarehomescreen.dart';
import 'package:staff_mate/pages/approval_queue.dart';
import 'package:staff_mate/pages/day_to_day_notes.dart';
import 'package:staff_mate/api/api_service.dart';
import 'package:staff_mate/services/session_manger.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentTab = 0;

  final PageStorageBucket _bucket = PageStorageBucket();

  // Keys to maintain nested navigation
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(), // Home - index 0
    GlobalKey<NavigatorState>(), // IPD - index 1
    GlobalKey<NavigatorState>(), // MY HR - index 2
    GlobalKey<NavigatorState>(), // My Tasks - index 3
  ];

  // The actual pages
  final List<Widget> _pages = [
    const SmartCareHomeScreen(key: PageStorageKey('Page1')),
    const IpdDashboardPage(key: PageStorageKey('Page4')),
    const SizedBox.shrink(), // Empty widget for MY HR
    const MyTasksPage(key: PageStorageKey('Page6')),
  ];

  @override
  void initState() {
    super.initState();
    
    // Set session expiry callback
    SessionManager.setSessionExpiryCallback((showDialog) {
      if (showDialog && mounted) {
        _showSessionExpiryDialog();
      }
    });
  }

  // Public method to change tab from child pages
  void changeTab(int index) {
    if (index == 2) { // MY HR tab
      _showComingSoonMessage();
      return;
    }
    
    if (mounted) {
      setState(() {
        _currentTab = index;
      });
      // Update user activity
      SessionManager.updateUserActivity();
      ApiService.updateUserActivity();
    }
  }

  // Method to navigate to Tasks page and highlight the Tasks icon
  void navigateToTasks() {
    if (mounted) {
      setState(() {
        _currentTab = 3; // Tasks tab index
      });
      
      // Optional: Pop to root of tasks navigator if needed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatorKeys[3].currentState?.popUntil((route) => route.isFirst);
      });
      
      SessionManager.updateUserActivity();
      ApiService.updateUserActivity();
    }
  }

  void _showSessionExpiryDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Session Expiring Soon"),
          content: const Text(
            "Your session will expire in 5 seconds. Do you want to continue?"
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (!mounted) return;
                Navigator.of(dialogContext).pop();
                await _handleLogout();
              },
              child: const Text("Logout", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!mounted) return;
                Navigator.of(dialogContext).pop();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Refreshing session..."),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                
                final success = await ApiService.refreshUserToken();
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Session refreshed successfully"),
                      backgroundColor: Colors.green,
                    ),
                  );
                  SessionManager.updateUserActivity();
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Failed to refresh session. Please login again."),
                        backgroundColor: Colors.red,
                      ),
                    );
                    await _handleLogout();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
              ),
              child: const Text("Refresh Session"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    await SessionManager.fullLogout();
    ApiService.clearSession();
    
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  void _onItemTapped(int index) {
    // Update user activity on tab tap
    SessionManager.updateUserActivity();
    ApiService.updateUserActivity();
    
    if (index == 2) { // MY HR tab
      _showComingSoonMessage();
      return;
    }
    
    if (_currentTab == index) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _currentTab = index;
      });
    }
  }

  void _showComingSoonMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('HR features are coming soon! Stay tuned.'),
        backgroundColor: const Color(0xFF1A237E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final NavigatorState? currentNavigator = _navigatorKeys[_currentTab].currentState;
        if (currentNavigator != null && currentNavigator.canPop()) {
          currentNavigator.pop();
        } else {
          if (_currentTab != 0) {
            setState(() => _currentTab = 0);
          } else {
            if (context.mounted) Navigator.of(context).pop();
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          SessionManager.updateUserActivity();
          ApiService.updateUserActivity();
        },
        onPanUpdate: (details) {
          SessionManager.updateUserActivity();
          ApiService.updateUserActivity();
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: PageStorage(
            bucket: _bucket,
            child: IndexedStack(
              index: _currentTab,
              children: [
                _buildNavigator(0),
                _buildNavigator(1),
                _buildNavigator(2),
                _buildNavigator(3),
              ],
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentTab,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF1A237E),
            unselectedItemColor: Colors.grey,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            elevation: 8,
            onTap: _onItemTapped,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.medical_services_outlined),
                activeIcon: Icon(Icons.medical_services),
                label: 'IPD',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.business_center_outlined),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 16,
                        ),
                        child: const Text(
                          'SOON',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
                activeIcon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.business_center),
                    Positioned(
                      top: -8,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 16,
                        ),
                        child: const Text(
                          'SOON',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
                label: 'MY HR',
                backgroundColor: Colors.white,
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.checklist_outlined),
                activeIcon: Icon(Icons.checklist),
                label: 'Tasks',
              ),
            ],
          ),
        ),
      ),
    );
  }
}