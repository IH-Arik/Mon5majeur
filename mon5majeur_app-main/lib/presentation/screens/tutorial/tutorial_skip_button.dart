import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../core/constants/app_strings.dart';
import 'tutorial_controller.dart';

/// Top-right "Skip" affordance for an active tutorial step (spec: no
/// confirmation dialog, ends the tutorial immediately).
///
/// Must be passed via `ShowCaseWidget(globalFloatingActionWidget: ...)`,
/// NOT placed as a normal sibling widget in the builder's subtree — the
/// showcase barrier is painted in the package's own Overlay, above the
/// app content, so a plain `Positioned` sibling ends up underneath it and
/// silently stops receiving taps while a step is active.
FloatingActionWidget buildTutorialSkipAction(BuildContext context) {
  final tutorial = Get.find<TutorialController>();
  return FloatingActionWidget(
    top: MediaQuery.of(context).padding.top + 12.h,
    right: 16.w,
    child: GestureDetector(
      onTap: () => tutorial.skip(),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          AppString.tutorialSkip.tr,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}
