import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/custom_assets/assets.gen.dart';
import '../../../core/routes/route_path.dart';
import '../../../core/routes/routes.dart';
import '../../widgets/active_button.dart';
// Import AppString

/// -----------------------------
/// Welcome Screen
/// -----------------------------
/// This is the first screen of the app.
/// Contains:
/// - App logo centered vertically
/// - "Sign in" and "Sign up" buttons fixed at the bottom
/// -----------------------------
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              /// Centered Logo
              Expanded(
                child: Center(
                  child: Assets.images.mainLogo.image(
                    width: 195.w,
                    height: 270.h,
                  ),
                ),
              ),

              /// Buttons at the bottom
              Column(
                children: [
                  ActiveButton(
                    text: AppString.loginTitle.tr,
                    onPressed: () =>
                        context.go(RoutePath.signInScreen.addBasePath),
                  ),
                  SizedBox(height: 10.h),
                  SizedBox(
                    height: 50.0.h,
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE8632C),
                        side: const BorderSide(
                          color: Color(0xFFE8632C),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      onPressed: () => context.go(RoutePath.signUp.addBasePath),
                      child: Text(
                        AppString.createAccountTitle.tr,
                        style: TextStyle(fontSize: 16.sp),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
