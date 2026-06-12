import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/local_db/local_db.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../controllers/home_controller.dart';
import '../controllers/create_league_controller.dart';

class CreatePrivateLeagueWaitingRoomScreen extends StatefulWidget {
  final int? leagueId;
  final bool isPublicLeague; // Add this parameter

  const CreatePrivateLeagueWaitingRoomScreen({
    super.key,
    this.leagueId,
    this.isPublicLeague = false, // Default to private
  });

  @override
  State<CreatePrivateLeagueWaitingRoomScreen> createState() =>
      _CreatePrivateLeagueWaitingRoomScreenState();
}

class _CreatePrivateLeagueWaitingRoomScreenState
    extends State<CreatePrivateLeagueWaitingRoomScreen> {
  late final CreateLeagueController _controller;
  late final HomeController _homeController;
  int? _currentUserTeamId;

  @override
  void initState() {
    super.initState();

    // Initialize the appropriate controller based on league type
    final tag = widget.isPublicLeague ? 'public' : 'private';
    try {
      _controller = Get.find<CreateLeagueController>(tag: tag);
    } catch (e) {
      _controller = Get.put(
        CreateLeagueController(isPublic: widget.isPublicLeague),
        tag: tag,
      );
    }

    _homeController = Get.find<HomeController>();
    _loadCurrentUserData();

    // Fetch league details if leagueId is provided
    if (widget.leagueId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.getLeagueDetails(context, widget.leagueId!);
      });
    }
  }

  // Load current user ID and team ID from SharedPreferences
  Future<void> _loadCurrentUserData() async {
    final userId = await SharedPrefsHelper.getString(AppConstants.userId);

    // Get the user's profile/team ID
    await _homeController.fetchUserProfile();
    final teamId = _homeController.userProfile.value?.id;

    print('🔍 DEBUG - Current User ID: $userId');
    print('🔍 DEBUG - Current Team ID: $teamId');
    print(
      '🔍 DEBUG - League Creator: ${_controller.currentLeague.value?.creator}',
    );

    setState(() {
      _currentUserTeamId = teamId;
    });

    // Force rebuild after data is loaded
    Future.delayed(Duration.zero, () {
      if (mounted) setState(() {});
    });
  }

  // Check if current user is the creator
  bool get _isCreator {
    final league = _controller.currentLeague.value;

    print('🔍 _isCreator check:');
    print('  - league: ${league != null}');
    print('  - creator (team ID): ${league?.creator}');
    print('  - currentUserTeamId: $_currentUserTeamId');

    if (league == null ||
        league.creator == null ||
        _currentUserTeamId == null) {
      return false;
    }

    // Compare creator (which is a team ID) with current user's team ID
    final isCreator = league.creator == _currentUserTeamId;
    print('  - Result: $isCreator');

    return isCreator;
  }

  @override
  void dispose() {
    _controller.disconnectWebSocket();
    super.dispose();
  }

  void _copyCode() {
    final joinCode = _controller.currentLeague.value?.joinCode ?? '';
    if (joinCode.isEmpty) return;

    Clipboard.setData(ClipboardData(text: joinCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppString.codeCopied.tr),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F2230),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Text(
            AppString.deleteLeagueConfirmation.tr,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          actionsPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 12.h,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                AppString.cancel.tr,
                style: TextStyle(
                  color: const Color(0xFF9B9EAF),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Obx(
              () => ElevatedButton(
                onPressed: _controller.isDeletingLeague.value
                    ? null
                    : () async {
                        Navigator.pop(context);
                        if (widget.leagueId != null) {
                          await _controller.deleteLeague(
                            context,
                            widget.leagueId!,
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC3545),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: _controller.isDeletingLeague.value
                    ? SizedBox(
                        width: 20.w,
                        height: 20.h,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        AppString.delete.tr,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _kickTeam(int teamId, String teamName) {
    if (widget.leagueId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: League ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F2230),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Text(
            '${AppString.kick.tr} $teamName?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          actionsPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 12.h,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                AppString.cancel.tr,
                style: TextStyle(
                  color: const Color(0xFF9B9EAF),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _controller.kickTeamFromLeague(
                  context,
                  teamId,
                  widget.leagueId!,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC3545),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                AppString.kick.tr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
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
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Obx(() {
          if (_controller.isLoading.value &&
              _controller.currentLeague.value == null) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFCC5123)),
            );
          }

          final league = _controller.currentLeague.value;
          if (league == null) {
            // Automatically redirect to My Leagues if league not found
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.go(RoutePath.myLeague.addBasePath);
              }
            });

            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFCC5123)),
            );
          }
          final teams = _controller.leagueTeams;
          final teamsJoined = teams.length;
          final maxTeams = int.tryParse(league.maxTeamNumber) ?? 6;

          return Column(
            children: [
              // Header with Back Button
              Padding(
                padding: EdgeInsets.all(16.0.w),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        // Check if we can pop before attempting to pop
                        if (Navigator.of(context).canPop()) {
                          context.pop();
                        } else {
                          // If we can't pop, navigate to home
                          context.go(RoutePath.home.addBasePath);
                        }
                      },
                      child: SizedBox(
                        width: 30.w,
                        height: 30.h,
                        child: Assets.icons.backButton.image(
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 20.0.w),
                  child: Column(
                    children: [
                      SizedBox(height: 10.h),

                      // League Logo
                      Container(
                        width: 65.w,
                        height: 66.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFCC5123),
                            width: 1.w,
                          ),
                        ),
                        child: Center(
                          child:
                              _getLogoAsset(
                                league.leagueLogo,
                              ).image(
                                width: 29.w,
                                height: 33.h,
                                fit: BoxFit.contain,
                              ),
                        ),
                      ),

                      SizedBox(height: 17.h),

                      // League Name
                      Text(
                        league.leagueName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20.sp,
                          fontFamily: 'Lato',
                          fontWeight: FontWeight.w600,
                          height: 1.10,
                        ),
                      ),

                      SizedBox(height: 4.h),

                      // League Type
                      Text(
                        AppString.privateLeague.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFAAAAAA),
                          fontSize: 16.sp,
                          fontFamily: 'Lato',
                          fontWeight: FontWeight.w600,
                          height: 1.38,
                        ),
                      ),

                      SizedBox(height: 29.h),

                      // League Information Card
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment(0.50, 0.00),
                            end: Alignment(0.50, 1.00),
                            colors: [Color(0x8C1C1F26), Color(0x8C0F1116)],
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: const Color(0xFF2C2C2C),
                            width: 1.w,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(20.0.w),
                          child: Column(
                            children: [
                              // Header with Creator Badge
                              Row(
                                children: [
                                  Text(
                                    AppString.leagueInformation.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16.sp,
                                      fontFamily: 'Roboto',
                                      fontWeight: FontWeight.w700,
                                      height: 1.38,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_isCreator)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.w,
                                        vertical: 5.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2C5F2D),
                                        borderRadius: BorderRadius.circular(
                                          26.r,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFF97C680),
                                          width: 1.w,
                                        ),
                                      ),
                                      child: Text(
                                        AppString.creator.tr,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: const Color(0xFF97C680),
                                          fontSize: 11.sp,
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w500,
                                          height: 2,
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              SizedBox(height: 8.h),

                              // Budget Info
                              _buildInfoRow(
                                Assets.icons.moneybag,
                                AppString.budget.tr,
                                league.teamBudget,
                              ),

                              SizedBox(height: 8.h),

                              // Max Teams Info
                              _buildInfoRow(
                                Assets.icons.teamgroup,
                                AppString.numberOfPlayers.tr,
                                league.maxTeamNumber,
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 30.h),

                      // Waiting Room Card
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment(0.50, 0.00),
                            end: Alignment(0.50, 1.00),
                            colors: [Color(0x8C1C1F26), Color(0x8C0F1116)],
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: const Color(0xFF2C2C2C),
                            width: 1.w,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(20.0.w),
                          child: Column(
                            children: [
                              // Header
                              Row(
                                children: [
                                  Text(
                                    AppString.waitingRoom.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16.sp,
                                      fontFamily: 'Roboto',
                                      fontWeight: FontWeight.w700,
                                      height: 1.38,
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 14.h),

                              // Teams Progress
                              Row(
                                children: [
                                  Text(
                                    AppString.teams.tr,
                                    style: TextStyle(
                                      color: const Color(0xFFAAAAAA),
                                      fontSize: 13.sp,
                                      fontFamily: 'Roboto',
                                      fontWeight: FontWeight.w500,
                                      height: 1.69,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '$teamsJoined/$maxTeams',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      color: const Color(0xFFAAAAAA),
                                      fontSize: 13.sp,
                                      fontFamily: 'Roboto',
                                      fontWeight: FontWeight.w500,
                                      height: 1.69,
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 8.h),

                              // Progress Bar
                              Container(
                                width: double.infinity,
                                height: 8.h,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2C2C2C),
                                  borderRadius: BorderRadius.circular(100.r),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: teamsJoined / maxTeams,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCC5123),
                                      borderRadius: BorderRadius.circular(
                                        100.r,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 18.h),

                      // Joined Team Lists Card
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment(0.50, 0.00),
                            end: Alignment(0.50, 1.00),
                            colors: [Color(0x8C1C1F26), Color(0x8C0F1116)],
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: const Color(0xFF2C2C2C),
                            width: 1.w,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(20.0.w),
                          child: Column(
                            children: [
                              // Header
                              Row(
                                children: [
                                  Text(
                                    AppString.joinedTeamLists.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16.sp,
                                      fontFamily: 'Roboto',
                                      fontWeight: FontWeight.w700,
                                      height: 1.38,
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 14.h),

                              // Team List
                              ...List.generate(maxTeams, (index) {
                                if (index < teams.length) {
                                  final team = teams[index];
                                  // Check if THIS specific team belongs to the current user
                                  final isMyTeam =
                                      _currentUserTeamId != null &&
                                      team.teamId == _currentUserTeamId;

                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 10.h),
                                    child: _buildTeamItem(
                                      index + 1,
                                      team.teamName,
                                      _getLogoAsset(team.teamLogo),
                                      isMyTeam ? 'creator' : 'joined',
                                      teamId: team.teamId,
                                    ),
                                  );
                                } else {
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 10.h),
                                    child: _buildTeamItem(
                                      index + 1,
                                      AppString.waitingForTeam.tr,
                                      Assets.icons.logo2,
                                      'waiting',
                                    ),
                                  );
                                }
                              }),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 32.h),

                      // Show Join Code, Edit, Delete, and Start buttons ONLY if user is creator
                      if (_isCreator) ...[
                        // Join Code Section
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppString.joinCode.tr,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 44.h,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1F2230),
                                      borderRadius: BorderRadius.circular(8.r),
                                      border: Border.all(
                                        color: const Color(0xFF2C2C2C),
                                        width: 1.w,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(width: 16.w),
                                        Expanded(
                                          child: Text(
                                            league.joinCode ?? '',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16.sp,
                                              fontFamily: 'Roboto',
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: _copyCode,
                                          child: Container(
                                            padding: EdgeInsets.all(10.r),
                                            child: Icon(
                                              Icons.copy,
                                              size: 20.r,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        SizedBox(height: 16.h),

                        // Bottom Buttons
                        Column(
                          children: [
                            // Edit League Button
                            SizedBox(
                              width: double.infinity,
                              height: 44.h,
                              child: OutlinedButton(
                                onPressed: () {
                                  if (widget.leagueId != null) {
                                    context.go(
                                      '${RoutePath.editPrivateLeagueScreen.addBasePath}?leagueId=${widget.leagueId}',
                                    );
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: const Color(0xFFCC5123),
                                    width: 1.w,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                ),
                                child: Text(
                                  AppString.editLeague.tr,
                                  style: TextStyle(
                                    color: const Color(0xFFCC5123),
                                    fontSize: 14.sp,
                                    fontFamily: 'Roboto',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: 16.h),

                            // Delete League Button
                            SizedBox(
                              width: double.infinity,
                              height: 44.h,
                              child: ElevatedButton(
                                onPressed: () =>
                                    _showDeleteConfirmationDialog(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC3545),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                ),
                                child: Text(
                                  AppString.deleteLeague.tr,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                    fontFamily: 'Roboto',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: 16.h),

                            // Start League Button
                            SizedBox(
                              width: double.infinity,
                              height: 42.h,
                              child: ElevatedButton(
                                onPressed: teamsJoined >= 2
                                    ? () async {
                                        if (widget.leagueId != null) {
                                          await _controller.startLeague(
                                            context,
                                            widget.leagueId!,
                                          );
                                        }
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: teamsJoined >= 2
                                      ? const Color(0xFFCC5123)
                                      : const Color(0xFF2C2C2C),
                                  disabledBackgroundColor: const Color(
                                    0xFF2C2C2C,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                ),
                                child: Text(
                                  teamsJoined >= 2
                                      ? AppString.startLeague.tr
                                      : AppString.waitingForMoreTeams.tr,
                                  style: TextStyle(
                                    color: teamsJoined >= 2
                                        ? Colors.white
                                        : const Color(0xFF777777),
                                    fontSize: 14.sp,
                                    fontFamily: 'Roboto',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 40.h),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildInfoRow(AssetGenImage icon, String label, String value) {
    return Container(
      width: double.infinity,
      height: 32.h,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xFF2C2C2C), width: 1.w),
      ),
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      child: Row(
        children: [
          icon.image(width: 14.w, height: 14.h),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.sp,
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w500,
              height: 2.20,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.sp,
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w500,
              height: 2.20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamItem(
    int index,
    String name,
    AssetGenImage logo,
    String status, {
    int? teamId,
  }) {
    final isWaiting = status == 'waiting';
    final isMyTeam = status == 'creator'; // This is now the current user's team

    return Container(
      height: 44.h,
      decoration: BoxDecoration(
        color: const Color(0x3535363B),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: const Color(0xFF2C2C2C), width: 1.w),
      ),
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      child: Row(
        children: [
          SizedBox(
            width: 14.w,
            child: Text(
              '$index.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFB0B0B0),
                fontSize: 16.sp,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w700,
                height: 1.38,
              ),
            ),
          ),
          SizedBox(width: 7.w),
          Container(
            width: 27.w,
            height: 26.h,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: const Color(0xFF2C2C2C), width: 1.w),
            ),
            child: Center(
              child: logo.image(width: 14.w, height: 15.h, fit: BoxFit.contain),
            ),
          ),
          SizedBox(width: 9.w),
          Expanded(
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isWaiting ? const Color(0xFF777777) : Colors.white,
                fontSize: 13.sp,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w500,
                fontStyle: isWaiting ? FontStyle.italic : FontStyle.normal,
                height: 1.69,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          if (isMyTeam)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26.r),
              ),
              child: Text(
                AppString.you.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFAAAAAA),
                  fontSize: 11.sp,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  height: 2,
                ),
              ),
            )
          else if (!isWaiting && teamId != null && _isCreator)
            GestureDetector(
              onTap: () {
                print('kick teamId: $teamId, name: $name');
                _kickTeam(teamId, name);
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10.w,
                  vertical: 5.h,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4.r),
                  border: Border.all(
                    color: const Color(0xFFD32F2F),
                    width: 1.w,
                  ),
                ),
                child: Text(
                  AppString.kick.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFFD32F2F),
                    fontSize: 11.sp,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    height: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
