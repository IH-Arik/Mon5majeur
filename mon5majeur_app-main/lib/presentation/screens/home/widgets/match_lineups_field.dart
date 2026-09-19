import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/utils/score_style.dart';
import '../../../../data/models/match_result_model.dart';

/// Both teams' lineups on a full court, with each player's fantasy score.
/// Shared by the Results tab ("View details") and the match detail screen
/// (QA 15/09/2026 items 4/7/8). While [scoresHidden] the API has already
/// zeroed every number; the badges show a dash instead of a misleading "0".
class MatchLineupsField extends StatelessWidget {
  final PlayerScore? teamA;
  final PlayerScore? teamB;
  final bool scoresHidden;

  const MatchLineupsField({
    super.key,
    required this.teamA,
    required this.teamB,
    this.scoresHidden = false,
  });

  @override
  Widget build(BuildContext context) {
    final teamAPlayers = teamA?.selection ?? [];
    final teamBPlayers = teamB?.selection ?? [];

    return Container(
      margin: EdgeInsets.only(top: 12.h),
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: 362.w),
      height: 700.h,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.r)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Stack(
          children: [
            Positioned.fill(
              child: Assets.images.fullplayground.image(fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.3)),
            ),

            if (teamAPlayers.isEmpty && teamBPlayers.isEmpty)
              Positioned.fill(child: Center(child: _notReadyCard())),

            if (teamAPlayers.isNotEmpty) ...[
              _teamLabel(
                teamA?.teamName ?? 'Team A',
                Colors.red,
                top: 16.h,
                left: 16.w,
              ),
              for (var i = 0; i < teamAPlayers.length; i++)
                _positionPlayer(
                  i,
                  teamAPlayers[i],
                  Assets.icons.jerseyDevil,
                  isTopTeam: true,
                ),
            ] else if (teamBPlayers.isNotEmpty)
              _teamNotReady(teamA?.teamName ?? 'Team A', Colors.red, top: 100.h),

            if (teamBPlayers.isNotEmpty) ...[
              _teamLabel(
                teamB?.teamName ?? 'Team B',
                Colors.blue,
                bottom: 16.h,
                right: 16.w,
              ),
              for (var i = 0; i < teamBPlayers.length; i++)
                _positionPlayer(
                  i,
                  teamBPlayers[i],
                  Assets.icons.jerseyFlower,
                  isTopTeam: false,
                ),
            ] else if (teamAPlayers.isNotEmpty)
              _teamNotReady(
                teamB?.teamName ?? 'Team B',
                Colors.blue,
                bottom: 100.h,
              ),
          ],
        ),
      ),
    );
  }

  Widget _notReadyCard() {
    return Container(
      margin: EdgeInsets.all(32.w),
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_outlined, color: Colors.orange, size: 48.r),
          SizedBox(height: 16.h),
          Text(
            AppString.teamsNotReady.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            AppString.teamsNotReadyDesc.tr,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  Widget _teamLabel(
    String name,
    Color color, {
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _teamNotReady(String name, Color color, {double? top, double? bottom}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            AppString.teamNotReadyTemplate.trParams({'name': name}),
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _positionPlayer(
    int index,
    PlayerSelection player,
    AssetGenImage jersey, {
    required bool isTopTeam,
  }) {
    double? top, bottom, left, right;
    // Two players in the back row (0/1), three on the baseline (2/3/4),
    // mirrored for the bottom team.
    final double y = index <= 1 ? 140.h : 60.h;
    if (isTopTeam) {
      top = y;
    } else {
      bottom = y;
    }
    switch (index) {
      case 0:
        left = 60.w;
      case 1:
        right = 60.w;
      case 2:
        left = 30.w;
      case 3:
        left = 0;
        right = 0;
      case 4:
        right = 30.w;
    }

    final playerWidget = _buildPlayer(player, jersey);
    if (left != null && right != null) {
      return Positioned(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        child: Center(child: playerWidget),
      );
    }
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: playerWidget,
    );
  }

  Widget _buildPlayer(PlayerSelection player, AssetGenImage jersey) {
    return SizedBox(
      width: 90.w,
      height: 107.h,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 90.w,
              height: 72.h,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: jersey.provider(),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned(
            left: 5.w,
            top: 66.h,
            right: 5.w,
            child: Text(
              player.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFFECD56),
                fontSize: 9.sp,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 85.h,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: ShapeDecoration(
                  color: const Color(0xFF1A1A1A),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      width: 1.w,
                      color: const Color(0xFF2C2C2C),
                    ),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                ),
                child: scoresHidden
                    ? Icon(Icons.lock_outline, color: Colors.grey, size: 13.r)
                    : Text(
                        '${player.score}',
                        textAlign: TextAlign.center,
                        style: scoreTextStyle(size: 16),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
