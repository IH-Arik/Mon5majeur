import '../../core/constants/api_constants.dart';
import '../../core/local_db/local_db.dart';
import '../models/match_result_model.dart';

/// In-memory cache of the PUBLISHED duel match days (league Results tab).
///
/// Only a complete day enters it, judged from what the server sent (never the
/// phone's clock): `status == "completed"`, scores not paywalled, and no
/// lineup or bonus still hidden for any team. Anything else (loading, error,
/// 404, a day in progress, a hidden score/lineup/bonus, an empty day) is never
/// kept, so the cache can never show a lineup or a bonus earlier than the
/// server would.
///
/// The day is addressed by its stable number (`match_day`), under its league
/// (type + id). It belongs to one account: [bindToCurrentUser] empties it when
/// the signed-in account is not the one that filled it.
class MatchResultCache {
  MatchResultCache._();

  /// Past this age a cached day is shown at once and refreshed silently.
  static const Duration freshness = Duration(minutes: 30);
  static const int maxDaysPerLeague = 30;
  static const int maxLeagues = 10;

  static String? _userId;
  // Map literals keep insertion order: least recently used first.
  static final Map<String, Map<int, CachedMatchResult>> _leagues = {};

  static Future<String?> bindToCurrentUser() async {
    final id = await SharedPrefsHelper.getString(AppConstants.userId);
    if (id.isEmpty) {
      clear();
      return null;
    }
    if (_userId != id) {
      _leagues.clear();
      _userId = id;
    }
    return id;
  }

  /// The server said this day is final and nothing is hidden from this viewer.
  static bool isComplete(MatchResultModel m) =>
      m.status == 'completed' &&
      !m.scoresHidden &&
      m.pairs.isNotEmpty &&
      m.playerScores.isNotEmpty &&
      !m.playerScores.any((p) => p.bonusHidden || p.selectionHidden);

  static CachedMatchResult? get(String league, int day) {
    final days = _leagues.remove(league);
    if (days == null) return null;
    _leagues[league] = days; // most recently used
    return days[day];
  }

  /// Keeps [result] only if it is complete and was fetched for the account the
  /// cache is bound to. A day that is no longer complete is dropped.
  static void put(
    String? userId,
    String league,
    int day,
    MatchResultModel result,
  ) {
    if (userId == null || _userId != userId) return;
    if (!isComplete(result) || result.matchDay != day) {
      _leagues[league]?.remove(day);
      return;
    }
    final days = _leagues.remove(league) ?? <int, CachedMatchResult>{};
    _leagues[league] = days;
    while (_leagues.length > maxLeagues) {
      _leagues.remove(_leagues.keys.first);
    }
    days.remove(day);
    days[day] = CachedMatchResult(result, DateTime.now());
    while (days.length > maxDaysPerLeague) {
      days.remove(days.keys.first);
    }
  }

  static void clear() {
    _leagues.clear();
    _userId = null;
  }

  // For tests of the size limits.
  static int get leagueCount => _leagues.length;
  static int daysFor(String league) => _leagues[league]?.length ?? 0;
}

class CachedMatchResult {
  final MatchResultModel result;
  final DateTime receivedAt;
  const CachedMatchResult(this.result, this.receivedAt);

  bool get isFresh =>
      DateTime.now().difference(receivedAt) < MatchResultCache.freshness;
}
