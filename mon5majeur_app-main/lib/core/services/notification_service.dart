import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/services/api_service.dart';
import '../../data/services/api_url.dart';
import '../../data/services/session_service.dart';
import '../constants/api_constants.dart';
import '../local_db/local_db.dart';

/// Where the OS notification permission stands for this install.
enum PushPermission { notAsked, denied, granted }

Future<PushPermission> pushPermissionState() async {
  final status = await Permission.notification.status;
  if (status.isGranted || status.isProvisional) return PushPermission.granted;
  if (status.isPermanentlyDenied || status.isRestricted) {
    return PushPermission.denied;
  }
  // iOS reports "never asked" as plain `denied`; Android as well until the
  // first refusal. Our own flag tells the two apart.
  final asked =
      await SharedPrefsHelper.getBool(AppConstants.notificationPermissionAsked) ??
          false;
  return asked ? PushPermission.denied : PushPermission.notAsked;
}

/// True when the player switched notifications off in the app's Settings.
Future<bool> isNotificationsOptOut() async =>
    await SharedPrefsHelper.getBool(AppConstants.notificationsOptOut) ?? false;

/// Counts app launches (called once per process from main).
Future<void> registerAppOpen() async {
  final count = await SharedPrefsHelper.getInt(AppConstants.appOpenCount);
  await SharedPrefsHelper.setInt(
    AppConstants.appOpenCount,
    (count < 0 ? 0 : count) + 1,
  );
}

/// Triggers the OS notification-permission prompt (from the explainer's
/// "Enable" button or the Settings switch), then registers the token and the
/// real outcome with the backend. Returns whether the permission was granted.
Future<bool> requestNotificationPermission() async {
  await SharedPrefsHelper.setBool(AppConstants.notificationPermissionAsked, true);
  final status = await Permission.notification.request();
  debugPrint('🔔 notification permission prompt → $status');
  if (status.isGranted || status.isProvisional) {
    await syncPushToken(reason: 'permission granted');
    return true;
  }
  // Refused: record the real choice so the backend stops counting on a push.
  await _setServerNotificationsFlag(false);
  return false;
}

Future<void>? _syncing;

/// The single place that sends this device's push token to the backend.
/// Safe to call from anywhere, any number of times: concurrent calls share
/// one run. Waits for a session, for APNs on iOS, checks the HTTP status and
/// retries (3 attempts, growing delays). Never throws, never blocks the UI.
Future<void> syncPushToken({String reason = ''}) {
  return _syncing ??=
      _syncPushToken(reason).whenComplete(() => _syncing = null);
}

Future<void> _syncPushToken(String reason) async {
  const tag = '🔔 syncPushToken';
  try {
    final access = await SharedPrefsHelper.getString(AppConstants.token);
    final refresh = await SharedPrefsHelper.getString(AppConstants.refreshToken);
    if (access.isEmpty && refresh.isEmpty) {
      debugPrint('$tag [$reason] skipped: no session yet');
      return;
    }

    final permission = await pushPermissionState();
    if (permission != PushPermission.granted) {
      debugPrint('$tag [$reason] skipped: permission is $permission');
      return;
    }

    final token = await _obtainFcmToken(tag);
    if (token == null) return;

    final registered = await _postTokenWithRetries(token, tag);
    if (!registered) return;

    // The server turns pushes on when it receives a token; a player who
    // switched them off in Settings must stay off.
    if (await isNotificationsOptOut()) {
      debugPrint('$tag opt-out is on: sending recived_notifications=false');
      await _setServerNotificationsFlag(false);
    }
  } catch (e) {
    debugPrint('$tag [$reason] unexpected failure: $e');
  }
}

/// iOS needs the APNs token before FCM can hand out its own; it arrives
/// asynchronously after registration, so wait for it with short retries.
Future<String?> _obtainFcmToken(String tag) async {
  final messaging = FirebaseMessaging.instance;
  try {
    if (Platform.isIOS) {
      // Permission is already granted here: this call only (re-)registers the
      // device for remote notifications, it does not prompt again.
      await messaging.requestPermission();
      String? apns;
      for (var i = 0; i < 10 && (apns == null || apns.isEmpty); i++) {
        apns = await messaging.getAPNSToken();
        if (apns == null || apns.isEmpty) {
          debugPrint('$tag APNs token not ready (try ${i + 1}/10)');
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      if (apns == null || apns.isEmpty) {
        debugPrint('$tag gave up: no APNs token (will retry on next resume)');
        return null;
      }
    }
    final token = await messaging.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('$tag getToken() returned no token');
      return null;
    }
    return token;
  } catch (e) {
    debugPrint('$tag could not get the FCM token: $e');
    return null;
  }
}

Future<bool> _postTokenWithRetries(String token, String tag) async {
  const delays = [Duration(seconds: 2), Duration(seconds: 4), Duration(seconds: 8)];
  final url =
      '${ApiUrl.baseUrl}${ApiUrl.registerFcmToken}?token=${Uri.encodeQueryComponent(token)}';
  for (var attempt = 0; attempt < delays.length; attempt++) {
    int? code;
    try {
      final response = await ApiClient().post(url: url, showResult: true);
      code = response.statusCode;
    } catch (e) {
      debugPrint('$tag POST failed (attempt ${attempt + 1}/3): $e');
    }
    if (code == 200) {
      debugPrint('$tag token registered');
      return true;
    }
    debugPrint('$tag POST answered $code (attempt ${attempt + 1}/3)');
    if (code == 401) {
      // ApiClient already tried one refresh; make sure a session still exists.
      if (!await SessionService.refresh()) {
        debugPrint('$tag session cannot be refreshed: stopping');
        return false;
      }
    } else if (code != null && code < 500) {
      debugPrint('$tag rejected by the server: stopping');
      return false;
    }
    if (attempt < delays.length - 1) await Future.delayed(delays[attempt]);
  }
  debugPrint('$tag gave up after 3 attempts');
  return false;
}

/// Writes `recived_notifications` on the player's profile. Best-effort.
Future<void> _setServerNotificationsFlag(bool enabled) async {
  const tag = '🔔 notifications flag';
  try {
    final api = ApiClient();
    int? profileId;
    final list = await api.get(url: '${ApiUrl.baseUrl}${ApiUrl.userProfiles}');
    if (list.statusCode == 200 && list.body is List && (list.body as List).isNotEmpty) {
      final first = (list.body as List).first;
      if (first is Map && first['id'] is int) profileId = first['id'] as int;
    }
    if (profileId == null) {
      debugPrint('$tag no profile yet: nothing to update');
      return;
    }
    final response = await api.patch(
      url: '${ApiUrl.baseUrl}${ApiUrl.updateProfile(profileId)}',
      body: {'recived_notifications': enabled},
    );
    if (response.statusCode != 200) {
      debugPrint('$tag PATCH answered ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('$tag failed: $e');
  }
}

/// Logout: detach this device from the account that is leaving, so the next
/// player on the phone does not share its token. Older servers answer
/// 404/405 — that is only logged.
Future<void> unregisterPushToken() async {
  const tag = '🔔 unregisterPushToken';
  try {
    final ok = await ApiClient()
        .delete(url: '${ApiUrl.baseUrl}${ApiUrl.registerFcmToken}', code: 204)
        .timeout(const Duration(seconds: 5));
    if (!ok) {
      debugPrint('$tag not accepted (server may not support it yet)');
    }
  } catch (e) {
    debugPrint('$tag failed: $e');
  }
}

/// Call after the Settings switch is turned on: honour it with the OS.
Future<void> enablePushFromSettings() async {
  switch (await pushPermissionState()) {
    case PushPermission.granted:
      await syncPushToken(reason: 'settings switch on');
    case PushPermission.notAsked:
      await requestNotificationPermission();
    case PushPermission.denied:
      // Only the iOS settings can grant it now.
      await openAppSettings();
  }
}
