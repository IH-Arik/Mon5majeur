// lib/data/models/my_match_today_model.dart
class MyMatchTodayModel {
  final int id;
  final int leagueId;
  final String leagueName;
  final String leagueLogo; // logo chosen at league creation
  final int matchDay;
  final String matchType;
  final String matchDate;
  final String status;
  final List<dynamic> playerScores;
  final List<MatchPair> pairs;
  final String createdAt;
  // Backend-gated Night's Results state (spec: only LIVE or FINAL are shown).
  final bool isLiveForUser;
  final bool resultAvailable;
  // Score paywall (QA 15/09/2026 item 4) — enforced by the API, which sends
  // zeros while true; the UI must show "Score dispo à 9h" instead.
  final bool scoresHidden;
  // Where tapping the card goes (QA 24/09 #3): the league itself, on the
  // match day it is currently on (the card may show an older result).
  final bool isPrivate;
  final int? leagueCurrentMatchDay;

  MyMatchTodayModel({
    required this.id,
    required this.leagueId,
    required this.leagueName,
    this.leagueLogo = '',
    required this.matchDay,
    required this.matchType,
    required this.matchDate,
    required this.status,
    required this.playerScores,
    required this.pairs,
    required this.createdAt,
    this.isLiveForUser = false,
    this.resultAvailable = false,
    this.scoresHidden = false,
    this.isPrivate = true,
    this.leagueCurrentMatchDay,
  });

  factory MyMatchTodayModel.fromJson(Map<String, dynamic> json) {
    return MyMatchTodayModel(
      id: json['id'] ?? 0,
      leagueId: json['league_id'] ?? 0,
      leagueName: json['league_name'] ?? '',
      leagueLogo: json['league_logo'] ?? '',
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
      isLiveForUser: json['is_live_for_user'] ?? false,
      resultAvailable: json['result_available'] ?? false,
      scoresHidden: json['scores_hidden'] ?? false,
      isPrivate: json['is_private'] ?? true,
      leagueCurrentMatchDay: json['league_current_match_day'],
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
      'is_live_for_user': isLiveForUser,
      'result_available': resultAvailable,
      'scores_hidden': scoresHidden,
      'is_private': isPrivate,
      'league_current_match_day': leagueCurrentMatchDay,
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
  final String? playerALogo;
  final String? playerBLogo;
  final int scoreA;
  final int scoreB;
  // Mongo LeagueMatch id — needed to call GET /live/match/{id}.
  final String? matchObjectId;

  MatchPair({
    this.playerAId,
    this.playerAName,
    this.playerBId,
    this.playerBName,
    this.playerALogo,
    this.playerBLogo,
    required this.scoreA,
    required this.scoreB,
    this.matchObjectId,
  });

  factory MatchPair.fromJson(Map<String, dynamic> json) {
    return MatchPair(
      playerAId: json['player_a_id'],
      playerAName: json['player_a_name'],
      playerBId: json['player_b_id'],
      playerBName: json['player_b_name'],
      playerALogo: json['player_a_logo'],
      playerBLogo: json['player_b_logo'],
      // Backend sends these as floats (e.g. 16.0) even for whole scores —
      // parsing directly into an int field throws (double is not a subtype
      // of int), silently swallowed by the caller's try/catch, which left
      // the whole match list stuck empty. Parse via num, then round.
      scoreA: (json['score_a'] as num?)?.round() ?? 0,
      scoreB: (json['score_b'] as num?)?.round() ?? 0,
      matchObjectId: json['match_object_id'],
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
      'match_object_id': matchObjectId,
    };
  }

  bool get hasPlayerB => playerBId != null && playerBName != null;
}
