import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class SessionManager {
  static final Map<String, dynamic> _dynamicData = {};

  // Secure storage for sensitive data
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ─── Secure credential storage (for biometric re-auth) ───────────────────

  static Future<void> saveCredentialsSecurely({
    required String username,
    required String password,
  }) async {
    await _secureStorage.write(key: 'secure_username', value: username);
    await _secureStorage.write(key: 'secure_password', value: password);
  }

  static Future<String?> getSecureUsername() async {
    return await _secureStorage.read(key: 'secure_username');
  }

  static Future<String?> getSecurePassword() async {
    return await _secureStorage.read(key: 'secure_password');
  }

  // ─── Biometric session flag ───────────────────────────────────────────────
  // This is SEPARATE from the API token session.
  // It just means "user has logged in before on this device"

  static Future<void> setBiometricSessionActive(bool value) async {
    await _secureStorage.write(
      key: 'biometric_session_active',
      value: value.toString(),
    );
  }

  static Future<bool> isBiometricSessionActive() async {
    final value = await _secureStorage.read(key: 'biometric_session_active');
    return value == 'true';
  }

  // ─── Existing session save (unchanged) ───────────────────────────────────

  static Future<void> saveSession({
    required String bearer,
    required String token,
    required String clinicId,
    required int subscriptionRemainingDays,
    required String userId,
    required String zoneid,
    required String expiryTime,
    required int branchId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('bearer', bearer);
    await prefs.setString('auth_token', token);
    await prefs.setString('clinicId', clinicId);
    await prefs.setInt('subscription_remaining_days', subscriptionRemainingDays);
    await prefs.setString('userId', userId);
    await prefs.setString('zoneid', zoneid);
    await prefs.setString('expiryTime', expiryTime);
    await prefs.setInt('branchId', branchId);

    _dynamicData.addAll({
      'bearer': bearer,
      'auth_token': token,
      'clinicId': clinicId,
      'subscription_remaining_days': subscriptionRemainingDays,
      'userId': userId,
      'zoneid': zoneid,
      'expiryTime': expiryTime,
      'branchId': branchId,
    });
  }

  static Future<void> saveFromApi(Map<String, dynamic> data) async {
    if (data.isEmpty) return;
    await saveSession(
      bearer: (data['bearer'] ?? '').toString(),
      token: (data['token'] ?? '').toString(),
      clinicId: (data['clinicid'] ?? data['clinicId'] ?? '').toString(),
      subscriptionRemainingDays: int.tryParse(
              (data['subscription_remaining_days'] ?? 0).toString()) ?? 0,
      userId: (data['userId'] ?? data['UserId'] ?? '').toString(),
      zoneid: (data['zoneid'] ?? data['ZONEID'] ?? '').toString(),
      expiryTime: (data['expirytime'] ?? data['expiryTime'] ?? '').toString(),
      branchId: int.tryParse((data['branch_id'] ?? 0).toString()) ?? 0,
    );
  }

  // ─── Session validation ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    if (token.isEmpty) return {};

    int getSafeInt(String key) {
      final dynamic value = prefs.get(key);
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return {
      'bearer': prefs.getString('bearer') ?? '',
      'auth_token': token,
      'clinicId': prefs.getString('clinicId') ?? '',
      'subscriptionRemainingDays': getSafeInt('subscription_remaining_days'),
      'userId': prefs.getString('userId') ?? '',
      'zoneid': prefs.getString('zoneid') ?? '',
      'expiryTime': prefs.getString('expiryTime') ?? '',
      'branchId': getSafeInt('branchId'),
    };
  }

  static Future<bool> hasValidSession() async {
    final session = await getSession();
    if (session['auth_token'] == null ||
        session['auth_token'].toString().isEmpty) {
      return false;
    }

    final expiryTime = session['expiryTime'] ?? '';
    if (expiryTime.isNotEmpty && expiryTime != 'null') {
      try {
        final expiryDate = DateTime.parse(expiryTime);
        if (DateTime.now().isAfter(expiryDate)) {
          await clearSession();
          return false;
        }
      } catch (e) {
        debugPrint('Error parsing expiry time: $e');
      }
    }

    final subscriptionDays = session['subscriptionRemainingDays'] ?? 0;
    if (subscriptionDays <= 0) {
      await clearSession();
      return false;
    }

    return true;
  }

  // ─── Clear methods ────────────────────────────────────────────────────────

  /// Soft logout: clears API session but keeps biometric credentials.
  /// Next app open → biometric screen shows (user just needs to verify face/finger)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();

    // Preserve these across soft logout
    final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    final lastUsername = prefs.getString('last_username') ?? '';

    await prefs.clear();

    if (biometricEnabled) await prefs.setBool('biometric_enabled', true);
    if (lastUsername.isNotEmpty) {
      await prefs.setString('last_username', lastUsername);
    }

    // Keep biometric session active so lock screen shows on next open
    await setBiometricSessionActive(true);

    _dynamicData.clear();
    debugPrint('Session cleared (soft logout).');
  }

  /// Hard logout: clears everything including biometric.
  /// Next app open → full login page, no biometric prompt.
  static Future<void> fullLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _secureStorage.deleteAll();
    _dynamicData.clear();
    debugPrint('Full logout complete.');
  }

  /// Clear only auth data (keep username for biometric re-login)
  static Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bearer');
    await prefs.remove('auth_token');
    await prefs.remove('clinicId');
    await prefs.remove('subscription_remaining_days');
    await prefs.remove('userId');
    await prefs.remove('zoneid');
    await prefs.remove('expiryTime');
    await prefs.remove('branchId');
    _dynamicData.clear();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Now checks secure storage instead of SharedPreferences
  static Future<bool> hasPreviousLogin() async {
    final username = await _secureStorage.read(key: 'secure_username');
    return username != null && username.isNotEmpty;
  }

  static Future<String?> getLastUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_username');
  }

  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<String?> getBearerToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('bearer');
  }

  static dynamic getDynamicData(String key) => _dynamicData[key];

  static String formatDate(DateTime dateTime) =>
      DateFormat('dd MMM yyyy').format(dateTime);

  static String formatTime(DateTime dateTime) =>
      DateFormat('hh:mm a').format(dateTime);

  static Future<void> set2FAVerified({required bool verified}) async {}

  static Future<void> debugPrintSession() async {
    final prefs = await SharedPreferences.getInstance();
    debugPrint('------ SESSION DEBUG START ------');
    for (var key in prefs.getKeys()) {
      debugPrint('$key: ${prefs.get(key)}');
    }
    debugPrint('------ SESSION DEBUG END ------');
  }
}