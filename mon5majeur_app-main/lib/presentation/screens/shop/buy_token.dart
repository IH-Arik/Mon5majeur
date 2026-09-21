import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/custom_assets/assets.gen.dart';
import '../../../core/routes/route_path.dart';
import '../../../core/routes/routes.dart';
import '../../../core/services/revenuecat_service.dart';
import 'shop_controller.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Premium Paywall Screen — a polished, animated purchase flow powered by
/// RevenueCat.  Falls back to the backend mock-purchase endpoint when no
/// store products are available (sandbox / early testing).
/// ─────────────────────────────────────────────────────────────────────────────

class BuyTokenScreen extends StatefulWidget {
  const BuyTokenScreen({super.key});

  @override
  State<BuyTokenScreen> createState() => _BuyTokenScreenState();
}

class _BuyTokenScreenState extends State<BuyTokenScreen>
    with TickerProviderStateMixin {
  // ── State ───────────────────────────────────────────────────────────────
  Offerings? _offerings;
  bool _isLoadingOfferings = true;
  bool _isPurchasing = false;
  String? _errorMessage;

  // Pack definitions (slug ↔ RevenueCat product id)
  static const _packs = [
    _PackDef(
      slug: 'rookie',
      rcProductId: 'tokens_200_rookie',
      name: 'Rookie Pack',
      tokens: 200,
      fallbackPrice: '\$1.99',
      iconGradient: [Color(0xFF8A35E9), Color(0xFF5145E5)],
      cardBg: Color(0xFF1A2243),
      iconBgColor: Color(0xFF7F38E8),
    ),
    _PackDef(
      slug: 'all_star',
      rcProductId: 'tokens_550_allstar',
      name: 'All-Star Pack',
      tokens: 550,
      fallbackPrice: '\$4.99',
      iconGradient: [Color(0xFF5B8DEF), Color(0xFF3A5FCD)],
      cardBg: Color(0xFF182240),
      iconBgColor: Color(0xFF5A43E6),
      badgeText: 'POPULAR',
      badgeColor: Color(0xFFFF6B35),
    ),
    _PackDef(
      slug: 'mvp',
      rcProductId: 'tokens_1200_mvp',
      name: 'MVP Pack',
      tokens: 1200,
      fallbackPrice: '\$9.99',
      iconGradient: [Color(0xFFE8632C), Color(0xFFD58564)],
      cardBg: Color(0xFF2D1D20),
      iconBgColor: Color(0xFFDD784E),
      badgeText: 'BEST VALUE',
      badgeColor: Color(0xFF10B981),
    ),
    _PackDef(
      slug: 'hall_of_fame',
      rcProductId: 'tokens_2500_halloffame',
      name: 'Hall of Fame',
      tokens: 2500,
      fallbackPrice: '\$19.99',
      iconGradient: [Color(0xFF2CCA87), Color(0xFF61D2A0)],
      cardBg: Color(0xFF123431),
      iconBgColor: Color(0xFF4BCF96),
    ),
  ];

  // Animations
  late final AnimationController _shimmerController;
  late final AnimationController _fadeInController;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(
      parent: _fadeInController,
      curve: Curves.easeOutCubic,
    );

    _loadOfferings();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _fadeInController.dispose();
    super.dispose();
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await RevenueCatService.instance.fetchOfferings();
      if (mounted) {
        setState(() {
          _offerings = offerings;
          _isLoadingOfferings = false;
        });
        _fadeInController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingOfferings = false;
          // Still show the packs — we'll use fallback prices
        });
        _fadeInController.forward();
      }
    }
  }

  /// Tries to find the RevenueCat package that matches [packDef].
  Package? _packageFor(_PackDef packDef) {
    if (_offerings == null) return null;
    final current = _offerings!.current;
    if (current == null) return null;
    for (final pkg in current.availablePackages) {
      if (pkg.storeProduct.identifier == packDef.rcProductId) {
        return pkg;
      }
    }
    return null;
  }

  /// The price string to display on a pack card.
  String _priceFor(_PackDef packDef) {
    final pkg = _packageFor(packDef);
    if (pkg != null) return pkg.storeProduct.priceString;
    return packDef.fallbackPrice;
  }

  Future<void> _handlePurchase(_PackDef packDef) async {
    if (_isPurchasing) return;
    setState(() => _isPurchasing = true);

    try {
      final pkg = _packageFor(packDef);
      if (pkg != null) {
        // ── Real store purchase via RevenueCat ──
        final info =
            await RevenueCatService.instance.purchasePackage(pkg);
        if (info != null && mounted) {
          // Credit the tokens on the backend so the wallet stays in sync
          final c = Get.find<ShopController>();
          await c.purchaseTokenPack(packDef.slug);
          if (mounted) {
            _showSuccessSnackbar(packDef);
          }
        }
      } else {
        // ── No store product available → mock purchase (dev / sandbox) ──
        final c = Get.find<ShopController>();
        final ok = await c.purchaseTokenPack(packDef.slug);
        if (ok && mounted) {
          _showSuccessSnackbar(packDef);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Purchase failed. Please try again.';
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _errorMessage = null);
        });
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  void _showSuccessSnackbar(_PackDef packDef) {
    Get.snackbar(
      '🎉 Tokens Added!',
      '+${packDef.tokens} tokens added to your wallet',
      backgroundColor: const Color(0xFF1a3d1a),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: EdgeInsets.all(16.w),
      borderRadius: 12.r,
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> _handleRestore() async {
    setState(() => _isPurchasing = true);
    try {
      await RevenueCatService.instance.restorePurchases();
      if (mounted) {
        Get.snackbar(
          'Restored',
          'Your purchases have been restored.',
          backgroundColor: const Color(0xFF1a2744),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(16.w),
          borderRadius: 12.r,
        );
      }
    } catch (_) {
      if (mounted) {
        Get.snackbar(
          'Error',
          'Could not restore purchases. Try again later.',
          backgroundColor: const Color(0xFF3a0000),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(16.w),
          borderRadius: 12.r,
        );
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          // ── Background glow effect ─────────────────────────────────────
          Positioned(
            top: -120.h,
            left: -80.w,
            child: Container(
              width: 300.r,
              height: 300.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8A35E9).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -60.h,
            right: -100.w,
            child: Container(
              width: 250.r,
              height: 250.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF6B35).withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Main content ────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: _isLoadingOfferings
                      ? _buildLoadingSkeleton()
                      : FadeTransition(
                          opacity: _fadeIn,
                          child: _buildBody(),
                        ),
                ),
              ],
            ),
          ),

          // ── Purchasing overlay ──────────────────────────────────────────
          if (_isPurchasing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: EdgeInsets.all(32.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 40.r,
                        height: 40.r,
                        child: const CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFFF6B35),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'Processing...',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () =>
                    context.go(RoutePath.shopScreen.addBasePath),
                child: Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18.r,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  AppString.getMoreTokens.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              SizedBox(width: 40.w),
            ],
          ),
          SizedBox(height: 8.h),

          // Token balance pill
          Obx(() {
            final c = Get.find<ShopController>();
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 8.h,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF6B35).withValues(alpha: 0.15),
                    const Color(0xFF8A35E9).withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(30.r),
                border: Border.all(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Assets.icons.tokenIcon.image(
                    width: 20.r,
                    height: 20.r,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '${c.tokenBalance.value}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'tokens',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Body ────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      physics: const BouncingScrollPhysics(),
      children: [
        SizedBox(height: 4.h),

        // Subtitle
        Text(
          AppString.choosePack.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white60,
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
        SizedBox(height: 20.h),

        // Error banner
        if (_errorMessage != null) ...[
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFF3a0000),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.redAccent, size: 20.r),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.white70, fontSize: 13.sp),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
        ],

        // Pack cards
        for (int i = 0; i < _packs.length; i++) ...[
          _buildPackCard(_packs[i], delay: i * 0.12),
          SizedBox(height: 14.h),
        ],

        SizedBox(height: 12.h),

        // Restore purchases
        Center(
          child: TextButton(
            onPressed: _isPurchasing ? null : _handleRestore,
            child: Text(
              'Restore Purchases',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white38,
              ),
            ),
          ),
        ),

        SizedBox(height: 40.h),
      ],
    );
  }

  // ── Pack Card ──────────────────────────────────────────────────────────
  Widget _buildPackCard(_PackDef pack, {double delay = 0}) {
    final price = _priceFor(pack);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (delay * 1000).toInt()),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value.clamp(0, 1),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: _isPurchasing ? null : () => _handlePurchase(pack),
        child: Container(
          decoration: BoxDecoration(
            color: pack.cardBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: pack.iconGradient.first.withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: pack.iconGradient.first.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: Stack(
              children: [
                // Subtle shimmer overlay
                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, _) {
                    return Positioned.fill(
                      child: ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            begin: Alignment(
                                -2 + 4 * _shimmerController.value, 0),
                            end: Alignment(
                                -1 + 4 * _shimmerController.value, 0),
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.03),
                              Colors.transparent,
                            ],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.srcATop,
                        child: Container(color: Colors.white),
                      ),
                    );
                  },
                ),

                // Content
                Padding(
                  padding: EdgeInsets.all(18.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: icon + name + badge
                      Row(
                        children: [
                          // Icon container
                          Container(
                            width: 44.r,
                            height: 44.r,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: pack.iconGradient,
                              ),
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [
                                BoxShadow(
                                  color: pack.iconGradient.first
                                      .withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Assets.icons.morecoin.image(
                                width: 24.r,
                                height: 24.r,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pack.name,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  '${pack.tokens} TOKENS',
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.5),
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (pack.badgeText != null)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 5.h,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    pack.badgeColor ?? const Color(0xFFFF6B35),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Text(
                                pack.badgeText!,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),

                      SizedBox(height: 18.h),

                      // Price button
                      Container(
                        width: double.infinity,
                        height: 48.h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: pack.iconGradient,
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: [
                            BoxShadow(
                              color: pack.iconGradient.first
                                  .withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            price,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Loading skeleton ───────────────────────────────────────────────────
  Widget _buildLoadingSkeleton() {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        SizedBox(height: 30.h),
        for (int i = 0; i < 4; i++) ...[
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, _) {
              return Container(
                height: 120.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.r),
                  gradient: LinearGradient(
                    begin: Alignment(
                      -2 + 4 * _shimmerController.value,
                      0,
                    ),
                    end: Alignment(
                      -1 + 4 * _shimmerController.value,
                      0,
                    ),
                    colors: [
                      Colors.white.withValues(alpha: 0.03),
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.03),
                    ],
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 14.h),
        ],
      ],
    );
  }
}

// ─── Pack definition ─────────────────────────────────────────────────────────

class _PackDef {
  final String slug;
  final String rcProductId;
  final String name;
  final int tokens;
  final String fallbackPrice;
  final List<Color> iconGradient;
  final Color cardBg;
  final Color iconBgColor;
  final String? badgeText;
  final Color? badgeColor;

  const _PackDef({
    required this.slug,
    required this.rcProductId,
    required this.name,
    required this.tokens,
    required this.fallbackPrice,
    required this.iconGradient,
    required this.cardBg,
    required this.iconBgColor,
    this.badgeText,
    this.badgeColor,
  });
}
