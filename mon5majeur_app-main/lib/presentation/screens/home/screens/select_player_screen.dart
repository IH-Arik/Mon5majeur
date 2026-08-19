import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../data/models/player.dart';
import '../../tutorial/tutorial_controller.dart';
import '../../tutorial/tutorial_skip_button.dart';
import '../widgets/player_form_badge.dart';

class SelectPlayerScreen extends StatefulWidget {
  final ValueNotifier<List<Player>> playersNotifier; // 🔑 reactive list
  final bool Function() getHasMorePages;
  final bool Function() getIsLoadingMore;
  final double remainingBudget;
  final AssetGenImage teamJersey;
  final Function(Player) onPlayerSelected;
  final Future<void> Function() onLoadMore;
  final String? positionCategory;
  final Set<String> excludedPlayerIds;
  // 6th Man picks must cost ≤ 8M (spec §4.4) — the backend rejects a pricier
  // pick at submit time, so filtering the list here means Confirm can never
  // silently fail on a 6th Man that was never a valid choice to begin with.
  final double? maxPrice;

  const SelectPlayerScreen({
    super.key,
    required this.playersNotifier,
    required this.getHasMorePages,
    required this.getIsLoadingMore,
    required this.remainingBudget,
    required this.teamJersey,
    required this.onPlayerSelected,
    required this.onLoadMore,
    this.positionCategory,
    this.excludedPlayerIds = const {},
    this.maxPrice,
  });

  @override
  State<SelectPlayerScreen> createState() => _SelectPlayerScreenState();
}

class _SelectPlayerScreenState extends State<SelectPlayerScreen> {
  String searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  final TutorialController _tutorial = Get.find<TutorialController>();
  BuildContext? _showcaseContext;
  bool _rowShowcaseStarted = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = maxScroll - 200.h;

    if (currentScroll >= threshold &&
        widget.getHasMorePages() &&
        !_isLoadingMore) {
      debugPrint(
        '🔄 Triggering load more... current: ${widget.playersNotifier.value.length}',
      );
      _triggerLoadMore();
    }
  }

  Future<void> _triggerLoadMore() async {
    if (_isLoadingMore || !widget.getHasMorePages()) return;
    setState(() => _isLoadingMore = true);
    await widget.onLoadMore();
    if (mounted) {
      setState(() => _isLoadingMore = false);
      debugPrint(
        '✅ Load more done. Total: ${widget.playersNotifier.value.length}',
      );
    }
  }

  List<Player> _applyFilters(List<Player> players) {
    return players.where((player) {
      // Exclude already selected players
      if (player.id != null && widget.excludedPlayerIds.contains(player.id!)) {
        return false;
      }

      // 6th Man price cap (spec §4.4) — backend rejects anything pricier.
      if (widget.maxPrice != null && player.price > widget.maxPrice!) {
        return false;
      }

      // Apply position filter
      if (widget.positionCategory != null) {
        final pos = player.position.toUpperCase();
        if (widget.positionCategory == 'C' && pos != 'C') return false;
        if (widget.positionCategory == 'G' && !pos.contains('G')) return false;
        if (widget.positionCategory == 'F' && !pos.contains('F')) return false;
      }

      // Apply search filter
      if (searchQuery.isNotEmpty) {
        return player.name.toLowerCase().contains(searchQuery.toLowerCase());
      }

      return true;
    }).toList();
  }

  /// Starts the step-2 (first player row) spotlight the first time a
  /// non-empty filtered list renders while the tutorial is at step 2.
  /// Guarded by [_rowShowcaseStarted] so pagination/search rebuilds don't
  /// retrigger it.
  void _maybeStartRowShowcase(List<Player> filteredPlayers) {
    if (_rowShowcaseStarted || filteredPlayers.isEmpty) return;
    if (!(_tutorial.active.value && _tutorial.step.value == 2)) return;
    _rowShowcaseStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _showcaseContext;
      if (ctx == null || !mounted) return;
      ShowCaseWidget.of(ctx).startShowCase([_tutorial.playerRowKey]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: ShowCaseWidget(
        enableAutoScroll: true,
        globalFloatingActionWidget: buildTutorialSkipAction,
        builder: (scContext) {
          _showcaseContext = scContext;
          return Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildBudgetInfo(),
                    _buildSearchBar(),
                    // 🔑 ValueListenableBuilder rebuilds automatically when notifier changes
                    ValueListenableBuilder<List<Player>>(
                      valueListenable: widget.playersNotifier,
                      builder: (context, players, _) {
                        final filteredPlayers = _applyFilters(players);
                        _maybeStartRowShowcase(filteredPlayers);
                        return Expanded(
                          child: Column(
                            children: [
                              _buildTableHeader(
                                filteredPlayers.length,
                                players.length,
                              ),
                              SizedBox(height: 12.h),
                              _buildPlayerList(filteredPlayers),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFFFF8C42),
      padding: EdgeInsets.all(16.w),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: SizedBox(
              width: 30.w,
              height: 30.h,
              child: Assets.icons.backButton.image(fit: BoxFit.contain),
            ),
          ),
          Expanded(
            child: Text(
              AppString.selectPlayer.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 28.w),
        ],
      ),
    );
  }

  Widget _buildBudgetInfo() {
    return Container(
      color: const Color(0xFF000000),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppString.bank.tr,
                style: TextStyle(color: Colors.white70, fontSize: 14.sp),
              ),
              Text(
                '\$${widget.remainingBudget.toInt()} M',
                style: TextStyle(
                  color: const Color(0xFF4CAF50),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (widget.maxPrice != null) ...[
            SizedBox(height: 4.h),
            Text(
              '6th Man pick must cost ≤ ${widget.maxPrice!.toInt()}M',
              style: TextStyle(color: Colors.white38, fontSize: 11.sp),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: TextField(
        onChanged: (value) => setState(() => searchQuery = value),
        style: TextStyle(color: Colors.white, fontSize: 14.sp),
        decoration: InputDecoration(
          hintText: AppString.searchPlayersHint.tr,
          hintStyle: TextStyle(color: Colors.white38, fontSize: 14.sp),
          prefixIcon: Icon(Icons.search, color: Colors.white38, size: 24.r),
          filled: true,
          fillColor: const Color(0xFF1A1C2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(int filteredCount, int totalLoaded) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2D3E),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppString.player,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              AppString.lastScores.tr,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              AppString.price,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerList(List<Player> filteredPlayers) {
    final hasMore = widget.getHasMorePages();
    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: filteredPlayers.length + (_isLoadingMore || hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filteredPlayers.length) {
            return Padding(
              padding: EdgeInsets.all(16.w),
              child: Center(
                child: _isLoadingMore
                    ? Column(
                        children: [
                          CircularProgressIndicator(
                            color: const Color(0xFFFF8C42),
                            strokeWidth: 4.r,
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Loading more players...',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            );
          }
          return _buildPlayerCard(filteredPlayers[index], isFirst: index == 0);
        },
      ),
    );
  }

  Widget _buildPlayerCard(Player player, {bool isFirst = false}) {
    void handleTap() {
      if (isFirst && _tutorial.active.value && _tutorial.step.value == 2) {
        _tutorial.advanceTo(3);
      }
      widget.onPlayerSelected(player);
      Navigator.pop(context);
    }

    // Cross-cutting rule (spec Part 1 §6.0): an OUT player is dimmed
    // uniformly across the WHOLE row — jersey, trigram, name, form badge,
    // scores, venue icon, opponent and price all included, none left at
    // full colour.
    final isOut = player.status == 'OUT';

    final card = GestureDetector(
      onTap: handleTap,
      child: Opacity(
        opacity: isOut ? 0.4 : 1.0,
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1C2A),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              _buildPlayerAvatar(player),
              SizedBox(width: 12.w),
              Expanded(child: _buildPlayerInfo(player)),
              _buildLastScores(player),
              SizedBox(width: 12.w),
              _buildPlayerPrice(player),
            ],
          ),
        ),
      ),
    );

    final spotlightThisRow =
        isFirst && _tutorial.active.value && _tutorial.step.value == 2;

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: !spotlightThisRow
          ? card
          : Showcase(
              key: _tutorial.playerRowKey,
              description: AppString.tutorialStep2.tr,
              disposeOnTap: true,
              disableBarrierInteraction: true,
              onTargetClick: handleTap,
              targetBorderRadius: BorderRadius.circular(12.r),
              child: card,
            ),
    );
  }

  Widget _buildPlayerAvatar(Player player) {
    return Column(
      children: [
        Container(
          width: 50.w,
          height: 50.h,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2D3E),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
              child: widget.teamJersey.image(fit: BoxFit.cover),
          ),
        ),
        if (player.trigram != null) ...[
          SizedBox(height: 2.h),
          Text(
            player.trigram!,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPlayerInfo(Player player) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                player.name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (player.form == 'HOT' || player.form == 'COLD') ...[
              SizedBox(width: 6.w),
              buildFormBadge(player.form, size: 15),
            ],
          ],
        ),
        SizedBox(height: 6.h),
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8C42),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                player.position,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (player.opponentTrigram != null) ...[
              SizedBox(width: 8.w),
              Icon(
                player.isHome == false ? Icons.flight : Icons.home,
                color: player.isHome == false
                    ? const Color(0xFFE05353)
                    : const Color(0xFF4CAF50),
                size: 13.r,
              ),
              SizedBox(width: 3.w),
              Flexible(
                child: Text(
                  player.opponentTrigram!,
                  style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Two chips showing the player's last 2 PLAYED games' Fantasy Points,
  /// chronological left-to-right (spec Part 1 §5.0). "—" for a missing
  /// game — never 0 or X, an absence isn't a bad performance.
  Widget _buildLastScores(Player player) {
    final scores = player.lastTwoScores;
    final older = scores.isNotEmpty ? scores[0] : null;
    final newer = scores.length > 1 ? scores[1] : null;

    Widget chip(int? value) {
      return Container(
        margin: EdgeInsets.only(left: 4.w),
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2D3E),
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Text(
          value?.toString() ?? '—',
          style: TextStyle(color: Colors.white70, fontSize: 11.sp),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [chip(older), chip(newer)]);
  }

  Widget _buildPlayerPrice(Player player) {
    return Text(
      '${player.price.toInt()} M',
      style: TextStyle(
        color: Colors.white,
        fontSize: 16.sp,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
