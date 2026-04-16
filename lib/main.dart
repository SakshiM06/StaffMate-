import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:staff_mate/pages/session_gate.dart';
import 'package:staff_mate/pages/welcome_page.dart';
import 'package:staff_mate/pages/login_page.dart';
import 'package:staff_mate/pages/dashboard_page.dart';
import 'package:staff_mate/pages/nurse_page.dart';
import 'package:staff_mate/api/api_service.dart';
import 'package:staff_mate/services/session_manger.dart';
import 'package:staff_mate/pages/biometric_lock_screen.dart';
import 'package:staff_mate/services/biometric_auth_service.dart';
import 'package:staff_mate/pages/biometric_setup_page.dart';
import 'package:staff_mate/pages/settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}
Future<String> determineStartRoute() async {
  try {
    final hasPreviousLogin = await SessionManager.hasPreviousLogin();
    if (!hasPreviousLogin) {
      return '/login';
    }

    final biometricEnabled = await BiometricAuthService.isBiometricEnabled();
    final biometricAvailable = await BiometricAuthService.isBiometricAvailable();

    if (biometricEnabled && biometricAvailable) {
      return '/biometric-lock';
    }

    final hasValidSession = await SessionManager.hasValidSession();
    if (hasValidSession) {
      // ✅ ADD THIS — refresh token silently before routing to dashboard
      try {
        await ApiService.refreshUserToken();
      } catch (e) {
        debugPrint('Silent token refresh failed: $e');
        // Don't block routing — local session still valid
      }
      SessionManager.updateUserActivity(); 
      SessionManager.startSessionMonitoring();
      return '/dashboard';
    }

    return '/login';
  } catch (e) {
    debugPrint('determineStartRoute error: $e');
    return '/login';
  }
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildTheme(bool isDark, double fontSize) {
    const primaryColor = Color(0xFF1A237E);

    final textTheme = TextTheme(
      displayLarge:  TextStyle(fontSize: fontSize + 18),
      displayMedium: TextStyle(fontSize: fontSize + 14),
      displaySmall:  TextStyle(fontSize: fontSize + 10),
      headlineLarge: TextStyle(fontSize: fontSize + 8),
      headlineMedium:TextStyle(fontSize: fontSize + 6),
      headlineSmall: TextStyle(fontSize: fontSize + 4),
      titleLarge:    TextStyle(fontSize: fontSize + 2),
      titleMedium:   TextStyle(fontSize: fontSize),
      titleSmall:    TextStyle(fontSize: fontSize - 1),
      bodyLarge:     TextStyle(fontSize: fontSize + 2),
      bodyMedium:    TextStyle(fontSize: fontSize),       // default body
      bodySmall:     TextStyle(fontSize: fontSize - 2),
      labelLarge:    TextStyle(fontSize: fontSize),
      labelMedium:   TextStyle(fontSize: fontSize - 2),
      labelSmall:    TextStyle(fontSize: fontSize - 3),
    );

    const appBarOverlay = AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: primaryColor,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    if (isDark) {
return ThemeData(
  brightness: Brightness.dark,
  primaryColor: primaryColor,
  colorScheme: ColorScheme.dark(
    primary: primaryColor,
    secondary: const Color(0xFF00C897),
  ),
  scaffoldBackgroundColor: const Color(0xFF121212),
  cardColor: const Color(0xFF1E1E1E),

  inputDecorationTheme: InputDecorationTheme(
    labelStyle: TextStyle(color: Colors.grey[400]),
    hintStyle: TextStyle(color: Colors.grey[400]),
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Colors.grey[600]!),
      borderRadius: BorderRadius.circular(8),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: Color(0xFF90CAF9), width: 2),
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  ),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: Color(0xFF90CAF9),
    selectionColor: Color(0x4490CAF9),
    selectionHandleColor: Color(0xFF90CAF9),
  ),

  appBarTheme: appBarOverlay.copyWith(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,  // ← fixed: was Colors.black (wrong for dark)
  ),
  textTheme: textTheme,
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? primaryColor : Colors.grey,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      textStyle: TextStyle(fontSize: fontSize),
    ),
  ),
);
    }

    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: const Color(0xFF00C897),
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      cardColor: Colors.white,
      appBarTheme: appBarOverlay.copyWith(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      textTheme: textTheme,
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primaryColor : Colors.grey,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: TextStyle(fontSize: fontSize),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkModeNotifier,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<double>(
          valueListenable: fontSizeNotifier,
          builder: (context, fontSize, _) {
            return MaterialApp(
              title: 'Smart Mate',
              debugShowCheckedModeBanner: false,
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              theme: _buildTheme(false, fontSize),
              darkTheme: _buildTheme(true, fontSize),
              home: const AppStartRouter(),
              routes: {
                 '/session-gate': (context) => const SessionGate(),
                '/login': (context) => const LoginPage(),
                '/dashboard': (context) =>
                    ActivityTracker(child: const DashboardPage()),
                '/nurse': (context) => const NursePage(),
                '/biometric-setup': (context) => BiometricSetupPage(
                      onContinue: () {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                            '/dashboard', (r) => false);
                      },
                      isFromSettings: false,
                    ),
                '/biometric-lock': (context) => BiometricLockScreen(
                      onContinue: () {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                            '/dashboard', (r) => false);
                      },
                    ),
              },
            );
          },
        );
      },
    );
  }
}

class AppStartRouter extends StatefulWidget {
  const AppStartRouter({super.key});

  @override
  State<AppStartRouter> createState() => _AppStartRouterState();
}

class _AppStartRouterState extends State<AppStartRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    final route = await determineStartRoute();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
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