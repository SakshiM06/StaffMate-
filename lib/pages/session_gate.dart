// lib/pages/session_gate.dart

import 'package:flutter/material.dart';
import 'package:staff_mate/services/biometric_auth_service.dart';
import 'package:staff_mate/services/session_manger.dart';
import 'package:staff_mate/api/api_service.dart';

/// Sits at app startup. Decides whether to resume the session silently,
/// show the biometric lock screen, or go to login.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  @override
  void initState() {
    super.initState();
    _resolveSession();
  }

  Future<void> _resolveSession() async {
    // 1. Check if a valid session exists
    final hasSession = await SessionManager.hasValidSession();

    if (!hasSession) {
      // No session at all → go to login normally
      _goToLogin();
      return;
    }

    // 2. Session exists — try to refresh the token silently
    try {
      await ApiService.refreshUserToken();
    } catch (_) {
      // Refresh failed but session might still be locally valid — continue
    }

    // 3. Check if biometric is enabled for this device
    final biometricEnabled = await BiometricAuthService.isBiometricEnabled();

    if (biometricEnabled) {
      // Biometric device → show the biometric lock screen (existing behaviour)
      _goToBiometricLock();
    } else {
      // ✅ Non-biometric device with valid session → skip login entirely
      SessionManager.updateUserActivity();
      SessionManager.startSessionMonitoring();
      _goToDashboard();
    }
  }

  void _goToDashboard() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/dashboard');
  }

  void _goToBiometricLock() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/biometric-lock');
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    // Show your existing splash/loading screen while resolving
    return const Scaffold(
      backgroundColor: Color(0xFF0A0F2C),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF00BCD4),
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}