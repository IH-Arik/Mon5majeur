import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../controllers/create_league_controller.dart';

class EditLeagueScreen extends StatefulWidget {
  final int? leagueId;
  final bool isPublic;

  const EditLeagueScreen({
    super.key,
    this.leagueId,
    this.isPublic = false,
  });

  @override
  State<EditLeagueScreen> createState() => _EditLeagueScreenState();
}

class _EditLeagueScreenState extends State<EditLeagueScreen> {
  late final CreateLeagueController _controller;
  bool _isInitialized = false;

  AssetGenImage? _selectedLogo;
  String _selectedBudget = AppString.budget80M;
  int _selectedPlayers = 6;
  bool _showLogoSelector = false;

  final List<AssetGenImage> _logoOptions = [
    Assets.icons.logo1,
    Assets.icons.logo2,
    Assets.icons.logo3,
    Assets.icons.logo4,
    Assets.icons.logo5,
    Assets.icons.logo6,
  ];

  final Map<String, AssetGenImage> _logoMap = {
    'atlanta_hawks': Assets.icons.logo1,
    'boston_celtics': Assets.icons.logo2,
    'chicago_bulls': Assets.icons.logo3,
    'lakers': Assets.icons.logo4,
    'golden_state_warriors': Assets.icons.logo5,
    'paris_fc': Assets.icons.logo6,
    'lion': Assets.icons.lion,
    'logo1': Assets.icons.logo1,
    'logo2': Assets.icons.logo2,
    'logo3': Assets.icons.logo3,
    'logo4': Assets.icons.logo4,
    'logo5': Assets.icons.logo5,
    'logo6': Assets.icons.logo6,
  };

  @override
  void initState() {
    super.initState();
    _controller = Get.find<CreateLeagueController>(
      tag: widget.isPublic ? 'public' : 'private',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeForm();
    });
  }

  void _initializeForm() {
    if (_isInitialized) return;

    final league = _controller.currentLeague.value;
    if (league != null) {
      _selectedLogo = _logoMap[league.leagueLogo.toLowerCase()];
      _selectedBudget = league.teamBudget;
      _selectedPlayers = int.tryParse(league.maxTeamNumber) ?? 6;

      if (_controller.leagueNameController.text.isEmpty) {
        _controller.leagueNameController.text = league.leagueName;
      }
      if (_controller.leagueDescriptionController.text.isEmpty) {
        _controller.leagueDescriptionController.text = league.leagueDescription;
      }

      _isInitialized = true;
      setState(() {});
    }
  }

  bool get _isFormValid {
    return _selectedLogo != null &&
        _controller.leagueNameController.text.isNotEmpty;
  }

  String _getLogoName(AssetGenImage logo) {
    if (logo == Assets.icons.logo1) return 'atlanta_hawks';
    if (logo == Assets.icons.logo2) return 'boston_celtics';
    if (logo == Assets.icons.logo3) return 'chicago_bulls';
    if (logo == Assets.icons.logo4) return 'lakers';
    if (logo == Assets.icons.logo5) return 'golden_state_warriors';
    if (logo == Assets.icons.logo6) return 'paris_fc';
    if (logo == Assets.icons.lion) return 'lion';
    return 'atlanta_hawks';
  }

  String get _waitingRoomRoute {
    if (widget.isPublic) {
      return '${RoutePath.createPrivateLeagueWaitingRoomScreen.addBasePath}?leagueId=${widget.leagueId}&isPublic=true';
    }
    return '${RoutePath.createPrivateLeagueWaitingRoomScreen.addBasePath}?leagueId=${widget.leagueId}';
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(32.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3A3D50), Color(0xFF2A2D3E)],
              ),
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: const Color(0xFF323232), width: 2.w),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80.w,
                  height: 80.h,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD85A2A),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check, color: Colors.white, size: 48.r),
                ),
                SizedBox(height: 24.h),
                Text(
                  AppString.leagueDetailsUpdated.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 32.h),
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go(_waitingRoomRoute);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD85A2A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        side: BorderSide(
                          color: const Color(0xFF323232),
                          width: 2.w,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      AppString.ok.tr,
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
          ),
        );
      },
    );
  }

  Future<void> _saveChanges() async {
    if (widget.leagueId == null) {
      _controller.showSnackbar(
        context,
        "Error",
        "League ID is missing",
        isError: true,
      );
      return;
    }

    if (_selectedLogo == null ||
        _controller.leagueNameController.text.trim().isEmpty) {
      _controller.showSnackbar(
        context,
        "Validation Error",
        "Please fill in all required fields",
        isError: true,
      );
      return;
    }

    _controller.selectedLogo.value = _getLogoName(_selectedLogo!);
    _controller.selectedBudget.value = _selectedBudget;
    _controller.selectedMaxTeams.value = _selectedPlayers.toString();

    await _controller.updateLeague(context, widget.leagueId!);

    if (_controller.currentLeague.value != null && context.mounted) {
      _showSuccessDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          SafeArea(
            child: Obx(() {
              if (!_isInitialized && _controller.currentLeague.value != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _initializeForm();
                });
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// Back Button
                          GestureDetector(
                            onTap: () => context.go(_waitingRoomRoute),
                            child: SizedBox(
                              width: 30.w,
                              height: 30.h,
                              child: Assets.icons.backButton.image(
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),

                          SizedBox(height: 16.h),

                          /// Title
                          Center(
                            child: Text(
                              AppString.editLeague.tr,
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

                          // Basic Info Section
                          Container(
                            width: double.infinity,
                            decoration: ShapeDecoration(
                              color: const Color(0xFF1A1A1A),
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  width: 3.w,
                                  color: const Color(0xFF2C2C2C),
                                ),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(20.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: const Color(0xFFD85A2A),
                                        size: 20.r,
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        AppString.basicInfo.tr,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 24.h),

                                  // League Logo
                                  Text(
                                    AppString.leagueLogoAsterisk.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _showLogoSelector = true;
                                      });
                                    },
                                    child: Container(
                                      width: 100.w,
                                      height: 100.h,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A1C2A),
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                        border: Border.all(
                                          color: _selectedLogo != null
                                              ? const Color(0xFFE8632C)
                                              : const Color(0xFF323232),
                                          width: 2.w,
                                        ),
                                      ),
                                      child: _selectedLogo != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(14.r),
                                              child: _selectedLogo!.image(
                                                fit: BoxFit.contain,
                                              ),
                                            )
                                          : Icon(
                                              Icons.add_photo_alternate,
                                              color: const Color(0xFF6B6E82),
                                              size: 40.r,
                                            ),
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    AppString.chooseYourLogo.tr,
                                    style: TextStyle(
                                      color: const Color(0xFF9B9EAF),
                                      fontSize: 12.sp,
                                    ),
                                  ),

                                  SizedBox(height: 24.h),

                                  // League Name
                                  Text(
                                    AppString.leagueNameAsterisk.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  TextField(
                                    controller:
                                        _controller.leagueNameController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText:
                                          AppString.enterYourLeagueName.tr,
                                      hintStyle: TextStyle(
                                        color: const Color(0xFF6B6E82),
                                        fontSize: 14.sp,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFF1A1C2A),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                        borderSide: BorderSide(
                                          color: const Color(0xFF323232),
                                          width: 2.w,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                        borderSide: BorderSide(
                                          color: const Color(0xFF323232),
                                          width: 2.w,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                        borderSide: BorderSide(
                                          color: const Color(0xFFE8632C),
                                          width: 2.w,
                                        ),
                                      ),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),

                                  SizedBox(height: 24.h),

                                  // League Description
                                  Text(
                                    AppString.leagueDescriptionOptional.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  TextField(
                                    controller:
                                        _controller.leagueDescriptionController,
                                    style: const TextStyle(color: Colors.white),
                                    maxLines: 4,
                                    decoration: InputDecoration(
                                      hintText: AppString
                                          .tellPeopleAboutYourLeague
                                          .tr,
                                      hintStyle: TextStyle(
                                        color: const Color(0xFF6B6E82),
                                        fontSize: 14.sp,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFF1A1C2A),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                        borderSide: BorderSide(
                                          color: const Color(0xFF323232),
                                          width: 2.w,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                        borderSide: BorderSide(
                                          color: const Color(0xFF323232),
                                          width: 2.w,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                        borderSide: BorderSide(
                                          color: const Color(0xFFE8632C),
                                          width: 2.w,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 16.h),

                          // Game Setup Section
                          Container(
                            width: double.infinity,
                            decoration: ShapeDecoration(
                              color: const Color(0xFF1A1A1A),
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  width: 3.w,
                                  color: const Color(0xFF2C2C2C),
                                ),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(20.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.sports_esports,
                                        color: const Color(0xFFD85A2A),
                                        size: 20.r,
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        AppString.gameSetup.tr,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 24.h),

                                  // Team Budget
                                  Text(
                                    AppString.teamBudgetAsterisk.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  Row(
                                    children: [
                                      _buildBudgetOption(AppString.budget80M),
                                      SizedBox(width: 12.w),
                                      Text(
                                        AppString.or.tr,
                                        style: TextStyle(
                                          color: const Color(0xFF6B6E82),
                                          fontSize: 14.sp,
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      _buildBudgetOption(AppString.budget100M),
                                    ],
                                  ),

                                  SizedBox(height: 12.h),

                                  // Number of Players
                                  Text(
                                    AppString.numberOfPlayersAsterisk.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  Row(
                                    children: [
                                      _buildPlayerOption(4),
                                      SizedBox(width: 12.w),
                                      _buildPlayerOption(6),
                                      SizedBox(width: 12.w),
                                      _buildPlayerOption(8),
                                      SizedBox(width: 12.w),
                                      _buildPlayerOption(10),
                                    ],
                                  ),

                                  SizedBox(height: 12.h),

                                  // League Format
                                  Text(
                                    AppString.leagueFormat.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 18.w,
                                      vertical: 8.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD85A2A),
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(
                                        color: const Color(0xFF323232),
                                        width: 2.w,
                                      ),
                                    ),
                                    child: Text(
                                      AppString.headToHead.tr,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 16.h),

                          // Rules Reminder Section
                          Container(
                            width: double.infinity,
                            decoration: ShapeDecoration(
                              color: const Color(0xFF1A1A1A),
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  width: 3.w,
                                  color: const Color(0xFF2C2C2C),
                                ),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(20.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.rule,
                                        color: const Color(0xFFD85A2A),
                                        size: 20.r,
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        AppString.rulesReminder.tr,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16.h),
                                  Text(
                                    '${AppString.leagueStartsWaitingRoom.tr}\n'
                                    '${AppString.leagueDeleted7Days.tr}\n'
                                    '${AppString.min4TeamsRequired.tr}\n'
                                    '${AppString.creatorFullControl.tr}',
                                    style: TextStyle(
                                      color: const Color(0xFF9B9EAF),
                                      fontSize: 14.sp,
                                      height: 1.6,
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

                  // Save Changes Button
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56.h,
                      child: Obx(
                        () => ElevatedButton(
                          onPressed:
                              (_isFormValid &&
                                  !_controller.isUpdatingLeague.value)
                              ? _saveChanges
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFormValid
                                ? const Color(0xFFD85A2A)
                                : const Color(0xFF3A3D4A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                              side: BorderSide(
                                color: const Color(0xFF323232),
                                width: 2.w,
                              ),
                            ),
                            elevation: 0,
                          ),
                          child: _controller.isUpdatingLeague.value
                              ? SizedBox(
                                  width: 24.w,
                                  height: 24.h,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.w,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  AppString.saveChanges.tr,
                                  style: TextStyle(
                                    color: _isFormValid
                                        ? Colors.white
                                        : const Color(0xFF6B6E82),
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),

          // Logo Selector Dialog
          if (_showLogoSelector)
            GestureDetector(
              onTap: () {
                setState(() {
                  _showLogoSelector = false;
                });
              },
              child: Container(
                color: Colors.black,
                child: Center(
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 40.w),
                      padding: EdgeInsets.all(24.w),
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
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showLogoSelector = false;
                                  });
                                },
                                child: Container(
                                  padding: EdgeInsets.all(4.w),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF3A3D4A),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20.r,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16.h),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 16.w,
                                  mainAxisSpacing: 16.h,
                                ),
                            itemCount: _logoOptions.length,
                            itemBuilder: (context, index) {
                              final logo = _logoOptions[index];
                              final isSelected = logo == _selectedLogo;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedLogo = logo;
                                    _showLogoSelector = false;
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1C2A),
                                    borderRadius: BorderRadius.circular(16.r),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFFE8632C)
                                          : const Color(0xFF323232),
                                      width: 2.w,
                                    ),
                                  ),
                                  child: Center(
                                    child: logo.image(
                                      width: 50.w,
                                      height: 50.h,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBudgetOption(String budget) {
    final isSelected = _selectedBudget == budget;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBudget = budget;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD85A2A) : const Color(0xFF1A1C2A),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFF323232), width: 2.w),
        ),
        child: Text(
          budget.tr,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF6B6E82),
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerOption(int players) {
    final isSelected = _selectedPlayers == players;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPlayers = players;
          });
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFD85A2A)
                : const Color(0xFF1A1C2A),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFF323232), width: 2.w),
          ),
          child: Center(
            child: Text(
              players.toString(),
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF6B6E82),
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
