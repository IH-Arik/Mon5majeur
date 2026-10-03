// lib/presentation/screens/home/screens/live_score_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../../../../data/models/live_score_model.dart';
import '../../../../data/models/match_result_model.dart';
import '../../../widgets/match_widgets.dart';
import '../controllers/live_score_controller.dart';
import '../widgets/league_tab_bar.dart';
import '../widgets/match_lineups_field.dart';

/// Live Score screen (spec §4.5), built like the league Results tab (QA 28/09
/// #4): league header, the league tab bar, a match card and the lineups on the
/// court, fed by the live endpoint and refreshed every 60s. A duel shows both
/// teams; the Global League shows the user's own five. Premium-gated: the
/// premium 403 renders an upsell. When nothing is being played it says so
/// instead of showing a finished 0-0 match.
///
/// Tapping one of the league tabs pops this screen with that tab's index, and
/// the league screen underneath switches to it.
class LiveScoreScreen extends StatefulWidget {
  final LiveScoreMode mode;
  final String? matchId;
  final int? leagueId;
  final int? matchDay;
  final bool isPrivate;

  const LiveScoreScreen({
    super.key,
    required this.mode,
    this.matchId,
    this.leagueId,
    this.matchDay,
    this.isPrivate = false,
  });

  @override
  State<LiveScoreScreen> createState() => _LiveScoreScreenState();
}

class _LiveScoreScreenState extends State<LiveScoreScreen> {
  late final LiveScoreController controller;
  late final String _tag;

  @override
  void initState() {
    super.initState();
    _tag = widget.mode == LiveScoreMode.duel
        ? 'live_${widget.matchId ?? '${widget.leagueId}_${widget.matchDay}'}'
        : 'live_global';
    controller = Get.put(
      LiveScoreController(
        mode: widget.mode,
        matchId: widget.matchId,
        leagueId: widget.leagueId,
        matchDay: widget.matchDay,
        isPrivate: widget.isPrivate,
      ),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    Get.delete<LiveScoreController>(tag: _tag);
    super.dispose();
  }

  bool get _isDuel => widget.mode == LiveScoreMode.duel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          children: [
            Obx(_buildHeader),
            LeagueTabBar(
              selected: -1,
              liveActive: true,
              onSelect: (i) => context.pop(i),
              onLive: controller.fetch,
            ),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF8C42)),
                  );
                }
                if (controller.isForbidden.value) {
                  return _buildLockedState();
                }
                if (controller.errorMessage.value != null) {
                  return _buildErrorState(controller.errorMessage.value!);
                }
                return RefreshIndicator(
                  onRefresh: controller.fetch,
                  color: const Color(0xFFFF8C42),
                  backgroundColor: const Color(0xFF252838),
                  child: _isDuel
                      ? _buildDuelView(controller.matchScore.value)
                      : _buildGlobalView(controller.globalScore.value),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // Same header as the league screens: logo, league name 14sp, 10sp line
  // under it, back button on the left.
  Widget _buildHeader() {
    // Both observables are always read: an Obx that reads none throws, and in
    // a release build that is the plain grey screen QA 28/09/#8 #7 reported
    // on the Global League (only the duel branch used to touch an Rx).
    final duelName = controller.matchScore.value?.leagueName;
    final resolvedName = controller.leagueName.value;
    final name = _isDuel
        ? (duelName != null && duelName.isNotEmpty ? duelName : resolvedName)
        : AppString.globalLeague.tr;
    return Container(
      width: double.infinity,
      color: const Color(0xFF1A1C2A),
      padding: EdgeInsets.all(16.w),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 36.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _leagueLogo(),
                  SizedBox(height: 4.h),
                  if (name.isNotEmpty)
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontFamily: 'Lato',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  SizedBox(height: 2.h),
                  Text(
                    AppString.liveScoreTitle.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.sp,
                      fontFamily: 'Lato',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              child: GestureDetector(
                onTap: () => context.pop(),
                child: SizedBox(
                  width: 30.w,
                  height: 30.h,
                  child: Assets.icons.backButton.image(fit: BoxFit.contain),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leagueLogo() {
    return Container(
      width: 35.w,
      height: 36.h,
      decoration: ShapeDecoration(
        color: const Color(0xFF1A1A1A),
        shape: OvalBorder(
          side: BorderSide(width: 1.r, color: const Color(0xFFB0B0B0)),
        ),
      ),
      child: Center(
        child: (_isDuel ? Assets.icons.logo1 : Assets.icons.earth).image(
          width: 16.w,
          height: 18.h,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildLockedState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 64.w,
              height: 64.h,
              child: Assets.icons.lock.image(fit: BoxFit.contain),
            ),
            SizedBox(height: 20.h),
            Text(
              AppString.liveScoreLockedTitle.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              AppString.liveScoreLockedDesc.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13.sp),
            ),
            SizedBox(height: 24.h),
            GestureDetector(
              onTap: () => context.go(RoutePath.shopScreen.addBasePath),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
                decoration: ShapeDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE8632C), Color(0xFFFF8A50)],
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  AppString.unlockNow.tr,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.white54, size: 48.r),
                SizedBox(height: 16.h),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 14.sp),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStaleBanner() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: ShapeDecoration(
        color: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
          side: const BorderSide(color: Color(0xFF3A3A3A)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: Colors.white54, size: 16.r),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              AppString.staleDataNotice.tr,
              style: TextStyle(color: Colors.white54, fontSize: 11.sp),
            ),
          ),
        ],
      ),
    );
  }

  // ── Views ────────────────────────────────────────────────────────────────

  /// Nothing is being played: a clear message, still pull-to-refresh.
  Widget _buildNoLiveState() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Assets.icons.livescoring.image(width: 40.r, height: 40.r),
                  SizedBox(height: 16.h),
                  Text(
                    AppString.noLiveMatchNow.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    AppString.noLiveMatchHint.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDuelView(LiveMatchScore? match) {
    // A finished (or not yet started) duel is not "live": the Results tab
    // already shows it.
    if (match == null || match.matchStatus != 'live') {
      return _buildNoLiveState();
    }

    final home = match.homeTeamName ?? '${AppString.team.tr} A';
    final away = match.awayTeamName ?? '${AppString.team.tr} B';
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          if (match.isStale) _buildStaleBanner(),
          const MatchStatusBadge(status: 'live'),
          SizedBox(height: 12.h),
          _buildMatchCard(
            home,
            away,
            match.homeScore.round(),
            match.awayScore.round(),
          ),
          MatchLineupsField(
            teamA: _toSquad(home, match.homePlayers),
            teamB: _toSquad(away, match.awayPlayers),
          ),
          ..._sixthManRows(home, match.homePlayers),
          ..._sixthManRows(away, match.awayPlayers),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  Widget _buildGlobalView(LiveGlobalScore? score) {
    if (score == null || !score.hasLiveGames) return _buildNoLiveState();

    final name = AppString.myTeam.tr;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          if (score.isStale) _buildStaleBanner(),
          const MatchStatusBadge(status: 'live'),
          SizedBox(height: 12.h),
          _cardShell(
            child: Column(
              children: [
                Text(
                  score.totalScore.toStringAsFixed(0),
                  style: TextStyle(
                    color: const Color(0xFFFF8C42),
                    fontSize: 36.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  AppString.pts.tr,
                  style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                ),
              ],
            ),
          ),
          if (score.players.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 32.h),
              child: Text(
                AppString.noLineupSubmitted.tr,
                style: TextStyle(color: Colors.white54, fontSize: 14.sp),
              ),
            )
          else ...[
            MatchLineupsField(
              teamA: _toSquad(name, score.players),
              teamB: null,
              showOpponent: false,
            ),
            ..._sixthManRows(name, score.players),
          ],
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  // Same card as the Results tab's match card: both teams and the score.
  Widget _buildMatchCard(String home, String away, int homeScore, int awayScore) {
    return _cardShell(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                _teamLogo(),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    home,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: ScoreLine(scoreA: homeScore, scoreB: awayScore),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    away,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                _teamLogo(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardShell({required Widget child}) {
    return Container(
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
      child: child,
    );
  }

  Widget _teamLogo() {
    return Container(
      width: 32.w,
      height: 32.w,
      decoration: ShapeDecoration(
        color: const Color(0xFF1A1A1A),
        shape: OvalBorder(
          side: BorderSide(width: 1.w, color: const Color(0xFFB0B0B0)),
        ),
      ),
      child: Center(child: Assets.icons.logo1.image(width: 16.w, height: 18.h)),
    );
  }

  // ── Live data → the Results tab's court model ────────────────────────────

  /// The court draws five players; the 6th man is listed under it.
  PlayerScore _toSquad(String teamName, List<LivePlayerScore> players) {
    final starters = players.where((p) => !p.isSixthMan).take(5).toList();
    return PlayerScore(
      playerId: 0,
      teamName: teamName,
      username: '',
      totalPoints:
          starters.fold(0, (sum, p) => sum + p.fantasyScoreLive.round()),
      selection: [
        for (final p in starters)
          PlayerSelection(
            id: p.playerId,
            name: p.fullName,
            position: p.position ?? '',
            score: p.fantasyScoreLive.round(),
          ),
      ],
    );
  }

  List<Widget> _sixthManRows(String teamName, List<LivePlayerScore> players) {
    return [
      for (final p in players.where((p) => p.isSixthMan))
        Container(
          width: double.infinity,
          constraints: BoxConstraints(maxWidth: 362.w),
          margin: EdgeInsets.only(top: 8.h),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: ShapeDecoration(
            color: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0xFF2C2C2C)),
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$teamName · ${AppString.sixthMan.tr}: ${p.fullName}'
                  '${p.isCounted ? '' : ' (${AppString.sixthManDropped.tr})'}',
                  style: TextStyle(
                    color: p.isCounted ? Colors.white : Colors.white38,
                    fontSize: 11.sp,
                  ),
                ),
              ),
              Text(
                p.fantasyScoreLive.toStringAsFixed(0),
                style: TextStyle(
                  color: p.isCounted ? Colors.white : Colors.white38,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
    ];
  }
}
