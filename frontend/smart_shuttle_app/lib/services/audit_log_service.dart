import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuditLogService {
  AuditLogService._();

  static Future<bool> logEvent({
    required String actionType,
    required String actionDetails,
    required String moduleName,
    required String userId,
    required String userRole,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'action_type': actionType,
        'action_details': actionDetails,
        'action_timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
        'device_info': _deviceInfo(),
        'module_name': moduleName,
        'user_id': userId,
        'user_role': userRole,
      });
      return true;
    } catch (e) {
      debugPrint('AuditLogService.logEvent error: $e');
      return false;
    }
  }

  static Future<bool> logLoginEvent({
    required String email,
    required String role,
    required bool success,
  }) async {
    return logEvent(
      actionType: success ? 'login_success' : 'login_failed',
      actionDetails: success
          ? 'User login successful'
          : 'User login failed validation',
      moduleName: 'auth',
      userId: email,
      userRole: role,
    );
  }

  static String _deviceInfo() {
    if (kIsWeb) {
      return 'Web Browser';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android App';
      case TargetPlatform.iOS:
        return 'iOS App';
      case TargetPlatform.windows:
        return 'Windows Desktop';
      case TargetPlatform.macOS:
        return 'macOS Desktop';
      case TargetPlatform.linux:
        return 'Linux Desktop';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }
}
