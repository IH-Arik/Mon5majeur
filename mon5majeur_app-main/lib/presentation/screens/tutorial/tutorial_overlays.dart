import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_strings.dart';
import 'tutorial_controller.dart';

/// Tutorial step 4 — full-screen overlay, no spotlight, single "Next"
/// button — plus a top-right Skip, since the spec allows Skip on steps 0
/// to 4 inclusive and step 4 has no Showcase (so no
/// `globalFloatingActionWidget`) to carry it automatically.
/// This is the only step with a Next button (spec Part 3 §13.0): there is
/// no real action to perform, so it cannot advance on a gesture.
Future<void> showTutorialStep4Overlay(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    barrierDismissible: false,
    builder: (ctx) => Stack(
      children: [
        Center(
          child: _TutorialCard(
            message: AppString.tutorialStep4.tr,
            buttons: [
              _TutorialButton(
                label: AppString.tutorialNext.tr,
                isPrimary: true,
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
        Positioned(
          top: MediaQuery.of(ctx).padding.top + 12.h,
          right: 16.w,
          child: GestureDetector(
            onTap: () {
              Navigator.of(ctx).pop();
              Get.find<TutorialController>().skip();
            },
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
        ),
      ],
    ),
  );
}

/// Tutorial step 5 — final step, full-screen overlay with two exits.
/// Returns 'create' or 'later' so the caller can navigate and log which
/// button was tapped (spec: "measures how many new users enter a private
/// league on day one").
Future<String> showTutorialStep5Overlay(BuildContext context) async {
  final choice = await showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    barrierDismissible: false,
    builder: (ctx) => _TutorialCard(
      message: AppString.tutorialStep5.tr,
      buttons: [
        _TutorialButton(
          label: AppString.tutorialLater.tr,
          isPrimary: false,
          onTap: () => Navigator.of(ctx).pop('later'),
        ),
        _TutorialButton(
          label: AppString.tutorialCreateMyLeague.tr,
          isPrimary: true,
          onTap: () => Navigator.of(ctx).pop('create'),
        ),
      ],
    ),
  );
  return choice ?? 'later';
}

class _TutorialCard extends StatelessWidget {
  final String message;
  final List<_TutorialButton> buttons;

  const _TutorialCard({required this.message, required this.buttons});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: const BorderSide(color: Color(0xFFFF6B35)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                for (final b in buttons) ...[
                  Expanded(child: b),
                  if (b != buttons.last) SizedBox(width: 12.w),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _TutorialButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: ShapeDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [Color(0xFFE8632C), Color(0xFFFF8A50)],
                )
              : null,
          color: isPrimary ? null : const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
