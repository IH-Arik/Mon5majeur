import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/custom_assets/assets.gen.dart';
import '../widgets/global_published_result.dart';

/// "Voir l'équipe" on a Global League leaderboard row: that member's lineup
/// and points for the latest PUBLISHED night, with arrows back through earlier
/// nights (QA #9 7.3). The night in progress is never shown, so no hourglass
/// and nobody's current lineup can be copied.
class GlobalTeamDetailScreen extends StatelessWidget {
  final int userAutoId;
  final String teamName;

  const GlobalTeamDetailScreen({
    super.key,
    required this.userAutoId,
    required this.teamName,
  });

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
          teamName,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(child: GlobalPublishedResult(userAutoId: userAutoId)),
    );
  }
}
