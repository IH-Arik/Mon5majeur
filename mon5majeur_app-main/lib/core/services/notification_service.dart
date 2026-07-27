import 'package:permission_handler/permission_handler.dart';

/// Triggers the OS notification-permission prompt.
///
/// This only secures the OS-level permission; actual push delivery
/// (device-token registration, FCM) is not wired up yet.
Future<bool> requestNotificationPermission() async {
  final status = await Permission.notification.request();
  return status.isGranted;
}
