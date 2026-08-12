// lib/data/models/profile_stats_model.dart
class ProfileStatsModel {
  final String teamName;
  final String teamLogo;
  final int sinceYear;
  final int wins;
  final int losses;
  final int noMatch;
  final int totalMatches;
  final int regularSeasonWins;
  final int leagueVictories;
  // Trophies (QA 08/08/2026 item 6): Gold=duel league win,
  // Silver=Global League weekly #1, Diamond=Global League monthly #1,
  // Orange L=last place in a completed duel league.
  final int trophyGold;
  final int trophySilver;
  final int trophyDiamond;
  final int trophyOrangeL;
  final double avgPointsScored;
  final double avgPointsConceded;

  ProfileStatsModel({
    required this.teamName,
    required this.teamLogo,
    required this.sinceYear,
    required this.wins,
    required this.losses,
    required this.noMatch,
    required this.totalMatches,
    required this.regularSeasonWins,
    required this.leagueVictories,
    required this.trophyGold,
    required this.trophySilver,
    required this.trophyDiamond,
    required this.trophyOrangeL,
    required this.avgPointsScored,
    required this.avgPointsConceded,
  });

  factory ProfileStatsModel.fromJson(Map<String, dynamic> json) {
    return ProfileStatsModel(
      teamName: json['team_name'] ?? '',
      teamLogo: json['team_logo'] ?? '',
      sinceYear: (json['since_year'] as num?)?.toInt() ?? 0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      noMatch: (json['no_match'] as num?)?.toInt() ?? 0,
      totalMatches: (json['total_matches'] as num?)?.toInt() ?? 0,
      regularSeasonWins: (json['regular_season_wins'] as num?)?.toInt() ?? 0,
      leagueVictories: (json['league_victories'] as num?)?.toInt() ?? 0,
      trophyGold: (json['trophy_gold'] as num?)?.toInt() ?? 0,
      trophySilver: (json['trophy_silver'] as num?)?.toInt() ?? 0,
      trophyDiamond: (json['trophy_diamond'] as num?)?.toInt() ?? 0,
      trophyOrangeL: (json['trophy_orange_l'] as num?)?.toInt() ?? 0,
      avgPointsScored: (json['avg_points_scored'] as num?)?.toDouble() ?? 0.0,
      avgPointsConceded:
          (json['avg_points_conceded'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static ProfileStatsModel empty() => ProfileStatsModel(
        teamName: '',
        teamLogo: '',
        sinceYear: DateTime.now().year,
        wins: 0,
        losses: 0,
        noMatch: 0,
        totalMatches: 0,
        regularSeasonWins: 0,
        leagueVictories: 0,
        trophyGold: 0,
        trophySilver: 0,
        trophyDiamond: 0,
        trophyOrangeL: 0,
        avgPointsScored: 0.0,
        avgPointsConceded: 0.0,
      );
}
