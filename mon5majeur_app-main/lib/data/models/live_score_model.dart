// lib/data/models/live_score_model.dart
// Matches backend LivePlayerScore / LiveMatchScore / LiveGlobalScore
// (app/modules/live_scores/schema.py).

class LivePlayerScore {
  final String playerId;
  final String fullName;
  final String? position;
  final String? teamName;
  final String slot;

  final int points;
  final int rebounds;
  final int assists;
  final int steals;
  final int blocks;
  final int turnovers;
  final int minutesPlayed;

  final double fantasyScoreLive;
  final bool isFinalized;
  // False only for the dropped 6th-Man score (spec §4.4: top 5 of 6 count).
  final bool isCounted;

  LivePlayerScore({
    required this.playerId,
    required this.fullName,
    this.position,
    this.teamName,
    required this.slot,
    required this.points,
    required this.rebounds,
    required this.assists,
    required this.steals,
    required this.blocks,
    required this.turnovers,
    required this.minutesPlayed,
    required this.fantasyScoreLive,
    required this.isFinalized,
    required this.isCounted,
  });

  factory LivePlayerScore.fromJson(Map<String, dynamic> json) {
    return LivePlayerScore(
      playerId: json['player_id']?.toString() ?? '',
      fullName: json['full_name'] ?? '',
      position: json['position'],
      teamName: json['team_name'],
      slot: json['slot'] ?? 'STARTER',
      points: (json['points'] as num?)?.toInt() ?? 0,
      rebounds: (json['rebounds'] as num?)?.toInt() ?? 0,
      assists: (json['assists'] as num?)?.toInt() ?? 0,
      steals: (json['steals'] as num?)?.toInt() ?? 0,
      blocks: (json['blocks'] as num?)?.toInt() ?? 0,
      turnovers: (json['turnovers'] as num?)?.toInt() ?? 0,
      minutesPlayed: (json['minutes_played'] as num?)?.toInt() ?? 0,
      fantasyScoreLive: (json['fantasy_score_live'] as num?)?.toDouble() ?? 0.0,
      isFinalized: json['is_finalized'] as bool? ?? false,
      isCounted: json['is_counted'] as bool? ?? true,
    );
  }

  bool get isSixthMan => slot == 'SIXTH_MAN';
}

class LiveMatchScore {
  final String matchId;
  final String leagueId;
  final String leagueName;
  final String nbaDate;

  final String homeUserId;
  final String awayUserId;
  final String? homeTeamName;
  final String? awayTeamName;

  final double homeScore;
  final double awayScore;
  final String matchStatus;

  final List<LivePlayerScore> homePlayers;
  final List<LivePlayerScore> awayPlayers;

  final bool isStale;
  final DateTime refreshedAt;

  LiveMatchScore({
    required this.matchId,
    required this.leagueId,
    required this.leagueName,
    required this.nbaDate,
    required this.homeUserId,
    required this.awayUserId,
    this.homeTeamName,
    this.awayTeamName,
    required this.homeScore,
    required this.awayScore,
    required this.matchStatus,
    required this.homePlayers,
    required this.awayPlayers,
    required this.isStale,
    required this.refreshedAt,
  });

  factory LiveMatchScore.fromJson(Map<String, dynamic> json) {
    return LiveMatchScore(
      matchId: json['match_id']?.toString() ?? '',
      leagueId: json['league_id']?.toString() ?? '',
      leagueName: json['league_name'] ?? '',
      nbaDate: json['nba_date'] ?? '',
      homeUserId: json['home_user_id']?.toString() ?? '',
      awayUserId: json['away_user_id']?.toString() ?? '',
      homeTeamName: json['home_team_name'],
      awayTeamName: json['away_team_name'],
      homeScore: (json['home_score'] as num?)?.toDouble() ?? 0.0,
      awayScore: (json['away_score'] as num?)?.toDouble() ?? 0.0,
      matchStatus: json['match_status'] ?? 'upcoming',
      homePlayers:
          (json['home_players'] as List<dynamic>?)
              ?.map((e) => LivePlayerScore.fromJson(e))
              .toList() ??
          [],
      awayPlayers:
          (json['away_players'] as List<dynamic>?)
              ?.map((e) => LivePlayerScore.fromJson(e))
              .toList() ??
          [],
      isStale: json['is_stale'] as bool? ?? false,
      refreshedAt:
          DateTime.tryParse(json['refreshed_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class LiveGlobalScore {
  final String leagueId;
  final String leagueName;
  final double totalScore;
  final List<LivePlayerScore> players;
  final bool isStale;
  final DateTime refreshedAt;

  LiveGlobalScore({
    required this.leagueId,
    required this.leagueName,
    required this.totalScore,
    required this.players,
    required this.isStale,
    required this.refreshedAt,
  });

  factory LiveGlobalScore.fromJson(Map<String, dynamic> json) {
    return LiveGlobalScore(
      leagueId: json['league_id']?.toString() ?? '',
      leagueName: json['league_name'] ?? '',
      totalScore: (json['total_score'] as num?)?.toDouble() ?? 0.0,
      players:
          (json['players'] as List<dynamic>?)
              ?.map((e) => LivePlayerScore.fromJson(e))
              .toList() ??
          [],
      isStale: json['is_stale'] as bool? ?? false,
      refreshedAt:
          DateTime.tryParse(json['refreshed_at'] ?? '') ?? DateTime.now(),
    );
  }
}
