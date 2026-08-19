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

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
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
                padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 30.h),
                child: Form(
                  key: _authController.signInFormKey,
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

                      /// Title
                      Center(
                        child: Text(
                          AppString.loginTitle.tr,
                          style: TextStyle(
                            fontFamily: 'Raleway',
                            fontWeight: FontWeight.w700,
                            fontSize: 24.sp,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 40.h),

                      /// Email Input
                      TextInputBox(
                        controller: _authController.emailController,
                        label: AppString.emailLabel.tr,
                        hintText: AppString.emailHintSignIn.tr,
                        validator: _authController.validateEmail,
                        suffixIcon: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Assets.icons.email.image(
                            width: 20.w,
                            height: 20.h,
                          ),
                        ),
                      ),
                      SizedBox(height: 20.h),

                      /// Password Input
                      PasswordInput(
                        controller: _authController.passwordController,
                        label: AppString.passwordLabel.tr,
                        validator: _authController.validatePassword,
                      ),
                      SizedBox(height: 20.h),

                      /// Remember Me & Forgot Password
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              _authController.toggleRememberMe(
                                !_authController.rememberMe.value,
                              );
                            },
                            child: Container(
                              width: 18.w,
                              height: 18.h,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(3.r),
                                color: _authController.rememberMe.value
                                    ? Color(0xFF004AAD)
                                    : Colors.transparent,
                              ),
                              child: _authController.rememberMe.value
                                  ? const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppString.rememberMe.tr,
                            style: TextStyle(color: Colors.white),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => context.go(
                              RoutePath.forgetPassword.addBasePath,
                            ),
                            child: Text(
                              AppString.forgetPassword.tr,
                              style: TextStyle(color: Color(0xFFE8632C)),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 30.h),

                      /// Sign In Button
                      ActiveButton(
                        text: AppString.loginButton.tr,
                        onPressed: () => _authController.login(context),
                      ),
                      SizedBox(height: 20.h),

                      /// Sign Up Text
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppString.dontHaveAccount.tr,
                            style: TextStyle(color: Colors.white),
                          ),
                          GestureDetector(
                            onTap: () =>
                                context.go(RoutePath.signUp.addBasePath),
                            child: Text(
                              AppString.createAccount.tr,
                              style: TextStyle(
                                color: Color(0xFFE8632C),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),

                      /// Divider
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade700)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.w),
                            child: Text(
                              AppString.or.tr,
                              style: TextStyle(color: Colors.white),
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
