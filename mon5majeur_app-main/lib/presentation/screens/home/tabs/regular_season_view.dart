import '../../../../core/utils/logo_assets.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:mon5majeur_app/core/custom_assets/assets.gen.dart';
import 'package:mon5majeur_app/core/constants/app_strings.dart';

import '../../../../data/models/standings_model.dart';
import '../controllers/leaderboard_controller.dart';

// Playoff-spot accents: the app's orange (the one of this screen's spinner),
// softened on large surfaces. Tune the opacities here.
const Color _playoffAccent = Color(0xFFFF6B35);
const double _spotRowBorderOpacity = 0.35;
const double _bannerFillOpacity = 0.14;
const double _bannerBorderOpacity = 0.5;
const double _bannerTextOpacity = 0.9; // off-white
const Color _cardColor = Color(0xFF1A1A1A);

class RegularSeasonView extends StatelessWidget {
  final LeaderboardController controller;

  const RegularSeasonView({super.key, required this.controller});

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
            _buildTeamRow(team, logoAsset(team.teamLogo)),
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
        color: _cardColor,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: team.isPlayoffSpot
              ? _playoffAccent.withValues(alpha: _spotRowBorderOpacity)
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
      // The border takes 1.r inside the box: less padding keeps the same size.
      padding: EdgeInsets.all(16.w - 1.r),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          _playoffAccent.withValues(alpha: _bannerFillOpacity),
          _cardColor,
        ),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: _playoffAccent.withValues(alpha: _bannerBorderOpacity),
          width: 1.r,
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              AppString.top4Playoff.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: _bannerTextOpacity),
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
