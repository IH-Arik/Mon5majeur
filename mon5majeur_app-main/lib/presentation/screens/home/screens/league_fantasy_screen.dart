import '../../../../controllers/my_leagues_controller.dart';
import '../../../../core/utils/logo_assets.dart';
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
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../../../../data/models/standings_model.dart';
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

  /// "Live" tab: the live score of MY duel in this league on the current
  /// match day (Global League's Live shows every player instead). The screen
  /// opens at once and looks the duel up itself behind a loading state.
  Future<void> _openLive() async {
    final leagueId = widget.leagueId;
    final matchDay = widget.matchDay;
    if (leagueId == null || matchDay == null || matchDay <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppString.noLiveMatchNow.tr)),
      );
      return;
    }
    // The live screen returns the league tab the user tapped, if any.
    final tab = await context.push<int>(
      '${RoutePath.liveScoreScreen.addBasePath}'
      '?leagueId=$leagueId&matchDay=$matchDay&isPrivate=${widget.isPrivate}',
    );
    if (tab != null && mounted) setState(() => _selectedTab = tab);
  }

  String _leagueName = '';

  @override
  void initState() {
    super.initState();
    _loadLeagueName();
  }

  // Every entry route passes only the league id, so the name comes from the
  // standings endpoint (the header used to show a hardcoded "Elite Ballers").
  Future<void> _loadLeagueName() async {
    final leagueId = widget.leagueId;
    if (leagueId == null || leagueId <= 0) return;
    try {
      final endpoint = widget.isPrivate
          ? ApiUrl.privateStandings(leagueId)
          : ApiUrl.publicStandings(leagueId);
      final response = await ApiClient().get(url: '${ApiUrl.baseUrl}$endpoint');
      if (response.statusCode == 200 && mounted) {
        final name = StandingsModel.fromJson(response.body).leagueName;
        setState(() => _leagueName = name);
      }
    } catch (_) {
      // header keeps the league type label only
    }
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
    // Same header as the Global League: uniform dark background (QA 24/09 #5),
    // title centered on the full width, name 14sp, 10sp line under it.
    final matchDay = widget.matchDay ?? 0;
    final title = _leagueName.isEmpty ? widget.leagueTypeLabel : _leagueName;
    final subtitle = [
      if (_leagueName.isNotEmpty) widget.leagueTypeLabel,
      if (matchDay > 0) '${AppString.matchday.tr} $matchDay',
    ].join(' · ');
    return Container(
      width: double.infinity,
      color: const Color(0xFF1A1C2A),
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  // keeps a long league name clear of the back button
                  padding: EdgeInsets.symmetric(horizontal: 36.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLeagueLogo(),
                      SizedBox(height: 4.h),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontFamily: 'Lato',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10.sp,
                            fontFamily: 'Lato',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  child: GestureDetector(
                    onTap: () => context.go(widget.backRoute),
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
        child: logoAsset(MyLeaguesController.logoFor(widget.leagueId, isPrivate: widget.isPrivate)).image(
          width: 24.w,
          height: 24.w,
          fit: BoxFit.contain,
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
