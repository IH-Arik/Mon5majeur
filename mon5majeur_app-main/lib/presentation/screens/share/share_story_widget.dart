import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/custom_assets/assets.gen.dart';
import '../../../core/utils/score_style.dart';
import '../../../data/models/match_result_model.dart';
import '../home/widgets/match_lineups_field.dart';
import 'share_story_model.dart';

const _orange = Color(0xFFE8642F);
// The same green and red as ScoreLine (the duel cards in Results).
const _win = Color(0xFF22C55E);
const _lose = Color(0xFFEF4444);
const _grey = Color(0xFF9A9A9A);

/// The 9:16 share image (designed for 1080x1920): a fixed 360x640 canvas, so
/// it looks the same on every device and renders at 1080x1920 with a pixel
/// ratio of 3. The court is the app's own [MatchLineupsField], scaled down
/// whole, so nothing in it is redrawn here.
///
/// Instagram covers the top (progress bar, account name) and the bottom (reply
/// field) of a story: 6 % of the height stays empty at both ends.
class ShareStoryWidget extends StatelessWidget {
  final ShareStoryData data;
  const ShareStoryWidget({super.key, required this.data});

  static const double width = 360;
  static const double height = 640;
  static const double _safeV = height * 0.06;

  // The court's own size at design scale (see MatchLineupsField._court).
  static double get _courtW => 362.w;
  static double get _duelCourtH => 482.h; // 12 margin + the 470 compact court
  static double get _worldCourtH => 362.h; // 12 margin + the 350 half court

  // Bebas Neue through the app's score style, in canvas pixels (not .sp).
  static TextStyle _bebas(double size, Color color, {double spacing = 1}) =>
      scoreTextStyle(
        size: 1,
        color: color,
        letterSpacing: spacing,
      ).copyWith(fontSize: size);

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: width,
        height: height,
        child: ColoredBox(
          color: Colors.black,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, _safeV, 12, _safeV),
            child: Column(
              children: [
                _header(),
                const SizedBox(height: 6),
                if (data.isDuel) ...[
                  _duelScore(),
                ] else
                  // The team name is on the court's own label: not repeated.
                  _worldScore(),
                const SizedBox(height: 4),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: data.isDuel ? _duelCourt() : _worldCourt(),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                _humor(),
                const SizedBox(height: 8),
                _footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  // "Journée 8 · 28/10", or just the date when the night has no number.
  String get _dayLabel {
    final phase = data.phaseLabel;
    if (phase != null && phase.isNotEmpty) return '$phase · ${data.dateLabel}';
    final n = data.matchDay;
    if (n == null) return data.dateLabel;
    return '${AppString.matchdayNumberTemplate.trParams({'n': '$n'})}'
        ' · ${data.dateLabel}';
  }

  // The logo is the ad: big, on the left. The league and the day on the right.
  Widget _header() => SizedBox(
    height: 32,
    child: Row(
      children: [
        Assets.icons.nameLogo.image(height: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                data.isDuel ? data.leagueName : AppString.globalLeague.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                _dayLabel,
                maxLines: 1,
                style: const TextStyle(color: _grey, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ── Duel ──────────────────────────────────────────────────────────────────

  // Score centered, the result stamp under it, the tie mention under the stamp.
  Widget _duelScore() => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Home on the left, away on the right; mine in the result's color
          // (green / red), theirs in grey. A tie follows the home rule.
          Text(
            '${data.homeScore}',
            style: _bebas(38, data.iAmHome ? _resultColor : _grey),
          ),
          Text(' – ', style: _bebas(26, _grey)),
          Text(
            '${data.awayScore}',
            style: _bebas(38, data.iAmHome ? _grey : _resultColor),
          ),
        ],
      ),
      const SizedBox(height: 2),
      _resultStamp(),
      if (data.category.isTie)
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            AppString.tieHomeWins.tr,
            style: const TextStyle(color: _grey, fontSize: 10),
          ),
        ),
    ],
  );

  // Green after a win (a tie won at home), red after a defeat.
  Color get _resultColor => data.category.isWin ? _win : _lose;

  Widget _resultStamp() {
    final win = data.category.isWin;
    return _stamp(
      (win ? AppString.shareVictory : AppString.shareDefeat).tr,
      _resultColor,
    );
  }

  Widget _stamp(String text, Color color) => Transform.rotate(
    angle: -0.05,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 2),
      ),
      child: Text(text, maxLines: 1, style: _bebas(20, color, spacing: 2)),
    ),
  );

  /// A team's bonus (and its 6th man, who never stands on the court), in the
  /// free corner of its own half. Nothing while the server still hides the
  /// bonus, or when none was used. A 6th man who does not beat the weakest of
  /// the five does not count: his card is greyed out, so nobody adds him to the
  /// score. Sizes are in court units (.w / .sp).
  Widget? _bonusCard(PlayerScore team) {
    PlayerSelection? sixth;
    for (final p in team.selection) {
      if (p.isSixthMan) sixth = p;
    }
    final (AssetGenImage? icon, String label) = team.bonusHidden
        ? (null, '')
        : switch (team.bonus) {
            'chef_curry' => (Assets.icons.chefcurry, AppString.chefCurry.tr),
            'sixth_man' => (Assets.icons.sixman, AppString.sixthMan.tr),
            'luxury_tax' => (Assets.icons.luxarytax, AppString.luxuryTax.tr),
            _ => (null, ''),
          };
    if (icon == null) return null;

    final starters = [
      for (final p in team.selection)
        if (!p.isSixthMan) p.score,
    ];
    final counts =
        sixth == null ||
        starters.isEmpty ||
        sixth.score > starters.reduce((a, b) => a < b ? a : b);
    final accent = counts ? _orange : _grey;

    return Container(
      width: 96.w,
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: accent, width: 1.5.w),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: counts ? 1 : 0.4,
            child: icon.image(width: 26.w, height: 26.h, fit: BoxFit.contain),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    style: TextStyle(
                      color: accent,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (team.bonus == 'chef_curry')
                  Text('+3', style: scoreTextStyle(size: 14, color: accent))
                else if (sixth != null)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${sixth.name} ',
                          style: TextStyle(
                            color: counts ? const Color(0xFFFECD56) : _grey,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${sixth.score}',
                          style: scoreTextStyle(
                            size: 14,
                            color: counts ? Colors.white : _grey,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _duelCourt() {
    final homeCard = _bonusCard(data.home);
    final awayCard = data.away == null ? null : _bonusCard(data.away!);
    return SizedBox(
      width: _courtW,
      height: _duelCourtH,
      child: Stack(
        children: [
          // The shared field also draws a bonus card under the court: it is
          // cut off here, the story shows the bonus in the court's corners.
          ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minWidth: _courtW,
              maxWidth: _courtW,
              minHeight: 0,
              maxHeight: 1200.h,
              child: MatchLineupsField(
                teamA: data.home,
                teamB: data.away,
                duelResultStyle: true,
                matchFinished: true,
                medals: data.medals,
                shareCompact: true,
                // Stops short of the center player and the bonus card.
                labelMaxWidth: 122.w,
              ),
            ),
          ),
          if (homeCard != null)
            Positioned(top: 14.h, right: 8.w, child: homeCard),
          if (awayCard != null)
            Positioned(bottom: 4.h, right: 8.w, child: awayCard),
        ],
      ),
    );
  }

  // ── World League ──────────────────────────────────────────────────────────

  Widget _worldCourt() => SizedBox(
    width: _courtW,
    height: _worldCourtH,
    child: MatchLineupsField(
      teamA: data.me,
      teamB: null,
      showOpponent: false,
      globalResultStyle: true,
      matchFinished: true,
      medals: data.medals,
      labelMaxWidth: 340.w,
    ),
  );

  // Same shape as the duel's: the score centered, a stamp under it.
  Widget _worldScore() {
    final color = data.category.isLoss ? _grey : _orange;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('${data.myScore}', style: _bebas(38, Colors.white)),
            const SizedBox(width: 6),
            Text(AppString.sharePts.tr, style: _bebas(22, color)),
          ],
        ),
        const SizedBox(height: 2),
        _stamp(AppString.shareNightScore.tr.toUpperCase(), color),
      ],
    );
  }

  // ── Bottom ────────────────────────────────────────────────────────────────

  // The punchline, handwritten and a little slanted: orange after a win, light
  // grey after a defeat. Two lines at most.
  Widget _humor() => SizedBox(
    width: double.infinity,
    child: Transform.rotate(
      angle: -0.044, // about -2.5 degrees
      child: Text(
        data.category.humor,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'CaveatBrush',
          fontSize: 16,
          height: 1.25,
          color: data.category.isLoss ? const Color(0xFFBDBDBD) : _orange,
        ),
      ),
    ),
  );

  // Both stores the same size, so they sit side by side as a pair.
  Widget _store(AssetGenImage icon, String label) => Container(
    width: 108,
    padding: const EdgeInsets.symmetric(vertical: 3),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: Colors.white24),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        icon.image(width: 11, height: 11),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
      ],
    ),
  );

  // Secondary to the court and the punchline: small, in the score's face.
  Widget _cta() => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      AppString.shareCta.tr.toUpperCase(),
      maxLines: 1,
      style: _bebas(15, Colors.white, spacing: 1.5),
    ),
  );

  // One centered block: a thin line, the call to action, the two stores.
  Widget _footer() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(height: 1, width: double.infinity, color: Colors.white24),
      const SizedBox(height: 6),
      _cta(),
      const SizedBox(height: 5),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _store(Assets.icons.apple, AppString.shareAppStore.tr),
          const SizedBox(width: 8),
          _store(Assets.icons.google, AppString.shareGooglePlay.tr),
        ],
      ),
    ],
  );
}
