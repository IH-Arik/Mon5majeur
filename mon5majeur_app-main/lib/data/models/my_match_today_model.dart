// lib/data/models/my_match_today_model.dart
class MyMatchTodayModel {
  final int id;
  final int leagueId;
  final String leagueName;
  final int matchDay;
  final String matchType;
  final String matchDate;
  final String status;
  final List<dynamic> playerScores;
  final List<MatchPair> pairs;
  final String createdAt;

  MyMatchTodayModel({
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

  factory MyMatchTodayModel.fromJson(Map<String, dynamic> json) {
    return MyMatchTodayModel(
      id: json['id'] ?? 0,
      leagueId: json['league_id'] ?? 0,
      leagueName: json['league_name'] ?? '',
      matchDay: json['match_day'] ?? 0,
      matchType: json['match_type'] ?? '',
      matchDate: json['match_date'] ?? '',
      status: json['status'] ?? '',
      playerScores: json['player_scores'] ?? [],
      pairs:
          (json['pairs'] as List<dynamic>?)
              ?.map((pair) => MatchPair.fromJson(pair))
              .toList() ??
          [],
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'league_id': leagueId,
      'league_name': leagueName,
      'match_day': matchDay,
      'match_type': matchType,
      'match_date': matchDate,
      'status': status,
      'player_scores': playerScores,
      'pairs': pairs.map((pair) => pair.toJson()).toList(),
      'created_at': createdAt,
    };
  }

  // Helper method to get formatted match type
  String get formattedMatchType {
    return matchType
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }
}

class MatchPair {
  final int? playerAId;
  final String? playerAName;
  final int? playerBId;
  final String? playerBName;
  final int scoreA;
  final int scoreB;

  MatchPair({
    this.playerAId,
    this.playerAName,
    this.playerBId,
    this.playerBName,
    required this.scoreA,
    required this.scoreB,
  });

  factory MatchPair.fromJson(Map<String, dynamic> json) {
    return MatchPair(
      playerAId: json['player_a_id'],
      playerAName: json['player_a_name'],
      playerBId: json['player_b_id'],
      playerBName: json['player_b_name'],
      scoreA: json['score_a'] ?? 0,
      scoreB: json['score_b'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'player_a_id': playerAId,
      'player_a_name': playerAName,
      'player_b_id': playerBId,
      'player_b_name': playerBName,
      'score_a': scoreA,
      'score_b': scoreB,
    };
  }

  bool get hasPlayerB => playerBId != null && playerBName != null;
}
