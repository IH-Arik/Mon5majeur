import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:mon5majeur_app/core/constants/app_strings.dart';

import '../../../../core/utils/score_style.dart';
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

      // One entry point per matchup (2 semifinals + the final): each series
      // has its own "Voir la série" button, so it is always clear which
      // series a tap opens (QA 15/09/2026 item 8). The old catch-all
      // "Voir les résultats" button at the bottom is gone.
      return Column(
        children: [
          for (final round in bracket.rounds) ...[
            _buildRoundTitle(
              round.roundType == 'final'
                  ? AppString.finalRound.tr
                  : AppString.semiFinals.tr,
            ),
            SizedBox(height: 24.h),
            for (final series in round.series) ...[
              _buildSeries(context, series),
              SizedBox(height: 24.h),
            ],
          ],
        ],
      );
    });
  }

  Widget _buildSeries(BuildContext context, PlayoffSeries series) {
    final isFinal = series.round == 'final';
    final aWon = series.winnerId != null && series.winnerId == series.teamAId;
    final bWon = series.winnerId != null && series.winnerId == series.teamBId;
    final wonLabel = isFinal ? AppString.seriesChampion.tr : AppString.seriesAdvances.tr;

    void open() => showSeriesDialog(
      context,
      series: series,
      leagueId: controller.leagueId ?? 0,
      isPrivate: controller.isPrivate,
    );

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: open,
          child: Row(
            children: [
              Expanded(
                child: _buildMatchCard(
                  series.teamAName,
                  series.winsA,
                  aWon,
                  aWon ? wonLabel : null,
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
                  bWon,
                  bWon ? wonLabel : null,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: open,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE8632C), Color(0xFFFF8A50)],
                ),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppString.viewSeries.tr,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(Icons.chevron_right, color: Colors.white, size: 16.r),
                ],
              ),
            ),
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

  Widget _buildMatchCard(String teamName, int wins, bool isWinner, String? tag) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: ShapeDecoration(
        color: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: 1.r,
            color: isWinner ? const Color(0xFF3CDF1C) : const Color(0xFF2C2C2C),
          ),
          borderRadius: BorderRadius.circular(7.r),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Full team name, wrapped — never truncated.
              Expanded(
                child: Text(
                  teamName,
                  softWrap: true,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontFamily: AppString.roboto,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(width: 6.w),
              Text('$wins', style: scoreTextStyle(size: 20)),
            ],
          ),
          if (tag != null) ...[
            SizedBox(height: 4.h),
            Text(
              tag,
              style: TextStyle(
                color: const Color(0xFF3CDF1C),
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
