class Player {
  final String? id;
  final String name;
  final String position;
  final String team;
  final String? teamId;
  final String? status;
  final double price;

  // Part 1 — Player Selection Row Redesign
  final String? trigram;               // own team, e.g. "LAL"
  final String? opponentTrigram;       // the OTHER team tonight — never own team
  final bool? isHome;                  // true=hosts, false=travels, null=no game data
  final String? form;                  // "HOT" | "COLD" | null (neutral — render nothing)
  final List<int?> lastTwoScores;      // chronological [older, newer]

  Player({
    this.id,
    required this.name,
    required this.position,
    required this.team,
    this.teamId,
    this.status,
    required this.price,
    this.trigram,
    this.opponentTrigram,
    this.isHome,
    this.form,
    this.lastTwoScores = const [null, null],
  });

  // JSON serialization methods (optional, useful for API calls)
  factory Player.fromJson(Map<String, dynamic> json) {
    // Parse price from string format "19M" or "14.2M" to double
    double parsedPrice = 0.0;
    if (json['price'] != null) {
      String priceStr = json['price'].toString().replaceAll('M', '').trim();
      parsedPrice = double.tryParse(priceStr) ?? 0.0;
    }

    final rawLastTwo = json['last_two_scores'];
    final lastTwo = rawLastTwo is List
        ? rawLastTwo.map((e) => e == null ? null : (e as num).toInt()).toList()
        : const <int?>[null, null];

    return Player(
      id: json['id']?.toString(),
      name: json['name'] ?? '',
      position: json['position'] ?? '',
      team: json['team'] ?? '',
      teamId: json['team_id']?.toString(),
      status: json['status'],
      price: parsedPrice,
      trigram: json['trigram'],
      opponentTrigram: json['opponent_trigram'],
      isHome: json['is_home'],
      form: json['form'],
      lastTwoScores: lastTwo.length == 2 ? lastTwo : const [null, null],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'position': position,
      'team': team,
      'team_id': teamId,
      'status': status,
      'price': price,
    };
  }

  // Add this method to Player class after toJson()
  Map<String, dynamic> toApiJson() {
    return {
      'id': id,
      'name': name,
      'position': position,
      'team': team,
      'team_id': teamId,
      'status': status ?? 'OK',
      'price': '${price.toStringAsFixed(1)}M', // Format with M suffix
    };
  }

  // Copy with method for easy updates
  Player copyWith({
    String? id,
    String? name,
    String? position,
    String? team,
    String? teamId,
    String? status,
    double? price,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      team: team ?? this.team,
      teamId: teamId ?? this.teamId,
      status: status ?? this.status,
      price: price ?? this.price,
    );
  }
}
