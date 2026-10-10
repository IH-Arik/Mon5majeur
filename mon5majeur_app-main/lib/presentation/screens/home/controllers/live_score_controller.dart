// lib/presentation/screens/home/controllers/live_score_controller.dart
import 'dart:async';

import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/local_db/local_db.dart';
import '../../../../data/models/live_score_model.dart';
import '../../../../data/models/match_result_model.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';

final _logger = Logger();

enum LiveScoreMode { duel, global }

/// Drives the Live Score screen for both the duels of a league and the
/// Global League (spec §4.5: live score must cover Global League too, not
/// just duel leagues). Polls every 60s while the screen is visible — cheap
/// on our own backend even though the Goalserve sync itself only refreshes
/// every ~20 min (see live_scores/service.py::_is_stale_for_date); the
/// is_stale flag from the backend tells the user when data hasn't moved.
///
/// In a duel league the screen shows EVERY match of the match day, the user's
/// own first (QA #9 12.1).
class LiveScoreController extends GetxController {
  final LiveScoreMode mode;
  final String? matchId;
  // A league tab opens this screen right away with only the league and match
  // day; the duel ids are looked up here, behind the loading state, instead of
  // freezing the tab for a second before the screen appears (QA 28/09/#8 #7).
  final int? leagueId;
  final int? matchDay;
  final bool isPrivate;

  LiveScoreController({
    required this.mode,
    this.matchId,
    this.leagueId,
    this.matchDay,
    this.isPrivate = false,
  });

  List<String>? _resolvedMatchIds;
  // For each match whose lookup is known: true when I am the home team, false
  // when I am the away team. A match missing here (Live opened straight with a
  // match id, or a match I am not in) has no known side.
  final Map<String, bool> myTeamIsHome = {};
  // League name known before any live data (from the match-result lookup).
  final leagueName = ''.obs;

  final isLoading = true.obs;
  final isForbidden = false.obs; // no active premium/live-score subscription
  final errorMessage = RxnString();

  // Every match of the league's match day, the user's own first.
  final matches = <LiveMatchScore>[].obs;
  // The user's own match (first of [matches]); kept for the screen header.
  final matchScore = Rxn<LiveMatchScore>();
  final globalScore = Rxn<LiveGlobalScore>();

  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    fetch();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => fetch());
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  Future<void> fetch() async {
    if (matches.isEmpty && globalScore.value == null) {
      isLoading.value = true;
    }
    errorMessage.value = null;

    try {
      if (mode == LiveScoreMode.duel) {
        await _fetchDuels();
      } else {
        await _fetchGlobal();
      }
    } catch (e) {
      _logger.e('Live score fetch failed: $e');
      errorMessage.value = 'Could not load live scores'.tr;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _fetchGlobal() async {
    final response = await ApiClient().get(
      url: '${ApiUrl.baseUrl}${ApiUrl.liveGlobal}',
      showResult: true,
    );
    if (response.statusCode == 200) {
      isForbidden.value = false;
      globalScore.value =
          LiveGlobalScore.fromJson(response.body as Map<String, dynamic>);
    } else {
      _handleError(response);
    }
  }

  Future<void> _fetchDuels() async {
    var ids = matchId != null ? [matchId!] : (_resolvedMatchIds ?? <String>[]);
    if (ids.isEmpty) {
      ids = await _resolveMatchIds();
      if (ids.isNotEmpty) _resolvedMatchIds = ids; // an empty lookup is retried
    }
    if (ids.isEmpty) {
      // No duel this match day: the screen shows "no live match".
      matches.clear();
      matchScore.value = null;
      return;
    }

    final responses = await Future.wait([
      for (final id in ids)
        ApiClient().get(
          url: '${ApiUrl.baseUrl}${ApiUrl.liveMatch(id)}',
          showResult: true,
        ),
    ]);

    final loaded = <LiveMatchScore>[];
    for (final response in responses) {
      if (response.statusCode == 200 && response.body is Map) {
        loaded.add(
          LiveMatchScore.fromJson(response.body as Map<String, dynamic>),
        );
      } else if (loaded.isEmpty && response == responses.first) {
        _handleError(response);
        return;
      }
    }
    isForbidden.value = false;
    matches.value = loaded;
    matchScore.value = loaded.isEmpty ? null : loaded.first;
  }

  void _handleError(dynamic response) {
    if (response.statusCode == 403) {
      // Only the premium refusal shows the paywall (QA 24/09 #6: a subscribed
      // user saw the lock screen).
      final detail =
          response.body is Map ? response.body['detail']?.toString() : null;
      if (detail == null || detail.toLowerCase().contains('premium')) {
        isForbidden.value = true;
      } else {
        isForbidden.value = false;
        errorMessage.value = detail.tr;
      }
    } else {
      errorMessage.value =
          (response.body is Map ? response.body['detail'] : null) ??
          'Could not load live scores'.tr;
    }
  }

  /// Every duel of this match day in this league, the user's own first.
  Future<List<String>> _resolveMatchIds() async {
    final league = leagueId;
    final day = matchDay;
    if (league == null || day == null || day <= 0) return [];
    try {
      final endpoint = isPrivate
          ? ApiUrl.privateMatchResult(league, day)
          : ApiUrl.publicMatchResult(league, day);
      final response =
          await ApiClient().get(url: '${ApiUrl.baseUrl}$endpoint');
      if (response.statusCode != 200) return [];
      final result = MatchResultModel.fromJson(response.body);
      leagueName.value = result.leagueName;
      final me =
          int.tryParse(await SharedPrefsHelper.getString(AppConstants.userId));
      final mine = <String>[];
      final others = <String>[];
      for (final pair in result.pairs) {
        final id = pair.matchObjectId;
        if (id == null) continue;
        final isMine =
            me != null && (pair.playerAId == me || pair.playerBId == me);
        if (isMine) myTeamIsHome[id] = pair.playerAId == me;
        (isMine ? mine : others).add(id);
      }
      return [...mine, ...others];
    } catch (e) {
      _logger.e('Live match lookup failed: $e');
    }
    return [];
  }
}
