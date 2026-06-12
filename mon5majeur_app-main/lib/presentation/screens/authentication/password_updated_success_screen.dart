import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // Add this import

import '../../../core/constants/app_strings.dart';
import '../../../core/routes/route_path.dart';
import '../../../core/routes/routes.dart';

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: 60.h,
                horizontal: 20.w,
              ), // Responsive padding
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Success icon with orange gradient background
                  Container(
                    width: 140.w,
                    height: 140.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF8A5B), Color(0xFFE85D35)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 70.sp, // Responsive icon size
                    ),
                  ),
                  SizedBox(height: 30.h),

                  // Success title text
                  Text(
                    AppString.successTitle.tr,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28.sp, // Responsive font size
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 15.h),

                  // Informational text
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 30.w,
                    ), // Responsive padding
                    child: Text(
                      AppString.successInfo.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFFAAAAAA),
                        fontSize: 16.sp, // Responsive font size
                        height: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(height: 40.h),

                  // Continue button with orange color
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                    ), // Responsive padding
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () =>
                            context.go(RoutePath.signInScreen.addBasePath),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7A50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              12.r,
                            ), // Responsive radius
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: 16.h,
                          ), // Responsive padding
                          elevation: 0,
                        ),
                        child: Text(
                          AppString.continueButton.tr,
                          style: TextStyle(
                            fontSize: 18.sp, // Responsive font size
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
