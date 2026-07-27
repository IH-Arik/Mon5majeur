import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../controllers/global_league_controller.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/custom_assets/assets.gen.dart';
import '../../../core/routes/route_path.dart';
import '../../../core/routes/routes.dart';
import '../../widgets/navigation.dart';
import 'controllers/home_controller.dart';
import 'widgets/home_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Logo bounce animation
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoRotation = Tween<double>(
      begin: -0.1,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));

    // Pulse animation for notification
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Slide animation for cards
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.3.h), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    // Start animations
    _logoController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Initialize home controller
    final homeController = Get.find<HomeController>();

    return Scaffold(
      backgroundColor: Colors.black,
      endDrawer: const HomeDrawer(),
      body: Stack(
        children: [
          /// Background Image with parallax effect
          Positioned(
            top: -100.h,
            left: 0,
            right: 0,
            bottom: 0,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1.0),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: 0.15,
                    child: Assets.images.homebg.image(fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),

          /// Main Content
          SafeArea(
            child: Column(
              children: [
                /// 🔹 Animated Team Logo and Name (API-driven)
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _logoScale.value,
                      child: Transform.rotate(
                        angle: _logoRotation.value,
                        child: Obx(() {
                          return Column(
                            children: [
                              Hero(
                                tag: AppString.teamLogoTag,
                                child: Container(
                                  width: 50.w,
                                  height: 50.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFFF6B35),
                                      width: 3.r,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        // color: const Color(
                                        //   0xFFFF6B35,
                                        // ).withOpacity(0.5),
                                        // blurRadius: 20.r,
                                        // spreadRadius: 2.r,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: homeController.isLoading.value
                                        ? SizedBox(
                                            width: 20.w,
                                            height: 20.w,
                                            child:
                                                const CircularProgressIndicator(
                                                  color: Color(0xFFFF6B35),
                                                  strokeWidth: 2,
                                                ),
                                          )
                                        : homeController.displayTeamLogo.image(
                                            width: 30.w,
                                            height: 30.w,
                                            fit: BoxFit.contain,
                                          ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                homeController.displayTeamName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    );
                  },
                ),

                /// Header Section
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 4.h,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      /// Notification + Menu
                      Row(
                        children: [
                          /// Pulsing Notification Icon
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  padding: EdgeInsets.all(8.r),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      // BoxShadow(
                                      //   color: Colors.yellow.withOpacity(0.4),
                                      //   blurRadius: 10.r,
                                      //   spreadRadius: 2.r,
                                      // ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.notifications,
                                    color: Colors.yellow,
                                    size: 24.r,
                                  ),
                                ),
                              );
                            },
                          ),
                          SizedBox(width: 12.w),
                          Builder(
                            builder: (context) => GestureDetector(
                              onTap: () => Scaffold.of(context).openEndDrawer(),
                              child: Icon(
                                Icons.menu,
                                color: Colors.white,
                                size: 28.r,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                /// 🔹 Main Scrollable Content with Slide Animation
                Expanded(
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _slideController,
                      child: RefreshIndicator(
                        onRefresh: homeController.refreshProfile,
                        color: const Color(0xFFFF6B35),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: Column(
                            children: [
                              SizedBox(height: 12.h),

                              /// 🔹 Global League status + stats card
                              _GlobalLeagueCard(),

                              SizedBox(height: 16.h),

                              /// 🔹 Join/Create League Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: _AnimatedActionCard(
                                      title: AppString.joinLeague.tr,
                                      delay: 100,
                                      onTap: () => context.go(
                                        RoutePath
                                            .chooseALeagueScreen
                                            .addBasePath,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: _AnimatedActionCard(
                                      title: AppString.createALeague.tr,
                                      delay: 200,
                                      onTap: () => context.go(
                                        RoutePath
                                            .createLeagueScreen
                                            .addBasePath,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 16.h),

                              /// 🔹 Night's Results
                              _SectionHeader(
                                title: AppString.nightsResults.tr,
                                linkText: AppString.allMatches.tr,
                                onTap: () => context.go(
                                  RoutePath.myMatchToday.addBasePath,
                                ),
                              ),
                              SizedBox(height: 16.h),

                              /// Animated Match Card
                              _AnimatedMatchCard(),

                              SizedBox(height: 16.h),

                              /// 🔹 My Leagues
                              _SectionHeader(
                                title: AppString.myLeagues.tr,
                                linkText: AppString.allLeagues.tr,
                                onTap: () =>
                                    context.go(RoutePath.myLeague.addBasePath),
                              ),
                              SizedBox(height: 16.h),

                              /// Animated League Card
                              _AnimatedLeagueCard(),

                              SizedBox(height: 30.h),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      /// 🔹 Bottom Navigation
      bottomNavigationBar: const NavigationWidget(currentIndex: 0),
    );
  }
}

/// Section header: title on the left, a tappable "<link> ›" on the right.
/// Shared by both home sections so the links keep identical X-alignment/style.
class _SectionHeader extends StatelessWidget {
  final String title;
  final String linkText;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.title,
    required this.linkText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                linkText,
                style: TextStyle(
                  color: const Color(0xFFFF6B35),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: const Color(0xFFFF6B35),
                size: 18.r,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Global League status + stats card (top of Home).
/// Left column = stats (night score, weekly/monthly rank); right column =
/// team status / CTA. Tapping anywhere opens the Global League team builder.
class _GlobalLeagueCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<GlobalLeagueController>();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30.h * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.go(RoutePath.globalLeagueScreen.addBasePath),
        child: Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: const Color(0xFF1a1a1a),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFF333333)),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.1),
                blurRadius: 15.r,
              ),
            ],
          ),
          child: Obx(() {
            final selection = controller.globalLeagueSelection.value;
            // Night score comes from the loaded selection; "—" until available.
            final nightScore = selection == null
                ? AppString.noResultPlaceholder
                : '${controller.totalPoints.value} pts';
            // TODO(backend): real per-user validated/locked lineup flag.
            // Using "5 players picked" as the validated proxy for now.
            final validated = controller.selectedPlayers.length >= 5;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Title
                Text(
                  AppString.nbaGlobalLeague.tr,
                  style: TextStyle(
                    color: const Color(0xFFFF6B35),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Left: stats column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _statLine('${AppString.nightScore.tr} $nightScore'),
                          SizedBox(height: 6.h),
                          // TODO(backend): real weekly rank.
                          _statLine(
                            '${AppString.weekly.tr} #${AppString.noResultPlaceholder}',
                          ),
                          SizedBox(height: 6.h),
                          // TODO(backend): real monthly rank.
                          _statLine(
                            '${AppString.monthly.tr} #${AppString.noResultPlaceholder}',
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),

                    /// Right: team status / CTA
                    _validationStatus(validated),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  static Widget _statLine(String text) {
    return Text(
      text,
      style: TextStyle(color: Colors.grey[300], fontSize: 12.sp),
    );
  }

  // Right-side team status / CTA:
  //   validated=false → 🔴 Set your 5    + "Lock in ..."
  //   validated=true  → 🟢 5 Validated   + "Tap to edit"
  static Widget _validationStatus(bool validated) {
    final color = validated
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            SizedBox(width: 6.w),
            Text(
              validated ? AppString.fiveValidated.tr : AppString.setYourFive.tr,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 2.h),
        Text(
          validated ? AppString.tapToEdit.tr : AppString.lockInPlaceholder.tr,
          style: TextStyle(color: Colors.grey, fontSize: 8.sp),
        ),
      ],
    );
  }
}

/// Animated Action Card (Join/Create League)
class _AnimatedActionCard extends StatefulWidget {
  final String title;
  final int delay;
  final VoidCallback onTap;

  const _AnimatedActionCard({
    required this.title,
    required this.delay,
    required this.onTap,
  });

  @override
  State<_AnimatedActionCard> createState() => _AnimatedActionCardState();
}

class _AnimatedActionCardState extends State<_AnimatedActionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + widget.delay),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: _isPressed ? 0.95 : value,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) {
              setState(() => _isPressed = false);
              widget.onTap();
            },
            onTapCancel: () => setState(() => _isPressed = false),
            child: Container(
              height: 140.h,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1a1a1a), Color(0xFF2a2a2a)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFF333333)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.1),
                    blurRadius: 10.r,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Icon(
                    Icons.add_circle,
                    color: const Color(0xFFE5E7EB),
                    size: 36.r,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Animated Match Card
/// Animated Match Card - Shows first match from API
class _AnimatedMatchCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final homeController = Get.find<HomeController>();

    return Obx(() {
      // Loading state
      if (homeController.matchesLoading.value) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Container(
                padding: EdgeInsets.all(16.r),
                height: 150.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF1a1a1a),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                ),
              ),
            );
          },
        );
      }

      // No matches state
      if (homeController.todayMatches.isEmpty) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a1a1a),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Assets.icons.vs.image(
                      width: 40.r,
                      height: 40.r,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      AppString.noMatchesToday.tr,
                      style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }

      // Get first match
      final match = homeController.todayMatches.first;
      final mainPair = match.pairs.isNotEmpty ? match.pairs.first : null;

      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 30.h * (1 - value)),
              child: Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a1a1a),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFF333333)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.1),
                      blurRadius: 15.r,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Assets.icons.basketBall.image(
                          width: 20.r,
                          height: 20.r,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            match.leagueName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        // Only two states now: LIVE or FINAL.
                        // TODO(backend): gate LIVE on premium live-access flag.
                        _statusBadge(_isMatchLive(match.status)),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    if (mainPair != null)
                      Builder(
                        builder: (context) {
                          final bool live = _isMatchLive(match.status);
                          // TODO(backend): drive from real completed-result
                          // availability instead of inferring from scores.
                          final bool hasResult =
                              live ||
                              mainPair.scoreA > 0 ||
                              mainPair.scoreB > 0;
                          return Row(
                            children: [
                              _teamLogo(Assets.icons.logo1),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  mainPair.playerAName ?? 'TBD',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14.sp,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _scoreText(
                                hasResult
                                    ? '${mainPair.scoreA}'
                                    : AppString.noResultPlaceholder,
                                const Color(0xFF22C55E),
                              ),
                              SizedBox(width: 12.w),
                              _AnimatedVsText(),
                              SizedBox(width: 12.w),
                              _scoreText(
                                hasResult
                                    ? '${mainPair.scoreB}'
                                    : AppString.noResultPlaceholder,
                                const Color(0xFFEF4444),
                              ),
                              Expanded(
                                child: Text(
                                  mainPair.playerBName ?? 'TBD',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14.sp,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              _teamLogo(
                                mainPair.hasPlayerB
                                    ? Assets.icons.logo2
                                    : null,
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }

  // A game counts as LIVE only for these raw statuses; everything else
  // (finished, scheduled, cancelled, …) collapses to FINAL per the spec.
  static bool _isMatchLive(String status) {
    final s = status.toLowerCase();
    return s == 'live' || s == 'in_progress';
  }

  static Widget _statusBadge(bool isLive) {
    final color = isLive ? const Color(0xFFEF4444) : const Color(0xFF22C55E);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        isLive
            ? Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Icon(
                  Icons.fiber_manual_record,
                  color: Colors.white,
                  size: 10.r,
                ),
              )
            : Icon(Icons.check_circle, color: color, size: 20.r),
        SizedBox(height: 2.h),
        Text(
          isLive ? AppString.liveLabel.tr : AppString.finalLabel.tr,
          style: TextStyle(
            color: color,
            fontSize: 8.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  static Widget _scoreText(String value, Color color) {
    return Text(
      value,
      style: TextStyle(
        color: color,
        fontSize: 18.sp,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  static Widget _teamLogo(dynamic logo) {
    return Container(
      width: 36.w,
      height: 36.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2a2a2a),
      ),
      child: Center(
        child: logo != null
            ? logo.image(width: 22.r, height: 22.r, fit: BoxFit.contain)
            : Icon(Icons.question_mark, color: Colors.grey[600], size: 18.r),
      ),
    );
  }
}

/// Animated VS Text
class _AnimatedVsText extends StatefulWidget {
  @override
  State<_AnimatedVsText> createState() => _AnimatedVsTextState();
}

class _AnimatedVsTextState extends State<_AnimatedVsText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _scale = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFFFD93D)],
            ).createShader(bounds),
            child: Text(
              AppString.vs.tr,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Animated League Card
/// Animated League Card - Shows first league from API
class _AnimatedLeagueCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final homeController = Get.find<HomeController>();

    return Obx(() {
      // Loading state
      if (homeController.leaguesLoading.value) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Container(
                padding: EdgeInsets.all(16.r),
                height: 100.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF1a1a1a),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
                ),
              ),
            );
          },
        );
      }

      // No leagues state
      if (homeController.myLeagues.isEmpty) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a1a1a),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Assets.icons.basketBall.image(
                      width: 40.r,
                      height: 40.r,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'No leagues joined yet',
                      style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }

      // Get first league
      final league = homeController.myLeagues.first;

      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 30.h * (1 - value)),
              child: GestureDetector(
                onTap: () => context.go(RoutePath.myLeague.addBasePath),
                child: Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1a1a1a),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: const Color(0xFF333333)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.1),
                        blurRadius: 15.r,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30.w,
                        height: 30.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2a2a2a),
                        ),
                        child: Center(
                          child: league.getLeagueLogoAsset().image(
                            width: 20.r,
                            height: 20.r,
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Assets.icons.basketBall.image(
                                  width: 20.r,
                                  height: 20.r,
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    league.leagueName,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16.sp,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                // Validation status (right side).
                                // TODO(backend): real per-user "5 validated"
                                // state + lock countdown; using placeholders.
                                _leagueValidationStatus(league.isActive),
                              ],
                            ),
                            SizedBox(height: 14.h),
                            Row(
                              children: [
                                Text(
                                  league.userRank > 0
                                      ? '#${_getOrdinal(league.userRank)} of ${league.totalTeams} teams'
                                      : '${league.totalTeams} teams',
                                  style: TextStyle(
                                    color: const Color(0xFFFF6B35),
                                    fontSize: 8.sp,
                                  ),
                                ),
                                _infoDivider(),
                                Text(
                                  league.season,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 8.sp,
                                  ),
                                ),
                                _infoDivider(),
                                Text(
                                  'Matchday ${league.currentMatchday}',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 8.sp,
                                  ),
                                ),
                              ],
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
        },
      );
    });
  }

  // Helper method to get ordinal (1st, 2nd, 3rd, etc.)
  static String _getOrdinal(int number) {
    if (number % 100 >= 11 && number % 100 <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  // Right-side validation status:
  //   validated=false → 🔴 Set your 5   + "Lock in ..."
  //   validated=true  → 🟢 5 Validated  + "Tap to edit"
  static Widget _leagueValidationStatus(bool validated) {
    final color = validated
        ? const Color(0xFF22C55E)
        : const Color(0xFFEF4444);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            SizedBox(width: 6.w),
            Text(
              validated
                  ? AppString.fiveValidated.tr
                  : AppString.setYourFive.tr,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 2.h),
        Text(
          validated
              ? AppString.tapToEdit.tr
              : AppString.lockInPlaceholder.tr,
          style: TextStyle(color: Colors.grey, fontSize: 8.sp),
        ),
      ],
    );
  }

  // Thin vertical separator between info-row items.
  static Widget _infoDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      child: Text(
        '|',
        style: TextStyle(color: Colors.grey, fontSize: 8.sp),
      ),
    );
  }
}

