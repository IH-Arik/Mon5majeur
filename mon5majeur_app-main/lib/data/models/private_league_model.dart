// lib/data/models/private_league_model.dart
class PrivateLeagueModel {
  final int? id;
  final List<TeamInfo> teams;
  final int currentMatchDay; // Add this field
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

  PrivateLeagueModel({
    this.id,
    required this.teams,
    this.currentMatchDay = 0, // Add this with default value
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
class LeagueLogoChoices {
  static const String atlantaHawks = 'atlanta_hawks';
  static const String bostonCeltics = 'boston_celtics';
  static const String chicagoBulls = 'chicago_bulls';
  static const String lakers = 'lakers';
  static const String goldenStateWarriors = 'golden_state_warriors';
  static const String parisFc = 'paris_fc';

  static String getLeagueLogoByIndex(int index) {
    switch (index) {
      case 0:
        return atlantaHawks;
      case 1:
        return bostonCeltics;
      case 2:
        return chicagoBulls;
      case 3:
        return lakers;
      case 4:
        return goldenStateWarriors;
      case 5:
        return parisFc;
      default:
        return atlantaHawks;
    }
  }
}
