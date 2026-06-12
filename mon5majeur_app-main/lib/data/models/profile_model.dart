// lib/data/models/profile_model.dart
class UserProfileModel {
  final int? id;
  final String teamLogo;
  final String teamName;
  final String favoriteTeam;
  final String dateOfBirth;
  final bool acceptTermsConditions;
  final bool recivedNotifications;
  final String? createdAt;
  final String? updatedAt;
  final int? user;

  UserProfileModel({
    this.id,
    required this.teamLogo,
    required this.teamName,
    required this.favoriteTeam,
    required this.dateOfBirth,
    required this.acceptTermsConditions,
    required this.recivedNotifications,
    this.createdAt,
    this.updatedAt,
    this.user,
  });

  // To JSON - for API request
  Map<String, dynamic> toJson() {
    return {
      'team_logo': teamLogo,
      'team_name': teamName,
      'favorite_team': favoriteTeam,
      'date_of_birth': dateOfBirth,
      'accept_terms_conditions': acceptTermsConditions,
      'recived_notifications': recivedNotifications,
    };
  }

  // From JSON - for API response
  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'],
      teamLogo: json['team_logo'] ?? '',
      teamName: json['team_name'] ?? '',
      favoriteTeam: json['favorite_team'] ?? '',
      dateOfBirth: json['date_of_birth'] ?? '',
      acceptTermsConditions: json['accept_terms_conditions'] ?? false,
      recivedNotifications: json['recived_notifications'] ?? false,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      user: json['user'],
    );
  }

  @override
  String toString() {
    return 'UserProfileModel(id: $id, teamName: $teamName, favoriteTeam: $favoriteTeam)';
  }
}

// Team Logo Choices (matching backend)
class TeamLogoChoices {
  static const String parisFc = 'paris_fc';
  static const String lakers = 'lakers';
  static const String bostonCeltics = 'boston_celtics';
  static const String chicagoBulls = 'chicago_bulls';
  static const String atlantaHawks = 'atlanta_hawks';
  static const String goldenStateWarriors = 'golden_state_warriors';

  // Map index to team logo value
  static String getTeamLogoByIndex(int index) {
    switch (index) {
      case 0:
        return parisFc;
      case 1:
        return lakers;
      case 2:
        return bostonCeltics;
      case 3:
        return chicagoBulls;
      case 4:
        return atlantaHawks;
      case 5:
        return goldenStateWarriors;
      default:
        return parisFc;
    }
  }
}
