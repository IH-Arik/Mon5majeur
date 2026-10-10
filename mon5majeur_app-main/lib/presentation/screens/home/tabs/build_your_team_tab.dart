import '../widgets/todays_games.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../../controllers/my_leagues_controller.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/utils/datetime_format.dart';
import '../../../../core/utils/server_message.dart';
import '../../../../data/models/bonus_inventory_model.dart';
import '../../../../data/models/game_model.dart';
import '../../../../data/models/player.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';
import '../screens/select_player_screen.dart';
import '../widgets/lineup_widgets.dart';
import '../widgets/position_label.dart';
import '../../../../data/services/jersey_service.dart';
import 'jersey_selection_screen.dart';
import 'team_confirm_controls.dart';

/// The three activatable bonuses. Only one can be active at a time.
enum BonusType { sixthMan, chefsCurry, luxuryTax }

class BuildYourTeamTab extends StatefulWidget {
  final int? leagueId;
  final int? matchDay;
  final bool isPrivate;
  final VoidCallback? onTeamSaved; // ADD THIS

  const BuildYourTeamTab({
    super.key,
    this.leagueId,
    this.matchDay,
    this.isPrivate = false,
    this.onTeamSaved, // ADD THIS
  });

  @override
  State<BuildYourTeamTab> createState() => _BuildYourTeamTabState();
}

class _BuildYourTeamTabState extends State<BuildYourTeamTab> {
  // Budget cap = the league's own budget (+ playoff seed bonus) as reported
  // by the server, plus the Luxury Tax bonus while that bonus is active -
  // QA 15/09/2026 item 6: the cap and progress bar used to stay at 100M
  // even with "Bonus Luxury Tax activated".
  double _baseBudget = 100.0;
  double _luxuryTaxBonus = 5.0;
  double get totalBudget =>
      _baseBudget + (luxuryTaxActivated ? _luxuryTaxBonus : 0.0);
  List<Player?> selectedPlayers = List.filled(5, null);
  Player? sixthManPlayer;

  // Client-side confirmed flag (no backend field). True after a successful
  // submit or when a complete saved team is loaded; reset to false on any edit.
  bool isConfirmed = false;
  // Real lock countdown from the backend: null = no game scheduled, 0 =
  // already locked, >0 = seconds until lock.
  int? lockInSeconds;
  int selectedJerseyIndex = 0;
  List<Game> todaysGames = [];
  bool isLoadingGames = true;
  String? gamesErrorMessage;

  // Bonus state — only one bonus can be active at a time (null = none).
  BonusType? activeBonus;

  // Derived flags so existing read-sites keep working.
  bool get sixthManActivated => activeBonus == BonusType.sixthMan;
  bool get chefsCurryActivated => activeBonus == BonusType.chefsCurry;
  bool get luxuryTaxActivated => activeBonus == BonusType.luxuryTax;

  // Show bonus options
  bool showBonusOptions = false;

  // Available counts (loaded from API)
  int sixthManAvailable = 0;
  int chefsCurryAvailable = 0;
  int luxuryTaxAvailable = 0;

  // API Integration
  List<Player> availablePlayers = [];
  bool isLoadingPlayers = true;
  String? errorMessage;
  int currentPage = 1;
  int totalPlayers = 0;
  bool hasMorePages = false;
  String? _nextPageUrl; // ADD THIS
  final ApiClient _apiClient = ApiClient();

  final List<AssetGenImage> jerseys = [
    Assets.icons.jerseyDevil,
    Assets.icons.jerseyFlower,
    Assets.icons.jerseyUfo,
    Assets.icons.jerseyShark,
    Assets.icons.jerseySnake,
    Assets.icons.jerseyZebra,
  ];

  // 6th Man is outside the budget — spec says it is NOT counted against the 100M cap
  // Same rule as the Global League tab: 80 M and 100 M leagues behave alike
  // (QA #9 9.4).
  bool get isOverBudget => usedBudget > totalBudget;

  double get usedBudget =>
      selectedPlayers.fold(0.0, (sum, p) => sum + (p?.price ?? 0.0));

  int get remainingPlayers => selectedPlayers.where((p) => p == null).length;
  bool get isTeamComplete => selectedPlayers.every((p) => p != null);
  Future<void> _fetchTodaysGames() async {
    setState(() {
      isLoadingGames = true;
      gamesErrorMessage = null;
    });

    try {
      final url = "${ApiUrl.baseUrl}${ApiUrl.gamesToday}";
      final response = await _apiClient.get(url: url, showResult: true);

      if (response.statusCode == 200) {
        final List<dynamic> gamesData = response.body;
        setState(() {
          todaysGames = gamesData.map((json) => Game.fromJson(json)).toList();
          isLoadingGames = false;
        });
      } else {
        setState(() {
          gamesErrorMessage = 'Failed to load games'.tr;
          isLoadingGames = false;
        });
      }
    } catch (e) {
      setState(() {
        gamesErrorMessage = 'Error loading games: @e'.trParams({'e': '$e'});
        isLoadingGames = false;
      });
    }
  }

  Future<void> _fetchBonusInventory() async {
    // Prefer the per-league combined count (free quota by league size +
    // purchased charges) — the free quota is otherwise invisible to the UI:
    // a user with free uses left but 0 purchased charges would see "0" and
    // the bonus button would silently refuse to activate at all.
    if (widget.leagueId != null) {
      try {
        final endpoint = widget.isPrivate
            ? ApiUrl.privateBonusStatus(widget.leagueId!)
            : ApiUrl.publicBonusStatus(widget.leagueId!);
        final response = await _apiClient.get(
          url: '${ApiUrl.baseUrl}$endpoint',
        );
        if (response.statusCode == 200 && response.body != null) {
          final data = response.body as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              sixthManAvailable = (data['sixth_man'] as num?)?.toInt() ?? 0;
              chefsCurryAvailable = (data['chef_curry'] as num?)?.toInt() ?? 0;
              luxuryTaxAvailable = (data['luxury_tax'] as num?)?.toInt() ?? 0;
            });
          }
          return;
        }
      } catch (_) {
        // fall through to the purchased-only inventory below
      }
    }

    try {
      final response = await _apiClient.get(
        url: '${ApiUrl.baseUrl}${ApiUrl.bonusInventory}',
      );
      if (response.statusCode == 200 && response.body != null) {
        final inv = BonusInventory.fromJson(
            response.body as Map<String, dynamic>);
        if (mounted) {
          setState(() {
            sixthManAvailable = inv.sixthManCharges;
            chefsCurryAvailable = inv.chefCurryCharges;
            luxuryTaxAvailable = inv.luxuryTaxCharges;
          });
        }
      }
    } catch (_) {
      // non-fatal: keep default 0
    }
  }

  // Add this ValueNotifier to notify child screen of updates
  final ValueNotifier<List<Player>> _playersNotifier = ValueNotifier([]);

  // The league's own budget ("80M") is known from the leagues list: use it
  // at once instead of showing 100 M until the server answers.
  void _seedBudgetFromLeague() {
    final id = widget.leagueId;
    if (id == null || !Get.isRegistered<MyLeaguesController>()) return;
    for (final l in Get.find<MyLeaguesController>().leagues) {
      if (l.leagueId == id && l.isPrivate == widget.isPrivate) {
        final v = double.tryParse(l.league.teamBudget.replaceAll(RegExp(r'[^0-9.]'), ''));
        if (v != null && v > 0) _baseBudget = v;
        return;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _seedBudgetFromLeague();
    _fetchPlayers();
    _fetchTodaysGames();
    _fetchSavedTeam();
    _fetchBonusInventory();
    _loadJersey();
  }

  @override
  void dispose() {
    _playersNotifier.dispose();
    super.dispose();
  }

  Future<void> _fetchPlayers({bool refresh = false}) async {
    try {
      if (refresh) {
        setState(() {
          isLoadingPlayers = true;
          currentPage = 1;
          availablePlayers.clear();
          errorMessage = null;
          _nextPageUrl = null;
          hasMorePages = false;
        });
        _playersNotifier.value = [];
      } else {
        setState(() {
          isLoadingPlayers = true;
          errorMessage = null;
        });
      }

      final url = '${ApiUrl.baseUrl}/api/players-today/';

      final response = await _apiClient.get(url: url, showResult: true);

      if (response.statusCode == 200 && response.body != null) {
        final data = response.body as Map<String, dynamic>;

        totalPlayers = data['count'] ?? 0;
        _nextPageUrl = data['next'];
        hasMorePages = _nextPageUrl != null;

        final results = data['results'] as List<dynamic>?;
        if (results != null) {
          final players = results
              .map((json) => Player.fromJson(json as Map<String, dynamic>))
              .toList();

          setState(() {
            availablePlayers = players;
            isLoadingPlayers = false;
          });

          _playersNotifier.value = List.from(availablePlayers);
          debugPrint(
            '✅ Loaded page 1: ${players.length} players. Total: $totalPlayers',
          );

          // 🔑 Auto-load remaining pages in background
          _loadAllRemainingPages();
        }
      } else {
        setState(() {
          errorMessage = 'Failed to load players. Please try again.'.tr;
          isLoadingPlayers = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading players: @e'.trParams({'e': e.toString()});
        isLoadingPlayers = false;
      });
      debugPrint('Error fetching players: $e');
    }
  }

  // Auto-load ALL remaining pages in background
  Future<void> _loadAllRemainingPages() async {
    while (_nextPageUrl != null && mounted) {
      try {
        debugPrint('🔄 Auto-loading next page: $_nextPageUrl');

        final response = await _apiClient.get(
          url: _nextPageUrl!,
          showResult: false, // suppress logs for background loading
        );

        if (response.statusCode == 200 && response.body != null) {
          final data = response.body as Map<String, dynamic>;

          _nextPageUrl = data['next'];
          hasMorePages = _nextPageUrl != null;

          final results = data['results'] as List<dynamic>?;
          if (results != null) {
            final players = results
                .map((json) => Player.fromJson(json as Map<String, dynamic>))
                .toList();

            if (mounted) {
              setState(() {
                availablePlayers.addAll(players);
                currentPage++;
              });

              // 🔑 Update notifier so SelectPlayerScreen sees new players
              _playersNotifier.value = List.from(availablePlayers);
              debugPrint(
                '✅ Auto-loaded: ${availablePlayers.length} / $totalPlayers players',
              );
            }
          }
        } else {
          debugPrint('⚠️ Failed to load page: ${response.statusCode}');
          break;
        }
      } catch (e) {
        debugPrint('❌ Error auto-loading page: $e');
        break;
      }
    }
    if (mounted) {
      setState(() => hasMorePages = false);
      debugPrint('🏁 All pages loaded. Total: ${availablePlayers.length}');
    }
  }

  bool _isLoadingMore = false;

  Future<void> _loadMorePlayers() async {
    if (_isLoadingMore || !hasMorePages || _nextPageUrl == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final response = await _apiClient.get(
        url: _nextPageUrl!,
        showResult: true,
      );

      if (response.statusCode == 200 && response.body != null) {
        final data = response.body as Map<String, dynamic>;

        _nextPageUrl = data['next'];
        hasMorePages = _nextPageUrl != null;

        final results = data['results'] as List<dynamic>?;
        if (results != null) {
          final players = results
              .map((json) => Player.fromJson(json as Map<String, dynamic>))
              .toList();

          setState(() {
            availablePlayers.addAll(players);
            currentPage++;
            _isLoadingMore = false;
          });

          _playersNotifier.value = List.from(availablePlayers);
          debugPrint('✅ Loaded more. Total: ${availablePlayers.length}');
        }
      } else {
        setState(() => _isLoadingMore = false);
      }
    } catch (e) {
      setState(() => _isLoadingMore = false);
      debugPrint('Error loading more players: $e');
    }
  }

  // Update _selectPlayer method
  void _selectPlayer(int index) {
    if (isLoadingPlayers && availablePlayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loading players, please wait...'.tr)),
      );
      return;
    }

    String positionCategory;
    if (index == 1) {
      positionCategory = 'C';
    } else if (index == 3 || index == 4) {
      positionCategory = 'G';
    } else {
      positionCategory = 'F';
    }

    final selectedIds = selectedPlayers
        .where((p) => p != null && p.id != null)
        .map((p) => p!.id!)
        .toSet();
    if (sixthManPlayer?.id != null) selectedIds.add(sixthManPlayer!.id!);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => SelectPlayerScreen(
          playersNotifier: _playersNotifier, // pass notifier
          getHasMorePages: () => hasMorePages,
          getIsLoadingMore: () => _isLoadingMore,
          teamJersey: jerseys[selectedJerseyIndex],
          positionCategory: positionCategory,
          excludedPlayerIds: selectedIds,
          remainingBudget: totalBudget - usedBudget,
          onPlayerSelected: (p) => setState(() {
            selectedPlayers[index] = p;
            isConfirmed = false; // editing after confirm → back to orange
          }),
          onLoadMore: _loadMorePlayers,
        ),
      ),
    );
  }

  // Update _selectSixthMan method
  void _selectSixthMan() {
    if (isLoadingPlayers && availablePlayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loading players, please wait...'.tr)),
      );
      return;
    }

    final selectedIds = selectedPlayers
        .where((p) => p != null && p.id != null)
        .map((p) => p!.id!)
        .toSet();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => SelectPlayerScreen(
          playersNotifier: _playersNotifier, // pass notifier
          getHasMorePages: () => hasMorePages,
          getIsLoadingMore: () => _isLoadingMore,
          teamJersey: jerseys[selectedJerseyIndex],
          positionCategory: null,
          excludedPlayerIds: selectedIds,
          remainingBudget: totalBudget - usedBudget,
          maxPrice: 8.0,
          onPlayerSelected: (p) => setState(() {
            sixthManPlayer = p;
            isConfirmed = false; // editing after confirm → back to orange
          }),
          onLoadMore: _loadMorePlayers,
        ),
      ),
    );
  }

  void _selectJersey() async {
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (ctx) => const JerseySelectionScreen()),
    );
    if (result != null) {
      setState(() {
        selectedJerseyIndex = result;
      });
      JerseyService.save(result); // kept on the account (QA 28/09 #5)
    }
  }

  Future<void> _loadJersey() async {
    final index = await JerseyService.load();
    if (mounted) setState(() => selectedJerseyIndex = index);
  }

  // Remaining charges available for a given bonus type.
  int _availableFor(BonusType type) {
    switch (type) {
      case BonusType.sixthMan:
        return sixthManAvailable;
      case BonusType.chefsCurry:
        return chefsCurryAvailable;
      case BonusType.luxuryTax:
        return luxuryTaxAvailable;
    }
  }

  // Adjust the local charge count for a bonus type by [delta] (must be inside setState).
  void _adjustCharge(BonusType type, int delta) {
    switch (type) {
      case BonusType.sixthMan:
        sixthManAvailable += delta;
        break;
      case BonusType.chefsCurry:
        chefsCurryAvailable += delta;
        break;
      case BonusType.luxuryTax:
        luxuryTaxAvailable += delta;
        break;
    }
  }

  // Activate or change the active bonus. Only one bonus is active at a time;
  // switching refunds the previously active bonus's charge and consumes the new one.
  void _selectBonus(BonusType type) {
    // Tapping the already-active bonus takes it off again (QA #9 9.1: it only
    // lit up and could not be removed). The 6th man keeps a way to re-pick the
    // substitute: tap his slot on the court.
    if (activeBonus == type) {
      _removeBonus();
      return;
    }

    // Need at least one available charge to activate a new bonus.
    if (_availableFor(type) <= 0) {
      setState(() => showBonusOptions = false);
      return;
    }

    final previous = activeBonus;
    setState(() {
      if (previous != null) _adjustCharge(previous, 1); // refund old
      activeBonus = type;
      _adjustCharge(type, -1); // consume new
      showBonusOptions = false;
      // Switching away from 6th man clears the on-court substitute slot.
      if (previous == BonusType.sixthMan) sixthManPlayer = null;
    });

    if (type == BonusType.sixthMan) _selectSixthMan();
  }

  // QA 30/09 #8 #5: a placed bonus can be taken off again. The charge is
  // given back, exactly as when switching to another bonus.
  void _removeBonus() {
    final previous = activeBonus;
    if (previous == null) return;
    setState(() {
      _adjustCharge(previous, 1);
      activeBonus = null;
      showBonusOptions = false;
      if (previous == BonusType.sixthMan) sixthManPlayer = null;
    });
  }

  bool isSubmitting = false; // Add this

  // Add this method to submit players
  Future<void> _submitPlayerSelection() async {
    // Validate that team is complete
    if (!isTeamComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select all 5 players before submitting'.tr),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (isOverBudget) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppString.budgetExceeded.tr} - '
            '${AppString.budgetExceededBy((usedBudget - totalBudget).ceil())}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Check if leagueId and matchDay are provided
    if (widget.leagueId == null || widget.matchDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('League information not available'.tr),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if matchDay is 0 (league not started)
    if (widget.matchDay == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('League has not started yet. Cannot select players.'.tr),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      // Prepare request body — bonus flags tell the backend which strategic
      // bonus (if any) to consume from the free quota / purchased charges
      // and apply when this duel is scored (spec §4.4).
      final requestBody = {
        'selected_players': selectedPlayers
            .where((p) => p != null)
            .map((p) => p!.toApiJson())
            .toList(),
        'luxury_tax': luxuryTaxActivated,
        'chef_curry': chefsCurryActivated,
        'sixth_man_player': sixthManActivated
            ? sixthManPlayer?.toApiJson()
            : null,
      };

      // Make API call - UPDATED TO USE publicPlayersSelection
      final url = widget.isPrivate
          ? '${ApiUrl.baseUrl}${ApiUrl.privatePlayersSelection(widget.leagueId!, widget.matchDay!)}'
          : '${ApiUrl.baseUrl}${ApiUrl.publicPlayersSelection(widget.leagueId!, widget.matchDay!)}';

      debugPrint(
        '🏀 Submitting to ${widget.isPrivate ? "PRIVATE" : "PUBLIC"} league: $url',
      );
      debugPrint('🏀 League ID: ${widget.leagueId}');
      debugPrint('🏀 Match Day: ${widget.matchDay}');
      debugPrint('🏀 Request body: $requestBody');

      final response = await _apiClient.post(
        url: url,
        body: requestBody,
        showResult: true,
      );

      if (response.statusCode == 200) {
        // Optionally update UI with response data
        final responseData = response.body as Map<String, dynamic>;
        debugPrint('✅ Match ID: ${responseData['match_id']}');
        debugPrint('✅ Total Points: ${responseData['total_points']}');
        debugPrint('✅ Current Balance: ${responseData['current_balance']}');

        if (mounted) {
          setState(() {
            isConfirmed = true;
            lockInSeconds = responseData['lock_in_seconds'];
          });
          await showTeamValidatedDialog(context);
          if (mounted) {
            await maybeShowNotificationPromptAfterFirstValidation(context);
          }

          // Notify parent that team was saved
          widget.onTeamSaved?.call(); // ADD THIS LINE
        }
      } else if (response.statusCode == 403) {
        // The server answers 403 for every refused lineup: invalid
        // positions, budget, bonus AND the real lock. Only the lock message
        // may switch the screen to "locked" (QA #9 9.2: a refused composition
        // showed "Verrouillé" while the games had not started).
        final errorBody = response.body;
        final detail = (errorBody is Map && errorBody['detail'] != null)
            ? errorBody['detail'].toString()
            : 'Night is locked — the first game has already tipped off';
        final reallyLocked = detail.toLowerCase().contains('locked');
        if (mounted) {
          if (reallyLocked) setState(() => lockInSeconds = 0);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizeServerMessage(detail)),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (response.statusCode == 404) {
        // Specific handling for 404
        final errorBody = response.body;
        String errorMessage = 'Match not found for this league day.'.tr;

        if (errorBody is Map && errorBody['detail'] != null) {
          errorMessage = errorBody['detail'];
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        debugPrint('❌ 404 Error: $errorMessage');
      } else {
        // Other errors
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to save team: @msg'.trParams({'msg': response.statusText ?? 'Unknown error'.tr}),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error submitting players: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: @e'.trParams({'e': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  // Add this method to fetch saved players for the current match day
  Future<void> _fetchSavedTeam() async {
    if (widget.leagueId == null ||
        widget.matchDay == null ||
        widget.matchDay == 0) {
      debugPrint(
        '⚠️ Cannot fetch saved team: League ID or Match Day not available',
      );
      return;
    }

    try {
      debugPrint(
        '🔄 Fetching saved team for PUBLIC League ${widget.leagueId}, Match Day ${widget.matchDay}',
      );

      final url = widget.isPrivate
          ? '${ApiUrl.baseUrl}${ApiUrl.privatePlayersSelection(widget.leagueId!, widget.matchDay!)}'
          : '${ApiUrl.baseUrl}${ApiUrl.publicPlayersSelection(widget.leagueId!, widget.matchDay!)}';

      final response = await _apiClient.get(url: url, showResult: true);

      if (response.statusCode == 200) {
        final data = response.body as Map<String, dynamic>;
        final savedPlayers = data['selected_players'] as List<dynamic>?;
        final savedSixthMan = data['sixth_man_player'] as Map<String, dynamic>?;

        setState(() {
          lockInSeconds = data['lock_in_seconds'];
          _baseBudget = (data['base_budget'] as num?)?.toDouble() ?? _baseBudget;
          _luxuryTaxBonus =
              (data['luxury_tax_bonus'] as num?)?.toDouble() ?? _luxuryTaxBonus;
          // Restore whichever bonus was saved server-side (only one is ever
          // active at a time from this screen's own UI).
          if (data['luxury_tax'] == true) {
            activeBonus = BonusType.luxuryTax;
          } else if (data['chef_curry'] == true) {
            activeBonus = BonusType.chefsCurry;
          } else if (savedSixthMan != null) {
            activeBonus = BonusType.sixthMan;
            sixthManPlayer = Player.fromJson(savedSixthMan);
          } else {
            activeBonus = null;
            sixthManPlayer = null;
          }
        });

        if (savedPlayers != null && savedPlayers.isNotEmpty) {
          debugPrint('✅ Found ${savedPlayers.length} saved players');

          setState(() {
            // Clear existing selections
            selectedPlayers = List.filled(5, null);

            // Fill in the saved players
            for (int i = 0; i < savedPlayers.length && i < 5; i++) {
              selectedPlayers[i] = Player.fromJson(
                savedPlayers[i] as Map<String, dynamic>,
              );
            }

            // A complete saved lineup loads as already-confirmed (green state).
            isConfirmed = selectedPlayers.every((p) => p != null);
          });

          debugPrint('✅ Team loaded successfully');
        } else {
          debugPrint('ℹ️ No saved team found for this match day');
        }
      } else if (response.statusCode == 404) {
        debugPrint('ℹ️ No saved team found (404) - starting fresh');
      } else {
        debugPrint('⚠️ Error fetching saved team: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching saved team: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 12.h),
          Text(
            AppString.buildYourTeam.tr,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12.h),
          _buildMatchdaySelector(),
          SizedBox(height: 12.h),
          _buildBudgetCard(),
          SizedBox(height: 12.h),

          // Show loading or error state
          if (isLoadingPlayers && availablePlayers.isEmpty)
            Padding(
              padding: EdgeInsets.all(16.0.w),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF8C42)),
              ),
            )
          else if (errorMessage != null && availablePlayers.isEmpty)
            Padding(
              padding: EdgeInsets.all(16.0.w),
              child: Column(
                children: [
                  Text(
                    errorMessage!,
                    style: TextStyle(color: Colors.red, fontSize: 14.sp),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8.h),
                  ElevatedButton(
                    onPressed: () => _fetchPlayers(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8C42),
                    ),
                    child: Text('Retry'.tr, style: TextStyle(fontSize: 14.sp)),
                  ),
                ],
              ),
            )
          // Remove the "Load More".tr button section and simplify the player count display
          else ...[
            // Show player count
            if (!isLoadingPlayers && availablePlayers.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Text(
                  'Available: @n / @m players'.trParams({'n': '${availablePlayers.length}', 'm': '$totalPlayers'}),
                  style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                ),
              ),
            SizedBox(height: 12.h),
          ],

          _buildCourtField(),
          SizedBox(height: 12.h),
          TeamStatusBanner(
            state: lineupStateFor(
              selectedCount: 5 - remainingPlayers,
              isConfirmed: isConfirmed,
              lockInSeconds: lockInSeconds,
            ),
            remainingPlayers: remainingPlayers,
          ),
          SizedBox(height: 12.h),
          _buildActivatedBonuses(),
          SizedBox(height: 12.h),
          _buildTodaysGames(),
          SizedBox(height: 12.h),
          _buildTimeLeft(),
          SizedBox(height: 12.h),
          TeamConfirmButton(
            state: lineupStateFor(
              selectedCount: 5 - remainingPlayers,
              isConfirmed: isConfirmed,
              lockInSeconds: lockInSeconds,
            ),
            isSubmitting: isSubmitting,
            onConfirm: _submitPlayerSelection,
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  // Persistent "… Bonus Activated" label for the currently active bonus.
  Widget _buildActivatedBonuses() {
    if (activeBonus == null) return const SizedBox.shrink();

    final AssetGenImage icon;
    final String label;
    final Color color;
    switch (activeBonus!) {
      case BonusType.sixthMan:
        icon = Assets.icons.sixman;
        label = AppString.sixthManBonusActivated.tr;
        color = const Color(0xFF2941F1);
        break;
      case BonusType.chefsCurry:
        icon = Assets.icons.chefcurry;
        label = AppString.chefsCurryBonusActivated.tr;
        color = const Color(0xFFFECD56);
        break;
      case BonusType.luxuryTax:
        icon = Assets.icons.luxarytax;
        label = AppString.luxuryTaxBonusActivated.tr;
        color = const Color(0xFF3CDF1C);
        break;
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon.image(width: 24.w, height: 24.h, fit: BoxFit.contain),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 15.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchdaySelector() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {},
              icon: Icon(
                Icons.chevron_left,
                color: Color(0xFFB1B1B1),
                size: 24.r,
              ),
            ),
            Text(
              formatMatchdayLabel(widget.matchDay ?? 1),
              style: TextStyle(
                color: Color(0xFFB1B1B1),
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: Icon(
                Icons.chevron_right,
                color: Color(0xFFB1B1B1),
                size: 24.r,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBudgetCard() {
    final overBudget = isOverBudget;
    final budgetDelta = (usedBudget - totalBudget).ceil();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1C2A),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppString.budgetUsed.tr,
                  style: TextStyle(color: Colors.white70, fontSize: 14.sp),
                ),
                Text(
                  '${usedBudget.toInt()}M / ${totalBudget.toInt()}M',
                  style: TextStyle(
                    color: overBudget ? const Color(0xFFF84A4A) : Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: LinearProgressIndicator(
                value: (usedBudget / totalBudget).clamp(0.0, 1.0),
                backgroundColor: const Color(0xFF2A2D3E),
                valueColor: AlwaysStoppedAnimation<Color>(
                  overBudget ? const Color(0xFFF84A4A) : const Color(0xFFFF8C42),
                ),
                minHeight: 8.h,
              ),
            ),
            if (overBudget) ...[
              SizedBox(height: 8.h),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  AppString.budgetExceededBy(budgetDelta),
                  style: TextStyle(
                    color: const Color(0xFFF84A4A),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCourtField() {
    return LineupCourt(
      height: sixthManActivated ? 720.h : null,
      slotBuilder: _buildPlayerSlot,
      changeJerseyButton: LineupChangeJerseyButton(
        jersey: jerseys[selectedJerseyIndex],
        onTap: _selectJersey,
      ),
      inside: [
        Positioned(top: 30.h, right: 20.w, child: _buildBonusButton()),
        // Own row under the starters, centred: it used to sit over the right
        // guard and hide his name and price (QA #9 9.3).
        if (sixthManActivated)
          Positioned(
            bottom: 12.h,
            left: 0,
            right: 0,
            child: Center(child: _buildSixthManSlot()),
          ),
      ],
      // Bonus options menu - on top layer
      floating: [
        if (showBonusOptions)
          Positioned(top: 94.h, right: 20.w, child: _buildBonusOptionsMenu()),
      ],
    );
  }

  Widget _buildBonusOptionsMenu() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF2C2C2C), width: 1.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildBonusOptionItem(
                icon: Assets.icons.sixman,
                label: AppString.sixthMan.tr,
                count: sixthManAvailable,
                isActivated: sixthManActivated,
                onTap: () => _selectBonus(BonusType.sixthMan),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildBonusOptionItem(
            icon: Assets.icons.chefcurry,
            label: AppString.chefsCurry.tr,
            count: chefsCurryAvailable,
            isActivated: chefsCurryActivated,
            onTap: () => _selectBonus(BonusType.chefsCurry),
          ),
          SizedBox(height: 12.h),
          _buildBonusOptionItem(
            icon: Assets.icons.luxarytax,
            label: AppString.luxuryTax.tr,
            count: luxuryTaxAvailable,
            isActivated: luxuryTaxActivated,
            onTap: () => _selectBonus(BonusType.luxuryTax),
          ),
          if (activeBonus != null) ...[
            SizedBox(height: 14.h),
            GestureDetector(
              onTap: _removeBonus,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 8.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: const Color(0xFFFF6B35)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close, color: const Color(0xFFFF6B35), size: 14.r),
                    SizedBox(width: 4.w),
                    Text(
                      AppString.removeBonus.tr,
                      style: TextStyle(
                        color: const Color(0xFFFF6B35),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBonusOptionItem({
    required AssetGenImage icon,
    required String label,
    required int count,
    required bool isActivated,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 37.w,
            height: 37.h,
            decoration: BoxDecoration(
              color: isActivated
                  ? const Color(0xFF777777)
                  : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(19.r),
              border: Border.all(color: const Color(0xFF2C2C2C), width: 1.r),
            ),
            child: Center(
              child: icon.image(width: 16.w, height: 16.h, fit: BoxFit.contain),
            ),
          ),
          SizedBox(width: 4.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: const Color(0xFF777777),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontFamily: 'Lato',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 4.w),
          Container(
            width: 25.w,
            height: 24.h,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(6.r),
              border: Border.all(color: const Color(0xFF2C2C2C)),
            ),
            child: Center(
              child: Text(
                '$count',
                style: TextStyle(
                  color: Color(0xFFE8632C),
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPlayerSlot(int index, String position) {
    return LineupPlayerSlot(
      player: selectedPlayers[index],
      jersey: jerseys[selectedJerseyIndex],
      label: position,
      onTap: () => _selectPlayer(index),
    );
  }

  Widget _buildSixthManSlot() {
    return LineupPlayerSlot(
      player: sixthManPlayer,
      jersey: jerseys[selectedJerseyIndex],
      label: AppString.sixthMan.tr,
      onTap: _selectSixthMan,
    );
  }

  // Icon of the currently active bonus, for the top-right corner button.
  AssetGenImage? get _activeBonusIcon {
    switch (activeBonus) {
      case BonusType.sixthMan:
        return Assets.icons.sixman;
      case BonusType.chefsCurry:
        return Assets.icons.chefcurry;
      case BonusType.luxuryTax:
        return Assets.icons.luxarytax;
      case null:
        return null;
    }
  }

  // QA 28/09 #3: the button was small dark grey and blended into the court.
  // Bigger, orange accent and a bolt icon so it is seen at first glance.
  Widget _buildBonusButton() {
    final activeIcon = _activeBonusIcon;
    const orange = Color(0xFFFF8C42);
    return GestureDetector(
      onTap: () {
        // A placed bonus is taken off by tapping its box (QA #10 15, third
        // report): the box goes back to its empty state; tapping it again
        // opens the bonus selection window as before.
        if (activeBonus != null) {
          if (!isLineupLocked(lockInSeconds)) _removeBonus(); // not after the lock
          return;
        }
        setState(() {
          showBonusOptions = !showBonusOptions;
        });
      },
      child: Container(
        width: 64.w,
        height: 56.h,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // One look whatever the state: no colour flip on tap (QA #10 15).
            colors: const [Color(0xFF2A1A10), Color(0xFF1A1A1A)],
          ),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: orange, width: 1.5.r),
          boxShadow: [
            BoxShadow(
              color: orange.withValues(alpha: 0.45),
              blurRadius: 10.r,
            ),
          ],
        ),
        // When a bonus is active, show its icon; tap to change the bonus.
        // Placed bonus: no "Bonus" text, just its image, large.
        child: activeIcon != null
            ? Center(child: activeIcon.image(width: 40.w, height: 40.h, fit: BoxFit.contain))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bolt, color: orange, size: 24.r),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      AppString.bonuses.tr,
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTodaysGames() => TodaysGamesSection(
        isLoading: isLoadingGames,
        errorMessage: gamesErrorMessage,
        games: todaysGames,
      );

  Widget _buildTimeLeft() {
    // Nothing to show until the lock data has loaded — never a placeholder
    // figure (QA 15/09/2026 item 6).
    if (lockInSeconds == null && isLoadingGames) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          if (lockInSeconds != null) ...[
            Icon(Icons.access_time, color: Colors.white70, size: 20.r),
            SizedBox(width: 8.w),
          ],
          Text(
            formatTimeLeft(lockInSeconds),
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
