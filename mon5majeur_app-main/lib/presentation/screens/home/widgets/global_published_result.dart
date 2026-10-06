import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/datetime_format.dart';
import '../../../../core/utils/lineup_positions.dart';
import '../../../../data/models/match_result_model.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';
import 'match_lineups_field.dart';

/// A Global League lineup with the points it scored, for a night whose
/// results are already published (QA #9 7.1 / 7.3). It replaces the hourglass
/// view: the lineup of the night in progress never appears here (it stays in
/// "Créer une équipe" and in Live); the points are the real published ones,
/// and the arrows walk back through earlier published nights.
///
/// [userAutoId] null = my own team; otherwise another member's ("Voir
/// l'équipe"), who is only ever shown for published nights too.
class GlobalPublishedResult extends StatefulWidget {
  final int? userAutoId;
  const GlobalPublishedResult({super.key, this.userAutoId});

  @override
  State<GlobalPublishedResult> createState() => _GlobalPublishedResultState();
}

class _GlobalPublishedResultState extends State<GlobalPublishedResult> {
  int _offset = 0;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = {
        'offset': '$_offset',
        if (widget.userAutoId != null) 'user_auto_id': '${widget.userAutoId}',
      };
      final url = Uri.parse(
        '${ApiUrl.baseUrl}${ApiUrl.globalPublishedResult}',
      ).replace(queryParameters: query).toString();
      final response = await ApiClient().get(url: url);
      if (!mounted) return;
      if (response.statusCode == 200 && response.body is Map) {
        setState(() {
          _data = Map<String, dynamic>.from(response.body as Map);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load team (@code).'
              .trParams({'code': '${response.statusCode}'});
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the result'.tr;
        _loading = false;
      });
    }
  }

  void _go(int delta) {
    setState(() => _offset = (_offset + delta).clamp(0, 9999));
    _load();
  }

  PlayerScore _toTeam(Map<String, dynamic> d) {
    final items = [
      for (final e in (d['selection'] as List? ?? const []))
        PlayerSelection.fromJson(Map<String, dynamic>.from(e as Map)),
    ];
    return PlayerScore(
      playerId: 0,
      teamName: d['team_name'] ?? '',
      username: '',
      totalPoints: (d['total_points'] as num?)?.toInt() ?? 0,
      selection: inCourtOrder(items, (p) => p.position),
      teamLogo: d['team_logo'] ?? '',
      jerseyIndex: (d['jersey_index'] as num?)?.toInt() ?? 0,
      isMe: d['is_me'] ?? false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF8C42)),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14.sp),
          ),
        ),
      );
    }

    final d = _data!;
    final available = d['available'] == true;
    final hasOlder = d['has_older'] == true;
    final hasNewer = d['has_newer'] == true;

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFFFF8C42),
      backgroundColor: const Color(0xFF252838),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            // ◀ date ▶ — earlier published nights
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: hasOlder ? () => _go(1) : null,
                  icon: Icon(
                    Icons.chevron_left,
                    color: hasOlder ? const Color(0xFFB1B1B1) : Colors.grey.shade800,
                    size: 28.r,
                  ),
                ),
                Text(
                  available
                      ? formatMatchDate(d['nba_date'] as String)
                      : AppString.result.tr,
                  style: TextStyle(
                    color: const Color(0xFFB1B1B1),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                IconButton(
                  onPressed: hasNewer ? () => _go(-1) : null,
                  icon: Icon(
                    Icons.chevron_right,
                    color: hasNewer ? const Color(0xFFB1B1B1) : Colors.grey.shade800,
                    size: 28.r,
                  ),
                ),
              ],
            ),
            if (!available) ...[
              SizedBox(height: 60.h),
              Icon(Icons.emoji_events_outlined, color: Colors.white38, size: 48.r),
              SizedBox(height: 12.h),
              Text(
                AppString.noPublishedResult.tr,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14.sp),
              ),
            ] else ...[
              SizedBox(height: 8.h),
              Text(
                '${d['total_points']}',
                style: TextStyle(
                  color: const Color(0xFFFF8C42),
                  fontSize: 36.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                AppString.pts.tr,
                style: TextStyle(color: Colors.white54, fontSize: 12.sp),
              ),
              MatchLineupsField(
                teamA: _toTeam(d),
                teamB: null,
                showOpponent: false,
              ),
            ],
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }
}
