import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:mon5majeur_app/core/custom_assets/assets.gen.dart';
import 'package:mon5majeur_app/core/constants/app_strings.dart';

import 'match_results_dialog.dart';

class PlayOffView extends StatelessWidget {
  const PlayOffView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRoundTitle(AppString.quarterFinalMatchday1.tr),
        SizedBox(height: 24.h),
        _buildPlayoffRound(
          [
            _PlayoffMatch(
              'Paris FC',
              Assets.icons.logo1,
              2,
              'Kiki FC',
              Assets.icons.logo2,
              0,
              true,
            ),
            _PlayoffMatch(
              'Lily FC',
              Assets.icons.logo3,
              2,
              'Micy FC',
              Assets.icons.logo4,
              0,
              true,
            ),
          ],
          [
            _SemiFinalTeam('Paris FC', Assets.icons.logo1, 0),
            _SemiFinalTeam('Lily FC', Assets.icons.logo5, 0),
          ],
        ),
        SizedBox(height: 40.h),
        _buildRoundTitle(AppString.semiFinals.tr),
        SizedBox(height: 24.h),
        _buildPlayoffRound(
          [
            _PlayoffMatch(
              'Paris FC',
              Assets.icons.logo1,
              2,
              'Kiki FC',
              Assets.icons.logo2,
              0,
              true,
            ),
            _PlayoffMatch(
              'Lily FC',
              Assets.icons.logo3,
              2,
              'Micy FC',
              Assets.icons.logo4,
              0,
              true,
            ),
          ],
          [
            _SemiFinalTeam('Paris FC', Assets.icons.logo1, 0),
            _SemiFinalTeam('Lily FC', Assets.icons.logo5, 0),
          ],
        ),
        SizedBox(height: 32.h),
        Builder(builder: (context) => _buildSeeMatchResultsButton(context)),
      ],
    );
  }

  Widget _buildPlayoffRound(
    List<_PlayoffMatch> matches,
    List<_SemiFinalTeam> winners,
  ) {
    return Column(
      children: [
        _buildPlayoffMatchRow(matches[0], winners[0]),
        SizedBox(height: 24.h),
        _buildPlayoffMatchRow(matches[1], winners[1]),
      ],
    );
  }

  Widget _buildPlayoffMatchRow(_PlayoffMatch match, _SemiFinalTeam winner) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _buildMatchCard(
                match.team1Logo,
                match.team1Name,
                match.score1.toString(),
                match.team1Won,
              ),
              SizedBox(height: 12.h),
              _buildMatchCard(
                match.team2Logo,
                match.team2Name,
                match.score2.toString(),
                !match.team1Won,
              ),
            ],
          ),
        ),
        SizedBox(width: 16.w),
        SizedBox(
          width: 40.w,
          child: CustomPaint(
            size: Size(40.w, 90.h),
            painter: _BracketPainter(),
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          flex: 5,
          child: _buildSemiFinalMatchCard(
            winner.logo,
            winner.name,
            winner.score.toString(),
          ),
        ),
      ],
    );
  }

  Widget _buildRoundTitle(String title) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF2A2A2A)],
        ),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white,
          fontSize: 12.sp,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildMatchCard(
    AssetGenImage logo,
    String teamName,
    String score,
    bool isWinner,
  ) {
    return SizedBox(
      width: 130.w,
      height: 43.h,
      child: Stack(
        children: [
          Positioned(
            left: 27.w,
            top: 0.h,
            child: Container(
              width: 103.w,
              height: 43.h,
              decoration: ShapeDecoration(
                color: const Color(0xFFE8632C),
                shape: RoundedRectangleBorder(
                  side: BorderSide(width: 1.r, color: const Color(0xFF2C2C2C)),
                  borderRadius: BorderRadius.circular(7.r),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0.w,
            top: 0.h,
            child: Container(
              width: 103.w,
              height: 43.h,
              decoration: ShapeDecoration(
                color: const Color(0xFF1A1A1A),
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    width: 1.r,
                    color: isWinner
                        ? const Color(0xFF3CDF1C)
                        : const Color(0xFFD32F2F),
                  ),
                  borderRadius: BorderRadius.circular(7.r),
                ),
              ),
            ),
          ),
          Positioned(
            left: 37.w,
            top: 11.h,
            child: Text(
              teamName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontFamily: AppString.roboto,
                fontWeight: FontWeight.w500,
                height: 1.57,
              ),
            ),
          ),
          Positioned(
            left: 7.w,
            top: 9.h,
            child: Container(
              width: 26.w,
              height: 26.h,
              decoration: ShapeDecoration(
                color: const Color(0xFF1A1A1A),
                shape: OvalBorder(
                  side: BorderSide(width: 1.r, color: const Color(0xFF2C2C2C)),
                ),
              ),
            ),
          ),
          Positioned(
            left: 14.22.w,
            top: 14.78.h,
            child: SizedBox(
              width: 13.13.w,
              height: 14.31.h,
              child: logo.image(fit: BoxFit.cover),
            ),
          ),
          Positioned(
            left: 110.w,
            top: 13.h,
            child: SizedBox(
              width: 9.w,
              height: 17.h,
              child: Text(
                score,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontFamily: AppString.russoOne,
                  fontWeight: FontWeight.w400,
                  height: 1.10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSemiFinalMatchCard(
    AssetGenImage logo,
    String teamName,
    String score,
  ) {
    return SizedBox(
      width: 130.w,
      height: 43.h,
      child: Stack(
        children: [
          Positioned(
            left: 27.w,
            top: 0.h,
            child: Container(
              width: 103.w,
              height: 43.h,
              decoration: ShapeDecoration(
                color: const Color(0xFFE8632C),
                shape: RoundedRectangleBorder(
                  side: BorderSide(width: 1.r, color: const Color(0xFF2C2C2C)),
                  borderRadius: BorderRadius.circular(7.r),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0.w,
            top: 0.h,
            child: Container(
              width: 103.w,
              height: 43.h,
              decoration: ShapeDecoration(
                color: const Color(0xFF1A1A1A),
                shape: RoundedRectangleBorder(
                  side: BorderSide(width: 1.r, color: const Color(0xFF2C2C2C)),
                  borderRadius: BorderRadius.circular(7.r),
                ),
              ),
            ),
          ),
          Positioned(
            left: 37.w,
            top: 11.h,
            child: Text(
              teamName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontFamily: AppString.roboto,
                fontWeight: FontWeight.w500,
                height: 1.57,
              ),
            ),
          ),
          Positioned(
            left: 7.w,
            top: 9.h,
            child: Container(
              width: 26.w,
              height: 26.h,
              decoration: ShapeDecoration(
                color: const Color(0xFF1A1A1A),
                shape: OvalBorder(
                  side: BorderSide(width: 1.r, color: const Color(0xFF2C2C2C)),
                ),
              ),
            ),
          ),
          Positioned(
            left: 14.22.w,
            top: 14.78.h,
            child: SizedBox(
              width: 13.13.w,
              height: 14.31.h,
              child: logo.image(fit: BoxFit.cover),
            ),
          ),
          Positioned(
            left: 110.w,
            top: 13.h,
            child: SizedBox(
              width: 9.w,
              height: 17.h,
              child: Text(
                score,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontFamily: AppString.russoOne,
                  fontWeight: FontWeight.w400,
                  height: 1.10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeeMatchResultsButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showMatchResultsDialog(context);
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8632C), Color(0xFFFF8A50)],
          ),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Text(
          AppString.seeMatchResults.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PlayoffMatch {
  final String team1Name;
  final AssetGenImage team1Logo;
  final int score1;
  final String team2Name;
  final AssetGenImage team2Logo;
  final int score2;
  final bool team1Won;

  _PlayoffMatch(
    this.team1Name,
    this.team1Logo,
    this.score1,
    this.team2Name,
    this.team2Logo,
    this.score2,
    this.team1Won,
  );
}

class _SemiFinalTeam {
  final String name;
  final AssetGenImage logo;
  final int score;

  _SemiFinalTeam(this.name, this.logo, this.score);
}

class _BracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.r
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.25);
    path.lineTo(size.width * 0.6, size.height * 0.25);
    path.moveTo(size.width * 0.6, size.height * 0.25);
    path.lineTo(size.width * 0.6, size.height * 0.75);
    path.moveTo(size.width * 0.6, size.height * 0.75);
    path.lineTo(0, size.height * 0.75);
    path.moveTo(size.width * 0.6, size.height * 0.5);
    path.lineTo(size.width, size.height * 0.5);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
