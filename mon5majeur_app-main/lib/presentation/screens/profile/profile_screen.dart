import '../../../core/utils/logo_assets.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/custom_assets/assets.gen.dart';
import '../../../core/routes/route_path.dart';
import '../../../core/routes/routes.dart';
import '../../../core/utils/score_style.dart';
import '../../../data/models/profile_stats_model.dart';
import '../../widgets/navigation.dart';
import 'profile_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProfileController());
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20.h),

              /// Settings Icon (Top Right)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () => context.go(
                        RoutePath.profileSettingsScreen.addBasePath,
                      ),
                      icon: Icon(
                        Icons.settings,
                        color: Colors.grey,
                        size: 30.r,
                      ),
                    ),
                  ],
                ),
              ),

              /// Team Logo
              Container(
                width: 100.w,
                height: 100.h,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1a1a1a),
                  border: Border.all(
                    color: const Color(0xFF333333),
                    width: 2.r,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 56.w,
                    height: 60.h,
                    decoration: BoxDecoration(shape: BoxShape.circle),
                    child: ClipOval(
                      child: Obx(
                        () => _teamLogoAsset(
                          controller.stats.value.teamLogo,
                        ).image(
                          width: 56.w,
                          height: 60.h,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 4.h),

              /// Team Name
              Obx(() {
                final name = controller.stats.value.teamName;
                return Text(
                  name.isNotEmpty ? name : AppString.teamName.tr,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }),

              /// Since Year
              Obx(() => Text(
                    '${AppString.sincePrefix.tr} ${controller.stats.value.sinceYear}',
                    style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                  )),

              SizedBox(height: 30.h),

              /// Statistics Overview Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppString.statisticsOverview.tr,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    /// Statistics Grid (2x2)
                    Obx(() {
                      final s = controller.stats.value;
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  title: AppString.statWLNB.tr,
                                  // QA4 #12: there is no draw mechanic - a
                                  // duel is always won or lost - so the
                                  // stored noMatch/draw count is dropped
                                  // entirely rather than displayed. Letters
                                  // follow the app language (V/D in FR, W/L
                                  // in EN) through AppString.
                                  value: _WinLossValue(
                                    wins: s.wins,
                                    losses: s.losses,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: _StatCard(
                                  title: AppString.statLeaguePlay.tr,
                                  value: _StatNumber(
                                    number: '${s.totalMatches}',
                                    unit: AppString.matches.tr,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  title: AppString.statRegularSeason.tr,
                                  value: _StatNumber(
                                    number: '${s.regularSeasonWins}',
                                    unit: AppString.wins.tr,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: _StatCard(
                                  title: AppString.statLeagueWins.tr,
                                  value: _StatNumber(
                                    number: '${s.leagueVictories}',
                                    unit: AppString.victories.tr,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              /// Trophies Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppString.trophies.tr,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    /// Trophy Cards (see _trophyDefs for what each one shows).
                    /// Four equal cards 12 apart, on the same 16 margins as the
                    /// statistics tiles above. A tap opens its description.
                    Obx(() {
                      final s = controller.stats.value;
                      return Row(
                        children: [
                          for (var i = 0; i < _trophyDefs.length; i++) ...[
                            if (i > 0) SizedBox(width: 12.w),
                            Expanded(
                              child: _TrophyCard(
                                def: _trophyDefs[i],
                                count: _trophyCount(s, _trophyDefs[i].kind),
                              ),
                            ),
                          ],
                        ],
                      );
                    }),
                  ],
                ),
              ),

              SizedBox(height: 40.h),

              /// Performance Highlights Section
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppString.performanceHighlights.tr,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    /// Average Point Scored
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(24.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1a1a1a),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: const Color(0xFF333333)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            AppString.avgPointScored.tr,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16.sp,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Obx(() => Text(
                                controller.stats.value.avgPointsScored
                                    .toStringAsFixed(1),
                                style: scoreTextStyle(
                                  size: 44,
                                  color: const Color(0xFF3CDF1C),
                                ),
                              )),
                        ],
                      ),
                    ),

                    SizedBox(height: 16.h),

                    /// Average Point Conceded
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(24.r),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1a1a1a),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: const Color(0xFF333333)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            AppString.avgPointConceded.tr,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16.sp,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Obx(() => Text(
                                controller.stats.value.avgPointsConceded
                                    .toStringAsFixed(1),
                                style: scoreTextStyle(
                                  size: 44,
                                  color: const Color(0xFFD32F2F),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 100.h),
            ],
          ),
        ),
      ),

      /// Bottom Navigation Bar
      bottomNavigationBar: const NavigationWidget(currentIndex: 4),
    );
  }

  // Get team logo asset based on team_logo string from API
  // (same mapping used by HomeController.getTeamLogoAsset).
  AssetGenImage _teamLogoAsset(String teamLogo) => logoAsset(teamLogo);

}

/// Statistics Card Widget: a grey label above a value (a widget, so the number
/// and its unit, or the two colours of W / L, can share one baseline).
class _StatCard extends StatelessWidget {
  final String title;
  final Widget value;

  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(color: Colors.grey, fontSize: 13.sp),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12.h),
          value,
        ],
      ),
    );
  }
}

/// A big white number in the scoreboard face with its small grey unit on the
/// same baseline ("12 Matches"), scaled down rather than overflowing.
class _StatNumber extends StatelessWidget {
  final String number;
  final String unit;

  const _StatNumber({required this.number, required this.unit});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(number, style: scoreTextStyle(size: 28, color: Colors.white)),
          SizedBox(width: 4.w),
          Text(
            unit,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// "12V - 5D": wins and their letter in green, losses and theirs in red, the
/// separator in grey. The letters come from AppString (V / D in French,
/// W / L in English).
class _WinLossValue extends StatelessWidget {
  final int wins;
  final int losses;

  const _WinLossValue({required this.wins, required this.losses});

  static const _green = Color(0xFF3CDF1C);
  static const _red = Color(0xFFD32F2F);

  @override
  Widget build(BuildContext context) {
    TextStyle letter(Color color) => TextStyle(
      color: color,
      fontSize: 14.sp,
      fontWeight: FontWeight.w700,
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('$wins', style: scoreTextStyle(size: 28, color: _green)),
          Text(AppString.statWinLetter.tr, style: letter(_green)),
          Text(
            '  -  ',
            style: TextStyle(color: Colors.grey, fontSize: 14.sp),
          ),
          Text('$losses', style: scoreTextStyle(size: 28, color: _red)),
          Text(AppString.statLossLetter.tr, style: letter(_red)),
        ],
      ),
    );
  }
}

enum _TrophyKind { leagueChampion, bestOfMonth, bestOfWeek, lastPlace }

class _TrophyDef {
  final AssetGenImage image;
  final _TrophyKind kind;
  final Color color;
  final String nameKey;
  final String descKey;

  const _TrophyDef(this.image, this.kind, this.color, this.nameKey, this.descKey);
}

/// THE one place that wires each trophy IMAGE to its COUNTER, its COLOUR and
/// its texts, in the order of the cards. The colour belongs to the image; the
/// texts belong to the counter (see _trophyCount):
///   trophie1 gold wings  : trophy_gold      league champion          gold
///   trophie2 globe       : trophy_diamond   Global League MONTHLY #1 light blue
///   trophie3 silver ball : trophy_silver    Global League WEEKLY #1  silver
///   trophie4 orange "L"  : trophy_orange_l  last of a duel league    bronze
/// (the field names are the server's: "diamond" is the monthly one and
/// "silver" the weekly one). To swap two cards later, swap their rows here.
final _trophyDefs = <_TrophyDef>[
  _TrophyDef(
    Assets.icons.trophie1,
    _TrophyKind.leagueChampion,
    const Color(0xFFFFD54A),
    AppString.trophyLeagueChampionName,
    AppString.trophyLeagueChampionDesc,
  ),
  _TrophyDef(
    Assets.icons.trophie2,
    _TrophyKind.bestOfMonth,
    const Color(0xFF6EC1E4),
    AppString.trophyBestOfMonthName,
    AppString.trophyBestOfMonthDesc,
  ),
  _TrophyDef(
    Assets.icons.trophie3,
    _TrophyKind.bestOfWeek,
    const Color(0xFFC9D1D9),
    AppString.trophyBestOfWeekName,
    AppString.trophyBestOfWeekDesc,
  ),
  _TrophyDef(
    Assets.icons.trophie4,
    _TrophyKind.lastPlace,
    const Color(0xFFCD7F32),
    AppString.trophyLastPlaceName,
    AppString.trophyLastPlaceDesc,
  ),
];

int _trophyCount(ProfileStatsModel s, _TrophyKind kind) => switch (kind) {
  _TrophyKind.leagueChampion => s.trophyGold,
  _TrophyKind.bestOfMonth => s.trophyDiamond,
  _TrophyKind.bestOfWeek => s.trophySilver,
  _TrophyKind.lastPlace => s.trophyOrangeL,
};

/// The description sheet of a trophy: big image with its halo, name,
/// description and how many were obtained. Scrolls if the screen is small.
void _showTrophySheet(BuildContext context, _TrophyDef def, int count) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1a1a1a),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.9,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF444444),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 24.h),
            Container(
              width: 150.r,
              height: 150.r,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: def.color.withValues(alpha: 0.3),
                    blurRadius: 40.r,
                    spreadRadius: 4.r,
                  ),
                ],
              ),
              child: def.image.image(
                width: 140.r,
                height: 140.r,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              def.nameKey.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              def.descKey.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 15.sp,
                height: 1.4,
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              AppString.trophyObtainedTimes.trParams({'n': '${count}x'}),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: def.color,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Trophy Card Widget: a thin outline and a soft halo in the trophy's colour,
/// the same whatever the counter. With a counter above 0 the colour also glows
/// from the four edges toward the inside of the card (fading to nothing before
/// the trophy in the middle) and the image is at full strength; with a counter
/// of 0 there is no inner glow and the image is muted. The number is white
/// either way.
class _TrophyCard extends StatelessWidget {
  final _TrophyDef def;
  final int count;

  const _TrophyCard({required this.def, required this.count});

  static const double _outline = 1.2;

  @override
  Widget build(BuildContext context) {
    final color = def.color;
    final earned = count > 0;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: color,
          width: _outline,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 12.r,
          ),
        ],
      ),
      // Clipped to the rounded corners, inside the outline.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r - _outline),
        child: Stack(
          children: [
            if (earned)
              Positioned.fill(
                child: CustomPaint(
                  painter: _InnerGlowPainter(
                    color: color,
                    radius: 16.r - _outline,
                    sigma: 9.r,
                  ),
                ),
              ),
            // Full card width, so the image and the number stay centred.
            SizedBox(
              width: double.infinity,
              child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20.h),
              child: Column(
                children: [
                  Opacity(
                    opacity: earned ? 1.0 : 0.4,
                    child: def.image.image(
                      width: 60.w,
                      height: 60.h,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  // "3x": the x stays glued to the number; scaled down, never
                  // wrapped.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${count}x',
                      style: scoreTextStyle(size: 26, color: Colors.white),
                    ),
                  ),
                ],
              ),
              ),
            ),
            // Tap: opens the description. The ripple stays inside the
            // rounded corners and the card looks the same at rest.
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => _showTrophySheet(context, def, count),
                  splashColor: color.withValues(alpha: 0.18),
                  highlightColor: color.withValues(alpha: 0.08),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Light that radiates from the four edges of a rounded card toward its
/// centre (an inner glow): the colour is about 40% at the edge and fades to
/// transparent within a couple of [sigma]. Drawn behind the card's content.
class _InnerGlowPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double sigma;

  const _InnerGlowPainter({
    required this.color,
    required this.radius,
    required this.sigma,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final card = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    // Everything OUTSIDE the card, blurred: its blur bleeds inward from every
    // edge and corner, evenly. (A blurred straight edge is only about 40% at a
    // few points inside the card, fading out over a couple of [sigma].)
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect.inflate(sigma * 4)),
      Path()..addRRect(card),
    );
    canvas.save();
    canvas.clipRRect(card);
    canvas.drawPath(
      outside,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InnerGlowPainter old) =>
      old.color != color || old.radius != radius || old.sigma != sigma;
}
