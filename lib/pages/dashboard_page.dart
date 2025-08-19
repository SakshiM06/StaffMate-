import 'package:flutter/material.dart';
import 'package:staff_mate/pages/attendance_page.dart';
import 'package:staff_mate/pages/nurse_page.dart';
import 'package:staff_mate/pages/profile_page.dart';
import 'package:staff_mate/services/services_page.dart'; 
import 'package:staff_mate/pages/smartcarehomescreen.dart';
// import 'package:staff_mate/pages/bed_list_page.dart';   


class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  
  final List<Widget> _pages = const [
  SmartCareHomeScreen(),     
    NursePage(),
    AttendancePage(),
    ServicesPage(),  
    ProfilePage(),    

  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_hospital),
            label: 'Nurse',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_add),
            label: 'Attendance'
            ),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services),
            label: 'Services',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          
        ],
      ),
    );
  }
}
