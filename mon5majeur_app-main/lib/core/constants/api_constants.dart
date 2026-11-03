// Update api_constants.dart
class AppConstants {
  // Store links used in the league invitation message
  static const String appStoreUrl =
      "https://apps.apple.com/fr/app/mon5majeur/id6753639666";
  static const String playStoreUrl =
      "https://play.google.com/store/apps/details?id=com.mon5majeur.app";

  // Auth tokens
  static const String token = "token";
  static const String refreshToken = "refreshToken";

  // User data
  static const String userRole = "userRole";
  static const String userId = "userId";
  static const String userEmail = "userEmail";

  // App settings
  static const String language = 'language';
  static const String isProfileCompleted = 'is_profile_completed';

  // Notifications
  // Set once the OS permission prompt has been shown (iOS cannot tell
  // "never asked" from "refused" through permission_handler alone).
  static const String notificationPermissionAsked =
      'notification_permission_asked';
  // Set once the explainer screen has been shown, so it never comes back.
  static const String notificationExplainerShown =
      'notification_explainer_shown';
  // Number of app launches; the explainer's safety net shows from the 2nd.
  static const String appOpenCount = 'app_open_count';
  // Written ONLY by the Settings switch: the player turned notifications off
  // in the app. Never re-enable, never nag.
  static const String notificationsOptOut = 'notifications_opt_out';
  // The player hid the "enable notifications" home banner.
  static const String notificationBannerDismissed =
      'notification_banner_dismissed';

  // Onboarding tutorial (spec Part 3)
  static const String tutorialStep = 'tutorial_step';
  static const String tutorialDone = 'tutorial_done';
}
