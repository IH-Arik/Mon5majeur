// lib/presentation/screens/home/my_league_screens/controller/result_controller.dart
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/local_db/local_db.dart';
import '../../../../data/models/match_result_model.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';

final logger = Logger();

enum LeagueType { private, public }

class ResultController extends GetxController {
  var isLoading = false.obs;
  var currentMatchDay = 1.obs;
  Rx<MatchResultModel?> matchResult = Rx<MatchResultModel?>(null);
  var expandedCardIndex = Rxn<int>();

  // Store league ID, current user ID, and league type
  int? leagueId;
  int? currentUserId;
  LeagueType leagueType = LeagueType.private; // Default to private

  @override
  void onInit() {
    super.onInit();
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    final userId = await SharedPrefsHelper.getString(AppConstants.userId);
    currentUserId = int.tryParse(userId);
    logger.i("Current User ID: $currentUserId");
  }

  void setLeagueId(
    int id, {
    int? initialMatchDay,
    LeagueType type = LeagueType.private,
  }) {
    leagueId = id;
    leagueType = type;
    if (initialMatchDay != null && initialMatchDay > 0) {
      currentMatchDay.value = initialMatchDay;
      logger.i(
        "League ID set to: $leagueId (${type.name}), Match Day: $initialMatchDay",
      );
    } else {
      logger.i(
        "League ID set to: $leagueId (${type.name}), Match Day: ${currentMatchDay.value} (default)",
      );
    }
    fetchMatchResult();
  }

  void toggleCardExpansion(int index) {
    if (expandedCardIndex.value == index) {
      expandedCardIndex.value = null;
    } else {
      expandedCardIndex.value = index;
    }
  }

  Future<void> fetchMatchResult() async {
    if (leagueId == null) {
      logger.e("League ID is null");
      return;
    }

    isLoading.value = true;

    try {
      final apiClient = ApiClient();

      // Use the appropriate endpoint based on league type
      final endpoint = leagueType == LeagueType.public
          ? ApiUrl.publicMatchResult(leagueId!, currentMatchDay.value)
          : ApiUrl.privateMatchResult(leagueId!, currentMatchDay.value);

      final url = '${ApiUrl.baseUrl}$endpoint';

      logger.i("🔵 Fetching ${leagueType.name} league match result: $url");

      final response = await apiClient.get(url: url, showResult: true);

      logger.i("🔵 Match Result Response Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = response.body;
        matchResult.value = MatchResultModel.fromJson(data);

        logger.i("✅ Match Result loaded successfully");
        logger.i("   - Match Day: ${matchResult.value?.matchDay}");
        logger.i("   - Pairs: ${matchResult.value?.pairs.length}");
        logger.i(
          "   - Player Scores: ${matchResult.value?.playerScores.length}",
        );

        if (matchResult.value?.matchDay != null &&
            matchResult.value!.matchDay != currentMatchDay.value) {
          logger.i(
            "   - Updating match day from ${currentMatchDay.value} to ${matchResult.value!.matchDay}",
          );
          currentMatchDay.value = matchResult.value!.matchDay;
        }

        matchResult.value?.playerScores.forEach((playerScore) {
          logger.i(
            "   - Player ${playerScore.username}: ${playerScore.selection.length} players selected",
          );
        });
      } else if (response.statusCode == 404) {
        logger.w(
          "❌ Match day ${currentMatchDay.value} not found, trying previous day",
        );
        if (currentMatchDay.value > 1) {
          currentMatchDay.value--;
          await fetchMatchResult();
        } else {
          matchResult.value = null;
        }
      } else {
        logger.e("❌ Failed to fetch match result: ${response.statusText}");
        matchResult.value = null;
      }
    } catch (e, stackTrace) {
      logger.e("❌ Error fetching match result: $e");
      logger.e("StackTrace: $stackTrace");
      matchResult.value = null;
    } finally {
      isLoading.value = false;
    }
  }

  void nextMatchDay() {
    currentMatchDay.value++;
    fetchMatchResult();
  }

  void previousMatchDay() {
    if (currentMatchDay.value > 1) {
      currentMatchDay.value--;
      fetchMatchResult();
    }
  }

  bool isCurrentUserInMatch(MatchPair pair) {
    if (currentUserId == null) return false;
    return pair.playerAId == currentUserId || pair.playerBId == currentUserId;
  }

  PlayerScore? getPlayerScoreById(int playerId) {
    final playerScore = matchResult.value?.playerScores.firstWhereOrNull(
      (score) => score.playerId == playerId,
    );

    if (playerScore != null) {
      logger.d(
        "Found player score for ID $playerId: ${playerScore.username} with ${playerScore.selection.length} players",
      );
    } else {
      logger.w("No player score found for ID $playerId");
    }

    return playerScore;
  }
}
