import '../../core/constants/api_constants.dart';
import '../../core/local_db/local_db.dart';

/// In-memory cache of the Global League standings, outside any widget State so
/// it survives leaving and re-entering the screen. One entry per
/// (period, offset). It belongs to one account: [bindToCurrentUser] drops
/// everything whenever the signed-in account is not the one that filled it
/// (sign out, or another account signing in), so a standing is never shown to
/// another account.
class GlobalLeaderboardCache {
  GlobalLeaderboardCache._();

  /// The current week / month (offset 0): refreshed on entry unless younger.
  static const Duration currentPeriodFreshness = Duration(minutes: 2);

  /// Past periods (offset >= 1) barely change: valid for an hour.
  static const Duration pastPeriodFreshness = Duration(hours: 1);

  static String? _userId;
  static final Map<String, CachedLeaderboard> _entries = {};

  static String _key(bool weekly, int offset) =>
      '${weekly ? 'weekly' : 'monthly'}:$offset';

  /// Ties the cache to the signed-in account (read from the stored session)
  /// and empties it if that account changed or there is none. Returns the
  /// account id the caller must pass back to [put], or null if signed out.
  static Future<String?> bindToCurrentUser() async {
    final id = await SharedPrefsHelper.getString(AppConstants.userId);
    if (id.isEmpty) {
      clear();
      return null;
    }
    if (_userId != id) {
      _entries.clear();
      _userId = id;
    }
    return id;
  }

  static CachedLeaderboard? get(bool weekly, int offset) =>
      _entries[_key(weekly, offset)];

  /// Stores a response, but only if it was fetched for the account the cache
  /// is still bound to (a late answer must not land in another account's cache).
  static void put(
    String userId,
    bool weekly,
    int offset,
    Map<String, dynamic> body,
  ) {
    if (_userId != userId) return;
    _entries[_key(weekly, offset)] = CachedLeaderboard(
      body: body,
      receivedAt: DateTime.now(),
    );
  }

  static void clear() {
    _entries.clear();
    _userId = null;
  }
}

class CachedLeaderboard {
  final Map<String, dynamic> body;
  final DateTime receivedAt;
  const CachedLeaderboard({required this.body, required this.receivedAt});

  bool isFresh(int offset) =>
      DateTime.now().difference(receivedAt) <
      (offset == 0
          ? GlobalLeaderboardCache.currentPeriodFreshness
          : GlobalLeaderboardCache.pastPeriodFreshness);
}
