import '../../../../core/utils/logo_assets.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/datetime_format.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';
import '../screens/global_team_detail_screen.dart';

class _LeaderboardEntry {
  final int rank;
  final int userAutoId;
  final String teamName;
  final int points;
  final String teamLogo;

  const _LeaderboardEntry({
    required this.rank,
    required this.userAutoId,
    required this.teamName,
    required this.points,
    this.teamLogo = '',
  });

  factory _LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return _LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      userAutoId: (json['user_id'] as num?)?.toInt() ?? 0,
      teamName: json['team_name'] as String? ?? '',
      points: (json['points'] as num?)?.toInt() ?? 0,
      teamLogo: json['team_logo'] as String? ?? '',
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
  int? _weekNumber;
  int? _monthNumber;
  int _year = 0;
  List<_LeaderboardEntry> _teams = const [];

  String get _periodLabel {
    if (_weekNumber != null) return formatWeekLabel(_weekNumber!);
    if (_monthNumber != null) return formatMonthLabel(_monthNumber!, _year);
    return '';
  }

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  // A ranking already shown (or prefetched) comes back at once, without a
  // spinner or a request: finished periods never change and the server
  // computes the current ones once per publication (QA #10 12).
  final Map<String, Map<String, dynamic>> _cache = {};
  final Set<String> _inFlight = {};

  String _key(bool weekly, int off) => '${weekly ? 'weekly' : 'monthly'}:$off';

  Future<Map<String, dynamic>?> _request(bool weekly, int off) async {
    try {
      final response = await ApiClient().get(
        url: '${ApiUrl.baseUrl}${ApiUrl.globalLeaderboard(weekly ? 'weekly' : 'monthly', off)}',
      );
      if (response.statusCode == 200 && response.body is Map<String, dynamic>) {
        return response.body as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  void _apply(Map<String, dynamic> body) {
    final rawTeams = body['teams'] as List<dynamic>? ?? const [];
    _weekNumber = (body['week_number'] as num?)?.toInt();
    _monthNumber = (body['month_number'] as num?)?.toInt();
    _year = (body['year'] as num?)?.toInt() ?? 0;
    _teams = rawTeams
        .whereType<Map<String, dynamic>>()
        .map(_LeaderboardEntry.fromJson)
        .toList();
  }

  void _prefetch(bool weekly, int off) {
    final k = _key(weekly, off);
    if (off < 0 || _cache.containsKey(k) || !_inFlight.add(k)) return;
    _request(weekly, off).then((body) {
      _inFlight.remove(k);
      if (body != null) _cache[k] = body;
    });
  }

  void _prefetchAround() {
    // the neighbours of what is shown, and the current week and month
    _prefetch(isWeekly, offset + 1);
    _prefetch(isWeekly, offset - 1);
    _prefetch(true, 0);
    _prefetch(false, 0);
  }

  Future<void> _fetchLeaderboard() async {
    final k = _key(isWeekly, offset);
    final cached = _cache[k];
    if (cached != null) {
      setState(() {
        _apply(cached);
        _isLoading = false;
        _error = null;
      });
      _prefetchAround();
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final weekly = isWeekly, off = offset;
    final body = await _request(weekly, off);
    if (!mounted || weekly != isWeekly || off != offset) return;
    if (body == null) {
      setState(() {
        _error = 'Failed to load standings'.tr;
        _isLoading = false;
      });
      return;
    }
    _cache[k] = body;
    setState(() {
      _apply(body);
      _isLoading = false;
    });
    _prefetchAround();
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
          // The team's own saved avatar (QA #9 11.2: a grey shield for all).
          Container(
            width: 26.w,
            height: 26.w,
            padding: EdgeInsets.all(3.r),
            decoration: const BoxDecoration(
              color: Color(0xFF3A3D4E),
              shape: BoxShape.circle,
            ),
            child: logoAsset(team.teamLogo).image(fit: BoxFit.contain),
          ),
          SizedBox(width: 12.w),

          // Team name
          Expanded(
            child: Text(
              team.teamName,
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
          SizedBox(width: 12.w),
          // QA5 #4: restored, now wired to the player's actual last-played
          // lineup + score (not a fake action like the removed version -
          // see global_team_detail_screen.dart) rather than tonight's
          // in-progress selection.
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GlobalTeamDetailScreen(
                  userAutoId: team.userAutoId,
                  teamName: team.teamName,
                ),
              ),
            ),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xFF3A3D4E),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                AppString.viewTeam.tr,
                style: TextStyle(color: Colors.white70, fontSize: 10.sp),
              ),
            ),
          ),
          if (isTopOne) ...[
            SizedBox(width: 8.w),
            Text('🏆', style: TextStyle(fontSize: 16.sp)),
          ],
        ],
      ),
    );
  }
}
