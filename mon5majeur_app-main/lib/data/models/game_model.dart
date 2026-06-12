// Create this new file: lib/data/models/game_model.dart

class Game {
  final int id;
  final String homeTeam;
  final String homeTeamId;
  final String awayTeam;
  final String awayTeamId;
  final String gameTime;
  final String status;
  final String venue;
  final String timezone;
  final String datetimeUtc;

  Game({
    required this.id,
    required this.homeTeam,
    required this.homeTeamId,
    required this.awayTeam,
    required this.awayTeamId,
    required this.gameTime,
    required this.status,
    required this.venue,
    required this.timezone,
    required this.datetimeUtc,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] ?? 0,
      homeTeam: json['home_team'] ?? '',
      homeTeamId: json['home_team_id'] ?? '',
      awayTeam: json['away_team'] ?? '',
      awayTeamId: json['away_team_id'] ?? '',
      gameTime: json['game_time'] ?? '',
      status: json['status'] ?? '',
      venue: json['venue'] ?? '',
      timezone: json['timezone'] ?? '',
      datetimeUtc: json['datetime_utc'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'home_team': homeTeam,
      'home_team_id': homeTeamId,
      'away_team': awayTeam,
      'away_team_id': awayTeamId,
      'game_time': gameTime,
      'status': status,
      'venue': venue,
      'timezone': timezone,
      'datetime_utc': datetimeUtc,
    };
  }
}
