import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/datetime_format.dart';
import '../../../../data/models/game_model.dart';

/// Height of the "Matchs du jour" list, and so of every card in it: set here
/// once for the Global League tab and the duel-league tab. High enough for a
/// three-line name, the time and the status. Width-based (.w) like the text
/// inside, so it holds on any screen shape.
double get gameCardListHeight => 138.w;

class GameCard extends StatelessWidget {
  final Game game;

  const GameCard({super.key, required this.game});

  /// The server's status in the app language. Case and spaces are ignored; a
  /// status we do not know is shown as received.
  String get _statusLabel {
    switch (game.status.trim().toLowerCase()) {
      case 'not started':
        return AppString.matchStatusNotStarted.tr;
      case 'live':
        return AppString.matchStatusLive.tr;
      case 'final':
        return AppString.matchStatusFinal.tr;
      default:
        return game.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    // The card fills the list's height (the same for every card): the name
    // takes what is left at the top and shrinks rather than overflow, the
    // time and the status sit at the bottom, level from one card to the next.
    return Container(
      width: 160.w,
      height: gameCardListHeight,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C2A),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF2A2D3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: box.maxWidth,
                  child: Text(
                    '${game.awayTeam} @ ${game.homeTeam}',
                    style: TextStyle(
                      color: Color(0xFFFF8C42),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, color: Colors.white70, size: 14.r),
                SizedBox(width: 4.w),
                Text(
                  formatGameLocalTime(game.datetimeUtc) ?? game.gameTime,
                  style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                ),
              ],
            ),
          ),
          SizedBox(height: 4.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: game.status == 'Not Started'
                    ? const Color(0xFF2C2C2C)
                    : const Color(0xFF00A86B),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                _statusLabel,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
