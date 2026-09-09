import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/feature_flags.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../../../../controllers/global_league_controller.dart';
import '../../../../data/models/player.dart';
import '../tabs/build_your_team_global_tab.dart';
import '../tabs/global_leaderboard_tab.dart';
import '../tabs/my_team_tab.dart';
import '../tabs/rules_tab.dart';

class GlobalLeagueScreen extends StatefulWidget {
  const GlobalLeagueScreen({super.key});

  @override
  State<GlobalLeagueScreen> createState() => _GlobalLeagueScreenState();
}

class _GlobalLeagueScreenState extends State<GlobalLeagueScreen> {
  int _selectedTab = 0;
  Key _resultKey = UniqueKey();

  late final GlobalLeagueController _controller; // ADD THIS

  @override
  void initState() {
    super.initState();
    // Initialize or get existing controller
    _controller = Get.put(GlobalLeagueController());
  }

  void _onTeamSaved() {
    // Refresh the Results tab (the saved squad) with a new key
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
            _buildTabBar(),
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  BuildYourTeamTabGlobal(
                    onTeamSaved: _onTeamSaved, // ADD THIS
                  ),
                  // QA4 #4: this tab used to render ResultTab(isGlobal: true),
                  // which showed a user ranking - exactly the Classement
                  // tab's content, duplicated. Résultats must show the
                  // player's OWN lineup with per-player and nightly points
                  // instead, so it now renders the same squad view that
                  // used to live behind a separate, redundant "My Team" tab
                  // (removed per QA4 #2). MyTeamTab only fetches a saved
                  // team when given a leagueId + matchDay (the private/
                  // public league path) - the Global League has neither, so
                  // the squad GlobalLeagueController already fetches on
                  // join is handed in directly, padded to 5 slots so
                  // _buildPlayerWithPoints's fixed indices (0-4) never run
                  // off the end of a shorter list.
                  Obx(() {
                    final squad = List<Player?>.filled(5, null);
                    for (
                      var i = 0;
                      i < _controller.selectedPlayers.length && i < 5;
                      i++
                    ) {
                      squad[i] = _controller.selectedPlayers[i];
                    }
                    return MyTeamTab(key: _resultKey, savedPlayers: squad);
                  }),
                  const LeaderboardTab(),
                  const RulesTab(isGlobal: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Obx(() {
      // Make header reactive to controller changes
      final matchDay = _controller.currentMatchDay.value;

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
                  // QA4 #5: the title block must be centered on the full
                  // header width, not between the back button and a
                  // "100M" balance box of unequal width (that box is
                  // removed - it duplicated info already on the budget
                  // bar and had no label). A Stack + Positioned back
                  // button keeps the title independently centered
                  // regardless of what (if anything) sits at the edges.
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLeagueLogo(),
                      SizedBox(height: 4.h),
                      Text(
                        AppString.globalLeague.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontFamily: 'Lato',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (matchDay > 0) ...[
                        SizedBox(height: 2.h),
                        Text(
                          '${AppString.matchday.tr} $matchDay',
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
                  Positioned(
                    left: 0,
                    child: GestureDetector(
                      onTap: () => context.go(RoutePath.home.addBasePath),
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
            if (kAdsEnabled && _selectedTab == 0) ...[
              SizedBox(height: 12.h),
              Align(
                alignment: Alignment.centerRight,
                child: _buildBudgetBonus(),
              ),
            ],
          ],
        ),
      );
    });
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
        child: Assets.icons.earth.image(
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
          Assets.icons.play.image(width: 12.w, height: 12.h),
          SizedBox(width: 6.w),
          Text(
            AppString.getExtraBudget.tr,
            style: TextStyle(color: Colors.white, fontSize: 10.sp),
          ),
          SizedBox(width: 4.w),
          Text('🎉', style: TextStyle(fontSize: 12.sp)),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    // QA4 #2: the client explicitly does not want a scrollable tab bar -
    // all tabs must be visible at once, on every screen size. Removing the
    // redundant "My Team" tab (its content moved into Résultats, see
    // build()) brings this down to 5 tabs, which fit in a plain Row
    // without scrolling.
    return Container(
      color: const Color(0xFF1A1C2A),
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTab(AppString.createTeam.tr, Icons.add, 0),
          _buildTab(AppString.result.tr, Icons.scoreboard, 1),
          _buildTab(AppString.leaderboard.tr, Icons.leaderboard, 2),
          _buildTab(AppString.rules.tr, Icons.menu_book, 3),
          _buildLiveTab(),
        ],
      ),
    );
  }

  Widget _buildLiveTab() {
    // Pushed instead of switched into the IndexedStack — it polls the
    // backend every 60s and shouldn't keep doing that in the background
    // while another tab is active.
    return GestureDetector(
      onTap: () => context.push(RoutePath.liveScoreScreen.addBasePath),
      child: Container(
        color: Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        child: Column(
          children: [
            Icon(Icons.bolt, color: Colors.white54, size: 24.r),
            SizedBox(height: 4.h),
            Text(
              AppString.liveScoreTitle.tr,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4.h),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, IconData icon, int index) {
    final isActive = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        color: Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        child: Column(
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFFFF8C42) : Colors.white54,
              size: 24.r,
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFFFF8C42) : Colors.white54,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4.h),
            if (isActive)
              Container(
                width: 40.w,
                height: 3.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8C42),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
