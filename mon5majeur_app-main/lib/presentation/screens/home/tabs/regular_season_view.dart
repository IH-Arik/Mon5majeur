import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:mon5majeur_app/core/custom_assets/assets.gen.dart';
import 'package:mon5majeur_app/core/constants/app_strings.dart';

import '../../../../data/models/standings_model.dart';
import '../controllers/leaderboard_controller.dart';

class RegularSeasonView extends StatelessWidget {
  final LeaderboardController controller;

  const RegularSeasonView({super.key, required this.controller});

  static final List<AssetGenImage> _logos = [
    Assets.icons.logo1,
    Assets.icons.logo2,
    Assets.icons.logo3,
    Assets.icons.logo4,
    Assets.icons.logo5,
    Assets.icons.logo6,
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingStandings.value) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 40.h),
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
          ),
        );
      }

      final standings = controller.standings.value;
      if (standings == null || standings.teams.isEmpty) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 40.h),
          child: Center(
            child: Text(
              AppString.noStandingsYet.tr,
              style: TextStyle(color: Colors.grey, fontSize: 14.sp),
            ),
          ),
        );
      }

      return Column(
        children: [
          _buildTableHeader(),
          SizedBox(height: 12.h),
          for (final team in standings.teams)
            _buildTeamRow(
              team,
              _logos[(team.rank - 1) % _logos.length],
            ),
          SizedBox(height: 20.h),
          _buildPlayoffInfo(standings.playoffSpots),
        ],
      );
    });
  }

  Widget _buildTableHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              AppString.teamName.tr,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              AppString.wl.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12.sp),
            ),
          ),
          Expanded(
            child: Text(
              AppString.pts.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12.sp),
            ),
          ),
          Expanded(
            child: Text(
              AppString.ptc.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12.sp),
            ),
          ),
          Expanded(
            child: Text(
              AppString.plusMinus.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamRow(StandingsEntry team, AssetGenImage logo) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: team.isPlayoffSpot
              ? const Color(0xFF007EF3)
              : const Color(0xFF2C2C2C),
          width: 1.r,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                SizedBox(
                  width: 12.w,
                  child: Text(
                    '${team.rank}',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                logo.image(width: 20.w, height: 20.w),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    team.teamName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${team.wins}',
                    style: TextStyle(
                      color: const Color(0xFF5DD344),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: AppString.hyphen.tr,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: '${team.losses}',
                    style: TextStyle(
                      color: const Color(0xFFD32F2F),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              team.pointsFor.toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF85AFB6),
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            child: Text(
              team.pointsAgainst.toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFBEBB94),
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            child: Text(
              team.differential > 0
                  ? '+${team.differential.toStringAsFixed(0)}'
                  : team.differential.toStringAsFixed(0),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFA88E53),
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayoffInfo(int playoffSpots) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF007EF3),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              AppString.top4Playoff.tr,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
