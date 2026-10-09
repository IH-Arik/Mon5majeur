import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/custom_assets/assets.gen.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/api_url.dart';
import '../../widgets/navigation.dart';
import 'player_info.dart';

// Player Model - Updated to match API response
class Player {
  final String? id;
  final String name;
  final String position;
  final int? avg; // null until the player has played a game this season
  final double price;
  final String team;
  final String? teamId;
  final String? status;

  Player({
    this.id,
    required this.name,
    required this.position,
    this.avg,
    required this.price,
    required this.team,
    this.teamId,
    this.status,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    // Parse price from string format "19M" or "14.2M" to double
    double parsedPrice = 0.0;
    if (json['price'] != null) {
      String priceStr = json['price'].toString().replaceAll('M', '').trim();
      parsedPrice = double.tryParse(priceStr) ?? 0.0;
    }

    return Player(
      id: json['id']?.toString(),
      name: json['name'] ?? '',
      position: json['position'] ?? '',
      avg: (json['avg'] as num?)?.round(),
      price: parsedPrice,
      team: json['team'] ?? '',
      teamId: json['team_id']?.toString(),
      status: json['status'],
    );
  }
}

// All 30 franchises: the team filter must list every team, not only the ones
// playing tonight (QA #9 4.2).
const _nbaTeams = [
  'Atlanta Hawks', 'Boston Celtics', 'Brooklyn Nets', 'Charlotte Hornets',
  'Chicago Bulls', 'Cleveland Cavaliers', 'Dallas Mavericks', 'Denver Nuggets',
  'Detroit Pistons', 'Golden State Warriors', 'Houston Rockets',
  'Indiana Pacers', 'LA Clippers', 'Los Angeles Lakers', 'Memphis Grizzlies',
  'Miami Heat', 'Milwaukee Bucks', 'Minnesota Timberwolves',
  'New Orleans Pelicans', 'New York Knicks', 'Oklahoma City Thunder',
  'Orlando Magic', 'Philadelphia 76ers', 'Phoenix Suns',
  'Portland Trail Blazers', 'Sacramento Kings', 'San Antonio Spurs',
  'Toronto Raptors', 'Utah Jazz', 'Washington Wizards',
];

enum _SortColumn { avg, price }

enum _PositionGroup { centers, forwards, guards, all }

// Position groups of the header (a hybrid can sit in two groups on purpose).
const _centersPositions = ['C', 'C-F', 'F-C'];
const _forwardsPositions = ['SF', 'PF', 'F', 'G-F', 'F-G', 'F-C', 'C-F'];
const _guardsPositions = ['PG', 'SG', 'G', 'G-F', 'F-G'];

/// Positions compared without case or spaces ("g-f " == "G-F").
String _normPosition(String position) =>
    position.replaceAll(RegExp(r'\s+'), '').toUpperCase();

List<String> _positionsOf(_PositionGroup group) => switch (group) {
  _PositionGroup.centers => _centersPositions,
  _PositionGroup.forwards => _forwardsPositions,
  _PositionGroup.guards => _guardsPositions,
  _PositionGroup.all => const [],
};

/// EU summer time (Paris is UTC+2 from the last Sunday of March 01:00 UTC to
/// the last Sunday of October 01:00 UTC, UTC+1 otherwise).
bool _isParisSummer(DateTime utc) {
  DateTime lastSunday(int month) {
    var d = DateTime.utc(utc.year, month + 1, 0, 1); // last day of [month]
    while (d.weekday != DateTime.sunday) {
      d = d.subtract(const Duration(days: 1));
    }
    return d;
  }

  return !utc.isBefore(lastSunday(3)) && utc.isBefore(lastSunday(10));
}

/// The latest 09:00 Paris (the daily publication) at or before [refUtc].
DateTime _lastParisPublication(DateTime refUtc) {
  final paris = refUtc.add(Duration(hours: _isParisSummer(refUtc) ? 2 : 1));
  var day = DateTime.utc(paris.year, paris.month, paris.day, 9);
  if (day.isAfter(paris)) day = day.subtract(const Duration(days: 1));
  return day.subtract(Duration(hours: _isParisSummer(day) ? 2 : 1));
}

/// When a player list fetched at [fetchedUtc] stops being valid: at the next
/// 09:00 Paris publication. A list fetched in the first 15 minutes after a
/// publication (the data may not be fully updated yet) is only kept 15 minutes.
@visibleForTesting
DateTime playersCacheExpiry(DateTime fetchedUtc) {
  final lastPublication = _lastParisPublication(fetchedUtc);
  final next = _lastParisPublication(
    lastPublication.add(const Duration(hours: 36)),
  );
  final grace = lastPublication.add(const Duration(minutes: 15));
  if (fetchedUtc.isBefore(grace)) {
    final soon = fetchedUtc.add(const Duration(minutes: 15));
    return soon.isBefore(next) ? soon : next;
  }
  return next;
}

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  // In-memory cache of the complete player list, kept for the app session.
  // Only a COMPLETE list is ever stored; the refresh button replaces it.
  static List<Player>? _cachePlayers;
  static int _cacheTotal = 0;
  static DateTime? _cacheExpiresAt;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiClient _apiClient = ApiClient();

  bool _showFilterMenu = false;
  String _searchQuery = '';

  // Filter states
  RangeValues _priceRange = RangeValues(0.w, 100.w);
  final Set<String> _selectedPositions = {};
  final Set<String> _selectedTeams = {};
  // Default: best average first. Tapping a header changes column / direction.
  _SortColumn _sortColumn = _SortColumn.avg;
  bool _sortAscending = false;

  // API states
  List<Player> _allPlayers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _totalPlayers = 0;
  String? _nextPageUrl;
  bool _hasMorePages = false;

  // Available positions and teams from API
  final Set<String> _availablePositions = {};
  final Set<String> _availableTeams = {..._nbaTeams};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _scrollController.addListener(_onScroll);
    if (_cacheIsValid) {
      _restoreFromCache();
    } else {
      _fetchPlayers();
    }
  }

  bool get _cacheIsValid =>
      _cachePlayers != null &&
      _cacheExpiresAt != null &&
      DateTime.now().toUtc().isBefore(_cacheExpiresAt!);

  void _restoreFromCache() {
    _allPlayers = List<Player>.of(_cachePlayers!);
    _totalPlayers = _cacheTotal;
    _nextPageUrl = null;
    _hasMorePages = false;
    _isLoading = false;
    for (final player in _allPlayers) {
      _availablePositions.add(player.position);
      _availableTeams.add(player.team);
    }
  }

  void _storeCache() {
    if (_allPlayers.isEmpty) return;
    _cachePlayers = List<Player>.of(_allPlayers);
    _cacheTotal = _totalPlayers;
    _cacheExpiresAt = playersCacheExpiry(DateTime.now().toUtc());
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200.h &&
        !_isLoadingMore &&
        _hasMorePages) {
      _loadMorePlayers();
    }
  }

  Future<void> _fetchPlayers({bool refresh = false}) async {
    try {
      if (refresh) {
        _cachePlayers = null; // the refresh button always replaces the cache
        setState(() {
          _isLoading = true;
          _allPlayers.clear();
          _errorMessage = null;
        });
      } else {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      // all=true: the complete player database, not only tonight's teams
      // (QA #9 4.1).
      final url = '${ApiUrl.baseUrl}/api/players-today/?all=true';

      final response = await _apiClient.get(url: url, showResult: true);

      if (response.statusCode == 200 && response.body != null) {
        final data = response.body as Map<String, dynamic>;

        _totalPlayers = data['count'] ?? 0;
        _nextPageUrl = data['next'];
        _hasMorePages = _nextPageUrl != null;

        final results = data['results'] as List<dynamic>?;
        if (results != null) {
          final players = results
              .map((json) => Player.fromJson(json as Map<String, dynamic>))
              .toList();

          // Extract unique positions and teams
          for (var player in players) {
            _availablePositions.add(player.position);
            _availableTeams.add(player.team);
          }

          setState(() {
            _allPlayers = players;
            _isLoading = false;
          });
          // Sorting, search and filters must cover EVERY player, not only the
          // first page on screen (QA #9 4.2): fetch the other pages now.
          _loadAllRemaining();
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load players. Please try again.'.tr;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading players: @e'.trParams({'e': e.toString()});
        _isLoading = false;
      });
      debugPrint('Error fetching players: $e');
    }
  }

  Future<void> _loadAllRemaining() async {
    final firstNext = _nextPageUrl;
    if (firstNext == null) {
      _storeCache();
      return;
    }
    final pageSize = _allPlayers.length;
    final nextUri = Uri.tryParse(firstNext);
    final firstNo = int.tryParse(nextUri?.queryParameters['page'] ?? '');
    if (nextUri == null || firstNo == null || pageSize == 0) {
      await _loadRemainingSequentially(); // cannot work the pages out
      return;
    }
    final lastNo = (_totalPlayers + pageSize - 1) ~/ pageSize;
    if (lastNo < firstNo) {
      await _loadRemainingSequentially();
      return;
    }
    final urls = <String>[
      for (var n = firstNo; n <= lastNo; n++)
        nextUri
            .replace(queryParameters: {...nextUri.queryParameters, 'page': '$n'})
            .toString(),
    ];

    // Pages 2..N are requested together. They are added to the list in page
    // order whatever order they arrive in, so the result is the same as with
    // sequential loading.
    setState(() => _isLoadingMore = true);
    final bodies = List<Map<String, dynamic>?>.filled(urls.length, null);
    final finished = List<bool>.filled(urls.length, false);
    var flushed = 0;
    int? failedAt;

    void flush() {
      while (mounted &&
          failedAt == null &&
          flushed < urls.length &&
          finished[flushed]) {
        final body = bodies[flushed];
        if (body == null) {
          failedAt = flushed;
          return;
        }
        final players = (body['results'] as List<dynamic>? ?? [])
            .map((json) => Player.fromJson(json as Map<String, dynamic>))
            .toList();
        for (final player in players) {
          _availablePositions.add(player.position);
          _availableTeams.add(player.team);
        }
        setState(() => _allPlayers.addAll(players));
        flushed++;
      }
    }

    Future<void> fetchOne(int i) async {
      // One retry: a page that fails twice is reported, never skipped.
      for (var attempt = 0; attempt < 2 && bodies[i] == null; attempt++) {
        try {
          final response = await _apiClient.get(url: urls[i], showResult: true);
          if (response.statusCode == 200 && response.body is Map) {
            bodies[i] = Map<String, dynamic>.from(response.body as Map);
          }
        } catch (e) {
          debugPrint('Error loading page ${i + firstNo}: $e');
        }
      }
      finished[i] = true;
      flush();
    }

    await Future.wait([for (var i = 0; i < urls.length; i++) fetchOne(i)]);
    if (!mounted) return;

    if (failedAt != null) {
      // Show what we have, exactly as when a page used to fail: the counter
      // and the "load more" row stay, and the list continues from the page
      // that failed. Nothing incomplete is cached.
      setState(() {
        _nextPageUrl = urls[failedAt!];
        _hasMorePages = true;
        _isLoadingMore = false;
      });
      return;
    }

    final lastBody = bodies.last!;
    setState(() {
      _totalPlayers = lastBody['count'] ?? _totalPlayers;
      _nextPageUrl = lastBody['next'];
      _hasMorePages = _nextPageUrl != null;
      _isLoadingMore = false;
    });
    if (_hasMorePages) {
      await _loadRemainingSequentially(); // the total had grown meanwhile
    } else {
      _storeCache();
    }
  }

  Future<void> _loadRemainingSequentially() async {
    while (mounted && _hasMorePages && _nextPageUrl != null) {
      final before = _allPlayers.length;
      await _loadMorePlayers();
      if (_allPlayers.length == before) break; // a page failed: stop, no loop
    }
  }

  Future<void> _loadMorePlayers() async {
    if (_isLoadingMore || !_hasMorePages || _nextPageUrl == null) return;

    try {
      setState(() {
        _isLoadingMore = true;
      });

      final response = await _apiClient.get(
        url: _nextPageUrl!,
        showResult: true,
      );

      if (response.statusCode == 200 && response.body != null) {
        final data = response.body as Map<String, dynamic>;

        _totalPlayers = data['count'] ?? 0;
        _nextPageUrl = data['next'];
        _hasMorePages = _nextPageUrl != null;

        final results = data['results'] as List<dynamic>?;
        if (results != null) {
          final players = results
              .map((json) => Player.fromJson(json as Map<String, dynamic>))
              .toList();

          // Extract unique positions and teams
          for (var player in players) {
            _availablePositions.add(player.position);
            _availableTeams.add(player.team);
          }

          setState(() {
            _allPlayers.addAll(players);
            _isLoadingMore = false;
          });
          if (!_hasMorePages) _storeCache(); // the list is now complete
        }
      } else {
        setState(() {
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      debugPrint('Error loading more players: $e');
    }
  }

  List<Player> get _filteredPlayers {
    final selectedPositions = _selectedPositions.map(_normPosition).toSet();
    List<Player> filtered = _allPlayers.where((player) {
      // Search filter
      final matchesSearch = player.name.toLowerCase().contains(_searchQuery);

      // Position filter
      final matchesPosition =
          selectedPositions.isEmpty ||
          selectedPositions.contains(_normPosition(player.position));

      // Team filter
      final matchesTeam =
          _selectedTeams.isEmpty || _selectedTeams.contains(player.team);

      // Price range filter
      final matchesPrice =
          player.price >= _priceRange.start && player.price <= _priceRange.end;

      return matchesSearch && matchesPosition && matchesTeam && matchesPrice;
    }).toList();

    // Sort by the chosen column; ties always fall back to name then id so the
    // list never jumps between two sorts.
    filtered.sort((a, b) {
      final int byKey;
      if (_sortColumn == _SortColumn.price) {
        byKey = a.price.compareTo(b.price);
      } else {
        // no game yet: below everyone
        byKey = (a.avg ?? -1).compareTo(b.avg ?? -1);
      }
      if (byKey != 0) return _sortAscending ? byKey : -byKey;
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (byName != 0) return byName;
      return (a.id ?? '').compareTo(b.id ?? '');
    });

    return filtered;
  }

  /// The header group the position selection currently matches (null = a
  /// custom choice made in the filter panel).
  _PositionGroup? get _activePositionGroup {
    final selected = _selectedPositions.map(_normPosition).toSet();
    for (final group in _PositionGroup.values) {
      final wanted = _positionsOf(group).map(_normPosition).toSet();
      if (selected.length == wanted.length && selected.containsAll(wanted)) {
        return group;
      }
    }
    return null;
  }

  String _positionGroupLabel(_PositionGroup group) => switch (group) {
    _PositionGroup.centers => AppString.positionGroupCenters.tr,
    _PositionGroup.forwards => AppString.positionGroupForwards.tr,
    _PositionGroup.guards => AppString.positionGroupGuards.tr,
    _PositionGroup.all => AppString.positionGroupAll.tr,
  };

  /// Position header: centers -> forwards -> guards -> all -> centers. After a
  /// manual choice in the filter panel the cycle restarts from the centers.
  void _cyclePositionGroup() {
    final next = switch (_activePositionGroup) {
      _PositionGroup.centers => _PositionGroup.forwards,
      _PositionGroup.forwards => _PositionGroup.guards,
      _PositionGroup.guards => _PositionGroup.all,
      _PositionGroup.all || null => _PositionGroup.centers,
    };
    setState(() {
      _selectedPositions
        ..clear()
        ..addAll(_positionsOf(next));
    });
  }

  /// Moy / Prix header: a tap on the sorted column flips its direction, a tap
  /// on the other column sorts it from the highest.
  void _onSortHeaderTap(_SortColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = false;
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _priceRange = RangeValues(0.w, 100.w);
      _selectedPositions.clear();
      _selectedTeams.clear();
      _sortColumn = _SortColumn.avg;
      _sortAscending = false;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredPlayers = _filteredPlayers;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          AppString.dataTitle.tr,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white, size: 24.r),
              onPressed: () => _fetchPlayers(refresh: true),
            ),
        ],
      ),
      body: Column(
        children: [
          /// Search Bar with Filter Button
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a1a),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Icon(
                      Icons.search,
                      color: Colors.grey,
                      size: 24.r,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                      ),
                      decoration: InputDecoration(
                        hintText: AppString.searchPlayersHint.tr,
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 14.sp,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        _searchController.clear();
                      },
                      icon: Icon(
                        Icons.clear,
                        color: Colors.grey,
                        size: 20.r,
                      ),
                    ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showFilterMenu = !_showFilterMenu;
                      });
                    },
                    icon: Icon(
                      Icons.tune,
                      color: _showFilterMenu
                          ? const Color(0xFFFF6B35)
                          : Colors.white,
                      size: 24.r,
                    ),
                  ),
                  // Same action as the filter icon, with a 44-point touch area.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() {
                      _showFilterMenu = !_showFilterMenu;
                    }),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        _showFilterMenu
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 24.r,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                ],
              ),
            ),
          ),

          // Everything under the search bar: the list, and the filter panel
          // opened over it (never over the search bar itself).
          Expanded(
            child: Stack(
              children: [
                Column(
                  children: [
                  /// Player count indicator
                  if (!_isLoading)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Row(
                        children: [
                          Text(
                            'Loaded: @n / @m players'.trParams({'n': '${_allPlayers.length}', 'm': '$_totalPlayers'}),
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12.sp,
                            ),
                          ),
                          if (_hasMorePages)
                            Text(
                              ' • Scroll for more'.tr,
                              style: TextStyle(
                                color: Color(0xFFFF6B35),
                                fontSize: 12.sp,
                              ),
                            ),
                        ],
                      ),
                    ),

                  /// Active Filters Display. A position group chosen with the
                  /// Poste header is already shown under that header, so it
                  /// does not open this strip (the list would jump down).
                  if ((_selectedPositions.isNotEmpty &&
                          _activePositionGroup == null) ||
                      _selectedTeams.isNotEmpty ||
                      _priceRange.start > 0 ||
                      _priceRange.end < 100.w)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      child: Row(
                        children: [
                          Text(
                            AppString.filtersLabel.tr,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12.sp,
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ..._selectedPositions.map(
                                    (pos) => _buildFilterChip(pos),
                                  ),
                                  ..._selectedTeams.map(
                                    (team) => _buildFilterChip(team),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _clearFilters,
                            child: Text(
                              AppString.clearAll.tr,
                              style: TextStyle(
                                color: Color(0xFFFF6B35),
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: 8.h),

                  /// Table Header (Poste cycles the position groups, Moy and
                  /// Prix sort). Same inset and same column widths as a player
                  /// row (see _playerColumns), so every title sits over its column.
                  if (!_isLoading)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: _rowInset),
                      child: _playerColumns(
                        name: _headerCell(
                          Alignment.centerLeft,
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              AppString.playerName.tr,
                              style: _headerStyle(Colors.grey),
                            ),
                          ),
                        ),
                        position: _headerCell(
                          Alignment.center,
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _cyclePositionGroup,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    AppString.position.tr,
                                    style: _headerStyle(Colors.grey),
                                  ),
                                ),
                                // The active group (nothing for a custom
                                // choice made in the filter panel). The slot
                                // is always there, so the list never moves.
                                SizedBox(
                                  height: 14.sp,
                                  child: _activePositionGroup == null
                                      ? null
                                      : FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            _positionGroupLabel(
                                              _activePositionGroup!,
                                            ),
                                            style: TextStyle(
                                              color: const Color(0xFFFF6B35),
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        avg: _sortHeader(
                          AppString.avg.tr,
                          _SortColumn.avg,
                          arrowOnRight: true,
                        ),
                        price: _sortHeader(
                          AppString.price.tr,
                          _SortColumn.price,
                          arrowOnRight: false,
                        ),
                      ),
                    ),

                  SizedBox(height: 8.h),

                  /// Player List
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: Color(0xFFFF6B35),
                                  strokeWidth: 4.w,
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  'Loading players...'.tr,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 64.r,
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 14.sp,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 16.h),
                                ElevatedButton(
                                  onPressed: () => _fetchPlayers(refresh: true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFFFF6B35),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 24.w,
                                      vertical: 12.h,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                  ),
                                  child: Text(
                                    'Retry'.tr,
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : filteredPlayers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  color: Colors.grey,
                                  size: 64.r,
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? '${AppString.noPlayersFoundFor.tr} "$_searchQuery"'
                                      : AppString.noPlayersMatchFilters.tr,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16.sp,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.symmetric(horizontal: 16.w),
                            itemCount: filteredPlayers.length + 1,
                            itemBuilder: (context, index) {
                              if (index == filteredPlayers.length) {
                                // Loading indicator at the bottom
                                if (_isLoadingMore) {
                                  return Padding(
                                    padding: EdgeInsets.all(16.w),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFFFF6B35),
                                        strokeWidth: 4.w,
                                      ),
                                    ),
                                  );
                                } else if (_hasMorePages) {
                                  return Padding(
                                    padding: EdgeInsets.all(16.w),
                                    child: Center(
                                      child: TextButton(
                                        onPressed: _loadMorePlayers,
                                        child: Text(
                                          'Load More'.tr,
                                          style: TextStyle(
                                            color: Color(0xFFFF6B35),
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                } else {
                                  return SizedBox.shrink();
                                }
                              }

                              final player = filteredPlayers[index];
                              return _buildPlayerCard(
                                player.id,
                                player.name,
                                player.position,
                                player.avg,
                                '${player.price.toStringAsFixed(1)}M',
                                player.team,
                              );
                            },
                          ),
                  ),
                  ],
                ),

                /// Tap outside the panel closes it (the list stays scrollable
                /// underneath, and taps on a player row only close the panel).
                if (_showFilterMenu)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => setState(() => _showFilterMenu = false),
                    ),
                  ),

                /// Filter Menu Overlay
              if (_showFilterMenu)
                Positioned(
                  top: 4.h,
                  bottom: 12.h,
                  right: 16.w,
                  child: Container(
                    width: 250.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a1a1a),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: const Color(0xFF333333)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 10.r,
                          offset: Offset(0, 5.h),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          /// Price Range
                          Padding(
                            padding: EdgeInsets.all(16.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppString.priceRange.tr,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${AppString.min.tr} ${_priceRange.start.toInt()}M',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12.sp,
                                      ),
                                    ),
                                    Text(
                                      '${AppString.max.tr} ${_priceRange.end.toInt()}M',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12.sp,
                                      ),
                                    ),
                                  ],
                                ),
                                SliderTheme(
                                  data: SliderThemeData(
                                    activeTrackColor: Color(0xFFFF6B35),
                                    inactiveTrackColor: Color(0xFF333333),
                                    thumbColor: Color(0xFFFF6B35),
                                    overlayColor: Color(0x33FF6B35),
                                    trackHeight: 4.h,
                                    thumbShape: RoundSliderThumbShape(
                                      enabledThumbRadius: 12.r,
                                    ),
                                    overlayShape: RoundSliderOverlayShape(
                                      overlayRadius: 20.r,
                                    ),
                                  ),
                                  child: RangeSlider(
                                    values: _priceRange,
                                    min: 0.w,
                                    max: 100.w,
                                    onChanged: (values) {
                                      setState(() {
                                        _priceRange = values;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Divider(color: Color(0xFF333333), height: 1.h),

                          /// Avg Point Scored Sorting
                          Padding(
                            padding: EdgeInsets.all(16.w),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppString.avgPointScored.tr,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _sortColumn = _SortColumn.avg;
                                            _sortAscending = true;
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _sortAscending
                                                ? Color(0xFFFF6B35)
                                                : Color(0xFF2a2a2a),
                                            borderRadius: BorderRadius.circular(
                                              8.r,
                                            ),
                                          ),
                                          child: Text(
                                            AppString.minToMax.tr,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: _sortAscending
                                                  ? Colors.white
                                                  : Colors.grey,
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _sortColumn = _SortColumn.avg;
                                            _sortAscending = false;
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: !_sortAscending
                                                ? Color(0xFFFF6B35)
                                                : Color(0xFF2a2a2a),
                                            borderRadius: BorderRadius.circular(
                                              8.r,
                                            ),
                                          ),
                                          child: Text(
                                            AppString.maxToMin.tr,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: !_sortAscending
                                                  ? Colors.white
                                                  : Colors.grey,
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          Divider(color: Color(0xFF333333), height: 1.h),

                          /// Position
                          if (_availablePositions.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.all(16.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppString.position.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  Wrap(
                                    spacing: 8.w,
                                    runSpacing: 8.h,
                                    children: _availablePositions.map((position) {
                                      final isSelected = _selectedPositions
                                          .contains(position);
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedPositions.remove(position);
                                            } else {
                                              _selectedPositions.add(position);
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16.w,
                                            vertical: 8.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Color(0xFFFF6B35)
                                                : Color(0xFF2a2a2a),
                                            borderRadius: BorderRadius.circular(
                                              8.r,
                                            ),
                                          ),
                                          child: Text(
                                            position,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.grey,
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),

                          Divider(color: Color(0xFF333333), height: 1.h),

                          /// Team
                          if (_availableTeams.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.all(16.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppString.team.tr,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  Wrap(
                                    spacing: 8.w,
                                    runSpacing: 8.h,
                                    children: _availableTeams.toList().map((team) {
                                      final isSelected = _selectedTeams.contains(
                                        team,
                                      );
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedTeams.remove(team);
                                            } else {
                                              _selectedTeams.add(team);
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12.w,
                                            vertical: 8.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Color(0xFFFF6B35)
                                                : Color(0xFF2a2a2a),
                                            borderRadius: BorderRadius.circular(
                                              8.r,
                                            ),
                                          ),
                                          child: Text(
                                            team,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.grey,
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          // room under the last option
                          SizedBox(height: 32.h),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const NavigationWidget(currentIndex: 2),
    );
  }

  /// A sortable column title: the sorted column shows an arrow for its
  /// direction (up = lowest first, down = highest first). The arrow is drawn
  /// beside the title without taking any room, so the title never moves
  /// whether its column is the sorted one or not. [arrowOnRight] puts it after
  /// the title (centred column); otherwise before it (right-aligned column).
  Widget _sortHeader(
    String label,
    _SortColumn column, {
    required bool arrowOnRight,
  }) {
    final active = _sortColumn == column;
    final arrowSize = 12.r;
    final arrow = Icon(
      _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
      color: const Color(0xFFFF6B35),
      size: arrowSize,
    );
    final title = Text(
      label,
      style: _headerStyle(active ? Colors.white : Colors.grey),
    );
    return _headerCell(
      arrowOnRight ? Alignment.center : Alignment.centerRight,
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onSortHeaderTap(column),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: arrowOnRight ? Alignment.center : Alignment.centerRight,
          // Only the title takes room; the arrow hangs outside its box.
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              title,
              if (active)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: arrowOnRight ? null : -(arrowSize + 2),
                  right: arrowOnRight ? -(arrowSize + 2) : null,
                  child: Center(child: arrow),
                ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _headerStyle(Color color) => TextStyle(
    color: color,
    fontSize: 14.sp,
    fontWeight: FontWeight.w600,
  );

  /// A header cell: at least 44 points tall, content aligned in its column.
  Widget _headerCell(Alignment alignment, Widget child) => SizedBox(
    height: 44,
    child: Align(alignment: alignment, child: child),
  );

  // ---- Column layout shared by the header and every player row ----------
  // List padding + card border + card padding: the space left of the first
  // column, on both sides.
  double get _rowInset => 16.w + 1 + 12.w;
  // Jersey (28) + gap (12): the name column starts after it.
  double get _jerseyZone => 28.w + 12.w;
  double get _positionWidth => 66.w;
  double get _avgWidth => 52.w;
  double get _priceWidth => 62.w;

  /// The four columns of the player table (name takes what is left). Used by
  /// the header and by each row so both always have the same widths.
  Widget _playerColumns({
    Widget? leading,
    required Widget name,
    required Widget position,
    required Widget avg,
    required Widget price,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: _jerseyZone, child: leading),
        Expanded(child: name),
        SizedBox(width: _positionWidth, child: position),
        SizedBox(width: _avgWidth, child: avg),
        SizedBox(width: _priceWidth, child: price),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    return Container(
      margin: EdgeInsets.only(right: 8.w),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Color(0xFFFF6B35),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPlayerCard(
    String? id,
    String name,
    String position,
    int? avg,
    String price,
    String team,
  ) {
    return GestureDetector(
      onTap: () {
        // While the filter panel is open, a tap on a row only closes it.
        if (_showFilterMenu) {
          setState(() => _showFilterMenu = false);
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerInfoScreen(
              playerId: id,
              name: name,
              position: position,
              avg: avg,
              price: price,
              team: team,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Color(0xFF1a1a1a),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Color(0xFF333333)),
        ),
        child: _playerColumns(
          /// Player Avatar/Jersey — QA4 #10: was the wrong (Lakers #20)
          /// jersey asset; the approved reference jersey must be used
          /// on every screen that shows this generic per-row jersey.
          leading: Align(
            alignment: Alignment.centerLeft,
            child: Assets.icons.jerseyReference.image(
              width: 28.w,
              height: 42.h,
            ),
          ),

          /// Player Name: two lines at most, "…" as a last resort
          name: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),

          /// Position Badge
          position: Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Color(0xFFFF6B35),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  position,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          /// Average Score
          avg: Center(
            child: Text(
              avg?.toString() ?? '-',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          /// Price
          // One line whatever the amount ("40.0M" used to wrap).
          price: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              price,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
