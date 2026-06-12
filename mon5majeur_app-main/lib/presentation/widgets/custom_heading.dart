import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/custom_assets/assets.gen.dart';

/// Reusable heading widget for multiple screens.
/// Supports both emoji and asset icons.
class CustomHeading extends StatelessWidget {
  final String title;
  final String? emoji; // optional text emoji
  final AssetGenImage? iconAsset; // optional image asset
  final String? routePath; // for back navigation
  final bool showBackButton;
  final bool showLogo;

  const CustomHeading({
    super.key,
    required this.title,
    this.emoji,
    this.iconAsset,
    this.routePath,
    this.showBackButton = true,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 48.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      color: Colors.transparent,
      child: Row(
        children: [
          /// 🔙 Back Button
          if (showBackButton)
            GestureDetector(
              onTap: () {
                if (routePath != null && routePath!.isNotEmpty) {
                  context.go(routePath!);
                } else {
                  context.pop();
                }
              },
              child: SizedBox(
                width: 30.w,
                height: 30.h,
                child: Assets.icons.backButton.image(fit: BoxFit.contain),
              ),
            )
          else
            SizedBox(width: 30.w, height: 30.h),

          const Spacer(),

          /// 🏷️ Title + Emoji/Icon (center)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontWeight: FontWeight.w700,
                  fontSize: 20.sp,
                  height: 22.h / 20.sp,
                  letterSpacing: 0,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 8.w),
              if (iconAsset != null)
                SizedBox(
                  width: 20.w,
                  height: 20.h,
                  child: iconAsset!.image(fit: BoxFit.contain),
                )
              else if (emoji != null && emoji!.isNotEmpty)
                Text(emoji!, style: TextStyle(fontSize: 20.sp)),
            ],
          ),

          const Spacer(),
        ],
      ),
    );
  }
}
