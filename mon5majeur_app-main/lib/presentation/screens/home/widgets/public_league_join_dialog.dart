import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/utils/logo_assets.dart';
import '../../../../data/models/private_league_model.dart';
import '../controllers/create_league_controller.dart';

/// "Join" popup of a public league (name, teams count, Duel, budget, the
/// teams already in, Join button). One widget for both entry points (Choose a
/// league and Explore leagues) so they cannot diverge again; the members come
/// from [league].teams, i.e. from GET /public-leagues/active_leagues/.
class PublicLeagueJoinDialog extends StatelessWidget {
  final PrivateLeagueModel league;
  final CreateLeagueController controller;
  final VoidCallback onClose;

  const PublicLeagueJoinDialog({
    super.key,
    required this.league,
    required this.controller,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final teamsCount = league.teams.length;
    final maxTeams = int.tryParse(league.maxTeamNumber) ?? 0;
    // Same fallback as the league cards: an empty/unknown logo shows the
    // flaming ball, not a team avatar.
    final leagueLogoAsset =
        LeagueLogoChoices.all.contains(league.leagueLogo.trim().toLowerCase())
        ? logoAsset(league.leagueLogo)
        : Assets.icons.leagueLogoFlamingBall;

    return GestureDetector(
      onTap: onClose,
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
                              Assets.icons.leaguePublic.image(
                                width: 14.w,
                                height: 14.w,
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
                          child: leagueLogoAsset.image(
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
                                  '@n/@m Teams'.trParams({
                                    'n': '$teamsCount',
                                    'm': '$maxTeams',
                                  }),
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

                      // Teams already in the league (team name + logo only:
                      // the endpoint sends no real name or email).
                      if (league.teams.isNotEmpty) ...[
                        SizedBox(height: 20.h),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            AppString.joinedTeamsTitle.tr,
                            style: TextStyle(
                              color: const Color(0xFF6B6E82),
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        // Up to 10 teams: scrolls past ~4 rows so the
                        // Join button always stays on screen.
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: 132.h),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: league.teams.length,
                            separatorBuilder: (_, _) => SizedBox(height: 6.h),
                            itemBuilder: (_, i) {
                              final team = league.teams[i];
                              return Row(
                                children: [
                                  logoAsset(team.teamLogo).image(
                                    width: 24.w,
                                    height: 24.w,
                                    fit: BoxFit.contain,
                                  ),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                    child: Text(
                                      team.teamName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],

                      SizedBox(height: 24.h),

                      // Join Button
                      Obx(() {
                        final isJoining = controller.isLoading.value;

                        return SizedBox(
                          width: double.infinity,
                          height: 48.h,
                          child: ElevatedButton(
                            onPressed: isJoining
                                ? null
                                : () async {
                                    if (league.id != null) {
                                      await controller.joinLeague(
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
                                    child: const CircularProgressIndicator(
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
  }
}
