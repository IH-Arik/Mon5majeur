// lib/data/models/match_result_model.dart
class MatchResultModel {
  final int id;
  final int leagueId;
  final String leagueName;
  final int matchDay;
  final String matchType;
  final String matchDate;
  final String status;
  final List<PlayerScore> playerScores;
  final List<MatchPair> pairs;
  final String createdAt;

  MatchResultModel({
    required this.id,
    required this.leagueId,
    required this.leagueName,
    required this.matchDay,
    required this.matchType,
    required this.matchDate,
    required this.status,
    required this.playerScores,
    required this.pairs,
    required this.createdAt,
  });

  factory MatchResultModel.fromJson(Map<String, dynamic> json) {
    return MatchResultModel(
      id: json['id'] ?? 0,
      leagueId: json['league_id'] ?? 0,
      leagueName: json['league_name'] ?? '',
      matchDay: json['match_day'] ?? 0,
      matchType: json['match_type'] ?? '',
      matchDate: json['match_date'] ?? '',
      status: json['status'] ?? '',
      playerScores:
          (json['player_scores'] as List?)
              ?.map((e) => PlayerScore.fromJson(e))
              .toList() ??
          [],
      pairs:
          (json['pairs'] as List?)
              ?.map((e) => MatchPair.fromJson(e))
              .toList() ??
          [],
      createdAt: json['created_at'] ?? '',
    );
  }
}

class PlayerScore {
  final int playerId;
  final String teamName;
  final String username;
  final int totalPoints;
  final List<PlayerSelection> selection;

  PlayerScore({
    required this.playerId,
    required this.teamName,
    required this.username,
    required this.totalPoints,
    required this.selection,
  });

  factory PlayerScore.fromJson(Map<String, dynamic> json) {
    return PlayerScore(
      playerId: json['player_id'] ?? 0,
      teamName: json['team_name'] ?? '',
      username: json['username'] ?? '',
      // score_full_selection() returns round(x, 2) which is always a float
      // in Python (e.g. 16.0), even for whole numbers — coerce via num.
      totalPoints: (json['total_points'] as num?)?.round() ?? 0,
      selection:
          (json['selection'] as List?)
              ?.map((e) => PlayerSelection.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class PlayerSelection {
  final String id;
  final String name;
  final String position;
  final int score;

  PlayerSelection({
    required this.id,
    required this.name,
    required this.position,
    required this.score,
  });

  factory PlayerSelection.fromJson(Map<String, dynamic> json) {
    return PlayerSelection(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      position: json['position'] ?? '',
      // Backend score fields are floats (e.g. 16.0) — parsing straight into
      // an int throws (double is not a subtype of int); coerce via num.
      score: (json['score'] as num?)?.round() ?? 0,
    );
  }
}

class MatchPair {
  final int playerAId;
  final String playerAName;
  final int playerBId;
  final String playerBName;
  final int scoreA;
  final int scoreB;
  // Mongo LeagueMatch id — needed to call GET /live/match/{id}.
  final String? matchObjectId;

  MatchPair({
    required this.playerAId,
    required this.playerAName,
    required this.playerBId,
    required this.playerBName,
    required this.scoreA,
    required this.scoreB,
    this.matchObjectId,
  });

  factory MatchPair.fromJson(Map<String, dynamic> json) {
    return MatchPair(
      playerAId: json['player_a_id'] ?? 0,
      playerAName: json['player_a_name'] ?? '',
      playerBId: json['player_b_id'] ?? 0,
      playerBName: json['player_b_name'] ?? '',
      scoreA: (json['score_a'] as num?)?.round() ?? 0,
      scoreB: (json['score_b'] as num?)?.round() ?? 0,
      matchObjectId: json['match_object_id'],
    );
  }
}
