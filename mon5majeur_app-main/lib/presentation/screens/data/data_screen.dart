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

/// Position groups of the "Poste" header / filter (validated mapping, QA #10
/// 6): a multi-position player is in every matching group; labels outside the
/// three groups (for example "NA") only appear under "All" (group 0).
const positionGroupLabels = ['', 'Centers', 'Forwards', 'Guards'];
const _positionGroups = <int, Set<String>>{
  1: {'C', 'C-F', 'F-C'},
  2: {'SF', 'PF', 'F', 'G-F', 'F-G', 'F-C', 'C-F'},
  3: {'PG', 'SG', 'G', 'G-F', 'F-G'},
};

bool inPositionGroup(int group, String position) =>
    group == 0 || (_positionGroups[group]?.contains(position.toUpperCase().trim()) ?? false);

/// [key] 'avg' | 'price' | null (keep the incoming order); a missing average
/// counts below every real one.
List<Player> sortPlayers(List<Player> players, String? key, bool desc) {
  if (key == null) return players;
  num value(Player p) => key == 'avg' ? (p.avg ?? -1) : p.price;
  final sorted = [...players];
  sorted.sort((a, b) {
    final c = value(a).compareTo(value(b));
    return desc ? -c : c;
  });
  return sorted;
}

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiClient _apiClient = ApiClient();

  bool _showFilterMenu = false;
  // Where the filter panel starts: just under the search bar, measured, so the
  // filter icon and the arrow stay visible and tappable while it is open.
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  double _panelTop = 80;

  void _toggleFilter() {
    setState(() => _showFilterMenu = !_showFilterMenu);
    if (!_showFilterMenu) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
      final search = _searchKey.currentContext?.findRenderObject() as RenderBox?;
      if (stack == null || search == null || !mounted) return;
      final bottom = stack.globalToLocal(search.localToGlobal(Offset(0, search.size.height))).dy;
      setState(() => _panelTop = bottom + 4);
    });
  }
  String _searchQuery = '';

  // Filter states
  RangeValues _priceRange = RangeValues(0.w, 100.w);
  // Position group, cycled by the "Poste" header: 0 all, 1 centers,
  // 2 forwards, 3 guards. A multi-position player is in every matching group.
  int _posGroup = 0;
  final Set<String> _selectedTeams = {};
  // One active sort at a time: 'avg' or 'price' (null = server order), with
  // its direction (QA #10 6).
  String? _sortKey;
  bool _sortDesc = true;

  static const _groupLabels = positionGroupLabels;

  // The last list, kept in memory: reopening shows it at once and refreshes
  // in the background (QA #10 5).
  static List<Player>? _cachedPlayers;

  // API states
  List<Player> _allPlayers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
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
    _fetchPlayers();
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
      final cached = _cachedPlayers;
      if (!refresh && cached != null && cached.isNotEmpty) {
        // shown instantly; the refresh below runs in the background
        setState(() {
          _allPlayers = cached;
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _isLoading = true;
          if (refresh) _allPlayers = [];
          _errorMessage = null;
        });
      }

      // all=true: the complete player database, not only tonight's teams
      // (QA #9 4.1).
      final url = '${ApiUrl.baseUrl}/api/players-today/?all=true&size=1000';

      final response = await _apiClient.get(url: url, showResult: true);

      if (response.statusCode == 200 && response.body != null) {
        final data = response.body as Map<String, dynamic>;
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

          _cachedPlayers = players;
          setState(() {
            _allPlayers = players;
            _isLoading = false;
          });
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
    List<Player> filtered = _allPlayers.where((player) {
      // Search filter
      final matchesSearch = player.name.toLowerCase().contains(_searchQuery);

      // Position filter
      final matchesPosition =
          inPositionGroup(_posGroup, player.position);

      // Team filter
      final matchesTeam =
          _selectedTeams.isEmpty || _selectedTeams.contains(player.team);

      // Price range filter
      final matchesPrice =
          player.price >= _priceRange.start && player.price <= _priceRange.end;

      return matchesSearch && matchesPosition && matchesTeam && matchesPrice;
    }).toList();

    filtered = sortPlayers(filtered, _sortKey, _sortDesc);

    return filtered;
  }

  void _clearFilters() {
    setState(() {
      _priceRange = RangeValues(0.w, 100.w);
      _posGroup = 0;
      _sortKey = null;
      _selectedTeams.clear();
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
      body: Stack(
        key: _stackKey,
        children: [
          Column(
            children: [
              /// Search Bar with Filter Button
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Container(
                  key: _searchKey,
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
                        onPressed: _toggleFilter,
                        icon: Icon(
                          Icons.tune,
                          color: _showFilterMenu
                              ? const Color(0xFFFF6B35)
                              : Colors.white,
                          size: 24.r,
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _toggleFilter,
                        child: Icon(
                          _showFilterMenu
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.white,
                          size: 24.r,
                        ),
                      ),
                      SizedBox(width: 8.w),
                    ],
                  ),
                ),
              ),

              /// Active Filters Display
              if (_posGroup != 0 ||
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
                              if (_posGroup != 0)
                                _buildFilterChip(_groupLabels[_posGroup].tr),
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

              /// Table Header: the SAME columns as the player cards (QA #10 6/7)
              /// - the cards sit in a 16 margin + 12 padding, with a 28 jersey and
              /// a 12 gap before the name - and tappable to sort / filter.
              if (!_isLoading)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 28.w),
                  child: Row(
                    children: [
                      SizedBox(width: 40.w), // jersey column
                      Expanded(flex: 3, child: _headerText(AppString.playerName.tr)),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _posGroup = (_posGroup + 1) % 4),
                          child: _headerText(
                            _posGroup == 0
                                ? AppString.position.tr
                                : '${AppString.position.tr} : ${_groupLabels[_posGroup].tr}',
                            align: TextAlign.center,
                            active: _posGroup != 0,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: _sortHeader('avg', AppString.avg.tr, TextAlign.center),
                      ),
                      Expanded(
                        flex: 1,
                        child: _sortHeader('price', AppString.price.tr, TextAlign.right),
                      ),
                    ],
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

          /// Filter Menu Overlay
          if (_showFilterMenu)
            // Tap outside the panel closes it.
            Positioned.fill(
              top: _panelTop,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _showFilterMenu = false),
                child: Container(color: Colors.black38),
              ),
            ),
          if (_showFilterMenu)
            Positioned(
              top: _panelTop,
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
                                        _sortKey = 'avg';
                                        _sortDesc = false;
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (_sortKey == 'avg' && !_sortDesc)
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
                                          color: (_sortKey == 'avg' && !_sortDesc)
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
                                        _sortKey = 'avg';
                                        _sortDesc = true;
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: (_sortKey == 'avg' && _sortDesc)
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
                                          color: (_sortKey == 'avg' && _sortDesc)
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

                      /// Position: the same four states as the "Poste" header
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
                              children: [
                                for (var g = 0; g < 4; g++)
                                  GestureDetector(
                                    onTap: () => setState(() => _posGroup = g),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16.w,
                                        vertical: 8.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _posGroup == g
                                            ? const Color(0xFFFF6B35)
                                            : const Color(0xFF2a2a2a),
                                        borderRadius: BorderRadius.circular(8.r),
                                      ),
                                      child: Text(
                                        (g == 0 ? 'All' : _groupLabels[g]).tr,
                                        style: TextStyle(
                                          color: _posGroup == g
                                              ? Colors.white
                                              : Colors.grey,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w600,
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
      bottomNavigationBar: const NavigationWidget(currentIndex: 2),
    );
  }

  Widget _headerText(String text, {TextAlign align = TextAlign.left, bool active = false}) {
    return Text(
      text,
      textAlign: align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: active ? const Color(0xFFFF6B35) : Colors.grey,
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// Sortable column header: first tap = descending (best first), then it
  /// alternates; tapping the other header replaces the sort.
  Widget _sortHeader(String key, String label, TextAlign align) {
    final active = _sortKey == key;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        if (_sortKey == key) {
          _sortDesc = !_sortDesc;
        } else {
          _sortKey = key;
          _sortDesc = true;
        }
      }),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: align == TextAlign.right ? Alignment.centerRight : Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _headerText(label, align: align, active: active),
            if (active)
              Icon(
                _sortDesc ? Icons.arrow_downward : Icons.arrow_upward,
                size: 12.r,
                color: const Color(0xFFFF6B35),
              ),
          ],
        ),
      ),
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
        child: Row(
          children: [
            /// Player Avatar/Jersey — QA4 #10: was the wrong (Lakers #20)
            /// jersey asset; the approved reference jersey must be used
            /// on every screen that shows this generic per-row jersey.
            Center(
              child: Assets.icons.jerseyReference.image(
                width: 28.w,
                height: 42.h,
              ),
            ),
            SizedBox(width: 12.w),

            /// Player Name
            Expanded(
              flex: 3,
              child: Text(
                name,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            /// Position Badge
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: Color(0xFFFF6B35),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
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
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Text(
                    avg?.toString() ?? '-',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            /// Price
            Expanded(
              flex: 1,
              // One line whatever the amount ("40.0M" used to wrap).
              child: FittedBox(
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
          ],
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
