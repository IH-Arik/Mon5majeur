import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';

class _LeaderboardEntry {
  final int rank;
  final String teamName;
  final int points;

  const _LeaderboardEntry({
    required this.rank,
    required this.teamName,
    required this.points,
  });

  factory _LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return _LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      teamName: json['team_name'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
    );
  }
}

class LeaderboardTab extends StatefulWidget {
  const LeaderboardTab({super.key});

  @override
  State<LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<LeaderboardTab> {
  bool isWeekly = true; // true for Weekly, false for Monthly
  // 0 = the current week/month, 1 = the one before it, etc. — matches the
  // backend's GET /global-leagues/leaderboard/?period=&offset= (real ranked
  // GlobalLeagueDailyScore totals, not the sample data this tab used to show).
  int offset = 0;
  String searchQuery = '';

  bool _isLoading = true;
  String? _error;
  String _periodLabel = '';
  List<_LeaderboardEntry> _teams = const [];

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final period = isWeekly ? 'weekly' : 'monthly';
      final response = await ApiClient().get(
        url: '${ApiUrl.baseUrl}${ApiUrl.globalLeaderboard(period, offset)}',
        showResult: true,
      );
      if (!mounted) return;

      if (response.statusCode == 200 && response.body is Map<String, dynamic>) {
        final body = response.body as Map<String, dynamic>;
        final rawTeams = body['teams'] as List<dynamic>? ?? const [];
        setState(() {
          _periodLabel = body['period_label'] as String? ?? '';
          _teams = rawTeams
              .whereType<Map<String, dynamic>>()
              .map(_LeaderboardEntry.fromJson)
              .toList();
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _error = 'Failed to load standings (${response.statusCode}).';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load standings: $e';
        _isLoading = false;
      });
    }
  }

  void _setWeekly(bool weekly) {
    if (isWeekly == weekly) return;
    setState(() {
      isWeekly = weekly;
      offset = 0;
    });
    _fetchLeaderboard();
  }

  void _changeOffset(int delta) {
    final next = offset + delta;
    if (next < 0) return;
    setState(() => offset = next);
    _fetchLeaderboard();
  }

  List<_LeaderboardEntry> get _filteredTeams {
    if (searchQuery.isEmpty) return _teams;
    final q = searchQuery.toLowerCase();
    return _teams.where((t) => t.teamName.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          SizedBox(height: 8.h),
          Text(
            AppString.leagueStandings.tr,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16.h),
          _buildTabSelector(),
          SizedBox(height: 16.h),
          _buildPeriodSelector(),
          SizedBox(height: 16.h),
          _buildSearchBar(),
          SizedBox(height: 16.h),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: EdgeInsets.all(3.r),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3E),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _setWeekly(true),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
              decoration: BoxDecoration(
                gradient: isWeekly
                    ? const LinearGradient(
                        colors: [Color(0xFFFF6B3D), Color(0xFFFF8F6B)],
                      )
                    : null,
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: Text(
                AppString.weekly.tr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: isWeekly ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _setWeekly(false),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
              decoration: BoxDecoration(
                gradient: !isWeekly
                    ? const LinearGradient(
                        colors: [Color(0xFFFF6B3D), Color(0xFFFF8F6B)],
                      )
                    : null,
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: Text(
                AppString.monthly.tr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: !isWeekly ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () => _changeOffset(1),
          icon: Icon(Icons.chevron_left, color: Colors.white54, size: 24.r),
        ),
        SizedBox(width: 16.w),
        Text(
          _isLoading && _periodLabel.isEmpty ? '…' : _periodLabel,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: 16.w),
        IconButton(
          onPressed: offset > 0 ? () => _changeOffset(-1) : null,
          icon: Icon(Icons.chevron_right, color: Colors.white54, size: 24.r),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3E),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: TextField(
        onChanged: (value) => setState(() => searchQuery = value),
        style: TextStyle(color: Colors.white, fontSize: 14.sp),
        decoration: InputDecoration(
          hintText: AppString.searchTeamsByName.tr,
          hintStyle: TextStyle(color: Colors.white38, fontSize: 14.sp),
          border: InputBorder.none,
          icon: Icon(Icons.search, color: Colors.white38, size: 20.r),
          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Padding(
        padding: EdgeInsets.only(top: 40.h),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6B3D)),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: EdgeInsets.only(top: 40.h),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14.sp),
        ),
      );
    }
    final teams = _filteredTeams;
    if (teams.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: 40.h),
        child: Text(
          AppString.noStandingsYet.tr,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 14.sp),
        ),
      );
    }
    return Column(children: teams.map(_buildTeamRow).toList());
  }

  Widget _buildTeamRow(_LeaderboardEntry team) {
    final bool isTopOne = team.rank == 1;
    final bool isTopThree = team.rank <= 3;

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3E),
        borderRadius: BorderRadius.circular(8.r),
        border: isTopOne
            ? Border.all(color: const Color(0xFFFF6B3D), width: 1.r)
            : null,
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 24.w,
            child: Text(
              '${team.rank}',
              style: TextStyle(
                color: isTopOne ? const Color(0xFFFF6B3D) : Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          if (isTopThree)
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: Text('🔥', style: TextStyle(fontSize: 16.sp)),
            ),
          // Team icon
          Container(
            width: 24.w,
            height: 24.h,
            decoration: const BoxDecoration(
              color: Color(0xFF3A3D4E),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield, size: 14.r, color: Colors.white54),
          ),
          SizedBox(width: 12.w),

          // Team name
          Expanded(
            child: Text(
              team.teamName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // QA4 #6: the jersey reward only exists for the Monthly
          // standings (Weekly has no jersey mechanic) - showing it on
          // both tabs implied a prize that doesn't exist for Weekly.
          if (isTopOne && !isWeekly)
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: Text('👕', style: TextStyle(fontSize: 16.sp)),
            ),
          // Points
          Text(
            '${team.points}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          // "View Details" used to sit here but had no onTap at all - dead,
          // misleading UI. A weekly/monthly total has no single night's
          // lineup to show as "details" in the first place, so removed
          // rather than wired to a fake action.
          if (isTopOne) ...[
            SizedBox(width: 8.w),
            Text('🏆', style: TextStyle(fontSize: 16.sp)),
          ],
        ],
      ),
    );
  }
}
