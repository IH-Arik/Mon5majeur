import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/custom_assets/assets.gen.dart';
import '../../../core/utils/datetime_format.dart';
import '../../../core/utils/score_style.dart';
import '../../../data/models/game_model.dart';
import '../../../data/models/player_today_score_model.dart';
import '../../widgets/navigation.dart';
import 'my_match_controller.dart';

class MyMatchScreen extends StatelessWidget {
  const MyMatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(MyMatchController());

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          AppString.result.tr,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Obx(() {
        if (ctrl.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFE8632C)),
          );
        }

        return RefreshIndicator(
          onRefresh: ctrl.fetchAll,
          color: const Color(0xFFE8632C),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                _Section(
                  title: AppString.todaysGames.tr,
                  initiallyExpanded: true,
                  children: ctrl.todaysGames.isEmpty
                      ? [_emptyState(AppString.noGamesToday.tr)]
                      : ctrl.todaysGames
                            .map((g) => _GameResultCard(game: g))
                            .toList(),
                ),
                SizedBox(height: 20.h),
                _Section(
                  title: AppString.todaysFantasyPlayersScore.tr,
                  initiallyExpanded: true,
                  children: ctrl.playerScores.isEmpty
                      ? [_emptyState(AppString.noPlayerScoresYet.tr)]
                      : _rankedScoreCards(ctrl.playerScores),
                ),
                SizedBox(height: 20.h),
              ],
            ),
          ),
        );
      }),
      bottomNavigationBar: const NavigationWidget(currentIndex: 1),
    );
  }

  static Widget _emptyState(String msg) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
      child: Text(
        msg,
        style: TextStyle(color: Colors.white54, fontSize: 14.sp),
      ),
    );
  }
}

/// The fantasy scores of the night as ranked rows: highest score first, ties
/// ordered by name so rows never jump between refreshes. Tied players share a
/// rank and the next rank skips the places (22, 22, 22, 21 -> 1, 1, 1, 4).
List<Widget> _rankedScoreCards(List<PlayerTodayScore> players) {
  final sorted = [...players]
    ..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  final cards = <Widget>[];
  var rank = 0;
  int? previousScore;
  for (var i = 0; i < sorted.length; i++) {
    if (sorted[i].score != previousScore) {
      rank = i + 1;
      previousScore = sorted[i].score;
    }
    cards.add(_PlayerScoreCard(player: sorted[i], rank: rank));
  }
  return cards;
}

class _Section extends StatefulWidget {
  final String title;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.initiallyExpanded,
    required this.children,
  });

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16.r),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 28.r,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...widget.children,
        ],
      ),
    );
  }
}

class _GameResultCard extends StatelessWidget {
  final Game game;

  const _GameResultCard({required this.game});

  Color _statusColor() {
    switch (game.status) {
      case 'Final':
        return Colors.blue;
      case 'Live':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  String _localizedStatus() {
    switch (game.status) {
      case 'Final':
        return AppString.matchStatusFinal.tr;
      case 'Live':
        return AppString.matchStatusLive.tr;
      case 'Not Started':
        return AppString.matchStatusNotStarted.tr;
      default:
        return game.status;
    }
  }

  // Away team on the left, home team on the right ("away @ home", like the
  // match cards of the leagues). The score colour follows the TEAM: green for
  // the one ahead, red for the one behind, white for both when level.
  Color _teamScoreColor(int own, int other) {
    if (own == other) return Colors.white;
    return own > other ? Colors.green : Colors.red;
  }

  // The name sits on the score line: a one-line name is level with the score,
  // a two-line name is centred on that same line (it grows above and below).
  Widget _teamName(String name, TextAlign align) {
    return OverflowBox(
      alignment: align == TextAlign.end
          ? Alignment.centerRight
          : Alignment.centerLeft,
      minHeight: 0,
      maxHeight: double.infinity,
      child: Text(
        name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: align,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _center() {
    final hasScore = game.homeScore != null && game.awayScore != null;
    if (hasScore) {
      final away = game.awayScore!;
      final home = game.homeScore!;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$away',
            style: TextStyle(
              color: _teamScoreColor(away, home),
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            child: Text(
              AppString.vs.tr,
              style: TextStyle(color: Colors.grey, fontSize: 11.sp),
            ),
          ),
          Text(
            '$home',
            style: TextStyle(
              color: _teamScoreColor(home, away),
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
    final time = formatGameLocalTime(game.datetimeUtc) ?? game.gameTime;
    if (time.isEmpty) {
      return Text(
        _localizedStatus(),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _statusColor(),
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.access_time, color: Colors.white70, size: 14.r),
        SizedBox(width: 4.w),
        Text(
          time,
          style: TextStyle(color: Colors.white70, fontSize: 12.sp),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      // One layout for the three states, and one height: away team, a
      // fixed-width centre column, home team. The names share what is left
      // (2 lines max) and never touch the centre.
      child: SizedBox(
        height: 48.h,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The score line: names and score share this line.
            SizedBox(
              height: 22.h,
              child: Row(
                children: [
                  Expanded(child: _teamName(game.awayTeam, TextAlign.start)),
                  SizedBox(
                    width: 104.w,
                    // At least 8 points between the score and the names.
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _center(),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: _teamName(game.homeTeam, TextAlign.end)),
                ],
              ),
            ),
            // Status under the score (room kept in every state so the score
            // line stays at the same height).
            SizedBox(
              height: 14.h,
              child: Center(
                child: game.homeScore != null && game.awayScore != null
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _StatusMark(
                          color: _statusColor(),
                          label: _localizedStatus(),
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status of a match: a dot inside a thin ring of the same colour, with a soft
/// halo, and the status text next to it (same look as the Home team status).
class _StatusMark extends StatelessWidget {
  final Color color;
  final String label;

  const _StatusMark({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12.w,
          height: 12.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.7), width: 1.w),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 5.r),
            ],
          ),
          child: Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ),
        SizedBox(width: 5.w),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PlayerScoreCard extends StatelessWidget {
  final PlayerTodayScore player;
  final int rank;

  const _PlayerScoreCard({required this.player, required this.rank});

  Color _rankColor() {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD54A);
      case 2:
        return const Color(0xFFC9D1D9);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.white;
    }
  }

  Color _scoreColor(int score) {
    if (score >= 21) return Colors.green;
    if (score >= 12) return const Color(0xFFFFD700);
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          // Rank: fixed-width column so two- and three-digit ranks never shift
          // the jerseys.
          SizedBox(
            width: 28.w,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$rank',
                style: scoreTextStyle(size: 18, color: _rankColor()),
              ),
            ),
          ),
          SizedBox(width: 6.w),
          // QA4 #10: was the wrong (Lakers #20) jersey asset.
          Center(
            child: Assets.icons.jerseyReference.image(
              width: 28.w,
              height: 42.h,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    if (player.position.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8632C),
                          borderRadius: BorderRadius.circular(9.r),
                        ),
                        child: Text(
                          player.position,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    SizedBox(width: 8.w),
                    Text(
                      player.team,
                      style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // The main figure of the row: scoreboard face, scaled down rather
          // than overflowing (three-digit score, small screen).
          Padding(
            padding: EdgeInsets.only(left: 8.w),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 60.w),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '${player.score}',
                  style: scoreTextStyle(
                    size: 22,
                    color: _scoreColor(player.score),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
