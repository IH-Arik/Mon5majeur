// lib/presentation/screens/home/my_match_today.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../controllers/my_match_today_controller.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../../../widgets/custom_heading.dart';
import '../../../widgets/match_widgets.dart';

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
                        child: NightMatchCard(match: controller.matches[index]),
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
