import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'controller/auth_controller.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/custom_assets/assets.gen.dart';
import '../../../core/routes/route_path.dart';
import '../../../core/routes/routes.dart';
import '../../widgets/active_button.dart';
import '../../widgets/custom_bottons/social_login_button.dart';
import '../../widgets/password_input.dart';
import '../../widgets/text_input_box.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final AuthController _authController = Get.put(AuthController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Obx(
          () => Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: 22.w,
                  vertical: 30.h,
                ),
                child: Form(
                  key: _authController.signUpFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// Back Button
                      GestureDetector(
                        onTap: () =>
                            context.go(RoutePath.welcomeScreen.addBasePath),
                        child: SizedBox(
                          width: 30.w,
                          height: 30.h,
                          child: Assets.icons.backButton.image(
                            fit: BoxFit.contain,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),

                      /// Screen Title
                      Center(
                        child: Text(
                          AppString.createAccountTitle.tr,
                          style: TextStyle(
                            fontFamily: 'Raleway',
                            fontWeight: FontWeight.w700,
                            fontSize: 24.sp,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      SizedBox(height: 40.h),

                      /// Email Input Field
                      TextInputBox(
                        controller: _authController.emailController,
                        label: AppString.emailLabelSignUp.tr,
                        hintText: AppString.emailHintSignUp.tr,
                        validator: _authController.validateEmail,
                        suffixIcon: Padding(
                          padding: EdgeInsets.all(12.0.r),
                          child: Assets.icons.email.image(
                            width: 20.w,
                            height: 20.h,
                          ),
                        ),
                      ),

                      SizedBox(height: 20.h),

                      /// Password Input Field
                      PasswordInput(
                        controller: _authController.passwordController,
                        label: AppString.passwordLabelSignUp.tr,
                        validator: _authController.validatePassword,
                      ),

                      SizedBox(height: 20.h),

                      /// Confirm Password Input Field
                      PasswordInput(
                        controller: _authController.confirmPasswordController,
                        label: AppString.confirmPasswordLabel.tr,
                        validator: _authController.validateConfirmPassword,
                      ),

                      SizedBox(height: 30.h),

                      /// Sign Up Button
                      ActiveButton(
                        text: AppString.signUpButton.tr,
                        onPressed: () => _authController.signUp(context),
                      ),

                      SizedBox(height: 20.h),

                      /// Navigate to Sign In
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppString.doYouHaveAccount.tr,
                            style: const TextStyle(color: Colors.white),
                          ),
                          GestureDetector(
                            onTap: () =>
                                context.go(RoutePath.signInScreen.addBasePath),
                            child: Text(
                              AppString.signInText.tr,
                              style: const TextStyle(
                                color: Color(0xFFE8632C),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 20.h),

                      /// Divider with "Or"
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade700)),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                            ),
                            child: Text(
                              AppString.or.tr,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade700)),
                        ],
                      ),

                      SizedBox(height: 20.h),

                      /// Google Login Button
                      SocialLoginButton(
                        text: AppString.continueWithGoogle.tr,
                        icon: Assets.icons.google.image(
                          width: 24.w,
                          height: 24.h,
                          fit: BoxFit.contain,
                        ),
                        onPressed: () => _authController.loginWithGoogle(context),
                        backgroundColor: Colors.white,
                        textColor: Colors.black,
                        borderColor: const Color(0xFFE0E0E0),
                      ),

                      SizedBox(height: 16.h),

                      /// Apple Login Button
                      SocialLoginButton(
                        text: AppString.continueWithApple.tr,
                        icon: Assets.icons.apple.image(
                          width: 24.w,
                          height: 24.h,
                          fit: BoxFit.contain,
                        ),
                        onPressed: () => _authController.loginWithApple(context),
                        backgroundColor: Colors.white,
                        textColor: Colors.black,
                        borderColor: const Color(0xFFE0E0E0),
                      ),

                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
              ),

              /// Loading Indicator
              if (_authController.isLoading.value)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE8632C)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
