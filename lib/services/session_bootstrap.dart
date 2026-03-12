import 'package:flutter/foundation.dart';
import 'package:staff_mate/services/clinic_service.dart';
import 'package:staff_mate/services/user_information_service.dart';
import 'package:staff_mate/services/session_manger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionBootstrap {
  /// Call this after biometric success OR after full login.
  /// It only re-fetches APIs if data is missing or stale.
  static Future<void> run() async {
    final session = await SessionManager.getSession();

    final token = session['auth_token'] ?? '';
    final clinicId = session['clinicId'] ?? '';
    final userId = session['userId'] ?? '';
    final zoneid = session['zoneid'] ?? 'Asia/Kolkata';

    if (token.isEmpty || clinicId.isEmpty || userId.isEmpty) {
      debugPrint('⚠️ Bootstrap skipped — session incomplete');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastBootstrap = prefs.getInt('last_bootstrap_time') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final hoursSinceLast = (now - lastBootstrap) / (1000 * 60 * 60);

    // Only re-fetch if more than 6 hours have passed
    if (hoursSinceLast < 6 && lastBootstrap != 0) {
      debugPrint('✅ Bootstrap skipped — data is fresh ($hoursSinceLast hrs ago)');
      return;
    }

    debugPrint('🔄 Running session bootstrap...');

    try {
      final clinicService = ClinicService();
      await clinicService.fetchAndSaveClinicDetails(
        token: token,
        clinicId: clinicId,
        userId: userId,
        zoneid: zoneid,
        branchId: 1,
      );
    } catch (e) {
      debugPrint('⚠️ Clinic bootstrap failed: $e');
    }

    try {
      final userInfoService = UserInformationService();
      await userInfoService.fetchAndSaveUserInformation(
        token: token,
        clinicId: clinicId,
        userId: userId,
        zoneid: zoneid,
        branchId: 1,
      );
    } catch (e) {
      debugPrint('⚠️ User info bootstrap failed: $e');
    }

    // Save timestamp so we don't re-fetch too soon
    await prefs.setInt('last_bootstrap_time', now);
    debugPrint('✅ Bootstrap complete');
  }
}