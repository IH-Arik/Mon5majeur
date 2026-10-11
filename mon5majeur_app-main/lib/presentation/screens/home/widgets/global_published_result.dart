import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/datetime_format.dart';
import '../../../../core/utils/lineup_positions.dart';
import '../../../../data/models/match_result_model.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';
import '../../../../data/services/global_result_cache.dart';
import 'match_lineups_field.dart';

typedef _Result = ({Map<String, dynamic>? body, String? error});

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
  bool _loading = true; // nothing at all to show yet
  bool _busy = false; // thin bar under the selector: a load is running
  String? _error;
  Map<String, dynamic>? _data;

  String? _userId; // the account the cache is bound to
  late final String _member = GlobalResultCache.memberKey(widget.userAutoId);
  int _token = 0; // bumped on every new request: older answers are not shown
  bool _revalidated = false; // offset 0 re-read once per opening
  Future<void> _prefetchChain = Future.value();

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    _userId = await GlobalResultCache.bindToCurrentUser();
    if (!mounted) return;
    _show();
  }

  /// The night [_offset] is on screen with its own data (not a previous one).
  bool get _shown =>
      _data != null && (_data!['offset'] as num?)?.toInt() == _offset;

  /// Shows the night at [_offset]: at once from the cache when known, else
  /// fetched. Offset 0 is re-read once per opening to notice a new publication.
  void _show({bool force = false}) {
    final offset = _offset;
    final token = ++_token;
    final cached = force ? null : GlobalResultCache.page(_member, offset);
    if (cached != null) {
      setState(() {
        _data = cached;
        _loading = false;
        _error = null;
      });
      if (offset == 0 && !_revalidated) {
        _revalidated = true;
        _fetchShown(offset, token);
      } else {
        setState(() => _busy = false);
        _prefetchNeighbors(token);
      }
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      if (_data == null) _loading = true;
    });
    if (offset == 0) _revalidated = true;
    _fetchShown(offset, token);
  }

  Future<void> _fetchShown(int offset, int token) async {
    final result = await _request(offset);
    if (!mounted) return;
    final body = result.body;
    var reset = false;
    if (body != null) {
      reset = GlobalResultCache.put(_userId, _member, offset, body);
    }
    if (token != _token) {
      // Another day was asked for meanwhile: not shown (cached for its date).
      if (reset) _jumpToLatest();
      return;
    }
    if (body != null) {
      setState(() {
        _data = body;
        _loading = false;
        _busy = false;
        _error = null;
      });
      if (reset) {
        _jumpToLatest();
      } else {
        _prefetchNeighbors(token);
      }
    } else {
      setState(() {
        _busy = false;
        _loading = false;
        // A failed refresh keeps what is on screen.
        if (!_shown) _error = result.error;
      });
    }
  }

  /// A new night was published: go back to the latest one, freshly read.
  void _jumpToLatest() {
    if (!mounted) return;
    _offset = 0;
    _show(force: true);
  }

  final Map<int, Future<_Result>> _running = {};

  /// One call per night at a time: asking again for a night already on its way
  /// (a prefetch the user caught up with) shares that call.
  Future<_Result> _request(int offset) {
    final running = _running[offset];
    if (running != null) return running;
    return _running[offset] = _requestNow(offset).whenComplete(() {
      _running.remove(offset);
    });
  }

  Future<_Result> _requestNow(int offset) async {
    try {
      final query = {
        'offset': '$offset',
        if (widget.userAutoId != null) 'user_auto_id': '${widget.userAutoId}',
      };
      final url = Uri.parse(
        '${ApiUrl.baseUrl}${ApiUrl.globalPublishedResult}',
      ).replace(queryParameters: query).toString();
      final response = await ApiClient().get(url: url);
      if (response.statusCode == 200 && response.body is Map) {
        return (
          body: Map<String, dynamic>.from(response.body as Map),
          error: null,
        );
      }
      return (
        body: null,
        error: 'Failed to load team (@code).'.trParams({
          'code': '${response.statusCode}',
        }),
      );
    } catch (e) {
      return (body: null, error: 'Could not load the result'.tr);
    }
  }

  /// Warms the day before and the day after the one on screen, one call at a
  /// time, silently, and stops as soon as the user moves on.
  void _prefetchNeighbors(int token) {
    final base = _offset;
    final hasOlder = _data?['has_older'] == true;
    final targets = [if (base > 0) base - 1, if (hasOlder) base + 1];
    _prefetchChain = _prefetchChain.then((_) async {
      for (final k in targets) {
        if (!mounted || token != _token) return;
        if (GlobalResultCache.page(_member, k) != null) continue;
        final result = await _request(k);
        if (!mounted || result.body == null) continue;
        if (GlobalResultCache.put(_userId, _member, k, result.body!) &&
            token == _token) {
          _jumpToLatest();
          return;
        }
      }
    });
  }

  void _go(int delta) {
    final next = _offset + delta;
    if (next < 0) return;
    setState(() => _offset = next);
    _show();
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
    if (_error != null && _data == null) {
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
    final shown = _shown;
    final available = shown && d['available'] == true;
    // Older nights are only offered once the one on screen says there is one.
    final hasOlder = shown && d['has_older'] == true;
    final hasNewer = _offset > 0;

    return RefreshIndicator(
      onRefresh: () async => _show(force: true),
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
                    color: hasOlder
                        ? const Color(0xFFB1B1B1)
                        : Colors.grey.shade800,
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
                    color: hasNewer
                        ? const Color(0xFFB1B1B1)
                        : Colors.grey.shade800,
                    size: 28.r,
                  ),
                ),
              ],
            ),
            // Discrete sign that a night is loading; the arrows stay usable.
            SizedBox(
              height: 2.h,
              child: _busy
                  ? LinearProgressIndicator(
                      color: const Color(0xFFFF6B3D),
                      backgroundColor: Colors.transparent,
                    )
                  : null,
            ),
            if (!shown) ...[
              if (_error != null) ...[
                SizedBox(height: 60.h),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14.sp),
                ),
              ],
            ] else if (!available) ...[
              SizedBox(height: 60.h),
              Icon(
                Icons.emoji_events_outlined,
                color: Colors.white38,
                size: 48.r,
              ),
              SizedBox(height: 12.h),
              Text(
                AppString.noPublishedResult.tr,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14.sp),
              ),
            ] else ...[
              Builder(
                builder: (context) {
                  final team = _toTeam(d);
                  // The score is the sum of the players' points shown on the
                  // court, so the two always agree.
                  final sum = team.selection.fold<int>(
                    0,
                    (a, p) => a + p.score,
                  );
                  return Column(
                    children: [
                      MatchLineupsField(
                        teamA: team,
                        teamB: null,
                        showOpponent: false,
                        globalResultStyle: true,
                      ),
                      SizedBox(height: 12.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Text(
                          AppString.totalPointsLabel(sum),
                          style: TextStyle(
                            color: const Color(0xFF1A1A1A),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }
}
