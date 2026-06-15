import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/custom_assets/assets.gen.dart';
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
          AppString.todaysNbaResults.tr,
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
                /// Today's NBA Results
                _Section(
                  title: AppString.todaysNbaResults.tr,
                  icon: Assets.icons.basketBall,
                  initiallyExpanded: true,
                  children: ctrl.todaysGames.isEmpty
                      ? [_emptyState('No games today')]
                      : ctrl.todaysGames
                            .map((g) => _GameResultCard(game: g))
                            .toList(),
                ),

                SizedBox(height: 20.h),

                /// Today's Fantasy Player Scores
                _Section(
                  title: AppString.todaysFantasyPlayersScore.tr,
                  icon: Assets.icons.basketBall,
                  initiallyExpanded: true,
                  children: ctrl.playerScores.isEmpty
                      ? [_emptyState('No player scores yet')]
                      : ctrl.playerScores
                            .map((p) => _PlayerScoreCard(player: p))
                            .toList(),
                ),

                SizedBox(height: 20.h),

                /// Last 7 Days NBA Results
                _Section(
                  title: 'Last 7 Days — NBA Results',
                  icon: Assets.icons.basketBall,
                  initiallyExpanded: true,
                  children: ctrl.gamesHistory.isEmpty
                      ? [_emptyState('No recent games')]
                      : ctrl.gamesHistory
                            .map((g) => _GameResultCard(game: g, showDate: true))
                            .toList(),
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
      child: Text(msg, style: TextStyle(color: Colors.white54, fontSize: 14.sp)),
    );
  }
}

// ─── Collapsible section wrapper ─────────────────────────────────────────────

class _Section extends StatefulWidget {
  final String title;
  final AssetGenImage icon;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
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
        color: const Color(0xFF1a1a1a),
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
                  widget.icon.image(width: 29.w, height: 29.h),
                  SizedBox(width: 12.w),
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

// ─── NBA game result card ─────────────────────────────────────────────────────

class _GameResultCard extends StatelessWidget {
  final Game game;
  final bool showDate;

  const _GameResultCard({required this.game, this.showDate = false});

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

  @override
  Widget build(BuildContext context) {
    final hasScore = game.homeScore != null && game.awayScore != null;
    final homeWon = hasScore && game.homeScore! > game.awayScore!;

    return Container(
      margin: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF0a0a0a),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF2a2a2a)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDate && game.datetimeUtc.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Text(
                _formatDate(game.datetimeUtc),
                style: TextStyle(color: Colors.white38, fontSize: 11.sp),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  game.homeTeam,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (hasScore) ...[
                Text(
                  '${game.homeScore}',
                  style: TextStyle(
                    color: homeWon ? Colors.green : Colors.red,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: Text(
                    AppString.vs.tr,
                    style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                  ),
                ),
                Text(
                  '${game.awayScore}',
                  style: TextStyle(
                    color: !homeWon ? Colors.green : Colors.red,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ] else ...[
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: _statusColor()),
                  ),
                  child: Text(
                    game.status,
                    style: TextStyle(
                      color: _statusColor(),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              Expanded(
                child: Text(
                  game.awayTeam,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (hasScore)
            Padding(
              padding: EdgeInsets.only(top: 6.h),
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    game.status,
                    style: TextStyle(
                      color: _statusColor(),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

// ─── Fantasy player score card ────────────────────────────────────────────────

class _PlayerScoreCard extends StatelessWidget {
  final PlayerTodayScore player;

  const _PlayerScoreCard({required this.player});

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
        color: const Color(0xFF0a0a0a),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF2a2a2a)),
      ),
      child: Row(
        children: [
          Center(child: Assets.icons.dress.image(width: 28.w, height: 42.h)),
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
          Text(
            '${player.score}',
            style: TextStyle(
              color: _scoreColor(player.score),
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
