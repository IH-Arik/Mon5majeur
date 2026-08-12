import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/custom_assets/assets.gen.dart';
import '../../../core/routes/route_path.dart';
import '../../../core/routes/routes.dart';
import 'shop_controller.dart';

class BuyTokenScreen extends StatelessWidget {
  const BuyTokenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            /// Custom Header
            Container(
              color: const Color(0xFF1A1A1A),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
              child: Column(
                children: [
                  /// Back Button and Title Row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            context.go(RoutePath.shopScreen.addBasePath),
                        child: SizedBox(
                          width: 30.w,
                          height: 30.h,
                          child: Assets.icons.backButton.image(
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            AppString.getMoreTokens.tr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 30.w), // Balance the back button
                    ],
                  ),
                  SizedBox(height: 16.h),

                  /// Token Icon
                  Assets.icons.morecoin.image(width: 30.5.w, height: 15.h),
                ],
              ),
            ),

            /// Body
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  children: [
                    SizedBox(height: 8.h),
                    Text(
                      AppString.choosePack.tr,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                        height: 1.57,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24.h),

                    /// Rookie Pack
                    _buildTokenPack(
                      context: context,
                      pack: 'rookie',
                      iconAsset: Assets.icons.rookle,
                      iconColor: const Color(0xFF7F38E8),
                      title: AppString.rookiePack.tr,
                      tokens: AppString.rookieTokens.tr,
                      price: AppString.rookiePrice.tr,
                      backgroundColor: const Color(0xFF1A2243),
                      gradientColors: [
                        const Color(0xFF8A35E9),
                        const Color(0xFF5145E5),
                      ],
                    ),
                    SizedBox(height: 20.h),

                    /// All Star Pack
                    _buildTokenPack(
                      context: context,
                      pack: 'all_star',
                      iconAsset: Assets.icons.allstar,
                      iconColor: const Color(0xFF5A43E6),
                      title: AppString.allStarPack.tr,
                      tokens: AppString.allStarTokens.tr,
                      price: AppString.allStarPrice.tr,
                      backgroundColor: const Color(0xFF291B49),
                      gradientColors: [
                        const Color(0xFF8A35E9),
                        const Color(0xFF5145E5),
                      ],
                    ),
                    SizedBox(height: 20.h),

                    /// MVP Pack
                    _buildTokenPack(
                      context: context,
                      pack: 'mvp',
                      iconAsset: Assets.icons.mvp,
                      iconColor: const Color(0xFFDD784E),
                      title: AppString.mvpPack.tr,
                      tokens: AppString.mvpTokens.tr,
                      price: AppString.mvpPrice.tr,
                      backgroundColor: const Color(0xFF2D1D20),
                      gradientColors: [
                        const Color(0xFFE8632C),
                        const Color(0xFFD58564),
                      ],
                    ),
                    SizedBox(height: 20.h),

                    /// Hall of Fame Pack
                    _buildTokenPack(
                      context: context,
                      pack: 'hall_of_fame',
                      iconAsset: Assets.icons.hall,
                      iconColor: const Color(0xFF4BCF96),
                      title: AppString.hallOfFamePack.tr,
                      tokens: AppString.hallOfFameTokens.tr,
                      price: AppString.hallOfFamePrice.tr,
                      backgroundColor: const Color(0xFF123431),
                      gradientColors: [
                        const Color(0xFF2CCA87),
                        const Color(0xFF61D2A0),
                      ],
                    ),
                    SizedBox(height: 30.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenPack({
    required BuildContext context,
    required String pack,
    required AssetGenImage iconAsset,
    required Color iconColor,
    required String title,
    required String tokens,
    required String price,
    required Color backgroundColor,
    required List<Color> gradientColors,
  }) {
    return Container(
      width: 302.w,
      height: 188.h,
      padding: EdgeInsets.all(19.w),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Icon + Title
          Row(
            children: [
              Container(
                width: 30.w,
                height: 27.h,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Center(
                  child: iconAsset.image(
                    width: 17.r,
                    height: 17.r,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              SizedBox(width: 11.w),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  height: 1.57,
                ),
              ),
            ],
          ),
          SizedBox(height: 32.h),

          /// Tokens Amount
          Text(
            tokens,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.w900,
              height: 1.10,
            ),
          ),
          SizedBox(height: 22.h),

          /// Price Button
          Obx(() {
            final c = Get.find<ShopController>();
            final loading = c.isPurchasingTokens.value;
            return GestureDetector(
              onTap: loading
                  ? null
                  : () => _confirmPurchase(context, c, pack, title, tokens),
              child: Container(
                width: double.infinity,
                height: 43.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(0.50, 0.00),
                    end: const Alignment(0.50, 1.00),
                    colors: gradientColors,
                  ),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Center(
                  child: loading
                      ? SizedBox(
                          width: 20.r,
                          height: 20.r,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          price,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w600,
                            height: 1.10,
                          ),
                        ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // TEMPORARY: mock purchase confirmation — no real payment is taken yet.
  // Swap for the real store checkout once App Store/Play Console products
  // exist (see ShopController.purchaseTokenPack / tokens/router.py).
  void _confirmPurchase(
    BuildContext context,
    ShopController c,
    String pack,
    String title,
    String tokens,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(title, style: TextStyle(color: Colors.white, fontSize: 16.sp)),
        content: Text(
          'Get $tokens for this pack?',
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
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await c.purchaseTokenPack(pack);
              if (ok) {
                Get.snackbar(
                  'Tokens added!',
                  '$tokens added to your wallet',
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
