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

/// The pieces of a sync that talk to the phone or the network. Tests replace
/// them; the app never touches this.
@visibleForTesting
class PushDeps {
  static Future<PushPermission> Function() permission = pushPermissionState;
  static Future<String?> Function() fcmToken = _obtainFcmToken;
  static Future<int?> Function(String token) postToken = _postToken;
  static Future<bool> Function() deleteToken = _deleteToken;
  static Future<bool> Function() isOptOut = isNotificationsOptOut;
  static Future<void> Function(bool enabled) setServerFlag =
      _setServerNotificationsFlag;
  // Delay between two POST attempts (a test shrinks it).
  static List<Duration> retryDelays = const [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];
  // Nothing may keep the one-at-a-time lock for longer than this.
  static Duration maxRun = const Duration(seconds: 120);
  // Wait before asking again when the phone had no token yet.
  static Duration noTokenRetryDelay = const Duration(seconds: 20);

  static void reset() {
    permission = pushPermissionState;
    fcmToken = _obtainFcmToken;
    postToken = _postToken;
    deleteToken = _deleteToken;
    isOptOut = isNotificationsOptOut;
    setServerFlag = _setServerNotificationsFlag;
    retryDelays = const [
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
    ];
    maxRun = const Duration(seconds: 120);
    noTokenRetryDelay = const Duration(seconds: 20);
    _noTokenRetries = 0;
    _syncing = null;
    _unregistering = null;
    _generation = 0;
  }
}

Future<void>? _syncing;
// Bumped to cancel whatever run is in flight: a run that sees a newer number
// stops before it sends anything.
int _generation = 0;

/// The single place that sends this device's push token to the backend.
/// Safe to call from anywhere, any number of times: concurrent calls share
/// one run. Waits for a session, for APNs on iOS, checks the HTTP status and
/// retries (3 attempts, growing delays). Never throws, never blocks the UI.
///
/// [force] is for a new session (login): the run in flight, if any, is
/// abandoned and a fresh one starts, so a stuck or stale run can never stand
/// between a login and the token reaching the server. A hard time limit also
/// frees the lock whatever happens inside a run.
Future<void> syncPushToken({String reason = '', bool force = false}) {
  if (force) {
    _generation++;
    _syncing = null;
    _noTokenRetries = 0;
  } else if (_syncing != null) {
    return _syncing!;
  }
  final generation = _generation;
  late final Future<void> run;
  run = _syncPushToken(reason, generation)
      .timeout(PushDeps.maxRun, onTimeout: () {
    debugPrint('🔔 syncPushToken [$reason] timed out: lock released');
  }).whenComplete(() {
    if (identical(_syncing, run)) _syncing = null;
  });
  return _syncing = run;
}

int _noTokenRetries = 0;

/// The phone had no token yet (APNs slow to answer, plugin error): try again
/// shortly, three times at most, instead of waiting for the next app opening.
void _retryLater(String reason, int generation, String tag) {
  if (_noTokenRetries >= 3) return;
  _noTokenRetries++;
  debugPrint('$tag no token yet: retry $_noTokenRetries/3 in 20 s');
  Future.delayed(PushDeps.noTokenRetryDelay, () {
    if (generation == _generation) syncPushToken(reason: 'retry ($reason)');
  });
}

/// True while this run is still the current one and a session still exists.
Future<bool> _stillValid(int generation, String tag, String step) async {
  if (generation != _generation) {
    debugPrint('$tag cancelled before $step (a newer sync or a logout)');
    return false;
  }
  if (!await _hasSession()) {
    debugPrint('$tag stopped before $step: the session is gone');
    return false;
  }
  return true;
}

Future<bool> _hasSession() async {
  final access = await SharedPrefsHelper.getString(AppConstants.token);
  final refresh = await SharedPrefsHelper.getString(AppConstants.refreshToken);
  return access.isNotEmpty || refresh.isNotEmpty;
}

Future<void> _syncPushToken(String reason, int generation) async {
  const tag = '🔔 syncPushToken';
  try {
    if (!await _hasSession()) {
      debugPrint('$tag [$reason] skipped: no session yet');
      return;
    }

    final permission = await PushDeps.permission();
    if (permission != PushPermission.granted) {
      debugPrint('$tag [$reason] skipped: permission is $permission');
      return;
    }

    final token = await PushDeps.fcmToken();
    if (token == null) {
      _retryLater(reason, generation, tag);
      return;
    }
    _noTokenRetries = 0;
    if (!await _stillValid(generation, tag, 'sending the token')) return;

    final registered = await _postTokenWithRetries(token, tag, generation);
    if (!registered) return;

    // The server turns pushes on when it receives a token; a player who
    // switched them off in Settings must stay off.
    if (await PushDeps.isOptOut()) {
      debugPrint('$tag opt-out is on: sending recived_notifications=false');
      await PushDeps.setServerFlag(false);
    }
  } catch (e) {
    debugPrint('$tag [$reason] unexpected failure: $e');
  }
}

/// iOS needs the APNs token before FCM can hand out its own; it arrives
/// asynchronously after registration, so wait for it with short retries.
/// Every call into the plugin has a time limit: none may wait forever.
Future<String?> _obtainFcmToken() async {
  const tag = '🔔 syncPushToken';
  final messaging = FirebaseMessaging.instance;
  try {
    if (Platform.isIOS) {
      // Permission is already granted here: this call only (re-)registers the
      // device for remote notifications, it does not prompt again.
      await messaging.requestPermission().timeout(const Duration(seconds: 10));
      String? apns;
      for (var i = 0; i < 10 && (apns == null || apns.isEmpty); i++) {
        apns = await messaging
            .getAPNSToken()
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
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
    final token =
        await messaging.getToken().timeout(const Duration(seconds: 15));
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

Future<int?> _postToken(String token) async {
  final url =
      '${ApiUrl.baseUrl}${ApiUrl.registerFcmToken}?token=${Uri.encodeQueryComponent(token)}';
  final response = await ApiClient().post(url: url, showResult: true);
  return response.statusCode;
}

Future<bool> _postTokenWithRetries(
  String token,
  String tag,
  int generation,
) async {
  final delays = PushDeps.retryDelays;
  for (var attempt = 0; attempt < delays.length; attempt++) {
    int? code;
    try {
      code = await PushDeps.postToken(token);
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
    if (attempt < delays.length - 1) {
      await Future.delayed(delays[attempt]);
      if (!await _stillValid(generation, tag, 'the next attempt')) return false;
    }
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

Future<void>? _unregistering;

/// Logout: detach this device from the account that is leaving, so the next
/// player on the phone does not share its token. Call it BEFORE the session
/// is erased. It runs once: a second call while one is running shares it, and
/// with no session left (already logged out) nothing is sent. Older servers
/// answer 404/405 — that is only logged.
Future<void> unregisterPushToken() {
  return _unregistering ??= _unregisterPushToken().whenComplete(() {
    _unregistering = null;
  });
}

Future<void> _unregisterPushToken() async {
  const tag = '🔔 unregisterPushToken';
  // Whatever sync is in flight must not put the token back after this.
  _generation++;
  _syncing = null;
  try {
    if (!await _hasSession()) {
      debugPrint('$tag skipped: no session (already logged out)');
      return;
    }
    final ok = await PushDeps.deleteToken().timeout(const Duration(seconds: 5));
    if (!ok) {
      debugPrint('$tag not accepted (server may not support it yet)');
    }
  } catch (e) {
    debugPrint('$tag failed: $e');
  }
}

Future<bool> _deleteToken() => ApiClient()
    .delete(url: '${ApiUrl.baseUrl}${ApiUrl.registerFcmToken}', code: 204);

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
