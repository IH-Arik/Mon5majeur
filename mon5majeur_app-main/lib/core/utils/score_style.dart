import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// NBA-style scoreboard face (bold, condensed) for every score in the app —
/// QA 15/09/2026 item 4: home card, tonight's results, results tab, playoff
/// series popup and match detail all use this one style.
///
/// Bebas Neue is bundled (assets/fonts) so it renders offline; it ships a
/// single weight, so no FontWeight is set to avoid a synthetic faux-bold.
TextStyle scoreTextStyle({
  required double size,
  Color color = Colors.white,
  double letterSpacing = 1,
}) {
  return TextStyle(
    fontFamily: 'BebasNeue',
    fontSize: size.sp,
    color: color,
    letterSpacing: letterSpacing,
    height: 1.0,
  );
}
