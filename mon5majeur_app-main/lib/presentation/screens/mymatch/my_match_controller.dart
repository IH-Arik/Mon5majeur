import 'package:get/get.dart';
import '../../../data/models/game_model.dart';
import '../../../data/models/player_today_score_model.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/api_url.dart';

class MyMatchController extends GetxController {
  final _api = ApiClient();

  final isLoading = true.obs;
  final todaysGames = <Game>[].obs;
  final playerScores = <PlayerTodayScore>[].obs;
  final error = ''.obs;

  /// Team filter of the fantasy scores: the normalized team key, null = all.
  final selectedTeam = Rxn<String>();

  /// Lower case, letters and digits only: "LA Clippers" and "la-clippers"
  /// are one team. Empty for a player without a team.
  static String teamKey(String team) =>
      team.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// One entry per team found in the scores (the first spelling met is shown),
  /// ordered by name.
  List<({String key, String name})> get teamOptions {
    final seen = <String, String>{};
    for (final p in playerScores) {
      final key = teamKey(p.team);
      if (key.isNotEmpty) seen.putIfAbsent(key, () => p.team.trim());
    }
    final options = [
      for (final e in seen.entries) (key: e.key, name: e.value),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return options;
  }

  void selectTeam(String? key) => selectedTeam.value = key;

  @override
  void onInit() {
    super.onInit();
    fetchAll();
  }

  Future<void> fetchAll() async {
    isLoading.value = true;
    error.value = '';
    await Future.wait([
      _fetchTodaysGames(),
      _fetchPlayerScores(),
    ]);
    // A team that no longer appears in the scores (new night) is dropped.
    final selected = selectedTeam.value;
    if (selected != null && !teamOptions.any((t) => t.key == selected)) {
      selectedTeam.value = null;
    }
    isLoading.value = false;
  }

  Future<void> _fetchTodaysGames() async {
    try {
      // The last night that has started: last night's results stay until the
      // new day's first tip-off (QA #9 3.2).
      final resp = await _api.get(url: '${ApiUrl.baseUrl}${ApiUrl.gamesToday}?results=true');
      if (resp.statusCode == 200 && resp.body is List) {
        todaysGames.value = (resp.body as List)
            .map((e) => Game.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchPlayerScores() async {
    try {
      final resp = await _api.get(
        url: ApiUrl.baseUrl + ApiUrl.playersTodayScores,
      );
      if (resp.statusCode == 200 && resp.body is Map) {
        final results = resp.body['results'] as List? ?? [];
        playerScores.value = results
            .map((e) => PlayerTodayScore.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
  }
}
