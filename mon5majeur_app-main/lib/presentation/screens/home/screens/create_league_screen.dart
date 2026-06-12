import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';

class CreateLeagueScreen extends StatelessWidget {
  const CreateLeagueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Back Button
                GestureDetector(
                  onTap: () => context.go(RoutePath.home.addBasePath),
                  child: SizedBox(
                    width: 30.w,
                    height: 30.h,
                    child: Assets.icons.backButton.image(
                      fit: BoxFit.contain,
                      color: Colors.white,
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                /// Title
                Center(
                  child: Text(
                    AppString.createALeague,
                    style: TextStyle(
                      fontFamily: 'Raleway',
                      fontWeight: FontWeight.w700,
                      fontSize: 20.sp,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                SizedBox(height: 8.h),

                /// Subtitle
                Center(
                  child: Text(
                    AppString.chooseLeagueType,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w400,
                      fontSize: 16.sp,
                      color: Color(0xFFB0B3B8),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                SizedBox(height: 20.h),

                // Private League Card
                GestureDetector(
                  onTap: () => context.go(
                    RoutePath.createPrivateLeagueScreen.addBasePath,
                  ),
                  child: Container(
                    width: double.infinity,
                    decoration: ShapeDecoration(
                      color: const Color(0xFF1A1A1A),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          width: 3.r,
                          color: const Color(0xFF2C2C2C),
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                        children: [
                          // Lock Icon
                          Container(
                            width: 64.w,
                            height: 64.h,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1C2A),
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: Center(
                              child: Assets.icons.lock.image(
                                width: 40.w,
                                height: 40.h,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                          SizedBox(height: 20.h),

                          Text(
                            AppString.privateLeague,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),

                          SizedBox(height: 8.h),

                          Text(
                            AppString.playWithFriendsUsingCode,
                            style: TextStyle(
                              color: Color(0xFF6B6E82),
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20.h),

                // Public League Card
                GestureDetector(
                  onTap: () => context.go(
                    RoutePath.createPublicLeagueScreen.addBasePath,
                  ),
                  child: Container(
                    width: double.infinity,
                    decoration: ShapeDecoration(
                      color: const Color(0xFF1A1A1A),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          width: 1.r,
                          color: const Color(0xFF2C2C2C),
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                        children: [
                          // Trophy Icon
                          Container(
                            width: 64.w,
                            height: 64.h,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1C2A),
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: Center(
                              child: Assets.icons.basketballtrophee.image(
                                width: 40.w,
                                height: 40.h,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                          SizedBox(height: 20.h),

                          Text(
                            AppString.publicLeague,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),

                          SizedBox(height: 8.h),

                          Text(
                            AppString.openForAnyoneToJoin,
                            style: TextStyle(
                              color: Color(0xFF6B6E82),
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
