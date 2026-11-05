import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../data/models/match_result_model.dart';
import '../../../../data/models/substitution_model.dart';

/// The substitute under a lineup on the Results and Live screens.
///
///  * entered     - normal card, his points count, "🔄 X remplace Y";
///  * did not enter - darker card, "Non entré" badge, points in parentheses and
///    not counted, no 🔄;
///  * pending (live: not every game is final) - nothing decided: darker card,
///    points in parentheses, no 🔄 and no badge.
class SubstituteResultCard extends StatelessWidget {
  final PlayerSelection substitute;
  final SubstitutionState? state;
  final String? replacedName;
  final bool scoresHidden;

  const SubstituteResultCard({
    super.key,
    required this.substitute,
    required this.state,
    this.replacedName,
    this.scoresHidden = false,
  });

  @override
  Widget build(BuildContext context) {
    final entered = state?.isEntered ?? false;
    final notEntered = state?.isNotEntered ?? false;
    final counts = entered;
    return Container(
      key: const ValueKey('substitute-card'),
      margin: EdgeInsets.only(top: 8.h),
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: 362.w),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: counts ? const Color(0xFF1A1C2A) : const Color(0xFF0D0E15),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF2C2C2C), width: 1.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppString.substitute.tr,
                style: TextStyle(color: Colors.white54, fontSize: 11.sp),
              ),
              const Spacer(),
              if (notEntered)
                Container(
                  key: const ValueKey('substitute-not-entered'),
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2D3E),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    AppString.substituteDidNotEnter.tr,
                    style: TextStyle(color: Colors.white70, fontSize: 10.sp),
                  ),
                ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  substitute.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: counts ? const Color(0xFFFECD56) : Colors.white38,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (scoresHidden)
                Icon(Icons.lock_outline, color: Colors.grey, size: 14.r)
              else
                Text(
                  counts ? '${substitute.score}' : '(${substitute.score})',
                  key: const ValueKey('substitute-points'),
                  style: TextStyle(
                    color: counts ? Colors.white : Colors.white38,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          if (entered && replacedName != null) ...[
            SizedBox(height: 4.h),
            Text(
              AppString.substituteReplaces.trParams({
                'sub': substitute.name,
                'starter': replacedName!,
              }),
              key: const ValueKey('substitute-replaces'),
              style: TextStyle(color: Colors.white70, fontSize: 12.sp),
            ),
          ],
        ],
      ),
    );
  }
}
