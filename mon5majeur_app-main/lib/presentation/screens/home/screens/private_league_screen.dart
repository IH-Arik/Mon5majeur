import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../controllers/create_league_controller.dart';

class PrivateLeagueScreen extends StatefulWidget {
  const PrivateLeagueScreen({super.key});

  @override
  State<PrivateLeagueScreen> createState() => _PrivateLeagueScreenState();
}

class _PrivateLeagueScreenState extends State<PrivateLeagueScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _clearCode() {
    setState(() {
      _codeController.clear();
      _hasError = false;
      _errorMessage = '';
    });
  }

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
                  onTap: () =>
                      context.go(RoutePath.chooseALeagueScreen.addBasePath),
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
                    AppString.privateLeague.tr,
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
                    AppString.connectWithYourFriends.tr,
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

                SizedBox(height: 20.h),

                // Main Card
                Container(
                  width: double.infinity,
                  decoration: ShapeDecoration(
                    color: const Color(0xFF1A1A1A),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: 1.w,
                        color: Color(0xFF2C2C2C),
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
                          AppString.accessYourLeague.tr,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),

                        SizedBox(height: 8.h),

                        Text(
                          AppString.enterCodeToJoinPrivateLeague.tr,
                          style: TextStyle(
                            color: const Color(0xFF6B6E82),
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: 24.h),

                        // Code Input Field
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF000000),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: _hasError
                                  ? const Color(0xFFD85A2A)
                                  : const Color(0xFF2C2C2C),
                              width: 1.w,
                            ),
                          ),
                          child: TextField(
                            controller: _codeController,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                            textAlign: TextAlign.center,
                            maxLength: 6,
                            keyboardType: TextInputType.text,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: AppString.enter6DigitCode.tr,
                              hintStyle: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.5,
                              ),
                              border: InputBorder.none,
                              counterText: '',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20.w,
                                vertical: 18.h,
                              ),
                              suffixIcon: _codeController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Container(
                                        width: 24.w,
                                        height: 24.h,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[800],
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16.r,
                                        ),
                                      ),
                                      onPressed: _clearCode,
                                    )
                                  : null,
                            ),
                            onChanged: (value) {
                              setState(() {
                                if (_hasError && value.isEmpty) {
                                  _hasError = false;
                                  _errorMessage = '';
                                }
                              });
                            },
                          ),
                        ),

                        // Error Message
                        if (_hasError)
                          Padding(
                            padding: EdgeInsets.only(top: 12.h),
                            child: Text(
                              _errorMessage,
                              style: TextStyle(
                                color: const Color(0xFFFF6B6B),
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        SizedBox(height: 24.h),

                        // Join Code Button
                        SizedBox(
                          width: double.infinity,
                          height: 56.h,
                          child: ElevatedButton(
                            onPressed: _codeController.text.isNotEmpty
                                ? () {
                                    final controller =
                                        Get.find<CreateLeagueController>(
                                          tag: 'private',
                                        );
                                    controller.joinLeague(
                                      context,
                                      joinCode: _codeController.text,
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD85A2A),
                              disabledBackgroundColor: const Color(0xFF3A3D4A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              AppString.joinCode.tr,
                              style: TextStyle(
                                color: _codeController.text.isNotEmpty
                                    ? Colors.white
                                    : const Color(0xFF6B6E82),
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),

                        // Bottom Helper Text (when no error)
                        if (!_hasError)
                          Padding(
                            padding: EdgeInsets.only(top: 16.h),
                            child: Text(
                              AppString.enterValidCodeToJoinFriendsLeague.tr,
                              style: TextStyle(
                                color: const Color(0xFF6B6E82),
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
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
