import 'package:flutter/material.dart';
import 'package:staff_mate/pages/welcome_page.dart';
import 'package:staff_mate/pages/login_page.dart';
import 'package:staff_mate/pages/dashboard_page.dart';
import 'package:staff_mate/pages/nurse_page.dart';
// import 'package:staff_mate/services/ipd_services.dart';
import 'package:staff_mate/tabs/ipd_tab.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Staff Mate',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomePage(),
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/nurse': (context) => const NursePage(),
        'services':(context) => const IPDTab(),
      },
    );
  }
}
