import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/routes/route_path.dart';
import '../../../core/language/language_controller.dart';
import '../../../core/routes/routes.dart';
import '../../widgets/active_button.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  late final LanguageController _languageController;
  String selectedLang = AppString.english;

  @override
  void initState() {
    super.initState();
    _languageController = Get.find<LanguageController>();
    // Set initial selection based on current language
    selectedLang = _languageController.selectedLanguage.value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              /// Centered Content (Logo + Language options)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Image.asset(
                      AppString.logoAsset,
                      width: 154.w,
                      height: 36.h,
                    ),
                    SizedBox(height: 70.h),

                    // Title
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppString.selectLanguageTitle.tr,
                        style: TextStyle(
                          fontSize: 20.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppString.selectLanguageSubtitle.tr,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Color(0xFFB1B1B1),
                        ),
                      ),
                    ),
                    SizedBox(height: 40.h),

                    // English Button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedLang = AppString.english;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 14.h,
                          horizontal: 16.w,
                        ),
                        margin: EdgeInsets.only(bottom: 16.h),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedLang == AppString.english
                                ? const Color(0xFFE8632C)
                                : const Color(0xFFB1B1B1),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(30.r),
                          color: Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14.r,
                              backgroundImage: AssetImage(
                                AppString.englishFlagAsset,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Text(
                              AppString.english.tr,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: selectedLang == AppString.english
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // French Button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedLang = AppString.french;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 14.h,
                          horizontal: 16.w,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedLang == AppString.french
                                ? const Color(0xFFE8632C)
                                : const Color(0xFFB1B1B1),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(30.r),
                          color: Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14.r,
                              backgroundImage: AssetImage(
                                AppString.frenchFlagAsset,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Text(
                              AppString.french.tr,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: selectedLang == AppString.french
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              /// Button fixed at the bottom
              Column(
                children: [
                  ActiveButton(
                    text: AppString.getStarted.tr,
                    onPressed: () async {
                      // Save the selected language
                      await _languageController.changeLanguage(selectedLang);

                      // Navigate to welcome screen
                      if (mounted) {
                        context.go(RoutePath.welcomeScreen.addBasePath);
                      }
                    },
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
