import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/utils/logo_assets.dart';
import '../../../../core/utils/score_style.dart';
import '../../../../data/models/match_result_model.dart';

/// Both teams' lineups on a full court, with each player's fantasy score.
/// Shared by the Results tab ("View details"), the match detail screen and the
/// Live screen.
///
/// Each half is laid out like the Global League court (QA #9 10.3): the center
/// in front, a wing on each side, the two guards behind. Every team wears the
/// jersey it saved (QA #9 11.3). The 6th man never stands on the court: he is
/// listed under it with his points, so he overlaps nobody (QA #9 10.4).
/// An opponent's lineup is hidden until tip-off and shows a message instead
/// (QA #9 10.1).
class MatchLineupsField extends StatelessWidget {
  final PlayerScore? teamA;
  final PlayerScore? teamB;
  final bool scoresHidden;
  // Global League live view: only the user's own five, no opponent.
  final bool showOpponent;
  // Global League "Results" look (and "view team"): the top half of the same
  // full court the duel results use, the team name at the top left, and no
  // summary card under the court (there is no bonus in the Global League).
  // False everywhere else, so no other screen changes.
  final bool globalResultStyle;

  const MatchLineupsField({
    super.key,
    required this.teamA,
    required this.teamB,
    this.scoresHidden = false,
    this.showOpponent = true,
    this.globalResultStyle = false,
  });

  List<PlayerSelection> _starters(PlayerScore? t) =>
      (t?.selection ?? const <PlayerSelection>[])
          .where((p) => !p.isSixthMan)
          .toList();

  PlayerSelection? _sixth(PlayerScore? t) {
    for (final p in t?.selection ?? const <PlayerSelection>[]) {
      if (p.isSixthMan) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final b = showOpponent ? teamB : null;
    return Column(
      children: [
        _court(b),
        if (!globalResultStyle) ..._summary(teamA),
        if (showOpponent) ..._summary(teamB),
      ],
    );
  }

  Widget _court(PlayerScore? b) {
    final aPlayers = _starters(teamA);
    final bPlayers = _starters(b);
    final aHidden = teamA?.selectionHidden ?? false;
    final bHidden = b?.selectionHidden ?? false;

    return Container(
      margin: EdgeInsets.only(top: 12.h),
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: 362.w),
      height: globalResultStyle ? 350.h : (showOpponent ? 700.h : 380.h),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.r)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Stack(
          children: [
            if (globalResultStyle)
              // The duel court at its full 700 height: only its top half shows.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 700.h,
                child: Assets.images.fullplayground.image(fit: BoxFit.cover),
              )
            else
              Positioned.fill(
                child: showOpponent
                    ? Assets.images.fullplayground.image(fit: BoxFit.cover)
                    : Assets.images.playground.image(fit: BoxFit.cover),
              ),
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.3)),
            ),
            if (aPlayers.isEmpty && bPlayers.isEmpty && !aHidden && !bHidden)
              Positioned.fill(
                child: Center(
                  child: globalResultStyle ? _noTeamCard() : _notReadyCard(),
                ),
              ),

            // ── Top team
            if (teamA != null)
              _teamLabel(
                teamA!.teamName,
                Colors.red,
                top: 8.h,
                leftAligned: globalResultStyle,
              ),
            if (aHidden)
              _hiddenCard(top: 130.h)
            else
              for (var i = 0; i < aPlayers.length; i++)
                _positionPlayer(i, aPlayers[i], teamA, isTopTeam: true),
            if (!aHidden && aPlayers.isEmpty && bPlayers.isNotEmpty)
              _teamNotReady(teamA?.teamName ?? 'Team A', Colors.red, top: 100.h),

            // ── Bottom team
            if (b != null) _teamLabel(b.teamName, Colors.blue, bottom: 8.h),
            if (bHidden)
              _hiddenCard(bottom: 130.h)
            else
              for (var i = 0; i < bPlayers.length; i++)
                _positionPlayer(i, bPlayers[i], b, isTopTeam: false),
            if (showOpponent &&
                !bHidden &&
                bPlayers.isEmpty &&
                aPlayers.isNotEmpty)
              _teamNotReady(b?.teamName ?? 'Team B', Colors.blue, bottom: 100.h),
          ],
        ),
      ),
    );
  }

  // ── Under the court: each team's bonus and 6th man ────────────────────────

  List<Widget> _summary(PlayerScore? t) {
    if (t == null) return const [];
    final sixth = _sixth(t);
    final bonusText = _bonusText(t);
    if (bonusText == null && sixth == null) return const [];
    return [
      Container(
        width: double.infinity,
        constraints: BoxConstraints(maxWidth: 362.w),
        margin: EdgeInsets.only(top: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: ShapeDecoration(
          color: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFF2C2C2C)),
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.teamName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (bonusText != null) ...[
              SizedBox(height: 4.h),
              Text(
                bonusText,
                style: TextStyle(
                  color: const Color(0xFFFF8C42),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (sixth != null) ...[
              SizedBox(height: 4.h),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${AppString.sixthMan.tr}: ${sixth.name}',
                      style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                    ),
                  ),
                  scoresHidden
                      ? Icon(Icons.lock_outline, color: Colors.grey, size: 13.r)
                      : Text('${sixth.score}', style: scoreTextStyle(size: 14)),
                ],
              ),
            ],
          ],
        ),
      ),
    ];
  }

  /// "Bonus : Chef Curry" / "Aucun bonus" / "Bonus révélé à 9h".
  String? _bonusText(PlayerScore t) {
    if (t.bonusHidden) return AppString.bonusHidden.tr;
    switch (t.bonus) {
      case 'chef_curry':
        return '${AppString.bonusLabel.tr} : ${AppString.chefCurry.tr}';
      case 'luxury_tax':
        return '${AppString.bonusLabel.tr} : ${AppString.luxuryTax.tr}';
      case 'sixth_man':
        return '${AppString.bonusLabel.tr} : ${AppString.sixthMan.tr}';
      default:
        // Only say "no bonus" once the lineup itself is known.
        return t.selection.isEmpty ? null : AppString.noBonus.tr;
    }
  }

  // ── Court pieces ──────────────────────────────────────────────────────────

  Widget _hiddenCard({double? top, double? bottom}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: 24.w,
      right: 24.w,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, color: Colors.orange, size: 18.r),
            SizedBox(width: 8.w),
            Flexible(
              child: Text(
                AppString.opponentLineupHidden.tr,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 12.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notReadyCard() => _messageCard(
        AppString.teamsNotReady.tr,
        AppString.teamsNotReadyDesc.tr,
      );

  // Global League: the server confirmed the night but no lineup was played.
  Widget _noTeamCard() => _messageCard(
        AppString.globalNoTeamTitle.tr,
        (teamA?.isMe ?? false)
            ? AppString.globalNoTeamMine.tr
            : AppString.globalNoTeamOther.tr,
      );

  Widget _messageCard(String title, String message) {
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
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
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
    bool leftAligned = false,
  }) {
    final label = Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
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
    );
    if (leftAligned) {
      return Positioned(top: top, bottom: bottom, left: 8.w, child: label);
    }
    return Positioned(
      top: top,
      bottom: bottom,
      left: 0,
      right: 0,
      child: Center(child: label),
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

  /// Slot [index] of a half court, in the Global League layout: 0 left wing,
  /// 1 center, 2 right wing, 3 left guard, 4 right guard. The values are
  /// offsets from the team's own baseline (top for the top team, bottom for
  /// the bottom team). No two players share both a row and a column band, so
  /// names and scores can no longer touch their neighbours (QA #9 10.3).
  Widget _positionPlayer(
    int index,
    PlayerSelection player,
    PlayerScore? team, {
    required bool isTopTeam,
  }) {
    final double y = switch (index) {
      1 => 44.h, // center, closest to the basket
      0 || 2 => 74.h, // wings
      _ => 190.h, // guards, behind the 3-point line
    };
    double? left, right;
    switch (index) {
      case 0:
        left = 12.w;
      case 2:
        right = 12.w;
      case 3:
        left = 62.w;
      case 4:
        right = 62.w;
    }

    final playerWidget = _buildPlayer(player, jerseyAsset(team?.jerseyIndex));
    final top = isTopTeam ? y : null;
    final bottom = isTopTeam ? null : y;

    if (index == 1) {
      return Positioned(
        top: top,
        bottom: bottom,
        left: 0,
        right: 0,
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
            child: FittedBox(
              fit: BoxFit.scaleDown,
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
              ),
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
