import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:mon5majeur_app/core/custom_assets/assets.gen.dart';
import 'package:mon5majeur_app/core/constants/app_strings.dart';

class MatchResultsDialog extends StatelessWidget {
  const MatchResultsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth * 0.9;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        width: dialogWidth.w,
        constraints: BoxConstraints(maxWidth: 350.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(9.r),
          border: Border.all(color: const Color(0xFF2C2C2C), width: 4.r),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 12.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRoundTitle(AppString.quarterFinalMatchday1.tr),
                SizedBox(height: 16.h),
                _buildMatchRow(
                  isYou: true,
                  team1Logo: Assets.icons.logo1,
                  team1Name: AppString.parisFC.tr,
                  team1Score: AppString.score102.tr,
                  team2Logo: Assets.icons.logo2,
                  team2Name: AppString.parisFC.tr,
                  team2Score: AppString.score99.tr,
                  isTeam1Winner: true,
                ),
                SizedBox(height: 12.h),
                _buildMatchRow(
                  isYou: true,
                  team1Logo: Assets.icons.logo1,
                  team1Name: AppString.parisFC.tr,
                  team1Score: AppString.score102.tr,
                  team2Logo: Assets.icons.logo2,
                  team2Name: AppString.parisFC.tr,
                  team2Score: AppString.score77.tr,
                  isTeam1Winner: true,
                ),
                SizedBox(height: 16.h),
                _buildCloseButton(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoundTitle(String title) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment(-1.0, 0.0),
          end: Alignment(1.0, 0.0),
          colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
        ),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12.sp,
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildMatchRow({
    required bool isYou,
    required AssetGenImage team1Logo,
    required String team1Name,
    required String team1Score,
    required AssetGenImage team2Logo,
    required String team2Name,
    required String team2Score,
    required bool isTeam1Winner,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;

        return Container(
          width: cardWidth.w,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment(-1.0, 0.0),
              end: Alignment(1.0, 0.0),
              colors: [Color(0xFF20222B), Color(0xFF14151C)],
            ),
            border: Border.all(color: const Color(0xFF2C2C2C), width: 1.r),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isYou)
                Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Text(
                    AppString.you.tr,
                    style: TextStyle(
                      color: Color(0xFFB0B0B0),
                      fontSize: 10.sp,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 26.r,
                          height: 26.r,
                          decoration: BoxDecoration(
                            color: const Color(0xFF242424),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF2C2C2C),
                              width: 2.r,
                            ),
                          ),
                          child: Center(
                            child: team1Logo.image(width: 12.r, height: 12.r),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Text(
                            team1Name,
                            style: TextStyle(
                              color: Color(0xFFAAAAAA),
                              fontSize: 10.sp,
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          team1Score,
                          style: TextStyle(
                            color: isTeam1Winner
                                ? const Color(0xFF3CDF1C)
                                : const Color(0xFFD32F2F),
                            fontSize: 14.sp,
                            fontFamily: 'Russo One',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Text(
                      AppString.vs.tr,
                      style: TextStyle(
                        color: Color(0xFFB0B0B0),
                        fontSize: 11.sp,
                        fontFamily: 'Russo One',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          team2Score,
                          style: TextStyle(
                            color: !isTeam1Winner
                                ? const Color(0xFF3CDF1C)
                                : const Color(0xFFD32F2F),
                            fontSize: 14.sp,
                            fontFamily: 'Russo One',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Text(
                            team2Name,
                            style: TextStyle(
                              color: Color(0xFFAAAAAA),
                              fontSize: 10.sp,
                              fontFamily: 'Roboto',
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          width: 26.r,
                          height: 26.r,
                          decoration: BoxDecoration(
                            color: const Color(0xFF242424),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF2C2C2C),
                              width: 2.r,
                            ),
                          ),
                          child: Center(
                            child: team2Logo.image(width: 12.r, height: 12.r),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxWidth: 120.w),
        height: 40.h,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8632C), Color(0xFFFF8A50)],
          ),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Center(
          child: Text(
            AppString.close.tr,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontFamily: 'Roboto',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

void showMatchResultsDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => const MatchResultsDialog(),
  );
}
