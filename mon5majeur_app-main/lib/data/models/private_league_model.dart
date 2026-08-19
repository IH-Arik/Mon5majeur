// lib/data/models/private_league_model.dart
class PrivateLeagueModel {
  final int? id;
  final List<TeamInfo> teams;
  final int currentMatchDay; // Add this field
  final int currentWeek;
  final int? rank;
  final String leagueName;
  final String leagueDescription;
  final String leagueLogo;
  final String teamBudget;
  final String maxTeamNumber;
  final String? joinCode;
  final String? createdAt;
  final String? startDate;
  final bool? isReady;
  final bool? isStarted;
  final bool? isActive;
  final int? creator;
  // Per-user "today" lineup validation state (My Leagues launch spec).
  final bool lineupSubmitted;
  final int? lockInSeconds;

  PrivateLeagueModel({
    this.id,
    required this.teams,
    this.currentMatchDay = 0, // Add this with default value
    this.currentWeek = 0,
    this.rank,
    required this.leagueName,
    required this.leagueDescription,
    required this.leagueLogo,
    required this.teamBudget,
    required this.maxTeamNumber,
    this.joinCode,
    this.createdAt,
    this.startDate,
    this.isReady,
    this.isStarted,
    this.isActive,
    this.creator,
    this.lineupSubmitted = false,
    this.lockInSeconds,
  });

  // To JSON - for API request (create/update)
  Map<String, dynamic> toJson() {
    return {
      'leauge_name': leagueName,
      'leauge_logo': leagueLogo,
      'leauge_description': leagueDescription,
      'team_budget': teamBudget,
      'max_team_number': maxTeamNumber,
    };
  }

  // From JSON - for API response
  factory PrivateLeagueModel.fromJson(Map<String, dynamic> json) {
    return PrivateLeagueModel(
      id: json['id'],
      teams:
          (json['teams'] as List?)
              ?.map((team) => TeamInfo.fromJson(team))
              .toList() ??
          [],
      currentMatchDay: json['current_match_day'] ?? 0, // Add this line
      currentWeek: json['current_week'] ?? 0,
      rank: json['rank'],
      leagueName: json['leauge_name'] ?? '',
      leagueDescription: json['leauge_description'] ?? '',
      leagueLogo: json['leauge_logo'] ?? '',
      teamBudget: json['team_budget'] ?? '',
      maxTeamNumber: json['max_team_number'] ?? '',
      joinCode: json['join_code'],
      createdAt: json['created_at'],
      startDate: json['start_date'],
      isReady: json['is_ready'],
      isStarted: json['is_started'],
      isActive: json['is_active'],
      creator: json['creator'],
      lineupSubmitted: json['lineup_submitted'] ?? false,
      lockInSeconds: json['lock_in_seconds'],
    );
  }

  @override
  String toString() {
    return 'PrivateLeagueModel(id: $id, leagueName: $leagueName, joinCode: $joinCode, teams: ${teams.length})';
  }
}

class TeamInfo {
  final int teamId;
  final String teamName;
  final String teamLogo;

  TeamInfo({
    required this.teamId,
    required this.teamName,
    required this.teamLogo,
  });

  factory TeamInfo.fromJson(Map<String, dynamic> json) {
    return TeamInfo(
      teamId: json['team_id'] ?? 0,
      teamName: json['team_name'] ?? '',
      teamLogo: json['team_logo'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'team_id': teamId, 'team_name': teamName, 'team_logo': teamLogo};
  }

  @override
  String toString() {
    return 'TeamInfo(teamId: $teamId, teamName: $teamName)';
  }
}

// WebSocket Event Models
class WebSocketLeagueEvent {
  final String type;
  final String event;
  final WebSocketPayload payload;

  WebSocketLeagueEvent({
    required this.type,
    required this.event,
    required this.payload,
  });

  factory WebSocketLeagueEvent.fromJson(Map<String, dynamic> json) {
    return WebSocketLeagueEvent(
      type: json['type'] ?? '',
      event: json['event'] ?? '',
      payload: WebSocketPayload.fromJson(json['payload'] ?? {}),
    );
  }
}

class WebSocketPayload {
  final String? user;
  final int? teamId;
  final String? teamName;
  final String? teamLogo;
  final String? message; // Add this for league_started event

  WebSocketPayload({
    this.user,
    this.teamId,
    this.teamName,
    this.teamLogo,
    this.message,
  });

  factory WebSocketPayload.fromJson(Map<String, dynamic> json) {
    return WebSocketPayload(
      user: json['user'],
      teamId: json['team_id'],
      teamName: json['team_name'],
      teamLogo: json['team_logo'],
      message: json['message'],
    );
  }
}

// League Logo Choices
/// Dedicated league-logo pool (QA 08/08/2026 item 8) — distinct from the
/// player jersey mascots and from the personal team-logo picker
/// (TeamLogoChoices in profile_model.dart), which is a separate feature.
class LeagueLogoChoices {
  static const String flamingBall = 'league_flaming_ball';
  static const String cap = 'league_cap';
  static const String yeti = 'league_yeti';
  static const String lion = 'league_lion';
  static const String ball = 'league_ball';
  static const String shark = 'league_shark';
  static const String snake = 'league_snake';

  static const List<String> all = [
    flamingBall, cap, yeti, lion, ball, shark, snake,
  ];

  static String getLeagueLogoByIndex(int index) {
    if (index < 0 || index >= all.length) return flamingBall;
    return all[index];
  }
}
