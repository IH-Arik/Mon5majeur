import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/custom_assets/assets.gen.dart';
import '../authentication/controller/auth_controller.dart';

class PasswordReset extends StatefulWidget {
  final String email;

  const PasswordReset({super.key, required this.email});

  @override
  State<PasswordReset> createState() => _PasswordResetState();
}

class _PasswordResetState extends State<PasswordReset> {
  final AuthController _authController = Get.put(AuthController());
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  // Check if both fields are filled
  bool get _isFormFilled =>
      _passwordController.text.isNotEmpty && _confirmController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onFormChange);
    _confirmController.addListener(_onFormChange);
  }

  void _onFormChange() => setState(() {});

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
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
                      onTap: () => context.pop(),
                      child: SizedBox(
                        width: 30.w,
                        height: 30.h,
                        child: Assets.icons.backButton.image(
                          fit: BoxFit.contain,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    SizedBox(height: 60.h),

                    /// Title
                    Center(
                      child: Text(
                        AppString.resetPassword.tr,
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
                        AppString.resetPasswordSubtitle.tr,
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

                    /// New Password Field
                    Container(
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
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w500,
                                fontSize: 16.sp,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                hintText: AppString.newPasswordHint.tr,
                                hintStyle: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontWeight: FontWeight.w400,
                                  fontSize: 16.sp,
                                  color: const Color(0xFF666666),
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF666666),
                              size: 22.r,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20.h),

                    /// Confirm Password Field
                    Container(
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
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _confirmController,
                              obscureText: _obscureConfirmPassword,
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w500,
                                fontSize: 16.sp,
                                color: Colors.white,
                              ),
                              decoration: InputDecoration(
                                hintText: AppString.confirmPasswordHint.tr,
                                hintStyle: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontWeight: FontWeight.w400,
                                  fontSize: 16.sp,
                                  color: const Color(0xFF666666),
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF666666),
                              size: 22.r,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 40.h),

                    /// Confirm Button
                    SizedBox(
                      width: double.infinity,
                      height: 56.h,
                      child: ElevatedButton(
                        onPressed:
                            _isFormFilled && !_authController.isLoading.value
                            ? () {
                                // Call change password API
                                _authController.changePassword(
                                  context,
                                  widget.email,
                                  _passwordController.text,
                                  _confirmController.text,
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
                          AppString.confirm.tr,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w700,
                            fontSize: 16.sp,
                            color: _isFormFilled
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
