import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/custom_assets/assets.gen.dart';
// Import AppString

class PlayerInfoScreen extends StatelessWidget {
  final String name;
  final String position;
  final int avg;
  final String price;
  final String team;

  const PlayerInfoScreen({
    super.key,
    required this.name,
    required this.position,
    required this.avg,
    required this.price,
    required this.team,
  });

  // Function to get random jersey image
  AssetGenImage _getRandomJersey() {
    final jerseys = [
      Assets.icons.gercy1,
      Assets.icons.gercy2,
      Assets.icons.gercy3,
      Assets.icons.gercy4,
      Assets.icons.gercy5,
    ];
    return jerseys[Random().nextInt(jerseys.length)];
  }

  // Function to get team border color
  Color _getTeamColor() {
    switch (team.toLowerCase()) {
      case 'warriors':
        return const Color(0xFF1D428A); // Warriors blue
      case 'lakers':
        return const Color(0xFFFDB927); // Lakers gold
      case 'celtics':
        return const Color(0xFF007A33); // Celtics green
      case 'suns':
        return const Color(0xFFE56020); // Suns orange
      default:
        return const Color(0xFFFECD56); // Default yellow
    }
  }

  @override
  Widget build(BuildContext context) {
    // Generate random stats for season performance
    final points = (avg + Random().nextInt(20) - 10).toDouble();
    final rebounds = (Random().nextInt(10) + 3).toDouble();
    final assists = (Random().nextInt(8) + 2).toDouble();
    final steals = (Random().nextDouble() * 3).toStringAsFixed(1);
    final turnovers = (Random().nextDouble() * 4 + 1).toStringAsFixed(1);
    final fantasy = (avg * 1.2 + Random().nextInt(10)).toStringAsFixed(1);
    final selectedPercentage = Random().nextInt(100);
    final rating = (avg / 10).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Header with back button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: SizedBox(
                      width: 30.w,
                      height: 30.h,
                      child: Assets.icons.backButton.image(fit: BoxFit.contain),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      AppString.playerInfoTitle.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                        height: 1.38,
                      ),
                    ),
                  ),
                  SizedBox(width: 30.w), // Balance the back button
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 24.h),

                    /// Player Header Section
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// Jersey Image
                        _getRandomJersey().image(width: 80.w, height: 100.h),
                        SizedBox(width: 22.w),

                        /// Player Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  height: 1.38,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Row(
                                children: [
                                  /// Position Badge
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 4.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8632C),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.r,
                                      ),
                                      borderRadius: BorderRadius.circular(7.r),
                                    ),
                                    child: Text(
                                      position,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8.sp,
                                        fontWeight: FontWeight.w600,
                                        height: 2.75,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 6.w),

                                  /// Team Badge
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 4.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1A1A),
                                      border: Border.all(
                                        color: _getTeamColor(),
                                        width: 1.r,
                                      ),
                                      borderRadius: BorderRadius.circular(7.r),
                                    ),
                                    child: Text(
                                      team,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w600,
                                        height: 2.20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 14.h),

                              /// Current Value
                              Row(
                                children: [
                                  Text(
                                    AppString.currentValue.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      height: 1.83,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    price,
                                    style: TextStyle(
                                      color: Color(0xFFE8632C),
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w800,
                                      height: 1.83,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        /// Active Badge & Rating
                        Column(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 1.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00FA36),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                AppString.active.tr,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 6.sp,
                                  fontWeight: FontWeight.w600,
                                  height: 3.67,
                                ),
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              AppString.rating.tr,
                              style: TextStyle(
                                color: Color(0xFFB0B0B0),
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                height: 1.38,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              rating,
                              style: TextStyle(
                                color: Color(0xFFE8632C),
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w600,
                                height: 0.61,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: 32.h),

                    /// Season Performance Section
                    Row(
                      children: [
                        Container(
                          width: 28.w,
                          height: 28.h,
                          padding: EdgeInsets.all(4.r),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3A2216),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Assets.icons.basketballtrophee.image(),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          AppString.seasonPerformance.tr,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            height: 1.38,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 16.h),

                    /// Stats Grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12.h,
                      crossAxisSpacing: 12.w,
                      childAspectRatio: 1.92,
                      children: [
                        _buildStatCard(
                          AppString.points.tr,
                          points.toStringAsFixed(1),
                          const Color(0xFF60A5FA),
                        ),
                        _buildStatCard(
                          AppString.rebounds.tr,
                          rebounds.toStringAsFixed(1),
                          const Color(0xFF34D399),
                        ),
                        _buildStatCard(
                          AppString.assists.tr,
                          assists.toStringAsFixed(1),
                          const Color(0xFFC084FC),
                        ),
                        _buildStatCard(
                          AppString.steals.tr,
                          steals,
                          const Color(0xFFFECD56),
                        ),
                        _buildStatCard(
                          AppString.turnovers.tr,
                          turnovers,
                          const Color(0xFFF87171),
                        ),
                        _buildStatCard(
                          AppString.fantasy.tr,
                          fantasy,
                          const Color(0xFFE8632C),
                        ),
                      ],
                    ),

                    SizedBox(height: 32.h),

                    /// Selected Today Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              AppString.selectedToday.tr,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400,
                                height: 1.57,
                              ),
                            ),
                            Text(
                              '$selectedPercentage%',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                height: 1.38,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        Container(
                          height: 15.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(13.r),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13.r),
                            child: Stack(
                              children: [
                                FractionallySizedBox(
                                  widthFactor: selectedPercentage / 100,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Color(0xFFE8632C),
                                          Color(0xFFFF8A50),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border.all(color: const Color(0xFF2C2C2C), width: 1.r),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              height: 0.92,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            label,
            style: TextStyle(
              color: Color(0xFFB0B0B0),
              fontSize: 10.sp,
              fontWeight: FontWeight.w400,
              height: 1.57,
            ),
          ),
        ],
      ),
    );
  }
}
