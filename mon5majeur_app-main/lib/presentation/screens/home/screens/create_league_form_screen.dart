import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../../../../data/models/private_league_model.dart';
import '../controllers/create_league_controller.dart';

class CreateLeagueFormScreen extends StatefulWidget {
  final bool isPublic;

  const CreateLeagueFormScreen({super.key, this.isPublic = false});

  @override
  State<CreateLeagueFormScreen> createState() => _CreateLeagueFormScreenState();
}

class _CreateLeagueFormScreenState extends State<CreateLeagueFormScreen> {
  late final CreateLeagueController controller;

  bool _showLogoSelector = false;

  final List<AssetGenImage> _logoOptions = [
    Assets.icons.logo1,
    Assets.icons.logo2,
    Assets.icons.logo3,
    Assets.icons.logo4,
    Assets.icons.logo5,
    Assets.icons.logo6,
  ];

  @override
  void initState() {
    super.initState();
    controller = Get.find<CreateLeagueController>(
      tag: widget.isPublic ? 'public' : 'private',
    );
  }

  String _getLogoValue(int index) {
    return LeagueLogoChoices.getLeagueLogoByIndex(index);
  }

  AssetGenImage? _getSelectedLogoAsset() {
    if (controller.selectedLogo.value.isEmpty) return null;

    final logoMap = {
      LeagueLogoChoices.atlantaHawks: Assets.icons.logo1,
      LeagueLogoChoices.bostonCeltics: Assets.icons.logo2,
      LeagueLogoChoices.chicagoBulls: Assets.icons.logo3,
      LeagueLogoChoices.lakers: Assets.icons.logo4,
      LeagueLogoChoices.goldenStateWarriors: Assets.icons.logo5,
      LeagueLogoChoices.parisFc: Assets.icons.logo6,
    };

    return logoMap[controller.selectedLogo.value];
  }

  void _createLeague() async {
    await controller.createLeague(context);

    // For private leagues, show success dialog with join code
    if (!widget.isPublic && controller.currentLeague.value != null) {
      _showSuccessDialog();
    }
    // For public leagues, navigation is handled inside the controller
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppString.codeCopied.tr),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareCode(String code) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${AppString.shareFunctionality.tr}: $code'),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSuccessDialog() {
    final league = controller.currentLeague.value;
    if (league == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 32.w),
            padding: EdgeInsets.all(16.w),
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
                SizedBox(
                  width: 35.w,
                  height: 35.h,
                  child: Center(
                    child:
                        _getSelectedLogoAsset()?.image(
                          width: 35.w,
                          height: 35.h,
                          fit: BoxFit.contain,
                        ) ??
                        Assets.icons.logo1.image(
                          width: 35.w,
                          height: 35.h,
                          fit: BoxFit.contain,
                        ),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  AppString.leagueCreated.tr,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1C2A),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: const Color(0xFF323232),
                      width: 2.w,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        AppString.shareThisCode.tr,
                        style: TextStyle(
                          color: const Color(0xFF9B9EAF),
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 12.h,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE8632C), Color(0xFFD85A2A)],
                          ),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              league.joinCode ?? '',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24.sp,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 4.w,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _copyCode(league.joinCode ?? ''),
                              icon: Icon(
                                Icons.copy,
                                size: 16.r,
                                color: Colors.white,
                              ),
                              label: Text(
                                AppString.copyCode.tr,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2A2D3E),
                                padding: EdgeInsets.symmetric(
                                  vertical: 12.h,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  side: BorderSide(
                                    color: const Color(0xFF323232),
                                    width: 2.w,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _shareCode(league.joinCode ?? ''),
                              icon: Icon(
                                Icons.share,
                                size: 16.r,
                                color: Colors.white,
                              ),
                              label: Text(
                                AppString.share.tr,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2A2D3E),
                                padding: EdgeInsets.symmetric(
                                  vertical: 12.h,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  side: BorderSide(
                                    color: const Color(0xFF323232),
                                    width: 2.w,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.go(
                        '${RoutePath.createPrivateLeagueWaitingRoomScreen.addBasePath}?leagueId=${league.id}',
                      );
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
                      AppString.goToWaitingRoom.tr,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16.w),
                    child: Form(
                      key: controller.formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// Back Button
                          GestureDetector(
                            onTap: () => context.go(
                              RoutePath.createLeagueScreen.addBasePath,
                            ),
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
                              widget.isPublic
                                  ? AppString.createPublicLeague.tr
                                  : AppString.createPrivateLeague.tr,
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
                                        Icons.info,
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

                                  // Logo Section
                                  Text(
                                    AppString.leagueLogo.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  Obx(
                                    () => GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _showLogoSelector = true;
                                        });
                                      },
                                      child: Container(
                                        width: 56.w,
                                        height: 56.h,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1A1C2A),
                                          borderRadius: BorderRadius.circular(
                                            100.r,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE8632C),
                                            width: 2.w,
                                          ),
                                        ),
                                        child: Center(
                                          child: _getSelectedLogoAsset() != null
                                              ? _getSelectedLogoAsset()!.image(
                                                  width: 40.w,
                                                  height: 40.h,
                                                  fit: BoxFit.contain,
                                                )
                                              : Icon(
                                                  Icons.add,
                                                  color: const Color(
                                                    0xFFD85A2A,
                                                  ),
                                                  size: 32.r,
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    AppString.chooseYourLogo.tr,
                                    style: TextStyle(
                                      color: const Color(0xFF6B6E82),
                                      fontSize: 12.sp,
                                    ),
                                  ),

                                  SizedBox(height: 24.h),

                                  // League Name
                                  Text(
                                    AppString.leagueName.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  TextFormField(
                                    controller: controller.leagueNameController,
                                    style: const TextStyle(color: Colors.white),
                                    validator: controller.validateLeagueName,
                                    decoration: InputDecoration(
                                      hintText:
                                          AppString.enterYourLeagueName.tr,
                                      hintStyle: TextStyle(
                                        color: const Color(0xFF6B6E82),
                                        fontSize: 14.sp,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFF000000),
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
                                          color: const Color(0xFF323232),
                                          width: 2.w,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                        borderSide: BorderSide(
                                          color: Colors.red,
                                          width: 2.w,
                                        ),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                        borderSide: BorderSide(
                                          color: Colors.red,
                                          width: 2.w,
                                        ),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                        borderSide: BorderSide(
                                          color: const Color(0xFF323232),
                                          width: 2.w,
                                        ),
                                      ),
                                      contentPadding: EdgeInsets.all(16.w),
                                    ),
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
                                        controller.leagueDescriptionController,
                                    maxLines: 4,
                                    maxLength: 150,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: AppString
                                          .tellPeopleAboutYourLeague
                                          .tr,
                                      hintStyle: TextStyle(
                                        color: const Color(0xFF6B6E82),
                                        fontSize: 14.sp,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFF000000),
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
                                          color: const Color(0xFF323232),
                                          width: 2.w,
                                        ),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                        borderSide: BorderSide(
                                          color: const Color(0xFF323232),
                                          width: 2.w,
                                        ),
                                      ),
                                      contentPadding: EdgeInsets.all(16.w),
                                      counterStyle: TextStyle(
                                        color: const Color(0xFF6B6E82),
                                        fontSize: 12.sp,
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
                                    AppString.teamBudget.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  Obx(
                                    () => Row(
                                      children: [
                                        _buildBudgetOption('80M'),
                                        SizedBox(width: 12.w),
                                        Text(
                                          AppString.or.tr,
                                          style: TextStyle(
                                            color: const Color(0xFF6B6E82),
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                        SizedBox(width: 12.w),
                                        _buildBudgetOption('100M'),
                                      ],
                                    ),
                                  ),

                                  SizedBox(height: 12.h),

                                  // Number of Players
                                  Text(
                                    AppString.numberOfPlayers.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  Obx(
                                    () => Row(
                                      children: [
                                        _buildPlayerOption('4'),
                                        SizedBox(width: 12.w),
                                        _buildPlayerOption('6'),
                                        SizedBox(width: 12.w),
                                        _buildPlayerOption('8'),
                                        SizedBox(width: 12.w),
                                        _buildPlayerOption('10'),
                                      ],
                                    ),
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
                                        Icons.info_outline,
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
                                    AppString.leagueStartsWaitingRoom.tr,
                                    style: TextStyle(
                                      color: const Color(0xFF9B9EAF),
                                      fontSize: 13.sp,
                                      height: 1.5,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    AppString.leagueDeleted7Days.tr,
                                    style: TextStyle(
                                      color: const Color(0xFF9B9EAF),
                                      fontSize: 13.sp,
                                      height: 1.5,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    AppString.min4TeamsRequired.tr,
                                    style: TextStyle(
                                      color: const Color(0xFF9B9EAF),
                                      fontSize: 13.sp,
                                      height: 1.5,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    AppString.creatorFullControl.tr,
                                    style: TextStyle(
                                      color: const Color(0xFF9B9EAF),
                                      fontSize: 13.sp,
                                      height: 1.5,
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

                // Create League Button
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Obx(() {
                    final isValid = controller.isFormValid.value;
                    final isLoading = controller.isCreatingLeague.value;

                    return SizedBox(
                      width: double.infinity,
                      height: 56.h,
                      child: ElevatedButton(
                        onPressed: (isValid && !isLoading)
                            ? _createLeague
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isValid
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
                        child: isLoading
                            ? SizedBox(
                                width: 24.w,
                                height: 24.h,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.w,
                                ),
                              )
                            : Text(
                                AppString.createLeague.tr,
                                style: TextStyle(
                                  color: isValid
                                      ? Colors.white
                                      : const Color(0xFF6B6E82),
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3.w,
                                ),
                              ),
                      ),
                    );
                  }),
                ),
              ],
            ),
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
                color: Colors.black87,
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppString.selectLogo.tr,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showLogoSelector = false;
                                  });
                                },
                                child: Container(
                                  width: 32.w,
                                  height: 32.h,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1A1C2A),
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
                              final logoValue = _getLogoValue(index);

                              return Obx(() {
                                final isSelected =
                                    controller.selectedLogo.value == logoValue;

                                return GestureDetector(
                                  onTap: () {
                                    controller.selectedLogo.value = logoValue;
                                    setState(() {
                                      _showLogoSelector = false;
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1C2A),
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFFE8632C)
                                            : const Color(0xFF323232),
                                        width: isSelected ? 3.w : 2.w,
                                      ),
                                    ),
                                    child: Center(
                                      child: logo.image(
                                        width: 40.w,
                                        height: 40.h,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                );
                              });
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
    final isSelected = controller.selectedBudget.value == budget;
    return GestureDetector(
      onTap: () {
        controller.selectedBudget.value = budget;
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD85A2A) : const Color(0xFF1A1C2A),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFF323232), width: 2.w),
        ),
        child: Text(
          budget,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF6B6E82),
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerOption(String players) {
    final isSelected = controller.selectedMaxTeams.value == players;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          controller.selectedMaxTeams.value = players;
        },
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFD85A2A)
                : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: const Color(0xFF323232), width: 2.w),
          ),
          child: Center(
            child: Text(
              players,
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
