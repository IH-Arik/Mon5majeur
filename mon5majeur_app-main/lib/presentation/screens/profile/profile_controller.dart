// lib/presentation/screens/profile/profile_controller.dart
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../../../data/models/profile_stats_model.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/api_url.dart';

final _logger = Logger();

class ProfileController extends GetxController {
  final _api = ApiClient();

  var isLoading = false.obs;
  var stats = Rx<ProfileStatsModel>(ProfileStatsModel.empty());

  @override
  void onInit() {
    super.onInit();
    fetchStats();
  }

  void resetSessionState() {
    isLoading.value = false;
    stats.value = ProfileStatsModel.empty();
  }

  Future<void> fetchStats() async {
    isLoading.value = true;
    try {
      final response =
          await _api.get(url: ApiUrl.baseUrl + ApiUrl.profileStats);
      if (response.statusCode == 200 && response.body != null) {
        stats.value =
            ProfileStatsModel.fromJson(response.body as Map<String, dynamic>);
      } else {
        stats.value = ProfileStatsModel.empty();
      }
    } catch (e) {
      stats.value = ProfileStatsModel.empty();
      _logger.e('Error fetching profile stats: $e');
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Future<void> refresh() async {
    await fetchStats();
  }
}
