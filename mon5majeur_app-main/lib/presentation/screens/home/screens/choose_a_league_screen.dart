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
import '../widgets/public_league_join_dialog.dart';

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
      case 'league_flaming_ball':
        return Assets.icons.leagueLogoFlamingBall;
      case 'league_cap':
        return Assets.icons.leagueLogoCap;
      case 'league_yeti':
        return Assets.icons.leagueLogoYeti;
      case 'league_lion':
        return Assets.icons.leagueLogoLion;
      case 'league_ball':
        return Assets.icons.leagueLogoBall;
      case 'league_shark':
        return Assets.icons.leagueLogoShark;
      case 'league_snake':
        return Assets.icons.leagueLogoSnake;
      // Legacy values from before the QA 08/08/2026 item-8 asset swap —
      // kept so leagues created before this change don't render blank.
      case 'lion':
        return Assets.icons.lion;
      case 'cap':
        return Assets.icons.cap;
      case 'runningball':
        return Assets.icons.runningball;
      default:
        return Assets.icons.leagueLogoFlamingBall;
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
                            SizedBox(
                              width: 72.w,
                              height: 72.w,
                              child: Assets.icons.leaguePrivate.image(
                                fit: BoxFit.contain,
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
                            SizedBox(
                              width: 72.w,
                              height: 72.w,
                              child: Assets.icons.leaguePublic.image(
                                fit: BoxFit.contain,
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
                                    'No active public leagues available'.tr,
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

              return PublicLeagueJoinDialog(
                league: league,
                controller: _controller,
                onClose: _hideLeagueDetails,
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
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '@n/@m Teams'.trParams({'n': '$teamsCount', 'm': '$maxTeams'}),
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
