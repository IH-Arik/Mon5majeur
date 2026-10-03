import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../core/constants/api_constants.dart';
import '../../core/local_db/local_db.dart';
import 'api_service.dart';
import 'api_url.dart';

/// Where a stored session leads the user.
enum SessionDestination { home, profileSetup, signedOut }

/// Keeps the user signed in (QA 30/09 #8 #1). Two parts:
///  * [refresh] swaps the stored refresh token for a new access/refresh pair
///    (the access token only lives 30 min); [ApiClient] calls it on a 401 and
///    retries, so an expired access token is never visible to the user.
///  * [resolve] decides, at app start and right after login, whether the
///    stored session goes to Home or Profile Setup, or is really over.
/// The user is only signed out when the server explicitly rejects the
/// refresh token. A flaky network never logs anybody out.
class SessionService {
  SessionService._();

  static Future<bool>? _refreshing;

  /// Single-flight: parallel 401s share one refresh call (the refresh token
  /// is rotated, so a second concurrent call would use a spent one).
  static Future<bool> refresh() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  static Future<bool> _doRefresh() async {
    final refreshToken =
        await SharedPrefsHelper.getString(AppConstants.refreshToken);
    if (refreshToken.isEmpty) return false;
    try {
      final response =
          await GetConnect(timeout: const Duration(seconds: 15)).post(
        '${ApiUrl.baseUrl}${ApiUrl.refresh}',
        {'refresh_token': refreshToken},
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      final body = response.body;
      if (response.statusCode == 200 && body is Map) {
        final access = body['access_token'] ?? body['access'];
        final refresh = body['refresh_token'] ?? body['refresh'];
        if (access is String && access.isNotEmpty) {
          await SharedPrefsHelper.setString(AppConstants.token, access);
          if (refresh is String && refresh.isNotEmpty) {
            await SharedPrefsHelper.setString(
                AppConstants.refreshToken, refresh);
          }
          return true;
        }
      }
    } catch (e) {
      debugPrint('⚠️ token refresh failed: $e');
    }
    return false;
  }

  static Future<void> clear() async {
    await SharedPrefsHelper.remove(AppConstants.token);
    await SharedPrefsHelper.remove(AppConstants.refreshToken);
    await SharedPrefsHelper.remove(AppConstants.userId);
    await SharedPrefsHelper.remove(AppConstants.userEmail);
    await SharedPrefsHelper.setBool(AppConstants.isProfileCompleted, false);
  }

  /// Home / Profile Setup for the stored session, or signed out.
  /// [attempts] > 1 retries a failed profile request, so one slow or failed
  /// call right after login can no longer send an existing user to the wrong
  /// screen.
  static Future<SessionDestination> resolve({int attempts = 1}) async {
    final token = await SharedPrefsHelper.getString(AppConstants.token);
    final refresh =
        await SharedPrefsHelper.getString(AppConstants.refreshToken);
    if (token.isEmpty && refresh.isEmpty) return SessionDestination.signedOut;

    for (var i = 0; i < attempts; i++) {
      try {
        // ApiClient refreshes an expired access token and retries by itself.
        final response = await ApiClient()
            .get(url: '${ApiUrl.baseUrl}${ApiUrl.userProfiles}');
        if (response.statusCode == 200 && response.body is List) {
          final hasProfile = (response.body as List).isNotEmpty;
          await SharedPrefsHelper.setBool(
              AppConstants.isProfileCompleted, hasProfile);
          return hasProfile
              ? SessionDestination.home
              : SessionDestination.profileSetup;
        }
        if (response.statusCode == 401) {
          // refresh was rejected too: the session is really over
          await clear();
          return SessionDestination.signedOut;
        }
      } catch (e) {
        debugPrint('⚠️ session check failed: $e');
      }
      if (i < attempts - 1) {
        await Future.delayed(const Duration(milliseconds: 700));
      }
    }

    // Server unreachable: keep the session and trust what we last knew.
    final completed =
        await SharedPrefsHelper.getBool(AppConstants.isProfileCompleted) ??
            false;
    return completed
        ? SessionDestination.home
        : SessionDestination.profileSetup;
  }
}
