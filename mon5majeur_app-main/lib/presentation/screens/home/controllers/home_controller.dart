// lib/presentation/screens/home/controller/home_controller.dart
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/local_db/local_db.dart';
import '../../../../data/models/my_league_model.dart';
import '../../../../data/models/my_match_today_model.dart';
import '../../../../data/models/private_league_model.dart';
import '../../../../data/models/profile_model.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';

final logger = Logger();

class HomeController extends GetxController {
  // Observable variables
  var isLoading = false.obs;
  var userProfile = Rx<UserProfileModel?>(null);
  var matchesLoading = false.obs;
  var todayMatches = <MyMatchTodayModel>[].obs;
  var leaguesLoading = false.obs;
  var myLeagues = <MyLeagueModel>[].obs;
  var profileExists = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchUserProfile();
    fetchTodayMatches();
    fetchMyLeagues();
  }

  void resetSessionState() {
    userProfile.value = null;
    todayMatches.clear();
    myLeagues.clear();
    profileExists.value = false;
    isLoading.value = false;
    matchesLoading.value = false;
    leaguesLoading.value = false;
  }

  // Check if user has completed profile setup
  Future<bool> hasCompletedProfile() async {
    final isCompleted = await SharedPrefsHelper.getBool(
      AppConstants.isProfileCompleted,
    );
    return isCompleted ?? false;
  }

  // Fetch user profile
  Future<void> fetchUserProfile() async {
    if (isLoading.value) return;

    isLoading.value = true;

    try {
      final apiClient = ApiClient();

      logger.i('Fetching User Profile...');

      final response = await apiClient.get(
        url: ApiUrl.baseUrl + ApiUrl.userProfiles,
        isBasic: false, // Use bearer token
        showResult: true,
      );

      logger.i('Profile Response: ${response.statusCode}');
      logger.i('Profile Body: ${response.body}');

      if (response.statusCode == 200) {
        // API returns an array, get the first profile
        if (response.body is List && (response.body as List).isNotEmpty) {
          final profileData = (response.body as List).first;
          userProfile.value = UserProfileModel.fromJson(profileData);
          profileExists.value = true;
          logger.i('Profile loaded: ${userProfile.value}');

          // ✅ Save flag when profile exists on server
          await SharedPrefsHelper.setBool(
            AppConstants.isProfileCompleted,
            true,
          );
        } else {
          logger.w('No profile found in response');
          userProfile.value = null;
          profileExists.value = false;
          // ✅ Clear flag if no profile exists
          await SharedPrefsHelper.setBool(
            AppConstants.isProfileCompleted,
            false,
          );
        }
      } else {
        logger.e('Failed to load profile: ${response.statusCode}');
        userProfile.value = null;
        profileExists.value = false;
      }
    } catch (e) {
      logger.e('Error fetching profile: $e');
      userProfile.value = null;
      profileExists.value = false;
    } finally {
      isLoading.value = false;
    }
  }

  // Fetch today's matches
  Future<void> fetchTodayMatches() async {
    if (matchesLoading.value) return;

    matchesLoading.value = true;

    try {
      final apiClient = ApiClient();

      logger.i('Fetching Today\'s Matches...');

      final response = await apiClient.get(
        url: ApiUrl.baseUrl + ApiUrl.myMatchesToday,
        isBasic: false,
        showResult: true,
      );

      logger.i('Matches Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        if (response.body is List) {
          final matchesList = (response.body as List)
              .map((json) => MyMatchTodayModel.fromJson(json))
              .toList();

          todayMatches.value = matchesList;
          logger.i('Loaded ${todayMatches.length} matches');
        }
      } else {
        logger.e('Failed to load matches: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Error fetching matches: $e');
    } finally {
      matchesLoading.value = false;
    }
  }

  // Fetch my leagues
  Future<void> fetchMyLeagues() async {
    if (leaguesLoading.value) return;

    leaguesLoading.value = true;

    try {
      final apiClient = ApiClient();

      logger.i('Fetching My Leagues...');

      final response = await apiClient.get(
        url: ApiUrl.baseUrl + ApiUrl.myPrivateLeagues,
        isBasic: false,
        showResult: true,
      );

      logger.i('Leagues Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        if (response.body is List) {
          final leaguesList = (response.body as List)
              .map((json) => PrivateLeagueModel.fromJson(json))
              .map(
                (privateLeague) => MyLeagueModel.fromPrivateLeague(
                  privateLeague,
                  userRank: privateLeague.rank,
                  matchday: privateLeague.currentMatchDay,
                  week: privateLeague.currentWeek,
                  season: 'Regular Season',
                ),
              )
              .toList();

          myLeagues.value = leaguesList;
          logger.i('Loaded ${myLeagues.length} leagues');
        }
      } else {
        logger.e('Failed to load leagues: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Error fetching leagues: $e');
    } finally {
      leaguesLoading.value = false;
    }
  }

  // Check if profile exists on the server
  Future<bool> checkProfileExists() async {
    try {
      final apiClient = ApiClient();
      final url = ApiUrl.baseUrl + ApiUrl.userProfiles;

      final response = await apiClient.get(url: url, showResult: true);

      if (response.statusCode == 200 && response.body is List) {
        final profiles = response.body as List;
        profileExists.value = profiles.isNotEmpty;
        return profileExists.value;
      }

      return false;
    } catch (e) {
      logger.e("Check profile error: $e");
      return false;
    }
  }

  // Get team logo asset based on team_logo string from API
  AssetGenImage getTeamLogoAsset(String teamLogo) {
    switch (teamLogo.toLowerCase()) {
      case 'paris_fc':
        return Assets.icons.logo1;
      case 'lakers':
        return Assets.icons.logo2;
      case 'boston_celtics':
        return Assets.icons.logo3;
      case 'chicago_bulls':
        return Assets.icons.logo4;
      case 'atlanta_hawks':
        return Assets.icons.logo5;
      case 'golden_state_warriors':
        return Assets.icons.logo6;
      default:
        return Assets.icons.logo1; // Default logo
    }
  }

  // Get display team name
  String get displayTeamName {
    return userProfile.value?.teamName ?? 'Team Name';
  }

  // Get team logo
  AssetGenImage get displayTeamLogo {
    if (userProfile.value != null) {
      return getTeamLogoAsset(userProfile.value!.teamLogo);
    }
    return Assets.icons.logo1; // Default
  }

  // Refresh profile data, matches, and leagues
  Future<void> refreshProfile() async {
    await Future.wait([
      fetchUserProfile(),
      fetchTodayMatches(),
      fetchMyLeagues(),
    ]);
  }
}
