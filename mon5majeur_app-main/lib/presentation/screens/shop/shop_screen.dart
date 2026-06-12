import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/custom_assets/assets.gen.dart';
import '../../../core/routes/route_path.dart';
import '../../../core/routes/routes.dart';
import '../../widgets/navigation.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            /// Header Section
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  /// Title
                  Text(
                    AppString.shop.tr,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  /// Placeholder for symmetry
                  SizedBox(width: 28.w),
                ],
              ),
            ),

            /// Token Balance Header
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a1a),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppString.bonuses.tr,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2a2a2a),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      children: [
                        Assets.icons.tokenIcon.image(width: 20.r, height: 20.r),
                        SizedBox(width: 6.w),
                        GestureDetector(
                          onTap: () =>
                              context.go(RoutePath.buyToken.addBasePath),
                          child: Text(
                            AppString.tokenAmount.tr,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            /// Scrollable Bonus Cards
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(16.w),
                children: [
                  /// Chef Curry Card (Brown/Popular)
                  _BonusCard(
                    backgroundColor: const Color(0xFF3d2f2f),
                    borderColor: const Color(0xFFFF6B35),
                    iconAsset: Assets.icons.chefcurry,
                    title: AppString.chefCurry.tr,
                    subtitle: AppString.doublePoints.tr,
                    description: AppString.chefCurryDesc.tr,
                    tokenAmount: '130',
                    buttonText: AppString.unlock.tr,
                    buttonColor: const Color(0xFFFF6B35),
                    badge: AppString.popular.tr,
                    badgeColor: const Color(0xFFFF6B35),
                    showMoreCoinIcon: true,
                    showStarIcon: true,
                  ),

                  SizedBox(height: 16.h),

                  /// 6th Man Card (Navy Blue)
                  _BonusCard(
                    backgroundColor: const Color(0xFF1a2744),
                    borderColor: const Color(0xFF2d4a7c),
                    iconAsset: Assets.icons.sixman,
                    title: AppString.sixthMan.tr,
                    subtitle: AppString.extraPlayer.tr,
                    description: AppString.sixthManDesc.tr,
                    tokenAmount: '170',
                    buttonText: AppString.unlock.tr,
                    buttonColor: const Color(0xFF8B5CF6),
                  ),

                  SizedBox(height: 16.h),

                  /// Luxary Tax Card (Dark Green)
                  _BonusCard(
                    backgroundColor: const Color(0xFF1a3d32),
                    borderColor: const Color(0xFF2d6b54),
                    iconAsset: Assets.icons.luxarytax,
                    title: AppString.luxaryTax.tr,
                    subtitle: AppString.budgetBoost.tr,
                    description: AppString.luxaryTaxDesc.tr,
                    tokenAmount: '150',
                    buttonText: AppString.unlock.tr,
                    buttonColor: const Color(0xFF10B981),
                  ),

                  SizedBox(height: 16.h),

                  /// Live Scoring Card (Dark Purple/PRO)
                  _BonusCard(
                    backgroundColor: const Color(0xFF2d2444),
                    borderColor: const Color(0xFF4a3d6b),
                    iconAsset: Assets.icons.livescoring,
                    title: AppString.liveScoring.tr,
                    subtitle: AppString.realTimeUpdate.tr,
                    description: AppString.liveScoringDesc.tr,
                    tokenAmount: '700',
                    tokenSuffix: AppString.perYear.tr,
                    buttonText: AppString.unlock.tr,
                    buttonColor: const Color(0xFF8B5CF6),
                    badge: AppString.pro.tr,
                    badgeColor: const Color(0xFFFF6B35),
                  ),

                  SizedBox(height: 16.h),

                  /// Jersey Card (Navy Blue/Coming Soon)
                  _BonusCard(
                    backgroundColor: const Color(0xFF1a2744),
                    borderColor: const Color(0xFF2d4a7c),
                    iconAsset: Assets.icons.jersey,
                    title: AppString.jersey.tr,
                    subtitle: AppString.buyCustomJerseys.tr,
                    description: AppString.comingSoon.tr,
                    tokenAmount: '',
                    buttonText: AppString.comingSoon.tr,
                    buttonColor: const Color(0xFF8B5CF6),
                    isComingSoon: true,
                  ),

                  SizedBox(height: 80.h),
                ],
              ),
            ),
          ],
        ),
      ),

      /// Bottom Navigation Bar
      bottomNavigationBar: const NavigationWidget(currentIndex: 3),
    );
  }
}

class _BonusCard extends StatelessWidget {
  final Color backgroundColor;
  final Color borderColor;
  final AssetGenImage iconAsset;
  final String title;
  final String subtitle;
  final String description;
  final String tokenAmount;
  final String tokenSuffix;
  final String buttonText;
  final Color buttonColor;
  final String? badge;
  final Color? badgeColor;
  final bool isComingSoon;
  final bool showMoreCoinIcon;
  final bool showStarIcon;

  const _BonusCard({
    required this.backgroundColor,
    required this.borderColor,
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.tokenAmount,
    this.tokenSuffix = '',
    required this.buttonText,
    required this.buttonColor,
    this.badge,
    this.badgeColor,
    this.isComingSoon = false,
    this.showMoreCoinIcon = false,
    this.showStarIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: borderColor, width: 1.5.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Header with Icon, Title, and Badge
          Row(
            children: [
              /// Icon
              Container(
                width: 50.r,
                height: 50.r,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: borderColor, width: 2.w),
                ),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(2.w),
                    child: iconAsset.image(fit: BoxFit.cover),
                  ),
                ),
              ),

              SizedBox(width: 12.w),

              /// Title and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey, fontSize: 13.sp),
                    ),
                  ],
                ),
              ),

              /// Badge (Popular/PRO) with optional star icon
              if (badge != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showStarIcon) ...[
                        Assets.icons.star.image(width: 14.r, height: 14.r),
                        SizedBox(width: 4.w),
                      ],
                      Text(
                        badge!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          SizedBox(height: 16.h),

          /// Description
          Text(
            description,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14.sp,
              height: 1.4,
            ),
          ),

          SizedBox(height: 20.h),

          /// Token Amount and Unlock Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              /// Token Display
              if (!isComingSoon)
                Row(
                  children: [
                    Assets.icons.morecoin.image(width: 24.r, height: 24.r),
                    SizedBox(width: 6.w),
                    Text(
                      tokenAmount,
                      style: TextStyle(
                        color: const Color(0xFFFFD700),
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (tokenSuffix.isNotEmpty)
                      Text(
                        ' $tokenSuffix',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                        ),
                      )
                    else
                      Text(
                        AppString.tokens.tr,
                        style: TextStyle(
                          color: const Color(0xFFFFD700),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),

              /// Unlock Button
              ElevatedButton(
                onPressed: isComingSoon ? null : () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  disabledBackgroundColor: buttonColor,
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 12.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
