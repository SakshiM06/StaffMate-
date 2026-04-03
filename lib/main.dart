import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:staff_mate/pages/welcome_page.dart';
import 'package:staff_mate/pages/login_page.dart';
import 'package:staff_mate/pages/dashboard_page.dart';
import 'package:staff_mate/pages/nurse_page.dart';
import 'package:staff_mate/api/api_service.dart';
import 'package:staff_mate/services/session_manger.dart';
import 'package:staff_mate/pages/biometric_lock_screen.dart';
import 'package:staff_mate/services/biometric_auth_service.dart';
import 'package:staff_mate/pages/biometric_setup_page.dart';

void main() async {
  // Required before any async work in main
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait (optional — remove if you support landscape)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

/// Decides which screen to show on cold open.
/// Called once from AppStartRouter — never from build().
Future<String> determineStartRoute() async {
  try {
    // 1. Has user ever logged in on this device?
    final hasPreviousLogin = await SessionManager.hasPreviousLogin();
    if (!hasPreviousLogin) {
      return '/login';
    }

    // 2. Biometric enabled and hardware available → show lock screen
    final biometricEnabled = await BiometricAuthService.isBiometricEnabled();
    final biometricAvailable = await BiometricAuthService.isBiometricAvailable();

    if (biometricEnabled && biometricAvailable) {
      return '/biometric-lock';
    }

    // 3. Biometric not set — is the session token still valid?
    final hasValidSession = await SessionManager.hasValidSession();
    if (hasValidSession) {
      SessionManager.startSessionMonitoring();
      return '/dashboard';
    }

    // 4. Everything expired — back to login
    return '/login';
  } catch (e) {
    debugPrint('determineStartRoute error: $e');
    return '/login';
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Staff Mate',
      debugShowCheckedModeBanner: false,
      // AppStartRouter is the true entry point — it resolves the route
      // asynchronously and replaces itself, so the user never sees a flash.
      home: const AppStartRouter(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => ActivityTracker(child: const DashboardPage()),
        '/nurse': (context) => const NursePage(),
        '/biometric-setup': (context) => BiometricSetupPage(
              onContinue: () {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/dashboard', (r) => false);
              },
              isFromSettings: false,
            ),
        '/biometric-lock': (context) => BiometricLockScreen(
              onContinue: () {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/dashboard', (r) => false);
              },
            ),
      },
    );
  }
}

/// Splash-style router shown only on cold open.
/// Resolves the start route async, then replaces itself — no flicker.
class AppStartRouter extends StatefulWidget {
  const AppStartRouter({super.key});

  @override
  State<AppStartRouter> createState() => _AppStartRouterState();
}

class _AppStartRouterState extends State<AppStartRouter> {
  @override
  void initState() {
    super.initState();
    // Run after the first frame so Navigator is ready
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    final route = await determineStartRoute();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    // Shown for the ~200ms while determineStartRoute() runs.
    // Matches your app's dark splash color so there's no white flash.
    return const Scaffold(
      backgroundColor: Color(0xFF0A0F2C),
      body: Center(
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}

/// Wraps any widget to track user activity globally.
/// Keeps the session alive as long as the user is interacting.
class ActivityTracker extends StatelessWidget {
  final Widget child;

  const ActivityTracker({super.key, required this.child});

  void _updateActivity() {
    SessionManager.updateUserActivity();
    ApiService.updateUserActivity();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Intercept all tap/drag/long-press without consuming them
      behavior: HitTestBehavior.translucent,
      onTap: _updateActivity,
      onPanStart: (_) => _updateActivity(),
      onLongPress: _updateActivity,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerMove: (_) => _updateActivity(),
        child: child,
      ),
    );
  }
}