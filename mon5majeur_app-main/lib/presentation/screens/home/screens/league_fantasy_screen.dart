import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:mon5majeur_app/core/constants/app_strings.dart';
import 'package:mon5majeur_app/core/constants/feature_flags.dart';
import 'package:mon5majeur_app/core/custom_assets/assets.gen.dart';
import '../tabs/build_your_team_tab.dart';
import '../tabs/leaderboard_tab.dart';
import '../tabs/result_tab.dart';
import '../tabs/rules_tab.dart';
import '../widgets/league_tab_bar.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/local_db/local_db.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../../../../data/models/match_result_model.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';

/// A single reusable fantasy-league shell used by private, public, and
/// joined-league screens. Pass [leagueId] + [matchDay] when the league has
/// already started so the tab widgets can load real data.
class LeagueFantasyScreen extends StatefulWidget {
  final int? leagueId;
  final int? matchDay;
  final bool isPrivate;
  final String backRoute;
  final String leagueTypeLabel;
  final bool showBudgetBonus;
  // Tab to open on (see LeagueTab). QA 24/09 #3: the home "Résultats de la
  // nuit" card opens the league straight on its Standings tab.
  final int initialTab;

  const LeagueFantasyScreen({
    super.key,
    this.leagueId,
    this.matchDay,
    this.isPrivate = false,
    required this.backRoute,
    required this.leagueTypeLabel,
    this.showBudgetBonus = false,
    this.initialTab = LeagueTab.createTeam,
  });

  @override
  State<LeagueFantasyScreen> createState() => _LeagueFantasyScreenState();
}

class _LeagueFantasyScreenState extends State<LeagueFantasyScreen> {
  late int _selectedTab = widget.initialTab;
  Key _resultKey = UniqueKey();
  bool _openingLive = false;

  /// "Live" tab: the live score of MY duel in this league on the current
  /// match day (Global League's Live shows every player instead). The duel id
  /// comes from the match result; without one there is nothing live to show.
  Future<void> _openLive() async {
    if (_openingLive) return;
    final leagueId = widget.leagueId;
    final matchDay = widget.matchDay;
    String? matchId;
    if (leagueId != null && matchDay != null && matchDay > 0) {
      setState(() => _openingLive = true);
      try {
        final endpoint = widget.isPrivate
            ? ApiUrl.privateMatchResult(leagueId, matchDay)
            : ApiUrl.publicMatchResult(leagueId, matchDay);
        final response = await ApiClient().get(url: '${ApiUrl.baseUrl}$endpoint');
        if (response.statusCode == 200) {
          final result = MatchResultModel.fromJson(response.body);
          final me = int.tryParse(await SharedPrefsHelper.getString(AppConstants.userId));
          for (final pair in result.pairs) {
            if (me != null && (pair.playerAId == me || pair.playerBId == me)) {
              matchId = pair.matchObjectId;
              break;
            }
          }
        }
      } catch (_) {
        // fall through to the "no live match" message
      } finally {
        if (mounted) setState(() => _openingLive = false);
      }
    }
    if (!mounted) return;
    if (matchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No live match for this matchday yet.'.tr)),
      );
      return;
    }
    context.push('${RoutePath.liveScoreScreen.addBasePath}?matchId=$matchId');
  }

  void _onTeamSaved() {
    setState(() {
      _resultKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            LeagueTabBar(
              selected: _selectedTab,
              onSelect: (i) => setState(() => _selectedTab = i),
              onLive: _openLive,
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  BuildYourTeamTab(
                    leagueId: widget.leagueId,
                    matchDay: widget.matchDay,
                    isPrivate: widget.isPrivate,
                    onTeamSaved: _onTeamSaved,
                  ),
                  ResultTab(
                    key: _resultKey,
                    leagueId: widget.leagueId,
                    matchDay: widget.matchDay,
                    isPrivate: widget.isPrivate,
                  ),
                  LeaderboardTab(
                    leagueId: widget.leagueId,
                    isPrivate: widget.isPrivate,
                  ),
                  const RulesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // QA 24/09 #5: same uniform dark header as the Global League (no orange
    // gradient banner).
    return Container(
      width: double.infinity,
      color: const Color(0xFF1A1C2A),
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => context.go(widget.backRoute),
                child: SizedBox(
                  width: 30.w,
                  height: 30.h,
                  child: Assets.icons.backButton.image(fit: BoxFit.contain),
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLeagueLogo(),
                    SizedBox(height: 4.h),
                    Text(
                      AppString.eliteBallers.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontFamily: 'Lato',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      widget.leagueTypeLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8.sp,
                        fontFamily: 'Lato',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 30.w),
            ],
          ),
          if (kAdsEnabled && widget.showBudgetBonus && _selectedTab == 0) ...[
            SizedBox(height: 12.h),
            Align(
              alignment: Alignment.centerRight,
              child: _buildBudgetBonus(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLeagueLogo() {
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
        child: Assets.icons.logo1.image(
          width: 16.w,
          height: 18.h,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildBudgetBonus() {
    return Container(
      height: 23.h,
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: ShapeDecoration(
        gradient: const LinearGradient(
          begin: Alignment(0.00, 0.50),
          end: Alignment(1.00, 0.50),
          colors: [Color(0xFF2A2A2A), Color(0xFF1F1F1F)],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Assets.icons.play.image(width: 8.w, height: 8.h),
          SizedBox(width: 4.w),
          Text(
            AppString.getExtraBudget.tr,
            style: TextStyle(color: Colors.white, fontSize: 8.sp),
          ),
          SizedBox(width: 4.w),
          Text('🎉', style: TextStyle(fontSize: 8.sp)),
        ],
      ),
    );
  }

}
