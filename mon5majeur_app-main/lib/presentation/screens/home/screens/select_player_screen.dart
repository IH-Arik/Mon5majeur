import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../data/models/player.dart';

class SelectPlayerScreen extends StatefulWidget {
  final ValueNotifier<List<Player>> playersNotifier; // 🔑 reactive list
  final bool Function() getHasMorePages;
  final bool Function() getIsLoadingMore;
  final double remainingBudget;
  final Function(Player) onPlayerSelected;
  final Future<void> Function() onLoadMore;
  final String? positionCategory;
  final Set<String> excludedPlayerIds;

  const SelectPlayerScreen({
    super.key,
    required this.playersNotifier,
    required this.getHasMorePages,
    required this.getIsLoadingMore,
    required this.remainingBudget,
    required this.onPlayerSelected,
    required this.onLoadMore,
    this.positionCategory,
    this.excludedPlayerIds = const {},
  });

  @override
  State<SelectPlayerScreen> createState() => _SelectPlayerScreenState();
}

class _SelectPlayerScreenState extends State<SelectPlayerScreen> {
  String searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
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
              AppString.selectPlayer,
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppString.bank,
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
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: TextField(
        onChanged: (value) => setState(() => searchQuery = value),
        style: TextStyle(color: Colors.white, fontSize: 14.sp),
        decoration: InputDecoration(
          hintText: AppString.searchPlayersByName,
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
              '$filteredCount shown · $totalLoaded loaded',
              style: TextStyle(color: Colors.white38, fontSize: 11.sp),
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
          return _buildPlayerCard(filteredPlayers[index]);
        },
      ),
    );
  }

  Widget _buildPlayerCard(Player player) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: GestureDetector(
        onTap: () {
          widget.onPlayerSelected(player);
          Navigator.pop(context);
        },
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1C2A),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              _buildPlayerAvatar(),
              SizedBox(width: 12.w),
              Expanded(child: _buildPlayerInfo(player)),
              _buildPlayerPrice(player),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerAvatar() {
    return Container(
      width: 50.w,
      height: 50.h,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3E),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.r),
        child: Assets.icons.dress.image(fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildPlayerInfo(Player player) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          player.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
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
            SizedBox(width: 8.w),
            Flexible(
              child: Text(
                player.team,
                style: TextStyle(color: Colors.white54, fontSize: 13.sp),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
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
