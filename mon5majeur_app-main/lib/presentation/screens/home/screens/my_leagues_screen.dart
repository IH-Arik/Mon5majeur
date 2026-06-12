import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../controllers/my_leagues_controller.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../../../../data/models/my_league_model.dart';
import '../../../widgets/custom_heading.dart';

// My Leagues Screen
class MyLeaguesScreen extends StatefulWidget {
  const MyLeaguesScreen({super.key});

  @override
  State<MyLeaguesScreen> createState() => _MyLeaguesScreenState();
}

class _MyLeaguesScreenState extends State<MyLeaguesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final MyLeaguesController controller;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    controller = Get.find<MyLeaguesController>();

    // Add listener to rebuild when tab changes (for icon colors)
    // _tabController.addListener(() {
    //   if (mounted) setState(() {});
    // });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToLeague(MyLeagueModel league) {
    if (league.league.isStarted == true) {
      // League has started - navigate to fantasy league screen WITH isPrivate flag
      context.go(
        '${RoutePath.fantasyLeagueScreenForJoin.addBasePath}/${league.leagueId}?matchDay=${league.currentMatchday}&isPrivate=${league.isPrivate}',
      );
    } else {
      // League not started - navigate to unified waiting room with league type flag
      context.go(
        '${RoutePath.createPrivateLeagueWaitingRoomScreen.addBasePath}?leagueId=${league.leagueId}&isPublic=${!league.isPrivate}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Column(
          children: [
            // Header using CustomHeading
            CustomHeading(
              title: AppString.myLeaguesTitle.tr,
              iconAsset: Assets.icons.win,
              routePath: RoutePath.home.addBasePath,
            ),

            SizedBox(height: 16.h),

            // Search Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: TextField(
                  style: TextStyle(color: Colors.white, fontSize: 14.sp),
                  onChanged: controller.searchLeagues,
                  decoration: InputDecoration(
                    hintText: AppString.searchHint.tr,
                    hintStyle: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14.sp,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.grey[600],
                      size: 24.r,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 16.h),

            // TabBar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFFFF6B35),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[600],
                  labelStyle: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w400,
                  ),
                  tabs: [
                    Tab(
                      child: AnimatedBuilder(
                        animation: _tabController,
                        builder: (context, child) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Assets.icons.lock.image(
                                width: 18.w,
                                height: 18.h,
                                color: _tabController.index == 0
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                AppString.privateLeague.tr,
                                style: TextStyle(fontSize: 15.sp),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Tab(
                      child: AnimatedBuilder(
                        animation: _tabController,
                        builder: (context, child) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Assets.icons.basketballtrophee.image(
                                width: 18.w,
                                height: 18.h,
                                color: _tabController.index == 1
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                AppString.publicLeague.tr,
                                style: TextStyle(fontSize: 15.sp),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16.h),

            // TabBarView
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Private Leagues Tab
                  _buildLeaguesTab(isPrivate: true),

                  // Public Leagues Tab
                  _buildLeaguesTab(isPrivate: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaguesTab({required bool isPrivate}) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
        );
      }

      // Filter leagues based on type and search query
      final filteredLeagues = controller.filteredLeagues
          .where((league) => league.isPrivate == isPrivate)
          .toList();

      if (filteredLeagues.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              (isPrivate ? Assets.icons.lock : Assets.icons.basketballtrophee)
                  .image(width: 80.w, height: 80.h, color: Colors.grey[700]),
              SizedBox(height: 16.h),
              Text(
                controller.searchQuery.value.isEmpty
                    ? (isPrivate ? 'No Private Leagues' : 'No Public Leagues')
                    : 'No leagues match your search',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              if (controller.searchQuery.value.isEmpty)
                Text(
                  isPrivate
                      ? 'Join a private league with a code'
                      : 'Explore and join public leagues',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
                ),
              if (controller.searchQuery.value.isEmpty) ...[
                SizedBox(height: 24.h),
                ElevatedButton.icon(
                  onPressed: () {
                    if (isPrivate) {
                      context.go(RoutePath.privateLeagueScreen.addBasePath);
                    } else {
                      context.go(RoutePath.publicLeagueScreen.addBasePath);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 14.h,
                    ),
                  ),
                  icon: Icon(
                    isPrivate ? Icons.lock : Icons.search,
                    color: Colors.white,
                    size: 20.r,
                  ),
                  label: Text(
                    isPrivate
                        ? AppString.joinWithCode.tr
                        : AppString.exploreAllLeagues.tr,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: controller.refreshLeagues,
        color: const Color(0xFFFF6B35),
        backgroundColor: const Color(0xFF2A2A2A),
        child: ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          itemCount: filteredLeagues.length,
          itemBuilder: (context, index) {
            final league = filteredLeagues[index];
            return LeagueCard(
              key: ValueKey(league.leagueId), // ADD THIS LINE
              league: league,
              onTap: () => _navigateToLeague(league),
            );
          },
        ),
      );
    });
  }
}

// League Card Widget
class LeagueCard extends StatelessWidget {
  final MyLeagueModel league;
  final VoidCallback? onTap;

  const LeagueCard({super.key, required this.league, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3A),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // League Icon
            Container(
              width: 44.w,
              height: 44.h,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2A),
                borderRadius: BorderRadius.circular(33.r),
              ),
              child: Center(
                child: SizedBox(
                  width: 24.w,
                  height: 24.h,
                  child: league.getLeagueLogoAsset().image(fit: BoxFit.contain),
                ),
              ),
            ),
            SizedBox(width: 16.w),

            // League Info + Matchday Row
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Top Row: League name + Matchday badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          league.leagueName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: league.isWaiting
                              ? Colors.grey[800]
                              : const Color(0xFFFF6B35),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          league.isWaiting
                              ? AppString.waiting.tr
                              : '${AppString.matchday.tr} ${league.currentMatchday}',
                          style: TextStyle(
                            color: league.isWaiting
                                ? Colors.grey
                                : Colors.white,
                            fontSize: 8.sp,
                            fontWeight: league.isWaiting
                                ? FontWeight.normal
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 8.h),

                  /// Rank, Season, Week info
                  Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: const Color(0xFFFF6B35),
                        size: 16.r,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        '${AppString.rank.tr} ${league.userRank}/${league.maxTeams}',
                        style: TextStyle(
                          color: const Color(0xFFFF6B35),
                          fontSize: 10.sp,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        AppString.separator.tr,
                        style: TextStyle(color: Colors.grey, fontSize: 10.sp),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.sports_basketball,
                        color: const Color(0xFFFF6B35),
                        size: 10.r,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        league.season,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 10.sp,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        AppString.separator.tr,
                        style: TextStyle(color: Colors.grey, fontSize: 10.sp),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${league.totalTeams} teams',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 10.sp,
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
    );
  }
}
