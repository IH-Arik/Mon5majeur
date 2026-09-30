import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_strings.dart';

/// Tab indexes shared by every league screen (the order of the IndexedStack).
class LeagueTab {
  static const createTeam = 0;
  static const result = 1;
  static const standings = 2;
  static const rules = 3;
}

/// The league menu — ONE component for the Global League and the private /
/// public leagues (QA 24/09 #4: the private-league menu had older icons and no
/// "Live" tab). Four switchable tabs plus "Live", which is pushed as its own
/// screen instead of switched in: the live screen polls the backend and must
/// not keep doing that in the background while another tab is shown.
class LeagueTabBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onLive;
  // On the Live screen itself: "Live" is the highlighted tab and none of the
  // four switchable ones is.
  final bool liveActive;

  const LeagueTabBar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onLive,
    this.liveActive = false,
  });

  static const icons = <IconData>[
    Icons.add,
    Icons.scoreboard,
    Icons.leaderboard,
    Icons.menu_book,
  ];
  static const liveIcon = Icons.bolt;

  @override
  Widget build(BuildContext context) {
    final labels = [
      AppString.createTeam.tr,
      AppString.result.tr,
      AppString.leaderboard.tr,
      AppString.rules.tr,
    ];
    // QA4 #2: no scrollable tab bar - all tabs must be visible at once. Each
    // tab gets an equal share of the width and its label shrinks if needed,
    // so five French labels never overflow a small phone (QA 15/09 #9 had
    // "Score en Dire..." cut off).
    return Container(
      color: const Color(0xFF1A1C2A),
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 4.w),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            _tab(labels[i], icons[i], !liveActive && selected == i,
                () => onSelect(i)),
          _tab(AppString.liveTabLabel.tr, liveIcon, liveActive, onLive),
        ],
      ),
    );
  }

  Widget _tab(String label, IconData icon, bool isActive, VoidCallback onTap) {
    final color = isActive ? const Color(0xFFFF8C42) : Colors.white54;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 4.h),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24.r),
              SizedBox(height: 4.h),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 4.h),
              Container(
                width: 40.w,
                height: 3.h,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFFF8C42)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
