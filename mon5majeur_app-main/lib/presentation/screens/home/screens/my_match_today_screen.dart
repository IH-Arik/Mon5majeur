// lib/presentation/screens/home/my_match_today.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../controllers/my_match_today_controller.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../../../../data/models/my_match_today_model.dart';
import '../../../widgets/custom_heading.dart';

// My Matches Today Screen
class MyMatchesTodayScreen extends StatelessWidget {
  const MyMatchesTodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MyMatchTodayController>();

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          children: [
            // Header using CustomHeading
            CustomHeading(
              title: AppString.nightsResults.tr,
              iconAsset: Assets.icons.vs,
              routePath: RoutePath.home.addBasePath,
            ),

            SizedBox(height: 30.h),

            // Matches List
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFF16C37)),
                  );
                }

                if (controller.matches.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Assets.icons.vs.image(
                          width: 80.w,
                          height: 80.h,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          AppString.noMatchesToday.tr,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: controller.refreshMatches,
                  color: const Color(0xFFF16C37),
                  backgroundColor: const Color(0xFF252838),
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    itemCount: controller.matches.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 16.h),
                        child: MatchCard(match: controller.matches[index]),
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// Match Card Widget
class MatchCard extends StatelessWidget {
  final MyMatchTodayModel match;

  const MatchCard({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    // Get first pair for display (main match)
    final mainPair = match.pairs.isNotEmpty ? match.pairs.first : null;

    return GestureDetector(
      onTap: () {
        // Navigate to fantasy league screen with league ID and match day
        context.go(
          '${RoutePath.fantasyLeagueScreenForJoin.addBasePath}/${match.leagueId}?matchDay=${match.matchDay}',
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A2D3E), Color(0xFF252838)],
          ),
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10.r,
              offset: Offset(0, 4.h),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(20.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // League Header
              Row(
                children: [
                  SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: Padding(
                      padding: EdgeInsets.all(0.r),
                      child: Assets.icons.basketBall.image(fit: BoxFit.contain),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      match.leagueName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3.w,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF462C21),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: const Color(0xFF462C21),
                        width: 1.r,
                      ),
                    ),
                    child: Text(
                      match.formattedMatchType,
                      style: TextStyle(
                        color: Color(0xFFF16C37),
                        fontSize: 6.sp,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5.w,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),

              // Match day and date info
              Row(
                children: [
                  Text(
                    'Match Day ${match.matchDay}',
                    style: TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '•',
                    style: TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    match.matchDate,
                    style: TextStyle(
                      color: Color(0xFFAAAAAA),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Match Info
              if (mainPair != null)
                Row(
                  children: [
                    // Team 1 (Player A)
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 45.w,
                            height: 45.h,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF3A3D50), Color(0xFF2D2F3E)],
                              ),
                              borderRadius: BorderRadius.circular(100.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8.r,
                                  offset: Offset(0, 2.h),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(6.r),
                              child: Assets.icons.logo1.image(
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            mainPair.playerAName ?? 'TBD',
                            style: TextStyle(
                              color: Color(0xFFAAAAAA),
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (mainPair.scoreA > 0) ...[
                            SizedBox(height: 4.h),
                            Text(
                              '${mainPair.scoreA}',
                              style: TextStyle(
                                color: Color(0xFFF16C37),
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // VS
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 0.w,
                          vertical: 0.h,
                        ),
                        child: Text(
                          AppString.vs.tr,
                          style: TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.w,
                          ),
                        ),
                      ),
                    ),

                    // Team 2 (Player B)
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 45.w,
                            height: 45.h,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF3A3D50), Color(0xFF2D2F3E)],
                              ),
                              borderRadius: BorderRadius.circular(100.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8.r,
                                  offset: Offset(0, 2.h),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(6.r),
                              child: mainPair.hasPlayerB
                                  ? Assets.icons.logo2.image(
                                      fit: BoxFit.contain,
                                    )
                                  : Icon(
                                      Icons.question_mark,
                                      color: Colors.grey[600],
                                      size: 24.r,
                                    ),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            mainPair.playerBName ?? 'TBD',
                            style: TextStyle(
                              color: Color(0xFFAAAAAA),
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (mainPair.scoreB > 0) ...[
                            SizedBox(height: 4.h),
                            Text(
                              '${mainPair.scoreB}',
                              style: TextStyle(
                                color: Color(0xFFF16C37),
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

              if (match.isLiveForUser && mainPair?.matchObjectId != null) ...[
                SizedBox(height: 16.h),
                GestureDetector(
                  onTap: () {
                    context.push(
                      '${RoutePath.liveScoreScreen.addBasePath}?matchId=${mainPair!.matchObjectId}',
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    decoration: ShapeDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE8632C), Color(0xFFFF8A50)],
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt, color: Colors.white, size: 16.r),
                        SizedBox(width: 6.w),
                        Text(
                          AppString.watchLive.tr,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Additional pairs if any
              if (match.pairs.length > 1) ...[
                SizedBox(height: 16.h),
                const Divider(color: Color(0xFF3A3D50)),
                SizedBox(height: 8.h),
                Text(
                  '+${match.pairs.length - 1} more ${match.pairs.length - 1 == 1 ? 'match' : 'matches'}',
                  style: TextStyle(
                    color: Color(0xFFAAAAAA),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
