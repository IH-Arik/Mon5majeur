// lib/presentation/screens/home/my_league_screens/tabs/result.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/constants/app_strings.dart';
import '../controllers/result_controller.dart';

class ResultTab extends StatefulWidget {
  final int? leagueId;
  final int? matchDay;
  final bool isPrivate; // ADD THIS

  const ResultTab({
    super.key,
    this.leagueId,
    this.matchDay,
    this.isPrivate = false, // ADD THIS
  });

  @override
  State<ResultTab> createState() => _ResultTabState();
}

class _ResultTabState extends State<ResultTab> {
  late final ResultController controller;

  @override
  void initState() {
    super.initState();
    print(
      '🎯 ResultTab initialized with leagueId: ${widget.leagueId}, matchDay: ${widget.matchDay}, isPrivate: ${widget.isPrivate}',
    );
    controller = Get.put(ResultController());
    if (widget.leagueId != null) {
      print('🎯 Setting leagueId to controller: ${widget.leagueId}');
      controller.setLeagueId(
        widget.leagueId!,
        initialMatchDay: widget.matchDay,
        type: widget.isPrivate
            ? LeagueType.private
            : LeagueType.public, // ADD THIS
      );
    } else {
      print('⚠️ WARNING: leagueId is NULL!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF8C42)),
        );
      }

      if (controller.matchResult.value == null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.white54, size: 48.r),
              SizedBox(height: 16.h),
              Text(
                'No match data available',
                style: TextStyle(color: Colors.white54, fontSize: 16.sp),
              ),
            ],
          ),
        );
      }

      final matchData = controller.matchResult.value!;

      return SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            SizedBox(height: 16.h),
            _buildMatchdaySelector(),
            SizedBox(height: 16.h),
            _buildMatchInfo(matchData),
            SizedBox(height: 16.h),
            ...matchData.pairs.asMap().entries.map((entry) {
              final index = entry.key;
              final pair = entry.value;
              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: _buildMatchCard(index, pair),
              );
            }),
            SizedBox(height: 16.h),
          ],
        ),
      );
    });
  }

  Widget _buildMatchdaySelector() {
    return Column(
      children: [
        // Debug info
        Text(
          ' League ${controller.leagueId}, Day ${controller.currentMatchDay.value}',
          style: TextStyle(color: Colors.white38, fontSize: 10.sp),
        ),
        SizedBox(height: 8.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: controller.currentMatchDay.value > 1
                  ? controller.previousMatchDay
                  : null,
              icon: Icon(
                Icons.chevron_left,
                color: controller.currentMatchDay.value > 1
                    ? const Color(0xFFB1B1B1)
                    : Colors.grey.shade700,
                size: 24.r,
              ),
            ),
            Obx(
              () => Text(
                '${AppString.matchday.tr} ${controller.currentMatchDay.value}',
                style: TextStyle(
                  color: const Color(0xFFB1B1B1),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              onPressed: controller.nextMatchDay,
              icon: Icon(
                Icons.chevron_right,
                color: const Color(0xFFB1B1B1),
                size: 24.r,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMatchInfo(matchResult) {
    return Column(
      children: [
        Text(
          matchResult.leagueName,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8.h),
        _buildStatusBadge(matchResult.status),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'scheduled':
        color = Colors.orange;
        text = 'Scheduled';
        break;
      case 'live':
        color = Colors.green;
        text = 'Live';
        break;
      case 'completed':
        color = Colors.blue;
        text = 'Completed';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: color),
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMatchCard(int index, pair) {
    final isCurrentUser = controller.isCurrentUserInMatch(pair);
    final playerAScore = controller.getPlayerScoreById(pair.playerAId);
    final playerBScore = controller.getPlayerScoreById(pair.playerBId);

    return Obx(() {
      final isExpanded = controller.expandedCardIndex.value == index;

      return Column(
        children: [
          Container(
            width: double.infinity,
            constraints: BoxConstraints(maxWidth: 362.w),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: ShapeDecoration(
              gradient: const LinearGradient(
                begin: Alignment(0.00, 0.50),
                end: Alignment(1.00, 0.50),
                colors: [Color(0xFF20222B), Color(0xFF14151C)],
              ),
              shape: RoundedRectangleBorder(
                side: BorderSide(width: 1.w, color: const Color(0xFF2C2C2C)),
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: Column(
              children: [
                if (isCurrentUser) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _buildYouBadge(),
                  ),
                  SizedBox(height: 8.h),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Team A
                    Expanded(
                      child: Row(
                        children: [
                          _buildTeamLogo(playerAScore?.teamName ?? ''),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              pair.playerAName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Score
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Row(
                        children: [
                          Text(
                            '${pair.scoreA}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.w),
                            child: Text(
                              AppString.vs.tr,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                          Text(
                            '${pair.scoreB}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Team B
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              pair.playerBName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          _buildTeamLogo(playerBScore?.teamName ?? ''),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                _buildViewDetailsButton(index),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: isExpanded
                ? _buildMatchDetailsField(playerAScore, playerBScore)
                : SizedBox.shrink(),
          ),
        ],
      );
    });
  }

  Widget _buildTeamLogo(String teamName) {
    // Use a default logo or map team names to logos
    return Container(
      width: 32.w,
      height: 32.w,
      decoration: ShapeDecoration(
        color: const Color(0xFF1A1A1A),
        shape: OvalBorder(
          side: BorderSide(width: 1.w, color: const Color(0xFFB0B0B0)),
        ),
      ),
      child: Center(
        child: Assets.icons.logo1.image(width: 16.w, height: 18.h),
      ),
    );
  }

  Widget _buildYouBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
      decoration: ShapeDecoration(
        color: const Color(0xFF2C2C2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.r)),
      ),
      child: Text(
        AppString.you.tr,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildViewDetailsButton(int index) {
    return GestureDetector(
      onTap: () => controller.toggleCardExpansion(index),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
        decoration: ShapeDecoration(
          gradient: const LinearGradient(
            begin: Alignment(0.00, 0.50),
            end: Alignment(1.00, 0.50),
            colors: [Color(0xFFE8632C), Color(0xFFFF8A50)],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6.r),
          ),
        ),
        child: Obx(() {
          final isExpanded = controller.expandedCardIndex.value == index;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppString.viewDetails.tr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 4.w),
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 16.r,
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMatchDetailsField(playerAScore, playerBScore) {
    final teamAPlayers = playerAScore?.selection ?? [];
    final teamBPlayers = playerBScore?.selection ?? [];

    return Container(
      margin: EdgeInsets.only(top: 12.h),
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: 362.w),
      height: 700.h,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.r)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Stack(
          children: [
            // Full playground background
            Positioned.fill(
              child: Assets.images.fullplayground.image(fit: BoxFit.cover),
            ),
            // Semi-transparent overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ),
            ),

            // Show message if no teams selected
            if (teamAPlayers.isEmpty && teamBPlayers.isEmpty)
              Positioned.fill(
                child: Center(
                  child: Container(
                    margin: EdgeInsets.all(32.w),
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.groups_outlined,
                          color: Colors.orange,
                          size: 48.r,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'Teams Not Ready',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'Both players need to select their teams before the match can begin.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Team A widgets - only show if there are players or if we want to show "not ready"
            if (teamAPlayers.isNotEmpty ||
                (teamAPlayers.isEmpty && teamBPlayers.isNotEmpty)) ...[
              // Team A label
              if (teamAPlayers.isNotEmpty)
                Positioned(
                  top: 16.h,
                  left: 16.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      playerAScore?.teamName ?? 'Team A',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Team A players
              ...teamAPlayers.map((player) {
                final idx = teamAPlayers.indexOf(player);
                return _positionPlayer(
                  idx,
                  teamAPlayers.length,
                  player.name,
                  '${player.score}',
                  Assets.icons.gercy1,
                  isTopTeam: true,
                );
              }).toList(),

              // Team A not ready message
              if (teamAPlayers.isEmpty)
                Positioned(
                  top: 100.h,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        '${playerAScore?.teamName ?? "Team A"} - Not Ready',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],

            // Team B widgets - only show if there are players or if we want to show "not ready"
            if (teamBPlayers.isNotEmpty ||
                (teamBPlayers.isEmpty && teamAPlayers.isNotEmpty)) ...[
              // Team B label
              if (teamBPlayers.isNotEmpty)
                Positioned(
                  bottom: 16.h,
                  right: 16.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      playerBScore?.teamName ?? 'Team B',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Team B players
              ...teamBPlayers.map((player) {
                final idx = teamBPlayers.indexOf(player);
                return _positionPlayer(
                  idx,
                  teamBPlayers.length,
                  player.name,
                  '${player.score}',
                  Assets.icons.gercy2,
                  isTopTeam: false,
                );
              }).toList(),

              // Team B not ready message
              if (teamBPlayers.isEmpty)
                Positioned(
                  bottom: 100.h,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        '${playerBScore?.teamName ?? "Team B"} - Not Ready',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _positionPlayer(
    int index,
    int totalPlayers,
    String name,
    String points,
    AssetGenImage jersey, {
    required bool isTopTeam,
  }) {
    // Calculate positions based on index
    double? top, bottom, left, right;

    if (isTopTeam) {
      if (index == 0) {
        top = 140.h;
        left = 60.w;
      } else if (index == 1) {
        top = 140.h;
        right = 60.w;
      } else if (index == 2) {
        top = 60.h;
        left = 30.w;
      } else if (index == 3) {
        top = 60.h;
        left = 0.w;
        right = 0.w;
      } else if (index == 4) {
        top = 60.h;
        right = 30.w;
      }
    } else {
      if (index == 0) {
        bottom = 140.h;
        left = 60.w;
      } else if (index == 1) {
        bottom = 140.h;
        right = 60.w;
      } else if (index == 2) {
        bottom = 60.h;
        left = 30.w;
      } else if (index == 3) {
        bottom = 60.h;
        left = 0.w;
        right = 0.w;
      } else if (index == 4) {
        bottom = 60.h;
        right = 30.w;
      }
    }

    Widget playerWidget = _buildPlayer(name, points, jersey);

    if (left != null && right != null) {
      return Positioned(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: Center(child: playerWidget),
      );
    }

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: playerWidget,
    );
  }

  Widget _buildPlayer(String name, String points, AssetGenImage jersey) {
    return SizedBox(
      width: 90.w,
      height: 107.h,
      child: Stack(
        children: [
          // Jersey image
          Positioned(
            left: 0.w,
            top: 0.h,
            child: Container(
              width: 90.w,
              height: 72.h,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: jersey.provider(),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          // Player name
          Positioned(
            left: 5.w,
            top: 66.h,
            right: 5.w,
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFFECD56),
                fontSize: 9.sp,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Points badge
          Positioned(
            left: 35.w,
            top: 85.h,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: ShapeDecoration(
                color: const Color(0xFF1A1A1A),
                shape: RoundedRectangleBorder(
                  side: BorderSide(width: 1.w, color: const Color(0xFF2C2C2C)),
                  borderRadius: BorderRadius.circular(6.r),
                ),
              ),
              child: Text(
                points,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
