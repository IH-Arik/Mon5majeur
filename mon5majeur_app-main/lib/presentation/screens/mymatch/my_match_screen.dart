import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/custom_assets/assets.gen.dart';
import '../../widgets/navigation.dart';

class MyMatchScreen extends StatefulWidget {
  const MyMatchScreen({super.key});

  @override
  State<MyMatchScreen> createState() => _MyMatchScreenState();
}

class _MyMatchScreenState extends State<MyMatchScreen> {
  bool _isNbaResultsExpanded = true;
  bool _isFantasyPlayersExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          AppString.todaysNbaResults.tr,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            /// Todays NBA Results Section
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a1a),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: Column(
                children: [
                  /// Header
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isNbaResultsExpanded = !_isNbaResultsExpanded;
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Row(
                        children: [
                          Assets.icons.basketBall.image(
                            width: 29.w,
                            height: 29.h,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              AppString.todaysNbaResults.tr,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            _isNbaResultsExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.white,
                            size: 28.r,
                          ),
                        ],
                      ),
                    ),
                  ),

                  /// Expandable Content
                  if (_isNbaResultsExpanded)
                    Column(
                      children: [
                        _buildMatchResult(
                          AppString.lakers.tr,
                          103,
                          AppString.suns.tr,
                          100,
                        ),
                        _buildMatchResult(
                          AppString.lakers.tr,
                          103,
                          AppString.suns.tr,
                          100,
                        ),
                        _buildMatchResult(
                          AppString.lakers.tr,
                          103,
                          AppString.suns.tr,
                          100,
                        ),
                      ],
                    ),
                ],
              ),
            ),

            SizedBox(height: 20.h),

            /// Todays Fantasy Players Score Section
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a1a),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: Column(
                children: [
                  /// Header
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isFantasyPlayersExpanded = !_isFantasyPlayersExpanded;
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Row(
                        children: [
                          Assets.icons.basketBall.image(
                            width: 29.w,
                            height: 29.h,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              AppString.todaysFantasyPlayersScore.tr,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            _isFantasyPlayersExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: Colors.white,
                            size: 28.r,
                          ),
                        ],
                      ),
                    ),
                  ),

                  /// Expandable Content
                  if (_isFantasyPlayersExpanded)
                    Column(
                      children: [
                        _buildPlayerCard(
                          AppString.lebronJames.tr,
                          AppString.lakers.tr,
                          35,
                        ),
                        _buildPlayerCard(
                          AppString.lebronJames.tr,
                          AppString.lakers.tr,
                          20,
                        ),
                        _buildPlayerCard(
                          AppString.lebronJames.tr,
                          AppString.lakers.tr,
                          33,
                        ),
                        _buildPlayerCard(
                          AppString.lebronJames.tr,
                          AppString.lakers.tr,
                          12,
                        ),
                        _buildPlayerCard(
                          AppString.lebronJames.tr,
                          AppString.lakers.tr,
                          14,
                        ),
                        _buildPlayerCard(
                          AppString.lebronJames.tr,
                          AppString.lakers.tr,
                          23,
                        ),
                        _buildPlayerCard(
                          AppString.lebronJames.tr,
                          AppString.lakers.tr,
                          22,
                        ),
                      ],
                    ),
                ],
              ),
            ),

            SizedBox(height: 20.h),
          ],
        ),
      ),
      bottomNavigationBar: const NavigationWidget(currentIndex: 1),
    );
  }

  Widget _buildMatchResult(String team1, int score1, String team2, int score2) {
    final bool team1Won = score1 > score2;

    return Container(
      margin: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF0a0a0a),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF2a2a2a)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              team1,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            score1.toString(),
            style: TextStyle(
              color: team1Won ? Colors.green : Colors.red,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Text(
              AppString.vs.tr,
              style: TextStyle(color: Colors.grey, fontSize: 16.sp),
            ),
          ),
          Text(
            score2.toString(),
            style: TextStyle(
              color: !team1Won ? Colors.green : Colors.red,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              team2,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(String playerName, String team, int score) {
    return Container(
      margin: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: const Color(0xFF0a0a0a),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF2a2a2a)),
      ),
      child: Row(
        children: [
          /// Player Avatar/Jersey
          Center(
            child: Assets.icons.dress.image(width: 28.w, height: 42.h),
          ),
          SizedBox(width: 12.w),

          /// Player Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playerName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8632C),
                        borderRadius: BorderRadius.circular(9.r),
                      ),
                      child: Text(
                        AppString.sf.tr,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      team,
                      style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                    ),
                  ],
                ),
              ],
            ),
          ),

          /// Score
          Text(
            score.toString(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
