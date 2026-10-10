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
  // Below the court: bonus / 6th man cards of each team. The Global League has
  // no bonuses, so it turns them off (QA #10 10).
  final bool showSummary;
  // "28 Points" pill centred under the court (Global League); null = none.
  final int? totalPill;
  // Text of the empty-court card (default: "teams not ready").
  final String? emptyMessage;

  const MatchLineupsField({
    super.key,
    required this.teamA,
    required this.teamB,
    this.scoresHidden = false,
    this.showOpponent = true,
    this.showSummary = true,
    this.totalPill,
    this.emptyMessage,
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
        if (totalPill != null) _pointsPill(totalPill!),
        if (showSummary && showOpponent) _bonusCard(),
        if (showSummary && !showOpponent) ..._summary(teamA),
      ],
    );
  }

  // Light grey rounded pill, bold dark text: "28 Points".
  Widget _pointsPill(int total) {
    return Container(
      margin: EdgeInsets.only(top: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFE6E6E6),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Text(
        '$total ${AppString.points.tr}',
        style: TextStyle(
          color: const Color(0xFF1A1A1A),
          fontSize: 16.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
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
      // One team: the same 600 high court as "Créer une équipe", so the
      // baseline and the basket are fully visible (QA #10 10).
      height: showOpponent ? 700.h : 600.h,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.r)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Stack(
          children: [
            Positioned.fill(
              child: showOpponent
                  ? Assets.images.fullplayground.image(fit: BoxFit.cover)
                  : Assets.images.playground.image(fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.3)),
            ),
            if (aPlayers.isEmpty && bPlayers.isEmpty && !aHidden && !bHidden)
              Positioned.fill(child: Center(child: _notReadyCard())),

            // ── Top team
            if (teamA != null)
              _teamLabel(teamA!.teamName, Colors.red, top: showOpponent ? 8.h : 16.h),
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

  // ── Under the court: ONE card, one column per team (QA #10 17) ────────────

  /// Left column = the left team of the game card, right column = the right
  /// team, a vertical line between. Each column: the username on one line,
  /// the bonus visual (no bonus name), and for the 6th man a small line with
  /// his name and points. Three states: the visual / "Aucun bonus" / a
  /// padlock with "9h00" while the opponent's bonus is not revealed yet.
  Widget _bonusCard() {
    final a = teamA, b = teamB;
    if (a == null || b == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: 362.w),
      margin: EdgeInsets.only(top: 8.h),
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: ShapeDecoration(
        color: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0xFF2C2C2C)),
          borderRadius: BorderRadius.circular(8.r),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _bonusColumn(a)),
            VerticalDivider(width: 1, thickness: 1, color: const Color(0xFF2C2C2C)),
            Expanded(child: _bonusColumn(b)),
          ],
        ),
      ),
    );
  }

  Widget _bonusColumn(PlayerScore t) {
    final sixth = _sixth(t);
    final AssetGenImage? visual = switch (t.bonus) {
      'sixth_man' => Assets.icons.sixman,
      'chef_curry' => Assets.icons.chefcurry,
      'luxury_tax' => Assets.icons.luxarytax,
      _ => null,
    };

    Widget bonusArea;
    if (t.bonusHidden) {
      bonusArea = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, color: Colors.white54, size: 28.r),
          SizedBox(height: 2.h),
          Text(
            AppString.revealAt9.tr,
            style: TextStyle(color: Colors.white54, fontSize: 11.sp),
          ),
        ],
      );
    } else if (visual != null) {
      bonusArea = visual.image(width: 44.w, height: 44.w, fit: BoxFit.contain);
    } else {
      bonusArea = Text(
        AppString.noBonus.tr,
        style: TextStyle(color: Colors.grey, fontSize: 12.sp),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.teamName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          bonusArea,
          if (!t.bonusHidden && t.bonus == 'sixth_man' && sixth != null) ...[
            SizedBox(height: 6.h),
            Text(
              scoresHidden ? sixth.name : '${sixth.name} · ${sixth.score}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white70, fontSize: 10.sp),
            ),
          ],
        ],
      ),
    );
  }

  // ── Global League: single team, no bonus ──────────────────────────────────

  List<Widget> _summary(PlayerScore? t) => const [];

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
            emptyMessage ?? AppString.teamsNotReady.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (emptyMessage == null) ...[
            SizedBox(height: 8.h),
            Text(
              AppString.teamsNotReadyDesc.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14.sp),
            ),
          ],
        ],
      ),
    );
  }

  Widget _teamLabel(String name, Color color, {double? top, double? bottom}) {
    // On the left of the court, like the Global League (QA #10 10 / 17).
    return Positioned(
      top: top,
      bottom: bottom,
      left: 16.w,
      right: 16.w,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: 220.w),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
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
    // One team = the "Créer une équipe" court (center 120, wings 150, guards
    // 320 on a 600 high court); two teams = a half court each.
    final single = !showOpponent;
    final double y = switch (index) {
      1 => single ? 120.h : 44.h, // center, closest to the basket
      0 || 2 => single ? 150.h : 74.h, // wings
      _ => single ? 320.h : 190.h, // guards, behind the 3-point line
    };
    double? left, right;
    switch (index) {
      case 0:
        left = single ? 40.w : 12.w;
      case 2:
        right = single ? 40.w : 12.w;
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
