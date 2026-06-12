// lib/controllers/global_league_controller.dart
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import '../data/models/player.dart';
import '../data/services/api_service.dart';
import '../data/services/api_url.dart';

final logger = Logger();

/// Model for Global League Player Selection Response
class GlobalLeagueSelection {
  final int matchDay;
  final List<Player> selectedPlayers;
  final int totalPoints;
  final String maxBalance;
  final String currentBalance;

  GlobalLeagueSelection({
    required this.matchDay,
    required this.selectedPlayers,
    required this.totalPoints,
    required this.maxBalance,
    required this.currentBalance,
  });

  factory GlobalLeagueSelection.fromJson(Map<String, dynamic> json) {
    return GlobalLeagueSelection(
      matchDay: json['match_day'] ?? 0,
      selectedPlayers:
          (json['selected_players'] as List?)
              ?.map((player) => Player.fromJson(player))
              .toList() ??
          [],
      totalPoints: json['total_points'] ?? 0,
      maxBalance: json['max_balance'] ?? '100M',
      currentBalance: json['current_balance'] ?? '100M',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'match_day': matchDay,
      'selected_players': selectedPlayers.map((p) => p.toJson()).toList(),
      'total_points': totalPoints,
      'max_balance': maxBalance,
      'current_balance': currentBalance,
    };
  }

  // Get remaining balance as double
  double get remainingBalanceValue {
    String cleaned = currentBalance.replaceAll('M', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  // Get max balance as double
  double get maxBalanceValue {
    String cleaned = maxBalance.replaceAll('M', '').trim();
    return double.tryParse(cleaned) ?? 100.0;
  }
}

class GlobalLeagueController extends GetxController {
  // Observable variables
  var isLoading = false.obs;
  var isSaving = false.obs;
  var globalLeagueSelection = Rx<GlobalLeagueSelection?>(null);
  var selectedPlayers = <Player>[].obs;
  var totalPoints = 0.obs;
  var currentBalance = '100M'.obs;
  var maxBalance = '100M'.obs;
  var currentMatchDay = 0.obs;

  // Error handling
  var errorMessage = ''.obs;
  var hasError = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchGlobalLeagueSelection();
  }

  /// Fetch current global league player selection
  Future<void> fetchGlobalLeagueSelection() async {
    if (isLoading.value) return;

    isLoading.value = true;
    hasError.value = false;
    errorMessage.value = '';

    try {
      final apiClient = ApiClient();

      logger.i('Fetching Global League Selection...');

      final response = await apiClient.get(
        url: ApiUrl.baseUrl + ApiUrl.globalLeaguePlayersSelection,
        isBasic: false, // Use bearer token
        showResult: true,
      );

      logger.i('Global League Selection Response: ${response.statusCode}');

      if (response.statusCode == 200 && response.body != null) {
        final selection = GlobalLeagueSelection.fromJson(response.body);

        globalLeagueSelection.value = selection;
        selectedPlayers.value = selection.selectedPlayers;
        totalPoints.value = selection.totalPoints;
        currentBalance.value = selection.currentBalance;
        maxBalance.value = selection.maxBalance;
        currentMatchDay.value = selection.matchDay;

        logger.i('Loaded ${selectedPlayers.length} players for Global League');
        logger.i('Current Balance: ${currentBalance.value}');
        logger.i('Total Points: ${totalPoints.value}');
      } else if (response.statusCode == 404) {
        // No selection yet - empty state
        logger.i('No global league selection found - creating new selection');
        _initializeEmptySelection();
      } else {
        hasError.value = true;
        errorMessage.value = 'Failed to load global league data';
        logger.e(
          'Failed to load global league selection: ${response.statusCode}',
        );
      }
    } catch (e) {
      hasError.value = true;
      errorMessage.value = 'Error loading global league: $e';
      logger.e('Error fetching global league selection: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Submit/Update player selection to global league
  Future<bool> submitPlayerSelection(List<Player> players) async {
    if (isSaving.value) return false;

    isSaving.value = true;
    hasError.value = false;
    errorMessage.value = '';

    try {
      final apiClient = ApiClient();

      logger.i('Submitting ${players.length} players to Global League...');

      // Convert players to API format
      final body = {
        'selected_players': players
            .map((player) => player.toApiJson())
            .toList(),
      };

      final response = await apiClient.post(
        url: ApiUrl.baseUrl + ApiUrl.globalLeaguePlayersSelection,
        isBasic: false, // Use bearer token
        body: body,
        showResult: true,
      );

      logger.i('Submit Player Selection Response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        logger.i('Successfully submitted player selection');

        // Refresh the selection after successful submission
        await fetchGlobalLeagueSelection();

        return true;
      } else {
        hasError.value = true;
        errorMessage.value = 'Failed to submit player selection';
        logger.e('Failed to submit player selection: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      hasError.value = true;
      errorMessage.value = 'Error submitting players: $e';
      logger.e('Error submitting player selection: $e');
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Add a player to selection
  void addPlayer(Player player) {
    if (!selectedPlayers.contains(player)) {
      selectedPlayers.add(player);
      _updateBalance();
      logger.i('Added player: ${player.name}');
    }
  }

  /// Remove a player from selection
  void removePlayer(Player player) {
    selectedPlayers.remove(player);
    _updateBalance();
    logger.i('Removed player: ${player.name}');
  }

  /// Clear all selected players
  void clearSelection() {
    selectedPlayers.clear();
    _updateBalance();
    logger.i('Cleared all selected players');
  }

  /// Update current balance based on selected players
  void _updateBalance() {
    double totalSpent = selectedPlayers.fold(
      0.0,
      (sum, player) => sum + player.price,
    );

    double maxBal =
        maxBalance.value.replaceAll('M', '').trim().toDoubleOrNull() ?? 100.0;
    double remaining = maxBal - totalSpent;

    currentBalance.value = '${remaining.toStringAsFixed(1)}M';
  }

  /// Initialize empty selection
  void _initializeEmptySelection() {
    selectedPlayers.clear();
    totalPoints.value = 0;
    currentBalance.value = '100M';
    maxBalance.value = '100M';
    currentMatchDay.value = 0;
  }

  /// Refresh data
  @override
  Future<void> refresh() async {
    await fetchGlobalLeagueSelection();
  }

  /// Check if player selection is valid (e.g., has 5 players)
  bool isSelectionValid() {
    return selectedPlayers.length == 5;
  }

  /// Get remaining budget as double
  double getRemainingBudget() {
    return currentBalance.value.replaceAll('M', '').trim().toDoubleOrNull() ??
        0.0;
  }

  /// Check if can afford a player
  bool canAffordPlayer(Player player) {
    return getRemainingBudget() >= player.price;
  }
}

// Extension to safely parse double from String
extension StringToDouble on String {
  double? toDoubleOrNull() {
    return double.tryParse(this);
  }
}
