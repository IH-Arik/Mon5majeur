import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../core/utils/datetime_format.dart';
import '../../../../data/models/match_result_model.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';
import '../../../widgets/match_widgets.dart';
import '../widgets/match_lineups_field.dart';

final _log = Logger();

/// One duel in detail: both teams, the result (or "Score dispo à 9h" while the
/// server withholds it from non-subscribers) and both lineups with every
/// player's fantasy score. Opened from the home card, "all my matches" and the
/// playoff series popup (QA 15/09/2026 items 4 & 8).
class MatchDetailScreen extends StatefulWidget {
  final int leagueId;
  final int matchDay;
  final bool isPrivate;
  final String? matchObjectId;

  const MatchDetailScreen({
    super.key,
    required this.leagueId,
    required this.matchDay,
    this.isPrivate = true,
    this.matchObjectId,
  });

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  bool _loading = true;
  MatchResultModel? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final endpoint = widget.isPrivate
          ? ApiUrl.privateMatchResult(widget.leagueId, widget.matchDay)
          : ApiUrl.publicMatchResult(widget.leagueId, widget.matchDay);
      final response = await ApiClient().get(
        url: '${ApiUrl.baseUrl}$endpoint',
        showResult: false,
      );
      if (response.statusCode == 200) {
        _result = MatchResultModel.fromJson(response.body);
      }
    } catch (e) {
      _log.e('Match detail load failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  MatchPair? get _pair {
    final r = _result;
    if (r == null || r.pairs.isEmpty) return null;
    final id = widget.matchObjectId;
    if (id != null) {
      final hit = r.pairs.where((p) => p.matchObjectId == id);
      if (hit.isNotEmpty) return hit.first;
    }
    return r.pairs.first;
  }

  PlayerScore? _scoreOf(int playerId) {
    return _result?.playerScores.firstWhereOrNull((s) => s.playerId == playerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: SizedBox(
                      width: 30.w,
                      height: 30.h,
                      child: Assets.icons.backButton.image(fit: BoxFit.contain),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      AppString.matchDetailTitle.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 30.w),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF8C42)),
      );
    }
    final result = _result;
    final pair = _pair;
    if (result == null || pair == null) {
      return Center(
        child: Text(
          AppString.noMatchesToday.tr,
          style: TextStyle(color: Colors.white54, fontSize: 14.sp),
        ),
      );
    }
    final a = _scoreOf(pair.playerAId);
    final b = _scoreOf(pair.playerBId);
    final hidden = result.scoresHidden;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  result.leagueName,
                  softWrap: true,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              MatchStatusBadge(
                status: result.status == 'scheduled' ? 'upcoming' : result.status,
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${formatMatchdayLabel(result.matchDay)} • ${formatMatchDate(result.matchDate)}',
              style: TextStyle(color: const Color(0xFFAAAAAA), fontSize: 12.sp),
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a1a),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFF333333)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    pair.playerAName,
                    softWrap: true,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: hidden
                      ? const ScoreLockedLabel()
                      : (result.status == 'scheduled'
                            ? Text(
                                AppString.vs.tr,
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14.sp,
                                ),
                              )
                            : ScoreLine(
                                scoreA: pair.scoreA,
                                scoreB: pair.scoreB,
                                size: 34,
                              )),
                ),
                Expanded(
                  child: Text(
                    pair.playerBName,
                    textAlign: TextAlign.right,
                    softWrap: true,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          MatchLineupsField(teamA: a, teamB: b, scoresHidden: hidden),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }
}
