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
  final int avg;
  final double price;
  final String team;
  final String? teamId;
  final String? status;

  Player({
    this.id,
    required this.name,
    required this.position,
    required this.avg,
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
      avg:
          0, // API doesn't provide avg, you might need to calculate or use a default
      price: parsedPrice,
      team: json['team'] ?? '',
      teamId: json['team_id']?.toString(),
      status: json['status'],
    );
  }
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
  String _searchQuery = '';

  // Filter states
  RangeValues _priceRange = RangeValues(0.w, 100.w);
  final Set<String> _selectedPositions = {};
  final Set<String> _selectedTeams = {};
  bool _sortAscending = true;

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
  final Set<String> _availableTeams = {};

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
      if (refresh) {
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

      final url = '${ApiUrl.baseUrl}/api/players-today/';

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
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load players. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading players: ${e.toString()}';
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
          _selectedPositions.isEmpty ||
          _selectedPositions.contains(player.position);

      // Team filter
      final matchesTeam =
          _selectedTeams.isEmpty || _selectedTeams.contains(player.team);

      // Price range filter
      final matchesPrice =
          player.price >= _priceRange.start && player.price <= _priceRange.end;

      return matchesSearch && matchesPosition && matchesTeam && matchesPrice;
    }).toList();

    // Sort by average score
    filtered.sort((a, b) {
      return _sortAscending ? a.avg.compareTo(b.avg) : b.avg.compareTo(a.avg);
    });

    return filtered;
  }

  void _clearFilters() {
    setState(() {
      _priceRange = RangeValues(0.w, 100.w);
      _selectedPositions.clear();
      _selectedTeams.clear();
      _sortAscending = true;
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
        children: [
          Column(
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
                      Icon(
                        _showFilterMenu
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 24.r,
                      ),
                      SizedBox(width: 8.w),
                    ],
                  ),
                ),
              ),

              /// Player count indicator
              if (!_isLoading)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    children: [
                      Text(
                        'Loaded: ${_allPlayers.length} / $_totalPlayers players',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12.sp,
                        ),
                      ),
                      if (_hasMorePages)
                        Text(
                          ' • Scroll for more',
                          style: TextStyle(
                            color: Color(0xFFFF6B35),
                            fontSize: 12.sp,
                          ),
                        ),
                    ],
                  ),
                ),

              /// Active Filters Display
              if (_selectedPositions.isNotEmpty ||
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

              /// Table Header
              if (!_isLoading)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          AppString.playerName.tr,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          AppString.position.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          AppString.avg.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          AppString.price.tr,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                              'Loading players...',
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
                                'Retry',
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
                                      'Load More',
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
            Positioned(
              top: 80.h,
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
    String name,
    String position,
    int avg,
    String price,
    String team,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerInfoScreen(
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
            /// Player Avatar/Jersey
            Center(
              child: Assets.icons.dress.image(width: 28.w, height: 42.h),
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
                    avg.toString(),
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
              child: Text(
                price,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
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
