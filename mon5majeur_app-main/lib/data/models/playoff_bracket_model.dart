// lib/data/models/playoff_bracket_model.dart
class PlayoffBracketModel {
  final int leagueId;
  final String leagueName;
  final List<PlayoffRound> rounds;

  PlayoffBracketModel({
    required this.leagueId,
    required this.leagueName,
    required this.rounds,
  });

  factory PlayoffBracketModel.fromJson(Map<String, dynamic> json) {
    return PlayoffBracketModel(
      leagueId: json['league_id'] ?? 0,
      leagueName: json['league_name'] ?? '',
      rounds:
          (json['rounds'] as List?)
              ?.map((e) => PlayoffRound.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class PlayoffRound {
  final String roundType;
  final String roundName;
  final List<PlayoffSeries> series;

  PlayoffRound({
    required this.roundType,
    required this.roundName,
    required this.series,
  });

  factory PlayoffRound.fromJson(Map<String, dynamic> json) {
    return PlayoffRound(
      roundType: json['round_type'] ?? '',
      roundName: json['round_name'] ?? '',
      series:
          (json['series'] as List?)
              ?.map((e) => PlayoffSeries.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class PlayoffSeries {
  final int seriesIndex;
  final String round;
  final int teamAId;
  final String teamAName;
  final int teamBId;
  final String teamBName;
  final int winsA;
  final int winsB;
  final List<PlayoffGame> games;
  final int? winnerId;
  final String? winnerName;
  final bool isComplete;

  PlayoffSeries({
    required this.seriesIndex,
    required this.round,
    required this.teamAId,
    required this.teamAName,
    required this.teamBId,
    required this.teamBName,
    required this.winsA,
    required this.winsB,
    required this.games,
    this.winnerId,
    this.winnerName,
    required this.isComplete,
  });

  factory PlayoffSeries.fromJson(Map<String, dynamic> json) {
    return PlayoffSeries(
      seriesIndex: json['series_index'] ?? 0,
      round: json['round'] ?? '',
      teamAId: json['team_a_id'] ?? 0,
      teamAName: json['team_a_name'] ?? '',
      teamBId: json['team_b_id'] ?? 0,
      teamBName: json['team_b_name'] ?? '',
      winsA: json['wins_a'] ?? 0,
      winsB: json['wins_b'] ?? 0,
      games:
          (json['games'] as List?)
              ?.map((e) => PlayoffGame.fromJson(e))
              .toList() ??
          [],
      winnerId: json['winner_id'],
      winnerName: json['winner_name'],
      isComplete: json['is_complete'] ?? false,
    );
  }
}

class PlayoffGame {
  final int gameNumber;
  final int scoreA;
  final int scoreB;
  final String winnerTeam;

  PlayoffGame({
    required this.gameNumber,
    required this.scoreA,
    required this.scoreB,
    required this.winnerTeam,
  });

  factory PlayoffGame.fromJson(Map<String, dynamic> json) {
    return PlayoffGame(
      gameNumber: json['game_number'] ?? 0,
      // Backend score fields are floats (e.g. 16.0) — parsing straight into
      // an int throws (double is not a subtype of int); coerce via num.
      scoreA: (json['score_a'] as num?)?.round() ?? 0,
      scoreB: (json['score_b'] as num?)?.round() ?? 0,
      winnerTeam: json['winner_team'] ?? '',
    );
  }
}
