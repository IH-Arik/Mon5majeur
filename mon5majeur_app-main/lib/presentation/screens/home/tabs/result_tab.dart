// lib/presentation/screens/home/my_league_screens/tabs/result.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../../../../data/models/match_result_model.dart';
import '../controllers/result_controller.dart';
import '../widgets/match_lineups_field.dart';
import '../../../widgets/match_widgets.dart';

class ResultTab extends StatefulWidget {
  final int? leagueId;
  final int? matchDay;
  final bool isPrivate; // ADD THIS
  final bool isGlobal;

  const ResultTab({
    super.key,
    this.leagueId,
    this.matchDay,
    this.isPrivate = false, // ADD THIS
    this.isGlobal = false,
  });

  @override
  State<ResultTab> createState() => _ResultTabState();
}

class _ResultTabState extends State<ResultTab> {
  late final ResultController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(ResultController());
    if (widget.isGlobal) {
      controller.setGlobalLeague(initialMatchDay: widget.matchDay);
    } else if (widget.leagueId != null) {
      controller.setLeagueId(
        widget.leagueId!,
        initialMatchDay: widget.matchDay,
        type: widget.isPrivate
            ? LeagueType.private
            : LeagueType.public, // ADD THIS
      );
    } else {
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
                AppString.noMatchesToday.tr,
                style: TextStyle(color: Colors.white54, fontSize: 16.sp),
              ),
            ],
          ),
        );
      }

      final matchData = controller.matchResult.value!;
      if (widget.isGlobal || matchData.matchType == 'global_night') {
        return _buildGlobalResults(matchData);
      }

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

  Widget _buildGlobalResults(MatchResultModel matchData) {
    final rankings = [...matchData.playerScores]
      ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

    if (rankings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard_outlined, color: Colors.white54, size: 48.r),
            SizedBox(height: 16.h),
            Text(
              AppString.noMatchesToday.tr,
              style: TextStyle(color: Colors.white54, fontSize: 16.sp),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          SizedBox(height: 16.h),
          _buildMatchdaySelector(),
          SizedBox(height: 16.h),
          _buildMatchInfo(matchData),
          SizedBox(height: 16.h),
          ...rankings.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final score = entry.value;
            final isMe = score.playerId == controller.currentUserId;
            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: ShapeDecoration(
                  gradient: LinearGradient(
                    colors: isMe
                        ? const [Color(0xFF2E2118), Color(0xFF1A1713)]
                        : const [Color(0xFF20222B), Color(0xFF14151C)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      width: 1.w,
                      color: isMe
                          ? const Color(0xFFE8632C)
                          : const Color(0xFF2C2C2C),
                    ),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34.w,
                      height: 34.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: rank <= 3
                            ? const Color(0xFFE8632C)
                            : const Color(0xFF2C2C2C),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            score.teamName.isNotEmpty
                                ? score.teamName
                                : score.username,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            isMe ? '${AppString.you.tr} • ${score.username}' : score.username,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${score.totalPoints}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'PTS',
                          style: TextStyle(
                            color: const Color(0xFFFF8C42),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: 16.h),
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

  Widget _buildMatchInfo(MatchResultModel matchResult) {
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
        MatchStatusBadge(
          status: matchResult.status == 'scheduled' ? 'upcoming' : matchResult.status,
        ),
      ],
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
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Score — NBA-style face, or the paywall placeholder when
                    // the server is withholding a non-subscriber's numbers.
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      child: (controller.matchResult.value?.scoresHidden ?? false)
                          ? const ScoreLockedLabel()
                          : ScoreLine(scoreA: pair.scoreA, scoreB: pair.scoreB),
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
                if (isCurrentUser &&
                    controller.matchResult.value?.status == 'live' &&
                    pair.matchObjectId != null) ...[
                  SizedBox(height: 8.h),
                  _buildWatchLiveButton(pair.matchObjectId!),
                ],
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: isExpanded
                ? MatchLineupsField(
                        teamA: playerAScore,
                        teamB: playerBScore,
                        scoresHidden:
                            controller.matchResult.value?.scoresHidden ?? false,
                      )
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

  Widget _buildWatchLiveButton(String matchObjectId) {
    return GestureDetector(
      onTap: () {
        context.push(
          '${RoutePath.liveScoreScreen.addBasePath}?matchId=$matchObjectId',
        );
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: ShapeDecoration(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Colors.green),
            borderRadius: BorderRadius.circular(6.r),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt, color: Colors.green, size: 14.r),
            SizedBox(width: 6.w),
            Text(
              AppString.watchLive.tr,
              style: TextStyle(
                color: Colors.green,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
}
