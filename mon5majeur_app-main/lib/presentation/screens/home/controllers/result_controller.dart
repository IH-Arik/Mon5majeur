// lib/presentation/screens/home/my_league_screens/controller/result_controller.dart
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../../../../controllers/global_league_controller.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/local_db/local_db.dart';
import '../../../../data/models/match_result_model.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/services/match_result_cache.dart';

final logger = Logger();

typedef _DayResponse = ({int? status, dynamic body});

enum LeagueType { private, public, global }

class ResultController extends GetxController {
  // A day that is not cached is loading: the body is hidden, a thin bar shows.
  var isLoading = false.obs;
  // A cached day is on screen while it is silently refreshed (thin bar only).
  var isRefreshing = false.obs;
  var currentMatchDay = 1.obs;
  // Last match day known for the league (read when the screen opens); the
  // "next" arrow stops there. Null = unknown, no limit.
  final lastMatchDay = Rxn<int>();
  Rx<MatchResultModel?> matchResult = Rx<MatchResultModel?>(null);
  var expandedCardIndex = Rxn<int>();

  // Store league ID, current user ID, and league type
  int? leagueId;
  int? currentUserId;
  LeagueType leagueType = LeagueType.private; // Default to private

  String? _userId; // the account the result cache is bound to
  int _token = 0; // bumped on every new request: older answers are not shown
  Future<void> _prefetchChain = Future.value();
  final Map<String, Future<_DayResponse>> _running = {};

  /// The cache key of the league on screen (null for the Global League, which
  /// is not cached here).
  String? get _leagueKey => leagueType == LeagueType.global || leagueId == null
      ? null
      : '${leagueType.name}:$leagueId';

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
    // The controller is shared by every league: never keep another league's
    // result on screen.
    final changed = leagueId != id || leagueType != type;
    leagueId = id;
    leagueType = type;
    if (changed) matchResult.value = null;
    lastMatchDay.value =
        (initialMatchDay != null && initialMatchDay > 0) ? initialMatchDay : null;
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
    if (matchResult.value == null) isLoading.value = true;
    _bindAndFetch();
  }

  Future<void> _bindAndFetch() async {
    _userId = await MatchResultCache.bindToCurrentUser();
    fetchMatchResult();
  }

  /// The tab was left: nothing more is loaded for it.
  void leave() {
    // No observable is touched here: this runs while the tree is being torn
    // down. The next fetch sets the loading flags itself.
    _token++;
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

  void toggleCardExpansion(int index) {
    if (expandedCardIndex.value == index) {
      expandedCardIndex.value = null;
    } else {
      expandedCardIndex.value = index;
    }
  }

  Future<void> fetchMatchResult({bool force = false}) async {
    if (leagueType != LeagueType.global && leagueId == null) {
      logger.e("League ID is null");
      return;
    }

    final token = ++_token;
    final type = leagueType;
    final id = leagueId;
    final key = _leagueKey;
    final day = currentMatchDay.value;
    bool stillCurrent() =>
        token == _token && type == leagueType && id == leagueId;

    // A complete day already known: shown at once; refreshed silently when it
    // is older than the freshness delay.
    final cached = (force || key == null) ? null : MatchResultCache.get(key, day);
    if (cached != null) {
      matchResult.value = cached.result;
      isLoading.value = false;
      if (cached.isFresh) {
        isRefreshing.value = false;
        _prefetchPrevious(token);
        return;
      }
      isRefreshing.value = true;
    } else {
      isLoading.value = true;
      isRefreshing.value = false;
    }
    final background = cached != null;

    try {
      final response = await _requestDay(type, id, day);

      if (response.status == 200 && response.body is Map) {
        final model = MatchResultModel.fromJson(
          Map<String, dynamic>.from(response.body as Map),
        );
        // Kept only when complete (see MatchResultCache); a late answer is
        // cached under its own league and day, never shown for another.
        if (key != null) MatchResultCache.put(_userId, key, day, model);
        if (!stillCurrent()) return;
        matchResult.value = model;

        logger.i("✅ Match Result loaded successfully");
        logger.i("   - Match Day: ${model.matchDay}");
        logger.i("   - Pairs: ${model.pairs.length}");

        if (model.matchDay != currentMatchDay.value) {
          logger.i(
            "   - Updating match day from ${currentMatchDay.value} to ${model.matchDay}",
          );
          currentMatchDay.value = model.matchDay;
        }
        final last = lastMatchDay.value;
        if (last != null && model.matchDay > last) {
          lastMatchDay.value = model.matchDay;
        }
        _prefetchPrevious(token);
      } else if (response.status == 404) {
        if (!stillCurrent()) return;
        if (background) return; // keep the cached day
        logger.w("❌ Match day $day not found, trying previous day");
        if (day > 1) {
          // Safety net: the day does not exist (yet); the bound follows.
          currentMatchDay.value--;
          lastMatchDay.value = currentMatchDay.value;
          await fetchMatchResult();
        } else {
          matchResult.value = null;
        }
      } else {
        if (!stillCurrent()) return;
        logger.e("❌ Failed to fetch match result: ${response.status}");
        if (!background) matchResult.value = null;
      }
    } catch (e, stackTrace) {
      logger.e("❌ Error fetching match result: $e");
      logger.e("StackTrace: $stackTrace");
      if (stillCurrent() && !background) matchResult.value = null;
    } finally {
      // Only the request still wanted ends the loading state.
      if (token == _token) {
        isLoading.value = false;
        isRefreshing.value = false;
      }
    }
  }

  /// Warms the day BEFORE the one on screen (the next one is often not
  /// published, so never cached): one call at a time, after the shown day is
  /// loaded, silent on failure, dropped when the user moves on.
  void _prefetchPrevious(int token) {
    final key = _leagueKey;
    final type = leagueType;
    final id = leagueId;
    final prev = currentMatchDay.value - 1;
    if (key == null || prev < 1) return;
    if (MatchResultCache.get(key, prev) != null) return;
    _prefetchChain = _prefetchChain.then((_) async {
      if (token != _token || key != _leagueKey) return;
      if (MatchResultCache.get(key, prev) != null) return;
      try {
        final r = await _requestDay(type, id, prev);
        if (r.status == 200 && r.body is Map) {
          final m = MatchResultModel.fromJson(
            Map<String, dynamic>.from(r.body as Map),
          );
          MatchResultCache.put(_userId, key, prev, m);
        }
      } catch (_) {
        // silent
      }
    });
  }

  /// One call per day at a time: asking again for a day already on its way
  /// (a prefetch the user caught up with) shares that call.
  Future<_DayResponse> _requestDay(LeagueType type, int? id, int day) {
    final key = '${type.name}:$id:$day';
    final running = _running[key];
    if (running != null) return running;
    return _running[key] = _requestNow(type, id, day).whenComplete(() {
      _running.remove(key);
    });
  }

  Future<_DayResponse> _requestNow(LeagueType type, int? id, int day) async {
    try {
      final endpoint = switch (type) {
        LeagueType.public => ApiUrl.publicMatchResult(id!, day),
        LeagueType.private => ApiUrl.privateMatchResult(id!, day),
        LeagueType.global => ApiUrl.globalMatchResult(day),
      };
      final url = '${ApiUrl.baseUrl}$endpoint';
      logger.i("🔵 Fetching ${type.name} league match result: $url");
      final response = await ApiClient().get(url: url, showResult: true);
      return (status: response.statusCode, body: response.body);
    } catch (e) {
      logger.e("❌ Error fetching match result: $e");
      return (status: null, body: null);
    }
  }

  void nextMatchDay() {
    final bound = lastMatchDay.value;
    if (bound != null && currentMatchDay.value >= bound) return;
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
