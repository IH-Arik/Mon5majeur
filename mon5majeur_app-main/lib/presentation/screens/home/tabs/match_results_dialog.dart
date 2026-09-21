import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/local_db/local_db.dart';
import '../../../../data/models/playoff_bracket_model.dart';
import '../../../widgets/match_widgets.dart';

/// Series popup (QA 15/09/2026 item 8): round name + series score, the games
/// of the series (best-of-3, so up to 3) with both teams and scores, and a
/// close (X). Tapping a played game opens its match detail (both lineups and
/// every player's score).
class SeriesDialog extends StatelessWidget {
  final PlayoffSeries series;
  final int leagueId;
  final bool isPrivate;

  const SeriesDialog({
    super.key,
    required this.series,
    required this.leagueId,
    required this.isPrivate,
  });

  bool get _isFinal => series.round == 'final';

  // Singular ("Demi-finale"): this popup is about one series, unlike the
  // plural round header ("Demi-finales") on the bracket list.
  String get _seriesRoundName =>
      _isFinal ? AppString.finalRound.tr : AppString.semifinalRound.tr;

  String _gameTitle(int n) => (_isFinal
          ? AppString.finalGameTemplate
          : AppString.semifinalGameTemplate)
      .trParams({'n': '$n'});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        constraints: BoxConstraints(maxWidth: 350.w),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(9.r),
          border: Border.all(color: const Color(0xFF2C2C2C), width: 4.r),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 12.w),
            child: FutureBuilder<String>(
              future: SharedPrefsHelper.getString(AppConstants.userId),
              builder: (context, snap) {
                final me = int.tryParse(snap.data ?? '');
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(context),
                    SizedBox(height: 16.h),
                    if (series.games.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        child: Text(
                          AppString.noGamesInSeriesYet.tr,
                          style: TextStyle(color: Colors.grey, fontSize: 13.sp),
                        ),
                      )
                    else
                      for (final g in series.games) ...[
                        _gameRow(context, g, me),
                        SizedBox(height: 12.h),
                      ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
              ),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Column(
              children: [
                Text(
                  _seriesRoundName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  AppString.seriesScoreTemplate.trParams({
                    'a': '${series.winsA}',
                    'b': '${series.winsB}',
                  }),
                  style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 8.w),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            padding: EdgeInsets.all(6.r),
            decoration: const BoxDecoration(
              color: Color(0xFFD32F2F),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.close, color: Colors.white, size: 18.r),
          ),
        ),
      ],
    );
  }

  Widget _gameRow(BuildContext context, PlayoffGame g, int? me) {
    final involvesMe = me != null && (me == series.teamAId || me == series.teamBId);
    final played = g.matchStatus == 'completed' || g.matchStatus == 'live';
    final tappable = g.matchDay != null && played;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tappable
          ? () {
              Navigator.of(context).pop();
              openMatchDetail(
                context,
                leagueId: leagueId,
                matchDay: g.matchDay!,
                isPrivate: isPrivate,
              );
            }
          : null,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF20222B), Color(0xFF14151C)],
          ),
          border: Border.all(color: const Color(0xFF2C2C2C), width: 1.r),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _gameTitle(g.gameNumber),
                    style: TextStyle(
                      color: const Color(0xFFB0B0B0),
                      fontSize: 10.sp,
                    ),
                  ),
                ),
                if (involvesMe)
                  Padding(
                    padding: EdgeInsets.only(right: 6.w),
                    child: Text(
                      AppString.you.tr,
                      style: TextStyle(
                        color: const Color(0xFFFF8C42),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                MatchStatusBadge(
                  status: g.matchStatus == 'scheduled' ? 'upcoming' : g.matchStatus,
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: Text(
                    series.teamAName,
                    softWrap: true,
                    style: TextStyle(
                      color: const Color(0xFFAAAAAA),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  child: g.scoresHidden
                      ? const ScoreLockedLabel(fontSize: 9)
                      : (played
                            ? ScoreLine(
                                scoreA: g.scoreA,
                                scoreB: g.scoreB,
                                size: 22,
                              )
                            : Text(
                                AppString.vs.tr,
                                style: TextStyle(
                                  color: const Color(0xFFB0B0B0),
                                  fontSize: 11.sp,
                                ),
                              )),
                ),
                Expanded(
                  child: Text(
                    series.teamBName,
                    textAlign: TextAlign.right,
                    softWrap: true,
                    style: TextStyle(
                      color: const Color(0xFFAAAAAA),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (tappable)
                  Icon(Icons.chevron_right, color: Colors.white54, size: 18.r),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void showSeriesDialog(
  BuildContext context, {
  required PlayoffSeries series,
  required int leagueId,
  required bool isPrivate,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) =>
        SeriesDialog(series: series, leagueId: leagueId, isPrivate: isPrivate),
  );
}
