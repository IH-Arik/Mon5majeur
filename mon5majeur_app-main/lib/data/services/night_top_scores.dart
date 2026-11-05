import 'package:flutter/foundation.dart';

import '../models/player_today_score_model.dart';
import 'api_service.dart';
import 'api_url.dart';

/// Gold / silver / bronze for the best fantasy scores of a night, over ALL the
/// NBA players (the same ranking as "Scores fantasy du jour").
///
/// The server ranks the night asked for (`nba_date`) and answers with the
/// night it really used. A server that does not know the parameter answers for
/// the last published night, or without that field: the answer is then
/// ignored, so a night is never given another night's medals.
class NightTopScores {
  NightTopScores._();

  static const Duration _ttl = Duration(minutes: 10);

  static final Map<String, (Map<String, int>, DateTime)> _cache = {};
  static final Map<String, Future<Map<String, int>>> _running = {};

  /// The request itself (status code and decoded body); tests replace it.
  @visibleForTesting
  static Future<(int?, dynamic)> Function(String night) request = _request;

  @visibleForTesting
  static void reset() {
    _cache.clear();
    _running.clear();
    request = _request;
  }

  static Future<(int?, dynamic)> _request(String night) async {
    final resp = await ApiClient().get(
      url: '${ApiUrl.baseUrl}${ApiUrl.playersTodayScores}?nba_date=$night',
    );
    return (resp.statusCode, resp.body);
  }

  /// Player id -> medal rank (1 gold, 2 silver, 3 bronze) for the night
  /// [date] (yyyy-mm-dd, or a longer ISO date): empty when unknown, not
  /// published yet, or on any error.
  static Future<Map<String, int>> forDate(String? date) {
    if (date == null || date.length < 10) return Future.value(const {});
    final night = date.substring(0, 10);
    final hit = _cache[night];
    if (hit != null && DateTime.now().difference(hit.$2) < _ttl) {
      return Future.value(hit.$1);
    }
    return _running[night] ??= _fetch(night).whenComplete(() {
      _running.remove(night);
    });
  }

  static Future<Map<String, int>> _fetch(String night) async {
    try {
      final (status, body) = await request(night);
      if (status == 200 && body is Map) {
        final answered = body['nba_date'];
        if (answered is! String || !answered.startsWith(night)) {
          return const {};
        }
        final results = body['results'] as List? ?? const [];
        final players = results
            .map((e) => PlayerTodayScore.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        final medals = medalRanks(players);
        // An empty answer (night not published yet) is not kept: asking again
        // after the 09:00 publication must reach the server.
        if (medals.isNotEmpty) _cache[night] = (medals, DateTime.now());
        return medals;
      }
    } catch (_) {}
    return const {};
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
