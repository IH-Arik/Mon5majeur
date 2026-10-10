import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/datetime_format.dart';
import '../../../../data/models/game_model.dart';

/// "Matchs du jour": ONE component for the duel leagues and the Global League
/// (QA #10 9: the Global League had its own copy - "Home vs Away", time only,
/// no icon, no status - while the duel leagues showed "Away @ Home", a clock
/// icon and a status badge). The duel version is the reference.
class TodaysGamesSection extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final List<Game> games;

  const TodaysGamesSection({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.games,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              AppString.todaysGames.tr,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        if (isLoading)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF8C42)),
            ),
          )
        else if (errorMessage != null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Text(
              errorMessage!,
              style: TextStyle(color: Colors.red, fontSize: 12.sp),
            ),
          )
        else if (games.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Text(
              AppString.noGamesToday.tr,
              style: TextStyle(color: Colors.white70, fontSize: 12.sp),
            ),
          )
        else
          SizedBox(
            height: 120.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemCount: games.length,
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(
                  right: index < games.length - 1 ? 12.w : 0,
                ),
                child: GameCard(game: games[index]),
              ),
            ),
          ),
      ],
    );
  }
}

class GameCard extends StatelessWidget {
  final Game game;
  const GameCard({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160.w,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C2A),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF2A2D3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${game.awayTeam} @ ${game.homeTeam}',
            style: TextStyle(
              color: const Color(0xFFFF8C42),
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.white70, size: 14.r),
              SizedBox(width: 4.w),
              Text(
                formatGameLocalTime(game.datetimeUtc) ?? game.gameTime,
                style: TextStyle(color: Colors.white70, fontSize: 11.sp),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: game.status == 'Not Started'
                  ? const Color(0xFF2C2C2C)
                  : const Color(0xFF00A86B),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Text(
              game.status,
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
