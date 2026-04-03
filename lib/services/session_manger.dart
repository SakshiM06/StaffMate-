import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // Add this for Timer

class SessionManager {
  static final Map<String, dynamic> _dynamicData = {};
  
  // Timer for session monitoring
  static Timer? _sessionMonitorTimer;
  static DateTime? _lastActivityTime;
  static Function(bool showDialog)? _onSessionExpiring;
  static bool _isDialogShowing = false;
  static const int sessionTimeoutMinutes = 15;
  static const int warningSeconds = 10;

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

  // ─── Token storage methods (new) ───────────────────────────────────────────
  
  static Future<void> saveTokens({
    required String? accessToken,
    required String? refreshToken,
    required DateTime? expiryTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (accessToken != null) {
      await prefs.setString('access_token', accessToken);
    }
    if (refreshToken != null) {
      await prefs.setString('refresh_token', refreshToken);
    }
    if (expiryTime != null) {
      await prefs.setString('token_expiry', expiryTime.toIso8601String());
    }
    
    // Update dynamic data
    _dynamicData['access_token'] = accessToken;
    _dynamicData['refresh_token'] = refreshToken;
    _dynamicData['token_expiry'] = expiryTime;
    
    debugPrint('Tokens saved - Expires at: $expiryTime');
  }
  
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }
  
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }
  
  static Future<DateTime?> getTokenExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString('token_expiry');
    if (expiryStr != null && expiryStr.isNotEmpty) {
      try {
        return DateTime.parse(expiryStr);
      } catch (e) {
        debugPrint('Error parsing token expiry: $e');
        return null;
      }
    }
    return null;
  }
  
  static Future<bool> isTokenValid() async {
    final expiry = await getTokenExpiry();
    if (expiry == null) return false;
    return DateTime.now().isBefore(expiry);
  }
  
  static Future<bool> isTokenExpiringSoon() async {
    final expiry = await getTokenExpiry();
    if (expiry == null) return false;
    final timeUntilExpiry = expiry.difference(DateTime.now());
    return timeUntilExpiry.inMinutes < 2; // Less than 2 minutes remaining
  }

  // ─── Existing session save (updated) ───────────────────────────────────────

  static Future<void> saveSession({
    required String bearer,
    required String token,
    required String clinicId,
    required int subscriptionRemainingDays,
    required String userId,
    required String zoneid,
    required String expiryTime,
    required int branchId,
    String email = '',
    String? refreshToken, // Add refresh token parameter
    DateTime? tokenExpiry, // Add token expiry parameter
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
    await prefs.setString('email', email);
    
    // Save tokens for session management
    if (refreshToken != null) {
      await prefs.setString('refresh_token', refreshToken);
    }
    if (tokenExpiry != null) {
      await prefs.setString('token_expiry', tokenExpiry.toIso8601String());
    }
    await prefs.setString('access_token', token); // Access token is the same as auth_token

    _dynamicData.addAll({
      'bearer': bearer,
      'auth_token': token,
      'clinicId': clinicId,
      'subscription_remaining_days': subscriptionRemainingDays,
      'userId': userId,
      'zoneid': zoneid,
      'expiryTime': expiryTime,
      'branchId': branchId,
      'access_token': token,
      'refresh_token': refreshToken,
      'token_expiry': tokenExpiry,
    });
    
    // Start session monitoring after login
    startSessionMonitoring();
  }

  static Future<void> saveFromApi(Map<String, dynamic> data) async {
    if (data.isEmpty) return;
    
    // Extract refresh token if present
    String? refreshToken = data['refreshToken'];
    DateTime? tokenExpiry;
    
    // Calculate token expiry (default 15 minutes from now)
    if (data['expiresIn'] != null) {
      tokenExpiry = DateTime.now().add(Duration(seconds: data['expiresIn']));
    } else {
      tokenExpiry = DateTime.now().add(const Duration(minutes: sessionTimeoutMinutes));
    }
    
    await saveSession(
      bearer: (data['bearer'] ?? '').toString(),
      token: (data['token'] ?? data['accessToken'] ?? '').toString(),
      clinicId: (data['clinicid'] ?? data['clinicId'] ?? '').toString(),
      subscriptionRemainingDays: int.tryParse(
              (data['subscription_remaining_days'] ?? 0).toString()) ?? 0,
      userId: (data['userId'] ?? data['UserId'] ?? '').toString(),
      zoneid: (data['zoneid'] ?? data['ZONEID'] ?? '').toString(),
      expiryTime: (data['expirytime'] ?? data['expiryTime'] ?? '').toString(),
      branchId: int.tryParse((data['branch_id'] ?? 0).toString()) ?? 0,
      email: (data['email'] ?? data['emailId'] ?? data['userEmail'] ?? '').toString(),
      refreshToken: refreshToken,
      tokenExpiry: tokenExpiry,
    );
  }

  // ─── Session monitoring (new) ───────────────────────────────────────────────
  
  static void startSessionMonitoring() {
    _resetInactivityTimer();
  }
  
  static void _resetInactivityTimer() {
    _lastActivityTime = DateTime.now();
    _sessionMonitorTimer?.cancel();
    
    // Start new timer to check for inactivity
    _sessionMonitorTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lastActivityTime != null) {
        final timeSinceLastActivity = DateTime.now().difference(_lastActivityTime!);
        final timeUntilExpiry = sessionTimeoutMinutes * 60 - timeSinceLastActivity.inSeconds;
        
        // Show warning 10 seconds before session expires
        if (timeUntilExpiry <= warningSeconds && timeUntilExpiry > 0 && !_isDialogShowing) {
          _isDialogShowing = true;
          if (_onSessionExpiring != null) {
            _onSessionExpiring!(true);
          }
        }
      }
    });
  }
  
  static void updateUserActivity() {
    _lastActivityTime = DateTime.now();
    _isDialogShowing = false;
    if (_onSessionExpiring != null) {
      _onSessionExpiring!(false);
    }
  }
  
  static void setSessionExpiryCallback(Function(bool showDialog) callback) {
    _onSessionExpiring = callback;
  }
  
  static void stopSessionMonitoring() {
    _sessionMonitorTimer?.cancel();
    _sessionMonitorTimer = null;
    _lastActivityTime = null;
    _isDialogShowing = false;
  }

  // ─── Session validation (updated) ───────────────────────────────────────────

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
      'access_token': prefs.getString('access_token') ?? token,
      'refresh_token': prefs.getString('refresh_token'),
      'token_expiry': await getTokenExpiry(),
    };
  }

  static Future<bool> hasValidSession() async {
    final session = await getSession();
    if (session['auth_token'] == null ||
        session['auth_token'].toString().isEmpty) {
      return false;
    }

    // Check token expiry
    final tokenExpiry = await getTokenExpiry();
    if (tokenExpiry != null && DateTime.now().isAfter(tokenExpiry)) {
      debugPrint('Token has expired');
      await clearSession();
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

  // ─── Clear methods (updated) ────────────────────────────────────────────────

  /// Soft logout: clears API session but keeps biometric credentials.
  /// Next app open → biometric screen shows (user just needs to verify face/finger)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();

    // Preserve these across soft logout
    final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    final lastUsername = prefs.getString('last_username') ?? '';
    final savedEmail = prefs.getString('email') ?? '';

    await prefs.clear();

    if (biometricEnabled) await prefs.setBool('biometric_enabled', true);
    if (lastUsername.isNotEmpty) await prefs.setString('last_username', lastUsername);
    if (savedEmail.isNotEmpty) await prefs.setString('email', savedEmail);

    // Keep biometric session active so lock screen shows on next open
    await setBiometricSessionActive(true);
    
    // Stop session monitoring
    stopSessionMonitoring();

    _dynamicData.clear();
    debugPrint('Session cleared (soft logout).');
  }

  /// Hard logout: clears everything including biometric.
  /// Next app open → full login page, no biometric prompt.
  static Future<void> fullLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _secureStorage.deleteAll();
    
    // Stop session monitoring
    stopSessionMonitoring();
    
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
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('token_expiry');
    
    // Stop session monitoring
    stopSessionMonitoring();
    
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
    debugPrint('Access Token: ${await getAccessToken()}');
    debugPrint('Refresh Token: ${await getRefreshToken()}');
    debugPrint('Token Expiry: ${await getTokenExpiry()}');
    debugPrint('------ SESSION DEBUG END ------');
  }
}
// Add this method to SessionManager to verify token storage
Future<void> debugTokenStorage() async {
  final prefs = await SharedPreferences.getInstance();
  debugPrint("======= TOKEN STORAGE DEBUG =======");
  debugPrint("Access Token: ${prefs.getString('access_token')?.substring(0, min(20, prefs.getString('access_token')?.length ?? 0)) ?? 'null'}...");
  debugPrint("Refresh Token: ${prefs.getString('refresh_token') ?? 'null'}");
  debugPrint("Token Expiry: ${prefs.getString('token_expiry') ?? 'null'}");
  debugPrint("Auth Token: ${prefs.getString('auth_token')?.substring(0, min(20, prefs.getString('auth_token')?.length ?? 0)) ?? 'null'}...");
  debugPrint("==================================");
}