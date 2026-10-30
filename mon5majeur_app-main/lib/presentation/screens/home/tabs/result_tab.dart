// lib/presentation/screens/home/my_league_screens/tabs/result.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/datetime_format.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../../../../data/models/match_result_model.dart';
import '../controllers/result_controller.dart';
import '../widgets/match_lineups_field.dart';
import '../widgets/night_top_builder.dart';
import '../../../widgets/match_widgets.dart';
import '../../../../core/constants/feature_flags.dart';
import '../../../../data/services/night_top_scores.dart';
import '../../share/share_story_button.dart';
import '../../share/share_story_from_duel.dart';
import '../../../../core/utils/logo_assets.dart';

class ResultTab extends StatefulWidget {
  final int? leagueId;
  final int? matchDay;
  final bool isPrivate; // ADD THIS
  final bool isGlobal;

  /// Opens the league's Live screen (every duel of the day).
  final VoidCallback? onOpenLive;

  /// False while another tab of the league is shown: the tab stays alive in
  /// the IndexedStack but must not refresh itself then.
  final bool isActive;

  const ResultTab({
    super.key,
    this.leagueId,
    this.matchDay,
    this.isPrivate = false, // ADD THIS
    this.isGlobal = false,
    this.onOpenLive,
    this.isActive = true,
  });

  @override
  State<ResultTab> createState() => _ResultTabState();
}

class _ResultTabState extends State<ResultTab> with WidgetsBindingObserver {
  /// A day still in progress is fetched again this often while it is on screen.
  static const Duration _refreshEvery = Duration(minutes: 5);

  late final ResultController controller;
  Timer? _refreshTimer;

  bool get _published => controller.matchResult.value?.status == 'completed';

  /// Silent refresh of the day on screen, only while it is not published yet.
  void _refreshIfInProgress() {
    if (!mounted || !widget.isActive || widget.isGlobal) return;
    if (controller.matchResult.value == null || controller.isLoading.value) {
      return;
    }
    if (_published) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      return;
    }
    controller.fetchMatchResult(silent: true);
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    if (widget.isGlobal || !widget.isActive) return;
    _refreshTimer = Timer.periodic(_refreshEvery, (_) => _refreshIfInProgress());
  }

  @override
  void didUpdateWidget(covariant ResultTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive == oldWidget.isActive) return;
    if (widget.isActive) {
      _startTimer();
      _refreshIfInProgress(); // back on the tab
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshIfInProgress();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    _startTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    controller.leave(); // nothing more is loaded once the tab is left
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Full-screen spinner only when there is nothing at all to show yet.
      if (controller.isLoading.value && controller.matchResult.value == null) {
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

      // A day that is not cached is loading: the selector stays, the body
      // waits; a cached day shown while refreshing keeps its body.
      final loadingDay = controller.isLoading.value;
      final busy = loadingDay || controller.isRefreshing.value;
      return SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            // Thin, discreet progress bar while a day loads or refreshes.
            SizedBox(
              height: 2.h,
              child: busy
                  ? LinearProgressIndicator(
                      color: const Color(0xFFFF6B3D),
                      backgroundColor: Colors.transparent,
                    )
                  : null,
            ),
            SizedBox(height: 14.h),
            _buildMatchdaySelector(),
            SizedBox(height: 16.h),
            if (!loadingDay) ...[
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
                controller.phaseLabelFor(controller.currentMatchDay.value) ??
                    '${AppString.matchday.tr} ${controller.currentMatchDay.value}',
                style: TextStyle(
                  color: const Color(0xFFB1B1B1),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Obx(() {
              // Stops at the last match day known for the league.
              final bound = controller.lastMatchDay.value;
              final canNext =
                  bound == null || controller.currentMatchDay.value < bound;
              return IconButton(
                onPressed: canNext ? controller.nextMatchDay : null,
                icon: Icon(
                  Icons.chevron_right,
                  color: canNext
                      ? const Color(0xFFB1B1B1)
                      : Colors.grey.shade700,
                  size: 24.r,
                ),
              );
            }),
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
      final result = controller.matchResult.value;
      final published = result?.status == 'completed';
      final serverHidden = result?.scoresHidden ?? false;
      // Live numbers belong to the Live screen: until the 09:00 publication
      // the card shows the lock, for everyone.
      final hideScores = serverHidden || !published;
      final started = result?.started ?? (result?.status != 'scheduled');

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
                          _buildTeamLogo(playerAScore?.teamLogo),
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
                      child: hideScores
                          // A Live Scoring subscriber has the live: the lock
                          // says where it is and when the official one comes.
                          ? ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: 110.w),
                              child: ScoreLockedLabel(
                                text: serverHidden
                                    ? null
                                    : (result?.status == 'live'
                                        ? AppString.liveScoreInLiveTab
                                            .trParams(publicationTimeParams())
                                        : AppString.scoreNotStarted.tr),
                              ),
                            )
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
                          _buildTeamLogo(playerBScore?.teamLogo),
                        ],
                      ),
                    ),
                  ],
                ),
                // The server gives a tie to the home team (the left one);
                // nothing else says why a 168-168 has a winner.
                if (published && !serverHidden && pair.scoreA == pair.scoreB) ...[
                  SizedBox(height: 6.h),
                  Text(
                    AppString.tieHomeWins.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 10.sp),
                  ),
                ],
                SizedBox(height: 8.h),
                _buildViewDetailsButton(index),
                // Shown once the day is published, for my own duel only.
                if (kShareStoryEnabled &&
                    isCurrentUser &&
                    published &&
                    !serverHidden &&
                    result != null) ...[
                  SizedBox(height: 4.h),
                  ShareStoryButton(
                    buildStory: () async => shareStoryFromDuel(
                      result: result,
                      pair: pair,
                      teamA: playerAScore,
                      teamB: playerBScore,
                      iAmHome: controller.currentUserId == pair.playerAId,
                      // Waits for the ranking: no badge missing.
                      medals: await NightTopScores.forDate(result.matchDate),
                      phaseLabel: controller.phaseLabelFor(result.matchDay),
                    ),
                  ),
                ],
                if (isCurrentUser &&
                    !published &&
                    started &&
                    !serverHidden &&
                    widget.onOpenLive != null) ...[
                  SizedBox(height: 8.h),
                  _buildWatchLiveButton(widget.onOpenLive!),
                ],
                // No Live Scoring: the same button leads to the premium
                // screen, with a reassuring line about the 9 AM results.
                if (isCurrentUser &&
                    !published &&
                    started &&
                    serverHidden) ...[
                  SizedBox(height: 8.h),
                  _buildWatchLiveButton(
                    () => context.go(RoutePath.shopScreen.addBasePath),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    AppString.resultsAt9WithCoffee.trParams(publicationTimeParams()),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 10.sp),
                  ),
                ],
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: isExpanded
                ? NightTopBuilder(
                    date: controller.matchResult.value?.matchDate,
                    builder: (medals) => MatchLineupsField(
                        teamA: playerAScore,
                        teamB: playerBScore,
                        medals: hideScores ? null : medals,
                        scoresHidden: hideScores,
                        duelResultStyle: true,
                        matchFinished:
                            controller.matchResult.value?.status == 'completed',
                        // Replaced by `started` from the server once exposed.
                        matchStarted:
                            controller.matchResult.value?.started ??
                            (controller.matchResult.value?.status !=
                                'scheduled'),
                      ),
                  )
                : SizedBox.shrink(),
          ),
        ],
      );
    });
  }

  Widget _buildTeamLogo(String? teamLogo) {
    // The team's own saved avatar (QA #9 11.2: every team showed the devil).
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
        child: logoAsset(teamLogo).image(width: 20.w, height: 20.w, fit: BoxFit.contain),
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

  Widget _buildWatchLiveButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
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
