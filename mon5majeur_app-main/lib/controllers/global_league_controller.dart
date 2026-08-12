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
  // Real validated/lock state from the backend (Home "NBA Global League" card).
  final bool lineupSubmitted;
  final int? lockInSeconds;
  final int? weeklyRank;
  final int? monthlyRank;

  GlobalLeagueSelection({
    required this.matchDay,
    required this.selectedPlayers,
    required this.totalPoints,
    required this.maxBalance,
    required this.currentBalance,
    this.lineupSubmitted = false,
    this.lockInSeconds,
    this.weeklyRank,
    this.monthlyRank,
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
      lineupSubmitted: json['lineup_submitted'] ?? false,
      lockInSeconds: json['lock_in_seconds'],
      weeklyRank: json['weekly_rank'],
      monthlyRank: json['monthly_rank'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'match_day': matchDay,
      'selected_players': selectedPlayers.map((p) => p.toJson()).toList(),
      'total_points': totalPoints,
      'max_balance': maxBalance,
      'current_balance': currentBalance,
      'lineup_submitted': lineupSubmitted,
      'lock_in_seconds': lockInSeconds,
      'weekly_rank': weeklyRank,
      'monthly_rank': monthlyRank,
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

  // Whether the user has ever joined the Global League (Home card shows a
  // "Join now" CTA until this is true, then switches to the stats card).
  var hasJoined = false.obs;
  var isJoining = false.obs;
  var isCheckingJoinStatus = false.obs;

  // Error handling
  var errorMessage = ''.obs;
  var hasError = false.obs;

  @override
  void onInit() {
    super.onInit();
    checkJoinStatus();
  }

  /// Check whether the current user has already joined the Global League.
  /// Only fetches the selection/stats once joined — an unjoined user has no
  /// selection to load yet.
  Future<void> checkJoinStatus() async {
    if (isCheckingJoinStatus.value) return;
    isCheckingJoinStatus.value = true;

    try {
      final apiClient = ApiClient();
      final response = await apiClient.get(
        url: ApiUrl.baseUrl + ApiUrl.globalLeagueStatus,
        isBasic: false,
        showResult: true,
      );

      if (response.statusCode == 200 && response.body != null) {
        hasJoined.value = response.body['joined'] ?? false;
        if (hasJoined.value) {
          await fetchGlobalLeagueSelection();
        }
      }
    } catch (e) {
      logger.e('Error checking Global League join status: $e');
    } finally {
      isCheckingJoinStatus.value = false;
    }
  }

  /// Join the Global League (Home card "Join now" CTA).
  Future<bool> joinGlobalLeague() async {
    if (isJoining.value) return false;
    isJoining.value = true;

    try {
      final apiClient = ApiClient();
      final response = await apiClient.post(
        url: ApiUrl.baseUrl + ApiUrl.globalLeagueJoin,
        isBasic: false,
        body: {},
        showResult: true,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        hasJoined.value = true;
        await fetchGlobalLeagueSelection();
        return true;
      }
      logger.e('Failed to join Global League: ${response.statusCode}');
      return false;
    } catch (e) {
      logger.e('Error joining Global League: $e');
      return false;
    } finally {
      isJoining.value = false;
    }
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

      // Convert players to API format — the Global League runs on the
      // no-bonus duel engine, so no bonus flags are sent here (see
      // build_your_team_tab.dart for the private/public bonus flow).
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
        await fetchGlobalLeagueSelection();
        return true;
      } else if (response.statusCode == 401) {
        hasError.value = true;
        errorMessage.value = 'Session expired. Please log in again.';
        logger.e('401 unauthorized submitting player selection');
        return false;
      } else if (response.statusCode == 404) {
        hasError.value = true;
        errorMessage.value = 'Global league not found. Please try again later.';
        logger.e('404 global league not found');
        return false;
      } else {
        hasError.value = true;
        final detail = response.body?['detail'] as String? ?? 'Unknown error';
        errorMessage.value = 'Failed to save team (${response.statusCode}): $detail';
        logger.e('Failed to submit player selection: ${response.statusCode} - $detail');
        return false;
      }
    } catch (e) {
      hasError.value = true;
      errorMessage.value = 'Network error: $e';
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
