// lib/presentation/screens/home/controllers/live_score_controller.dart
import 'dart:async';

import 'package:get/get.dart';
import 'package:logger/logger.dart';

import '../../../../data/models/live_score_model.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';

final _logger = Logger();

enum LiveScoreMode { duel, global }

/// Drives the Live Score screen for both a single duel match and the
/// Global League (spec §4.5: live score must cover Global League too, not
/// just duel leagues). Polls every 60s while the screen is visible — cheap
/// on our own backend even though the Goalserve sync itself only refreshes
/// every ~20 min (see live_scores/service.py::_is_stale_for_date); the
/// is_stale flag from the backend tells the user when data hasn't moved.
class LiveScoreController extends GetxController {
  final LiveScoreMode mode;
  final String? matchId;

  LiveScoreController({required this.mode, this.matchId});

  final isLoading = true.obs;
  final isForbidden = false.obs; // no active premium/live-score subscription
  final errorMessage = RxnString();

  final matchScore = Rxn<LiveMatchScore>();
  final globalScore = Rxn<LiveGlobalScore>();

  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    fetch();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => fetch());
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  Future<void> fetch() async {
    if (matchScore.value == null && globalScore.value == null) {
      isLoading.value = true;
    }
    errorMessage.value = null;

    try {
      final apiClient = ApiClient();
      final endpoint = mode == LiveScoreMode.duel
          ? ApiUrl.liveMatch(matchId!)
          : ApiUrl.liveGlobal;
      final url = '${ApiUrl.baseUrl}$endpoint';

      final response = await apiClient.get(url: url, showResult: true);

      if (response.statusCode == 200) {
        isForbidden.value = false;
        final data = response.body as Map<String, dynamic>;
        if (mode == LiveScoreMode.duel) {
          matchScore.value = LiveMatchScore.fromJson(data);
        } else {
          globalScore.value = LiveGlobalScore.fromJson(data);
        }
      } else if (response.statusCode == 403) {
        isForbidden.value = true;
      } else {
        errorMessage.value =
            (response.body is Map ? response.body['detail'] : null) ??
            'Could not load live scores';
      }
    } catch (e) {
      _logger.e('Live score fetch failed: $e');
      errorMessage.value = 'Could not load live scores';
    } finally {
      isLoading.value = false;
    }
  }
}
