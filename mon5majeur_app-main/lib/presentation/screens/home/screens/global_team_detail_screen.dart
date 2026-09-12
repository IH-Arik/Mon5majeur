import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/custom_assets/assets.gen.dart';
import '../../../../data/models/player.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';
import '../tabs/my_team_tab.dart';

/// QA5 #4 (regression per the client, though the button never actually had
/// an onTap in any commit history - see global_leaderboard_tab.dart): shows
/// one Global League member's LAST PLAYED lineup + score, reached by
/// tapping "Voir l'équipe" on a leaderboard row. Reuses MyTeamTab's
/// existing squad-on-court rendering rather than building a new one, per
/// the client's own request.
class GlobalTeamDetailScreen extends StatefulWidget {
  final int userAutoId;
  final String teamName;

  const GlobalTeamDetailScreen({
    super.key,
    required this.userAutoId,
    required this.teamName,
  });

  @override
  State<GlobalTeamDetailScreen> createState() =>
      _GlobalTeamDetailScreenState();
}

class _GlobalTeamDetailScreenState extends State<GlobalTeamDetailScreen> {
  bool _isLoading = true;
  String? _error;
  String? _nbaDate;
  List<Player?> _players = List.filled(5, null);

  @override
  void initState() {
    super.initState();
    _fetchTeamDetail();
  }

  Future<void> _fetchTeamDetail() async {
    try {
      final response = await ApiClient().get(
        url: '${ApiUrl.baseUrl}${ApiUrl.globalLeaderboardTeamDetail(widget.userAutoId)}',
        showResult: true,
      );
      if (!mounted) return;

      if (response.statusCode == 200 && response.body is Map<String, dynamic>) {
        final body = response.body as Map<String, dynamic>;
        final rawPlayers = body['selected_players'] as List<dynamic>? ?? const [];
        final players = List<Player?>.filled(5, null);
        for (var i = 0; i < rawPlayers.length && i < 5; i++) {
          final raw = rawPlayers[i];
          if (raw is Map<String, dynamic>) {
            players[i] = Player.fromJson(raw);
          }
        }
        setState(() {
          _nbaDate = body['nba_date'] as String?;
          _players = players;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _error = 'Failed to load team (${response.statusCode}).';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load team: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Assets.icons.backButton.image(fit: BoxFit.contain),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.teamName,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF6B3D)),
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 14.sp),
                      ),
                    ),
                  )
                : _nbaDate == null
                    ? Center(
                        child: Text(
                          AppString.noGamesPlayedYet.tr,
                          style: TextStyle(color: Colors.white54, fontSize: 14.sp),
                        ),
                      )
                    : MyTeamTab(
                        savedPlayers: _players,
                        headerText: '${widget.teamName} — $_nbaDate',
                      ),
      ),
    );
  }
}
