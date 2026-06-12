import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/custom_assets/assets.gen.dart';
import '../../../core/routes/route_path.dart';
import '../../../core/routes/routes.dart';
import 'controller/auth_controller.dart';

class ForgetPassword extends StatefulWidget {
  const ForgetPassword({super.key});

  @override
  State<ForgetPassword> createState() => _ForgetPasswordState();
}

class _ForgetPasswordState extends State<ForgetPassword> {
  final AuthController _authController = Get.put(AuthController());
  final TextEditingController _emailController = TextEditingController();
  bool isButtonActive = false;

  @override
  void initState() {
    super.initState();
    // Listen for text changes to enable/disable button dynamically
    _emailController.addListener(() {
      setState(() {
        isButtonActive = _emailController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Obx(
          () => Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 30.h),

                    /// Back Button
                    GestureDetector(
                      onTap: () =>
                          context.go(RoutePath.signInScreen.addBasePath),
                      child: SizedBox(
                        width: 30.w,
                        height: 30.w,
                        child: Assets.icons.backButton.image(
                          fit: BoxFit.contain,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    SizedBox(height: 40.h),

                    /// Title
                    Center(
                      child: Text(
                        AppString.forgotPasswordTitle.tr,
                        style: TextStyle(
                          fontFamily: 'Raleway',
                          fontWeight: FontWeight.w700,
                          fontSize: 28.sp,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    SizedBox(height: 16.h),

                    /// Subtitle
                    Center(
                      child: Text(
                        AppString.forgotPasswordSubtitle.tr,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w400,
                          fontSize: 16.sp,
                          color: const Color(0xFFB0B3B8),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    SizedBox(height: 60.h),

                    /// Email Input Field
                    Container(
                      width: double.infinity,
                      height: 64.h,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: const Color(0xFF333333),
                          width: 1.5.w,
                        ),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: TextField(
                        controller: _emailController,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w500,
                          fontSize: 16.sp,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: AppString.emailHint.tr,
                          hintStyle: TextStyle(
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w400,
                            fontSize: 16.sp,
                            color: const Color(0xFF666666),
                          ),
                          border: InputBorder.none,
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),

                    SizedBox(height: 40.h),

                    /// Reset Password Button
                    SizedBox(
                      width: double.infinity,
                      height: 56.h,
                      child: ElevatedButton(
                        onPressed:
                            isButtonActive && !_authController.isLoading.value
                            ? () {
                                // Call the API
                                _authController.sendForgotPasswordOtp(
                                  context,
                                  _emailController.text.trim(),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6B35),
                          disabledBackgroundColor: const Color(0xFF333333),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          AppString.resetPasswordButton.tr,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w700,
                            fontSize: 16.sp,
                            color: isButtonActive
                                ? Colors.white
                                : const Color(0xFF666666),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 40.h),
                  ],
                ),
              ),

              /// Loading Indicator
              if (_authController.isLoading.value)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
