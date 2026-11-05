// lib/presentation/screens/home/controller/home_controller.dart
import '../../../../core/utils/logo_assets.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../controllers/global_league_controller.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/local_db/local_db.dart';
import '../../../../core/utils/datetime_format.dart';
import '../../../../data/models/my_league_model.dart';
import '../../../../data/models/my_match_today_model.dart';
import '../../../../data/models/private_league_model.dart';
import '../../../../data/models/profile_model.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';

final logger = Logger();

/// How long to wait before the next silent refresh of the Home "Résultats de
/// la nuit" card: every 30 s while any of the user's matches is live (a Live
/// Scoring subscriber then sees the score move), otherwise every 2 min so a
/// tip-off, a final and the 09:00 Paris score release all show up without a
/// manual pull-to-refresh.
const Duration kLiveMatchRefresh = Duration(seconds: 30);
const Duration kIdleMatchRefresh = Duration(minutes: 2);

Duration matchRefreshInterval(List<MyMatchTodayModel> matches) =>
    matches.any((m) => m.status == 'live') ? kLiveMatchRefresh : kIdleMatchRefresh;

/// Time in the background after which the day state (match day, lock, lineup)
/// is read again on return. 1 min in debug builds, to test without waiting.
const Duration kLongBackground =
    kDebugMode ? Duration(minutes: 1) : Duration(minutes: 10);

class HomeController extends GetxController {
  // Observable variables
  var isLoading = false.obs;
  var userProfile = Rx<UserProfileModel?>(null);
  var matchesLoading = false.obs;
  var todayMatches = <MyMatchTodayModel>[].obs;
  var leaguesLoading = false.obs;
  var myLeagues = <MyLeagueModel>[].obs;
  var profileExists = false.obs;

  /// The logo chosen at creation for league [leagueId] ('' when unknown, the
  /// default image is then used). It reads the observable [myLeagues], so a
  /// widget calling it inside an Obx redraws when the leagues load (Live
  /// header: the list used to be read through a non-observable copy).
  static String leagueLogoOf(int? leagueId, {required bool isPrivate}) {
    if (leagueId == null || !Get.isRegistered<HomeController>()) return '';
    for (final l in Get.find<HomeController>().myLeagues) {
      if (l.leagueId == leagueId && l.isPrivate == isPrivate) {
        return l.leagueLogo;
      }
    }
    return '';
  }

  Timer? _matchTimer;
  bool _matchRefreshInFlight = false;

  DateTime? _pausedAt;
  DateTime _dayLoadedAt = DateTime.now();

  /// Bumped once the day state has been read again on return from the
  /// background: open lineup screens listen to it.
  final dayRefreshTick = 0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchUserProfile();
    fetchTodayMatches();
    fetchMyLeagues();
  }

  @override
  void onClose() {
    stopMatchAutoRefresh();
    super.onClose();
  }

  /// Start the silent refresh loop (Home screen visible). Safe to call twice.
  void startMatchAutoRefresh() {
    _matchTimer?.cancel();
    _scheduleNextMatchRefresh();
  }

  void stopMatchAutoRefresh() {
    _matchTimer?.cancel();
    _matchTimer = null;
  }

  void _scheduleNextMatchRefresh() {
    _matchTimer?.cancel();
    _matchTimer = Timer(matchRefreshInterval(todayMatches), () async {
      await refreshMatchesSilently();
      // stopMatchAutoRefresh() during the request must not be undone
      if (_matchTimer != null) _scheduleNextMatchRefresh();
    });
  }

  /// Reload the matches WITHOUT the loading spinner, so the card updates in
  /// place instead of flashing.
  Future<void> refreshMatchesSilently() => _loadMatches(silent: true);

  void markPaused() => _pausedAt = DateTime.now();

  /// On return to the foreground: read the leagues and the Global League
  /// selection again (match day, lock, validated flag) when the app stayed
  /// away for [kLongBackground], or when a 09:00 Paris publication has passed
  /// since the last load. Otherwise nothing is called.
  Future<void> refreshDayState() async {
    final now = DateTime.now();
    final paused = _pausedAt;
    _pausedAt = null;
    final longAway = paused != null && now.difference(paused) > kLongBackground;
    final published = !nextParisNineAm(_dayLoadedAt).isAfter(now.toUtc());
    if (!longAway && !published) return;

    _dayLoadedAt = now;
    final global = Get.find<GlobalLeagueController>();
    await Future.wait([
      fetchMyLeagues(),
      if (global.hasJoined.value) global.fetchGlobalLeagueSelection(),
    ]);
    dayRefreshTick.value++;
  }

  void resetSessionState() {
    stopMatchAutoRefresh();
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
  Future<void> fetchTodayMatches() => _loadMatches(silent: false);

  Future<void> _loadMatches({required bool silent}) async {
    if (matchesLoading.value || _matchRefreshInFlight) return;

    _matchRefreshInFlight = true;
    if (!silent) matchesLoading.value = true;

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
      _matchRefreshInFlight = false;
      if (!silent) matchesLoading.value = false;
    }
  }

  bool _leaguesReloadQueued = false;
  Completer<void>? _leaguesIdle; // done when the load and its queued rerun end

  // Fetch my leagues: private AND public (QA #9 2.1: only private ones were
  // loaded, so a user whose league was public saw "Pas encore de ligue").
  Future<void> fetchMyLeagues() async {
    if (leaguesLoading.value) {
      // A refresh asked while one is running (e.g. right after creating a
      // league) must not be dropped: run once more when the current ends.
      _leaguesReloadQueued = true;
      await _leaguesIdle?.future;
      return;
    }

    final idle = _leaguesIdle = Completer<void>();
    leaguesLoading.value = true;

    try {
      final results = await Future.wait([
        _loadLeaguesFrom(ApiUrl.myPrivateLeagues, isPrivate: true),
        _loadLeaguesFrom(ApiUrl.myPublicLeagues, isPrivate: false),
      ]);
      // Keep what was shown if both calls failed (null), otherwise replace.
      if (results.any((r) => r != null)) {
        myLeagues.value = [
          for (final r in results) ...?r,
        ];
        logger.i('Loaded ${myLeagues.length} leagues');
      }
    } catch (e) {
      logger.e('Error fetching leagues: $e');
    } finally {
      leaguesLoading.value = false;
      if (_leaguesReloadQueued) {
        _leaguesReloadQueued = false;
        await fetchMyLeagues();
      }
      idle.complete();
    }
  }

  Future<List<MyLeagueModel>?> _loadLeaguesFrom(
    String endpoint, {
    required bool isPrivate,
  }) async {
    try {
      final response = await ApiClient().get(
        url: ApiUrl.baseUrl + endpoint,
        isBasic: false,
        showResult: true,
      );
      if (response.statusCode == 200 && response.body is List) {
        return (response.body as List)
            .map((json) => PrivateLeagueModel.fromJson(json))
            .map(
              (league) => MyLeagueModel.fromPrivateLeague(
                league,
                userRank: league.rank,
                matchday: league.currentMatchDay,
                week: league.currentWeek,
                isPrivate: isPrivate,
              ),
            )
            .toList();
      }
      logger.e('Failed to load leagues ($endpoint): ${response.statusCode}');
    } catch (e) {
      logger.e('Error fetching leagues ($endpoint): $e');
    }
    return null;
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
  AssetGenImage getTeamLogoAsset(String teamLogo) => logoAsset(teamLogo);


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
