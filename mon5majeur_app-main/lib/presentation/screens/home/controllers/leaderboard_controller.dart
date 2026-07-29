// lib/presentation/screens/home/controllers/leaderboard_controller.dart
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../../../../data/models/playoff_bracket_model.dart';
import '../../../../data/models/standings_model.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';

final logger = Logger();

class LeaderboardController extends GetxController {
  var isLoadingStandings = false.obs;
  var isLoadingPlayoffs = false.obs;
  Rx<StandingsModel?> standings = Rx<StandingsModel?>(null);
  Rx<PlayoffBracketModel?> playoffBracket = Rx<PlayoffBracketModel?>(null);

  int? leagueId;
  bool isPrivate = true;

  void setLeague(int id, {bool isPrivate = true}) {
    leagueId = id;
    this.isPrivate = isPrivate;
    fetchStandings();
  }

  Future<void> fetchStandings() async {
    if (leagueId == null) return;
    isLoadingStandings.value = true;
    try {
      final apiClient = ApiClient();
      final endpoint = isPrivate
          ? ApiUrl.privateStandings(leagueId!)
          : ApiUrl.publicStandings(leagueId!);
      final response = await apiClient.get(
        url: '${ApiUrl.baseUrl}$endpoint',
        showResult: true,
      );

      if (response.statusCode == 200) {
        standings.value = StandingsModel.fromJson(response.body);
        logger.i('Loaded standings: ${standings.value?.teams.length} teams');
      } else {
        logger.e('Failed to load standings: ${response.statusCode}');
        standings.value = null;
      }
    } catch (e) {
      logger.e('Error fetching standings: $e');
      standings.value = null;
    } finally {
      isLoadingStandings.value = false;
    }
  }

  Future<void> fetchPlayoffBracket() async {
    if (leagueId == null) return;
    isLoadingPlayoffs.value = true;
    try {
      final apiClient = ApiClient();
      final endpoint = isPrivate
          ? ApiUrl.privatePlayoffs(leagueId!)
          : ApiUrl.publicPlayoffs(leagueId!);
      final response = await apiClient.get(
        url: '${ApiUrl.baseUrl}$endpoint',
        showResult: true,
      );

      if (response.statusCode == 200) {
        playoffBracket.value = PlayoffBracketModel.fromJson(response.body);
        logger.i(
          'Loaded playoff bracket: ${playoffBracket.value?.rounds.length} rounds',
        );
      } else {
        logger.w('No playoff bracket yet: ${response.statusCode}');
        playoffBracket.value = null;
      }
    } catch (e) {
      logger.e('Error fetching playoff bracket: $e');
      playoffBracket.value = null;
    } finally {
      isLoadingPlayoffs.value = false;
    }
  }
}
