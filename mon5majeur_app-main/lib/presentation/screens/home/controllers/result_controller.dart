// lib/presentation/screens/home/my_league_screens/controller/result_controller.dart
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../../../../controllers/global_league_controller.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/local_db/local_db.dart';
import '../../../../data/models/match_result_model.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';

final logger = Logger();

enum LeagueType { private, public, global }

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

  void setGlobalLeague({int? initialMatchDay}) {
    leagueId = null;
    leagueType = LeagueType.global;
    if (initialMatchDay != null && initialMatchDay > 0) {
      currentMatchDay.value = initialMatchDay;
    } else {
      if (Get.isRegistered<GlobalLeagueController>()) {
        final global = Get.find<GlobalLeagueController>();
        if (global.currentMatchDay.value > 0) {
          currentMatchDay.value = global.currentMatchDay.value;
        }
      }
    }
    logger.i(
      "Global league result configured, Match Day: ${currentMatchDay.value}",
    );
    fetchMatchResult();
  }

  // Published match days never change: a day already shown (or prefetched) is
  // displayed again at once, no request, no spinner (QA #10 16). Only
  // COMPLETED days that are not behind the score paywall are kept, so the
  // current day - where the opponent's lineup and bonus are still hidden - is
  // always read fresh from the server and never leaks early.
  final Map<String, MatchResultModel> _dayCache = {};
  final Set<String> _prefetching = {};

  String _cacheKey(int day) => '${leagueType.name}:${leagueId ?? 0}:$day';

  bool _isFinal(MatchResultModel r) => r.status == 'completed' && !r.scoresHidden;

  String _endpointFor(int day) => switch (leagueType) {
        LeagueType.public => ApiUrl.publicMatchResult(leagueId!, day),
        LeagueType.private => ApiUrl.privateMatchResult(leagueId!, day),
        LeagueType.global => ApiUrl.globalMatchResult(day),
      };

  /// Loads a neighbouring day in the background and keeps it if published.
  void _prefetch(int day) {
    if (day < 1 || leagueType == LeagueType.global) return;
    final key = _cacheKey(day);
    if (_dayCache.containsKey(key) || !_prefetching.add(key)) return;
    ApiClient()
        .get(url: '${ApiUrl.baseUrl}${_endpointFor(day)}')
        .then((response) {
      if (response.statusCode == 200 && response.body is Map) {
        final r = MatchResultModel.fromJson(response.body);
        if (_isFinal(r)) _dayCache[key] = r;
      }
    }).catchError((_) {}).whenComplete(() => _prefetching.remove(key));
  }

  void toggleCardExpansion(int index) {
    if (expandedCardIndex.value == index) {
      expandedCardIndex.value = null;
    } else {
      expandedCardIndex.value = index;
    }
  }

  Future<void> fetchMatchResult() async {
    if (leagueType != LeagueType.global && leagueId == null) {
      logger.e("League ID is null");
      return;
    }

    final cached = leagueType == LeagueType.global
        ? null
        : _dayCache[_cacheKey(currentMatchDay.value)];
    if (cached != null) {
      matchResult.value = cached;
      expandedCardIndex.value = null;
      _prefetch(currentMatchDay.value - 1);
      _prefetch(currentMatchDay.value + 1);
      return;
    }

    isLoading.value = true;

    try {
      final apiClient = ApiClient();

      // Use the appropriate endpoint based on league type
      final endpoint = switch (leagueType) {
        LeagueType.public =>
          ApiUrl.publicMatchResult(leagueId!, currentMatchDay.value),
        LeagueType.private =>
          ApiUrl.privateMatchResult(leagueId!, currentMatchDay.value),
        LeagueType.global => ApiUrl.globalMatchResult(currentMatchDay.value),
      };

      final url = '${ApiUrl.baseUrl}$endpoint';

      logger.i("🔵 Fetching ${leagueType.name} league match result: $url");

      final response = await apiClient.get(url: url, showResult: true);

      logger.i("🔵 Match Result Response Status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = response.body;
        matchResult.value = MatchResultModel.fromJson(data);
        if (leagueType != LeagueType.global && _isFinal(matchResult.value!)) {
          _dayCache[_cacheKey(matchResult.value!.matchDay)] = matchResult.value!;
        }
        if (leagueType != LeagueType.global) {
          _prefetch(matchResult.value!.matchDay - 1);
          _prefetch(matchResult.value!.matchDay + 1);
        }

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
