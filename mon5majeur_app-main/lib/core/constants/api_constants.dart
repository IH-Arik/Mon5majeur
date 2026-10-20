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
  static const String notificationPromptHandled = 'notification_prompt_handled';

  // Onboarding tutorial (spec Part 3)
  static const String tutorialStep = 'tutorial_step';
  static const String tutorialDone = 'tutorial_done';
}
