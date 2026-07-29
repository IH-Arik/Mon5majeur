import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:mon5majeur_app/core/constants/app_strings.dart';
import 'package:mon5majeur_app/core/custom_assets/assets.gen.dart';
import '../tabs/build_your_team_tab.dart';
import '../tabs/leaderboard_tab.dart';
import '../tabs/my_team_tab.dart';
import '../tabs/result_tab.dart';
import '../tabs/rules_tab.dart';

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

  const LeagueFantasyScreen({
    super.key,
    this.leagueId,
    this.matchDay,
    this.isPrivate = false,
    required this.backRoute,
    required this.leagueTypeLabel,
    this.showBudgetBonus = false,
  });

  @override
  State<LeagueFantasyScreen> createState() => _LeagueFantasyScreenState();
}

class _LeagueFantasyScreenState extends State<LeagueFantasyScreen> {
  int _selectedTab = 0;
  Key _myTeamKey = UniqueKey();
  Key _resultKey = UniqueKey();

  void _onTeamSaved() {
    setState(() {
      _myTeamKey = UniqueKey();
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
                  BuildYourTeamTab(
                    leagueId: widget.leagueId,
                    matchDay: widget.matchDay,
                    isPrivate: widget.isPrivate,
                    onTeamSaved: _onTeamSaved,
                  ),
                  MyTeamTab(
                    key: _myTeamKey,
                    leagueId: widget.leagueId,
                    matchDay: widget.matchDay,
                    isPrivate: widget.isPrivate,
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
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(0.50, 0.00),
          end: Alignment(0.50, 1.00),
          colors: [Color(0xFFE8632C), Color(0xFFFF944D)],
        ),
      ),
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
          if (widget.showBudgetBonus && _selectedTab == 0) ...[
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

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF1A1C2A),
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildTab(AppString.createTeam.tr, Icons.add, 0),
          _buildTab(AppString.myTeam.tr, Icons.group, 1),
          _buildTab(AppString.result.tr, Icons.receipt, 2),
          _buildTab(AppString.leaderboard.tr, Icons.leaderboard, 3),
          _buildTab(AppString.rules.tr, Icons.menu_book, 4),
        ],
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
