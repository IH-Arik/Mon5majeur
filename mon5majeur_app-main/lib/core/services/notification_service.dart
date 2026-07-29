import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/services/api_service.dart';
import '../../data/services/api_url.dart';

/// Triggers the OS notification-permission prompt, and if granted,
/// registers this device's FCM token with the backend right away.
Future<bool> requestNotificationPermission() async {
  final status = await Permission.notification.request();
  if (status.isGranted) {
    await registerFcmToken();
  }
  return status.isGranted;
}

/// Fetches the current FCM device token and sends it to the backend
/// (`POST /api/v1/users/me/fcm-token`) so push notifications can reach
/// this device. Safe to call repeatedly — the backend just overwrites
/// the stored token.
Future<void> registerFcmToken() async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;

    final apiClient = ApiClient();
    final url =
        '${ApiUrl.baseUrl}${ApiUrl.registerFcmToken}?token=${Uri.encodeQueryComponent(token)}';
    await apiClient.post(url: url, showResult: true);
  } catch (_) {
    // Best-effort — a failed registration just means this device won't
    // receive pushes until the next successful sync; never block the UI.
  }
}

/// Called once at app startup: if the user already granted notification
/// permission in a previous session, keep the backend's stored token fresh
/// (FCM tokens can rotate). Does NOT prompt — the actual permission request
/// only happens from the post-team-validation opt-in (team_confirm_controls).
Future<void> syncFcmTokenIfPermissionGranted() async {
  final status = await Permission.notification.status;
  if (status.isGranted) {
    await registerFcmToken();
  }
}
