import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/custom_assets/assets.gen.dart';
import '../../core/routes/route_path.dart';
import '../../core/routes/routes.dart';
import '../../core/utils/datetime_format.dart';
import '../../core/utils/score_style.dart';
import '../../data/models/my_match_today_model.dart';

/// Opens the match detail screen (both lineups, player scores, result) —
/// QA 15/09/2026 items 4 & 8. Uses the private-league endpoint, which serves
/// any league the caller is a member of.
void openMatchDetail(
  BuildContext context, {
  required int leagueId,
  required int matchDay,
  bool isPrivate = true,
  String? matchObjectId,
}) {
  final query = StringBuffer(
    'leagueId=$leagueId&matchDay=$matchDay&isPrivate=$isPrivate',
  );
  if (matchObjectId != null) query.write('&matchObjectId=$matchObjectId');
  context.push('${RoutePath.matchDetailScreen.addBasePath}?$query');
}

/// Status badge shared by every match card (QA 15/09/2026 items 4/5/7):
/// "En cours"/"Live" with the Live Score icon above it while playing,
/// "Terminé"/"Final" once over. Not shown for a match that hasn't started.
class MatchStatusBadge extends StatelessWidget {
  final String status;

  const MatchStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == 'live') {
      const color = Color(0xFFEF4444);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Assets.icons.livescoring.image(width: 18.r, height: 18.r),
          SizedBox(height: 3.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              AppString.liveLabel.tr,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }
    if (status == 'completed') {
      const color = Color(0xFF22C55E);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: color, size: 18.r),
          SizedBox(height: 3.h),
          Text(
            AppString.finalLabel.tr,
            style: TextStyle(
              color: color,
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

/// The "Score dispo à 9h" placeholder shown instead of the digits while the
/// server is withholding a non-subscriber's scores.
class ScoreLockedLabel extends StatelessWidget {
  final double fontSize;

  const ScoreLockedLabel({super.key, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.lock_outline, color: Colors.grey, size: 16.r),
        SizedBox(height: 2.h),
        Text(
          AppString.scoreAvailableAt9.tr,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: fontSize.sp),
        ),
      ],
    );
  }
}

/// "12 – 9" in the scoreboard font, with breathing room on both sides so the
/// digits never touch a team name (QA 15/09 item 4: "Dunk Stars 10").
class ScoreLine extends StatelessWidget {
  final int scoreA;
  final int scoreB;
  final double size;

  const ScoreLine({
    super.key,
    required this.scoreA,
    required this.scoreB,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    final winnerA = scoreA > scoreB;
    final winnerB = scoreB > scoreA;
    const win = Color(0xFF22C55E);
    const lose = Color(0xFFEF4444);
    const tie = Colors.white;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$scoreA',
          style: scoreTextStyle(
            size: size,
            color: winnerA ? win : (winnerB ? lose : tie),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Text(
            '-',
            style: scoreTextStyle(size: size * 0.8, color: Colors.white54),
          ),
        ),
        Text(
          '$scoreB',
          style: scoreTextStyle(
            size: size,
            color: winnerB ? win : (winnerA ? lose : tie),
          ),
        ),
      ],
    );
  }
}

/// One duel card — the SAME component on the Home "Résultats de la nuit"
/// section and on the "all my matches" screen (QA 15/09 item 5). Tapping
/// opens the match detail.
class NightMatchCard extends StatelessWidget {
  final MyMatchTodayModel match;

  const NightMatchCard({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    final pair = match.pairs.isNotEmpty ? match.pairs.first : null;
    final locked = match.scoresHidden;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openMatchDetail(
        context,
        leagueId: match.leagueId,
        matchDay: match.matchDay,
        matchObjectId: pair?.matchObjectId,
      ),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a1a),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFF333333)),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.1),
              blurRadius: 15.r,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 2.h),
                  child: Assets.icons.basketBall.image(
                    width: 20.r,
                    height: 20.r,
                  ),
                ),
                SizedBox(width: 8.w),
                // Full league name, wrapped — never cut with "..." (QA 15/09).
                Expanded(
                  child: Text(
                    match.leagueName,
                    softWrap: true,
                    style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  ),
                ),
                SizedBox(width: 8.w),
                MatchStatusBadge(status: match.status),
              ],
            ),
            SizedBox(height: 6.h),
            Wrap(
              spacing: 8.w,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  formatMatchdayLabel(match.matchDay),
                  style: TextStyle(
                    color: const Color(0xFFAAAAAA),
                    fontSize: 12.sp,
                  ),
                ),
                Text(
                  '•',
                  style: TextStyle(
                    color: const Color(0xFFAAAAAA),
                    fontSize: 12.sp,
                  ),
                ),
                Text(
                  formatMatchDate(match.matchDate),
                  style: TextStyle(
                    color: const Color(0xFFAAAAAA),
                    fontSize: 12.sp,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF462C21),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    AppString.headToHead.tr,
                    style: TextStyle(
                      color: const Color(0xFFF16C37),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (pair != null) ...[
              SizedBox(height: 16.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _teamLogo(Assets.icons.logo1),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      pair.playerAName ?? 'TBD',
                      softWrap: true,
                      style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: locked
                        ? const ScoreLockedLabel()
                        : (match.resultAvailable
                              ? ScoreLine(
                                  scoreA: pair.scoreA,
                                  scoreB: pair.scoreB,
                                )
                              : Text(
                                  AppString.vs.tr,
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14.sp,
                                  ),
                                )),
                  ),
                  Expanded(
                    child: Text(
                      pair.playerBName ?? 'TBD',
                      textAlign: TextAlign.right,
                      softWrap: true,
                      style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  _teamLogo(pair.hasPlayerB ? Assets.icons.logo2 : null),
                ],
              ),
            ],
            if (match.isLiveForUser && pair?.matchObjectId != null) ...[
              SizedBox(height: 12.h),
              GestureDetector(
                onTap: () => context.push(
                  '${RoutePath.liveScoreScreen.addBasePath}?matchId=${pair!.matchObjectId}',
                ),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  decoration: ShapeDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8632C), Color(0xFFFF8A50)],
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bolt, color: Colors.white, size: 14.r),
                      SizedBox(width: 6.w),
                      Text(
                        AppString.watchLive.tr,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _teamLogo(AssetGenImage? logo) {
    return Container(
      width: 36.w,
      height: 36.w,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF2a2a2a),
      ),
      child: Center(
        child: logo != null
            ? logo.image(width: 22.r, height: 22.r, fit: BoxFit.contain)
            : Icon(Icons.question_mark, color: Colors.grey[600], size: 18.r),
      ),
    );
  }
}
