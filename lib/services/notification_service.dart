
import 'package:shared_preferences/shared_preferences.dart';

class NotificationRefreshService {
  static final NotificationRefreshService _instance = NotificationRefreshService._internal();
  factory NotificationRefreshService() => _instance;
  NotificationRefreshService._internal();

  Future<void> markInvestigationSaved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_investigation_save_time', DateTime.now().toIso8601String());
    await prefs.setBool('shouldRefreshNotifications', true);
  }

  // Save timestamp when prescription is saved
  Future<void> markPrescriptionSaved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_prescription_save_time', DateTime.now().toIso8601String());
    await prefs.setBool('shouldRefreshNotifications', true);
  }

  // Check if refresh is needed
  Future<bool> shouldRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check flag
    final shouldRefreshFlag = prefs.getBool('shouldRefreshNotifications') ?? false;
    if (shouldRefreshFlag) {
      await prefs.remove('shouldRefreshNotifications');
      return true;
    }
    
    // Check timestamps
    final lastInvestigationSave = prefs.getString('last_investigation_save_time');
    final lastPrescriptionSave = prefs.getString('last_prescription_save_time');
    
    if (lastInvestigationSave != null) {
      final saveTime = DateTime.parse(lastInvestigationSave);
      final difference = DateTime.now().difference(saveTime).inMinutes;
      if (difference < 10) {
        await prefs.remove('last_investigation_save_time');
        return true;
      }
    }
    
    if (lastPrescriptionSave != null) {
      final saveTime = DateTime.parse(lastPrescriptionSave);
      final difference = DateTime.now().difference(saveTime).inMinutes;
      if (difference < 10) {
        await prefs.remove('last_prescription_save_time');
        return true;
      }
    }
    
    return false;
  }

  // Clear all refresh flags
  Future<void> clearRefreshFlags() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('shouldRefreshNotifications');
    await prefs.remove('last_investigation_save_time');
    await prefs.remove('last_prescription_save_time');
  }
}