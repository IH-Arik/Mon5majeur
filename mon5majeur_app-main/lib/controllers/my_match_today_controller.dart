// lib/controllers/my_match_today_controller.dart
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../data/models/my_match_today_model.dart';
import '../data/services/api_service.dart';
import '../data/services/api_url.dart';

final logger = Logger();

class MyMatchTodayController extends GetxController {
  // Observable variables
  var isLoading = false.obs;
  var matches = <MyMatchTodayModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchMyMatchesToday();
  }

  // Fetch my matches today from API
  Future<void> fetchMyMatchesToday() async {
    if (isLoading.value) return;

    isLoading.value = true;

    try {
      final apiClient = ApiClient();

      logger.i('Fetching My Matches Today...');

      final response = await apiClient.get(
        url: ApiUrl.baseUrl + ApiUrl.myMatchesToday,
        isBasic: false, // Use bearer token
        showResult: true,
      );

      logger.i('My Matches Today Response: ${response.statusCode}');
      logger.i('My Matches Today Body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body is List) {
          final matchesList = (response.body as List)
              .map((json) => MyMatchTodayModel.fromJson(json))
              .toList();

          matches.value = matchesList;
          logger.i('Loaded ${matches.length} matches');
        } else {
          logger.w('Response is not a list');
        }
      } else {
        logger.e('Failed to load matches: ${response.statusCode}');
      }
    } catch (e) {
      logger.e('Error fetching matches: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Refresh matches
  Future<void> refreshMatches() async {
    await fetchMyMatchesToday();
  }
}
