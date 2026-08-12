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

class ExploreLeaguesScreen extends StatefulWidget {
  const ExploreLeaguesScreen({super.key});

  @override
  State<ExploreLeaguesScreen> createState() => _ExploreLeaguesScreenState();
}

class _ExploreLeaguesScreenState extends State<ExploreLeaguesScreen> {
  final TextEditingController _searchController = TextEditingController();
  int? _selectedLeagueIndex;
  late final CreateLeagueController _controller;

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      default:
        return Assets.icons.leagueLogoFlamingBall;
    }
  }

  // Filter leagues based on search
  List<PrivateLeagueModel> _getFilteredLeagues() {
    final leagues = _controller.activePublicLeagues;
    final searchQuery = _searchController.text.toLowerCase();

    if (searchQuery.isEmpty) {
      return leagues;
    }

    return leagues
        .where(
          (league) => league.leagueName.toLowerCase().contains(searchQuery),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    children: [
                      // Back Button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => context.go(
                            RoutePath.chooseALeagueScreen.addBasePath,
                          ),
                          child: SizedBox(
                            width: 30.w,
                            height: 30.h,
                            child: Assets.icons.backButton.image(
                              fit: BoxFit.contain,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 16.h),

                      // Title
                      Text(
                        AppString.exploreLeague.tr,
                        style: TextStyle(
                          fontFamily: 'Raleway',
                          fontWeight: FontWeight.w700,
                          fontSize: 20.sp,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: 8.h),

                      // Subtitle
                      Text(
                        AppString.browseAndJoinOpenLeagues.tr,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontWeight: FontWeight.w400,
                          fontSize: 16.sp,
                          color: const Color(0xFFB0B3B8),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: 20.h),

                      // Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2D3E),
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          onChanged: (value) {
                            setState(() {}); // Rebuild to filter
                          },
                          decoration: InputDecoration(
                            hintText: AppString.findLeaguesByName.tr,
                            hintStyle: TextStyle(
                              color: const Color(0xFF6B6E82),
                              fontSize: 15.sp,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: const Color(0xFF6B6E82),
                              size: 24.r,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 14.h,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // League List
                Expanded(
                  child: Obx(() {
                    if (_controller.isLoadingActiveLeagues.value) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFD85A2A),
                        ),
                      );
                    }

                    final filteredLeagues = _getFilteredLeagues();

                    if (filteredLeagues.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Assets.icons.basketballtrophee.image(
                              width: 64.w,
                              height: 64.h,
                              color: const Color(0xFF6B6E82),
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No active public leagues available'
                                  : 'No leagues found',
                              style: TextStyle(
                                color: const Color(0xFF6B6E82),
                                fontSize: 16.sp,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      itemCount: filteredLeagues.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 16.h),
                          child: _buildLeagueCard(
                            filteredLeagues[index],
                            index,
                          ),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),

          // League Details Popup
          if (_selectedLeagueIndex != null)
            Obx(() {
              final filteredLeagues = _getFilteredLeagues();
              if (_selectedLeagueIndex! >= filteredLeagues.length) {
                return const SizedBox.shrink();
              }

              final league = filteredLeagues[_selectedLeagueIndex!];
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
                                      color: const Color(0xFF6B6E82),
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
                                              child:
                                                  const CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
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

  Widget _buildLeagueCard(PrivateLeagueModel league, int index) {
    final teamsCount = league.teams.length;
    final maxTeams = int.tryParse(league.maxTeamNumber) ?? 0;

    return GestureDetector(
      onTap: () => _showLeagueDetails(index),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A2D3E), Color(0xFF1F2230)],
          ),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: const Color(0xFF3A3D50), width: 1.w),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              // League Icon
              Container(
                width: 56.w,
                height: 56.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1C2A),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: const Color(0xFF2C2C2C)),
                ),
                child: Center(
                  child: _getLogoAsset(
                    league.leagueLogo,
                  ).image(width: 32.w, height: 32.h, fit: BoxFit.contain),
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
                        color: const Color(0xFF6B6E82),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),

              // Entry Icon
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
