import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../data/models/player.dart';
import 'position_label.dart';

/// Shared team-builder building blocks — ONE implementation for the private
/// league AND the Global League (QA 15/09/2026: "same components across
/// private and Global leagues"). Before this, both screens carried their own
/// copy of the slot, jersey button and court layout, and drifted apart.

/// One jersey slot: jersey, position pill, and — once picked — the player's
/// name and price. An empty slot shows a small "+" bubble that sits below the
/// jersey number instead of covering it.
class LineupPlayerSlot extends StatelessWidget {
  final Player? player;
  final AssetGenImage jersey;
  final String label;
  final VoidCallback onTap;

  const LineupPlayerSlot({
    super.key,
    required this.player,
    required this.jersey,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = player;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            width: 114.w,
            height: 104.h,
            child: Stack(
              // The position pill hangs below the jersey; never clip it.
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    width: 114.w,
                    height: 91.h,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: jersey.provider(),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 84.h,
                  child: Center(child: PositionLabel(label)),
                ),
                if (p == null)
                  Positioned(
                    left: 47.w,
                    top: 58.h,
                    child: Container(
                      width: 18.w,
                      height: 18.h,
                      decoration: const ShapeDecoration(
                        color: Color(0xFFFF8C42),
                        shape: OvalBorder(),
                      ),
                      child: Icon(Icons.add, color: Colors.white, size: 13.r),
                    ),
                  ),
              ],
            ),
          ),
          if (p != null) ...[
            SizedBox(height: 8.h),
            Text(
              p.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFFECD56),
                fontSize: 12.sp,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w600,
                height: 1.83,
              ),
            ),
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              decoration: ShapeDecoration(
                color: const Color(0xFF1A1A1A),
                shape: RoundedRectangleBorder(
                  side: BorderSide(width: 1.r, color: const Color(0xFF2C2C2C)),
                  borderRadius: BorderRadius.circular(6.r),
                ),
              ),
              child: Text(
                '${p.price.toInt()}M',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w800,
                  height: 1.83,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Changer de maillot +" button at the top-left of the court.
class LineupChangeJerseyButton extends StatelessWidget {
  final AssetGenImage jersey;
  final VoidCallback onTap;

  const LineupChangeJerseyButton({
    super.key,
    required this.jersey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60.w,
        height: 80.h,
        decoration: ShapeDecoration(
          color: const Color(0xFF2C2C2C),
          shape: RoundedRectangleBorder(
            side: BorderSide(width: 1.r, color: const Color(0xFF1A1A1A)),
            borderRadius: BorderRadius.circular(6.r),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 35.w,
              height: 35.h,
              child: jersey.image(fit: BoxFit.contain),
            ),
            SizedBox(height: 4.h),
            Text(
              AppString.changeJersey.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 8.sp,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w400,
                height: 1.2,
              ),
            ),
            Text(
              AppString.plus,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w100,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The half-court with the five lineup slots (2 forwards + centre on top,
/// 2 guards below). [inside] widgets are drawn on the court (bonus button,
/// 6th-man slot); [floating] widgets sit above it and may extend past its
/// edge (the bonus menu).
class LineupCourt extends StatelessWidget {
  final Widget Function(int index, String label) slotBuilder;
  final Widget changeJerseyButton;
  final List<Widget> inside;
  final List<Widget> floating;

  const LineupCourt({
    super.key,
    required this.slotBuilder,
    required this.changeJerseyButton,
    this.inside = const [],
    this.floating = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          height: 600.h,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.r)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Assets.images.playground.image(fit: BoxFit.cover),
                ),
                Positioned.fill(
                  child: Container(color: Colors.black.withValues(alpha: 0.3)),
                ),
                Positioned(top: 50.h, left: 20.w, child: changeJerseyButton),
                Positioned(
                  top: 150.h,
                  left: 40.w,
                  child: slotBuilder(0, AppString.sfPf),
                ),
                Positioned(
                  top: 120.h,
                  left: 0,
                  right: 0,
                  child: Center(child: slotBuilder(1, AppString.c)),
                ),
                Positioned(
                  top: 150.h,
                  right: 40.w,
                  child: slotBuilder(2, AppString.sfPf),
                ),
                Positioned(
                  top: 320.h,
                  left: 60.w,
                  child: slotBuilder(3, AppString.pgSg),
                ),
                Positioned(
                  top: 320.h,
                  right: 60.w,
                  child: slotBuilder(4, AppString.pgSg),
                ),
                ...inside,
              ],
            ),
          ),
        ),
        ...floating,
      ],
    );
  }
}
