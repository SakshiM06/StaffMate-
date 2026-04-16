import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';

class BiometricAuthService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

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

  // ─── Availability Checks ─────────────────────────────────────────────────

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

  static Future<bool> isFaceIdAvailable() async {
    try {
      final biometrics = await _auth.getAvailableBiometrics();
      if (biometrics.contains(BiometricType.face)) {
        debugPrint("✅ Face biometric detected via standard API");
        return true;
      }
      
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        if (androidInfo.version.sdkInt >= 29) {
          final manufacturer = androidInfo.manufacturer.toLowerCase();
          final hasFaceUnlock = 
              manufacturer.contains('samsung') ||
              manufacturer.contains('oneplus') ||
              manufacturer.contains('xiaomi') ||
              manufacturer.contains('oppo') ||
              manufacturer.contains('vivo') ||
              manufacturer.contains('huawei');
              
          if (hasFaceUnlock) {
            debugPrint("✅ Device likely has face unlock: $manufacturer");
            return true;
          }
        }
      }
      
      debugPrint("❌ Face biometric not detected");
      return false;
    } on PlatformException catch (e) {
      debugPrint("Face detection error: $e");
      return false;
    }
  }

  static Future<bool> isFingerprintAvailable() async {
    try {
      final biometrics = await _auth.getAvailableBiometrics();
      final hasFingerprint = biometrics.contains(BiometricType.fingerprint);
      debugPrint("🔍 Fingerprint available: $hasFingerprint");
      return hasFingerprint;
    } on PlatformException catch (e) {
      debugPrint("Fingerprint detection error: $e");
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

  // ─── Labels & Icons (Required by BiometricLockScreen) ────────────────────

  static Future<String?> getLastUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_username');
  }

  static Future<String> getBiometricLabel() async {
    try {
      final biometrics = await _auth.getAvailableBiometrics();
      
      if (Platform.isIOS) {
        if (biometrics.contains(BiometricType.face)) return 'Face ID';
        if (biometrics.contains(BiometricType.fingerprint)) return 'Touch ID';
      }
      
      final hasFace = biometrics.contains(BiometricType.face);
      final hasFingerprint = biometrics.contains(BiometricType.fingerprint);
      
      if (hasFace && hasFingerprint) {
        return 'Face or Fingerprint';
      } else if (hasFace) {
        return 'Face Unlock';
      } else if (hasFingerprint) {
        return 'Fingerprint';
      }
      
      return 'Biometric';
    } catch (e) {
      return 'Biometric';
    }
  }

  static Future<IconData> getBiometricIcon() async {
    try {
      final biometrics = await _auth.getAvailableBiometrics();
      
      if (Platform.isIOS) {
        if (biometrics.contains(BiometricType.face)) return Icons.face_retouching_natural;
        if (biometrics.contains(BiometricType.fingerprint)) return Icons.fingerprint;
      }
      
      final hasFace = biometrics.contains(BiometricType.face);
      final hasFingerprint = biometrics.contains(BiometricType.fingerprint);
      
      if (hasFace && hasFingerprint) return Icons.fingerprint;
      if (hasFace) return Icons.face_retouching_natural;
      if (hasFingerprint) return Icons.fingerprint;
      
      return Icons.fingerprint;
    } catch (e) {
      return Icons.fingerprint;
    }
  }

  // ─── Enable Biometric ────────────────────────────────────────────────────

  static Future<BiometricResult> enableBiometric() async {
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
      
      final hasFace = await isFaceIdAvailable();
      final hasFingerprint = await isFingerprintAvailable();
      
      final biometricInfo = {
        'hasFace': hasFace,
        'hasFingerprint': hasFingerprint,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      await _secureStorage.write(
        key: _enrollmentCheckKey,
        value: jsonEncode(biometricInfo),
      );
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', true);
      
      debugPrint("✅ Biometric enabled. Face: $hasFace, Fingerprint: $hasFingerprint");
      return BiometricResult.success;
    } catch (e) {
      debugPrint("❌ Error storing biometric key: $e");
      return BiometricResult.failed;
    }
  }

  // ─── Authentication ──────────────────────────────────────────────────────

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

  static Future<BiometricResult> _promptBiometricResult({
    required String reason,
  }) async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
      return authenticated ? BiometricResult.success : BiometricResult.cancelled;
    } on PlatformException catch (e) {
      debugPrint("Biometric prompt error: ${e.code} - ${e.message}");
      switch (e.code) {
        case 'LockedOut':
        case 'PermanentlyLockedOut':
          return BiometricResult.lockedOut;
        case 'NotAvailable':
        case 'NotEnrolled':
        case 'OtherOperatingSystem':
          return BiometricResult.notAvailable;
        case 'auth_in_progress':
          return BiometricResult.cancelled;
        default:
          return BiometricResult.failed;
      }
    }
  }

  // ─── Disable Biometric ───────────────────────────────────────────────────

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

  static Future<bool> _promptBiometric({required String reason}) async {
    final result = await _promptBiometricResult(reason: reason);
    return result == BiometricResult.success;
  }

  // ─── State Management ────────────────────────────────────────────────────

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

  // ─── Private Helpers ─────────────────────────────────────────────────────

  static Future<bool> _hasEnrollmentChanged() async {
    try {
      final storedInfoStr = await _secureStorage.read(key: _enrollmentCheckKey);
      if (storedInfoStr == null) return false;
      
      final storedInfo = jsonDecode(storedInfoStr) as Map<String, dynamic>;
      final storedHasFace = storedInfo['hasFace'] ?? false;
      final storedHasFingerprint = storedInfo['hasFingerprint'] ?? false;
      
      final currentHasFace = await isFaceIdAvailable();
      final currentHasFingerprint = await isFingerprintAvailable();
      
      if ((currentHasFace && !storedHasFace) || 
          (currentHasFingerprint && !storedHasFingerprint)) {
        debugPrint("⚠️ New biometric enrolled");
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Enrollment check error: $e");
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

// ─── Result Enum ───────────────────────────────────────────────────────────

enum BiometricResult {
  success,
  failed,
  cancelled,
  enrollmentChanged,
  keyInvalidated,
  lockedOut,
  notAvailable,
}