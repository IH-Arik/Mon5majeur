import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../data/models/player.dart';
import '../../../../data/models/game_model.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';
import '../../../../controllers/global_league_controller.dart';
import '../../../../data/models/bonus_inventory_model.dart';
import '../screens/select_player_screen.dart';
import 'build_your_team_tab.dart' show BonusType;
import 'jersey_selection_screen.dart';
import 'team_confirm_controls.dart';

class BuildYourTeamTabGlobal extends StatefulWidget {
  final VoidCallback? onTeamSaved;

  const BuildYourTeamTabGlobal({
    super.key,
    this.onTeamSaved,
  });

  @override
  State<BuildYourTeamTabGlobal> createState() => _BuildYourTeamTabGlobalState();
}

class _BuildYourTeamTabGlobalState extends State<BuildYourTeamTabGlobal> {
  final double totalBudget = 100.0;
  List<Player?> selectedPlayers = List.filled(5, null);
  Player? sixthManPlayer;

  // Client-side confirmed flag (no backend field). True after a successful
  // submit or when a complete saved team is loaded; reset to false on any edit.
  bool isConfirmed = false;

  int selectedJerseyIndex = 0;
  List<Game> todaysGames = [];
  bool isLoadingGames = true;
  String? gamesErrorMessage;

  late final GlobalLeagueController _controller;

  // Bonus state — only one bonus can be active at a time (null = none).
  BonusType? activeBonus;
  bool get sixthManActivated => activeBonus == BonusType.sixthMan;
  bool get chefsCurryActivated => activeBonus == BonusType.chefsCurry;
  bool get luxuryTaxActivated => activeBonus == BonusType.luxuryTax;
  bool showBonusOptions = false;
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
  String? _nextPageUrl;
  final ApiClient _apiClient = ApiClient();

  // ValueNotifier for reactive updates
  final ValueNotifier<List<Player>> _playersNotifier = ValueNotifier([]);

  final List<AssetGenImage> jerseys = [
    Assets.icons.gercy1,
    Assets.icons.gercy2,
    Assets.icons.gercy3,
    Assets.icons.gercy4,
    Assets.icons.gercy5,
  ];

  // 6th Man is outside the budget — spec says it is NOT counted against the cap.
  double get usedBudget =>
      selectedPlayers.fold(0.0, (sum, p) => sum + (p?.price ?? 0.0));

  int get remainingPlayers => selectedPlayers.where((p) => p == null).length;
  bool get isTeamComplete => selectedPlayers.every((p) => p != null);

  @override
  void initState() {
    super.initState();
    _controller = Get.find<GlobalLeagueController>();
    _fetchPlayers();
    _fetchTodaysGames();
    _loadExistingSelection();
    _fetchBonusInventory();
  }

  @override
  void dispose() {
    _playersNotifier.dispose();
    super.dispose();
  }

  Future<void> _fetchBonusInventory() async {
    // Prefer the combined free-quota + purchased-charge count for the
    // Global League (same accounting model as private/public leagues —
    // the free quota is otherwise invisible: a user with free uses left but
    // 0 purchased charges would see "0" and the button would refuse to work).
    try {
      final response = await _apiClient.get(
        url: '${ApiUrl.baseUrl}${ApiUrl.globalLeagueBonusStatus}',
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

    try {
      final response = await _apiClient.get(
        url: '${ApiUrl.baseUrl}${ApiUrl.bonusInventory}',
      );
      if (response.statusCode == 200 && response.body != null) {
        final inv = BonusInventory.fromJson(
          response.body as Map<String, dynamic>,
        );
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

  void _loadExistingSelection() {
    final selection = _controller.globalLeagueSelection.value;
    if (selection != null) {
      if (selection.luxuryTax) {
        activeBonus = BonusType.luxuryTax;
      } else if (selection.chefCurry) {
        activeBonus = BonusType.chefsCurry;
      } else if (selection.sixthManPlayer != null) {
        activeBonus = BonusType.sixthMan;
        sixthManPlayer = selection.sixthManPlayer;
      }
    }

    if (_controller.selectedPlayers.isNotEmpty) {
      setState(() {
        for (int i = 0; i < _controller.selectedPlayers.length && i < 5; i++) {
          selectedPlayers[i] = _controller.selectedPlayers[i];
        }
        // A complete saved lineup loads as already-confirmed (green state).
        isConfirmed = selectedPlayers.every((p) => p != null);
      });
    }
  }

  Future<void> _fetchPlayers({bool refresh = false}) async {
    try {
      if (refresh) {
        setState(() {
          availablePlayers.clear();
          isLoadingPlayers = true;
          errorMessage = null;
          currentPage = 1;
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
          final players = results.map((json) => Player.fromJson(json)).toList();

          setState(() {
            availablePlayers.addAll(players);
            isLoadingPlayers = false;
          });

          _playersNotifier.value = List.from(availablePlayers);

          debugPrint(
            '✅ Loaded ${players.length} players (Total: ${availablePlayers.length})',
          );

          // Start loading remaining pages in background
          if (hasMorePages) {
            _loadAllRemainingPages();
          }
        }
      } else {
        setState(() {
          errorMessage = 'Failed to load players';
          isLoadingPlayers = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading players: ${e.toString()}';
        isLoadingPlayers = false;
      });
      debugPrint('Error fetching players: $e');
    }
  }

  Future<void> _loadAllRemainingPages() async {
    while (_nextPageUrl != null && mounted) {
      try {
        debugPrint('🔄 Auto-loading next page: $_nextPageUrl');

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
                .map((json) => Player.fromJson(json))
                .toList();

            if (mounted) {
              setState(() {
                availablePlayers.addAll(players);
              });
              _playersNotifier.value = List.from(availablePlayers);
            }
          }
        } else {
          debugPrint('❌ Failed to load page: ${response.statusCode}');
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
          final players = results.map((json) => Player.fromJson(json)).toList();

          setState(() {
            availablePlayers.addAll(players);
            _isLoadingMore = false;
          });

          _playersNotifier.value = List.from(availablePlayers);

          debugPrint(
            '✅ Loaded more: ${players.length} (Total: ${availablePlayers.length})',
          );
        }
      } else {
        setState(() => _isLoadingMore = false);
      }
    } catch (e) {
      setState(() => _isLoadingMore = false);
      debugPrint('Error loading more players: $e');
    }
  }

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
          gamesErrorMessage = 'Failed to load games';
          isLoadingGames = false;
        });
      }
    } catch (e) {
      setState(() {
        gamesErrorMessage = 'Error loading games: $e';
        isLoadingGames = false;
      });
    }
  }

  void _selectPlayer(int index) {
    if (isLoadingPlayers && availablePlayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading players, please wait...')),
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
          playersNotifier: _playersNotifier,
          getHasMorePages: () => hasMorePages,
          getIsLoadingMore: () => _isLoadingMore,
          remainingBudget: totalBudget - usedBudget,
          onPlayerSelected: (p) => setState(() {
            selectedPlayers[index] = p;
            isConfirmed = false; // editing after confirm → back to orange
          }),
          onLoadMore: _loadMorePlayers,
          positionCategory: positionCategory,
          excludedPlayerIds: selectedIds,
        ),
      ),
    );
  }

  void _selectSixthMan() {
    if (isLoadingPlayers && availablePlayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading players, please wait...')),
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
          playersNotifier: _playersNotifier,
          getHasMorePages: () => hasMorePages,
          getIsLoadingMore: () => _isLoadingMore,
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
    // Tapping the already-active bonus: just close the menu (re-pick 6th man player).
    if (activeBonus == type) {
      setState(() => showBonusOptions = false);
      if (type == BonusType.sixthMan) _selectSixthMan();
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

  void _selectJersey() async {
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (ctx) => const JerseySelectionScreen()),
    );
    if (result != null) {
      setState(() {
        selectedJerseyIndex = result;
      });
    }
  }

  Future<void> _saveTeam() async {
    if (!isTeamComplete) {
      Get.snackbar(
        'Incomplete Team',
        'Please select all 5 players before saving',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    final playersToSave = selectedPlayers.whereType<Player>().toList();

    final success = await _controller.submitPlayerSelection(
      playersToSave,
      luxuryTax: luxuryTaxActivated,
      chefCurry: chefsCurryActivated,
      sixthManPlayer: sixthManActivated ? sixthManPlayer : null,
    );

    if (success) {
      setState(() => isConfirmed = true);
      if (mounted) {
        await showTeamValidatedDialog(context);
        if (mounted) {
          await maybeShowNotificationPromptAfterFirstValidation(context);
        }
      }
      widget.onTeamSaved?.call();
    } else {
      Get.snackbar(
        'Error',
        _controller.errorMessage.value.isNotEmpty
            ? _controller.errorMessage.value
            : 'Failed to save team. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
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
          _buildCourtField(),
          SizedBox(height: 12.h),
          _buildActivatedBonuses(),
          SizedBox(height: 12.h),
          Obx(
            () => TeamStatusBanner(
              state: lineupStateFor(
                selectedCount: 5 - remainingPlayers,
                isConfirmed: isConfirmed,
                lockInSeconds:
                    _controller.globalLeagueSelection.value?.lockInSeconds,
              ),
              remainingPlayers: remainingPlayers,
            ),
          ),
          SizedBox(height: 12.h),
          _buildTodaysGames(),
          SizedBox(height: 12.h),
          Obx(() => _buildTimeLeft()),
          SizedBox(height: 12.h),
          Obx(
            () => TeamConfirmButton(
              state: lineupStateFor(
                selectedCount: 5 - remainingPlayers,
                isConfirmed: isConfirmed,
                lockInSeconds:
                    _controller.globalLeagueSelection.value?.lockInSeconds,
              ),
              isSubmitting: _controller.isSaving.value,
              onConfirm: _saveTeam,
            ),
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _buildMatchdaySelector() {
    return Obx(
      () => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.chevron_left,
              color: const Color(0xFFB1B1B1),
              size: 24.r,
            ),
          ),
          Text(
            '${AppString.matchday.tr} ${_controller.currentMatchDay.value}',
            style: TextStyle(
              color: const Color(0xFFB1B1B1),
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.chevron_right,
              color: const Color(0xFFB1B1B1),
              size: 24.r,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        padding: EdgeInsets.all(16.r),
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
                  '\$${usedBudget.toInt()} M / ${totalBudget.toInt()} M',
                  style: TextStyle(
                    color: Colors.white,
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
                value: usedBudget / totalBudget,
                backgroundColor: const Color(0xFF2A2D3E),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFFF8C42),
                ),
                minHeight: 8.h,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourtField() {
    return Stack(
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          height: 600.h,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.r)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Assets.images.playground.image(fit: BoxFit.cover),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                Positioned(
                  top: 50.h,
                  left: 20.w,
                  child: _buildChangeJerseyButton(),
                ),
                Positioned(top: 30.h, right: 20.w, child: _buildBonusButton()),
                Positioned(
                  top: 150.h,
                  left: 40.w,
                  child: _buildPlayerSlot(0, 'SF/PF'),
                ),
                Positioned(
                  top: 120.h,
                  left: 0,
                  right: 0,
                  child: Center(child: _buildPlayerSlot(1, 'C')),
                ),
                Positioned(
                  top: 150.h,
                  right: 40.w,
                  child: _buildPlayerSlot(2, 'SF/PF'),
                ),
                Positioned(
                  top: 320.h,
                  left: 60.w,
                  child: _buildPlayerSlot(3, 'PG/SG'),
                ),
                Positioned(
                  top: 320.h,
                  right: 60.w,
                  child: _buildPlayerSlot(4, 'PG/SG'),
                ),
                if (sixthManActivated)
                  Positioned(
                    bottom: 20.h,
                    right: 40.w,
                    child: _buildSixthManSlot(),
                  ),
              ],
            ),
          ),
        ),
        // Bonus options menu - on top layer
        if (showBonusOptions)
          Positioned(top: 80.h, right: 36.w, child: _buildBonusOptionsMenu()),
      ],
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
        label = AppString.sixthManBonusActivated;
        color = const Color(0xFF2941F1);
        break;
      case BonusType.chefsCurry:
        icon = Assets.icons.chefcurry;
        label = AppString.chefsCurryBonusActivated;
        color = const Color(0xFFFECD56);
        break;
      case BonusType.luxuryTax:
        icon = Assets.icons.luxarytax;
        label = AppString.luxuryTaxBonusActivated;
        color = const Color(0xFF3CDF1C);
        break;
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon.image(width: 24.w, height: 24.h),
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
          _buildBonusOptionItem(
            icon: Assets.icons.sixman,
            label: AppString.sixthMan,
            count: sixthManAvailable,
            isActivated: sixthManActivated,
            onTap: () => _selectBonus(BonusType.sixthMan),
          ),
          SizedBox(height: 12.h),
          _buildBonusOptionItem(
            icon: Assets.icons.chefcurry,
            label: AppString.chefsCurry,
            count: chefsCurryAvailable,
            isActivated: chefsCurryActivated,
            onTap: () => _selectBonus(BonusType.chefsCurry),
          ),
          SizedBox(height: 12.h),
          _buildBonusOptionItem(
            icon: Assets.icons.luxarytax,
            label: AppString.luxuryTax,
            count: luxuryTaxAvailable,
            isActivated: luxuryTaxActivated,
            onTap: () => _selectBonus(BonusType.luxuryTax),
          ),
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
            child: Center(child: icon.image(width: 16.w, height: 16.h)),
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
                  color: const Color(0xFFE8632C),
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

  Widget _buildBonusButton() {
    final activeIcon = _activeBonusIcon;
    return GestureDetector(
      onTap: () {
        setState(() {
          showBonusOptions = !showBonusOptions;
        });
      },
      child: Container(
        width: 42.w,
        height: 42.h,
        decoration: ShapeDecoration(
          color: showBonusOptions
              ? const Color(0xFF777777)
              : const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            side: BorderSide(width: 1.r, color: const Color(0xFF2C2C2C)),
            borderRadius: BorderRadius.circular(6.r),
          ),
        ),
        child: activeIcon != null
            ? Center(child: activeIcon.image(width: 24.w, height: 24.h))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppString.plus,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  Text(
                    AppString.bonuses,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8.sp,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSixthManSlot() {
    final player = sixthManPlayer;

    return GestureDetector(
      onTap: _selectSixthMan,
      child: Column(
        children: [
          SizedBox(
            width: 114.w,
            height: 96.h,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    width: 114.w,
                    height: 91.h,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: jerseys[selectedJerseyIndex].provider(),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 39.w,
                  top: 85.h,
                  child: Container(
                    width: 36.w,
                    height: 11.h,
                    decoration: ShapeDecoration(
                      color: const Color(0xFF777777),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(width: 0.50.r, color: Colors.white),
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 44.w,
                  top: 86.h,
                  child: SizedBox(
                    width: 28.w,
                    height: 9.h,
                    child: Text(
                      AppString.sixthMan,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontFamily: 'Lato',
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                if (player == null)
                  Positioned(
                    left: 48.w,
                    top: 57.h,
                    child: SizedBox(
                      width: 17.w,
                      height: 21.h,
                      child: Text(
                        AppString.plus,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFAAAAAA),
                          fontSize: 10.sp,
                          fontFamily: 'Lato',
                          fontWeight: FontWeight.w300,
                          height: 1.10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (player != null) ...[
            SizedBox(height: 8.h),
            Text(
              player.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFFECD56),
                fontSize: 12.sp,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w600,
                height: 1.83,
              ),
            ),
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              decoration: ShapeDecoration(
                color: const Color(0xFF1A1A1A),
                shape: RoundedRectangleBorder(
                  side: BorderSide(width: 1.r, color: const Color(0xFF2C2C2C)),
                  borderRadius: BorderRadius.circular(6.r),
                ),
              ),
              child: Text(
                '${player.price.toInt()} M',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w800,
                  height: 1.83,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChangeJerseyButton() {
    return GestureDetector(
      onTap: _selectJersey,
      child: Container(
        width: 60.w,
        height: 80.h,
        decoration: ShapeDecoration(
          color: const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(
            side: BorderSide(width: 1.r, color: const Color(0xFF1A1A1A)),
            borderRadius: BorderRadius.circular(6.r),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 35.w,
              height: 35.h,
              child: jerseys[selectedJerseyIndex].image(fit: BoxFit.contain),
            ),
            SizedBox(height: 4.h),
            Text(
              AppString.changeJersey.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 8.sp,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w400,
                height: 1.2,
              ),
            ),
            Text(
              AppString.plus.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w100,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerSlot(int index, String position) {
    final player = selectedPlayers[index];

    return GestureDetector(
      onTap: () => _selectPlayer(index),
      child: Column(
        children: [
          SizedBox(
            width: 114.w,
            height: 96.h,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    width: 114.w,
                    height: 91.h,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: jerseys[selectedJerseyIndex].image().image,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 41.w,
                  top: 85.h,
                  child: Container(
                    width: 28.w,
                    height: 11.h,
                    decoration: ShapeDecoration(
                      color: const Color(0xFF1A1A1A),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          width: 0.50.r,
                          color: const Color(0xFF1A1A1A),
                        ),
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 44.w,
                  top: 86.h,
                  child: SizedBox(
                    width: 22.w,
                    child: Text(
                      position,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.sp,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w400,
                        height: 0.89,
                      ),
                    ),
                  ),
                ),
                if (player == null)
                  Positioned(
                    left: 45.w,
                    top: 35.h,
                    child: Container(
                      width: 20.w,
                      height: 20.h,
                      decoration: const ShapeDecoration(
                        color: Color(0xFFFF8C42),
                        shape: OvalBorder(),
                      ),
                      child: Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 16.r,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (player != null) ...[
            SizedBox(height: 8.h),
            Text(
              player.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFFECD56),
                fontSize: 12.sp,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w600,
                height: 1.83,
              ),
            ),
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              decoration: ShapeDecoration(
                color: const Color(0xFF1A1A1A),
                shape: RoundedRectangleBorder(
                  side: BorderSide(width: 1.r, color: const Color(0xFF2C2C2C)),
                  borderRadius: BorderRadius.circular(6.r),
                ),
              ),
              child: Text(
                '${player.price.toInt()} M',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w800,
                  height: 1.83,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTodaysGames() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              AppString.todaysGames.tr,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        if (isLoadingGames)
          Center(
            child: CircularProgressIndicator(
              color: const Color(0xFFFF8C42),
            ),
          )
        else if (gamesErrorMessage != null)
          Text(
            gamesErrorMessage!,
            style: TextStyle(color: Colors.red, fontSize: 12.sp),
          )
        else if (todaysGames.isEmpty)
          Text(
            'No games today',
            style: TextStyle(color: Colors.white70, fontSize: 12.sp),
          )
        else
          SizedBox(
            height: 120.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemCount: todaysGames.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(right: 12.w),
                  child: _buildGameCard(todaysGames[index]),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildGameCard(Game game) {
    return Container(
      width: 160.w,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C2A),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF2A2D3E)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${game.homeTeam} vs ${game.awayTeam}',
            style: TextStyle(
              color: const Color(0xFFFF8C42),
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            game.gameTime,
            style: TextStyle(color: Colors.white70, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeLeft() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Icon(Icons.access_time, color: Colors.white70, size: 20.r),
          SizedBox(width: 8.w),
          Text(
            formatTimeLeft(_controller.globalLeagueSelection.value?.lockInSeconds),
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
