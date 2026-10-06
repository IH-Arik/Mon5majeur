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
