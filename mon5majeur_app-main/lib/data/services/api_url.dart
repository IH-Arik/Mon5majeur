// Update api_url.dart
class ApiUrl {
  static const baseUrl =
      "https://energize-dyslexic-frisbee.ngrok-free.dev"; // Dev: ngrok tunnel → localhost:8001

  static const imageBaseUrl = baseUrl;

  // Auth endpoints
  static const register = "/api/auth/register/";
  static const verifyOtp = "/api/auth/verify-otp/";
  static const login = "/api/auth/login/";

  // Forgot password endpoints
  static const forgotPassword = "/api/auth/forgot-password/";
  static const verifyForgotPasswordOtp =
      "/api/auth/verify-forgot-password-otp/";
  static const changePassword = "/api/auth/change-password/";

  // Change password while logged in (settings screen)
  static const changePasswordAuth = "/api/auth/change-password-auth/";

  // Social auth
  static const googleAuth = "/api/auth/google/";

  // Profile endpoints
  static const userProfiles = "/api/UserProfiles/";
  static String updateProfile(int profileId) => "/api/UserProfiles/$profileId/";
  static const tokenBalance = "/api/UserProfiles/token-balance/";

  // Push notifications
  static const registerFcmToken = "/api/v1/users/me/fcm-token";

  // Static content & GDPR (About Us / Legal Notices / Privacy Policy)
  static const aboutUs = "/api/aboutus/";
  static const legalNotices = "/api/legal-notices/";
  static const privacyPolicy = "/api/privacy-policies/";

  // Private League endpoints
  static const privateLeagues = "/api/private-leagues/";
  static const myPrivateLeagues = "/api/private-leagues/my_leagues/";
  static const kickTeam = "/api/private-leagues/kick/";
  static const startLeague = "/api/private-leagues/start_league/";
  static const joinLeague = "/api/private-leagues/join/";
  static const myMatchesToday =
      "/api/private-leagues/matches/my-matches-today/";

  // Players endpoint
  static const playersToday = "/api/players-today/";

  // WebSocket — derived from baseUrl so it works with ngrok and production
  static String leagueWebSocket(int leagueId) {
    final wsBase = baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return "$wsBase/ws/leagues/$leagueId/";
  }

  // Bonus shop endpoints
  static const bonusInventory = "/api/bonuses/my-inventory/";
  static const bonusPurchase = "/api/bonuses/purchase/";
  static const earnDailyVideo = "/api/tokens/earn/daily-video/";
  static const tokenWallet = "/api/tokens/wallet";

  static const gamesToday = "/api/games-today/";
  static const gamesHistory = "/api/games-history/";
  static const playersTodayScores = "/api/players-today-scores/";

  // Private League - Player Selection & Match Results
  static String playersSelection(int leagueId, int matchDay) =>
      "/api/private-leagues/$leagueId/$matchDay/players-selection/";

  static String privatePlayersSelection(int leagueId, int matchDay) =>
      "/api/private-leagues/$leagueId/$matchDay/players-selection/";

  static String privateMatchResult(int leagueId, int matchDay) =>
      "/api/private-leagues/matches/$leagueId/$matchDay/";

  // For backward compatibility
  static String matchResult(int leagueId, int matchDay) =>
      "/api/private-leagues/matches/$leagueId/$matchDay/";

  // Private League - Standings & Playoffs (Leaderboard tab)
  static String privateStandings(int leagueId) =>
      "/api/private-leagues/$leagueId/standings/";

  static String privatePlayoffs(int leagueId) =>
      "/api/private-leagues/$leagueId/playoffs/";

  // Private League - combined free-quota + purchased bonus availability
  static String privateBonusStatus(int leagueId) =>
      "/api/private-leagues/$leagueId/bonus-status/";

  // Public League endpoints
  static const publicLeagues = "/api/public-leagues/";
  static const activePublicLeagues = "/api/public-leagues/active_leagues/";
  static const joinPublicLeague = "/api/public-leagues/join/";
  static const myPublicLeagues = "/api/public-leagues/my_leagues/";
  static const startPublicLeague = "/api/public-leagues/start_league/";
  static const kickPublicTeam = "/api/public-leagues/kick/";

  // Public League - Player Selection & Match Results
  static String publicPlayersSelection(int leagueId, int matchDay) =>
      "/api/public-leagues/$leagueId/$matchDay/players-selection/";

  static String publicMatchResult(int leagueId, int matchDay) =>
      "/api/public-leagues/matches/$leagueId/$matchDay/";
  static String playerDetails(String playerId, String gameId) =>
      "/api/player-details/$playerId/$gameId/";

  // Public League - Standings & Playoffs (Leaderboard tab)
  static String publicStandings(int leagueId) =>
      "/api/public-leagues/$leagueId/standings/";

  static String publicPlayoffs(int leagueId) =>
      "/api/public-leagues/$leagueId/playoffs/";

  // Public League - combined free-quota + purchased bonus availability
  static String publicBonusStatus(int leagueId) =>
      "/api/public-leagues/$leagueId/bonus-status/";

  // Global League endpoints
  static const globalLeaguePlayersSelection =
      "/api/global-leagues/players-selection/";

  // Live Score endpoints (premium, spec §4.5)
  static const livePremiumStatus = "/api/v1/live/premium-status";
  static String liveMatch(String matchId) => "/api/v1/live/match/$matchId";
  static const liveGlobal = "/api/v1/live/global";
}
