import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:mon5majeur_app/core/constants/app_strings.dart';

import '../../../../data/models/playoff_bracket_model.dart';
import '../controllers/leaderboard_controller.dart';
import 'match_results_dialog.dart';

class PlayOffView extends StatelessWidget {
  final LeaderboardController controller;

  const PlayOffView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingPlayoffs.value) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 40.h),
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
          ),
        );
      }

      final bracket = controller.playoffBracket.value;
      if (bracket == null || bracket.rounds.isEmpty) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 40.h),
          child: Center(
            child: Text(
              AppString.noPlayoffBracketYet.tr,
              style: TextStyle(color: Colors.grey, fontSize: 14.sp),
            ),
          ),
        );
      }

      return Column(
        children: [
          for (final round in bracket.rounds) ...[
            _buildRoundTitle(round.roundName),
            SizedBox(height: 24.h),
            for (final series in round.series) ...[
              _buildSeriesRow(series),
              SizedBox(height: 24.h),
            ],
          ],
          SizedBox(height: 8.h),
          Builder(builder: (context) => _buildSeeMatchResultsButton(context)),
        ],
      );
    });
  }

  Widget _buildSeriesRow(PlayoffSeries series) {
    return Row(
      children: [
        Expanded(
          child: _buildMatchCard(
            series.teamAName,
            series.winsA,
            series.winnerId == null
                ? false
                : series.winnerId == series.teamAId,
          ),
        ),
        SizedBox(width: 12.w),
        Text(
          AppString.vs.tr,
          style: TextStyle(color: Colors.grey, fontSize: 12.sp),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildMatchCard(
            series.teamBName,
            series.winsB,
            series.winnerId == null
                ? false
                : series.winnerId == series.teamBId,
          ),
        ),
      ],
    );
  }

  Widget _buildRoundTitle(String title) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
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
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildMatchCard(String teamName, int wins, bool isWinner) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: ShapeDecoration(
        color: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: 1.r,
            color: isWinner
                ? const Color(0xFF3CDF1C)
                : const Color(0xFF2C2C2C),
          ),
          borderRadius: BorderRadius.circular(7.r),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              teamName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontFamily: AppString.roboto,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$wins',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontFamily: AppString.russoOne,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeeMatchResultsButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showMatchResultsDialog(context);
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8632C), Color(0xFFFF8A50)],
          ),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Text(
          AppString.seeMatchResults.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
