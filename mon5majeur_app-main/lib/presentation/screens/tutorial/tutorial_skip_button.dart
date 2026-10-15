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
  // Looked up now: this builder gets the Showcase's context, which sits under
  // the ShowCaseWidget. Null (no ancestor) must not stop Skip from working.
  final showCase = context.findAncestorStateOfType<ShowCaseWidgetState>();
  return FloatingActionWidget(
    top: MediaQuery.of(context).padding.top + 12.h,
    right: 16.w,
    child: TutorialSkipButton(
      onTap: () async {
        // Awaited: dismissing rebuilds the Home ShowCaseWidget, whose builder
        // restarts the step-0 spotlight while showHomeSpotlight is still set
        // (it is cleared at the end of skip()).
        await tutorial.skip();
        // skip() only ends the tutorial state: the spotlight overlay stays
        // up (the Home Showcase never leaves the tree) unless dismissed.
        try {
          showCase?.dismiss();
        } catch (_) {
          // nothing to dismiss
        }
      },
    ),
  );
}

/// The "Skip" pill, shared by every tutorial step that offers it.
///
/// Its own transparent [Material]: the showcase overlay and the step-4 dialog
/// stack have none, and a Text without one shows the yellow double underline
/// in debug. At least 44x44 to tap, 17 (not scaled, so 16-18 at any width)
/// bold, on a darker pill for contrast; never wraps or overflows.
class TutorialSkipButton extends StatelessWidget {
  final VoidCallback onTap;

  const TutorialSkipButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white54),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  AppString.tutorialSkip.tr,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
