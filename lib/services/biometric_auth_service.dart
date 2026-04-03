import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: false,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _biometricKeyKey = 'biometric_validation_key';
  static const String _enrollmentCheckKey = 'biometric_enrollment_count';

  // ─── Availability ─────────────────────────────────────────────────────────

  static Future<bool> isBiometricAvailable() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isSupported && canCheck;
    } on PlatformException catch (e) {
      debugPrint("Biometric availability error: $e");
      return false;
    }
  }

  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint("Get biometrics error: $e");
      return [];
    }
  }

  static Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException catch (e) {
      debugPrint("Device support error: $e");
      return false;
    }
  }

  // ─── Enable ───────────────────────────────────────────────────────────────

  /// NOW returns BiometricResult (not bool)
 static Future<BiometricResult> enableBiometric() async {
  // Guard: make sure hardware is actually ready before prompting
  final available = await isBiometricAvailable();
  if (!available) {
    debugPrint("❌ Biometric hardware not available");
    return BiometricResult.notAvailable;
  }

  final result = await _promptBiometricResult(
    reason: 'Verify your identity to enable biometric login',
  );
  if (result != BiometricResult.success) return result;

  try {
    final token = _generateToken();
    await _secureStorage.write(key: _biometricKeyKey, value: token);
    final biometrics = await _auth.getAvailableBiometrics();
    await _secureStorage.write(
      key: _enrollmentCheckKey,
      value: biometrics.length.toString(),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', true);
    debugPrint("✅ Biometric enabled. Enrolled count: ${biometrics.length}");
    return BiometricResult.success;
  } catch (e) {
    debugPrint("❌ Error storing biometric key: $e");
    return BiometricResult.failed;
  }
}

  // ─── Core prompt (returns BiometricResult) ────────────────────────────────

 static Future<BiometricResult> _promptBiometricResult({
  required String reason,
}) async {
  try {
    final authenticated = await _auth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: false, // ← KEY FIX: allows PIN fallback that Android requires
        useErrorDialogs: true,
      ),
    );
    return authenticated ? BiometricResult.success : BiometricResult.cancelled;
  } on PlatformException catch (e) {
    debugPrint("Biometric prompt error: ${e.code} - ${e.message}");
    switch (e.code) {
      case 'LockedOut':
      case 'PermanentlyLockedOut':
        return BiometricResult.lockedOut; // new enum value — see below
      case 'NotAvailable':
      case 'NotEnrolled':
      case 'OtherOperatingSystem':
        return BiometricResult.notAvailable; // new enum value
      case 'auth_in_progress':
        return BiometricResult.cancelled;
      default:
        debugPrint("Unhandled biometric error code: ${e.code}");
        return BiometricResult.failed;
    }
  }
}
  /// Bool wrapper — used internally by disableBiometric & authenticateSecure
  static Future<bool> _promptBiometric({required String reason}) async {
    final result = await _promptBiometricResult(reason: reason);
    return result == BiometricResult.success;
  }

  // ─── Authenticate (secure) ────────────────────────────────────────────────

  static Future<BiometricResult> authenticateSecure({
    String reason = 'Authenticate to access SmartMate',
  }) async {
    try {
      if (await _hasEnrollmentChanged()) {
        debugPrint("🚨 New biometric enrolled — forcing re-login");
        await _invalidateBiometricKey();
        await setBiometricEnabled(false);
        return BiometricResult.enrollmentChanged;
      }

      final storedKey = await _secureStorage.read(key: _biometricKeyKey);
      if (storedKey == null || storedKey.isEmpty) {
        debugPrint("🚨 Biometric key missing — forcing re-login");
        await setBiometricEnabled(false);
        return BiometricResult.keyInvalidated;
      }

      // Use _promptBiometricResult so cancelled is handled correctly
      return await _promptBiometricResult(reason: reason);

    } on PlatformException catch (e) {
      debugPrint("Platform error during biometric auth: $e");
      return BiometricResult.failed;
    } catch (e) {
      debugPrint("Biometric error: $e");
      return BiometricResult.failed;
    }
  }

  static Future<bool> authenticate({
    String reason = 'Authenticate to access SmartMate',
  }) async {
    final result = await authenticateSecure(reason: reason);
    return result == BiometricResult.success;
  }

  // ─── Disable ──────────────────────────────────────────────────────────────

  static Future<bool> disableBiometric() async {
    final ok = await _promptBiometric(
      reason: 'Verify your identity to disable biometric login',
    );
    if (!ok) return false;

    await _invalidateBiometricKey();
    await setBiometricEnabled(false);
    debugPrint("✅ Biometric disabled");
    return true;
  }

  // ─── State ────────────────────────────────────────────────────────────────

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('biometric_enabled') ?? false)) return false;
    try {
      final key = await _secureStorage.read(key: _biometricKeyKey);
      return key != null && key.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enabled);
    if (!enabled) await _invalidateBiometricKey();
  }

  // ─── Labels & Icons ───────────────────────────────────────────────────────

  static Future<String?> getLastUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_username');
  }

  static Future<String> getBiometricLabel() async {
    try {
      final list = await _auth.getAvailableBiometrics();
      if (list.contains(BiometricType.face)) return 'Face ID';
      if (list.contains(BiometricType.fingerprint)) return 'Fingerprint';
      if (list.contains(BiometricType.strong) ||
          list.contains(BiometricType.weak)) return 'Fingerprint';
      return 'Biometric';
    } on PlatformException {
      return 'Biometric';
    }
  }

  static Future<IconData> getBiometricIcon() async {
    try {
      final list = await _auth.getAvailableBiometrics();
      if (list.contains(BiometricType.face)) return Icons.face_retouching_natural;
      if (list.contains(BiometricType.fingerprint)) return Icons.fingerprint;
      if (list.contains(BiometricType.strong) ||
          list.contains(BiometricType.weak)) return Icons.fingerprint;
      return Icons.fingerprint; // Safe default
    } on PlatformException {
      return Icons.fingerprint;
    }
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  static Future<bool> _hasEnrollmentChanged() async {
    try {
      final storedStr = await _secureStorage.read(key: _enrollmentCheckKey);
      if (storedStr == null) return false;
      final storedCount = int.tryParse(storedStr) ?? 0;
      final current = await _auth.getAvailableBiometrics();
      if (current.length > storedCount) {
        debugPrint("⚠️ Enrollment: was $storedCount, now ${current.length}");
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _invalidateBiometricKey() async {
    try {
      await _secureStorage.delete(key: _biometricKeyKey);
      await _secureStorage.delete(key: _enrollmentCheckKey);
    } catch (e) {
      debugPrint("Error deleting biometric key: $e");
    }
  }

  static String _generateToken() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final entropy = List<int>.generate(32, (i) => (ts ^ (i * 31)) % 256);
    return '$ts.${base64Url.encode(entropy)}';
  }
}

// ─── Result enum ─────────────────────────────────────────────────────────────

enum BiometricResult {
  success,
  failed,
  cancelled,       // User dismissed the prompt
  enrollmentChanged,
  keyInvalidated,
  lockedOut,
  notAvailable,
}