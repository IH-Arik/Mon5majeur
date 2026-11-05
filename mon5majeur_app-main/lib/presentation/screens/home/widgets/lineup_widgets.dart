import 'dart:ui' show ImageFilter;

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
  // 1.0 for a starter; the substitute's jersey is lighter (the "+", the label
  // and the texts stay at full strength).
  final double jerseyOpacity;
  // The name is shrunk to the slot's width instead of widening it (duel court,
  // where the slot stands at the very edge and must not grow past it).
  final bool fitName;
  // A fixed halo that follows the jersey's silhouette (the duel composition's
  // 6th Man once he is picked). Null for everybody else.
  final Color? glow;

  const LineupPlayerSlot({
    super.key,
    required this.player,
    required this.jersey,
    required this.label,
    required this.onTap,
    this.jerseyOpacity = 1.0,
    this.fitName = false,
    this.glow,
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
                if (glow != null) ...[
                  // Wide soft halo, then a tight bright edge: the laser.
                  _glowLayer(
                    Color.lerp(glow!, Colors.white, 0.2)!,
                    sigma: 8,
                    scale: 1.06,
                    alpha: 1,
                  ),
                  _glowLayer(
                    Color.lerp(glow!, Colors.white, 0.55)!,
                    sigma: 2.2,
                    scale: 1.02,
                    alpha: 1,
                  ),
                ],
                Positioned(
                  left: 0,
                  top: 0,
                  child: Opacity(
                    opacity: jerseyOpacity,
                    child: _jerseyPicture(),
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
            _name(p.name),
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

  Widget _jerseyPicture() => Container(
    width: 114.w,
    height: 91.h,
    decoration: BoxDecoration(
      image: DecorationImage(image: jersey.provider(), fit: BoxFit.cover),
    ),
  );

  // The jersey's own picture painted in one colour and blurred: its outline, not
  // a rectangle (the picture around the jersey is transparent).
  Widget _glowLayer(
    Color color, {
    required double sigma,
    required double scale,
    required double alpha,
  }) => Positioned(
    left: 0,
    top: 0,
    child: Transform.scale(
      scale: scale,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            color.withValues(alpha: alpha),
            BlendMode.srcIn,
          ),
          child: _jerseyPicture(),
        ),
      ),
    ),
  );

  Widget _name(String name) {
    final text = Text(
      name,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: const Color(0xFFFECD56),
        fontSize: 12.sp,
        fontFamily: 'Roboto',
        fontWeight: FontWeight.w600,
        height: 1.83,
      ),
    );
    if (!fitName) return text;
    return SizedBox(
      width: 114.w,
      child: FittedBox(fit: BoxFit.scaleDown, child: text),
    );
  }
}

/// The blue of the "6ÈME HOMME" bonus icon (measured on assets/icons/sixman.png).
const Color sixthManBlue = Color(0xFF2C46F4);

/// How strong the substitute's jersey is drawn (composition, and live while
/// nothing is decided).
const double substituteJerseyOpacity = 0.8;

/// The composition court is the usual 600 high plus [lineupBelowLine]: the
/// substitute stands on the half-way line (the top of his jersey on it, centred)
/// with his name and price in the other half. The line sits at 487.5 of the 600.
///
/// In pixels, not court units: under the line the slot holds the rest of the
/// jersey and the gaps (which the 600 already has room for, scaled with the
/// height) and two lines of text (scaled with the font), so on a small phone
/// the text would otherwise be cut off. 44 = the two lines of text, margin included.
double get lineupBelowLine => 44.sp;

/// Court units from the top of the court: the substitute's slot starts 11.5 above
/// the half-way line (the drawn jersey starts 11.5 under the top of its picture).
const double lineupSubstituteTop = 476;

/// The substitute's slot: the usual jersey slot labelled "Remplaçant" /
/// "Substitute", with a small "Retirer" action once somebody is picked (he is
/// optional, so he can be taken out again).
class LineupSubstituteSlot extends StatelessWidget {
  final Player? player;
  final AssetGenImage jersey;
  final VoidCallback onTap;
  final bool fitName;

  const LineupSubstituteSlot({
    super.key,
    required this.player,
    required this.jersey,
    required this.onTap,
    this.fitName = false,
  });

  @override
  Widget build(BuildContext context) {
    return LineupPlayerSlot(
      player: player,
      jersey: jersey,
      label: AppString.substitute.tr,
      onTap: onTap,
      jerseyOpacity: substituteJerseyOpacity,
      fitName: fitName,
    );
  }
}

/// The duel court's row on the half-way line: the substitute on the left edge, the
/// 6th Man on the right edge (null while that bonus is off). Fixed places, so
/// neither moves when the other appears. Both start with the top of
/// the jersey on the line ([lineupSubstituteTop]).
class LineupHalfwayRow extends StatelessWidget {
  final Widget substitute;
  final Widget? sixthMan;

  const LineupHalfwayRow({super.key, required this.substitute, this.sixthMan});

  @override
  Widget build(BuildContext context) {
    // Against the court's own edges: the guards' price tags end just above the
    // line, in the columns 103 and 258 of the court; a jersey there would touch
    // them on a small phone.
    return Positioned(
      top: lineupSubstituteTop.h,
      left: 0,
      right: 0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Align(alignment: Alignment.topLeft, child: substitute)),
          Expanded(
            child: sixthMan == null
                ? const SizedBox.shrink()
                : Align(alignment: Alignment.topRight, child: sixthMan),
          ),
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
  // Taller court when the 6th man needs his own row under the starters.
  final double? height;
  // More court under the half-way line (the substitute's name and price). The
  // picture is then the full court, so the line stays where it was.
  final double belowLine;

  // How far the four side players (wings and guards) sit further out toward
  // the edges of the court than their original offsets (40 / 60).
  static const double _flankShift = 14;

  const LineupCourt({
    super.key,
    required this.slotBuilder,
    required this.changeJerseyButton,
    this.inside = const [],
    this.floating = const [],
    this.height,
    this.belowLine = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          height: (height ?? 600.h) + belowLine,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.r)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: Stack(
              children: [
                if (belowLine > 0)
                  // 975 = the picture's height that puts the half-way line at
                  // 487.5, exactly where the half-court picture has it at 600.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 975.h,
                    child: Assets.images.fullplayground.image(fit: BoxFit.cover),
                  )
                else
                  Positioned.fill(
                    child: Assets.images.playground.image(fit: BoxFit.cover),
                  ),
                Positioned.fill(
                  child: Container(color: Colors.black.withValues(alpha: 0.3)),
                ),
                Positioned(top: 50.h, left: 20.w, child: changeJerseyButton),
                Positioned(
                  top: 150.h,
                  left: (40 - _flankShift).w,
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
                  right: (40 - _flankShift).w,
                  child: slotBuilder(2, AppString.sfPf),
                ),
                Positioned(
                  top: 320.h,
                  left: (60 - _flankShift).w,
                  child: slotBuilder(3, AppString.pgSg),
                ),
                Positioned(
                  top: 320.h,
                  right: (60 - _flankShift).w,
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
