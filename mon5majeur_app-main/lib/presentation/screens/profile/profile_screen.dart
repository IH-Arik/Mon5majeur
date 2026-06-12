import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/custom_assets/assets.gen.dart';
import '../../../core/routes/route_path.dart';
import '../../../core/routes/routes.dart';
import '../../widgets/navigation.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20.h),

              /// Settings Icon (Top Right)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () => context.go(
                        RoutePath.profileSettingsScreen.addBasePath,
                      ),
                      icon: Icon(
                        Icons.settings,
                        color: Colors.grey,
                        size: 30.r,
                      ),
                    ),
                  ],
                ),
              ),

              /// Team Logo
              Container(
                width: 100.w,
                height: 100.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1a1a1a),
                  border: Border.all(
                    color: const Color(0xFF333333),
                    width: 2.r,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 56.w,
                    height: 60.h,
                    decoration: BoxDecoration(shape: BoxShape.circle),
                    child: ClipOval(
                      child: Assets.icons.logo1.image(
                        width: 56.w,
                        height: 60.h,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 4.h),

              /// Team Name
              Text(
                AppString.teamName.tr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),

              /// Since Year
              Text(
                AppString.sinceYear.tr,
                style: TextStyle(color: Colors.grey, fontSize: 14.sp),
              ),

              SizedBox(height: 30.h),

              /// Statistics Overview Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppString.statisticsOverview.tr,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    /// Statistics Grid (2x2)
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: AppString.statWLNB.tr,
                            value: AppString.statWLNBValue.tr,
                            valueColor: const Color(0xFFFF6B35),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _StatCard(
                            title: AppString.statLeaguePlay.tr,
                            value: AppString.statLeaguePlayValue.tr,
                            valueColor: const Color(0xFFFF6B35),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: AppString.statRegularSeason.tr,
                            value: AppString.statRegularSeasonValue.tr,
                            valueColor: const Color(0xFFFF6B35),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _StatCard(
                            title: AppString.statLeagueWins.tr,
                            value: AppString.statLeagueWinsValue.tr,
                            valueColor: const Color(0xFFFF6B35),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              /// Trophies Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppString.trophies.tr,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    /// Trophy Cards
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _TrophyCard(
                          iconAsset: Assets.icons.trophie1,
                          count: '2x',
                        ),
                        _TrophyCard(
                          iconAsset: Assets.icons.trophie2,
                          count: '5x',
                        ),
                        _TrophyCard(
                          iconAsset: Assets.icons.trophie3,
                          count: '4x',
                        ),
                        _TrophyCard(
                          iconAsset: Assets.icons.trophie4,
                          count: '0x',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 40.h),

              /// Performance Highlights Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppString.performanceHighlights.tr,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    /// Average Point Scored
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(24.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1a1a1a),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: const Color(0xFF333333)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            AppString.avgPointScored.tr,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16.sp,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            AppString.avgPointScoredValue.tr,
                            style: TextStyle(
                              color: Color(0xFF3CDF1C),
                              fontSize: 40.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16.h),

                    /// Average Point Conceded
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(24.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1a1a1a),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: const Color(0xFF333333)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            AppString.avgPointConceded.tr,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16.sp,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            AppString.avgPointConcededValue.tr,
                            style: TextStyle(
                              color: Color(0xFFD32F2F),
                              fontSize: 40.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 100.h),
            ],
          ),
        ),
      ),

      /// Bottom Navigation Bar
      bottomNavigationBar: const NavigationWidget(currentIndex: 4),
    );
  }
}

/// Statistics Card Widget
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color valueColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(color: Colors.grey, fontSize: 13.sp),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12.h),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Trophy Card Widget
class _TrophyCard extends StatelessWidget {
  final AssetGenImage iconAsset;
  final String count;

  const _TrophyCard({required this.iconAsset, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80.w,
      padding: EdgeInsets.symmetric(vertical: 20.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        children: [
          iconAsset.image(width: 60.w, height: 60.h, fit: BoxFit.contain),
          SizedBox(height: 12.h),
          Text(
            count,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
