import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class SessionManager {
  // In-memory cache for quick access
  static final Map<String, dynamic> _dynamicData = {};

  /// Save a complete session
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
    await prefs.setInt('subscription_remaining_days', subscriptionRemainingDays); // Fixed key name
    await prefs.setString('userId', userId);
    await prefs.setString('zoneid', zoneid);
    await prefs.setString('expiryTime', expiryTime);
    await prefs.setInt('branchId', branchId);

    // also store in-memory for quick access
    _dynamicData.addAll({
      'bearer': bearer,
      'auth_token': token,
      'clinicId': clinicId,
      'subscription_remaining_days': subscriptionRemainingDays, // Fixed key
      'userId': userId,
      'zoneid': zoneid,
      'expiryTime': expiryTime,
      'branchId': branchId,
    });
  }

  /// Save directly from API JSON
  static Future<void> saveFromApi(Map<String, dynamic> data) async {
    if (data.isEmpty) {
      debugPrint('No data provided to save session.');
      return;
    }
    
    await saveSession(
      bearer: (data['bearer'] ?? '').toString(),
      token: (data['token'] ?? '').toString(),
      clinicId: (data['clinicid'] ?? data['clinicId'] ?? '').toString(),
      subscriptionRemainingDays: int.tryParse(
              (data['subscription_remaining_days'] ?? 0).toString()) ??
          0,
      userId: (data['userId'] ?? data['UserId'] ?? '').toString(),
      zoneid: (data['zoneid'] ?? data['ZONEID'] ?? '').toString(),
      expiryTime: (data['expirytime'] ?? data['expiryTime'] ?? '').toString(),
      branchId: int.tryParse((data['branch_id'] ?? 0).toString()) ?? 0,
    );
  }

  /// Retrieve session data - SAFE VERSION
  static Future<Map<String, dynamic>> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    if (token.isEmpty) {
      debugPrint('No auth_token found in session.');
      return {};
    }

    // Safe way to get integer - handle both int and string cases
    int getSafeInt(String key) {
      final dynamic value = prefs.get(key);
      if (value is int) {
        return value;
      } else if (value is String) {
        return int.tryParse(value) ?? 0;
      }
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

  /// Check if user has a valid session (not expired)
  static Future<bool> hasValidSession() async {
    final session = await getSession();
    
    if (session['auth_token'] == null || 
        session['auth_token'].toString().isEmpty) {
      return false;
    }
    
    // Check expiry time if available
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
        // Don't logout if we can't parse expiry time
      }
    }
    
    // Check subscription days
    final subscriptionDays = session['subscriptionRemainingDays'] ?? 0;
    if (subscriptionDays <= 0) {
      await clearSession();
      return false;
    }
    
    return true;
  }

  /// Get authentication token
  static Future<String?> getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  /// Get bearer token
  static Future<String?> getBearerToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('bearer');
  }

  /// Debug: print all session values
  static Future<void> debugPrintSession() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    debugPrint('------ SESSION DEBUG START ------');
    for (var key in allKeys) {
      final value = prefs.get(key);
      debugPrint('$key: $value (Type: ${value.runtimeType})');
    }
    debugPrint('------ SESSION DEBUG END ------');
  }

  /// Clear all session data (except biometric settings)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save biometric settings before clearing
    final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
    final lastUsername = prefs.getString('last_username') ?? '';
    
    // Clear all preferences
    await prefs.clear();
    
    // Restore biometric settings
    if (biometricEnabled) {
      await prefs.setBool('biometric_enabled', true);
    }
    if (lastUsername.isNotEmpty) {
      await prefs.setString('last_username', lastUsername);
    }
    
    _dynamicData.clear();
    debugPrint('Session cleared.');
  }

  /// Clear only auth data (keep username for biometric)
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
    debugPrint('Auth data cleared.');
  }

  /// Check if user has ever logged in before (for biometric)
  static Future<bool> hasPreviousLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUsername = prefs.getString('last_username');
    return lastUsername != null && lastUsername.isNotEmpty;
  }

  /// Get last username
  static Future<String?> getLastUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_username');
  }

  static dynamic getDynamicData(String key) => _dynamicData[key];

  /// Format a DateTime to a date string
  static String formatDate(DateTime dateTime) {
    return DateFormat('dd MMM yyyy').format(dateTime);
  }

  /// Format a DateTime to a time string
  static String formatTime(DateTime dateTime) {
    return DateFormat('hh:mm a').format(dateTime);
  }
}