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
    required int branchId, // ✅ now int
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('bearer', bearer);
    await prefs.setString('auth_token', token);
    await prefs.setString('clinicId', clinicId);
    await prefs.setInt('subscriptionRemainingDays', subscriptionRemainingDays);
    await prefs.setString('userId', userId);
    await prefs.setString('zoneid', zoneid);
    await prefs.setString('expiryTime', expiryTime);
    await prefs.setInt('branchId', branchId); // ✅ int now

    // also store in-memory for quick access
    _dynamicData.addAll({
      'bearer': bearer,
      'auth_token': token,
      'clinicId': clinicId,
      'subscriptionRemainingDays': subscriptionRemainingDays,
      'userId': userId,
      'zoneid': zoneid,
      'expiryTime': expiryTime,
      'branchId': branchId,
    });
  }

  /// Save directly from API JSON
  static Future<void> saveFromApi(Map<String, dynamic> data) async {
      debugPrint('No data provided to save session. $data');
   
    await saveSession(
      bearer: (data['bearer'] ?? '').toString(),
      token: (data['token'] ?? '').toString(),
      clinicId: (data['clinicid'] ?? data['clinicId'] ?? '').toString(),
      subscriptionRemainingDays: int.tryParse(
              (data['subscription_remaining_days'] ??
                      data['subscriptionRemainingDays'] ??
                      0)
                  .toString()) ??
          0,
      userId: (data['userId'] ?? data['UserId'] ?? '').toString(),
      zoneid: (data['zoneid'] ?? data['ZONEID'] ?? '').toString(),
      expiryTime: (data['expirytime'] ?? data['expiryTime'] ?? '').toString(),
      branchId: int.tryParse(
              (data['branch_id'] ?? data['branchId'] ?? 0).toString()) ??
          0, // ✅ int parse safe
    );
  }

  /// Retrieve session data
  static Future<Map<String, dynamic>> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    if (token.isEmpty) {
      debugPrint('No auth_token found in session.');
      return {};
    }

    return {
      'bearer': prefs.getString('bearer') ?? '',
      'auth_token': token,
      'clinicId': prefs.getString('clinicId') ?? '',
      'subscriptionRemainingDays':
          prefs.getInt('subscriptionRemainingDays') ?? 0,
      'userId': prefs.getString('userId') ?? '',
      'zoneid': prefs.getString('zoneid') ?? '',
      'expiryTime': prefs.getString('expiryTime') ?? '',
      'branchId': prefs.getInt('branchId') ?? 0, // ✅ int
    };
  }

  /// Debug: print all session values
  static Future<void> debugPrintSession() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    debugPrint('------ SESSION DEBUG START ------');
    for (var key in allKeys) {
      debugPrint(
          '$key: ${prefs.get(key)} (Type: ${prefs.get(key)?.runtimeType})');
    }
    debugPrint('------ SESSION DEBUG END ------');
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _dynamicData.clear();
    debugPrint('Session cleared.');
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
