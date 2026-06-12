// lib/data/models/my_league_model.dart
import 'package:mon5majeur_app/core/custom_assets/assets.gen.dart';
import 'private_league_model.dart';

/// View model for displaying leagues in My Leagues screen
/// Extends PrivateLeagueModel with UI-specific computed properties
class MyLeagueModel {
  final PrivateLeagueModel league;
  final int userRank;
  final int currentMatchday;
  final int currentWeek;
  final String season;
  final LeagueStatus status;
  final bool
  isPrivate; // Added field to distinguish between private and public leagues

  MyLeagueModel({
    required this.league,
    this.userRank = 0,
    this.currentMatchday = 0,
    this.currentWeek = 0,
    this.season = 'Regular Season',
    required this.status,
    this.isPrivate = true, // Default to private
  });

  // Factory constructor to create from PrivateLeagueModel
  factory MyLeagueModel.fromPrivateLeague(
    PrivateLeagueModel league, {
    int? userRank,
    int? matchday,
    int? week,
    String? season,
    bool isPrivate = true, // Added parameter
  }) {
    LeagueStatus status;

    if (league.isStarted == true) {
      status = LeagueStatus.active;
    } else if (league.isReady == true) {
      status = LeagueStatus.ready;
    } else {
      status = LeagueStatus.waiting;
    }

    return MyLeagueModel(
      league: league,
      userRank: userRank ?? 0,
      currentMatchday: matchday ?? 0,
      currentWeek: week ?? 0,
      season: season ?? 'Regular Season',
      status: status,
      isPrivate: isPrivate, // Pass the parameter
    );
  }

  // Getters for easy access
  int get leagueId => league.id ?? 0;
  String get leagueName => league.leagueName;
  String get leagueLogo => league.leagueLogo;
  String get leagueDescription => league.leagueDescription;
  int get totalTeams => league.teams.length;
  int get maxTeams => int.tryParse(league.maxTeamNumber) ?? 0;
  String get joinCode => league.joinCode ?? '';
  List<TeamInfo> get teams => league.teams;
  bool get isUserCreator => false; // TODO: Compare with current user ID
  String get createdAt => league.createdAt ?? '';

  // Helper methods
  bool get isWaiting => status == LeagueStatus.waiting;
  bool get isReady => status == LeagueStatus.ready;
  bool get isActive => status == LeagueStatus.active;

  String get statusText {
    switch (status) {
      case LeagueStatus.waiting:
        return 'Waiting';
      case LeagueStatus.ready:
        return 'Ready';
      case LeagueStatus.active:
        return 'Active';
    }
  }

  // Get league type text
  String get leagueTypeText => isPrivate ? 'Private' : 'Public';

  // Get league logo asset
  AssetGenImage getLeagueLogoAsset() {
    switch (leagueLogo.toLowerCase()) {
      case 'paris_fc':
        return Assets.icons.logo1;
      case 'lakers':
        return Assets.icons.logo2;
      case 'boston_celtics':
        return Assets.icons.logo3;
      case 'chicago_bulls':
        return Assets.icons.logo4;
      case 'atlanta_hawks':
        return Assets.icons.logo5;
      case 'golden_state_warriors':
        return Assets.icons.logo6;
      default:
        return Assets.icons.logo1;
    }
  }

  @override
  String toString() {
    return 'MyLeagueModel(id: $leagueId, name: $leagueName, type: $leagueTypeText, status: $statusText, teams: $totalTeams/$maxTeams)';
  }
}

/// Enum for league status
enum LeagueStatus {
  waiting, // Not started, waiting for players
  ready, // Ready to start
  active, // Currently active/started
}
