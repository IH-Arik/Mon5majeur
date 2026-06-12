import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../controllers/create_league_controller.dart';

class JoinLeagueWaitingRoomScreen extends StatefulWidget {
  final int? leagueId;
  final bool isPublic;

  const JoinLeagueWaitingRoomScreen({
    super.key,
    this.leagueId,
    this.isPublic = false,
  });

  @override
  State<JoinLeagueWaitingRoomScreen> createState() =>
      _JoinLeagueWaitingRoomScreenState();
}

class _JoinLeagueWaitingRoomScreenState
    extends State<JoinLeagueWaitingRoomScreen>
    with SingleTickerProviderStateMixin {
  bool _showLeaveDialog = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late final CreateLeagueController _controller;

  String get _tag => widget.isPublic ? 'public' : 'private';

  String get _leagueTypeLabel =>
      widget.isPublic ? AppString.publicLeague.tr : AppString.privateLeague.tr;

  String get _backRoute => widget.isPublic
      ? RoutePath.publicLeagueScreen.addBasePath
      : RoutePath.myLeague.addBasePath;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<CreateLeagueController>(tag: _tag);

    // Fetch league details if leagueId is provided
    if (widget.leagueId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.getLeagueDetails(context, widget.leagueId!);
      });
    }

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.disconnectWebSocket();
    super.dispose();
  }

  // Helper to get logo asset
  AssetGenImage _getLogoAsset(String logoName) {
    switch (logoName.toLowerCase()) {
      case 'lion':
        return Assets.icons.lion;
      case 'logo1':
        return Assets.icons.logo1;
      case 'logo2':
        return Assets.icons.logo2;
      case 'logo3':
        return Assets.icons.logo3;
      case 'logo4':
        return Assets.icons.logo4;
      case 'logo5':
        return Assets.icons.logo5;
      default:
        return Assets.icons.lion;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Obx(() {
        if (_controller.isLoading.value &&
            _controller.currentLeague.value == null) {
          return Center(
            child: CircularProgressIndicator(
              color: const Color(0xFFCC5123),
              strokeWidth: 4.0.w,
            ),
          );
        }

        final league = _controller.currentLeague.value;
        if (league == null) {
          // Automatically redirect if league not found
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go(RoutePath.myLeague.addBasePath);
            }
          });

          return Center(
            child: CircularProgressIndicator(
              color: const Color(0xFFCC5123),
              strokeWidth: 4.0.w,
            ),
          );
        }

        final teams = _controller.leagueTeams;
        final teamsJoined = teams.length;
        final maxTeams = int.tryParse(league.maxTeamNumber) ?? 6;
        final logoAsset = _getLogoAsset(league.leagueLogo);

        return Stack(
          children: [
            // Main Content
            SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16.0.w),
                  child: Column(
                    children: [
                      // Back Button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => context.go(_backRoute),
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

                      SizedBox(height: 20.h),

                      // League Logo
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 100.w,
                          height: 100.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2A2D3E),
                            border: Border.all(
                              color: const Color(0xFFD85A2A),
                              width: 2.r,
                            ),
                          ),
                          child: Center(
                            child: logoAsset.image(
                              width: 56.w,
                              height: 56.w,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 16.h),

                      // League Name
                      Text(
                        league.leagueName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3.w,
                        ),
                      ),

                      SizedBox(height: 4.h),

                      Text(
                        _leagueTypeLabel,
                        style: TextStyle(
                          color: const Color(0xFF6B6E82),
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.2.w,
                        ),
                      ),

                      SizedBox(height: 32.h),

                      // League Information Card
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0x3535363B),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: const Color(0xFF2C2C2C),
                            width: 2.r,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(20.0.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppString.leagueInformation.tr,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3.w,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                league.leagueDescription.isNotEmpty
                                    ? league.leagueDescription
                                    : AppString
                                          .detailsAboutBudgetFormatTeams
                                          .tr,
                                style: TextStyle(
                                  color: const Color(0xFF6B6E82),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.2.w,
                                ),
                              ),
                              SizedBox(height: 20.h),
                              _buildInfoRow(
                                Assets.icons.win,
                                AppString.format.tr,
                                AppString.headToHead.tr,
                              ),
                              SizedBox(height: 12.h),
                              _buildInfoRow(
                                Assets.icons.teamgroup,
                                AppString.teams.tr,
                                league.maxTeamNumber,
                              ),
                              SizedBox(height: 12.h),
                              _buildInfoRow(
                                Assets.icons.moneybag,
                                AppString.budget.tr,
                                league.teamBudget,
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 20.h),

                      // Waiting Room Card
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0x3535363B),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: const Color(0xFF2C2C2C),
                            width: 2.r,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(20.0.w),
                          child: Column(
                            children: [
                              Text(
                                AppString.waitingRoom.tr,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3.w,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                AppString.waitingForMoreTeams.tr,
                                style: TextStyle(
                                  color: const Color(0xFF6B6E82),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.2.w,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 24.h),

                              // Progress Text
                              Text(
                                '$teamsJoined/$maxTeams ${AppString.teamsJoined.tr}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2.w,
                                ),
                              ),
                              SizedBox(height: 12.h),

                              // Progress Bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8.r),
                                child: LinearProgressIndicator(
                                  value: teamsJoined / maxTeams,
                                  backgroundColor: const Color(0xFF2C2C2C),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Color(0xFFD85A2A),
                                      ),
                                  minHeight: 8.h,
                                ),
                              ),

                              SizedBox(height: 16.h),

                              Text(
                                '${maxTeams - teamsJoined} ${AppString.morePlayers.tr}',
                                style: TextStyle(
                                  color: const Color(0xFF6B6E82),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.2.w,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              SizedBox(height: 24.h),

                              // Joined Team Lists Header
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    AppString.joinedTeams.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2.w,
                                    ),
                                  ),
                                  Text(
                                    '$teamsJoined',
                                    style: TextStyle(
                                      color: const Color(0xFFD85A2A),
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2.w,
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 16.h),

                              // Team List
                              ...List.generate(maxTeams, (index) {
                                if (index < teams.length) {
                                  final team = teams[index];
                                  final teamLogoAsset = _getLogoAsset(
                                    team.teamLogo,
                                  );
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 8.0.h),
                                    child: _buildTeamItem(
                                      teamLogoAsset,
                                      team.teamName,
                                      '#${index + 1}',
                                      false,
                                    ),
                                  );
                                } else {
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 8.0.h),
                                    child: _buildTeamItem(
                                      Assets.icons.lion,
                                      '${AppString.waitingForTeam.tr} ${index + 1}',
                                      '#${index + 1}',
                                      true,
                                    ),
                                  );
                                }
                              }),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 24.h),

                      // Leave League Button
                      SizedBox(
                        width: double.infinity,
                        height: 56.h,
                        child: ElevatedButton(
                          onPressed: _showLeaveConfirmation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC3545),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.logout,
                                color: Colors.white,
                                size: 20.r,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                AppString.leaveLeague.tr,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3.w,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 24.h),
                    ],
                  ),
                ),
              ),
            ),

            // Leave Dialog Overlay
            if (_showLeaveDialog)
              AnimatedOpacity(
                opacity: _showLeaveDialog ? 1.0 : 0.0,
                duration: Duration(milliseconds: 200),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.9),
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40.0.w),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2A2D3E), Color(0xFF1F2230)],
                          ),
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(
                            color: const Color(0xFF3A3D50),
                            width: 1.r,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(32.0.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                AppString.leaveLeague.tr,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3.w,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 32.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _hideLeaveDialog,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF3A3D4A,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12.r,
                                          ),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          vertical: 16.h,
                                        ),
                                      ),
                                      child: Text(
                                        AppString.cancel.tr,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _hideLeaveDialog();
                                        context.go(
                                          RoutePath.myLeague.addBasePath,
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFDC3545,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12.r,
                                          ),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          vertical: 16.h,
                                        ),
                                      ),
                                      child: Text(
                                        AppString.leave.tr,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildInfoRow(AssetGenImage iconAsset, String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0x3535363B),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF2C2C2C), width: 2.r),
      ),
      child: Row(
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              color: const Color(0x3535363B),
              borderRadius: BorderRadius.circular(30.r),
              border: Border.all(color: const Color(0xFF2C2C2C), width: 1.r),
            ),
            child: Center(
              child: iconAsset.image(
                width: 18.w,
                height: 18.w,
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.sp,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2.w,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: const Color(0xFF6B6E82),
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2.w,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamItem(
    AssetGenImage iconAsset,
    String name,
    String rank,
    bool isWaiting,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0x3535363B),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF2C2C2C), width: 2.r),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: const Color(0x3535363B),
              borderRadius: BorderRadius.circular(30.r),
              border: Border.all(color: const Color(0xFF2C2C2C), width: 1.r),
            ),
            child: Center(
              child: iconAsset.image(
                width: 24.w,
                height: 24.w,
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: isWaiting ? const Color(0xFF6B6E82) : Colors.white,
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2.w,
                fontStyle: isWaiting ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          Text(
            rank,
            style: TextStyle(
              color: isWaiting
                  ? const Color(0xFF4A4D5A)
                  : const Color(0xFF6B6E82),
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2.w,
            ),
          ),
        ],
      ),
    );
  }

  void _showLeaveConfirmation() {
    setState(() {
      _showLeaveDialog = true;
    });
  }

  void _hideLeaveDialog() {
    setState(() {
      _showLeaveDialog = false;
    });
  }
}
