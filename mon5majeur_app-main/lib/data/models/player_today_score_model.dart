class PlayerTodayScore {
  final String id;
  final String name;
  final String position;
  final String team;
  final int score;

  PlayerTodayScore({
    required this.id,
    required this.name,
    required this.position,
    required this.team,
    required this.score,
  });

  factory PlayerTodayScore.fromJson(Map<String, dynamic> json) {
    return PlayerTodayScore(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      position: json['position'] ?? '',
      team: json['team'] ?? '',
      score: json['score'] ?? 0,
    );
  }
}
