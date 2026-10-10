// lib/presentation/screens/home/screens/live_score_screen.dart
import '../controllers/home_controller.dart';
import '../../../../data/services/jersey_service.dart';
import '../../../../controllers/my_leagues_controller.dart';
import '../../../../core/utils/logo_assets.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../../../../data/models/live_score_model.dart';
import '../../../../core/utils/lineup_positions.dart';
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
    JerseyService.cached().then((i) {
      if (mounted) setState(() => _myJersey = i);
    });
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

  // The user's saved jersey, for the Global League court (own five only).
  int _myJersey = 0;

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
                      ? _buildDuelView(controller.matches.toList())
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
        child: (_isDuel
                ? logoAsset(MyLeaguesController.logoFor(widget.leagueId, isPrivate: widget.isPrivate))
                : Assets.icons.earth)
            .image(
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
                  Assets.icons.livematch.image(
                    width: 56.r,
                    height: 56.r,
                    fit: BoxFit.contain,
                  ),
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

  // Matches whose lineups are folded out; the user's own (first) starts open.
  final Set<String> _expanded = {};
  bool _expandedInit = false;

  Widget _buildDuelView(List<LiveMatchScore> all) {
    // Live keeps the night until the 09:00 publication (QA #9 12.2): the
    // message only shows when no match of the night is left to display.
    final shown = all.where((m) => m.hasLiveGames).toList();
    if (shown.isEmpty) return _buildNoLiveState();

    if (!_expandedInit) {
      _expandedInit = true;
      _expanded.add(shown.first.matchId);
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          if (shown.any((m) => m.isStale)) _buildStaleBanner(),
          for (var i = 0; i < shown.length; i++) ...[
            _buildDuelSection(shown[i]),
            SizedBox(height: 16.h),
          ],
        ],
      ),
    );
  }

  Widget _buildDuelSection(LiveMatchScore match) {
    final home = match.homeTeamName ?? '${AppString.team.tr} A';
    final away = match.awayTeamName ?? '${AppString.team.tr} B';
    final open = _expanded.contains(match.matchId);
    return Column(
      children: [
        MatchStatusBadge(
          status: match.matchStatus == 'completed' ? 'completed' : 'live',
        ),
        SizedBox(height: 8.h),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            open ? _expanded.remove(match.matchId) : _expanded.add(match.matchId);
          }),
          child: _buildMatchCard(
            home,
            away,
            match.homeScore.round(),
            match.awayScore.round(),
          ),
        ),
        Icon(
          open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: Colors.white54,
          size: 20.r,
        ),
        if (open)
          MatchLineupsField(
            showSummary: false, // Live does not reveal bonuses
            teamA: _toSquad(home, match.homePlayers, jersey: match.homeJerseyIndex),
            teamB: _toSquad(away, match.awayPlayers, jersey: match.awayJerseyIndex),
          ),
      ],
    );
  }

  Widget _buildGlobalView(LiveGlobalScore? score) {
    if (score == null || !score.hasLiveGames) return _buildNoLiveState();

    // The user's own team name, as in the Results tab.
    final name = Get.isRegistered<HomeController>() &&
            Get.find<HomeController>().userProfile.value?.teamName.isNotEmpty == true
        ? Get.find<HomeController>().userProfile.value!.teamName
        : AppString.myTeam.tr;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          if (score.isStale) _buildStaleBanner(),
          const MatchStatusBadge(status: 'live'),
          SizedBox(height: 12.h),
          if (score.players.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 32.h),
              child: Text(
                AppString.noLineupTonight.tr,
                style: TextStyle(color: Colors.white54, fontSize: 14.sp),
              ),
            )
          else ...[
            // Same layout as the Global League Results tab: full court, name on
            // the left, "X Points" pill below with the live total.
            MatchLineupsField(
              teamA: _toSquad(name, score.players, jersey: _myJersey),
              teamB: null,
              showOpponent: false,
              showSummary: false,
              totalPill: score.totalScore.round(),
            ),
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

  /// The court draws the five starters by position; the 6th man rides along
  /// flagged, and the lineup widget lists him under the court.
  PlayerScore _toSquad(String teamName, List<LivePlayerScore> players,
      {int jersey = 0}) {
    final starters = inCourtOrder(
      players.where((p) => !p.isSixthMan).take(5).toList(),
      (p) => p.position,
    );
    final sixth = players.where((p) => p.isSixthMan).toList();
    PlayerSelection toSel(LivePlayerScore p, {bool sixth = false}) =>
        PlayerSelection(
          id: p.playerId,
          name: p.fullName,
          position: p.position ?? '',
          score: p.fantasyScoreLive.round(),
          isSixthMan: sixth,
        );
    return PlayerScore(
      playerId: 0,
      teamName: teamName,
      username: '',
      totalPoints:
          starters.fold(0, (sum, p) => sum + p.fantasyScoreLive.round()),
      selection: [
        for (final p in starters) toSel(p),
        for (final p in sixth) toSel(p, sixth: true),
      ],
      jerseyIndex: jersey,
      isMe: true,
    );
  }
}
