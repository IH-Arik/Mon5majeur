import '../models/player_today_score_model.dart';
import 'api_service.dart';
import 'api_url.dart';

/// Gold / silver / bronze for the best fantasy scores of the night, over ALL
/// the NBA players (the same ranking as "Scores fantasy du jour").
///
/// The endpoint has no date: it only answers for the LAST PUBLISHED night, so
/// the medals are only valid for that night. Callers must only ask for them
/// when the night on screen is the latest one. Once the server takes a night
/// date, [latest] is the only place to change.
class NightTopScores {
  NightTopScores._();

  static const Duration _ttl = Duration(minutes: 10);

  static Map<String, int>? _cache;
  static DateTime? _fetchedAt;
  static Future<Map<String, int>>? _running;

  /// Player id -> medal rank (1 gold, 2 silver, 3 bronze) for the last
  /// published night. Empty when unknown or on any error: no medals then.
  static Future<Map<String, int>> latest() {
    final at = _fetchedAt;
    if (_cache != null && at != null && DateTime.now().difference(at) < _ttl) {
      return Future.value(_cache);
    }
    return _running ??= _fetch().whenComplete(() => _running = null);
  }

  static Future<Map<String, int>> _fetch() async {
    try {
      final resp = await ApiClient().get(
        url: ApiUrl.baseUrl + ApiUrl.playersTodayScores,
      );
      if (resp.statusCode == 200 && resp.body is Map) {
        final results = resp.body['results'] as List? ?? const [];
        final players = results
            .map((e) => PlayerTodayScore.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _cache = medalRanks(players);
        _fetchedAt = DateTime.now();
        return _cache!;
      }
    } catch (_) {}
    return const {};
  }

  static String? _latestDate;
  static DateTime? _dateFetchedAt;
  static Future<String?>? _runningDate;

  /// The top 3 for the night [date] (yyyy-mm-dd, a duel's match date): the
  /// medals only when it is the last published night, else empty. The server
  /// takes no date for the scores, so no other night can be ranked.
  static Future<Map<String, int>> forDate(String? date) async {
    if (date == null || date.length < 10) return const {};
    final latest = await _latestNight();
    if (latest == null || latest != date.substring(0, 10)) return const {};
    return NightTopScores.latest();
  }

  /// Date of the last published night: the World League result at offset 0.
  static Future<String?> _latestNight() {
    final at = _dateFetchedAt;
    if (_latestDate != null &&
        at != null &&
        DateTime.now().difference(at) < _ttl) {
      return Future.value(_latestDate);
    }
    return _runningDate ??= _fetchNight().whenComplete(() => _runningDate = null);
  }

  static Future<String?> _fetchNight() async {
    try {
      final resp = await ApiClient().get(
        url: '${ApiUrl.baseUrl}${ApiUrl.globalPublishedResult}?offset=0',
      );
      if (resp.statusCode == 200 && resp.body is Map) {
        final d = resp.body['match_date'];
        if (d is String && d.length >= 10) {
          _latestDate = d.substring(0, 10);
          _dateFetchedAt = DateTime.now();
          return _latestDate;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Same ranking as the "Scores fantasy du jour" list: highest score first,
  /// equal scores share a rank. Only ranks 1 to 3 with a positive score get a
  /// medal, so a tie for 1st gives two golds and no silver.
  static Map<String, int> medalRanks(List<PlayerTodayScore> players) {
    final sorted = [...players]..sort((a, b) => b.score.compareTo(a.score));
    final medals = <String, int>{};
    var rank = 0;
    int? previous;
    for (var i = 0; i < sorted.length; i++) {
      if (sorted[i].score != previous) {
        rank = i + 1;
        previous = sorted[i].score;
      }
      if (rank > 3) break;
      if (sorted[i].score > 0 && sorted[i].id.isNotEmpty) {
        medals[sorted[i].id] = rank;
      }
    }
    return medals;
  }
}
