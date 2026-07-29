// lib/data/models/standings_model.dart
class StandingsModel {
  final int leagueId;
  final String leagueName;
  final int playoffSpots;
  final List<StandingsEntry> teams;

  StandingsModel({
    required this.leagueId,
    required this.leagueName,
    required this.playoffSpots,
    required this.teams,
  });

  factory StandingsModel.fromJson(Map<String, dynamic> json) {
    return StandingsModel(
      leagueId: json['league_id'] ?? 0,
      leagueName: json['league_name'] ?? '',
      playoffSpots: json['playoff_spots'] ?? 4,
      teams:
          (json['teams'] as List?)
              ?.map((e) => StandingsEntry.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class StandingsEntry {
  final int rank;
  final int teamId;
  final String teamName;
  final int wins;
  final int losses;
  final double pointsFor;
  final double pointsAgainst;
  final double differential;
  final bool isPlayoffSpot;

  StandingsEntry({
    required this.rank,
    required this.teamId,
    required this.teamName,
    required this.wins,
    required this.losses,
    required this.pointsFor,
    required this.pointsAgainst,
    required this.differential,
    required this.isPlayoffSpot,
  });

  factory StandingsEntry.fromJson(Map<String, dynamic> json) {
    return StandingsEntry(
      rank: json['rank'] ?? 0,
      teamId: json['team_id'] ?? 0,
      teamName: json['team_name'] ?? '',
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      pointsFor: (json['points_for'] ?? 0).toDouble(),
      pointsAgainst: (json['points_against'] ?? 0).toDouble(),
      differential: (json['differential'] ?? 0).toDouble(),
      isPlayoffSpot: json['is_playoff_spot'] ?? false,
    );
  }
}
