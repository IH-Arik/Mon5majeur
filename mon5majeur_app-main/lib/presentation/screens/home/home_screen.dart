import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      /// Animated Earn Tokens Badge
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(-50.w * (1 - value), 0),
                            child: Opacity(
                              opacity: value,
                              child: _AnimatedTokenBadge(),
                            ),
                          );
                        },
                      ),

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

                              /// 🔹 NBA Global League Card
                              _AnimatedGlobalLeagueCard(),

                              SizedBox(height: 20.h),

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

                              /// 🔹 My Matches Today
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  AppString.myMatchesToday,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              SizedBox(height: 16.h),

                              /// Animated Match Card
                              _AnimatedMatchCard(),

                              SizedBox(height: 16.h),

                              /// See All Matches Button
                              _AnimatedOrangeButton(
                                text: AppString.seeAllMatches.tr,
                                onPressed: () => context.go(
                                  RoutePath.myMatchToday.addBasePath,
                                ),
                              ),

                              SizedBox(height: 16.h),

                              /// 🔹 My Leagues
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  AppString.myLeagues,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              SizedBox(height: 16.h),

                              /// Animated League Card
                              _AnimatedLeagueCard(),

                              SizedBox(height: 16.h),

                              /// See All Leagues Button
                              _AnimatedOrangeButton(
                                text: AppString.seeAllLeagues.tr,
                                onPressed: () =>
                                    context.go(RoutePath.myLeague.addBasePath),
                              ),

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

/// Animated Token Badge Widget
class _AnimatedTokenBadge extends StatefulWidget {
  @override
  State<_AnimatedTokenBadge> createState() => _AnimatedTokenBadgeState();
}

class _AnimatedTokenBadgeState extends State<_AnimatedTokenBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _bounce = Tween<double>(
      begin: 0,
      end: 5.h,
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
      animation: _bounce,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_bounce.value),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: const Color(0xFF2a2a2a),
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                  blurRadius: 10.r,
                ),
              ],
            ),
            child: Row(
              children: [
                Assets.icons.play.image(width: 16.r, height: 16.r),
                SizedBox(width: 6.w),
                Text(
                  AppString.earnFreeTokens.tr,
                  style: TextStyle(color: Colors.white, fontSize: 12.sp),
                ),
                SizedBox(width: 4.w),
                Text(
                  AppString.celebrationEmoji.tr,
                  style: TextStyle(fontSize: 12.sp),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Animated Global League Card
class _AnimatedGlobalLeagueCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1a1a1a),
                  const Color(0xFFE8632C).withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: const Color(0xFFE8632C).withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE8632C).withValues(alpha: 0.2),
                  blurRadius: 20.r,
                  spreadRadius: 2.r,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppString.nbaGlobalLeague.tr,
                        style: TextStyle(
                          color: const Color(0xFFE8632C),
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        AppString.competeAgainstEveryone.tr,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12.sp,
                        ),
                      ),
                      Text(
                        AppString.weeklyMonthlyPrizes.tr,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () =>
                      context.go(RoutePath.globalLeagueScreen.addBasePath),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8632C),
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 8.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    elevation: 5,
                  ),
                  child: Text(
                    AppString.joinNow.tr,
                    style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2a2a2a),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            match.status == 'scheduled'
                                ? AppString.upcoming.tr
                                : match.status.toUpperCase(),
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 10.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    if (mainPair != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _teamColumn(
                            Assets.icons.logo1,
                            mainPair.playerAName ?? 'TBD',
                          ),
                          _AnimatedVsText(),
                          _teamColumn(
                            mainPair.hasPlayerB ? Assets.icons.logo2 : null,
                            mainPair.playerBName ?? 'TBD',
                          ),
                        ],
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

  static Widget _teamColumn(dynamic logo, String name) {
    return Column(
      children: [
        Container(
          width: 50.w,
          height: 50.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2a2a2a),
          ),
          child: Center(
            child: logo != null
                ? logo.image(width: 28.r, height: 28.r, fit: BoxFit.contain)
                : Icon(
                    Icons.question_mark,
                    color: Colors.grey[600],
                    size: 24.r,
                  ),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          name,
          style: TextStyle(color: Colors.grey, fontSize: 14.sp),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
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
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2a2a2a),
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Text(
                                    'Matchday ${league.currentMatchday}',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10.sp,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 14.h),
                            Row(
                              children: [
                                Text(
                                  league.userRank > 0
                                      ? '${_getOrdinal(league.userRank)} of ${league.totalTeams} Teams'
                                      : '${league.totalTeams} Teams',
                                  style: TextStyle(
                                    color: Color(0xFFFF6B35),
                                    fontSize: 8.sp,
                                  ),
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  '${league.season} Week ${league.currentWeek}',
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
}

/// Animated Orange Button
class _AnimatedOrangeButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;

  const _AnimatedOrangeButton({required this.text, required this.onPressed});

  @override
  State<_AnimatedOrangeButton> createState() => _AnimatedOrangeButtonState();
}

class _AnimatedOrangeButtonState extends State<_AnimatedOrangeButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            widget.onPressed();
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 14.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
              ),
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                // BoxShadow(
                //   color: const Color(0xFFFF6B35),
                //   blurRadius: 15.r,
                //   spreadRadius: 1.r,
                // ),
              ],
            ),
            child: Text(
              widget.text,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
