import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/datetime_format.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/utils/logo_assets.dart';
import '../../../../core/utils/score_style.dart';
import '../../../../data/models/match_result_model.dart';
import 'out_badge.dart';
import 'substitute_widgets.dart';

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
  // Duel "Results" look (QA #10 17): the team name labels sit at the left of
  // the court, and the two bonus cards are replaced by one two-column card
  // (left column = [teamA], right = [teamB], like the match card above).
  // False everywhere else, so no other screen changes.
  final bool duelResultStyle;
  // The match is over: a side with no lineup then means the player never set
  // one, not that the match is waiting for it. False everywhere else, so the
  // Live and the Global League keep the "not ready" wording.
  final bool matchFinished;
  // The first tip-off has happened: an empty side then means "never set", not
  // "not ready yet". False everywhere else, so the Live keeps "not ready".
  final bool matchStarted;
  // Best fantasy scores of the night: player id -> 1, 2 or 3 (see
  // NightTopScores): the jersey gets a gold / silver / bronze halo. Null
  // everywhere else.
  final Map<String, int>? medals;
  // Share story layout: the same full court squeezed to 470 high instead of
  // 700 (the whole image, so the background stays continuous, with its
  // half-way line and center circle) and the rows of players pulled in, so it
  // keeps the full width in a short space. False everywhere else, so no other
  // screen changes.
  final bool shareCompact;
  // Widest a team label may be (court units): a longer name is shrunk to fit
  // instead of running over the players or off the court. Null everywhere
  // else, so no other screen changes.
  final double? labelMaxWidth;

  const MatchLineupsField({
    super.key,
    required this.teamA,
    required this.teamB,
    this.scoresHidden = false,
    this.showOpponent = true,
    this.globalResultStyle = false,
    this.duelResultStyle = false,
    this.matchFinished = false,
    this.matchStarted = false,
    this.medals,
    this.shareCompact = false,
    this.labelMaxWidth,
  });

  /// The substitute of a single-team view (Global League results, "view
  /// team", Live) stands on the court itself. The duel's two-team view comes
  /// with the duel screens.
  bool get _showsSubstitute =>
      globalResultStyle &&
      !shareCompact &&
      teamA?.substitute != null &&
      !(teamA?.selectionHidden ?? false);

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
        if (duelResultStyle)
          ..._duelBonusCard()
        else ...[
          if (!globalResultStyle) ..._summary(teamA),
          if (showOpponent) ..._summary(teamB),
        ],
      ],
    );
  }

  Widget _court(PlayerScore? b) {
    final aPlayers = _starters(teamA);
    final bPlayers = _starters(b);
    final aHidden = teamA?.selectionHidden ?? false;
    final bHidden = b?.selectionHidden ?? false;
    // Nobody has a lineup and nothing is waiting for one: one message for the
    // whole court. Before tip-off each side says its own state instead.
    final noTeamAtAll = aPlayers.isEmpty &&
        bPlayers.isEmpty &&
        !aHidden &&
        !bHidden &&
        (globalResultStyle || matchFinished || matchStarted);

    return Container(
      margin: EdgeInsets.only(top: 12.h),
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: 362.w),
      height: shareCompact
          ? 470.h
          : (globalResultStyle
              ? (350 + (_showsSubstitute ? _belowLine : 0)).h
              : (showOpponent ? 700.h : 380.h)),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.r)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Stack(
          children: [
            if (shareCompact)
              Positioned.fill(
                child: Assets.images.fullplayground.image(fit: BoxFit.fill),
              )
            else if (globalResultStyle)
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
            if (noTeamAtAll)
              Positioned.fill(
                child: Center(
                  child: globalResultStyle ? _noTeamCard() : _noLineupCard(),
                ),
              ),

            // ── Top team
            if (teamA != null)
              _teamLabel(
                teamA!.teamName,
                Colors.red,
                top: 8.h,
                leftAligned: globalResultStyle || duelResultStyle,
              ),
            if (aHidden)
              _hiddenCard(top: 130.h)
            else
              for (var i = 0; i < aPlayers.length; i++)
                _positionPlayer(i, aPlayers[i], teamA, isTopTeam: true),
            if (_showsSubstitute) _substituteOnCourt(),
            if (!globalResultStyle &&
                !noTeamAtAll &&
                !aHidden &&
                aPlayers.isEmpty)
              _teamNotReady(teamA?.teamName ?? 'Team A', Colors.red, top: 100.h),

            // ── Bottom team
            if (b != null)
              _teamLabel(
                b.teamName,
                Colors.blue,
                bottom: 8.h,
                leftAligned: duelResultStyle,
              ),
            if (bHidden)
              _hiddenCard(bottom: 130.h)
            else
              for (var i = 0; i < bPlayers.length; i++)
                _positionPlayer(i, bPlayers[i], b, isTopTeam: false),
            if (showOpponent &&
                !noTeamAtAll &&
                !bHidden &&
                bPlayers.isEmpty)
              _teamNotReady(b?.teamName ?? 'Team B', Colors.blue, bottom: 100.h),
          ],
        ),
      ),
    );
  }

  // ── Duel results: one card, one column per team ──────────────────────────

  static const double _bonusImageSize = 44;

  List<Widget> _duelBonusCard() {
    if (teamA == null && teamB == null) return const [];
    return [
      Container(
        width: double.infinity,
        constraints: BoxConstraints(maxWidth: 362.w),
        margin: EdgeInsets.only(top: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
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
              Expanded(child: _bonusColumn(teamA)),
              Container(width: 1.w, color: const Color(0xFF2C2C2C)),
              Expanded(child: _bonusColumn(teamB)),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _bonusColumn(PlayerScore? t) {
    if (t == null) return const SizedBox.shrink();
    final sixth = _sixth(t);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Column(
        children: [
          Text(
            t.teamName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          SizedBox(
            height: _bonusImageSize.w,
            child: Center(child: _bonusZone(t)),
          ),
          if (sixth != null) ...[
            SizedBox(height: 6.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    sixth.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                  ),
                ),
                Text(
                  ' · ',
                  style: TextStyle(color: Colors.white70, fontSize: 11.sp),
                ),
                scoresHidden
                    ? Icon(Icons.lock_outline, color: Colors.grey, size: 13.r)
                    : Text('${sixth.score}', style: scoreTextStyle(size: 14)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Decided only by what the server sends: [PlayerScore.bonusHidden] first,
  /// then [PlayerScore.bonus] (null = no bonus; an unknown value = empty).
  Widget _bonusZone(PlayerScore t) {
    if (t.bonusHidden) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, color: Colors.grey, size: 18.r),
          SizedBox(height: 2.h),
          Text(
            AppString.bonusRevealTime.trParams(publicationTimeParams()),
            style: TextStyle(color: Colors.grey, fontSize: 11.sp),
          ),
        ],
      );
    }
    final AssetGenImage? image;
    switch (t.bonus) {
      case 'sixth_man':
        image = Assets.icons.sixman;
      case 'chef_curry':
        image = Assets.icons.chefcurry;
      case 'luxury_tax':
        image = Assets.icons.luxarytax;
      case null:
        return Text(
          AppString.noBonus.tr,
          style: TextStyle(color: Colors.grey, fontSize: 11.sp),
        );
      default:
        return const SizedBox.shrink(); // unknown value: nothing, no error
    }
    return image.image(
      width: _bonusImageSize.w,
      height: _bonusImageSize.w,
      fit: BoxFit.contain,
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
                AppString.teamRevealedAtTipOff.tr,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 12.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Finished duel where neither player set a lineup.
  Widget _noLineupCard() => _messageCard(
        AppString.noLineupTitle.tr,
        AppString.noLineupDesc.tr,
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
    Widget label = Container(
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
    final maxWidth = labelMaxWidth;
    if (maxWidth != null) {
      label = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: label,
        ),
      );
    }
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
            matchFinished
                ? AppString.playerNoLineupTemplate.trParams({'name': name})
                : AppString.teamNotReady.tr,
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
    final double y = shareCompact
        ? switch (index) {
            // Center and wings stay clear of the guards, who stand between
            // them sideways and a row lower: no two players touch.
            1 => 6.h,
            0 || 2 => 44.h,
            _ => 118.h,
          }
        : switch (index) {
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
        left = shareCompact ? 88.w : 62.w;
      case 4:
        right = shareCompact ? 88.w : 62.w;
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

  static const _haloColors = {
    1: Color(0xFFFFC83D),
    2: Color(0xFFDDE3EC),
    3: Color(0xFFFF7A2F),
  };

  // Halo that follows the shirt itself (not the picture box, mostly empty
  // around the shirt): a tinted copy of the jersey, blurred, under the jersey.
  Widget _halo(AssetGenImage jersey, Color color, double sigma, double alpha) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(
          color.withValues(alpha: alpha),
          BlendMode.srcIn,
        ),
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
    );
  }

  /// The substitute stands on the half-way line (the court's bottom edge for a
  /// lineup without him): the top of his jersey on the line, centred, his name
  /// and points in the other half. The court is longer by [_belowLine] to hold
  /// them. 341 = 350 (the line) - 9 (where the drawn jersey starts in its box);
  /// 106 = what is needed under the line, margin included.
  static const double _substituteTop = 341;
  static const double _belowLine = 106;

  Widget _substituteOnCourt() {
    final team = teamA!;
    final sub = team.substitute!;
    final state = team.substitution;
    final entered = state?.isEntered ?? false;
    final notEntered = state?.isNotEntered ?? false;
    final jersey = jerseyAsset(team.jerseyIndex);
    final body = _playerBody(
      sub,
      jersey,
      // Counted points plain, the others in brackets (nothing counts yet, or
      // he did not come in).
      scoreText: entered ? null : '(${sub.score})',
      // Like on the composition screen: a jersey at 80 % while nothing is decided.
      jerseyOpacity: entered || notEntered ? 1.0 : 0.8,
      cornerMark: entered ? const SubstituteEnteredMark() : null,
    );
    return Positioned(
      key: const ValueKey('substitute-on-court'),
      top: _substituteTop.h,
      left: 0,
      right: 0,
      child: Center(
        child: notEntered
            ? Opacity(key: const ValueKey('in-the-shadow'), opacity: 0.4, child: body)
            : body,
      ),
    );
  }

  /// A player who is not playing: in the shadow, with [badge] on his jersey.
  Widget _inTheShadow(Widget body, Widget badge, {required String keyName}) {
    return SizedBox(
      width: 90.w,
      height: 107.h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(
            key: const ValueKey('in-the-shadow'),
            opacity: 0.4,
            child: body,
          ),
          Positioned(
            key: ValueKey(keyName),
            right: -2.w,
            top: 2.h,
            child: badge,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer(PlayerSelection player, AssetGenImage jersey) {
    if (!player.absent) return _playerBody(player, jersey);
    // A starter who played no minute: in the shadow, with the OUT badge.
    return _inTheShadow(
      _playerBody(player, jersey, scoreText: '0'),
      const OutBadge(),
      keyName: 'starter-out',
    );
  }

  Widget _playerBody(
    PlayerSelection player,
    AssetGenImage jersey, {
    String? scoreText,
    double jerseyOpacity = 1.0,
    Widget? cornerMark,
  }) {
    final rank = medals?[player.id];
    final haloColor = rank == null ? null : _haloColors[rank];
    return SizedBox(
      width: 90.w,
      height: 107.h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (haloColor != null) ...[
            Positioned(
              left: 0,
              top: 0,
              child: _halo(jersey, haloColor, 9.w, 0.85),
            ),
            Positioned(
              left: 0,
              top: 0,
              child: _halo(jersey, haloColor, 3.w, 1),
            ),
          ],
          Positioned(
            left: 0,
            top: 0,
            child: Opacity(
              opacity: jerseyOpacity,
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
          ),
          if (cornerMark != null)
            Positioned(left: 62.w, top: 16.h, child: cornerMark),
          if (haloColor != null)
            Positioned(
              right: -4.w,
              top: 2.h,
              child: Transform.rotate(
                angle: 0.2,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: const Color(0xCC111111),
                    borderRadius: BorderRadius.circular(3.r),
                    border: Border.all(color: haloColor, width: 1.2.w),
                  ),
                  child: Text(
                    '${AppString.nightTopRank.tr} $rank',
                    style: TextStyle(
                      color: haloColor,
                      fontSize: 8.sp,
                      fontFamily: 'Roboto',
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      height: 1.2,
                    ),
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
                        scoreText ?? '${player.score}',
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
