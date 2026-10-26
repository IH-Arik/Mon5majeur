import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/routes/route_path.dart';
import '../../../../core/routes/routes.dart';
import '../../../../core/utils/logo_assets.dart';
import '../../../../core/utils/server_message.dart';
import '../../../../data/services/api_service.dart';
import '../../../../data/services/api_url.dart';
import '../controllers/create_league_controller.dart';
import '../../../../controllers/my_leagues_controller.dart';
import '../controllers/home_controller.dart';

/// "Ligue terminee": the screen a finished duel league opens on instead of
/// the waiting room (Arik QA item 10 — tapping it used to open the waiting
/// room as for a brand new league, and Delete led nowhere). Shows the final
/// standings and champion, and offers Delete (hides it from this player's
/// own "My Leagues" without losing history or trophies) and Replay (a new
/// league with the same name, settings and roster).
class LeagueFinishedScreen extends StatefulWidget {
  final int leagueId;
  final bool isPublic;

  const LeagueFinishedScreen({
    super.key,
    required this.leagueId,
    required this.isPublic,
  });

  @override
  State<LeagueFinishedScreen> createState() => _LeagueFinishedScreenState();
}

class _LeagueFinishedScreenState extends State<LeagueFinishedScreen> {
  bool _loading = true;
  bool _busy = false;
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
      final url = widget.isPublic
          ? ApiUrl.publicLeagueFinished(widget.leagueId)
          : ApiUrl.privateLeagueFinished(widget.leagueId);
      final response = await ApiClient().get(url: '${ApiUrl.baseUrl}$url');
      if (!mounted) return;
      if (response.statusCode == 200 && response.body is Map) {
        setState(() {
          _data = Map<String, dynamic>.from(response.body as Map);
          _loading = false;
        });
      } else {
        final detail = response.body is Map ? response.body['detail'] : null;
        setState(() {
          _error = detail != null
              ? localizeServerMessage(detail.toString())
              : 'Something went wrong'.tr;
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error'.tr;
        _loading = false;
      });
    }
  }

  String get _tag => widget.isPublic ? 'public' : 'private';

  CreateLeagueController get _controller =>
      Get.find<CreateLeagueController>(tag: _tag);

  Future<void> _delete() async {
    setState(() => _busy = true);
    await _controller.deleteLeague(context, widget.leagueId);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _replay() async {
    final data = _data;
    if (data == null) return;
    if (data['already_replayed'] == true) {
      final id = data['replayed_league_id'] as int?;
      if (id != null) {
        context.go(
          '${RoutePath.privateLeagueWaitingRoomScreen.addBasePath}?leagueId=$id&isPublic=${widget.isPublic}',
        );
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2230),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          AppString.replayLeague.tr,
          style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w700),
        ),
        content: Text(
          AppString.replayLeagueConfirmation.tr,
          style: TextStyle(color: Colors.white70, fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppString.cancel.tr, style: const TextStyle(color: Color(0xFF9B9EAF))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B3D)),
            child: Text(AppString.replayLeague.tr, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final url = widget.isPublic
          ? ApiUrl.replayPublicLeague
          : ApiUrl.replayPrivateLeague;
      final response = await ApiClient().post(
        url: '${ApiUrl.baseUrl}$url',
        body: {'league_id': widget.leagueId},
      );
      if (!mounted) return;
      if (response.statusCode == 200 && response.body is Map) {
        final body = Map<String, dynamic>.from(response.body as Map);
        try {
          await Get.find<MyLeaguesController>().refreshLeagues();
          if (Get.isRegistered<HomeController>()) {
            Get.find<HomeController>().fetchMyLeagues();
          }
        } catch (_) {}
        final newId = body['id'] as int?;
        if (newId != null) {
          context.go(
            '${RoutePath.privateLeagueWaitingRoomScreen.addBasePath}?leagueId=$newId&isPublic=${widget.isPublic}',
          );
        }
      } else {
        final detail = response.body is Map ? response.body['detail'] : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              detail != null ? localizeServerMessage(detail.toString()) : 'Something went wrong'.tr,
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error'.tr), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2230),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          AppString.deleteLeagueConfirmation.tr,
          style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppString.cancel.tr, style: const TextStyle(color: Color(0xFF9B9EAF))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _delete();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC3545)),
            child: Text(AppString.deleteLeague.tr, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F17),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go(RoutePath.myLeague.addBasePath),
        ),
        title: Text(
          AppString.leagueFinished.tr,
          style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B3D)))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.w),
                    child: Text(_error!, style: const TextStyle(color: Colors.white70)),
                  ),
                )
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final data = _data!;
    final teams = (data['teams'] as List? ?? []);
    final championName = data['champion_team_name'] as String? ?? '';
    final leagueName = data['league_name'] as String? ?? '';
    final alreadyReplayed = data['already_replayed'] == true;

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFFFF6B3D),
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 64.w,
                  height: 64.w,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B3D),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.emoji_events, color: Colors.white, size: 36.r),
                ),
                SizedBox(height: 12.h),
                Text(
                  leagueName,
                  style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4.h),
                Text(
                  AppString.leagueFinished.tr,
                  style: TextStyle(color: Colors.white54, fontSize: 13.sp),
                ),
                if (championName.isNotEmpty) ...[
                  SizedBox(height: 16.h),
                  Text(
                    AppString.champion.tr,
                    style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    championName,
                    style: TextStyle(
                      color: const Color(0xFFFFD700),
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            AppString.finalStandings.tr,
            style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8.h),
          ...teams.map((raw) {
            final t = Map<String, dynamic>.from(raw as Map);
            final rank = t['rank'] as int? ?? 0;
            final logo = (t['team_logo'] as String?) ?? '';
            return Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D2B),
                borderRadius: BorderRadius.circular(12.r),
                border: rank == 1
                    ? Border.all(color: const Color(0xFFFFD700), width: 1.r)
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24.w,
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        color: rank == 1 ? const Color(0xFFFFD700) : Colors.white70,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  CircleAvatar(
                    radius: 14.r,
                    backgroundColor: const Color(0xFF0E0F17),
                    backgroundImage: logoAsset(logo).provider(),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      t['team_name'] as String? ?? '',
                      style: TextStyle(color: Colors.white, fontSize: 14.sp),
                    ),
                  ),
                  Text(
                    '${t['wins'] ?? 0}-${t['losses'] ?? 0}',
                    style: TextStyle(color: Colors.white54, fontSize: 13.sp),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: 24.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _busy ? null : _replay,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B3D),
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: Text(
                alreadyReplayed ? AppString.replayAlreadyDoneCta.tr : AppString.replayLeague.tr,
                style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _busy ? null : _confirmDelete,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFDC3545)),
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
              child: Text(
                AppString.deleteLeague.tr,
                style: TextStyle(color: const Color(0xFFDC3545), fontSize: 15.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
