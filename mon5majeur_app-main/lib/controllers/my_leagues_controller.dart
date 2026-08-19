// lib/presentation/screens/home/controller/my_leagues_controller.dart
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../data/models/my_league_model.dart';
import '../data/models/private_league_model.dart';
import '../data/services/api_service.dart';
import '../data/services/api_url.dart';

final logger = Logger();

class MyLeaguesController extends GetxController {
  // Observable variables
  var isLoading = false.obs;
  var leagues = <MyLeagueModel>[].obs;
  var filteredLeagues = <MyLeagueModel>[].obs;
  var searchQuery = ''.obs;

  // Separate loading states for private and public leagues
  var isLoadingPrivateLeagues = false.obs;
  var isLoadingPublicLeagues = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchLeagues();
  }

  // Fetch all leagues (both private and public) from API
  Future<void> fetchLeagues() async {
    if (isLoading.value) return;

    isLoading.value = true;

    try {
      // Fetch both private and public leagues in parallel
      await Future.wait([_fetchPrivateLeagues(), _fetchPublicLeagues()]);

      logger.i('Loaded total ${leagues.length} leagues');
    } catch (e) {
      logger.e('Error fetching leagues: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Fetch private leagues
  Future<void> _fetchPrivateLeagues() async {
    isLoadingPrivateLeagues.value = true;

    try {
      final apiClient = ApiClient();

      logger.i('Fetching Private Leagues...');

      final response = await apiClient.get(
        url: ApiUrl.baseUrl + ApiUrl.myPrivateLeagues,
        isBasic: false, // Use bearer token
        showResult: true,
      );

      logger.i('Private Leagues Response: ${response.statusCode}');
      logger.i('Private Leagues Body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body is List) {
          final privateLeaguesList = (response.body as List)
              .map((json) => PrivateLeagueModel.fromJson(json))
              .map(
                (privateLeague) => MyLeagueModel.fromPrivateLeague(
                  privateLeague,
                  userRank: privateLeague.rank,
                  matchday: privateLeague.currentMatchDay,
                  week: privateLeague.currentWeek,
                  season: 'Regular Season',
                  isPrivate: true, // Mark as private league
                ),
              )
              .toList();

          // Add to leagues list
          leagues.addAll(privateLeaguesList);
          filteredLeagues.value = leagues;
          logger.i('Loaded ${privateLeaguesList.length} private leagues');
        } else {
          logger.w('Private leagues response is not a list');
        }
      } else {
        logger.e('Failed to load private leagues: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Error fetching private leagues: $e');
    } finally {
      isLoadingPrivateLeagues.value = false;
    }
  }

  // Fetch public leagues
  Future<void> _fetchPublicLeagues() async {
    isLoadingPublicLeagues.value = true;

    try {
      final apiClient = ApiClient();

      logger.i('Fetching Public Leagues...');

      final response = await apiClient.get(
        url: ApiUrl.baseUrl + ApiUrl.myPublicLeagues,
        isBasic: false, // Use bearer token
        showResult: true,
      );

      logger.i('Public Leagues Response: ${response.statusCode}');
      logger.i('Public Leagues Body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body is List) {
          final publicLeaguesList = (response.body as List)
              .map((json) => PrivateLeagueModel.fromJson(json))
              .map(
                (publicLeague) => MyLeagueModel.fromPrivateLeague(
                  publicLeague,
                  userRank: publicLeague.rank,
                  matchday: publicLeague.currentMatchDay,
                  week: publicLeague.currentWeek,
                  season: 'Regular Season',
                  isPrivate: false, // Mark as public league
                ),
              )
              .toList();

          // Add to leagues list
          leagues.addAll(publicLeaguesList);
          filteredLeagues.value = leagues;
          logger.i('Loaded ${publicLeaguesList.length} public leagues');
        } else {
          logger.w('Public leagues response is not a list');
        }
      } else {
        logger.e('Failed to load public leagues: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Error fetching public leagues: $e');
    } finally {
      isLoadingPublicLeagues.value = false;
    }
  }

  // Search leagues by name
  void searchLeagues(String query) {
    searchQuery.value = query;

    if (query.isEmpty) {
      filteredLeagues.value = List.from(leagues); // Create a new list
    } else {
      filteredLeagues.value = leagues
          .where(
            (league) =>
                league.leagueName.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    }
  }

  // Refresh leagues
  Future<void> refreshLeagues() async {
    leagues.clear(); // Clear existing leagues before refresh
    await fetchLeagues();
  }
}
