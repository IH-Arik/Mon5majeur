import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../../../../data/models/private_league_model.dart';

import '../controllers/create_league_controller.dart';

class ChooseALeagueScreen extends StatefulWidget {
  const ChooseALeagueScreen({super.key});

  @override
  State<ChooseALeagueScreen> createState() => _ChooseALeagueScreenState();
}

class _ChooseALeagueScreenState extends State<ChooseALeagueScreen> {
  late final CreateLeagueController _controller;
  int? _selectedLeagueIndex;

  @override
  void initState() {
    super.initState();
    // Initialize controller if not already initialized
    _controller = Get.find<CreateLeagueController>(tag: 'public');

    // Fetch active public leagues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.getActivePublicLeagues(context);
    });
  }

  void _showLeagueDetails(int index) {
    setState(() {
      _selectedLeagueIndex = index;
    });
  }

  void _hideLeagueDetails() {
    setState(() {
      _selectedLeagueIndex = null;
    });
  }

  // Helper to get logo asset
  AssetGenImage _getLogoAsset(String logoName) {
    switch (logoName.toLowerCase()) {
      case 'atlanta_hawks':
        return Assets.icons.logo1;
      case 'boston_celtics':
        return Assets.icons.logo2;
      case 'chicago_bulls':
        return Assets.icons.logo3;
      case 'lakers':
        return Assets.icons.logo4;
      case 'golden_state_warriors':
        return Assets.icons.logo5;
      case 'paris_fc':
        return Assets.icons.logo6;
      case 'lion':
        return Assets.icons.lion;
      case 'cap':
        return Assets.icons.cap;
      case 'runningball':
        return Assets.icons.runningball;
      default:
        return Assets.icons.lion;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          // Main Content
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Back Button
                    GestureDetector(
                      onTap: () => context.go(RoutePath.home.addBasePath),
                      child: SizedBox(
                        width: 30.w,
                        height: 30.h,
                        child: Assets.icons.backButton.image(
                          fit: BoxFit.contain,
                          color: Colors.white,
                          // tooltip: AppString.backButtonTooltip, // If you use tooltips
                        ),
                      ),
                    ),

                    SizedBox(height: 16.h),

                    /// Title
                    Center(
                      child: Text(
                        AppString.chooseALeague.tr,
                        style: TextStyle(
                          fontFamily: 'Raleway',
                          fontWeight: FontWeight.w700,
                          fontSize: 20.sp,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    SizedBox(height: 8.h),

                    /// Subtitle
                    Center(
                      child: Text(
                        AppString.pickALeagueAndStartPlaying.tr,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w400,
                          fontSize: 16.sp,
                          color: Color(0xFFB0B3B8),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                    SizedBox(height: 20.h),

                    // Private League Card
                    Container(
                      width: double.infinity,
                      decoration: ShapeDecoration(
                        color: const Color(0xFF1A1A1A),
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(
                            width: 1,
                            color: Color(0xFF2C2C2C),
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(24.w),
                        child: Column(
                          children: [
                            // Lock Icon
                            Container(
                              width: 64.w,
                              height: 64.h,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1C2A),
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              child: Center(
                                child: Assets.icons.lock.image(
                                  width: 40.w,
                                  height: 40.h,
                                  fit: BoxFit.contain,
                                  // tooltip: AppString.lockIconTooltip,
                                ),
                              ),
                            ),

                            SizedBox(height: 20.h),

                            // Private League Title
                            Text(
                              AppString.privateLeague.tr,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),

                            SizedBox(height: 8.h),

                            // Private League Subtitle
                            Text(
                              AppString.joinALeagueWithACode.tr,
                              style: TextStyle(
                                color: Color(0xFF6B6E82),
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.2,
                              ),
                            ),

                            SizedBox(height: 24.h),

                            // Join with code button
                            SizedBox(
                              width: double.infinity,
                              height: 56.h,
                              child: ElevatedButton(
                                onPressed: () => context.go(
                                  RoutePath.privateLeagueScreen.addBasePath,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD85A2A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  AppString.joinWithCode.tr,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 20.h),

                    // Public League Card
                    Container(
                      width: double.infinity,
                      decoration: ShapeDecoration(
                        color: const Color(0xFF1A1A1A),
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(
                            width: 1,
                            color: Color(0xFF2C2C2C) /* Stroke */,
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(24.w),
                        child: Column(
                          children: [
                            // Trophy Icon
                            Container(
                              width: 64.w,
                              height: 64.h,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1C2A),
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              child: Center(
                                child: Assets.icons.basketballtrophee.image(
                                  width: 40.w,
                                  height: 40.h,
                                  fit: BoxFit.contain,
                                  // tooltip: AppString.trophyIconTooltip,
                                ),
                              ),
                            ),

                            SizedBox(height: 20.h),

                            // Public League Title
                            Text(
                              AppString.publicLeague.tr,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),

                            SizedBox(height: 8.h),

                            // Public League Subtitle
                            Text(
                              AppString.joinFreelyNoCodeNeeded.tr,
                              style: TextStyle(
                                color: Color(0xFF6B6E82),
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.2,
                              ),
                            ),

                            SizedBox(height: 24.h),

                            // League List - Dynamic from API
                            Obx(() {
                              if (_controller.isLoadingActiveLeagues.value) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20.0),
                                    child: CircularProgressIndicator(
                                      color: Color(0xFFD85A2A),
                                    ),
                                  ),
                                );
                              }

                              final leagues = _controller.activePublicLeagues;

                              if (leagues.isEmpty) {
                                return Padding(
                                  padding: EdgeInsets.all(20.w),
                                  child: Text(
                                    'No active public leagues available',
                                    style: TextStyle(
                                      color: Color(0xFF6B6E82),
                                      fontSize: 14.sp,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                );
                              }

                              // Show up to 4 leagues
                              final displayLeagues = leagues.take(4).toList();

                              return Column(
                                children: [
                                  for (
                                    int i = 0;
                                    i < displayLeagues.length;
                                    i++
                                  ) ...[
                                    _buildLeagueItem(displayLeagues[i], i),
                                    if (i < displayLeagues.length - 1)
                                      SizedBox(height: 12.h),
                                  ],
                                ],
                              );
                            }),

                            SizedBox(height: 24.h),

                            // Explore all leagues button
                            SizedBox(
                              width: double.infinity,
                              height: 56.h,
                              child: ElevatedButton(
                                onPressed: () => context.go(
                                  RoutePath.publicLeagueScreen.addBasePath,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD85A2A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  AppString.exploreAllLeagues.tr,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),
          ),

          // League Details Popup
          if (_selectedLeagueIndex != null)
            Obx(() {
              final leagues = _controller.activePublicLeagues;
              if (_selectedLeagueIndex! >= leagues.length) {
                return const SizedBox.shrink();
              }

              final league = leagues[_selectedLeagueIndex!];
              final teamsCount = league.teams.length;
              final maxTeams = int.tryParse(league.maxTeamNumber) ?? 0;

              return GestureDetector(
                onTap: _hideLeagueDetails,
                child: Container(
                  color: Colors.black87,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {},
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32.w),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2A2D3E), Color(0xFF1F2230)],
                            ),
                            borderRadius: BorderRadius.circular(24.r),
                            border: Border.all(
                              color: const Color(0xFFE8632C),
                              width: 2.w,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black54,
                                blurRadius: 20.r,
                                offset: Offset(0, 10.h),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(28.w),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Public League Badge - Right Aligned
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12.w,
                                      vertical: 6.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3A3D4A),
                                      borderRadius: BorderRadius.circular(20.r),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Assets.icons.basketballtrophee.image(
                                          width: 10.w,
                                          height: 10.h,
                                          fit: BoxFit.contain,
                                        ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          AppString.publicLeague.tr,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                SizedBox(height: 20.h),

                                // League Icon
                                Container(
                                  width: 64.w,
                                  height: 64.h,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1C2A),
                                    borderRadius: BorderRadius.circular(32.r),
                                    border: Border.all(
                                      color: const Color(0xFFE8632C),
                                      width: 2.w,
                                    ),
                                  ),
                                  child: Center(
                                    child: _getLogoAsset(league.leagueLogo)
                                        .image(
                                          width: 40.w,
                                          height: 40.h,
                                          fit: BoxFit.contain,
                                        ),
                                  ),
                                ),

                                SizedBox(height: 20.h),

                                // League Name
                                Text(
                                  league.leagueName,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                SizedBox(height: 8.h),

                                // Description
                                if (league.leagueDescription.isNotEmpty)
                                  Text(
                                    league.leagueDescription,
                                    style: TextStyle(
                                      color: Color(0xFF6B6E82),
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0.2,
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),

                                SizedBox(height: 20.h),

                                // Info Badges
                                Wrap(
                                  spacing: 12.w,
                                  runSpacing: 12.h,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14.w,
                                        vertical: 8.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A1C2A),
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFF2C2C2C),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Assets.icons.teamgroup.image(
                                            width: 14.w,
                                            height: 14.h,
                                            fit: BoxFit.contain,
                                          ),
                                          SizedBox(width: 6.w),
                                          Text(
                                            '$teamsCount/$maxTeams Teams',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14.w,
                                        vertical: 8.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A1C2A),
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFF2C2C2C),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Assets.icons.win.image(
                                            width: 14.w,
                                            height: 14.h,
                                            fit: BoxFit.contain,
                                          ),
                                          SizedBox(width: 6.w),
                                          Text(
                                            AppString.headToHead.tr,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14.w,
                                        vertical: 8.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A1C2A),
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFF2C2C2C),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.attach_money,
                                            color: Colors.white,
                                            size: 14.r,
                                          ),
                                          Text(
                                            league.teamBudget,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 24.h),

                                // Join Button
                                Obx(() {
                                  final isJoining = _controller.isLoading.value;

                                  return SizedBox(
                                    width: double.infinity,
                                    height: 48.h,
                                    child: ElevatedButton(
                                      onPressed: isJoining
                                          ? null
                                          : () async {
                                              if (league.id != null) {
                                                await _controller.joinLeague(
                                                  context,
                                                  leagueId: league.id!,
                                                );
                                              }
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFD85A2A,
                                        ),
                                        disabledBackgroundColor: const Color(
                                          0xFF6B6E82,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16.r,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: isJoining
                                          ? SizedBox(
                                              width: 20.w,
                                              height: 20.h,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.w,
                                              ),
                                            )
                                          : Text(
                                              AppString.join.tr,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16.sp,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
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

  Widget _buildLeagueItem(PrivateLeagueModel league, int index) {
    final teamsCount = league.teams.length;
    final maxTeams = int.tryParse(league.maxTeamNumber) ?? 0;

    return GestureDetector(
      onTap: () => _showLeagueDetails(index),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1C2A),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFF2A2D3E), width: 1.w),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40.w,
                height: 40.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF252838),
                  borderRadius: BorderRadius.circular(30.r),
                ),
                child: Center(
                  child: _getLogoAsset(
                    league.leagueLogo,
                  ).image(width: 18.w, height: 18.h, fit: BoxFit.contain),
                ),
              ),

              SizedBox(width: 16.w),

              // League Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      league.leagueName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '$teamsCount/$maxTeams Teams',
                      style: TextStyle(
                        color: Color(0xFF6B6E82),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),

              // User Icon
              SizedBox(
                width: 32.w,
                height: 32.h,
                child: Center(
                  child: Assets.icons.entry.image(
                    width: 32.w,
                    height: 32.h,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
