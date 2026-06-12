import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:mon5majeur_app/core/custom_assets/assets.gen.dart';
import 'package:mon5majeur_app/core/constants/app_strings.dart';

class RegularSeasonView extends StatelessWidget {
  const RegularSeasonView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTableHeader(),
        SizedBox(height: 12.h),
        _buildTeamRow(
          1,
          Assets.icons.logo1,
          AppString.parisFC,
          AppString.wl_3_0,
          288,
          260,
          28,
          true,
        ),
        _buildTeamRow(
          2,
          Assets.icons.logo2,
          AppString.fc,
          AppString.wl_2_1,
          288,
          260,
          28,
          true,
        ),
        _buildTeamRow(
          3,
          Assets.icons.logo3,
          AppString.fc,
          AppString.wl_1_2,
          288,
          260,
          28,
          true,
        ),
        _buildTeamRow(
          4,
          Assets.icons.logo4,
          AppString.fc,
          AppString.wl_1_2,
          288,
          260,
          28,
          true,
        ),
        _buildTeamRow(
          5,
          Assets.icons.logo5,
          AppString.fc,
          AppString.wl_1_2,
          288,
          260,
          28,
          false,
        ),
        _buildTeamRow(
          6,
          Assets.icons.logo6,
          AppString.fc,
          AppString.wl_3_0,
          288,
          260,
          28,
          false,
        ),
        _buildTeamRow(
          7,
          Assets.icons.logo1,
          AppString.fc,
          AppString.wl_3_0,
          288,
          260,
          28,
          false,
        ),
        _buildTeamRow(
          8,
          Assets.icons.logo2,
          AppString.fc,
          AppString.wl_3_0,
          288,
          260,
          28,
          false,
        ),
        _buildTeamRow(
          9,
          Assets.icons.logo3,
          AppString.fc,
          AppString.wl_3_0,
          288,
          260,
          28,
          false,
        ),
        _buildTeamRow(
          10,
          Assets.icons.logo4,
          AppString.fc,
          AppString.wl_3_0,
          288,
          260,
          28,
          false,
        ),
        SizedBox(height: 20.h),
        _buildPlayoffInfo(),
      ],
    );
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

  Widget _buildTeamRow(
    int rank,
    AssetGenImage logo,
    String name,
    String wl,
    int pts,
    int ptc,
    int diff,
    bool isTopFour,
  ) {
    final wlParts = wl.split('-');
    final wins = int.parse(wlParts[0]);
    final losses = int.parse(wlParts[1]);

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: isTopFour ? const Color(0xFF007EF3) : const Color(0xFF2C2C2C),
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
                    '$rank',
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
                    name,
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
                    text: '$wins',
                    style: TextStyle(
                      color: Color(0xFF5DD344),
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
                    text: '$losses',
                    style: TextStyle(
                      color: Color(0xFFD32F2F),
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
              '$pts',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF85AFB6),
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '$ptc',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFBEBB94),
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '$diff',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFA88E53),
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayoffInfo() {
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
