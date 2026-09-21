import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// The position pill under a jersey ("PG/SG", "SF/PF", "C") — ONE component
/// for the private league AND the Global League (QA 15/09/2026 items 6 & 9).
///
/// Fixes the old cut-off labels: it sizes itself to its text (no fixed-height
/// box that clipped the bottom, no fixed-width box that turned "PG/SG" into
/// "PG/"), has equal padding above and below, rounded corners and centred
/// text. Callers must place it in a Stack that does not clip
/// (`clipBehavior: Clip.none`) or leave enough room below it.
class PositionLabel extends StatelessWidget {
  final String label;
  final Color background;
  final Color textColor;

  const PositionLabel(
    this.label, {
    super.key,
    this.background = const Color(0xFF777777),
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: Colors.white, width: 0.5.r),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor,
          fontSize: 9.sp,
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w600,
          height: 1.15,
        ),
      ),
    );
  }
}
