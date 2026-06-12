import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_strings.dart';

class LeaderboardTab extends StatefulWidget {
  const LeaderboardTab({super.key});

  @override
  State<LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<LeaderboardTab> {
  bool isWeekly = true; // true for Weekly, false for Monthly
  int currentPeriod = 1; // Week 1 or Month 1

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          SizedBox(height: 8.h),
          Text(
            AppString.leagueStandings.tr,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16.h),
          _buildTabSelector(),
          SizedBox(height: 16.h),
          _buildPeriodSelector(),
          SizedBox(height: 12.h),
          _buildRewardBanner(),
          SizedBox(height: 16.h),
          _buildSearchBar(),
          SizedBox(height: 16.h),
          _buildStandingsList(),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: EdgeInsets.all(3.r),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3E),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => isWeekly = true),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
              decoration: BoxDecoration(
                gradient: isWeekly
                    ? const LinearGradient(
                        colors: [Color(0xFFFF6B3D), Color(0xFFFF8F6B)],
                      )
                    : null,
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: Text(
                AppString.weekly.tr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: isWeekly ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => isWeekly = false),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
              decoration: BoxDecoration(
                gradient: !isWeekly
                    ? const LinearGradient(
                        colors: [Color(0xFFFF6B3D), Color(0xFFFF8F6B)],
                      )
                    : null,
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: Text(
                AppString.monthly.tr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: !isWeekly ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: currentPeriod > 1
              ? () => setState(() => currentPeriod--)
              : null,
          icon: Icon(Icons.chevron_left, color: Colors.white54, size: 24.r),
        ),
        SizedBox(width: 16.w),
        Text(
          isWeekly
              ? AppString.weekWithNumber(currentPeriod).tr
              : AppString.monthWithNumber(currentPeriod).tr,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: 16.w),
        IconButton(
          onPressed: () => setState(() => currentPeriod++),
          icon: Icon(Icons.chevron_right, color: Colors.white54, size: 24.r),
        ),
      ],
    );
  }

  Widget _buildRewardBanner() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3E),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, color: Color(0xFFFF6B3D), size: 16.r),
          SizedBox(width: 8.w),
          Text(
            isWeekly
                ? AppString.top8WeeklyReward.tr
                : AppString.monthlyWinnerReward.tr,
            style: TextStyle(color: Colors.white70, fontSize: 12.sp),
          ),
          SizedBox(width: 4.w),
          if (!isWeekly) Text('🏅', style: TextStyle(fontSize: 14.sp)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3E),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: TextField(
        style: TextStyle(color: Colors.white, fontSize: 14.sp),
        decoration: InputDecoration(
          hintText: AppString.searchTeamsByName.tr,
          hintStyle: TextStyle(color: Colors.white38, fontSize: 14.sp),
          border: InputBorder.none,
          icon: Icon(Icons.search, color: Colors.white38, size: 20.r),
          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
        ),
      ),
    );
  }

  Widget _buildStandingsList() {
    // Sample data - replace with your actual data
    final teams = List.generate(
      20,
      (index) => {'rank': index + 1, 'name': 'Paris FC', 'points': 300},
    );

    return Column(children: teams.map((team) => _buildTeamRow(team)).toList());
  }

  Widget _buildTeamRow(Map<String, dynamic> team) {
    final int rank = team['rank'];
    final bool isTopOne = rank == 1;
    final bool isTopThree = rank <= 3;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3E),
        borderRadius: BorderRadius.circular(8.r),
        border: isTopOne
            ? Border.all(color: const Color(0xFFFF6B3D), width: 1.r)
            : null,
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 24.w,
            child: Text(
              '$rank',
              style: TextStyle(
                color: isTopOne ? const Color(0xFFFF6B3D) : Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          // Fire icon for top ranks
          if (isTopThree)
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: Text('🔥', style: TextStyle(fontSize: 16.sp)),
            ),
          // Team icon
          Container(
            width: 24.w,
            height: 24.h,
            decoration: BoxDecoration(
              color: Color(0xFF3A3D4E),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield, size: 14.r, color: Colors.white54),
          ),
          SizedBox(width: 12.w),

          // Team name
          Expanded(
            child: Text(
              team['name'],
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // if top one show jersey icon
          if (isTopOne)
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: Text('👕', style: TextStyle(fontSize: 16.sp)),
            ),
          // Points
          Text(
            '${team['points']}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 12.w),
          // View Details button
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Color(0xFF3A3D4E),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Text(
              AppString.viewDetails.tr,
              style: TextStyle(color: Colors.white70, fontSize: 10.sp),
            ),
          ),
          if (isTopOne) ...[
            SizedBox(width: 8.w),
            Text('🏆', style: TextStyle(fontSize: 16.sp)),
          ],
        ],
      ),
    );
  }
}
