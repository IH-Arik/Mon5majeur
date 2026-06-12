import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:mon5majeur_app/core/constants/app_strings.dart';

import 'regular_season_view.dart';
import 'play_off_view.dart';

class LeaderboardTab extends StatefulWidget {
  const LeaderboardTab({super.key});

  @override
  State<LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<LeaderboardTab> {
  bool isRegularSeason = true;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          SizedBox(height: 8.h),
          Text(
            AppString.leagueStandings,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12.h),
          _buildTabSelector(),
          SizedBox(height: 12.h),
          if (isRegularSeason)
            const RegularSeasonView()
          else
            const PlayOffView(),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: EdgeInsets.all(2.w),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3E),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => isRegularSeason = true),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  gradient: isRegularSeason
                      ? const LinearGradient(
                          colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  AppString.regularSeason,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isRegularSeason ? Colors.white : Colors.white54,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => isRegularSeason = false),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  gradient: !isRegularSeason
                      ? const LinearGradient(
                          colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  AppString.playOff,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !isRegularSeason ? Colors.white : Colors.white54,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
