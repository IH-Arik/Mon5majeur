import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_strings.dart';

/// The red "OUT" badge: same shape and font as the position badge, in red. One
/// widget for the player picker (injured players) and for the results / live
/// courts (a starter who played no minute), so both always look the same.
class OutBadge extends StatelessWidget {
  const OutBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFFE05353),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        AppString.playerStatusOut.tr,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
