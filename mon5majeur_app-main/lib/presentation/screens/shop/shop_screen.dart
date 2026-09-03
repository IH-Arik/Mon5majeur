import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/custom_assets/assets.gen.dart';
import '../../../core/routes/route_path.dart';
import '../../../core/routes/routes.dart';
import '../../widgets/navigation.dart';
import 'shop_controller.dart';

class _ShopOffer {
  final String slug;
  final String name;
  final int cost;

  const _ShopOffer({
    required this.slug,
    required this.name,
    required this.cost,
  });
}

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  static const _chefCurryOffer = _ShopOffer(
    slug: 'chef_curry',
    name: AppString.chefCurry,
    cost: 130,
  );
  static const _sixthManOffer = _ShopOffer(
    slug: 'sixth_man',
    name: AppString.sixthMan,
    cost: 170,
  );
  static const _luxuryTaxOffer = _ShopOffer(
    slug: 'luxury_tax',
    name: AppString.luxaryTax,
    cost: 150,
  );
  static const _liveScoringOffer = _ShopOffer(
    slug: 'live_scoring',
    name: AppString.liveScoring,
    cost: 200,
  );
  static const _stopPubOffer = _ShopOffer(
    slug: 'stop_pub',
    name: 'Stop-Pub',
    cost: 450,
  );

  @override
  Widget build(BuildContext context) {
    Get.put(ShopController());
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            /// Header
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppString.shop.tr,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                  Row(
                    children: [
                      /// Daily video earn button (ads disabled for launch)
                      if (kAdsEnabled)
                        Obx(() {
                          final c = Get.find<ShopController>();
                          return GestureDetector(
                          onTap: c.isEarningVideo.value
                              ? null
                              : () => c.earnDailyVideoTokens(),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 6.h),
                            margin: EdgeInsets.only(right: 8.w),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1a3d1a),
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                  color: const Color(0xFF2d6b2d), width: 1),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.play_circle_outline,
                                    color: Colors.greenAccent, size: 16.r),
                                SizedBox(width: 4.w),
                                Text(
                                  c.isEarningVideo.value
                                      ? '...'
                                      : '+6 ${AppString.tokens.tr.trim()}',
                                  style: TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      /// Token balance pill — the whole pill (not just the
                      /// number) is the tap target to reach the top-up
                      /// screen, plus a "+" cue so it reads as tappable.
                      GestureDetector(
                        onTap: () =>
                            context.go(RoutePath.buyToken.addBasePath),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2a2a2a),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Row(
                            children: [
                              Assets.icons.tokenIcon
                                  .image(width: 20.r, height: 20.r),
                              SizedBox(width: 6.w),
                              Obx(() {
                                final c = Get.find<ShopController>();
                                return Text(
                                  c.isLoadingBalance.value
                                      ? '...'
                                      : '${c.tokenBalance.value}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }),
                              SizedBox(width: 4.w),
                              Icon(
                                Icons.add_circle,
                                color: const Color(0xFFFF6B35),
                                size: 16.r,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            /// Scrollable Bonus Cards
            Expanded(
              child: Obx(() {
                final c = Get.find<ShopController>();
                final inv = c.inventory.value;
                return ListView(
                  padding: EdgeInsets.all(16.w),
                  children: [
                    /// Chef Curry
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
                      showStarIcon: true,
                      chargesRemaining: inv.chefCurryCharges,
                      onUnlock: () =>
                          _confirmPurchase(context, c, _chefCurryOffer),
                    ),

                    SizedBox(height: 16.h),

                    /// 6th Man
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
                      chargesRemaining: inv.sixthManCharges,
                      onUnlock: () =>
                          _confirmPurchase(context, c, _sixthManOffer),
                    ),

                    SizedBox(height: 16.h),

                    /// Luxury Tax
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
                      chargesRemaining: inv.luxuryTaxCharges,
                      onUnlock: () =>
                          _confirmPurchase(context, c, _luxuryTaxOffer),
                    ),

                    SizedBox(height: 16.h),

                    /// Live Scoring
                    _BonusCard(
                      backgroundColor: const Color(0xFF2d2444),
                      borderColor: const Color(0xFF4a3d6b),
                      iconAsset: Assets.icons.livescoring,
                      title: AppString.liveScoring.tr,
                      subtitle: AppString.realTimeUpdate.tr,
                      description: AppString.liveScoringDesc.tr,
                      tokenAmount: '${_liveScoringOffer.cost}',
                      tokenSuffix: AppString.perMonth.tr,
                      buttonText: inv.liveScoringActive
                          ? 'Active ✓'
                          : AppString.unlock.tr,
                      buttonColor: inv.liveScoringActive
                          ? const Color(0xFF10B981)
                          : const Color(0xFF8B5CF6),
                      badge: AppString.pro.tr,
                      badgeColor: const Color(0xFFFF6B35),
                      onUnlock: inv.liveScoringActive
                          ? null
                          : () =>
                              _confirmPurchase(context, c, _liveScoringOffer),
                    ),

                    SizedBox(height: 16.h),

                    /// Stop-Pub (ads disabled for launch)
                    if (kAdsEnabled) ...[
                      _BonusCard(
                        backgroundColor: const Color(0xFF2d1a1a),
                        borderColor: const Color(0xFF6b2d2d),
                        iconAsset: Assets.icons.livescoring,
                        title: 'Stop-Pub',
                        subtitle: 'Remove all ads',
                        description:
                            'Enjoy the app without any advertisements for a full year.',
                        tokenAmount: '${_stopPubOffer.cost}',
                        tokenSuffix: AppString.perYear.tr,
                        buttonText: inv.stopPubActive
                            ? 'Active ✓'
                            : AppString.unlock.tr,
                        buttonColor: inv.stopPubActive
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        onUnlock: inv.stopPubActive
                            ? null
                            : () =>
                                _confirmPurchase(context, c, _stopPubOffer),
                      ),
                      SizedBox(height: 16.h),
                    ],

                    /// Jersey SALE — reserved for a future in-game jersey
                    /// store (QA 28/08/2026 #2). This card must stay a
                    /// "Coming soon" placeholder: it is not the same thing
                    /// as the free jersey customization already reachable
                    /// from team building — this card used to open that
                    /// same free-styles screen, which is out of scope here
                    /// and confuses players into thinking there's nothing
                    /// left to sell.
                    _BonusCard(
                      backgroundColor: const Color(0xFF1a2744),
                      borderColor: const Color(0xFF2d4a7c),
                      iconAsset: Assets.icons.jersey,
                      title: AppString.jersey.tr,
                      subtitle: AppString.comingSoon.tr,
                      description: AppString.jerseySelectionHint.tr,
                      tokenAmount: '',
                      buttonText: AppString.comingSoon.tr,
                      buttonColor: const Color(0xFF8B5CF6),
                      onUnlock: null,
                    ),

                    SizedBox(height: 80.h),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const NavigationWidget(currentIndex: 3),
    );
  }

  void _confirmPurchase(
    BuildContext context,
    ShopController c,
    _ShopOffer offer,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          'Confirm Purchase',
          style: TextStyle(color: Colors.white, fontSize: 16.sp),
        ),
        content: Text(
          'Buy ${offer.name.tr} for ${offer.cost} tokens?\n\nYour balance: ${c.tokenBalance.value} tokens.',
          style: TextStyle(color: Colors.grey, fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: TextStyle(color: Colors.grey, fontSize: 13.sp)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await c.purchaseBonus(offer.slug);
              if (ok) {
                Get.snackbar(
                  'Purchased!',
                  offer.slug == _liveScoringOffer.slug
                      ? '${offer.name.tr} activated for 30 days'
                      : '${offer.name.tr} added to your inventory',
                  backgroundColor: const Color(0xFF1a3d1a),
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
            child: Text('Buy',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

}

// ─── Bonus Card Widget ────────────────────────────────────────────────────────

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
  final bool showStarIcon;
  final int chargesRemaining;
  final VoidCallback? onUnlock;

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
    this.showStarIcon = false,
    this.chargesRemaining = 0,
    this.onUnlock,
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
          /// Header: icon + title + badge
          Row(
            children: [
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (chargesRemaining > 0) ...[
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1a3d1a),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Text(
                              'x$chargesRemaining',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey, fontSize: 13.sp),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 12.w, vertical: 6.h),
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
                color: Colors.grey, fontSize: 14.sp, height: 1.4),
          ),

          SizedBox(height: 20.h),

          /// Token amount + unlock button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (tokenAmount.isNotEmpty)
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
                            color: Colors.white, fontSize: 14.sp),
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
              Obx(() {
                final c = Get.find<ShopController>();
                final loading = c.isPurchasing.value;
                return ElevatedButton(
                  onPressed: loading ? null : onUnlock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    disabledBackgroundColor: buttonColor.withValues(alpha: 0.5),
                    padding: EdgeInsets.symmetric(
                        horizontal: 24.w, vertical: 12.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: loading
                      ? SizedBox(
                          width: 16.r,
                          height: 16.r,
                          child: const CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          buttonText,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                          ),
                        ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
