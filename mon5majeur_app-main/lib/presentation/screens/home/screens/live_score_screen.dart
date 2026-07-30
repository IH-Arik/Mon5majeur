// lib/presentation/screens/home/screens/live_score_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../../../../data/models/live_score_model.dart';
import '../../../widgets/custom_heading.dart';
import '../controllers/live_score_controller.dart';

/// Live Score screen (spec §4.5) — shows either a single duel match (with
/// opponent + per-player breakdown on both sides) or the Global League
/// selection (no opponent, no bonuses). Premium-gated: a 403 from the
/// backend renders an upsell instead of an error.
class LiveScoreScreen extends StatefulWidget {
  final LiveScoreMode mode;
  final String? matchId;

  const LiveScoreScreen({super.key, required this.mode, this.matchId});

  @override
  State<LiveScoreScreen> createState() => _LiveScoreScreenState();
}

class _LiveScoreScreenState extends State<LiveScoreScreen> {
  late final LiveScoreController controller;
  late final String _tag;

  @override
  void initState() {
    super.initState();
    _tag = widget.mode == LiveScoreMode.duel
        ? 'live_${widget.matchId}'
        : 'live_global';
    controller = Get.put(
      LiveScoreController(mode: widget.mode, matchId: widget.matchId),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    Get.delete<LiveScoreController>(tag: _tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Column(
          children: [
            CustomHeading(
              title: AppString.liveScoreTitle.tr,
              iconAsset: Assets.icons.livescoring,
            ),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF8C42)),
                  );
                }
                if (controller.isForbidden.value) {
                  return _buildLockedState();
                }
                if (controller.errorMessage.value != null) {
                  return _buildErrorState(controller.errorMessage.value!);
                }
                return RefreshIndicator(
                  onRefresh: controller.fetch,
                  color: const Color(0xFFFF8C42),
                  backgroundColor: const Color(0xFF252838),
                  child: widget.mode == LiveScoreMode.duel
                      ? _buildDuelView(controller.matchScore.value)
                      : _buildGlobalView(controller.globalScore.value),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 64.w,
              height: 64.h,
              child: Assets.icons.lock.image(fit: BoxFit.contain),
            ),
            SizedBox(height: 20.h),
            Text(
              AppString.liveScoreLockedTitle.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              AppString.liveScoreLockedDesc.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13.sp),
            ),
            SizedBox(height: 24.h),
            GestureDetector(
              onTap: () => context.go(RoutePath.shopScreen.addBasePath),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
                decoration: ShapeDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE8632C), Color(0xFFFF8A50)],
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  AppString.unlockNow.tr,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.white54, size: 48.r),
                SizedBox(height: 16.h),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 14.sp),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStaleBanner() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: ShapeDecoration(
        color: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
          side: const BorderSide(color: Color(0xFF3A3A3A)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: Colors.white54, size: 16.r),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              AppString.staleDataNotice.tr,
              style: TextStyle(color: Colors.white54, fontSize: 11.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuelView(LiveMatchScore? match) {
    if (match == null) {
      return _buildErrorState('No live match data available');
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: 24.h),
      child: Column(
        children: [
          if (match.isStale) _buildStaleBanner(),
          SizedBox(height: 16.h),
          _buildScoreHeader(
            leftName: match.homeTeamName ?? 'Team A',
            leftScore: match.homeScore,
            rightName: match.awayTeamName ?? 'Team B',
            rightScore: match.awayScore,
            status: match.matchStatus,
          ),
          SizedBox(height: 20.h),
          _buildTeamSection(match.homeTeamName ?? 'Team A', match.homePlayers),
          SizedBox(height: 16.h),
          _buildTeamSection(match.awayTeamName ?? 'Team B', match.awayPlayers),
        ],
      ),
    );
  }

  Widget _buildGlobalView(LiveGlobalScore? score) {
    if (score == null) {
      return _buildErrorState('No live score data available');
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: 24.h),
      child: Column(
        children: [
          if (score.isStale) _buildStaleBanner(),
          SizedBox(height: 16.h),
          Text(
            score.leagueName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            score.totalScore.toStringAsFixed(0),
            style: TextStyle(
              color: const Color(0xFFFF8C42),
              fontSize: 40.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            AppString.pts.tr,
            style: TextStyle(color: Colors.white54, fontSize: 12.sp),
          ),
          SizedBox(height: 20.h),
          if (score.players.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 40.h),
              child: Text(
                AppString.noLineupSubmitted.tr,
                style: TextStyle(color: Colors.white54, fontSize: 14.sp),
              ),
            )
          else
            _buildPlayerList(score.players),
        ],
      ),
    );
  }

  Widget _buildScoreHeader({
    required String leftName,
    required double leftScore,
    required String rightName,
    required double rightScore,
    required String status,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  leftName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  leftScore.toStringAsFixed(0),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: ShapeDecoration(
                  color: status == 'live'
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.blue.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: status == 'live' ? Colors.green : Colors.blue,
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  status == 'live' ? AppString.liveLabel.tr : status.toUpperCase(),
                  style: TextStyle(
                    color: status == 'live' ? Colors.green : Colors.blue,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'VS',
                style: TextStyle(color: Colors.white54, fontSize: 12.sp),
              ),
            ],
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  rightName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  rightScore.toStringAsFixed(0),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSection(String teamName, List<LivePlayerScore> players) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(12.w),
      decoration: ShapeDecoration(
        gradient: const LinearGradient(
          begin: Alignment(0.00, 0.50),
          end: Alignment(1.00, 0.50),
          colors: [Color(0xFF20222B), Color(0xFF14151C)],
        ),
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0xFF2C2C2C)),
          borderRadius: BorderRadius.circular(8.r),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            teamName,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          if (players.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Text(
                AppString.noLineupSubmitted.tr,
                style: TextStyle(color: Colors.white38, fontSize: 12.sp),
              ),
            )
          else
            ...players.map(_buildPlayerRow),
        ],
      ),
    );
  }

  Widget _buildPlayerList(List<LivePlayerScore> players) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(12.w),
      decoration: ShapeDecoration(
        gradient: const LinearGradient(
          begin: Alignment(0.00, 0.50),
          end: Alignment(1.00, 0.50),
          colors: [Color(0xFF20222B), Color(0xFF14151C)],
        ),
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0xFF2C2C2C)),
          borderRadius: BorderRadius.circular(8.r),
        ),
      ),
      child: Column(children: players.map(_buildPlayerRow).toList()),
    );
  }

  Widget _buildPlayerRow(LivePlayerScore p) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Container(
            width: 28.w,
            height: 28.h,
            decoration: ShapeDecoration(
              color: const Color(0xFF1A1A1A),
              shape: OvalBorder(
                side: BorderSide(width: 1.w, color: const Color(0xFFB0B0B0)),
              ),
            ),
            child: Center(
              child: Text(
                p.position ?? '-',
                style: TextStyle(color: Colors.white70, fontSize: 9.sp),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.isCounted ? Colors.white : Colors.white38,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!p.isCounted)
                  Text(
                    AppString.sixthManDropped.tr,
                    style: TextStyle(color: Colors.white38, fontSize: 9.sp),
                  ),
              ],
            ),
          ),
          if (!p.isFinalized)
            Padding(
              padding: EdgeInsets.only(right: 6.w),
              child: Container(
                width: 6.r,
                height: 6.r,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: ShapeDecoration(
              color: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 1, color: Color(0xFF2C2C2C)),
                borderRadius: BorderRadius.circular(6.r),
              ),
            ),
            child: Text(
              p.fantasyScoreLive.toStringAsFixed(0),
              style: TextStyle(
                color: p.isCounted ? Colors.white : Colors.white38,
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
