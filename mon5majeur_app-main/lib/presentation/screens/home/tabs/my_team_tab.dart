import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../data/models/player.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';

class MyTeamTab extends StatefulWidget {
  final List<Player?>? savedPlayers;
  final int? savedJerseyIndex;
  final int? leagueId;
  final int? matchDay;
  final bool isPrivate; // ADD THIS

  const MyTeamTab({
    super.key,
    this.savedPlayers,
    this.savedJerseyIndex,
    this.leagueId,
    this.matchDay,
    this.isPrivate = false, // ADD THIS
  });

  @override
  State<MyTeamTab> createState() => _MyTeamTabState();
}

class _MyTeamTabState extends State<MyTeamTab> {
  late List<Player?> selectedPlayers;
  late int selectedJerseyIndex;
  final ApiClient _apiClient = ApiClient();

  final List<AssetGenImage> jerseys = [
    Assets.icons.jerseyDevil,
    Assets.icons.jerseyFlower,
    Assets.icons.jerseyUfo,
    Assets.icons.jerseyShark,
    Assets.icons.jerseySnake,
    Assets.icons.jerseyZebra,
  ];

  // Mock points for players
  final Map<String, int> playerPoints = {
    AppString.nikolaVucevic: 21,
    AppString.jasonTatum: 12,
    AppString.lebronJames: 22,
    AppString.donovanMitchell: 9,
    AppString.stephenCurry: 19,
  };

  @override
  void initState() {
    super.initState();
    selectedPlayers = widget.savedPlayers ?? List.filled(5, null);
    selectedJerseyIndex = widget.savedJerseyIndex ?? 0;

    // Fetch saved team if leagueId and matchDay are provided
    if (widget.leagueId != null &&
        widget.matchDay != null &&
        widget.matchDay! > 0) {
      _fetchSavedTeam();
    }
  }

  @override
  void didUpdateWidget(MyTeamTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reload team if match day changes
    if (oldWidget.matchDay != widget.matchDay &&
        widget.leagueId != null &&
        widget.matchDay != null &&
        widget.matchDay! > 0) {
      _fetchSavedTeam();
    }
  }

  Future<void> _fetchSavedTeam() async {
    if (widget.leagueId == null ||
        widget.matchDay == null ||
        widget.matchDay == 0) {
      debugPrint(
        '⚠️ Cannot fetch saved team: League ID or Match Day not available',
      );
      return;
    }

    try {
      debugPrint(
        '🔄 Fetching saved team for League ${widget.leagueId}, Match Day ${widget.matchDay}',
      );

      final url = widget.isPrivate
          ? '${ApiUrl.baseUrl}${ApiUrl.privatePlayersSelection(widget.leagueId!, widget.matchDay!)}'
          : '${ApiUrl.baseUrl}${ApiUrl.publicPlayersSelection(widget.leagueId!, widget.matchDay!)}';

      final response = await _apiClient.get(url: url, showResult: true);

      if (response.statusCode == 200) {
        final data = response.body as Map<String, dynamic>;
        final savedPlayersData = data['selected_players'] as List<dynamic>?;

        if (savedPlayersData != null && savedPlayersData.isNotEmpty) {
          debugPrint('✅ Found ${savedPlayersData.length} saved players');

          setState(() {
            // Clear existing selections
            selectedPlayers = List.filled(5, null);

            // Fill in the saved players
            for (int i = 0; i < savedPlayersData.length && i < 5; i++) {
              selectedPlayers[i] = Player.fromJson(
                savedPlayersData[i] as Map<String, dynamic>,
              );
            }
          });

          debugPrint('✅ Team loaded successfully');
        } else {
          debugPrint('ℹ️ No saved team found for this match day');
        }
      } else if (response.statusCode == 404) {
        debugPrint('ℹ️ No saved team found (404)');
      } else {
        debugPrint('⚠️ Error fetching saved team: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetching saved team: $e');
    }
  }

  int get totalPoints => selectedPlayers.fold(0, (sum, player) {
    if (player != null) {
      return sum + (playerPoints[player.name] ?? 0);
    }
    return sum;
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 16.h),
          Text(
            AppString.myTeamPointsForToday.tr,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 16.h),
          Positioned.fill(
            child: Assets.icons.timer.image(height: 33.h, width: 33.w),
          ),
          SizedBox(height: 16.h),
          _buildCourtField(),
          SizedBox(height: 16.h),
          _buildTotalPoints(),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  Widget _buildCourtField() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      height: 600.h,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12.r)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Stack(
          children: [
            Positioned.fill(
              child: Assets.images.playground.image(fit: BoxFit.cover),
            ),
            // Semi-transparent overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ),
            ),
            // Player positions matching BuildYourTeamTab layout
            Positioned(
              top: 150.h,
              left: 40.w,
              child: _buildPlayerWithPoints(0, AppString.sfPf.tr),
            ),
            Positioned(
              top: 120.h,
              left: 0.w,
              right: 0.w,
              child: Center(child: _buildPlayerWithPoints(1, AppString.c.tr)),
            ),
            Positioned(
              top: 150.h,
              right: 40.w,
              child: _buildPlayerWithPoints(2, AppString.sfPf.tr),
            ),
            Positioned(
              top: 320.h,
              left: 60.w,
              child: _buildPlayerWithPoints(3, AppString.pgSg.tr),
            ),
            Positioned(
              top: 320.h,
              right: 60.w,
              child: _buildPlayerWithPoints(4, AppString.pgSg.tr),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerWithPoints(int index, String position) {
    final player = selectedPlayers[index];
    final points = player != null ? (playerPoints[player.name] ?? 0) : 0;

    return Column(
      children: [
        SizedBox(
          width: 114.w,
          height: 96.h,
          child: Stack(
            children: [
              // Jersey background
              Positioned(
                left: 0.w,
                top: 0.h,
                child: Container(
                  width: 114.w,
                  height: 91.h,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: jerseys[selectedJerseyIndex].provider(),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              // Points circle
              if (player != null)
                Positioned(
                  left: 41.w,
                  top: 85.h,
                  child: Container(
                    width: 28.w,
                    height: 11.h,
                    decoration: ShapeDecoration(
                      color: const Color(0xFF777777),
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(
                          width: 0.50,
                          color: Color(0xFFFFFFFF),
                        ),
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                    ),
                  ),
                ),
              // Position label text
              Positioned(
                left: 44.w,
                top: 86.h,
                child: SizedBox(
                  width: 22.w,
                  height: 9.h,
                  child: Text(
                    position,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 8.sp,
                      fontFamily: AppString.latoFont.tr,
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (player != null) ...[
          SizedBox(height: 4.h),
          SizedBox(
            width: 114.w,
            child: Text(
              player.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFFFECD56),
                fontSize: 11.sp,
                fontFamily: AppString.robotoFont.tr,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
          SizedBox(height: 2.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            decoration: ShapeDecoration(
              color: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 1, color: Color(0xFF2C2C2C)),
                borderRadius: BorderRadius.circular(6.r),
              ),
            ),
            child: Text(
              '$points',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontFamily: AppString.robotoFont.tr,
                fontWeight: FontWeight.w800,
                height: 1.2,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTotalPoints() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0.w, vertical: 10.0.h),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Text(
          '$totalPoints ${AppString.points.tr}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
