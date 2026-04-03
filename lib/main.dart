import 'package:flutter/material.dart';
import 'package:staff_mate/pages/welcome_page.dart';
import 'package:staff_mate/pages/login_page.dart';
import 'package:staff_mate/pages/dashboard_page.dart';
import 'package:staff_mate/pages/nurse_page.dart';
import 'package:staff_mate/api/api_service.dart';
import 'package:staff_mate/services/session_manger.dart';
import 'package:staff_mate/pages/biometric_lock_screen.dart';
import 'package:staff_mate/services/biometric_auth_service.dart';
// import 'package:staff_mate/services/ipd_services.dart';
// import 'package:staff_mate/tabs/ipd_tab.dart';

void main() {
  runApp(const MyApp());
}

Future<Widget> determineStartScreen() async {
  // 1. Does any session exist at all?
  final hasPreviousLogin = await SessionManager.hasPreviousLogin();
  if (!hasPreviousLogin) {
    // Fresh install or full logout — go straight to login
    return const LoginPage();
  }
 
  // 2. Is biometric enabled AND the secure key still valid?
  final biometricEnabled = await BiometricAuthService.isBiometricEnabled();
  final biometricAvailable = await BiometricAuthService.isBiometricAvailable();
 
  if (biometricEnabled && biometricAvailable) {
    // Show biometric lock screen — it handles token refresh internally
    // NO re-login needed unless refresh token is also expired
    return BiometricLockScreen(
      onContinue: () {
        // Navigate to dashboard after successful biometric authentication
      },
    );
  }
 
  // 3. Biometric not enabled — check if session/token is still valid
  final hasValidSession = await SessionManager.hasValidSession();
  if (hasValidSession) {
    // Token still valid (app was closed recently) — go to dashboard
    SessionManager.startSessionMonitoring();
    return const DashboardPage(); // replace with your dashboard widget
  }
 
  // 4. Session expired — go to login
  return const LoginPage();
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
        '/biometric': (context) => BiometricLockScreen(
          onContinue: () {
            Navigator.of(context).pushReplacementNamed('/dashboard');
          },
        ),
        '/nurse': (context) => const NursePage(),
        // 'services':(context) => const IPDTab(),
      },
    );
  }
}

// Activity tracker widget to monitor user interactions globally
class ActivityTracker extends StatefulWidget {
  final Widget child;
  
  const ActivityTracker({super.key, required this.child});
  
  @override
  State<ActivityTracker> createState() => _ActivityTrackerState();
}

class _ActivityTrackerState extends State<ActivityTracker> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _updateActivity();
      },
      onPanStart: (details) {
        _updateActivity();
      },
      onLongPress: () {
        _updateActivity();
      },
      child: Listener(
        onPointerMove: (event) {
          _updateActivity();
        },
        child: widget.child,
      ),
    );
  }
  
  void _updateActivity() {
    SessionManager.updateUserActivity();
    ApiService.updateUserActivity();
  }
}