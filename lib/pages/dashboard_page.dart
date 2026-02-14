import 'package:flutter/material.dart';
import 'package:staff_mate/pages/attendance_page.dart';
import 'package:staff_mate/pages/ipd_dashboard_page.dart';
import 'package:staff_mate/pages/my_hr_screen.dart';
import 'package:staff_mate/pages/mytasks.dart';
import 'package:staff_mate/pages/nurse_page.dart';
import 'package:staff_mate/pages/smartcarehomescreen.dart';
import 'package:staff_mate/pages/approval_queue.dart';
import 'package:staff_mate/pages/day_to_day_notes.dart';

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
    GlobalKey<NavigatorState>(), // Approval Queue - index 4
   // Day to Day Notes - index 5
  ];

  // The actual pages - MUST MATCH the order of navigator keys
  final List<Widget> _pages = [
    SmartCareHomeScreen(key: PageStorageKey('Page1')),
    IpdDashboardPage(key: PageStorageKey('Page4')),
    MyHRScreen(key: PageStorageKey('Page5')),
    MyTasksPage(key: PageStorageKey('Page6')),
    ApprovalQueuePage(key: PageStorageKey('Page7')),

  ];

  void _onItemTapped(int index) {
    if (_currentTab == index) {
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
    // Calculate available width for each tab
    final screenWidth = MediaQuery.of(context).size.width;
    final tabWidth = screenWidth / 5;

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
              _buildNavigator(4),
          
            ],
          ),
        ),
        bottomNavigationBar: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBottomNavItem(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                width: tabWidth,
              ),
              _buildBottomNavItem(
                index: 1,
                icon: Icons.medical_services_outlined,
                activeIcon: Icons.medical_services,
                label: 'IPD',
                width: tabWidth,
              ),
              _buildBottomNavItem(
                index: 2,
                icon: Icons.business_center_outlined,
                activeIcon: Icons.business_center,
                label: 'MY HR',
                width: tabWidth,
              ),
              _buildBottomNavItem(
                index: 3,
                icon: Icons.checklist_outlined,
                activeIcon: Icons.checklist,
                label: 'Tasks',
                width: tabWidth,
              ),
              _buildBottomNavItem(
                index: 4,
                icon: Icons.approval_outlined,
                activeIcon: Icons.approval,
                label: 'Approvals',
                width: tabWidth,
              ),
      
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required double width,
  }) {
    final isSelected = _currentTab == index;
    
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onItemTapped(index),
          splashColor: const Color(0xFF1A237E).withOpacity(0.1),
          highlightColor: const Color(0xFF1A237E).withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                margin: const EdgeInsets.only(bottom: 2),
                decoration: isSelected
                    ? BoxDecoration(
                        color: const Color(0xFF1A237E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                child: Icon(
                  isSelected ? activeIcon : icon,
                  size: 22,
                  color: isSelected ? const Color(0xFF1A237E) : Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? const Color(0xFF1A237E) : Colors.grey,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}