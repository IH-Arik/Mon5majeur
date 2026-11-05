import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/custom_assets/assets.gen.dart';
import '../../../core/routes/route_path.dart';
import '../../../core/routes/routes.dart';
import '../../../core/utils/datetime_format.dart';
import '../../../data/models/profile_model.dart';
import 'controller/profile_setup_controller.dart';

class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize controller
    final controller = Get.put(ProfileSetupController());

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 30.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              /// Screen Title
              Text(
                AppString.completeProfileTitle.tr,
                style: TextStyle(
                  fontFamily: 'Raleway',
                  fontWeight: FontWeight.w700,
                  fontSize: 20.sp,
                  color: Colors.white,
                ),
              ),

              SizedBox(height: 20.h),

              /// Selected Logo Display
              Obx(
                () => Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFF6B35),
                      width: 4.r,
                    ),
                  ),
                  child: Center(
                    child: TeamLogoChoices
                        .assets[controller.selectedLogoIndex.value]
                        .image(
                      width: 40.w,
                      height: 40.w,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 26.h),

              /// Logo Selection Section
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Assets.icons.league.image(width: 20.w, height: 20.w),
                    SizedBox(width: 8.w),
                    Text(
                      AppString.chooseTeamLogo.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16.sp,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 8.h),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  AppString.chooseLogoBelow.tr,
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey),
                ),
              ),

              SizedBox(height: 16.h),

              /// Logo Options
              SizedBox(
                height: 48.h,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: TeamLogoChoices.assets.length,
                  itemBuilder: (context, index) {
                    return Obx(() {
                      final isSelected =
                          index == controller.selectedLogoIndex.value;
                      return GestureDetector(
                        onTap: () => controller.updateSelectedLogo(index),
                        child: Container(
                          width: 48.w,
                          height: 48.w,
                          margin: EdgeInsets.only(right: 12.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1a1a1a),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFF6B35)
                                  : const Color(0xFF333333),
                              width: isSelected ? 2.r : 1.r,
                            ),
                          ),
                          child: Center(
                            child: TeamLogoChoices.assets[index].image(
                              width: 24.w,
                              height: 24.w,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    });
                  },
                ),
              ),

              SizedBox(height: 20.h),

              /// Team Name Input
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1a1a1a),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: 10.w,
                  vertical: 0.h,
                ),
                child: Row(
                  children: [
                    Assets.icons.profileVector.image(width: 20.w, height: 20.w),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: TextField(
                        controller: controller.teamNameController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: AppString.teamNameHint.tr,
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              /// Favorite Team Dropdown
              // GestureDetector(
              //   onTap: () async {
              //     final result = await showModalBottomSheet<String>(
              //       context: context,
              //       backgroundColor: const Color(0xFF1a1a1a),
              //       shape: RoundedRectangleBorder(
              //         borderRadius: BorderRadius.vertical(
              //           top: Radius.circular(20.r),
              //         ),
              //       ),
              //       builder: (context) => Container(
              //         padding: EdgeInsets.all(20.w),
              //         child: Column(
              //           mainAxisSize: MainAxisSize.min,
              //           children: controller.teams.map((team) {
              //             return ListTile(
              //               title: Text(
              //                 team,
              //                 style: TextStyle(color: Colors.white),
              //               ),
              //               onTap: () => Navigator.pop(context, team),
              //             );
              //           }).toList(),
              //         ),
              //       ),
              //     );
              //     if (result != null) {
              //       controller.updateFavoriteTeam(result);
              //     }
              //   },
              //   child: Container(
              //     decoration: BoxDecoration(
              //       color: const Color(0xFF1a1a1a),
              //       borderRadius: BorderRadius.circular(16.r),
              //       border: Border.all(color: const Color(0xFF333333)),
              //     ),
              //     padding: EdgeInsets.symmetric(
              //       horizontal: 10.w,
              //       vertical: 10.h,
              //     ),
              //     child: Row(
              //       children: [
              //         Assets.icons.league.image(width: 20.w, height: 20.w),
              //         SizedBox(width: 12.w),
              //         Expanded(
              //           child: Obx(
              //             () => Text(
              //               controller.selectedFavoriteTeam.value.isEmpty
              //                   ? AppString.chooseFavoriteTeam.tr
              //                   : controller.selectedFavoriteTeam.value,
              //               style: TextStyle(
              //                 color:
              //                     controller.selectedFavoriteTeam.value.isEmpty
              //                     ? Colors.grey
              //                     : Colors.white,
              //               ),
              //             ),
              //           ),
              //         ),
              //         Icon(Icons.arrow_drop_down, color: Colors.grey),
              //       ],
              //     ),
              //   ),
              // ),
              SizedBox(height: 16.h),

              /// Date of Birth Picker
              GestureDetector(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    locale: Get.locale,
                    initialDate:
                        controller.selectedDate.value ?? DateTime(2000, 1, 1),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(), // ✅ Good - prevents future dates
                  );
                  if (pickedDate != null) {
                    controller.updateSelectedDate(pickedDate);
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1a1a1a),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: const Color(0xFF333333)),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 10.h,
                  ),
                  child: Row(
                    children: [
                      Assets.icons.league.image(width: 20.w, height: 20.w),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Obx(
                          () => Text(
                            controller.selectedDate.value != null
                                ? formatBirthDate(
                                    controller.selectedDate.value!,
                                  )
                                : AppString.dateOfBirth.tr,
                            style: TextStyle(
                              color: controller.selectedDate.value != null
                                  ? Colors.white
                                  : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.calendar_today,
                        color: Colors.grey,
                        size: 18.r,
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 24.h),

              /// Terms & Conditions Checkbox
              Obx(
                () => GestureDetector(
                  onTap: controller.toggleTermsAccepted,
                  child: Row(
                    children: [
                      Container(
                        width: 20.w,
                        height: 20.w,
                        decoration: BoxDecoration(
                          color: controller.termsAccepted.value
                              ? const Color(0xFFFF6B35)
                              : Colors.transparent,
                          border: Border.all(
                            color: controller.termsAccepted.value
                                ? const Color(0xFFFF6B35)
                                : Colors.grey,
                          ),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: controller.termsAccepted.value
                            ? Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16.r,
                              )
                            : null,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: const _TermsLabel(),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 16.h),

              SizedBox(height: 20.h),

              /// Save & Continue Button
              Obx(
                () => SizedBox(
                  width: double.infinity,
                  height: 40.h,
                  child: ElevatedButton(
                    onPressed: controller.isLoading.value
                        ? null
                        : () => controller.saveProfile(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    child: controller.isLoading.value
                        ? SizedBox(
                            height: 20.h,
                            width: 20.w,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.r,
                            ),
                          )
                        : Text(
                            AppString.saveAndContinue.tr,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16.sp,
                            ),
                          ),
                  ),
                ),
              ),

              SizedBox(height: 16.h),

              /// Bottom Info Text
              Text(
                AppString.bottomInfoText.tr,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13.sp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "I accept the Terms of Use and the Privacy Policy": the two document names
/// open their screen (pushed, so this form stays as it is); tapping anywhere
/// else is left to the surrounding checkbox.
class _TermsLabel extends StatefulWidget {
  const _TermsLabel();

  @override
  State<_TermsLabel> createState() => _TermsLabelState();
}

class _TermsLabelState extends State<_TermsLabel> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => context.push(RoutePath.termsOfUseScreen.addBasePath);
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => context.push(RoutePath.privacyPolicyScreen.addBasePath);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(color: Colors.white, fontSize: 14.sp);
    final link = base.copyWith(
      color: const Color(0xFFFF6B35),
      decoration: TextDecoration.underline,
      decorationColor: const Color(0xFFFF6B35),
    );
    final full = AppString.acceptTerms.tr;
    final terms = AppString.termsLinkText.tr;
    final privacy = AppString.privacyLinkText.tr;
    final i = full.indexOf(terms);
    final j = full.indexOf(privacy);
    if (i < 0 || j < i + terms.length) return Text(full, style: base);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: full.substring(0, i)),
          TextSpan(text: terms, style: link, recognizer: _terms),
          TextSpan(text: full.substring(i + terms.length, j)),
          TextSpan(text: privacy, style: link, recognizer: _privacy),
          TextSpan(text: full.substring(j + privacy.length)),
        ],
      ),
    );
  }
}
