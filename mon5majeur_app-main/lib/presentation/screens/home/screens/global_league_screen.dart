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
import '../tabs/build_your_team_global_tab.dart';
import '../tabs/global_leaderboard_tab.dart';
import '../widgets/global_published_result.dart';
import '../tabs/rules_tab.dart';
import '../widgets/league_tab_bar.dart';

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
            LeagueTabBar(
              selected: _selectedTab,
              onSelect: (i) => setState(() => _selectedTab = i),
              onLive: () async {
                // The live screen returns the league tab the user tapped.
                final tab = await context
                    .push<int>(RoutePath.liveScoreScreen.addBasePath);
                if (tab != null && mounted) setState(() => _selectedTab = tab);
              },
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedTab,
                children: [
                  BuildYourTeamTabGlobal(
                    onTeamSaved: _onTeamSaved, // ADD THIS
                  ),
                  // QA #9 7.1: the Results tab shows the lineup that produced the
                  // latest PUBLISHED results with its points (no hourglass); the
                  // lineup of the night in progress stays in "Créer une équipe"
                  // and in Live. Arrows go back through earlier nights.
                  GlobalPublishedResult(key: _resultKey),
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

}
