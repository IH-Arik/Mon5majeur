class RoutePath {
  static const String basePath = '/';

  //=================== Initial screens ===================
  static const String languageScreen = 'languageScreen';

  //=================== Auth screens ===================
  static const String welcomeScreen = 'welcomeScreen';
  static const String signInScreen = 'signInScreen';
  static const String signUp = 'signUp';
  static const String verifyRegistration = 'verifyRegistration';
  static const String forgetPassword = 'forgetPassword';
  static const String otpScreen = 'otpScreen';
  static const String updatePassword = 'updatePassword';
  static const String success = 'success';

  //==================================== Profile Setup screens =====================================

  static const String profileSetup = 'profileSetup';

  //==================================== Home screens =====================================

  static const String home = 'home';
  static const String myLeague = 'myLeague';
  static const String myMatchToday = 'myMatchToday';
  static const String createLeagueScreen = 'createLeagueScreen';
  static const String createPrivateLeagueScreen = 'createPrivateLeagueScreen';
  static const String createPrivateLeagueWaitingRoomScreen =
      'createPrivateLeagueWaitingRoomScreen';
  static const String editPrivateLeagueScreen = 'editPrivateLeagueScreen';
  static const String createPublicLeagueScreen = 'createPublicLeagueScreen';
  static const String createPublicLeagueWaitingRoomScreen =
      'createPublicLeagueWaitingRoomScreen';
  static const String editPublicLeagueScreen = 'editPublicLeagueScreen';
  static const String selectPlayerScreenPublic = 'selectPlayerScreenPublic';
  static const String chooseALeagueScreen = 'chooseALeagueScreen';
  static const String privateLeagueScreen = 'privateLeagueScreen';
  static const String publicLeagueScreen = 'publicLeagueScreen';
  static const String publicLeagueWaitingRoomScreen =
      'publicLeagueWaitingRoomScreen';
  static const String privateLeagueWaitingRoomScreen =
      'privateLeagueWaitingRoomScreen';
  static const String globalLeagueScreen = 'globalLeagueScreen';
  static const String faqScreen = 'faqScreen';
  static const String aboutUsScreen = 'aboutUsScreen';
  static const String legalNoticesScreen = 'legalNoticesScreen';
  static const String privacyPolicyScreen = 'privacyPolicyScreen';
  static const String termsOfUseScreen = 'termsOfUseScreen';
  static const String fantasyLeagueScreenPrivate = 'fantasyLeagueScreenPrivate';
  static const String fantasyLeagueScreenForJoin = 'fantasyLeagueScreenForJoin';
  static const String liveScoreScreen = 'liveScoreScreen';
  static const String notificationsScreen = 'notificationsScreen';

  //==================================== Shop screens =====================================

  static const String shopScreen = 'shopScreen';
  static const String buyToken = 'buyToken';

  //==================================== ProfileScreen screens =====================================

  static const String profileScreen = 'profileScreen';
  static const String profileSettingsScreen = 'profileSettingsScreen';
  static const String supportScreen = 'supportScreen';
  static const String passwordReset = 'passwordReset';

  //==================================== myMatch screens =====================================
  static const String myMatch = 'myMatch';
  static const String data = 'data';

  //==================================== Subscription screens =====================================

  static const String subscription = 'subscription';
  static const String errorScreen = 'errorScreen';
}

// // Update api_url.dart
// class ApiUrl {
//   static const baseUrl = "https://api.mon5majeur.com"; // Production URL
//   // static const baseUrl =
//   // "https://partnerless-rochel-however.ngrok-free.dev"; // Production URL

//   static const imageBaseUrl = '$baseUrl';

//   // Auth endpoints
//   static const register = "/api/auth/register/";
//   static const verifyOtp = "/api/auth/verify-otp/";
//   static const login = "/api/auth/login/";

//   // Forgot password endpoints
//   static const forgotPassword = "/api/auth/forgot-password/";
//   static const verifyForgotPasswordOtp =
//       "/api/auth/verify-forgot-password-otp/";
//   static const changePassword = "/api/auth/change-password/";

//   // Profile endpoints
//   static const userProfiles = "/api/UserProfiles/";

//   // Private League endpoints
//   static const privateLeagues = "/api/private-leagues/";
//   static const myPrivateLeagues = "/api/private-leagues/my_leagues/";
//   static const kickTeam = "/api/private-leagues/kick/";
//   static const startLeague = "/api/private-leagues/start_league/";
//   static const joinLeague = "/api/private-leagues/join/";
//   static const myMatchesToday =
//       "/api/private-leagues/matches/my-matches-today/";

//   // Players endpoint
//   static const playersToday = "/api/players-today/";

//   // WebSocket
//   static String leagueWebSocket(int leagueId) =>
//       "ws://api.mon5majeur.com/ws/leagues/$leagueId/";
// }
