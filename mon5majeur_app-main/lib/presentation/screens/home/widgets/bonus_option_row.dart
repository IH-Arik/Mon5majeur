import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';

/// One bonus of the team builder's menu: its icon, its name, how many are left,
/// and an "i" that says in a sentence what the bonus does (it never picks it).
class BonusOptionRow extends StatelessWidget {
  final AssetGenImage icon;
  final String label;
  final int count;
  final bool isActivated;
  final VoidCallback onTap;
  // The AppString key of the sentence.
  final String info;

  const BonusOptionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.isActivated,
    required this.onTap,
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          // The picture on its own, big: no circle around it.
          SizedBox(
            width: 40.w,
            height: 40.w,
            child: Center(
              child: icon.image(width: 36.w, height: 36.w, fit: BoxFit.contain, key: const ValueKey('bonus-icon')),
            ),
          ),
          SizedBox(width: 4.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              // Grey; orange while this is the bonus that is on.
              color: isActivated ? const Color(0xFFFF8C42) : const Color(0xFF777777),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontFamily: 'Lato',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 4.w),
          Container(
            width: 25.w,
            height: 24.h,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(6.r),
              border: Border.all(color: const Color(0xFF2C2C2C)),
            ),
            child: Center(
              child: Text(
                '$count',
                style: TextStyle(
                  color: const Color(0xFFE8632C),
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          // Its own tap: it opens the sentence and never picks the bonus.
          GestureDetector(
            key: ValueKey('bonus-info-$info'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _showInfo(context),
            child: SizedBox(
              width: 32.w,
              height: 32.h,
              child: Icon(Icons.info_outline, color: Colors.white70, size: 18.r),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(label, style: TextStyle(color: Colors.white, fontSize: 16.sp)),
        content: Text(info.tr, style: TextStyle(color: Colors.white70, fontSize: 14.sp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(AppString.ok.tr, style: const TextStyle(color: Color(0xFFFF6B35))),
          ),
        ],
      ),
    );
  }
}
