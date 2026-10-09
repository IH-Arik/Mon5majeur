import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/utils/datetime_format.dart';
import '../../../../data/models/game_model.dart';

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
              color: Color(0xFFFF8C42),
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
