import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/custom_assets/assets.gen.dart';
import '../../../core/routes/route_path.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/routes/routes.dart';
// Import AppString

class OtpScreen extends StatefulWidget {
  final String email;

  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController otpController = TextEditingController();
  bool isOtpComplete = false;

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 30.h),

              /// Back Button
              GestureDetector(
                onTap: () => context.go(RoutePath.signUp.addBasePath),
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
                  AppString.verificationCodeTitle.tr,
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
                  AppString.verificationCodeSubtitle.tr,
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

              SizedBox(height: 60.h),

              /// OTP Input Field
              PinCodeTextField(
                appContext: context,
                length: 6,
                controller: otpController,
                keyboardType: TextInputType.number,
                animationType: AnimationType.fade,
                autoDisposeControllers: false,
                cursorColor: const Color(0xFFFF6B35),
                textStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                ),
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(16.r),
                  fieldHeight: 70.h,
                  fieldWidth: 50.w,
                  borderWidth: 2.w,
                  activeColor: const Color(0xFFFF6B35),
                  selectedColor: const Color(0xFFFF6B35),
                  inactiveColor: const Color(0xFF333333),
                  activeFillColor: Colors.transparent,
                  selectedFillColor: Colors.transparent,
                  inactiveFillColor: Colors.transparent,
                ),
                animationDuration: Duration(milliseconds: 300),
                enableActiveFill: true,
                onChanged: (value) {
                  setState(() {
                    isOtpComplete = value.length == 6;
                  });
                },
                beforeTextPaste: (text) {
                  return true;
                },
              ),

              SizedBox(height: 30.h),

              /// Resend Code Text
              Center(
                child: GestureDetector(
                  onTap: () {
                    // Resend OTP logic
                  },
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.w400,
                        fontSize: 14.sp,
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(
                          text: AppString.didntReceiveCode.tr,
                          style: TextStyle(color: Color(0xFFB0B3B8)),
                        ),
                        TextSpan(
                          text: AppString.resend.tr,
                          style: TextStyle(
                            color: Color(0xFFFF6B35),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 40.h),

              /// Verify Button
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: isOtpComplete
                      ? () {
                          context.go(RoutePath.passwordReset.addBasePath);
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
                    AppString.verify.tr,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w700,
                      fontSize: 16.sp,
                      color: isOtpComplete
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
      ),
    );
  }
}
